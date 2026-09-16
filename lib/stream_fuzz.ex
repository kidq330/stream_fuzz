defmodule StreamFuzz do
  @moduledoc """
  Coverage-guided fuzzing for StreamData / ExUnitProperties.

  ## Usage

  Keep writing properties as usual with `ExUnitProperties`, then run:

      mix stream_fuzz --duration 30m --cover-app my_app

  For better mutation quality, use `StreamFuzz.check all` (records bindings):

      import StreamFuzz

      property "add is commutative" do
        StreamFuzz.check all x <- integer(), y <- integer() do
          assert MyApp.add(x, y) == MyApp.add(y, x)
        end
      end

  Optional guidance:

      StreamFuzz.event(:empty_input)
      StreamFuzz.target(byte_size(bin))

  See `DESIGN-hypofuzz-stream-data.md` for architecture and goals.
  """

  @doc """
  Import StreamFuzz helpers and StreamData generators.
  """
  defmacro __using__(_opts) do
    quote do
      require StreamFuzz
      import StreamFuzz
      import StreamData
      import ExUnit.Assertions
    end
  end

  @doc """
  Record a named virtual branch / event (HypoFuzz-style).

  No-op unless a StreamFuzz campaign is running.
  """
  @spec event(term()) :: :ok
  def event(name) do
    if Process.get(:stream_fuzz_mode) do
      events = Process.get(:stream_fuzz_events, MapSet.new())
      Process.put(:stream_fuzz_events, MapSet.put(events, name))
    end

    :ok
  end

  @doc """
  Prefer examples that maximize `score` when coverage plateaus (IJON-style).
  """
  @spec target(number()) :: :ok
  def target(score) when is_number(score) do
    if Process.get(:stream_fuzz_mode) do
      scores = Process.get(:stream_fuzz_target_scores, [])
      Process.put(:stream_fuzz_target_scores, [score | scores])
    end

    :ok
  end

  @doc """
  Drop-in replacement for `ExUnitProperties.check all` that records bindings
  under StreamFuzz and otherwise behaves like stock StreamData.
  """
  defmacro check({:all, _meta, clauses_with_body}) when is_list(clauses_with_body) do
    {clauses, [body_with_options]} = Enum.split(clauses_with_body, -1)
    {options, [do: body]} = Enum.split(body_with_options, -1)
    compile_check_all(clauses ++ [options], body)
  end

  @doc false
  defmacro check({:all, _meta, clauses_and_options}, do: body)
           when is_list(clauses_and_options) do
    compile_check_all(clauses_and_options, body)
  end

  defp compile_check_all(clauses_and_options, body) do
    {clauses, options} = split_clauses_and_options(clauses_and_options)

    quote do
      require ExUnitProperties

      options = unquote(options)

      initial_seed =
        cond do
          seed = Process.get(:stream_fuzz_seed) ->
            {0, 0, seed}

          true ->
            case Keyword.get(options, :initial_seed, ExUnit.configuration()[:seed]) do
              seed when is_integer(seed) ->
                {0, 0, seed}

              other ->
                raise ArgumentError,
                      "expected :initial_seed to be an integer, got: #{inspect(other)}"
            end
        end

      max_runs =
        cond do
          Process.get(:stream_fuzz_mode) -> 1
          true -> options[:max_runs] || Application.fetch_env!(:stream_data, :max_runs)
        end

      initial_size =
        cond do
          size = Process.get(:stream_fuzz_size) ->
            size

          true ->
            options[:initial_size] || Application.fetch_env!(:stream_data, :initial_size)
        end

      check_options = [
        initial_seed: initial_seed,
        initial_size: initial_size,
        max_runs: max_runs,
        max_run_time:
          options[:max_run_time] || Application.fetch_env!(:stream_data, :max_run_time),
        max_shrinking_steps:
          options[:max_shrinking_steps] ||
            Application.fetch_env!(:stream_data, :max_shrinking_steps)
      ]

      property =
        ExUnitProperties.gen all unquote_splicing(clauses) do
          fn ->
            if Process.get(:stream_fuzz_mode) do
              values =
                Enum.map(var!(generated_values, ExUnitProperties), fn {_clause, value} ->
                  value
                end)

              Process.put(:stream_fuzz_captured, values)
            end

            try do
              unquote(body)
            rescue
              exception ->
                result = %{
                  exception: exception,
                  stacktrace: __STACKTRACE__,
                  generated_values: var!(generated_values, ExUnitProperties)
                }

                {:error, result}
            else
              _result ->
                {:ok, nil}
            end
          end
        end

      property =
        if max_size = options[:max_generation_size] do
          StreamData.scale(property, &min(max_size, &1))
        else
          property
        end

      case StreamData.check_all(property, check_options, & &1.()) do
        {:ok, _result} -> :ok
        {:error, test_result} -> ExUnitProperties.__raise__(test_result)
      end
    end
  end

  defp split_clauses_and_options(clauses_and_options) do
    case Enum.split_while(clauses_and_options, &(not Keyword.keyword?(&1))) do
      {_clauses, []} = result -> result
      {clauses, [options]} -> {clauses, options}
    end
  end
end
