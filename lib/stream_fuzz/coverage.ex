defmodule StreamFuzz.Coverage do
  @moduledoc """
  OTP `:cover` line-coverage novelty signal.

  Coverage is process-global on the BEAM. The campaign runs examples
  sequentially (or serializes through this module) so deltas are trustworthy.
  """

  @type line_id :: {:line, module(), pos_integer()}
  @type feature :: line_id() | {:event, term()} | {:target, number()}

  defstruct seen: MapSet.new(), modules: [], started?: false

  @type t :: %__MODULE__{
          seen: MapSet.t(feature()),
          modules: [module()],
          started?: boolean()
        }

  @doc """
  Start cover and compile beams for the given applications.
  """
  @spec start([atom()]) :: {:ok, t()} | {:error, term()}
  def start(apps) when is_list(apps) do
    case ensure_cover_started() do
      :ok ->
        modules =
          apps
          |> Enum.flat_map(&app_modules/1)
          |> Enum.uniq()
          |> Enum.filter(&cover_compile_module/1)

        {:ok, %__MODULE__{modules: modules, started?: true, seen: MapSet.new()}}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Start cover without compiling any apps (useful for event-only novelty).
  """
  @spec start_empty() :: {:ok, t()}
  def start_empty do
    _ = ensure_cover_started()
    {:ok, %__MODULE__{modules: [], started?: true, seen: MapSet.new()}}
  end

  @doc """
  Reset counters, run `fun`, and return `{result, new_features, updated_state}`.
  """
  @spec measure(t(), (-> result), keyword()) :: {result, MapSet.t(feature()), t()}
        when result: term()
  def measure(%__MODULE__{} = state, fun, opts \\ []) when is_function(fun, 0) do
    events_before = Process.get(:stream_fuzz_events, MapSet.new())
    targets_before = Process.get(:stream_fuzz_target_scores, [])

    Process.put(:stream_fuzz_events, MapSet.new())
    Process.put(:stream_fuzz_target_scores, [])

    if state.modules != [] do
      Enum.each(state.modules, fn mod ->
        try do
          :cover.reset(mod)
        rescue
          _ -> :ok
        end
      end)
    end

    result =
      try do
        fun.()
      after
        :ok
      end

    line_hits = collect_line_hits(state.modules)
    events = Process.get(:stream_fuzz_events, MapSet.new())
    scores = Process.get(:stream_fuzz_target_scores, [])

    event_features = MapSet.new(Enum.map(events, &{:event, &1}))
    target_features = target_novelty(scores, opts)

    hits = MapSet.union(line_hits, MapSet.union(event_features, target_features))
    new_features = MapSet.difference(hits, state.seen)
    new_state = %{state | seen: MapSet.union(state.seen, hits)}

    # Restore any outer event context (should be empty in campaign).
    Process.put(:stream_fuzz_events, events_before)
    Process.put(:stream_fuzz_target_scores, targets_before)

    {result, new_features, new_state}
  end

  @doc false
  def seen_count(%__MODULE__{seen: seen}), do: MapSet.size(seen)

  @doc false
  def export_summary(%__MODULE__{} = state, dir) do
    File.mkdir_p!(dir)
    path = Path.join(dir, "cover_summary.json")

    summary = %{
      "modules" => Enum.map(state.modules, &Atom.to_string/1),
      "seen_features" => MapSet.size(state.seen),
      "seen_lines" =>
        state.seen
        |> Enum.count(fn
          {:line, _, _} -> true
          _ -> false
        end)
    }

    File.write!(path, Jason.encode!(summary, pretty: true))
    path
  end

  defp ensure_cover_started do
    case :cover.start() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp app_modules(app) when is_atom(app) do
    case :application.get_key(app, :modules) do
      {:ok, modules} -> modules
      :undefined -> []
    end
  end

  defp cover_compile_module(module) do
    case :cover.is_compiled(module) do
      {:file, _} ->
        true

      false ->
        case :code.which(module) do
          path when is_list(path) ->
            case :cover.compile_beam(path) do
              {:ok, _} -> true
              _ -> false
            end

          _ ->
            false
        end
    end
  rescue
    _ -> false
  end

  defp collect_line_hits(modules) do
    Enum.reduce(modules, MapSet.new(), fn mod, acc ->
      case :cover.analyse(mod, :coverage, :line) do
        {:ok, {^mod, lines}} ->
          Enum.reduce(lines, acc, fn
            {{_mod, line}, {hits, _misses}}, acc
            when hits > 0 and is_integer(line) and line > 0 ->
              MapSet.put(acc, {:line, mod, line})

            {{line, _}, {hits, _}}, acc when hits > 0 and is_integer(line) and line > 0 ->
              MapSet.put(acc, {:line, mod, line})

            _, acc ->
              acc
          end)

        {:ok, lines} when is_list(lines) ->
          Enum.reduce(lines, acc, fn
            {{line, _}, {hits, _}}, acc when hits > 0 and is_integer(line) and line > 0 ->
              MapSet.put(acc, {:line, mod, line})

            {{_m, line}, {hits, _}}, acc when hits > 0 and is_integer(line) and line > 0 ->
              MapSet.put(acc, {:line, mod, line})

            _, acc ->
              acc
          end)

        _ ->
          acc
      end
    end)
  end

  defp target_novelty([], _opts), do: MapSet.new()

  defp target_novelty(scores, opts) do
    # Treat a new max score as novelty (IJON-style guidance).
    best = Enum.max(scores)
    prev_best = Keyword.get(opts, :prev_target_best, nil)

    if is_nil(prev_best) or best > prev_best do
      MapSet.new([{:target, best}])
    else
      MapSet.new()
    end
  end
end
