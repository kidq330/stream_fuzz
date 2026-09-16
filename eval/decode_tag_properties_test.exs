defmodule StreamFuzz.Eval.DecodeTag do
  @moduledoc false
  # Planted-bug harness loaded only via `mix stream_fuzz eval/...`.

  use ExUnit.Case, async: false
  use ExUnitProperties

  alias StreamFuzz.ToyCodec

  property "decode_tag accepts or rejects every tag" do
    check all tag <- integer(0..255),
              rest <- binary(max_length: 8) do
      case ToyCodec.decode_tag(<<tag, rest::binary>>) do
        {:ok, _} -> true
        {:error, _} -> true
      end
    end
  end
end
