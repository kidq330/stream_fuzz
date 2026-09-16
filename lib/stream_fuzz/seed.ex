defmodule StreamFuzz.Seed do
  @moduledoc """
  A retained example that uncovered novelty (coverage, events, or failure).
  """

  @enforce_keys [:target_id, :stream_seed, :size]
  defstruct [
    :target_id,
    :data,
    :stream_seed,
    :size,
    :features,
    :interesting_reason,
    :saved_at,
    :run_index
  ]

  @type feature :: {:line, module(), pos_integer()} | {:event, term()} | {:target, number()}

  @type t :: %__MODULE__{
          target_id: String.t(),
          data: term() | nil,
          stream_seed: integer(),
          size: non_neg_integer(),
          features: MapSet.t(feature()),
          interesting_reason: :coverage | :event | :target | :failure | nil,
          saved_at: DateTime.t() | nil,
          run_index: non_neg_integer() | nil
        }

  @doc false
  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)

    struct!(
      __MODULE__,
      Map.merge(
        %{
          data: nil,
          features: MapSet.new(),
          interesting_reason: nil,
          saved_at: DateTime.utc_now(),
          run_index: 0
        },
        attrs
      )
    )
  end

  @doc """
  Encode a seed for JSONL persistence.

  Terms that are not Jason-safe are stored as base64 Erlang external format
  under `"data_etf"`.
  """
  def to_map(%__MODULE__{} = seed) do
    {data_field, data_value} = encode_data(seed.data)

    %{
      "target_id" => seed.target_id,
      "stream_seed" => seed.stream_seed,
      "size" => seed.size,
      "run_index" => seed.run_index || 0,
      "interesting_reason" => seed.interesting_reason && Atom.to_string(seed.interesting_reason),
      "saved_at" => seed.saved_at && DateTime.to_iso8601(seed.saved_at),
      "features" => Enum.map(MapSet.to_list(seed.features || MapSet.new()), &encode_feature/1)
    }
    |> Map.put(data_field, data_value)
  end

  @doc """
  Decode a seed from a persisted map.
  """
  def from_map(map) when is_map(map) do
    data =
      cond do
        Map.has_key?(map, "data_etf") ->
          map["data_etf"] |> Base.decode64!() |> :erlang.binary_to_term([:safe])

        Map.has_key?(map, "data") ->
          map["data"]

        true ->
          nil
      end

    features =
      (map["features"] || [])
      |> Enum.map(&decode_feature/1)
      |> MapSet.new()

    reason =
      case map["interesting_reason"] do
        nil -> nil
        s when is_binary(s) -> String.to_existing_atom(s)
      end

    saved_at =
      case map["saved_at"] do
        nil ->
          nil

        iso ->
          case DateTime.from_iso8601(iso) do
            {:ok, dt, _} -> dt
            _ -> nil
          end
      end

    new(%{
      target_id: map["target_id"],
      data: data,
      stream_seed: map["stream_seed"],
      size: map["size"],
      run_index: map["run_index"] || 0,
      features: features,
      interesting_reason: reason,
      saved_at: saved_at
    })
  end

  defp encode_data(nil), do: {"data", nil}

  defp encode_data(data) do
    # Always use ETF so atoms, tuples, and non-JSON terms round-trip exactly.
    {"data_etf", data |> :erlang.term_to_binary() |> Base.encode64()}
  end

  defp encode_feature({:line, mod, line}), do: ["line", Atom.to_string(mod), line]
  defp encode_feature({:event, name}), do: ["event", encode_event_name(name)]
  defp encode_feature({:target, score}), do: ["target", score]

  defp decode_feature(["line", mod, line]) when is_binary(mod),
    do: {:line, String.to_atom(mod), line}

  defp decode_feature(["event", name]), do: {:event, decode_event_name(name)}
  defp decode_feature(["target", score]), do: {:target, score}

  defp encode_event_name(name) when is_atom(name), do: ["atom", Atom.to_string(name)]
  defp encode_event_name(name) when is_binary(name), do: ["binary", name]
  defp encode_event_name(name), do: ["etf", name |> :erlang.term_to_binary() |> Base.encode64()]

  defp decode_event_name(["atom", s]), do: String.to_atom(s)
  defp decode_event_name(["binary", s]), do: s
  defp decode_event_name(["etf", s]), do: s |> Base.decode64!() |> :erlang.binary_to_term([:safe])
  defp decode_event_name(name) when is_binary(name), do: String.to_atom(name)

  @doc false
  def simpler?(%__MODULE__{} = a, %__MODULE__{} = b) do
    size_a = term_complexity(a.data) + a.size
    size_b = term_complexity(b.data) + b.size
    size_a <= size_b
  end

  defp term_complexity(nil), do: 0
  defp term_complexity(term) when is_binary(term), do: byte_size(term)

  defp term_complexity(term) when is_list(term),
    do: length(term) + Enum.sum(Enum.map(term, &term_complexity/1))

  defp term_complexity(term) when is_tuple(term), do: term_complexity(Tuple.to_list(term))
  defp term_complexity(term) when is_map(term), do: term_complexity(Map.to_list(term))
  defp term_complexity(_), do: 1
end
