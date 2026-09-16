defmodule StreamFuzz.Executor do
  @moduledoc """
  Run a single property example under coverage measurement.
  """

  alias StreamFuzz.{Coverage, Seed, Target}

  @type outcome :: :ok | :interesting | :failure

  @type result :: %{
          outcome: outcome(),
          novelty: MapSet.t(),
          seed: Seed.t(),
          error: term() | nil,
          stacktrace: list() | nil,
          captured_data: term() | nil,
          target_score: number() | nil
        }

  @doc """
  Execute one example for `target` using the given seed parameters.
  """
  @spec run_one(Target.t(), Seed.t(), Coverage.t(), keyword()) :: {result(), Coverage.t()}
  def run_one(%Target{} = target, %Seed{} = seed, %Coverage{} = coverage, opts \\ []) do
    prev_best = Keyword.get(opts, :prev_target_best)

    # Drive stock ExUnitProperties.check all via Application env + ExUnit seed.
    previous_max_runs = Application.get_env(:stream_data, :max_runs)
    previous_initial_size = Application.get_env(:stream_data, :initial_size)
    previous_ex_seed = ExUnit.configuration()[:seed]

    Application.put_env(:stream_data, :max_runs, 1)
    Application.put_env(:stream_data, :initial_size, seed.size)
    ExUnit.configure(seed: seed.stream_seed)

    Process.put(:stream_fuzz_mode, true)
    Process.put(:stream_fuzz_seed, seed.stream_seed)
    Process.put(:stream_fuzz_size, seed.size)
    Process.put(:stream_fuzz_captured, nil)
    Process.put(:stream_fuzz_events, MapSet.new())
    Process.put(:stream_fuzz_target_scores, [])

    # Structured replay: if we have captured data and a registered runner, prefer it.
    fun = fn -> invoke_target(target, seed) end

    {raw, novelty, coverage} =
      Coverage.measure(coverage, fun, prev_target_best: prev_best)

    captured = Process.get(:stream_fuzz_captured)
    scores = Process.get(:stream_fuzz_target_scores, [])
    target_score = if scores != [], do: Enum.max(scores), else: nil

    Process.delete(:stream_fuzz_mode)
    Process.delete(:stream_fuzz_seed)
    Process.delete(:stream_fuzz_size)
    Process.delete(:stream_fuzz_captured)

    restore_env(:stream_data, :max_runs, previous_max_runs)
    restore_env(:stream_data, :initial_size, previous_initial_size)
    if previous_ex_seed, do: ExUnit.configure(seed: previous_ex_seed)

    {outcome, error, stacktrace} =
      case raw do
        {:ok, :ok} ->
          {:ok, nil, nil}

        {:ok, other} ->
          # Property functions usually return :ok; treat other as ok.
          if other == :ok or other == nil, do: {:ok, nil, nil}, else: {:ok, nil, nil}

        {:error, {exception, stacktrace}} ->
          {:failure, exception, stacktrace}

        {:error, exception} ->
          {:failure, exception, []}

        other ->
          # apply returned something unexpected but did not raise
          if match?(%{__exception__: true}, other) do
            {:failure, other, []}
          else
            {:ok, nil, nil}
          end
      end

    interesting? = MapSet.size(novelty) > 0

    outcome =
      cond do
        outcome == :failure -> :failure
        interesting? -> :interesting
        true -> :ok
      end

    reason =
      cond do
        outcome == :failure -> :failure
        interesting? and Enum.any?(novelty, &match?({:event, _}, &1)) -> :event
        interesting? and Enum.any?(novelty, &match?({:target, _}, &1)) -> :target
        interesting? -> :coverage
        true -> nil
      end

    out_seed = %{
      seed
      | data: captured || seed.data,
        features: novelty,
        interesting_reason: reason,
        saved_at: DateTime.utc_now()
    }

    result = %{
      outcome: outcome,
      novelty: novelty,
      seed: out_seed,
      error: error,
      stacktrace: stacktrace,
      captured_data: captured,
      target_score: target_score
    }

    {result, coverage}
  end

  defp invoke_target(%Target{runner: runner}, seed) when is_function(runner, 1) do
    try do
      {:ok,
       runner.(seed: seed, max_runs: 1, initial_size: seed.size, initial_seed: seed.stream_seed)}
    rescue
      e -> {:error, {e, __STACKTRACE__}}
    catch
      kind, reason -> {:error, {{kind, reason}, __STACKTRACE__}}
    end
  end

  defp invoke_target(%Target{module: module, name: name}, _seed) do
    context = build_context(module)

    try do
      {:ok, apply(module, name, [context])}
    rescue
      e -> {:error, {e, __STACKTRACE__}}
    catch
      kind, reason -> {:error, {{kind, reason}, __STACKTRACE__}}
    end
  end

  defp build_context(module) do
    base = %{
      module: module,
      file: "",
      line: 0,
      test: nil,
      async: false,
      registered: %{}
    }

    if function_exported?(module, :__ex_unit__, 2) do
      # Run setup callbacks when available (ExUnit 1.18+ keeps them on the module).
      try do
        case module.__ex_unit__(:setup, base) do
          {:ok, ctx} when is_map(ctx) -> Map.merge(base, ctx)
          ctx when is_map(ctx) -> Map.merge(base, ctx)
          _ -> base
        end
      rescue
        _ -> base
      catch
        _, _ -> base
      end
    else
      base
    end
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
