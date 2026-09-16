# refscript, refinement types, and the 2026 verification landscape

Notes from an investigation session, 2026-09-15/16. Covers: why this repo stopped, the state of
liquid/refinement types, adoption evidence, the LLM-era shift in formal methods, how it reaches
non-systems ecosystems, and where testing/QA practice could be pushed up the ladder.

---

## 1. This repo (refscript / RSC)

- Paper: *Refinement Types for TypeScript* (Vekris, Cosman, Jhala, PLDI 2016).
  https://dl.acm.org/doi/10.1145/2908080.2908110 — extended: https://arxiv.org/abs/1604.02480
- History: 2,380 commits, 2013-04-17 → 2016-05-29 (last real commit "Porting demo tests"), one
  README edit in 2019. Upstream `UCSD-PL/refscript`: not archived, last push Jan 2019, 70 stars,
  16 open issues; the two newest (2018) are "demo not working".
- Frozen toolchain: `stack.yaml` pins `nightly-2016-01-06` (GHC 7.10.3), Z3 >= 4.3.2, a patched
  fork of **tsc 1.0.1** as frontend (`ext/tsc-bin/.../tsc-refscript.js`), `liquid-fixpoint`
  submodule (still alive; shared with LiquidHaskell and Flux).
- `TODO.md` shows it stopped mid-refactor (PR #145 "Refactor types" merged 2016-05-07): variance
  checks, WF checks for overloads, bidirectional TC, refinement sort checker, `fixEnums` disabled.

### Techniques
Refinements only on immutable bindings (X10-style); IGJ-style parametric mutability
(`Immutable / Mutable / ReadOnly / Unique`); SSA for flow sensitivity; two-phase typing for
value-based overloading/reflection; Liquid inference for refinements.

### Evaluation (Fig. 5)
2,522 LOC (Octane, D3, Transducers, tsc). **529 annotations, ~1 per 5 LOC**: 334 plain TS types,
104 mutability, 91 real refinements. Required edits: rewrite `break` loops and `x++`, explicit
ctor args, 5 manual non-null checks (splay), ghost lemmas for non-linear index math
(navier-stokes: 473 s).

### Documented unhandled cases (Vekris thesis §4.4.3, §5.2)
- Method calls on `this` inside constructors.
- Cannot recover `Unique` after `Mutable` (their own example: `distinct()` from tsc, interleaving
  `res[j]` reads and `res.push` in one loop).
- One annotation per overload.
- Programs must be fully base-typed with **zero `any`**.
- Base-type inference burden; proposed Flow as a base-type oracle.

### Why it stopped (no official statement; inference from evidence)
1. **People.** Vekris's 2017 thesis *Precise Type Checking for JavaScript*
   (https://goto.ucsd.edu/~pvekris/docs/pvekris-thesis.pdf) bundles RSC with his Facebook Flow
   work; co-author on the OOPSLA'17 Flow paper; joined Meta. Jhala's group's next imperative
   target was Rust (Flux, PLDI 2023).
2. **The mutability wall.** Flux's intro: refinements "have remained a fish out of water in the
   imperative setting"; prior substructural/effect retrofits "proved impractical." RSC's answer
   (a mutability lattice = 20% of annotations) is exactly that non-idiomatic overhead; Rust's
   borrow checker supplies the aliasing facts for free.
3. **Substrate rot.** Forking tsc 1.0.1 was untenable. TS 2.0 (Sept 2016) added
   `strictNullChecks`, control-flow narrowing, discriminated unions; later `strictFunctionTypes`,
   literal/template-literal types, `noUncheckedIndexedAccess`, `satisfies`. Two of RSC's four
   headline properties (safe property access, safe downcasts) became largely native.

### Was TypeScript's unsoundness the cause?
Mostly no. RSC already fixed the four sources it identified (`null`/`undefined` as bottom,
bivariance, unchecked overloads, `any`) — it is a sound system on a TS subset. TS's non-goal #3
("Apply a sound or provably correct type system") is deliberate and stable
(https://github.com/microsoft/TypeScript/wiki/TypeScript-Design-Goals,
https://github.com/microsoft/TypeScript/issues/9825). The deeper obstacles are JavaScript's:
unrestricted aliasing/mutation, array holes, computed property access — thesis §5.1: "some
aspects of JavaScript force us into choosing unsoundness where it is objectively justified."
Banning `any` outright is workable for 2.5K LOC of benchmarks and impossible for a real codebase;
gradual refinement types (Lehmann & Tanter, POPL 2017) came later and only for a functional core.

---

## 2. Is aliasing the only blocker for imperative refinement types?

No, but it is the one that forces inventing a type-system layer:

| System | Alias discipline bought |
|---|---|
| CSolve (C) | physical location types + heap-effect layer |
| RSC (TS) | IGJ mutability lattice |
| ConSORT (2020) | fractional ownership; aliased mutable refs get only ⊤ |
| RefinedC (2021) | ownership + Iris separation logic, more annotations, foundational |
| Flux (Rust) | reuses borrow checker, but still adds `&strg` strong refs + `ensures` |

Other blockers that persist even with Rust:
- **Higher-order effectful code** (closures capturing mutable state): needs ghost/implicit
  parameters (Implicit Refinement Types, ECOOP 2021) or bounded refinements (ICFP 2015).
- **Decidability discipline**: quantifier-free only; sortedness, non-linear arithmetic, strings
  fall off the cliff into manual proof.
- **Data-structure invariants** need measures/reflection → termination/totality → proof engineering.
- **Object initialization and behavioral subtyping** (only 46% of LiquidJava users got
  object-state refinements right).
- **Base-type inference burden** in untyped hosts.
- **Concurrency**: out of scope for every liquid system so far.

---

## 3. Adoption evidence (meta-analyses)

- **Usability Barriers for Liquid Types** (Gamboa et al., 2025, 19 LH users,
  https://doi.org/10.1145/3729327). Nine barriers: unclear divide between host language and
  refinement layer; confusing verification features; unfamiliarity with proof engineering;
  automation-vs-manual-proof cliff; scalability/solver limits; unhelpful errors; limited IDE
  support; poor learning resources; painful installation. Quote: "using comments feels fake"
  (directly about RSC/LH-style `/*@ ... */` annotations).
- **LiquidJava** (ICSE 2023, 30 devs): 80% had never heard of refinement types; 86% could use
  variable/method refinements untrained; only 46% got object-state refinements right.
- **The Way of Types** (ICPC 2026, 130 practitioners): inhibitors = unshielded complexity, weak
  ecosystems, no real-world library support; recommends embedding refinements in existing
  compilers and combining static with runtime checks.
- **Neurosymbolic Modular Refinement Type Inference / LHC** (ICSE 2025, Jhala group,
  https://doi.org/10.1109/icse55347.2025.00090): annotation burden is *the* blocker; fine-tuned
  StarCoder-3B / CodeLlama-7B propose up to 50 candidate types per function; LiquidHaskell is the
  oracle; failed guesses are harvested as qualifiers for symbolic Horn inference. Up to 94% of
  functions annotated automatically in hours vs. expert days/weeks.
- **Refinement Type Refutations / HayStack** (OOPSLA 2024): compositional counterexamples for
  failed typing; 99.7% of LH benchmarks; not shipped in LH.
- **Flagship status**: LiquidHaskell 0.9.14.1 (May 2026, GHC 9.14) — maintained but tiny team,
  Stack config abandoned, undocumented features (issue #2603, Jan 2026); 18 direct reverse deps.
  Flux: 909 stars, 121 open issues, ~2 maintainers; in AWS/Rust Foundation verify-rust-std, but
  running on `core` yields ~300 warnings and ~200 ICEs.
- **Bottom line**: 18 years after Liquid Types (2008), no liquid type system has crossed into
  mainstream use in any language. Failure modes are UX/integration, not theory.

### Where gruntwork would land (liquid-types world)
Flux (Rust feature coverage, closures, trait objects, `Real` sorts); LiquidHaskell (parser,
docs, multi-GHC, ship HayStack, LSP); liquid-fixpoint (perf, CVC5); refined std-lib specs
(Generic Refinement Types, POPL 2025, for `Vec` → rest of std / `lib.d.ts`); a public,
training-excluded refinement-type benchmark (no DafnyBench equivalent exists); LiquidJava;
Ezno (2.7k stars, one dev, cannot check real projects).

### If reviving a TS refinement checker in 2026
- Don't fork the compiler: consume TS as base-type oracle (`@typescript/typescript6` or tsgo IPC;
  TS 7 has no API until 7.1). Own IR (SSA/ANF) → liquid-fixpoint, Flux-style driver architecture.
- Reuse TS strict mode as phase 1; keep only the refinement phase. Treat TS holes (method
  bivariance, array covariance, `any`) as `assume`/`trusted` + lint.
- Gradual boundary via runtime validators (Zod/Effect Schema/ArkType `refine` = RSC's envisioned
  `castT`); share one predicate language between checker and validator.
- Ride modern immutability idioms (`readonly`, `as const`, `ReadonlyArray`) instead of inventing a
  lattice; target "verified islands" (index math, arithmetic, parsers, protocol invariants).
- Kill annotation burden with LHC-style LLM inference; TS is the largest training corpus.
- UX first: refinements in type positions not comments; LSP; refutations; quantifier-free discipline.
- Honest scope: research vehicle for LLM-driven refinement inference, or a narrow tool for
  arithmetic/bounds-heavy TS — not a general TS checker. Remaining differentiator vs.
  contracts+SMT (theorem), TS→Dafny/Lean (LemmaScript, jscore), Ezno: liquid *inference* for
  higher-order/generic code (the `minIndex`/`reduce` example).

---

## 4. LLM-era formal methods: what changed

- Sharpest statements: de Moura, *When AI Writes the World's Software, Who Verifies It?*
  (Feb 2026, https://leodemoura.github.io/blog/2026-2-28-when-ai-writes-the-worlds-software-who-verifies-it/);
  MSR *Intent Formalization: A Grand Challenge* (Mar 2026, https://arxiv.org/pdf/2603.17150).
- Oxide correction: RFD 576 says LLM-generated tests "may mirror existing bugs" / "false sense of
  coverage," but Oxide's answer is accountability + TLA+/proptest, not proofs.
- Numbers: Vericoding benchmark (12.5k tasks): 82% Dafny / 44% Verus / 27% Lean off-the-shelf;
  Dafny proof-completion 68%→96% in a year. AlgoVeri (harder, aligned): 40/25/8%. Aria: Claude
  Code proves all 4,257 Iris core lemmas + Rust std proofs on it. lean-zip: agent-ported zlib with
  roundtrip proof.
- The catch: lean-zip had an OOM in the *unverified* archive parser and a heap overflow in Lean's
  C++ runtime. Verification works where applied; spec and TCB are the residual risk. Tests lost
  value as *evidence of intent* (same agent wrote code and tests), not against proofs.
- Industrial stacks are layered: AWS-LC (SAW/Cryptol, HOL Light s2n-bignum, Lean 4 for AArch64),
  s2n-tls (SAW + CBMC + SideTrail), s2n-quic (Kani + fuzzing + Duvet traceability), Cedar
  (Dafny/Lean model + differential tests), verify-rust-std (Kani/ESBMC/VeriFast/Flux, 450+ PRs,
  cash challenges). Microsoft SymCrypt-in-Rust: Aeneas → Lean, agents write proofs, 237 KLOC Lean
  for 16.7 KLOC Rust. Ethereum zkEVM: Rust→Lean with Aristotle/Aleph.

### The map (automation high→low, expressiveness low→high)
1. Push-button decidable fragments: type systems → **refinement/liquid types**, abstract
   interpretation, BMC (Kani/CBMC/ESBMC). Engine: SMT/SAT + Horn solvers.
2. Auto-active: Dafny, Verus, Prusti, Creusot, F*, Why3/Viper, RefinedC. LLM+verifier loops shine here.
3. Interactive/foundational: Lean, Rocq, Isabelle, HOL Light; Iris; Aeneas/hax. Most transformed by agents.
4. Design-level model checking: TLA+/TLC/Apalache, Alloy, P, Veil.
5. Dynamic: PBT, fuzzing, sanitizers, Kani harnesses-as-tests.

SMT made VC discharge cheap (2010s); LLMs are making annotation/proof search cheap (2020s);
what remains expensive: specification validation and the trusted computing base.

### Liquid types in this shift
- Least transformed tier (their pitch was already automation); gains from LLM *spec* inference
  and error explanation; natural role = cheap always-on tier with escalation to Verus/Lean.
- Possibly the best spec notation for the intent bottleneck: types are the one formal notation
  mainstream developers already review; a refinement signature is a few tokens vs. dozens of
  lines of contract that can be "vacuously correct."

Caveats: NL→TLA+ semantic correctness topped at 8.6% across 30 models; Vero (repo-level Lean)
shows agents fail at shared invariants; toolchain drift and TCB bugs recur; adopters remain the
same handful of well-funded orgs.

---

## 5. Non-systems ecosystems (mobile, web, devops, multimedia)

Formal methods arrived there in disguise — types, linters, config languages, model checkers
inside cloud products — never under the name "verification."

- **Web frontend**: Elm, Elm-architecture → Redux, TS narrowing/exhaustiveness, Statecharts
  (Harel 1987) via XState; React Compiler assumes purity. No verification of the parts that bite
  (async races, fetching, stale closures). No SMT story.
- **Phoenix/Elixir**: BEAM culture (QuickCheck/PropEr, Concuerror, `gen_statem`). **Elixir v1.20
  (June 2026)** is gradually typed with set-theoretic types — full inference, no annotations,
  "verified bugs" and dead code found in Phoenix/LiveView. Closest thing to the refinement-type
  promise actually shipping to a web community.
- **Mobile**: Meta Infer (separation logic, since 2015) at scale on Android/iOS; Swift 6 strict
  concurrency = compile-time data-race freedom for millions of devs. React Native inherits
  neither. Formal UI specification (screens + state flows) was solved for FDA-regulated medical
  devices (PVSio-web, IVY) and never crossed to consumer apps.
- **DevOps**: most formal methods in production, all invisible — AWS Zelkova (IAM), Tiros (VPC
  reachability), Cedar (Lean-verified), Batfish, TLA+/P internally; Anvil (OSDI 2024) verified
  Kubernetes controllers with *liveness* proofs in Verus. Config languages are refinement types by
  another name: CUE (lattice types), Nickel (gradual + contracts), Dhall. Unverified: CI
  pipelines, Terraform plans, Helm.
- **Multimedia**: compiler correctness and numerics — Halide TRS verified with Z3 + translation
  validation; GPUVerify (race-freedom of CUDA/OpenCL); Herbie/Daisy/FPTaylor; rav1d-safe;
  Faust. No verified codec end to end.

### "A spec language a bit higher than code, for screens and state flow"
Attempted at least four times: Statecharts/SCXML (1987 → W3C 2015); Executable UML/MDA (2000s,
died of round-trip drift); Sketch.systems (2018) → Stately Studio (2023–, generates React from a
machine, MCP for agents); spec-driven agent tooling (Kiro with EARS requirements syntax, GitHub
Spec Kit) — all informal, no checker.

Why formal versions failed in frontend: round-trip drift; the statechart is the small part
(glue/fetch/layout is most code); framework churn under the model; felt like a second codebase.
LLMs plausibly fix drift and churn (regenerate implementation from the model). Missing piece:
**conformance** — checking the implementation refines the machine. Practical middle tier from
parts on npm: XState machine as spec → `@xstate/graph` path enumeration → generated model-based
e2e tests as oracle → agent implements until they pass.

Lineage to build on for UI state specs: Harel → SCXML → XState → conformance testing, with LLMs
as the implementation engine. Not refinement types.

---

## 6. Evolving testing/QA up the ladder

### The ladder (each rung = previous + one ingredient)
- **Input axis**: example → property (+generator, +shrinking) → coverage-guided PBT (+coverage
  feedback = fuzzing) → concolic (SMT-solved paths) → bounded model checking → proof (+invariants).
- **Oracle axis**: exact value → snapshot/approval → differential → metamorphic → contract/refinement.
- **Environment axis**: integration test → deterministic simulation → schedule exploration /
  model checking → design-level model (TLA+/Alloy).
- **Meta**: mutation score (test the tests); vacuity (property never reached the interesting region).

### Merges that already exist (mostly Rust / Python / C++ / databases)
Bolero (one harness → proptest/libFuzzer/AFL/Kani), Google FuzzTest and rust-derive-fuzztest
(PBT + fuzz target from one annotation), HypoFuzz (coverage-guided scheduling of Hypothesis
tests), Hypothesis + CrossHair backend (PBT → concolic), Antithesis (DST as CI step / agent
skill), Meta ACH (LLM mutants + LLM tests + equivalent-mutant detection 0.95/0.96, deployed on
WhatsApp/Messenger), TigerBeetle "sometimes assertions" (coverage for properties). Almost none
of this exists in JS/TS, JVM, Go, Swift, Kotlin.

### Merges nobody has shipped
1. **Bolero for JS/TS**: fast-check + Jazzer.js + a **CrossHair-for-TypeScript** concolic
   backend, one `check()` with escalating engines; TS types/Zod schemas give generators for free.
2. **Every schema boundary is a fuzz target**: auto-generate harnesses from Zod/Effect/ArkType
   decoders; `refine()` predicates are the refinements — static check that a refine implies a
   downstream precondition is the one mainstream slot for SMT refinement reasoning in TS.
3. **Codecov for mutants**: diff-scoped incremental mutation score + LLM equivalent-mutant
   filtering; mutants as the fitness function for agent-written tests (coverage is gameable,
   concern-specific mutants are not).
4. **Example → property promotion** (`pytest --promote`): mine constants from existing unit
   tests, propose the abstraction (Daikon-style + LLM intent), validate against examples and
   CrossHair counterexamples. "A property test is an example test with the constants abstracted."
5. **Metamorphic testing, packaged**: per-domain relation libraries + runner in
   fast-check/Hypothesis; LLMs propose relations; first taste for ML/multimedia/search teams.
6. **DST-lite for app code**: deterministic event loop for Node/Deno/browser tests with schedule
   exploration + shrinking ("model checking for async JS"); combine with XState machines + fault
   injection = a VOPR for frontends.
7. **Refactor-safety ladder** for agent migrations: record traces → replay old/new →
   `old(x) == new(x)` property → fuzz boundary → CrossHair `diffbehavior` → Alive2/Kani bounded
   equivalence where small. Makes churn safe.
8. **Static findings as failed tests** (with synthesized repro inputs); "sometimes assertions"
   as state-space coverage / vacuity detection.
9. **Budgeted escalation in CI**: examples per save, properties per push, fuzz/concolic nightly,
   BMC weekly; promotion/demotion by finding rate and flakiness.

### Popularisation artifacts that don't exist
- A one-page **ladder taxonomy** with the "+1 ingredient" between rungs in each ecosystem's tool names.
- A **bugs-per-CPU-hour benchmark** running example / property / coverage-guided / concolic / BMC
  on the same corpus of real dated bugs (Vericoding did this for proofs; nothing for testing rungs).

### Three to actually build
JS/TS unified harness with concolic backend; diff-scoped mutation score with LLM equivalence
filtering; example→property promotion.

---

## Key links
- RSC paper: https://dl.acm.org/doi/10.1145/2908080.2908110 · thesis: https://goto.ucsd.edu/~pvekris/docs/pvekris-thesis.pdf
- Flux: https://dl.acm.org/doi/10.1145/3591283 · repo: https://github.com/flux-rs/flux
- Usability Barriers for Liquid Types: https://doi.org/10.1145/3729327
- LHC (neurosymbolic inference): https://doi.org/10.1109/icse55347.2025.00090
- Refinement Type Refutations: https://gleissen.github.io/papers/refinement-refutations.pdf
- Generic Refinement Types: https://ranjitjhala.github.io/static/popl25-generic-refinements.pdf
- Gradual Refinement Types: https://dl.acm.org/doi/10.1145/3009837.3009856
- ConSORT: https://doi.org/10.1007/978-3-030-44914-8_25 · RefinedC: https://doi.org/10.1145/3453483.3454036
- verify-rust-std: https://github.com/model-checking/verify-rust-std · paper: https://arxiv.org/html/2606.17374
- Vericoding: https://arxiv.org/abs/2509.22908 · AlgoVeri: https://arxiv.org/html/2602.09464v1 · Vero: https://github.com/sunblaze-ucb/vero
- Aria (code agents proving Iris): https://arxiv.org/html/2607.06341v1
- SymCrypt Rust/Lean: https://arxiv.org/abs/2609.15648
- Intent Formalization: https://arxiv.org/pdf/2603.17150
- Oxide RFD 576: https://rfd.shared.oxide.computer/rfd/0576
- Anvil: https://www.usenix.org/conference/osdi24/presentation/sun-xudong
- Elixir v1.20: https://elixir-lang.org/blog/2026/06/03/elixir-v1-20-0-released/
- Stately MCP: https://stately.ai/docs/packages/mcp · Kiro specs: https://kiro.dev/docs/specs/feature-specs/ · Spec Kit: https://github.com/github/spec-kit
- PVSio-web: https://github.com/thehogfather/pvsio-web/
- Halide TRS verification: https://doi.org/10.1145/3428234 · GPUVerify: https://www.doc.ic.ac.uk/~afd/papers/2014/CAV.pdf
- Meta ACH: https://arxiv.org/abs/2501.12862
- Bolero unified interface: https://camshaft.github.io/bolero/features/unified-interface.html
- HypoFuzz: https://hypofuzz.com/ · CrossHair: https://github.com/pschanely/CrossHair
- Antithesis DST: https://antithesis.com/docs/resources/deterministic_simulation_testing/
- TigerBeetle protocol-aware DST: https://tigerbeetle.com/blog/2026-08-20-protocol-aware-dst/
- SpecPylot: https://arxiv.org/html/2604.16560
