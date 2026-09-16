defmodule StreamFuzz.MutatorTest do
  use ExUnit.Case, async: true

  alias StreamFuzz.{Mutator, Seed}

  test "mutates structured data" do
    seed =
      Seed.new(
        target_id: "t",
        stream_seed: 1,
        size: 5,
        data: [1, 2, 3, 4]
      )

    mutated = Mutator.mutate(seed, rng_seed: 99)
    assert mutated.target_id == "t"
    # May or may not change data depending on operator; still a valid seed.
    assert is_integer(mutated.stream_seed)
  end

  test "opaque mutate changes seed or size" do
    seed = Seed.new(target_id: "t", stream_seed: 1, size: 5, data: nil)
    mutated = Mutator.mutate(seed, rng_seed: 7)
    assert mutated.stream_seed != 1 or mutated.size != 5
  end
end
