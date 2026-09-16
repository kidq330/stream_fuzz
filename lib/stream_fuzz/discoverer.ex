defmodule StreamFuzz.Discoverer do
  @moduledoc """
  Discover ExUnit `:property` tests eligible for fuzzing.
  """

  alias StreamFuzz.Target

  @doc """
  Load test helper + test files and return fuzz targets.

  Options:
    * `:paths` — files or directories (default `["test"]`)
    * `:only` — substring filter on property description
    * `:exclude_tagged_false` — honor `@tag stream_fuzz: false` (default `true`)
  """
  @spec discover(keyword()) :: {:ok, [Target.t()]} | {:error, term()}
  def discover(opts \\ []) do
    paths = Keyword.get(opts, :paths, ["test"])
    only = Keyword.get(opts, :only)
    honor_opt_out = Keyword.get(opts, :exclude_tagged_false, true)

    with :ok <- ensure_ex_unit(),
         {:ok, modules} <- load_tests(paths) do
      targets =
        modules
        |> Enum.flat_map(&targets_from_module/1)
        |> Enum.filter(&eligible?(&1, honor_opt_out))
        |> maybe_filter_only(only)

      case targets do
        [] -> {:error, :no_targets}
        list -> {:ok, list}
      end
    end
  end

  @doc false
  def targets_from_module(module) when is_atom(module) do
    if function_exported?(module, :__ex_unit__, 0) do
      %{tests: tests} = module.__ex_unit__()

      tests
      |> Enum.filter(fn test ->
        tags = test.tags
        Map.get(tags, :property) == true or Map.get(tags, :test_type) == :property
      end)
      |> Enum.map(fn test ->
        Target.new(%{
          module: module,
          name: test.name,
          description: test_description(test),
          file: test.tags[:file],
          line: test.tags[:line],
          tags: test.tags
        })
      end)
    else
      []
    end
  end

  defp eligible?(%Target{tags: tags}, true) do
    Map.get(tags, :stream_fuzz, true) != false
  end

  defp eligible?(_target, false), do: true

  defp maybe_filter_only(targets, nil), do: targets

  defp maybe_filter_only(targets, only) when is_binary(only) do
    Enum.filter(targets, fn t ->
      String.contains?(t.description || "", only) or String.contains?(t.id, only)
    end)
  end

  defp test_description(%{name: name, tags: tags}) do
    cond do
      is_binary(tags[:describe]) and is_binary(tags[:tested]) ->
        "#{tags[:describe]} #{tags[:tested]}"

      is_binary(tags[:tested]) ->
        tags[:tested]

      true ->
        name
        |> Atom.to_string()
        |> String.replace_prefix("test ", "")
    end
  end

  defp ensure_ex_unit do
    Application.ensure_all_started(:ex_unit)

    unless ExUnit.configuration()[:autorun] == false do
      ExUnit.configure(autorun: false)
    end

    :ok
  rescue
    e -> {:error, e}
  end

  defp load_tests(paths) do
    helper = "test/test_helper.exs"

    if File.exists?(helper) do
      Code.require_file(helper)
    end

    files =
      paths
      |> Enum.flat_map(fn path ->
        cond do
          File.dir?(path) ->
            Path.wildcard(Path.join(path, "**/*_test.exs"))

          File.regular?(path) ->
            [path]

          true ->
            Path.wildcard(path)
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    modules_before = MapSet.new(:code.all_loaded() |> Enum.map(&elem(&1, 0)))

    Enum.each(files, fn file ->
      Code.require_file(file)
    end)

    modules_after = :code.all_loaded() |> Enum.map(&elem(&1, 0)) |> MapSet.new()
    new_modules = MapSet.difference(modules_after, modules_before) |> MapSet.to_list()

    # Also include any module that defines __ex_unit__/0 under Elixir.
    ex_unit_modules =
      :code.all_loaded()
      |> Enum.map(&elem(&1, 0))
      |> Enum.filter(fn mod ->
        function_exported?(mod, :__ex_unit__, 0)
      end)

    {:ok, Enum.uniq(new_modules ++ ex_unit_modules)}
  rescue
    e -> {:error, e}
  end
end
