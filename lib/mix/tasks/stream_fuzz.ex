defmodule Mix.Tasks.StreamFuzz do
  @shortdoc "Coverage-guided fuzzing of StreamData properties"
  @moduledoc """
  Runs a coverage-guided fuzz campaign over ExUnit `property` tests.

      mix stream_fuzz
      mix stream_fuzz test/codec_test.exs --only roundtrip
      mix stream_fuzz --duration 30m --workers 4 --max-failures 10
      mix stream_fuzz --cover-app my_app --corpus _build/stream_fuzz/corpus
      mix stream_fuzz --replay _build/stream_fuzz/failures/....json

  Exit codes:

    * `0` — no failures
    * `1` — one or more property failures
    * `2` — tooling error
  """

  use Mix.Task

  @switches [
    duration: :string,
    max_examples: :integer,
    max_failures: :integer,
    workers: :integer,
    cover_app: :keep,
    corpus: :string,
    replay: :string,
    replay_seed: :integer,
    replay_size: :integer,
    only: :string,
    progress_every: :string,
    allow_side_effects: :boolean
  ]

  @aliases [
    d: :duration,
    n: :max_examples,
    f: :max_failures
  ]

  @impl Mix.Task
  def run(args) do
    {opts, paths, invalid} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    if invalid != [] do
      Mix.shell().error("Invalid options: #{inspect(invalid)}")
      exit({:shutdown, 2})
    end

    Mix.Task.run("loadpaths")
    Mix.Task.run("app.config")
    Mix.Task.run("compile")

    Application.ensure_all_started(:stream_data)
    Application.ensure_all_started(:jason)
    Application.ensure_all_started(:ex_unit)
    Application.ensure_all_started(:stream_fuzz)

    # Soft acknowledgment for integration properties that touch FS/network.
    _ = opts[:allow_side_effects]

    cover_apps =
      opts
      |> Keyword.get_values(:cover_app)
      |> Enum.map(&String.to_atom/1)
      |> case do
        [] -> Application.get_env(:stream_fuzz, :cover_apps, default_project_apps())
        apps -> apps
      end

    Enum.each(cover_apps, fn app ->
      _ = Application.ensure_all_started(app)
    end)

    campaign_opts = [
      paths: paths_or_default(paths),
      corpus_dir:
        opts[:corpus] ||
          Application.get_env(:stream_fuzz, :corpus_dir, "_build/stream_fuzz/corpus"),
      cover_apps: cover_apps,
      duration_ms: parse_duration(opts[:duration]),
      max_examples: opts[:max_examples],
      max_failures: opts[:max_failures] || 10,
      only: opts[:only],
      replay: opts[:replay],
      replay_seed: opts[:replay_seed],
      replay_size: opts[:replay_size],
      progress_every_ms: parse_duration(opts[:progress_every]) || 5_000
    ]

    # Default budget if nothing specified: a short local run.
    campaign_opts =
      if is_nil(campaign_opts[:duration_ms]) and is_nil(campaign_opts[:max_examples]) and
           is_nil(campaign_opts[:replay]) and is_nil(campaign_opts[:replay_seed]) do
        Keyword.put(campaign_opts, :max_examples, 200)
      else
        campaign_opts
      end

    case StreamFuzz.Campaign.run(campaign_opts) do
      {:ok, %{status: :ok}} ->
        :ok

      {:ok, %{status: :failed}} ->
        exit({:shutdown, 1})

      {:error, :no_targets} ->
        Mix.shell().error(
          "No fuzz targets found (property tests under #{inspect(campaign_opts[:paths])})."
        )

        exit({:shutdown, 2})

      {:error, reason} ->
        Mix.shell().error("StreamFuzz failed: #{inspect(reason)}")
        exit({:shutdown, 2})
    end
  end

  defp paths_or_default([]), do: ["test"]
  defp paths_or_default(paths), do: paths

  defp default_project_apps do
    app = Mix.Project.config()[:app]
    if app && app != :stream_fuzz, do: [app], else: [:stream_fuzz]
  end

  defp parse_duration(nil), do: nil

  defp parse_duration(str) when is_binary(str) do
    case Regex.run(~r/^(\d+)(ms|s|m|h)?$/, String.trim(str)) do
      [_, n, unit] ->
        n = String.to_integer(n)

        case unit do
          "ms" -> n
          "s" -> n * 1_000
          "m" -> n * 60_000
          "h" -> n * 3_600_000
          nil -> n * 1_000
        end

      [_, n] ->
        String.to_integer(n) * 1_000

      _ ->
        Mix.raise("Invalid duration: #{inspect(str)} (use 30s, 5m, 1h)")
    end
  end
end
