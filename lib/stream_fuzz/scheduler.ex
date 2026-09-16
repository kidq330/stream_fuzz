defmodule StreamFuzz.Scheduler do
  @moduledoc """
  Progress-weighted bandit scheduler over fuzz targets.
  """

  alias StreamFuzz.{Corpus, Mutator, Seed, Target}

  defstruct [
    :targets,
    :stats,
    p_fresh: 0.2,
    p_mutate: 0.7,
    plateau_ms: 60_000,
    epsilon: 0.05
  ]

  @type stats :: %{
          examples_run: non_neg_integer(),
          failures: non_neg_integer(),
          last_novelty_at: integer() | nil,
          novelty_ema: float(),
          plateau_since: integer() | nil,
          target_best: number() | nil
        }

  @type t :: %__MODULE__{
          targets: [Target.t()],
          stats: %{optional(String.t()) => stats()},
          p_fresh: float(),
          p_mutate: float(),
          plateau_ms: non_neg_integer(),
          epsilon: float()
        }

  @type work_unit :: %{
          target: Target.t(),
          mode: :fresh | :mutate | :replay,
          seed: Seed.t() | nil
        }

  @doc """
  Build a scheduler for the given targets.
  """
  @spec new([Target.t()], keyword()) :: t()
  def new(targets, opts \\ []) when is_list(targets) do
    now = now_ms()

    stats =
      Map.new(targets, fn %Target{id: id} ->
        {id,
         %{
           examples_run: 0,
           failures: 0,
           last_novelty_at: now,
           novelty_ema: 1.0,
           plateau_since: nil,
           target_best: nil
         }}
      end)

    %__MODULE__{
      targets: targets,
      stats: stats,
      p_fresh: Keyword.get(opts, :p_fresh, 0.2),
      p_mutate: Keyword.get(opts, :p_mutate, 0.7),
      plateau_ms: Keyword.get(opts, :plateau_ms, 60_000),
      epsilon: Keyword.get(opts, :epsilon, 0.05)
    }
  end

  @doc """
  Pick the next work unit.
  """
  @spec next(t(), Corpus.t()) :: {work_unit(), t()}
  def next(%__MODULE__{targets: []}, _corpus) do
    raise ArgumentError, "no targets to schedule"
  end

  def next(%__MODULE__{} = sched, %Corpus{} = corpus) do
    now = now_ms()
    sched = update_plateaus(sched, now)

    {target, sched} =
      if :rand.uniform() < sched.p_fresh do
        {pick_random_non_plateaued(sched), sched}
      else
        pick_weighted(sched)
      end

    seeds = Corpus.seeds_for(corpus, target.id)

    {mode, seed} =
      cond do
        seeds != [] and :rand.uniform() < sched.p_mutate ->
          base = Enum.random(seeds)

          if length(seeds) > 1 and :rand.uniform() < 0.15 do
            other = Enum.random(seeds)
            {:mutate, Mutator.crossover(base, other)}
          else
            {:mutate, Mutator.mutate(base)}
          end

        true ->
          fresh = %Seed{
            target_id: target.id,
            data: nil,
            stream_seed: :rand.uniform(1_000_000_000),
            size: :rand.uniform(20),
            features: MapSet.new(),
            interesting_reason: nil,
            saved_at: nil,
            run_index: 0
          }

          {:fresh, fresh}
      end

    {%{target: target, mode: mode, seed: seed}, sched}
  end

  @doc """
  Record the outcome of a work unit.
  """
  @spec record(t(), Target.t(), keyword()) :: t()
  def record(%__MODULE__{} = sched, %Target{id: id}, opts) do
    now = now_ms()
    novelty? = Keyword.get(opts, :novelty?, false)
    failure? = Keyword.get(opts, :failure?, false)
    target_score = Keyword.get(opts, :target_score)

    stats =
      Map.update!(sched.stats, id, fn s ->
        novelty_ema =
          if novelty? do
            0.3 * 1.0 + 0.7 * s.novelty_ema
          else
            0.7 * s.novelty_ema
          end

        s
        |> Map.update!(:examples_run, &(&1 + 1))
        |> Map.update!(:failures, fn f -> if(failure?, do: f + 1, else: f) end)
        |> Map.put(:novelty_ema, novelty_ema)
        |> then(fn s ->
          if novelty? do
            %{s | last_novelty_at: now, plateau_since: nil}
          else
            s
          end
        end)
        |> then(fn s ->
          cond do
            is_number(target_score) and (is_nil(s.target_best) or target_score > s.target_best) ->
              %{s | target_best: target_score}

            true ->
              s
          end
        end)
      end)

    %{sched | stats: stats}
  end

  @doc false
  def total_examples(%__MODULE__{stats: stats}) do
    stats |> Map.values() |> Enum.map(& &1.examples_run) |> Enum.sum()
  end

  @doc false
  def total_failures(%__MODULE__{stats: stats}) do
    stats |> Map.values() |> Enum.map(& &1.failures) |> Enum.sum()
  end

  @doc false
  def hot_cold(%__MODULE__{} = sched, n \\ 3) do
    ranked =
      sched.targets
      |> Enum.map(fn t -> {t, Map.fetch!(sched.stats, t.id)} end)
      |> Enum.sort_by(fn {_t, s} -> -s.novelty_ema end)

    hot = ranked |> Enum.take(n) |> Enum.map(&elem(&1, 0))

    cold =
      ranked
      |> Enum.filter(fn {_t, s} -> not is_nil(s.plateau_since) end)
      |> Enum.take(-n)
      |> Enum.map(&elem(&1, 0))

    {hot, cold}
  end

  defp update_plateaus(%__MODULE__{} = sched, now) do
    stats =
      Map.new(sched.stats, fn {id, s} ->
        plateau_since =
          cond do
            is_nil(s.last_novelty_at) ->
              s.plateau_since || now

            now - s.last_novelty_at >= sched.plateau_ms ->
              s.plateau_since || s.last_novelty_at

            true ->
              nil
          end

        {id, %{s | plateau_since: plateau_since}}
      end)

    %{sched | stats: stats}
  end

  defp pick_random_non_plateaued(%__MODULE__{targets: targets, stats: stats}) do
    candidates =
      Enum.filter(targets, fn t ->
        is_nil(Map.fetch!(stats, t.id).plateau_since)
      end)

    case candidates do
      [] -> Enum.random(targets)
      list -> Enum.random(list)
    end
  end

  defp pick_weighted(%__MODULE__{} = sched) do
    weights =
      Enum.map(sched.targets, fn t ->
        s = Map.fetch!(sched.stats, t.id)
        base = max(s.novelty_ema, sched.epsilon)
        weight = if s.plateau_since, do: base * 0.1, else: base
        {t, weight}
      end)

    total = Enum.reduce(weights, 0.0, fn {_t, w}, acc -> acc + w end)
    pick = :rand.uniform() * total

    {chosen, _} =
      Enum.reduce_while(weights, {nil, 0.0}, fn {t, w}, {_cur, acc} ->
        acc = acc + w
        if pick <= acc, do: {:halt, {t, acc}}, else: {:cont, {t, acc}}
      end)

    {chosen || hd(sched.targets), sched}
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
