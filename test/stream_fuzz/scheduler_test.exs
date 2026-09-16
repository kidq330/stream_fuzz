defmodule StreamFuzz.SchedulerTest do
  use ExUnit.Case, async: true

  alias StreamFuzz.{Corpus, Scheduler, Target}

  test "schedules work units across targets" do
    targets = [
      Target.new(module: A, name: :"test one", description: "one"),
      Target.new(module: B, name: :"test two", description: "two")
    ]

    sched = Scheduler.new(targets)
    dir = Path.join(System.tmp_dir!(), "sf_sched_#{System.unique_integer([:positive])}")
    corpus = Corpus.open(Path.join(dir, "corpus"))
    on_exit(fn -> File.rm_rf!(dir) end)

    {work, sched} = Scheduler.next(sched, corpus)
    assert work.target.id in Enum.map(targets, & &1.id)
    assert work.mode in [:fresh, :mutate]
    assert work.seed.stream_seed > 0

    sched = Scheduler.record(sched, work.target, novelty?: true)
    assert Scheduler.total_examples(sched) == 1
  end
end
