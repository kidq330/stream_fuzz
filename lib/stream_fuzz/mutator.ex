defmodule StreamFuzz.Mutator do
  @moduledoc """
  Mutation operators for structured corpus seeds.

  When `data` is unavailable (opaque `check all`), mutation falls back to
  size nudge / reseed strategies.
  """

  alias StreamFuzz.Seed

  @doc """
  Produce a candidate seed from a corpus seed or fresh generation params.
  """
  @spec mutate(Seed.t(), keyword()) :: Seed.t()
  def mutate(%Seed{} = seed, opts \\ []) do
    rng_seed = Keyword.get_lazy(opts, :rng_seed, fn -> :erlang.unique_integer([:positive]) end)
    :rand.seed(:exsss, {rng_seed, rng_seed * 2 + 1, rng_seed * 3 + 2})

    cond do
      is_nil(seed.data) ->
        opaque_mutate(seed)

      true ->
        case :rand.uniform(5) do
          1 -> %{seed | data: type_aware_tweak(seed.data), interesting_reason: nil}
          2 -> %{seed | size: max(0, seed.size + :rand.uniform(5) - 2), interesting_reason: nil}
          3 -> %{seed | data: resample_sibling(seed.data), interesting_reason: nil}
          4 -> %{seed | stream_seed: :rand.uniform(1_000_000_000), interesting_reason: nil}
          5 -> opaque_mutate(seed)
        end
    end
  end

  @doc """
  Crossover two seeds that share a similar data shape.
  """
  @spec crossover(Seed.t(), Seed.t()) :: Seed.t()
  def crossover(%Seed{} = a, %Seed{} = b) do
    data =
      case {a.data, b.data} do
        {da, db} when is_list(da) and is_list(db) and da != [] and db != [] ->
          i = :rand.uniform(min(length(da), length(db))) - 1
          List.replace_at(da, i, Enum.at(db, i))

        {da, db}
        when is_tuple(da) and is_tuple(db) and tuple_size(da) == tuple_size(db) and
               tuple_size(da) > 0 ->
          i = :rand.uniform(tuple_size(da)) - 1
          da |> Tuple.to_list() |> List.replace_at(i, elem(db, i)) |> List.to_tuple()

        {da, db} when is_map(da) and is_map(db) ->
          keys = Map.keys(da) |> Enum.filter(&Map.has_key?(db, &1))

          case keys do
            [] ->
              da

            ks ->
              k = Enum.random(ks)
              Map.put(da, k, Map.get(db, k))
          end

        {da, _} ->
          da
      end

    %{a | data: data, interesting_reason: nil, features: MapSet.new()}
  end

  defp opaque_mutate(%Seed{} = seed) do
    case :rand.uniform(3) do
      1 ->
        %{
          seed
          | size: max(0, seed.size + :rand.uniform(7) - 3),
            data: nil,
            features: MapSet.new()
        }

      2 ->
        %{seed | stream_seed: :rand.uniform(1_000_000_000), data: nil, features: MapSet.new()}

      3 ->
        %{
          seed
          | size: max(0, seed.size),
            stream_seed: :rand.uniform(1_000_000_000),
            data: nil,
            features: MapSet.new()
        }
    end
  end

  defp type_aware_tweak(n) when is_integer(n), do: n + :rand.uniform(3) - 2
  defp type_aware_tweak(f) when is_float(f), do: f + (:rand.uniform() - 0.5)

  defp type_aware_tweak(bin) when is_binary(bin) and byte_size(bin) > 0 do
    case :rand.uniform(3) do
      1 ->
        i = :rand.uniform(byte_size(bin)) - 1
        <<prefix::binary-size(i), _byte, rest::binary>> = bin
        prefix <> <<:rand.uniform(256) - 1>> <> rest

      2 ->
        binary_part(bin, 0, max(0, byte_size(bin) - 1))

      3 ->
        bin <> <<:rand.uniform(256) - 1>>
    end
  end

  defp type_aware_tweak([]), do: []

  defp type_aware_tweak([_ | _] = list) do
    case :rand.uniform(3) do
      1 -> List.delete_at(list, :rand.uniform(length(list)) - 1)
      2 -> list ++ [Enum.random(list)]
      _ -> List.update_at(list, :rand.uniform(length(list)) - 1, &type_aware_tweak/1)
    end
  end

  defp type_aware_tweak(tuple) when is_tuple(tuple) and tuple_size(tuple) > 0 do
    i = :rand.uniform(tuple_size(tuple)) - 1
    tuple |> Tuple.to_list() |> List.update_at(i, &type_aware_tweak/1) |> List.to_tuple()
  end

  defp type_aware_tweak(%{} = map) when map_size(map) > 0 do
    {k, v} = Enum.random(map)
    Map.put(map, k, type_aware_tweak(v))
  end

  defp type_aware_tweak(other), do: other

  defp resample_sibling(data) when is_list(data) and data != [] do
    List.replace_at(data, :rand.uniform(length(data)) - 1, Enum.random(data))
  end

  defp resample_sibling(data) when is_tuple(data) and tuple_size(data) > 1 do
    list = Tuple.to_list(data)
    i = :rand.uniform(length(list)) - 1
    j = :rand.uniform(length(list)) - 1
    list |> List.replace_at(i, Enum.at(list, j)) |> List.to_tuple()
  end

  defp resample_sibling(data), do: type_aware_tweak(data)
end
