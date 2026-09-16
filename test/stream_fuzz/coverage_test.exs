defmodule StreamFuzz.CoverageTest do
  use ExUnit.Case, async: false

  alias StreamFuzz.Coverage

  test "measures new line features across examples" do
    {:ok, state} = Coverage.start([:stream_fuzz])

    {_, novelty1, state} =
      Coverage.measure(state, fn ->
        StreamFuzz.ToyCodec.encode([1, 2, 3])
      end)

    assert MapSet.size(novelty1) > 0

    {_, novelty2, state} =
      Coverage.measure(state, fn ->
        StreamFuzz.ToyCodec.encode([1, 2, 3])
      end)

    # Same path — no new lines expected (events empty).
    line_novelty = Enum.filter(novelty2, &match?({:line, _, _}, &1))
    assert line_novelty == []

    {_, novelty3, _state} =
      Coverage.measure(state, fn ->
        StreamFuzz.ToyCodec.decode(<<0::16>>)
      end)

    assert MapSet.size(novelty3) > 0
  end

  test "event/1 contributes novelty" do
    {:ok, state} = Coverage.start_empty()
    Process.put(:stream_fuzz_mode, true)

    {_, novelty, _} =
      Coverage.measure(state, fn ->
        StreamFuzz.event(:hello)
        :ok
      end)

    Process.delete(:stream_fuzz_mode)
    assert MapSet.member?(novelty, {:event, :hello})
  end
end
