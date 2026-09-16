defmodule StreamFuzz.CorpusTest do
  use ExUnit.Case, async: true

  alias StreamFuzz.{Corpus, Seed}

  setup do
    dir = Path.join(System.tmp_dir!(), "stream_fuzz_corpus_#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)
    corpus = Corpus.open(Path.join(dir, "corpus"))
    on_exit(fn -> File.rm_rf!(dir) end)
    %{corpus: corpus, dir: dir}
  end

  test "put and reload seeds", %{corpus: corpus, dir: dir} do
    seed =
      Seed.new(
        target_id: "T|prop",
        stream_seed: 42,
        size: 3,
        data: [1, 2, 3],
        features: MapSet.new([{:line, Foo, 1}, {:event, :x}]),
        interesting_reason: :coverage
      )

    corpus = Corpus.put(corpus, seed)
    assert Corpus.size(corpus) == 1

    reloaded = Corpus.open(Path.join(dir, "corpus"))
    assert [loaded] = Corpus.seeds_for(reloaded, "T|prop")
    assert loaded.stream_seed == 42
    assert loaded.data == [1, 2, 3]
    assert MapSet.member?(loaded.features, {:event, :x})
  end

  test "distill drops dominated seeds" do
    a =
      Seed.new(
        target_id: "t",
        stream_seed: 1,
        size: 5,
        data: [1, 2, 3, 4, 5],
        features: MapSet.new([{:line, M, 1}])
      )

    b =
      Seed.new(
        target_id: "t",
        stream_seed: 2,
        size: 1,
        data: [1],
        features: MapSet.new([{:line, M, 1}, {:line, M, 2}])
      )

    distilled = Corpus.distill([a, b])
    assert length(distilled) == 1
    assert hd(distilled).stream_seed == 2
  end
end
