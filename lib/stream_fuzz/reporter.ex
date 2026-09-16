defmodule StreamFuzz.Reporter do
  @moduledoc false

  alias StreamFuzz.{Scheduler, Target}

  def progress(elapsed_ms, scheduler, coverage, corpus) do
    mins = div(elapsed_ms, 60_000)
    secs = div(rem(elapsed_ms, 60_000), 1000)
    time = if mins > 0, do: "#{mins}m#{secs}s", else: "#{secs}s"

    seen = StreamFuzz.Coverage.seen_count(coverage)
    failures = Scheduler.total_failures(scheduler)
    examples = Scheduler.total_examples(scheduler)
    corpus_size = StreamFuzz.Corpus.size(corpus)
    targets = length(scheduler.targets)

    {hot, cold} = Scheduler.hot_cold(scheduler, 1)

    hot_line =
      case hot do
        [t | _] ->
          s = Map.fetch!(scheduler.stats, t.id)
          "  hot: #{short(t)} (ema=#{Float.round(s.novelty_ema, 2)})"

        _ ->
          nil
      end

    cold_line =
      case cold do
        [t | _] ->
          s = Map.fetch!(scheduler.stats, t.id)

          plateau =
            case s.plateau_since do
              nil -> "n/a"
              ts -> "#{div(System.monotonic_time(:millisecond) - ts, 60_000)}m"
            end

          "  cold: #{short(t)} (plateau #{plateau})"

        _ ->
          nil
      end

    IO.puts(
      "[#{time}] targets=#{targets} examples=#{examples} corpus=#{corpus_size} seen=#{seen} failures=#{failures}"
    )

    if hot_line, do: IO.puts(hot_line)
    if cold_line, do: IO.puts(cold_line)
  end

  def failure(%Target{} = target, result, replay_cmd) do
    IO.puts("")
    IO.puts("FAILURE: #{target.id}")
    IO.puts("  seed: #{result.seed.stream_seed}  size: #{result.seed.size}")

    if result.seed.data do
      IO.puts("  data: #{inspect(result.seed.data, pretty: true, limit: 50)}")
    end

    if result.error do
      IO.puts("  error: #{Exception.format_banner(:error, result.error)}")
    end

    IO.puts("  replay: #{replay_cmd}")
    IO.puts("")
  end

  def failure_report(%Target{} = target, result, replay_cmd) do
    %{
      "target_id" => target.id,
      "module" => inspect(target.module),
      "property" => target.description,
      "stream_seed" => result.seed.stream_seed,
      "size" => result.seed.size,
      "data" => encode_data(result.seed.data),
      "error" => error_string(result.error),
      "replay" => replay_cmd,
      "features" => MapSet.size(result.novelty)
    }
  end

  def summary(nil, _coverage, _corpus, failures) do
    IO.puts("")
    IO.puts("=== StreamFuzz summary ===")
    IO.puts("  failures: #{length(failures)}")
    IO.puts("")
  end

  def summary(scheduler, coverage, corpus, failures) do
    IO.puts("")
    IO.puts("=== StreamFuzz summary ===")
    IO.puts("  targets:  #{length(scheduler.targets)}")
    IO.puts("  examples: #{Scheduler.total_examples(scheduler)}")
    IO.puts("  corpus:   #{StreamFuzz.Corpus.size(corpus)}")
    IO.puts("  seen:     #{StreamFuzz.Coverage.seen_count(coverage)}")
    IO.puts("  failures: #{length(failures)}")
    IO.puts("")
  end

  defp short(%Target{description: desc}), do: desc || "?"

  defp encode_data(nil), do: nil

  defp encode_data(data) do
    case Jason.encode(data) do
      {:ok, _} -> data
      _ -> Base.encode64(:erlang.term_to_binary(data))
    end
  rescue
    _ -> Base.encode64(:erlang.term_to_binary(data))
  end

  defp error_string(nil), do: nil
  defp error_string(e), do: Exception.message(e)
end
