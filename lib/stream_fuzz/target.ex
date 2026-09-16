defmodule StreamFuzz.Target do
  @moduledoc """
  A fuzzable property discovered from an ExUnit test module.
  """

  @enforce_keys [:id, :module, :name]
  defstruct [
    :id,
    :module,
    :name,
    :description,
    :file,
    :line,
    :tags,
    :runner
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          module: module(),
          name: atom(),
          description: String.t() | nil,
          file: String.t() | nil,
          line: pos_integer() | nil,
          tags: map(),
          runner: (keyword() -> :ok | {:error, term()}) | nil
        }

  @doc false
  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)
    module = Map.fetch!(attrs, :module)
    name = Map.fetch!(attrs, :name)
    description = Map.get(attrs, :description) || humanize_name(name)

    id =
      Map.get(attrs, :id) ||
        "#{inspect(module)}|#{description}"

    struct!(
      __MODULE__,
      Map.merge(
        %{
          id: id,
          description: description,
          file: nil,
          line: nil,
          tags: %{},
          runner: nil
        },
        attrs
      )
    )
  end

  @doc false
  def hash_id(%__MODULE__{id: id}), do: hash_id(id)

  def hash_id(id) when is_binary(id) do
    :crypto.hash(:sha256, id) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  defp humanize_name(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace(~r/^test /, "")
    |> String.trim()
  end
end
