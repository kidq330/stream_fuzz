# StreamFuzz

Coverage-guided fuzzing for [StreamData](https://github.com/whatyouhide/stream_data) / `ExUnitProperties`.

Keep your existing `property` / `check all` tests. Run them under a scheduler that
interleaves targets, prioritizes novelty (OTP `:cover` line deltas + optional events),
and persists a distilled corpus — HypoFuzz-style workflow for Elixir.

> Inspired by [HypoFuzz](https://hypofuzz.com/); independent project, no affiliation.

Design notes: [`DESIGN-hypofuzz-stream-data.md`](./DESIGN-hypofuzz-stream-data.md).

## Install

```elixir
def deps do
  [
    {:stream_fuzz, "~> 0.1.0", only: :test}
  ]
end
```

```elixir
# config/test.exs
config :stream_fuzz,
  cover_apps: [:my_app],
  corpus_dir: "_build/stream_fuzz/corpus"
```

## Usage

```bash
# Fuzz all properties under test/
mix stream_fuzz

# Subset + budgets
mix stream_fuzz test/codec_test.exs --only roundtrip --duration 30m --max-failures 10

# Coverage scope
mix stream_fuzz --cover-app my_app

# Replay a saved failure
mix stream_fuzz --replay _build/stream_fuzz/failures/<file>.json
```

Exit codes: `0` ok, `1` property failures, `2` tooling error.

### Optional API (better mutation)

```elixir
require StreamFuzz
# or: use StreamFuzz

property "roundtrip" do
  StreamFuzz.check all bin <- binary() do
    if bin == <<>>, do: StreamFuzz.event(:empty)
    StreamFuzz.target(byte_size(bin))
    assert decode(encode(bin)) == bin
  end
end
```

Exclude a property with `@tag stream_fuzz: false`.

Planted-bug eval (not run by `mix test`):

```bash
mix stream_fuzz eval/decode_tag_properties_test.exs --max-examples 200
```

## How it works

1. Discover ExUnit tests tagged `:property`
2. Cover-compile configured apps
3. Interleave one-example runs (`max_runs: 1` + controlled seed/size)
4. Keep seeds that hit new lines / events; distill dominated seeds
5. On failure: StreamData shrink → JSON report + replay command

## Development

```bash
nix develop   # or use system Elixir 1.15+ / OTP 26+
mix deps.get
mix test
mix stream_fuzz --max-examples 100 --cover-app stream_fuzz
```
