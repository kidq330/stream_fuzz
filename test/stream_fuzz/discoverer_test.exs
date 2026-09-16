defmodule StreamFuzz.DiscovererTest do
  use ExUnit.Case, async: false

  alias StreamFuzz.Discoverer

  test "discovers property targets and honors stream_fuzz: false" do
    assert {:ok, targets} =
             Discoverer.discover(paths: ["test/stream_fuzz/toy_codec_properties_test.exs"])

    ids = Enum.map(targets, & &1.description)
    assert Enum.any?(ids, &String.contains?(&1, "roundtrip"))
    assert Enum.any?(ids, &String.contains?(&1, "slice_sum"))
    refute Enum.any?(ids, &String.contains?(&1, "opted out"))
  end

  test "only filter narrows targets" do
    assert {:ok, targets} =
             Discoverer.discover(
               paths: ["test/stream_fuzz/toy_codec_properties_test.exs"],
               only: "roundtrip"
             )

    assert length(targets) == 1
  end
end
