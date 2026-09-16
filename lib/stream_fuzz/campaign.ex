defmodule StreamFuzz.Campaign do
  @moduledoc """
  Orchestrates discovery → coverage → schedule → execute → corpus loop.
  """

  alias StreamFuzz.{
    Corpus,
    Coverage,
    Discoverer,
    Executor,
    Reporter,
    Scheduler,
    Seed,
    Target
  }

  @type opts :: keyword()

  @doc """
  Run a fuzz campaign.

  Returns `{:ok, summary}` or `{:error, reason}`.
  """
  @spec run(opts()) :: {:ok, map()} | {:error, term()}
  def run(opts \\ []) do
    paths = Keyword.get(opts, :paths, ["test"])
    corpus_dir = Keyword.get(opts, :corpus_dir, default_corpus_dir())
    cover_apps = Keyword.get(opts, :cover_apps, default_cover_apps())
    duration_ms = Keyword.get(opts, :duration_ms)
    max_examples = Keyword.get(opts, :max_examples)
    max_failures = Keyword.get(opts, :max_failures, 10)
    progress_every_ms = Keyword.get(opts, :progress_every_ms, 5_000)
    only = Keyword.get(opts, :only)
    replay = Keyword.get(opts, :replay)
    replay_seed = Keyword.get(opts, :replay_seed)
    replay_size = Keyword.get(opts, :replay_size)

    cond do
      replay ->
        replay_failure(replay, opts)

      replay_seed ->
        run_replay(opts, only, replay_seed, replay_size || 1)

      true ->
        with {:ok, targets} <- Discoverer.discover(paths: paths, only: only),
             {:ok, coverage} <- start_coverage(cover_apps) do
          corpus = Corpus.open(corpus_dir)
          Corpus.write_meta(corpus, %{"cover_apps" => Enum.map(cover_apps, &Atom.to_string/1)})

          scheduler =
            Scheduler.new(targets,
              p_fresh: config(:p_fresh, 0.2),
              p_mutate: config(:p_mutate, 0.7),
              plateau_ms: config(:plateau_ms, 60_000)
            )

          IO.puts("StreamFuzz: #{length(targets)} target(s), corpus=#{corpus_dir}")
          Enum.each(targets, fn t -> IO.puts("  • #{t.id}") end)
          IO.puts("")

          state = %{
            coverage: coverage,
            corpus: corpus,
            scheduler: scheduler,
            failures: [],
            started_at: System.monotonic_time(:millisecond),
            last_progress_at: System.monotonic_time(:millisecond),
            duration_ms: duration_ms,
            max_examples: max_examples,
            max_failures: max_failures,
            progress_every_ms: progress_every_ms
          }

          summary = loop(state)
          Reporter.summary(summary.scheduler, summary.coverage, summary.corpus, summary.failures)

          _ = Coverage.export_summary(summary.coverage, Path.dirname(corpus_dir))

          status = if summary.failures == [], do: :ok, else: :failed
          {:ok, Map.put(summary, :status, status)}
        end
    end
  end

  defp loop(state) do
    cond do
      stop?(state) ->
        state

      true ->
        {work, scheduler} = Scheduler.next(state.scheduler, state.corpus)
        state = %{state | scheduler: scheduler}

        prev_best = Map.fetch!(state.scheduler.stats, work.target.id).target_best

        {result, coverage} =
          Executor.run_one(work.target, work.seed, state.coverage, prev_target_best: prev_best)

        state = %{state | coverage: coverage}
        state = handle_result(state, work.target, result)
        state = maybe_progress(state)
        loop(state)
    end
  end

  defp handle_result(state, target, result) do
    novelty? = MapSet.size(result.novelty) > 0
    failure? = result.outcome == :failure

    scheduler =
      Scheduler.record(state.scheduler, target,
        novelty?: novelty?,
        failure?: failure?,
        target_score: result.target_score
      )

    corpus =
      if result.outcome in [:interesting, :failure] do
        Corpus.put(state.corpus, result.seed)
      else
        state.corpus
      end

    failures =
      if failure? do
        replay_cmd = replay_command(target, result.seed)
        Reporter.failure(target, result, replay_cmd)
        report = Reporter.failure_report(target, result, replay_cmd)
        path = Corpus.write_failure(corpus, target, report)
        IO.puts("  wrote #{path}")
        [%{target: target, result: result, path: path} | state.failures]
      else
        state.failures
      end

    %{state | scheduler: scheduler, corpus: corpus, failures: failures}
  end

  defp maybe_progress(state) do
    now = System.monotonic_time(:millisecond)

    if now - state.last_progress_at >= state.progress_every_ms do
      Reporter.progress(now - state.started_at, state.scheduler, state.coverage, state.corpus)
      %{state | last_progress_at: now}
    else
      state
    end
  end

  defp stop?(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.started_at

    cond do
      state.duration_ms && elapsed >= state.duration_ms ->
        true

      state.max_examples && Scheduler.total_examples(state.scheduler) >= state.max_examples ->
        true

      length(state.failures) >= state.max_failures ->
        true

      true ->
        false
    end
  end

  defp start_coverage([]), do: Coverage.start_empty()
  defp start_coverage(apps), do: Coverage.start(apps)

  defp default_corpus_dir do
    Application.get_env(:stream_fuzz, :corpus_dir, Path.join(["_build", "stream_fuzz", "corpus"]))
  end

  defp default_cover_apps do
    Application.get_env(:stream_fuzz, :cover_apps, [])
  end

  defp config(key, default) do
    Application.get_env(:stream_fuzz, key, default)
  end

  defp replay_command(%Target{} = target, %Seed{} = seed) do
    only = shell_escape(target.description)

    "mix stream_fuzz --only #{only} --replay-seed #{seed.stream_seed} --replay-size #{seed.size} --max-examples 1"
  end

  defp shell_escape(s) when is_binary(s) do
    if String.contains?(s, " "), do: "\"#{String.replace(s, "\"", "\\\"")}\"", else: s
  end

  defp replay_failure(path, opts) when is_binary(path) do
    with {:ok, body} <- File.read(path),
         {:ok, report} <- Jason.decode(body) do
      only = report["property"] || report["target_id"]
      seed = String.to_integer(to_string(report["stream_seed"]))
      size = String.to_integer(to_string(report["size"]))

      run_replay(opts, only, seed, size, path)
    end
  end

  @doc false
  def run_replay(opts, only, stream_seed, size, source \\ nil) do
    paths = Keyword.get(opts, :paths, ["test"])

    with {:ok, targets} <- Discoverer.discover(paths: paths, only: only) do
      target = hd(targets)
      {:ok, coverage} = start_coverage(Keyword.get(opts, :cover_apps, []))

      seed = %Seed{
        target_id: target.id,
        stream_seed: stream_seed,
        size: size,
        data: nil,
        features: MapSet.new(),
        interesting_reason: :failure,
        saved_at: nil,
        run_index: 0
      }

      {result, _} = Executor.run_one(target, seed, coverage)
      replay_hint = source || "mix stream_fuzz --replay-seed #{stream_seed} --replay-size #{size}"

      case result.outcome do
        :failure ->
          Reporter.failure(target, result, replay_hint)
          Reporter.summary(nil, coverage, nil, [result])
          {:ok, %{status: :failed, failures: [result]}}

        _ ->
          IO.puts("Replay did not fail (property may have been fixed).")
          Reporter.summary(nil, coverage, nil, [])
          {:ok, %{status: :ok, failures: []}}
      end
    end
  end
end
