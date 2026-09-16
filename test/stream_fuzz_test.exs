defmodule StreamFuzzTest do
  use ExUnit.Case

  test "event/1 and target/1 are no-ops outside fuzz mode" do
    assert :ok = StreamFuzz.event(:x)
    assert :ok = StreamFuzz.target(1)
  end

  test "Seed round-trips through map encoding" do
    seed =
      StreamFuzz.Seed.new(
        target_id: "M|p",
        stream_seed: 9,
        size: 2,
        data: %{a: 1, b: "x"},
        features: MapSet.new([{:line, StreamFuzz, 10}]),
        interesting_reason: :coverage
      )

    round_tripped = seed |> StreamFuzz.Seed.to_map() |> StreamFuzz.Seed.from_map()
    assert round_tripped.target_id == seed.target_id
    assert round_tripped.stream_seed == seed.stream_seed
    assert round_tripped.size == seed.size
    assert round_tripped.data == seed.data
    assert round_tripped.features == seed.features
    assert round_tripped.interesting_reason == seed.interesting_reason
  end
end
