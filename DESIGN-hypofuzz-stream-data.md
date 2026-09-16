# Design: StreamFuzz — coverage-guided StreamData

**Status:** draft  
**Date:** 2026-09-16  
**Related:** [NOTES-refscript-and-verification-landscape-2026.md](./NOTES-refscript-and-verification-landscape-2026.md) §6  
**Product name:** StreamFuzz  
**Hex / Mix package:** `stream_fuzz` (`mix stream_fuzz`)  
**Inspiration:** [HypoFuzz](https://hypofuzz.com/) for Hypothesis (name is independent; no affiliation)

---

## 1. Problem

Elixir already has strong property-based testing via [StreamData](https://github.com/whatyouhide/stream_data) / `ExUnitProperties`. A property is typically run with a fixed budget (default 100 examples). That is the right default for `mix test` on every save.

It is the wrong default for “spend a night of CI CPU finding bugs.” Today the only knobs are:

- raise `:max_runs` uniformly across properties
- run the same suite longer and hope

Neither uses **coverage feedback**. Properties that are still discovering new behavior get the same budget as properties that saturated in the first minute. Counterexamples that open new code paths are discarded after the run instead of being retained as seeds.

Python’s [HypoFuzz](https://hypofuzz.com/) solves this for Hypothesis: keep existing `@given` tests, run them under a coverage-guided scheduler that interleaves targets, prioritizes progress, and maintains a minimal covering corpus. **No equivalent exists for StreamData.**

This is the first rung past vanilla PBT on the testing ladder in the landscape notes:

> example → property → **coverage-guided PBT** → concolic → BMC → proof

---

## 2. Goals

1. **Zero rewrite of properties.** Existing `property` / `check all` blocks run unchanged under a new Mix task.
2. **Coverage-guided budget.** Prefer properties (and seeds) that still uncover new executable lines / events in the SUT.
3. **Persistent corpus.** Save minimal interesting inputs per property so later runs start warm and CI artifacts are shareable.
4. **ExUnit-native failure UX.** On bug: shrink (reuse StreamData), print seed + replay command, exit non-zero.
5. **Whole-suite fuzzing.** One command fuzzes many properties with interleaved scheduling, not one process per property forever.
6. **BEAM-realistic cost model.** Coverage overhead must be acceptable for long runs (minutes–hours), not for every `mix test`.

### Non-goals (v1)

- Replacing StreamData or changing generator APIs.
- Stateful PropEr/PropCheck FSM campaigns (follow-up; different seed/model shape).
- Schedule/concurrency exploration (Lockstep/eta territory).
- Concolic / SMT backends (CutEr-shaped escalation; later rung).
- Native AFL/libFuzzer instrumentation of BEAM bytecode.
- Branch-perfect coverage (OTP `:cover` is **line**-oriented; see §5).
- Proving absence of bugs.

---

## 3. Users and success criteria

**Primary user:** library author or backend team that already writes StreamData properties for parsers, codecs, changesets, pure domain logic.

**Success looks like:**

| Metric | Target (v0.1 evaluation) |
|---|---|
| Drop-in | ≥90% of StreamData properties in 3 OSS libs run without code changes |
| Find rate | More distinct failing properties per CPU-hour than `max_runs: 10_000` uniform baseline on a fixed corpus of seeded bugs |
| Overhead | ≤3× slowdown vs uninstrumented StreamData on the same examples (coverage on) |
| Replay | Every retained seed and every failure replays with a one-liner |
| UX | `mix stream_fuzz` works with only StreamData + this package as deps |

---

## 4. Prior art (what to copy, what to adapt)

### HypoFuzz (Hypothesis)

Copy:

- Interleave many test functions; do not give each a fixed large budget up front.
- Treat coverage (and custom events) as the novelty signal.
- Keep a **distilled corpus**: minimal examples that cover each novelty feature.
- Separate “unit-test mode” (Hypothesis defaults) from “fuzz mode” (long-running, instrumented).

Adapt:

- Hypothesis has an internal **byte-buffer** choice sequence that makes mutation and replay natural. StreamData generators are Elixir enumerables / trees of binds — no public choice tape. Mutation strategy must differ (§7).
- HypoFuzz uses `sys.monitoring` / tracing. BEAM uses `:cover` (and optionally tracers) — coarser and process-global (§5).

### Adjacent BEAM tools (do not reinvent)

| Tool | Relationship |
|---|---|
| StreamData | Generators, shrinking, `check all` — **dependency**, not fork |
| PropCheck/PropEr | Out of scope for v1; design corpus format so stateful can plug in later |
| excoveralls / Six | Reporting; we need **per-example** deltas, not end-of-suite reports |
| Lockstep.RFF | Coverage-guided **schedules**; complementary product, different coverage domain |
| muex | Mutation *of the SUT*; orthogonal meta-metric |

---

## 5. Coverage on the BEAM

### 5.1 Default signal: line coverage deltas

Use OTP `:cover`:

1. At campaign start, cover-compile configured application modules (exclude the test modules themselves unless opted in).
2. Before each example: snapshot line hit set (or reset counters for instrumented modules — prefer **delta via reset** if cheap enough; else snapshot+diff).
3. After each example: compute `new_lines = hits_this_example ∖ global_seen`.
4. If `new_lines` nonempty → mark example **interesting**; union into `global_seen`; enqueue seed.

**Known limitations (document honestly):**

- Line coverage, not branch/edge. `a() \|\| b()` on one line is one feature.
- Macros / compile-time code may not appear.
- Cover-compilation has measurable overhead and interacts poorly with some hot paths.
- Multi-process SUT: coverage is collected for cover-compiled modules regardless of which process runs them; that is usually what we want for libraries. For apps that spawn work on other nodes, v1 is single-node only.

### 5.2 Optional richer signals (v1.x)

| Signal | Use |
|---|---|
| `StreamFuzz.event(name)` | Virtual branch (HypoFuzz `hypothesis.event`) |
| `StreamFuzz.target(score)` | Prefer higher scores when coverage plateaus (IJON-style) |
| Exception class / error tag | Novelty on new failure shapes even before assert |
| Telemetry handler (opt-in) | Treat selected `[:my_app, ...]` events as virtual branches |

### 5.3 Instrumentation lifecycle

```
mix stream_fuzz
  → load test + lib
  → :cover.start / compile_beam for --cover-apps
  → discover properties
  → run campaign loop
  → on exit: export corpus + optional cover HTML summary
```

Do **not** enable this path from default `mix test`. Fuzz mode is opt-in so day-to-day tests stay fast.

---

## 6. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ mix stream_fuzz [paths] [--duration] [--max-failures] ...   │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Discoverer                                                  │
│  - load *test*.exs modules                                  │
│  - find properties tagged :property / registered checks     │
│  - build Target{id, MFA or anonymous runner, generators?}   │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Scheduler (bandit / progress-weighted)                      │
│  - pick next Target                                         │
│  - pick Seed strategy: corpus mutate | fresh generate       │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
┌──────────────────────────┐    ┌─────────────────────────────┐
│ Executor                 │    │ Coverage                    │
│  - run one example       │◄──►│  - reset/snapshot           │
│  - catch fail/shrink     │    │  - delta lines + events     │
│  - record stats          │    └─────────────────────────────┘
└───────────────┬──────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│ Corpus (per-target)                                         │
│  - seeds with feature bitmask / line-set refs               │
│  - distilled: drop dominated seeds                          │
│  - on-disk under priv or _build/stream_fuzz/corpus          │
└─────────────────────────────────────────────────────────────┘
```

### Process model (v1)

- **Single BEAM node**, one scheduler process, **N worker processes** (default: `System.schedulers_online()`).
- Workers pull work units `{target_id, seed_or_fresh}`; return `{outcome, novelty, shrunk_seed?}`.
- Coverage database is global; novelty computation must be serialized (coverage agent process) to avoid lost updates. Workers may run examples in parallel **only if** cover accounting is multiplexed carefully — **v1 recommendation: parallelize across targets with isolated cover snapshots, or run examples concurrently only with process-local tracing**.

**Pragmatic v1 choice:** parallelize by **target** (each worker owns a target for a time slice and uses `:cover` sequentially for that worker’s examples), share corpus via ETS + disk. Revisit true parallel same-module cover once measured.

---

## 7. Seeds, generation, and mutation

StreamData has no public “choice tape.” v1 uses a hybrid that stays compatible with shrinking:

### 7.1 Seed record

```elixir
%StreamFuzz.Seed{
  target_id: "MyTest|property encode/decode roundtrip",
  # Prefer structured terms when the check binds named generators;
  # fall back to generator seed + run index for opaque checks.
  data: term(),                 # the values fed into the property body
  stream_seed: integer(),       # :rand seed used for reproduction
  size: non_neg_integer(),      # StreamData size parameter
  features: MapSet.t(),         # line ids and/or event names covered
  interesting_reason: :coverage | :event | :target | :failure,
  saved_at: DateTime.t()
}
```

### 7.2 How to obtain `data`

**Preferred path — instrumented `check all`:**  
Provide `StreamFuzz.check all ...` (or a `__using__` override) that records bound values into the seed when running under the fuzz runner. Same macros as ExUnitProperties; recording is no-op under normal `mix test`.

**Compatible path — opaque properties:**  
If the user keeps stock `ExUnitProperties.check/2`, fuzz mode can still run by replaying `(stream_seed, size, run_index)` and treating the whole draw as atomic. Mutation is weaker (re-generate with nearby size / reseed), but zero code change still works.

Document that **named `StreamFuzz.check all` bindings get better mutation**. Migration is one alias change.

### 7.3 Mutation operators (on structured `data`)

| Operator | Example |
|---|---|
| Resample sibling | Replace one field with a fresh draw from the same generator |
| Size nudge | Re-generate with `size ± δ` |
| Type-aware tweaks | int ±1, list drop/dup element, binary bit flip / truncate |
| Crossover | Swap subterms between two corpus seeds (same shape) |
| Fresh | Ignore corpus; pure StreamData generate (exploration) |

Shrinking on failure: call existing StreamData shrink toward the failure predicate; store shrunk seed in corpus and failure report.

### 7.4 Corpus distillation

When seed A’s feature set ⊆ seed B’s and B is “simpler” (smaller term / smaller size), drop A. Periodic distill pass keeps corpus small (HypoFuzz / `afl-cmin` analogue).

---

## 8. Scheduling policy

State per target:

- `examples_run`, `failures`, `last_novelty_at`, `novelty_ema`, `plateau_since`

Each tick:

1. With probability `p_fresh` (e.g. 0.2), schedule fresh generation on a random non-plateaued target.
2. Else pick target proportional to `novelty_ema` (plus a small ε so new targets get explored).
3. With probability `p_mutate` (e.g. 0.7), mutate a corpus seed; else fresh.

**Plateau:** no new features for `T` seconds → demote weight (still occasional fresh pulses so we do not permanently starve).

**Stop conditions:** `--duration`, `--max-examples`, `--max-failures`, or interrupt.

---

## 9. Property discovery

### v1 mechanisms

1. Run test files with a custom ExUnit formatter / loader that registers each `property` (ExUnit already tags them `:property`).
2. Wrap registered tests so the fuzz runner can invoke **one example** at a time instead of the whole `check all` loop.
3. Support explicit opt-in:

```elixir
@tag stream_fuzz: true
property "roundtrip" do
  StreamFuzz.check all bin <- binary() do
    assert decode(encode(bin)) == bin
  end
end
```

Default: all `:property` tests under given paths are eligible; exclude with `@tag stream_fuzz: false`.

### Constraint

The property body must be **safe to run repeatedly** in one VM (no irreversible global pollution). Document: prefer setup/on_exit; warn on module attribute mutation. Same discipline as long PropEr runs.

---

## 10. CLI / Mix UX

```bash
# Fuzz all properties under test/
mix stream_fuzz

# Subset
mix stream_fuzz test/codec_test.exs --only roundtrip

# Budgets
mix stream_fuzz --duration 30m --workers 4 --max-failures 10

# Coverage scope
mix stream_fuzz --cover-app my_app --cover-app my_app_web

# Corpus
mix stream_fuzz --corpus _build/stream_fuzz/corpus
mix stream_fuzz --replay _build/stream_fuzz/failures/2026-09-16T01-02-03.json
```

Exit codes:

- `0` — no failures
- `1` — one or more property failures (corpus + reports written)
- `2` — tooling error (cover failed to start, no targets, etc.)

### Failure report (stdout + JSON)

- property id  
- shrunk values (inspect)  
- `stream_seed` / `size`  
- replay mix command  
- novelty features touched (optional, debug)

### Live progress (stdout)

```
[12m] targets=24 corpus=881 seen_lines=4521 (+3/min) failures=1
  hot: CodecTest.roundtrip (+12 lines/min)
  cold: UserTest.valid_email (plateau 8m)
```

Optional later: tiny Phoenix/LiveDashboard — not v1.

---

## 11. Public API (library surface)

```elixir
# drop-in recording check (recommended for better mutation)
import StreamFuzz
StreamFuzz.check all x <- integer(), y <- integer() do
  assert MyApp.add(x, y) == x + y
end

# optional guidance
StreamFuzz.event(:empty_input)
StreamFuzz.target(byte_size(bin))
```

Configuration (`config/test.exs` or mix opts):

```elixir
config :stream_fuzz,
  cover_apps: [:my_app],
  corpus_dir: "_build/stream_fuzz/corpus",
  workers: System.schedulers_online(),
  p_mutate: 0.7,
  p_fresh: 0.2
```

---

## 12. Persistence format

Directory layout:

```
_build/stream_fuzz/
  corpus/
    <target_hash>.jsonl          # one seed per line
  failures/
    <timestamp>_<target_hash>.json
  meta.json                      # tool version, otp, elixir, cover module set
```

JSON (not ETS-only) so CI can cache/upload corpus between jobs. Terms via Erlang external term format base64 **or** Jason-safe subset with a documented fallback to `:erlang.term_to_binary/1`.

---

## 13. Implementation plan

### Phase 0 — spike (1–2 weeks)

- Cover delta measurement cost on a mid-size app (`:cover.reset` vs analyse diff).
- Prove one-example invocation of an existing `check all` property.
- Decide parallelization story from measurements.

**Go/no-go:** if per-example cover accounting cannot stay under ~3×, switch novelty signal to sampling (every Nth example) or to `:erlang.trace` call counts on a module allowlist.

### Phase 1 — MVP

- `mix stream_fuzz` discovers `:property` tests.
- Sequential or per-target workers.
- Line-coverage novelty + on-disk corpus.
- Failure → StreamData shrink → report + replay.
- Opaque seed replay (`stream_seed` + size) without API changes.

### Phase 2 — mutation quality

- `StreamFuzz.check all` binding capture.
- Structured mutators + distillation.
- `event/1`, `target/1`.
- Progress UI + JSON reports.

### Phase 3 — ecosystem

- Hex package, docs, “add to CI” guide (nightly job).
- Benchmark suite: planted bugs vs uniform `max_runs` (bugs-per-CPU-hour from landscape notes).
- Optional PropCheck target adapter (design only if demand).

### Phase 4 — ladder hooks (explicit non-goals becoming goals)

- Emit corpus as seeds for a future concolic backend.
- Diff-scoped “properties that gained coverage on this PR” report.

---

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| `:cover` too slow / coarse | Measure in Phase 0; sampling; allowlist modules; accept line-level honesty |
| Cannot split `check all` into one-example runs | Compile-time macro wrapper; or fork ExUnitProperties runner module |
| Flaky properties / shared state | Document; detect nondeterminism by double-running failures; quarantine |
| Corpus stores huge binaries | Size cap; hash+external blob; refuse seeds over N bytes |
| False confidence (“we fuzzed”) | Report plateau + seen_lines; never claim completeness |
| OTP cover quirks across versions | CI matrix; pin behavior tests |
| Name / trademark | Keep HypoFuzz as inspiration only; ship as independent Hex name |

---

## 15. Security / safety

- Fuzz mode may feed adversarial strings into code that hits the FS/network if the SUT is not pure. Default **recommend** running against pure units; provide `--allow-side-effects` acknowledgment for integration properties.
- Corpus is untrusted input when downloaded from CI artifacts — treat as data, not code (no `Code.eval`).
- Do not cover-compile dependency hell by default; only `--cover-app` applications.

---

## 16. Alternatives considered

| Alternative | Why not first |
|---|---|
| Wrap StreamData with external libFuzzer via NIFs | Hostile BEAM instrumentation; loses structured generation |
| Only increase `max_runs` | No prioritization; no corpus |
| Fork StreamData in-tree | Social/maintenance cost; upstream already good at generate/shrink |
| Build on PropEr only | Worse Elixir UX; StreamData is the default teaching path |
| Start with concolic (CutEr) | Higher complexity; fewer runnable properties; second rung |

---

## 17. Open questions

1. **Upstream vs satellite:** Is a StreamData PR (fuzz hooks) preferable long-term to a satellite package? Satellite is faster to ship; thin upstream hooks (`on_example` callback) would be ideal later.
2. **Cover reset semantics** under parallel workers — need Phase 0 numbers before locking the process model.
3. **Should `mix test --fuzz` exist** as sugar, or keep a separate task forever?
4. **Minimum Elixir/OTP versions** — likely Elixir 1.15+ / OTP 26+ for simpler cover behavior; confirm against native coverage support.
5. **Integration with ExUnitProperties’ upcoming changes** if StreamData merges deeper into Elixir stdlib again.

---

## 18. Recommendation

Build **`stream_fuzz` as a Hex library + Mix task** that treats StreamData properties as fuzz targets, uses OTP `:cover` line deltas as the novelty signal, and persists a distilled corpus. Optimize for **nightly CI** and library authors first. Keep the API compatible with stock properties; reward a one-line switch to `StreamFuzz.check all` with better mutation.

This is the smallest step that moves the Elixir ecosystem from “PBT exists” to “PBT scales with CPU,” and it leaves clean extension points for schema-auto-harnesses and concolic backends later.

---

## 19. StreamData adoption (Hex, 2026-09-16)

| Signal | Value | Caveat |
|---|---|---|
| Hex **dependants** | **55** packages | Only published packages that list `stream_data` in `mix.exs` |
| Downloads (current ver, ~30d) | ~300k+ | Better adoption proxy than dependant count |
| Downloads (all-time) | ~37M | Includes CI; still indicates ubiquity |
| Package deps | 0 | Easy to depend on |

Hex dependants are a **lower bound**. Most app usage is `:only => :test` and never appears on the dependants page.

### Dependants useful as evaluation / drop-in candidates

Scout for packages that ship **ExUnit `property` tests**, not only generators:

| Package | Why interesting |
|---|---|
| [peri](https://hex.pm/packages/peri) | Schema validation; natural property surface |
| [norm](https://hex.pm/packages/norm) | Specs + generation |
| [type_check](https://hex.pm/packages/type_check) | Types → generators |
| [purl](https://hex.pm/packages/purl) | Small, parser-shaped |
| [crux](https://hex.pm/packages/crux) | SAT / boolean expressions |
| [ash](https://hex.pm/packages/ash) | Large; sample a subsystem, don’t start here |
| [more_stream_data](https://hex.pm/packages/more_stream_data) | Extra generators; good compat canary |
| [ecto_stream_factory](https://hex.pm/packages/ecto_stream_factory) | Factory + PBT bridge |
| [program_facts](https://hex.pm/packages/program_facts) | Generates programs with known facts — meta-evaluation ally |
| [ab](https://hex.pm/packages/ab) | Differential compare of two implementations |

Re-check [hex.pm/packages/stream_data/dependents](https://hex.pm/packages/stream_data/dependents) when starting Phase 3 benchmarks.

---

## 20. Evaluation corpora (two different meanings)

### A. Fuzzer seed corpus (runtime artifact)

Produced by StreamFuzz itself under `_build/stream_fuzz/corpus/`. Empty on first run; warm across CI jobs if cached. This is **not** something we need before implementing.

### B. Benchmark / research corpus (must be assembled)

No public “bugs-per-CPU-hour” ladder benchmark exists for Elixir (landscape notes §6). Build in tiers:

| Tier | Contents | Purpose |
|---|---|---|
| **A — Synthetic** | Tiny SUT modules with planted branchy bugs + StreamData properties | Controlled find-rate vs `max_runs: 10_000` |
| **B — Dependants** | Clone 3–5 Hex users that already have `property` tests | Drop-in ≥90% target; real generator shapes |
| **C — Historical (optional)** | Mine fixed bugs from git history; ask “would fuzz mode have hit this?” | Stronger external claim; more labor |

Phase 0/1 should include at least Tier A inside this repo (`bench/` or `eval/`). Tier B starts once MVP can load foreign test suites.

### Suggested synthetic bug patterns

- Off-by-one in parsers / slice math  
- Unhandled tag in `case` / missing `def` clause  
- Encode/decode asymmetry on empty or max-size inputs  
- Unicode / invalid UTF-8 paths that line coverage under-exercises without guidance  

---

## 21. Glossary (ladder terms used here)

| Term | Meaning |
|---|---|
| **PBT** | Property-based testing (StreamData / PropEr) |
| **Coverage-guided PBT** | Schedule examples/seeds by novelty (this project) |
| **Corpus** | Retained interesting inputs (seeds), distilled for coverage |
| **BMC** | Bounded model checking — SMT/SAT over a finite unrolling; later ladder rung, not v1 |
| **Concolic** | Concrete run + symbolic path constraints (e.g. CutEr); next rung after this |
| **Novelty** | New `:cover` lines and/or `StreamFuzz.event/1` names |

---

## 22. Repo / handoff notes (for implementation sessions)

**Dev environment:** `nix develop` (see root `flake.nix`). Local Mix/Hex dirs under `.mix` / `.hex` so the flake shell stays hermetic-ish.

**Suggested first implementation slice (Phase 0 spike):**

1. `mix new stream_fuzz --module StreamFuzz` (library) under this repo or `stream_fuzz/` subdir — pick one layout and stick to it.  
2. Spike: cover-compile a toy module, run N StreamData examples, measure per-example `:cover` delta cost.  
3. Spike: invoke **one** iteration of an `ExUnitProperties.check all` body with a fixed seed.  
4. Only then: `Mix.Tasks.StreamFuzz` skeleton + target discovery.

**Layout recommendation:** implement as a library at repo root (this ecosystem repo becomes the StreamFuzz project), keep `NOTES-*.md` and this design doc in-tree. Alternative: `stream_fuzz/` subdirectory if you want notes isolated — prefer **repo root = package** for Hex later.

**Out of scope reminders:** Lockstep/eta, CutEr, PropCheck state machines, schema→harness auto-gen — separate tracks after MVP.

**Open product decision:** satellite Hex package first (default); propose thin StreamData `on_example` hook upstream only after MVP proves the workflow.
