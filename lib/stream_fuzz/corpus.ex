defmodule StreamFuzz.Corpus do
  @moduledoc """
  Per-target distilled seed corpus persisted as JSONL under a corpus directory.
  """

  alias StreamFuzz.{Seed, Target}

  defstruct root: nil, by_target: %{}, max_seed_bytes: 1_048_576

  @type t :: %__MODULE__{
          root: String.t(),
          by_target: %{optional(String.t()) => [Seed.t()]},
          max_seed_bytes: pos_integer()
        }

  @doc """
  Open (or create) a corpus directory and load existing seeds.
  """
  @spec open(String.t(), keyword()) :: t()
  def open(root, opts \\ []) do
    File.mkdir_p!(root)
    File.mkdir_p!(Path.join(Path.dirname(Path.expand(root)), "failures"))

    corpus = %__MODULE__{
      root: root,
      by_target: %{},
      max_seed_bytes: Keyword.get(opts, :max_seed_bytes, 1_048_576)
    }

    load_all(corpus)
  end

  @doc """
  Seeds for a target id.
  """
  @spec seeds_for(t(), String.t()) :: [Seed.t()]
  def seeds_for(%__MODULE__{by_target: by_target}, target_id) do
    Map.get(by_target, target_id, [])
  end

  @doc """
  Insert a seed if interesting and within size limits; distill dominated seeds.
  """
  @spec put(t(), Seed.t()) :: t()
  def put(%__MODULE__{} = corpus, %Seed{} = seed) do
    if oversized?(corpus, seed) do
      corpus
    else
      list = [seed | seeds_for(corpus, seed.target_id)]
      distilled = distill(list)
      by_target = Map.put(corpus.by_target, seed.target_id, distilled)
      corpus = %{corpus | by_target: by_target}
      persist_target(corpus, seed.target_id)
      corpus
    end
  end

  @doc """
  Drop seeds whose feature set is dominated by a simpler seed.
  """
  @spec distill([Seed.t()]) :: [Seed.t()]
  def distill(seeds) when is_list(seeds) do
    seeds = Enum.uniq_by(seeds, fn s -> {s.stream_seed, s.size, s.data} end)

    Enum.reject(seeds, fn a ->
      fa = a.features || MapSet.new()

      Enum.any?(seeds, fn b ->
        fb = b.features || MapSet.new()

        a != b and MapSet.subset?(fa, fb) and not MapSet.equal?(fa, fb) and Seed.simpler?(b, a)
      end)
    end)
  end

  @doc false
  def size(%__MODULE__{by_target: by_target}) do
    by_target |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end

  @doc false
  def write_meta(%__MODULE__{root: root}, attrs) when is_map(attrs) do
    meta_path = Path.join(Path.dirname(root), "meta.json")

    meta =
      Map.merge(
        %{
          "tool" => "stream_fuzz",
          "version" => Application.spec(:stream_fuzz, :vsn) |> to_string(),
          "otp" => :erlang.system_info(:otp_release) |> List.to_string(),
          "elixir" => System.version(),
          "saved_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        },
        attrs
      )

    File.mkdir_p!(Path.dirname(meta_path))
    File.write!(meta_path, Jason.encode!(meta, pretty: true))
  end

  @doc false
  def failures_dir(%__MODULE__{root: root}) do
    root |> Path.dirname() |> Path.join("failures")
  end

  @doc false
  def write_failure(%__MODULE__{} = corpus, %Target{} = target, report) when is_map(report) do
    dir = failures_dir(corpus)
    File.mkdir_p!(dir)
    stamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:.]/, "-")
    path = Path.join(dir, "#{stamp}_#{Target.hash_id(target)}.json")
    File.write!(path, Jason.encode!(report, pretty: true))
    path
  end

  defp oversized?(%__MODULE__{max_seed_bytes: max}, %Seed{data: data}) do
    case data do
      nil -> false
      term -> byte_size(:erlang.term_to_binary(term)) > max
    end
  end

  defp load_all(%__MODULE__{root: root} = corpus) do
    paths = Path.wildcard(Path.join(root, "*.jsonl"))

    by_target =
      Enum.reduce(paths, %{}, fn path, acc ->
        seeds =
          path
          |> File.stream!()
          |> Stream.map(&String.trim/1)
          |> Stream.reject(&(&1 == ""))
          |> Enum.flat_map(fn line ->
            case Jason.decode(line) do
              {:ok, map} -> [Seed.from_map(map)]
              _ -> []
            end
          end)

        case seeds do
          [first | _] -> Map.update(acc, first.target_id, seeds, &(&1 ++ seeds))
          [] -> acc
        end
      end)

    %{corpus | by_target: Map.new(by_target, fn {k, v} -> {k, distill(v)} end)}
  end

  defp persist_target(%__MODULE__{root: root, by_target: by_target}, target_id) do
    seeds = Map.get(by_target, target_id, [])
    path = Path.join(root, Target.hash_id(target_id) <> ".jsonl")

    content =
      seeds
      |> Enum.map(&(Seed.to_map(&1) |> Jason.encode!()))
      |> Enum.join("\n")

    File.write!(path, content <> if(content == "", do: "", else: "\n"))
  end
end
