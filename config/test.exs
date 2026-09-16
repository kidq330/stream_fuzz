# StreamFuzz configuration (used when MIX_ENV=test)
import Config

config :stream_fuzz,
  cover_apps: [:stream_fuzz],
  corpus_dir: "_build/stream_fuzz/corpus",
  p_mutate: 0.7,
  p_fresh: 0.2,
  plateau_ms: 60_000

config :stream_data,
  initial_size: 1,
  max_runs: 100,
  max_run_time: :infinity,
  max_shrinking_steps: 100
