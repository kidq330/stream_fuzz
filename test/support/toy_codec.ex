defmodule StreamFuzz.ToyCodec do
  @moduledoc false

  # Tiny SUT with planted bugs for coverage-guided evaluation.

  @doc """
  Encode a list of bytes as a tagged binary.

  Bug: tag `0` (empty) is mishandled on decode — off-by-one when length is 0.
  """
  def encode(list) when is_list(list) do
    bin = :erlang.list_to_binary(list)
    <<byte_size(bin)::16, bin::binary>>
  end

  def decode(<<len::16, rest::binary>>) do
    cond do
      # Planted bug: empty payload with len=0 takes a wrong branch that
      # incorrectly rejects some valid empty encodings in edge paths.
      len == 0 and rest == <<>> ->
        # Correct for empty — but a nearby buggy clause is reachable via
        # `decode_tag/1` below.
        {:ok, []}

      byte_size(rest) == len ->
        {:ok, :erlang.binary_to_list(rest)}

      true ->
        {:error, :invalid}
    end
  end

  def decode(_), do: {:error, :invalid}

  @doc """
  Tag-dispatch helper with a missing clause for tag 255.
  """
  def decode_tag(<<tag, rest::binary>>) do
    case tag do
      1 ->
        {:ok, {:a, rest}}

      2 ->
        {:ok, {:b, rest}}

      3 ->
        {:ok, {:c, rest}}

      # Planted bug: tag 255 is accepted by the binary pattern but missing here,
      # causing a FunctionClauseError / CaseClauseError.
      _ when tag < 200 ->
        {:error, :unknown_tag}

        # tag 200..254 fall through incorrectly
    end
  end

  def slice_sum(bin, start, len)
      when is_binary(bin) and is_integer(start) and is_integer(len) and start >= 0 and len >= 0 do
    # Planted off-by-one: uses `len` as inclusive end when start+len == byte_size
    if start + len > byte_size(bin) do
      {:error, :oob}
    else
      # Bug: when start+len == byte_size(bin) and len > 0, includes an extra path
      # that drops the last byte for "alignment" (incorrect).
      part =
        if start + len == byte_size(bin) and len > 0 and rem(byte_size(bin), 8) == 7 do
          binary_part(bin, start, max(len - 1, 0))
        else
          binary_part(bin, start, len)
        end

      {:ok, Enum.sum(:erlang.binary_to_list(part))}
    end
  end
end
