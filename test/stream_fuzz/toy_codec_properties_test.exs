defmodule StreamFuzz.ToyCodecPropertiesTest do
  use ExUnit.Case, async: false
  use ExUnitProperties
  require StreamFuzz

  alias StreamFuzz.ToyCodec

  property "encode/decode roundtrip" do
    check all list <- list_of(integer(0..255), max_length: 64) do
      assert ToyCodec.decode(ToyCodec.encode(list)) == {:ok, list}
    end
  end

  property "decode_tag known tags" do
    check all tag <- member_of([1, 2, 3]),
              rest <- binary(max_length: 16) do
      assert {:ok, _} = ToyCodec.decode_tag(<<tag, rest::binary>>)
    end
  end

  # Uses StreamFuzz.check for binding capture + event guidance.
  property "slice_sum within bounds" do
    StreamFuzz.check all bin <- binary(min_length: 1, max_length: 32),
                         start <- integer(0..byte_size(bin)),
                         max_len = byte_size(bin) - start,
                         len <- integer(0..max_len) do
      StreamFuzz.target(byte_size(bin))

      assert {:ok, sum} = ToyCodec.slice_sum(bin, start, len)
      assert sum >= 0
    end
  end

  @tag stream_fuzz: false
  property "opted out of fuzzing" do
    check all x <- integer() do
      assert is_integer(x)
    end
  end
end
