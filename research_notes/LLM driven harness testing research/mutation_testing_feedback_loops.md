# Mutation testing and test-adequacy signals as the feedback loop for LLM-generated tests (2023 – Oct 2026)

**Method / provenance note.** Web search was the primary channel. The egress proxy in this session blocked direct fetches of arxiv.org, dl.acm.org, engineering.fb.com, alphaxiv, semanticscholar, researchgate, zenodo, infoq, sciencedirect, stryker-mutator.io and research.google.com; only github.com pages were fetchable. Consequently most numbers below come from search-engine summaries of the primary paper pages (URLs recorded), and a few from GitHub READMEs/issues that I did fetch in full. Items marked **[snippet]** were seen only in search summaries of the primary source; items marked **[fetched]** were verified against a page I retrieved. Where a figure's attribution to a specific paper was ambiguous in the summary, it is flagged. Vendor/self-reported figures are flagged as such.

---

## KQ1. Meta: TestGen-LLM (2024), ACH (2025), and 2025–2026 follow-ups

### Takeaway
Meta's line of work moved from coverage-filtered test *improvement* (TestGen-LLM, FSE 2024: 73% engineer acceptance in test-a-thons, but only 25% of generated tests actually raised coverage) to mutation-*driven* hardening (ACH, FSE 2025: LLM writes a small number of issue-specific mutants, an LLM agent filters equivalent ones at precision 0.79/recall 0.47 — 0.95/0.96 with simple pre-processing — and an LLM writes tests to kill the survivors; 73% acceptance again, 36% judged privacy-relevant). The 2025 keynote paper reframes this as "hardening" vs "catching" tests and poses the open "Catching JiTTest Challenge".

### Cited Findings

**TestGen-LLM — "Automated Unit Test Improvement using Large Language Models at Meta" (Alshahwan, Chheda, Finegenova, Gokkaya, Harman, Harper, Marginean, Sengupta, Wang; FSE 2024 industry track; arXiv Feb 2024)**
- Tool uses LLMs to *improve existing human-written tests*; it is the canonical "Assured LLM-based Software Engineering" pipeline: candidates must (1) build, (2) pass, (3) pass repeatedly (non-flaky), (4) increase coverage, before being shown to an engineer. **[snippet]** — [arXiv 2402.09171](https://arxiv.org/abs/2402.09171)
- Instagram Reels and Stories evaluation: 75% of generated test cases built correctly, 57% passed reliably, 25% increased coverage. **[snippet]** — [arXiv 2402.09171](https://arxiv.org/html/2402.09171v1)
- Instagram and Facebook test-a-thons: TestGen-LLM improved 11.5% of all classes to which it was applied; 73% of its recommendations were accepted for production deployment by Meta engineers. **[snippet]** — [arXiv 2402.09171](https://arxiv.org/html/2402.09171v1); summary mirror: [HuggingFace papers](https://huggingface.co/papers/2402.09171)
- Note: TestGen-LLM's adequacy signal is *coverage increase*, not mutation score; no mutation-score figures are reported in the summaries I saw (see Gaps).

**ACH — "Mutation-Guided LLM-based Test Generation at Meta" (Foster, Gulati, Harman, Harper, Mao, Ritchey, Robert, Sengupta; FSE 2025 industry track, DOI 10.1145/3696630.3728544; arXiv Jan 2025)**
- Design: ACH "generates relatively few mutants (simulated faults) compared to traditional mutation testing, and instead focuses on generating currently undetected faults specific to an issue of concern" (privacy is the worked example, but the authors state ACH can harden against any regression type). From those faults it generates tests that kill the mutants. **[snippet]** — [arXiv 2501.12862](https://arxiv.org/abs/2501.12862); [ACM DL](https://dl.acm.org/doi/10.1145/3696630.3728544)
- Loop as summarized by a third-party tool-design issue citing the paper: "surviving mutant + reaching tests → LLM writes killing test". **[fetched, secondary]** — [mutrim issue #63](https://github.com/illumination-k/mutrim/issues/63)
- Scale: applied to 10,795 Android Kotlin classes in 7 software platforms deployed by Meta; generated 9,095 mutants and 571 privacy-hardening test cases. **[snippet]** — [arXiv 2501.12862](https://arxiv.org/abs/2501.12862)
- Deployment/acceptance: used in Messenger and WhatsApp test-a-thons where engineers accepted 73% of its tests and judged 36% to be privacy-relevant. **[snippet]** — [arXiv 2501.12862 (search summary)](https://arxiv.org/pdf/2501.12862)
- Equivalent-mutant detection: an LLM-based equivalent-mutant detection agent achieves precision 0.79 and recall 0.47, "rising to 0.95 and 0.96 with simple pre-processing". **[snippet]** — [arXiv 2501.12862](https://arxiv.org/abs/2501.12862)
- Meta Engineering blog announcement, 5 Feb 2025: "Revolutionizing software testing: Introducing LLM-powered bug catchers" (ACH). Blocked from fetch; listed in awesome-mutation-testing. — [engineering.fb.com](https://engineering.fb.com/2025/02/05/security/revolutionizing-software-testing-llm-powered-bug-catchers-meta-ach/); [awesome-mutation-testing listing](https://github.com/theofidry/awesome-mutation-testing)
- Ratio implied by the reported counts: 571 tests from 9,095 mutants ≈ 6.3% of generated mutants yielded an engineer-facing hardening test (my arithmetic on the reported numbers; the paper's own per-stage attrition was not visible to me).

**2025–2026 follow-ups from Meta**
- "Harden and Catch for Just-in-Time Assured LLM-Based Software Testing: Open Research Challenges" (Harman, O'Hearn, Sengupta; written to accompany FSE 2025 keynote; arXiv Apr 2025). Defines *hardening* tests (protect against future regressions — what ACH produces) vs *catching* tests (catch a fault introduced by the current change), and poses the "Catching JiTTest Challenge": generate tests just-in-time on a pull request to catch new faults before landing; includes "initial results from work on automated LLM-based hardening at Meta". **[snippet]** — [arXiv 2504.16472](https://arxiv.org/abs/2504.16472); [UCL Discovery](https://discovery.ucl.ac.uk/id/eprint/10218053/)
- Meta Engineering blog, 30 Sep 2025, Mark Harman: "LLMs Are the Key to Mutation Testing and Better Compliance" (blocked from fetch; content not verified). — [engineering.fb.com](https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/); InfoQ coverage Jan 2026: [InfoQ](https://www.infoq.com/news/2026/01/meta-llm-mutation-testing/)
- A March 2026 arXiv paper "Boosting LLMs for Mutation Generation" (arXiv 2603.24560) surfaced alongside ACH in search; authorship/affiliation not verified. — [arXiv 2603.24560](https://arxiv.org/html/2603.24560v1)
- One search summary stated "Meta deployed LLM-based mutation testing using Llama 3.1 models in 2024"; I could not trace this to a primary page (it may originate from a vendor guide). Treat as unverified. — [Augment Code vendor guide (unfetched)](https://www.augmentcode.com/guides/mutation-testing-ai-generated-code)

### Inferences
- Both Meta systems report the same 73% acceptance rate, but the denominators differ: TestGen-LLM's candidates were pre-filtered by *coverage increase*, ACH's by *killing an LLM-written mutant*. ACH's extra "36% judged privacy-relevant" suggests that even mutant-killing tests are often accepted for general regression value rather than for the targeted concern.
- ACH's equivalent-mutant agent at recall 0.47 (before pre-processing) means roughly half of equivalent mutants would leak into the test-generation stage and waste LLM calls; the paper's claim that simple pre-processing lifts this to ~0.95 is the single most important engineering detail for anyone replicating the loop, and I could not see what the pre-processing is (Gap).
- The "Catching JiTTest" framing is Meta's acknowledgement that mutation-guided hardening does not by itself find the bug in the current diff — the mutation engine judges tests against *simulated* faults, not the real one.

### Gaps
- Could not fetch the ACH paper body: per-platform acceptance breakdown (Facebook/Instagram vs Messenger/WhatsApp), the human-labelled sample size behind P=0.79/R=0.47, what the "simple pre-processing" is, which LLM was used, fraction of generated tests that built/passed/killed, and time/cost per class.
- Could not fetch the Sept 2025 Meta blog or InfoQ Jan 2026 piece — any newer deployment numbers (2025–2026) are unrecorded.
- No mutation-score figures for TestGen-LLM; it is coverage-filtered only.

---

## KQ2. LLMs as mutant generators: MuTAP, LLMorpheus, LLM-vs-PIT/Major/μBERT, higher-order and "realistic" mutants

### Takeaway
Across the largest controlled study (851 real Java bugs), LLM-generated mutants couple to real faults far better than rule-based operators (≈52% coupling for LLMorpheus-style generation vs 23.5% for PIT, 38.9% Major, 47.3% μBERT; 1.8× real-bug detection) but pay for it with +26.6 pp non-compilable, +10.1 pp duplicate and +3.5 pp equivalent mutants. MuTAP (2023/24) was the first to close the loop (surviving mutant → prompt augmentation) and reports up to 28% more faulty snippets detected than SOTA/zero-shot baselines.

### Cited Findings

**MuTAP — "Effective Test Generation Using Pre-trained Large Language Models and Mutation Testing" (Dakhel et al.; arXiv Aug 2023; Information and Software Technology vol. 171, 107468, 2024)**
- LLMs: Codex and llama-2-chat; mutation tool: MutPy; benchmarks: HumanEval (163 tasks) and Refactory (5 tasks). **[fetched, repo README]** — [GitHub ExpertiseModel/MuTAP](https://github.com/ExpertiseModel/MuTAP); [IST article](https://www.sciencedirect.com/science/article/abs/pii/S0950584924000739)
- Loop: initial zero-/few-shot prompt → repair syntax and functional errors in generated tests → run MutPy → if survivors exist, augment the prompt with (a) the current test, (b) an instruction stating its shortcoming, (c) one surviving mutant, (d) a request for a new test; repeat until all mutants killed or no unused survivor remains. **[snippet]** — [arXiv 2308.16557](https://arxiv.org/abs/2308.16557)
- Result: detects up to 28% more faulty human-written code snippets; 17% remained undetected by both SOTA automated test generation tools and zero/few-shot LLM baselines. **[snippet]** — [arXiv 2308.16557](https://arxiv.org/abs/2308.16557)
- Later comparison point: CoverUp reports MuTAP reaching 77% overall line+branch coverage on the same Python benchmark where CoverUp reaches 90%. **[snippet]** — [arXiv 2403.16218](https://arxiv.org/html/2403.16218v3)

**LLMorpheus — "Mutation Testing using Large Language Models" (Tip, Bell, Schäfer; arXiv Apr 2024; IEEE TSE 2025)**
- Mechanism: replaces a code fragment with the token `PLACEHOLDER` and asks the LLM what could go there; parses fenced code blocks, validates syntax, writes `mutants.json`, then runs StrykerJS to classify killed/survived/timed-out. Experiments used codellama-13b-instruct, codellama-34b-instruct and mixtral-8x7b-instruct; reports token usage for prompts and completions. **[fetched, repo README]** — [GitHub neu-se/llmorpheus](https://github.com/neu-se/llmorpheus)
- Evaluated on 13 JavaScript subject packages; "capable of producing mutants that resemble existing bugs that cannot be produced by StrykerJS". **[snippet]** — [arXiv 2404.09952](https://www.arxiv.org/pdf/2404.09952); TSE preprint: [jonbell.net](https://www.jonbell.net/preprint/tse25-llmorpheus.pdf)

**"A Comprehensive Study on Large Language Models for Mutation Testing" (Bo Wang, Mingda Chen et al., Beijing Jiaotong; arXiv Jun 2024 as "An Exploratory Study…", later versions; ACM TOSEM, DOI 10.1145/3805038)**
- Setup: 7 LLMs vs Major, PIT, LEAM and μBERT on 851 real bugs (605 from Defects4J 2.0 + 246 from ConDefects). **[snippet]** — [arXiv 2406.09843](https://arxiv.org/pdf/2406.09843); [TOSEM](https://dl.acm.org/doi/pdf/10.1145/3805038)
- LLM mutants are more diverse and behaviourally closer to real bugs: 1.8× improvement in real-bug detection (proportion of real bugs whose faulty behaviour is mimicked by ≥1 mutant). **[snippet]** — [arXiv 2406.09843](https://arxiv.org/abs/2406.09843)
- Cost side: LLM mutants have worse non-compilability, duplication and equivalent-mutant rates by 26.60, 10.14 and 3.51 percentage points respectively. **[snippet]** — [arXiv 2406.09843](https://arxiv.org/abs/2406.09843)
- Coupling to real faults (later version): PIT 23.5%, Major 38.9%, LEAM 38.1%, μBERT 47.3%; LLMorpheus(DeepSeek-671b) 52.0%, LLMorpheus(GPT-4o) 51.7% — "LLMorpheus produces mutants whose failing behaviors align most closely with those of real bugs". **[snippet]** — [arXiv 2406.09843 v5](https://arxiv.org/html/2406.09843v5)
- Higher-order mutants: experiments with five LLMs found llama-3.3-70b-instruct and codellama-34b-instruct "generally produced the largest number of mutants and surviving mutants". **[snippet]** — [arXiv 2406.09843](https://arxiv.org/pdf/2406.09843)
- Third-party citation of the TOSEM version: LLM mutants achieve 87.98% fault detection vs 41.64% for rule-based operators, "though with higher compilation and duplication issues". **[fetched, secondary]** — [mutrim issue #63](https://github.com/illumination-k/mutrim/issues/63)

**Other LLM-mutant work 2025–2026**
- "Beyond Rule-Based Mutation Testing: Test-Aware Mutant Generation Using Large Language Models" (arXiv 2609.35841, Sep 2026): LLM receives problem statement, canonical solution and base tests; evaluated across LLMs including Gemini 3.1 Pro and Gemini 3 Flash. Numbers not retrieved. **[snippet]** — [awesomepapers.io listing](https://awesomepapers.io/ai-for-code/papers/2609.35841)
- "Exploring the Potential of Large Language Models in Simulink-Stateflow Mutant Generation" (arXiv 2602.04066, Feb 2026) — domain extension to model-based code. **[snippet]** — [arXiv 2602.04066](https://arxiv.org/html/2602.04066)
- "Boosting LLMs for Mutation Generation" (arXiv 2603.24560, Mar 2026) — title only. — [arXiv 2603.24560](https://arxiv.org/html/2603.24560v1)
- "A Declarative Framework for Hand-Crafted Mutation Analysis and Management" (arXiv 2603.07065, Mar 2026) — title only. — [arXiv 2603.07065](https://arxiv.org/pdf/2603.07065)
- Mutahunter (codeintegrity-ai, AGPL-3.0; ~300 stars, 27 forks, 126 commits; examples dated Mar 2025): LLM-generated, repo-map-aware mutants; README claims LLM mutants show "higher fault detection potential, fewer equivalent mutants, and higher coupling and semantic similarity to real faults" (vendor claim citing research). Example runs: 7 mutants, 57.14% mutation score, $0.00060, 29 s; 30 mutants (19 killed / 11 survived), 63.33%, $0.00167, 127 s. GPT-4o/4o-mini, Anthropic and self-hosted models via LiteLLM. **[fetched]** — [GitHub codeintegrity-ai/mutahunter](https://github.com/codeintegrity-ai/mutahunter); [fork README](https://github.com/RussPalms/mutahunter_dev/blob/main/README.md)

### Inferences
- The coupling-rate ordering (PIT < LEAM ≈ Major < μBERT < LLM) tracks how much *context* the generator sees: PIT's fixed operators see a bytecode instruction, μBERT sees a masked token window, LLMorpheus sees the whole function. The same context is what produces the +26.6 pp non-compilable rate, so a production loop needs a compile/duplicate/equivalence filter *before* the LLM test writer is invoked (this is exactly ACH's architecture).
- MuTAP's 17% "undetected by everything" figure is an early quantification that mutation-guided prompting does not saturate; later MutGen reaches ~89% mutation score on similar small-function benchmarks, suggesting the ceiling moved with model quality rather than loop design.

### Gaps
- LLMorpheus quantitative results (percent valid, kill/survive/timeout rates, cost per package, run-to-run variability) were not retrievable — only the qualitative "resembles bugs StrykerJS can't produce" claim.
- No study found that directly measures *higher-order* LLM mutants' coupling to real faults; only the count-based observation above.
- μBERT's own fault-detection figures vs PIT (Degiovanni & Papadakis 2022; Khanfir et al. 2023) are background and were not re-verified here.

---

## KQ3. Coverage-feedback loops (CoverUp, CodaMosa, HITS, TELPA, SymPrompt, ChatUniTest, TestPilot) and what they say about plateaus and fault detection

### Takeaway
Coverage-guided LLM loops reliably push structural coverage into the 80–90% range (CoverUp 90% line+branch vs MuTAP 77%; TestPilot median 70.2% statement), but the loops that report mutation score show it lagging badly (≈80% coverage ↔ ≈35% mutation score; plain-LLM 33.8% MS vs HITS 28.0% and SymPrompt 28.4% on one Java benchmark). Mutation-guided loops (MutGen, AdverTest, YATE) report 20%–60% more killed mutants than coverage-guided ones.

### Cited Findings

**CodaMosa (Lemieux, Inala, Lahiri, Sen; ICSE 2023)**
- Runs search-based testing (Pynguin/MOSA) until coverage stalls, then asks Codex for example tests for under-covered functions to redirect the search; evaluated on 27 Python projects; beats Pynguin and Codex alone on coverage. **[snippet]** — [Semantic Scholar](https://www.semanticscholar.org/paper/CodaMosa:-Escaping-Coverage-Plateaus-in-Test-with-Lemieux-Inala/f9b301daed4205af692a1b1389d86238610de270)
- Follow-on: EvoGPT (arXiv 2505.12424, May 2025) uses LLM-generated seeds to escape plateaus in EvoSuite-style search. **[snippet]** — [arXiv 2505.12424](https://arxiv.org/html/2505.12424)

**CoverUp (Altmayer Pizzorno & Berger; arXiv Mar 2024; FSE 2025, DOI 10.1145/3729398)**
- Prompts carry coverage analysis + code context + execution feedback; iteratively targets uncovered lines/branches. Overall line+branch coverage 90% vs MuTAP 77%; per-module median 80% vs CodaMosa 47%; the iterative coverage-guided component "contributes to nearly 40% of its successes". **[snippet]** — [arXiv 2403.16218](https://arxiv.org/html/2403.16218v3); [ACM](https://dl.acm.org/doi/10.1145/3729398)
- No mutation-score evaluation visible in the summaries I obtained (Gap).

**TestPilot (Schäfer, Nadi, Eghbali, Tip; TSE 2024; arXiv 2302.06527)**
- JavaScript; prompt = function signature + body + doc usage examples + framework scaffolding. With gpt-3.5-turbo: median statement coverage 70.2%, branch 52.8%. Median 61.4% of generated tests contain *non-trivial* assertions; those alone reach 61.6% median coverage. **[snippet]** — [arXiv 2302.06527](https://arxiv.org/abs/2302.06527); [TSE PDF](https://www.franktip.org/pubs/testpilot2024.pdf)

**HITS / TELPA / SymPrompt / ChatUniTest / TestSpark comparisons**
- "LLM Test Generation via Iterative Hybrid Program Analysis" (arXiv 2503.13580, Mar 2025): "TELPA and HITS do not consistently outperform each other, but both perform better than basic ChatUniTest". **[snippet]** — [arXiv 2503.13580](https://arxiv.org/pdf/2503.13580)
- YATE — "The Role of Test Repair in LLM-Based Unit Test Generation" (arXiv 2507.18316, Jul 2025): compares with HITS, SymPrompt, TestSpark and CoverUp; produces tests that kill 20% more mutants at comparable cost; method-level YATE killed 19.97% more mutants than HITS; reported mutation scores: Plain-LLM 33.82%, HITS 27.97%, SymPrompt 28.40%, TestSpark 16.48%. **[snippet]** — [arXiv 2507.18316](https://arxiv.org/html/2507.18316v1)
- HITS: "High-coverage LLM-based Unit Test Generation via Method Slicing" (arXiv 2408.11324). — [arXiv 2408.11324](https://arxiv.org/html/2408.11324v1)
- "How well LLM-based test generation techniques perform with newer LLM versions?" (arXiv 2601.09695, Jan 2026) — re-benchmarks these techniques on newer models; numbers not retrieved. — [arXiv 2601.09695](https://arxiv.org/abs/2601.09695)

**Mutation-guided loops that benchmark against coverage-guided ones**
- MutGen — "Mutation-Guided Unit Test Generation with a Large Language Model" (arXiv 2506.02954, Jun 2025, v8 later): puts surviving-mutant feedback directly in the prompt. Mutation score 89.5% on HumanEval-Java (1,144 mutants) and 89.1% on LeetCode-Java (1,900 mutants); 28.8% and 51.3% higher than EvoSuite; baselines are EvoSuite, EvoSuite_mut (strong-mutation fitness instead of coverage) and Gen_vanilla (LLM without mutation feedback). Reports a subject (HumanEval-Java id_81) with 100% line and branch coverage but only 4% mutation score. Token cost: fewer tokens than alternatives on HumanEval-Java, more on LeetCode-Java (table values 125.9 vs 149.4 — units not visible in the summary, likely thousands of tokens per subject; flagged). **[snippet]** — [arXiv 2506.02954](https://arxiv.org/abs/2506.02954); [v8 HTML](https://arxiv.org/html/2506.02954v8)
- A search summary attributed "removing the iterative mutation loop caused a 50% drop in fault detection rate, while the mutation-feedback approach reached 89.5%" to the MuTAP/MutGen family; the 89.5% is MutGen's; the 50% ablation figure's exact source is unverified. — [arXiv 2506.02954](https://arxiv.org/html/2506.02954v1)
- "Beyond Coverage: Automatic Test Suite Augmentation for Enhanced Effectiveness using Large Language Models" (PACMPL vol. 10, OOPSLA1, Apr 2026, DOI 10.1145/3798251): motivates with the observation that LLM suites reach ≈80% coverage but only ≈35% mutation score; criticises MuTAP/MutGen for evaluating only standalone methods; targets non-standalone methods with user-defined types. **[snippet]** — [ACM](https://dl.acm.org/doi/10.1145/3798251); supplementary: [Zenodo 18300435](https://zenodo.org/records/18300435)
- AdverTest — "Test vs Mutant: Adversarial LLM Agents for Robust Unit Test Generation" (Chang, Fang, Chen, Shi, Shen, Gu; arXiv 2602.08146, Feb 2026): test agent T and mutant agent M in an adversarial loop (M hacks T's blind spots, T kills M's mutants). On Defects4J: fault detection +8.56% over the best existing LLM method and +63.30% over EvoSuite, with higher line/branch coverage; ablations show both the iterative loop and mutant-guided feedback are necessary. **[snippet]** — [arXiv 2602.08146](https://arxiv.org/abs/2602.08146)
- PRIMG — "Efficient LLM-driven Test Generation Using Mutant Prioritization" (arXiv 2505.05584; ACM DOI 10.1145/3756681.3756991; Solidity): ML model trained on mutant-subsumption graphs ranks surviving mutants; LLM writes and iteratively repairs tests. Iterative compile/run/feedback loop raises correct-test share from 2–5% (single shot) to 28–40% at 5 iterations, no gain at 10. On three real Solidity projects a prioritized 50-test suite killed more mutants than three random 50-test suites (one project: 300 vs 200, 158, 8). **[snippet]** — [arXiv 2505.05584](https://arxiv.org/abs/2505.05584); [ACM](https://dl.acm.org/doi/10.1145/3756681.3756991)
- "Mutation Testing via Iterative Large Language Model-Driven Scientific Debugging" (Mutation 2025 workshop @ ICST 2025; arXiv 2503.08182): LLM is asked to kill each surviving mutant, optionally via a "scientific debugging" (hypothesis → experiment → test) protocol. Iterative and scientific variants both reach ≈60% success; scientific variants mark >15% of mutants as equivalent (baseline marks none); scientific variants need 3.51–3.63 turns vs 2.51 for plain iteration; baseline cost <US$0.001 and ≈5,000 tokens per mutant, iterative variants cache most tokens. LLMs beat Pynguin on fault detection at higher compute cost. **[snippet]** — [arXiv 2503.08182](https://arxiv.org/pdf/2503.08182); [ICST 2025 programme](https://conf.researchr.org/details/icst-2025/mutation-2025-papers/4/Mutation-Testing-via-Iterative-Large-Language-Model-driven-Scientific-Debugging)
- "Evaluating the effectiveness of class-level LLM-generated test suites in Python" (arXiv 2609.24341, Sep 2026): ClassEval benchmark, Cosmic Ray mutation scores; "structural coverage is consistently near its ceiling and offers little discrimination among configurations, and a suite can reach 100% line coverage while making no meaningful assertion about program behavior". **[snippet]** — [arXiv 2609.24341](https://arxiv.org/html/2609.24341v1)
- "Enhancing LLM-Based Test Generation by Eliminating Covered Code" (arXiv 2602.21997, Feb 2026) and "Type-aware LLM-based Regression Test Generation for Python" (arXiv 2503.14000) — coverage-loop variants; numbers not retrieved. — [arXiv 2602.21997](https://arxiv.org/html/2602.21997v1); [arXiv 2503.14000](https://arxiv.org/pdf/2503.14000)

### Inferences
- The coverage-loop papers (CodaMosa, CoverUp, HITS, TELPA, SymPrompt) mostly do not report mutation score; the papers that *do* (YATE, MutGen, Beyond Coverage, class-level Python) consistently find coverage saturating while mutation score stays at 28–35%. The field's own replication trend is toward mutation score as the headline metric.
- YATE's finding that a *plain* LLM (33.8% MS) beat coverage-optimised HITS/SymPrompt (28%) suggests coverage-targeted decomposition can trade assertion strength for reachability — a concrete instance of coverage being optimised at the expense of fault detection.

### Gaps
- No single benchmark comparing TestPilot, ChatUniTest, HITS, TELPA, SymPrompt, CoverUp and a mutation-guided loop on the same subjects with mutation score was found.
- CoverUp's mutation score (if any) is unknown to me.
- MutGen's token-cost units and absolute dollar cost not visible.

---

## KQ4. Is coverage gameable while mutation score is not? Tests that mirror bugs, assertion weakness, vacuous tests

### Takeaway
Two ISSTA 2026 papers from the same group (Zhao, Zhou, Cohen) give the sharpest answer: coverage *and* mutation score are meaningful adequacy signals only in regression settings where the code under test is assumed correct; when the code is buggy, LLM-generated tests are "misguided" into asserting the bug and both metrics stop predicting bug exposure. A 22,374-variant study shows >99% of LLM tests that fail after a semantic change still pass on the *original* program — the tests encode the old behaviour, not a specification.

### Cited Findings
- "Do Coverage and Mutation Scores of LLM-Generated Test Suites Correlate with Their Effectiveness? (Replicability Study)" (Junda Zhao, Shurui Zhou, Eldan Cohen; PACMSE 3, ISSTA 2026, Article ISSTA002; arXiv 2607.22880): Defects4J harness with JaCoCo (coverage), PIT (mutation) and CodeCover (MC/DC). Conclusion: "the usefulness of coverage and mutation is highly context-dependent: in regression-style settings where the code provided to the LLM can be reasonably assumed bug-free, these metrics can provide meaningful signals when comparing across models; however, in scenarios where the code-under-test may already be buggy and the goal is to expose the bug, they no longer serve as reliable indicators." Uses Gemini 2.5 Flash among models. **[snippet]** — [arXiv 2607.22880](https://arxiv.org/abs/2607.22880); replication: [Zenodo 21437945](https://zenodo.org/records/21437945)
- "Evaluating and Mitigating the Misguidance Effect of Buggy Code in LLM-Generated Unit Tests" (Zhao et al.; PACMSE 3, ISSTA 2026; arXiv 2607.22883): defines a metric for the "misguidance effect"; prompting with buggy code "significantly increases misguided tests that assert incorrect behavior while simultaneously suppressing the generation of effective, bug-finding tests"; mitigation replaces the code in the prompt with an LLM-generated specification docstring, reducing misguided tests and increasing effective ones for both buggy and bug-free code. **[snippet]** — [arXiv 2607.22883](https://arxiv.org/abs/2607.22883); replication: [Zenodo 21428156](https://zenodo.org/records/21428156)
- "Evaluating LLM-Based Test Generation Under Software Evolution" (arXiv 2603.23443, Mar 2026): 8 LLMs, 22,374 program variants; mutation-driven framework with semantic-altering changes (SAC) and semantic-preserving changes (SPC). Under SAC, pass rate of newly generated tests drops to 66% and branch coverage to 60%; "more than 99% of failing SAC tests pass on the original program while executing the modified region", i.e., tests align with the original behaviour rather than the new semantics. Under SPC (no behaviour change) pass rates still fall to 79% and coverage to 69%. **[snippet]** — [arXiv 2603.23443](https://arxiv.org/html/2603.23443v1)
- "On the risk of coding before testing: An empirical study on LLM-based test generation workflow" (arXiv 2607.05139, Jul 2026) and "Measuring the Influence of Incorrect Code on Test Generation" (ACM DOI 10.1145/3744916.3764532) — same theme; numbers not retrieved. — [arXiv 2607.05139](https://arxiv.org/pdf/2607.05139); [ACM](https://dl.acm.org/doi/10.1145/3744916.3764532)
- "How effective are traditional test criteria at detecting bugs in large language models generated code?" (arXiv 2609.09315, Sep 2026) — title only. — [arXiv 2609.09315](https://arxiv.org/pdf/2609.09315)
- "Adversarial Test-Hardening for AI-Written Code: An Instrument Autopsy and a Pre-Registered Causal Estimate of the Critic Loop" (arXiv 2607.23002, Jul 2026) — title only; appears to be a pre-registered study of an adversarial critic loop for AI-written code. — [arXiv 2607.23002](https://arxiv.org/pdf/2607.23002)
- "From Business Requirements to Test Assertions: Evaluating LLM-Generated Oracles on Real Bugs" (arXiv 2607.10277, Jul 2026): derives oracles from natural-language requirements rather than code, to avoid mirroring the implementation. — [arXiv 2607.10277](https://arxiv.org/html/2607.10277v1)
- MutGen's id_81 example — 100% line and branch coverage, 4% mutation score — is the most-cited single data point for "coverage is gameable". **[snippet]** — [arXiv 2506.02954](https://arxiv.org/html/2506.02954v8)
- TestPilot's "non-trivial assertion" split (61.4% of tests) is an early (2023) explicit acknowledgment that a substantial share of LLM tests are vacuous. **[snippet]** — [arXiv 2302.06527](https://arxiv.org/abs/2302.06527)
- Oxide RFD 576 "Using LLMs at Oxide" (Bryan Cantrill) exists at rfd.shared.oxide.computer/rfd/0576 and was discussed on Hacker News (Dec 2025); I could not fetch the RFD or HN threads, and a GitHub issue that excerpts the RFD contains no passage about tests mirroring bugs. The specific "LLM tests mirror the bugs in the code" wording could not be verified as RFD text. — [RFD 576](https://rfd.shared.oxide.computer/rfd/0576); [HN](https://news.ycombinator.com/item?id=46178347); [HN 2](https://news.ycombinator.com/item?id=46182998); [fullsend issue #244 (fetched, no test passage)](https://github.com/fullsend-ai/fullsend/issues/244)

### Inferences
- The ISSTA 2026 pair shows that mutation score is *not* immune to gaming in the way often assumed: a test that asserts a buggy return value still kills mutants of that buggy line (the mutant changes the value, the test notices). Mutation score measures *sensitivity to change*, not *correctness of the oracle*. So the "LLM as driver, mutation engine as judge" loop guarantees non-vacuity, not truth — the oracle still has to come from somewhere other than the code under test (spec docstrings, requirements, properties).
- The >99% figure from the evolution study is the quantitative form of the "tests mirror the implementation" concern: regenerated tests are essentially characterisation tests.

### Gaps
- No correlation coefficients (Spearman/Kendall) from the replicability study were visible to me; only its qualitative conclusion.
- Oxide RFD 576's exact text on tests was not retrievable.

---

## KQ5. Equivalent-mutant detection with LLMs; incremental/diff-scoped mutation testing; Google's industrial reports

### Takeaway
Fine-tuned code-embedding LLMs detect equivalent mutants at ≈94% precision / ≈82% recall / F1 ≈86.6% (Java, MutantBench), beating compiler-based TCE by 75% (Java) to 558% (C) in F1 — but this is a classifier on *given* mutant pairs; Meta's production agent, which must decide on LLM-generated mutants in the wild, sits at P 0.79 / R 0.47 before pre-processing. Diff-scoped mutation is mature in Stryker (incremental, `--since`/`--diff`), PIT (history files) and Mutahunter (`--diff`), and Google has run diff-scoped mutation in code review at a scale of ~17M mutants / 760k changes — with no LLM component found in the published Google work.

### Cited Findings

**LLM equivalent-mutant detection**
- "Large Language Models for Equivalent Mutant Detection: How Far Are We?" (Zhao Tian, Honglin Shu, Dong Wang, Xuejie Cao, Yasutaka Kamei, Junjie Chen; ISSTA 2024, Vienna; ACM SIGSOFT Distinguished Paper Award; arXiv 2408.01760). Dataset MutantBench (Java; train/test split; 28 mutation operators). Models: CodeBERT, CodeLlama, CodeT5, CodeT5+, GraphCodeBERT, PLBART, StarCoder, UniXcoder, GPT-3.5-Turbo, GPT-4, text-embedding-ada-002/3-small/3-large; five strategies (zero-shot, few-shot, fine-tune+instruction, pre-trained embedding, fine-tuned embedding). **[fetched, repo README]** — [GitHub tianzhaotju/EMD](https://github.com/tianzhaotju/EMD); [ACM](https://dl.acm.org/doi/10.1145/3650212.3680395)
- Best results (Java): fine-tuned UniXcoder (110M) embedding — precision 94.33%, recall 81.81%, F1 86.58%; GPT-3.5-Turbo fine-tuned with instruction — precision 92.82%, recall 76.95%, F1 82.31%. Fine-tuned UniXcoder improves F1 by 1.16%–84.10% over other LLM/strategy combinations. CodeT5+ and UniXcoder reach 96.02% precision; CodeT5+ and StarCoder reach 75.70% recall (per-strategy maxima). Embedding strategies beat prompting strategies by 55.81% (precision), 41.50% (recall), 54.21% (F1) on average. **[snippet]** — [arXiv 2408.01760](https://arxiv.org/pdf/2408.01760); [author PDF](https://posl.ait.kyushu-u.ac.jp/~kamei/publications/Tian_ISSTA2024.pdf)
- Third-party summary: LLM-based detection improves F1 by 35.7% over prior methods; another summary gives detection rate 77.4% vs 41.6% for rule-based (source attribution for the 77.4/41.6 pair is unclear — flagged). **[fetched, secondary]** — [mutrim issue #63](https://github.com/illumination-k/mutrim/issues/63); **[snippet]** — [ACM](https://dl.acm.org/doi/10.1145/3650212.3680395)
- Extended study: "Large Language Models for Multi-Lingual Equivalent Mutant Detection: An Extended Empirical Study" (Shu, Tian, Wang, Yu, Zhang, Cao, Chen, Kamei; arXiv 2607.00511, Jul 2026): 3,302 Java and 1,088 C mutant pairs; LLMs beat all ten EMD baselines; average F1 gains of 75.18% (Java) / 557.79% (C) over compiler-based (TCE-style), 19.14% / 7.21% over ML-based, 12.75% / 48.83% over tree-based NN; fine-tuned code embedding is best; also studies efficiency and cross-lingual transfer of fine-tuned models. **[snippet]** — [arXiv 2607.00511](https://arxiv.org/abs/2607.00511)
- "Cluster Purge Loss: Structuring Transformer Embeddings for Equivalent Mutants Detection" (arXiv 2507.20078, Jul 2025) — embedding-space objective for EMD. — [arXiv 2507.20078](https://arxiv.org/abs/2507.20078)
- GEM-LLM — "Identifying contextual equivalent mutants via large language models; a global invariant-based approach" (Intelligent Systems with Applications, 2026): combines LLMs with SMT solving; classifies 25%–30% of overlooked surviving mutants as equivalent with 98% precision. **[snippet]** — [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S2667305326000153)
- Meta ACH production agent: P 0.79 / R 0.47, 0.95 / 0.96 after pre-processing (see KQ1). — [arXiv 2501.12862](https://arxiv.org/abs/2501.12862)
- Scientific-debugging loop: LLM flags >15% of mutants as equivalent during test generation (no ground truth given). — [arXiv 2503.08182](https://arxiv.org/pdf/2503.08182)

**Incremental / diff-scoped mutation testing**
- StrykerJS `--incremental`: stores `reports/stryker-incremental.json`, performs a git-like diff of code and test files against the previous report, reuses a result when (a) the mutant was killed and its killing test is unchanged, or (b) it survived with no new covering tests and unchanged existing tests; `--force` reruns everything in scope; `--mutate src/app.js:5-7` restricts to line ranges. Limitations: changes outside mutated/test files are not detected; test-file tracking depends on runner plugin (Jest/Vitest full location reporting, Mocha per-file, Command runner none); dependency/env/config changes not monitored; static mutants lack coverage info. **[fetched]** — [stryker-js docs/incremental.md](https://github.com/stryker-mutator/stryker-js/blob/master/docs/incremental.md)
- Stryker.NET `--diff` / `--git-source`: mutate only files changed vs a branch; merged 15 Nov 2019; file-level only ("LibGit2Sharp doesn't seem to have a way to provide us with usable spans"); any test-file change forces full-project mutation; designed for PR builds. The approach was "inspired by incremental analysis based on the PIT implementation" (PIT history files). **[fetched]** — [stryker-net PR #708](https://github.com/stryker-mutator/stryker-net/pull/708)
- Third-party CI guide claim: PR runs use incremental mutation over changed files, main runs full-repo post-merge; incremental "can reduce mutation testing time from 30 minutes to under 2 minutes on typical PRs" (unverified blog claim). **[snippet]** — [specstory](https://specstory.com/learning/test-quality/diff-scoped-mutation-testing); [oneuptime blog](https://oneuptime.com/blog/post/2026-01-25-mutation-testing-with-stryker/view)
- Mutahunter `--diff`: mutation testing on "modified files and lines based on the latest commit or pull request changes"; also an "LLM Surviving Mutants Analysis" that explains survivors. **[fetched]** — [mutahunter_dev README](https://github.com/RussPalms/mutahunter_dev/blob/main/README.md)
- mutrim (Go mutation tester using type-checking + AST hashing): issue #63 (22 Sep 2026) proposes `gen -extra mutants.json` to import LLM/"wild-caught" mutants and `export-survivors` (unified diff + enclosing function + reaching tests) so an external LLM can propose killing tests or equivalence verdicts; rule-based operators remain default. An example of the tooling ecosystem converging on the "mutation engine as judge, LLM as external driver" interface. **[fetched]** — [mutrim issue #63](https://github.com/illumination-k/mutrim/issues/63)
- Tool landscape (awesome-mutation-testing): cargo-mutants (Rust), mutmut and Cosmic Ray (Python), StrykerJS, PIT, and for Elixir "mutation" (JordiPolo); the only LLM items listed are the two Meta blog posts and the ACH paper. **[fetched]** — [awesome-mutation-testing](https://github.com/theofidry/awesome-mutation-testing)

**Google (background, pre-2023; no LLM component found)**
- "State of Mutation Testing at Google" (Petrović & Ivanković, ICSE-SEIP 2018): used by 6,000 engineers, processed ~30% of all diffs with statement coverage. **[snippet]** — [Google Research pub 46584](https://research.google/pubs/pub46584/)
- "Practical Mutation Testing at Scale: A view from Google" (Petrović, Ivanković, Fraser, Just; TSE 2021; arXiv 2102.11378): code-review-based setting, >24,000 developers, >1,000 projects; evaluated on almost 17 million mutants and 760,000 changes, surfacing 2 million mutants during code review in Critique; diff-based (mutants only for changed code), with mutants filtered/selected by historical operator performance and "arid node" suppression. **[snippet]** — [TSE](https://dl.acm.org/doi/abs/10.1109/TSE.2021.3107634); [arXiv 2102.11378](https://arxiv.org/pdf/2102.11378)
- "Does mutation testing improve testing practices?" (ICSE 2021; arXiv 2103.07189) — background. — [arXiv 2103.07189](https://arxiv.org/pdf/2103.07189)
- No 2023–2026 publication from Google adding LLM mutant generation or LLM equivalent-mutant filtering to this system was found (Gap).

### Inferences
- The academic EMD numbers (F1 ≈ 0.87) and Meta's production number (F1 ≈ 0.59 at P 0.79/R 0.47) differ by the distribution: MutantBench pairs come from classical operators, whereas ACH judges LLM-written mutants that are more often subtly equivalent (Wang et al. +3.5 pp equivalent rate). Anyone building the loop should expect the lower figure unless they add the kind of pre-processing Meta reports.
- Diff scoping is what made Google's and Meta's deployments tractable; Stryker's incremental mode and Mutahunter's `--diff` give the same property to OSS pipelines, but none of the OSS tools ships an LLM equivalence filter (Mutahunter only *explains* survivors).

### Gaps
- Google: no LLM component found; whether Mutagenesis uses ML for mutant selection beyond historical operator statistics was not confirmed.
- PIT's own git-diff / history-file documentation was not fetched (stryker-net PR cites it).
- No "Codecov for mutants"-style SaaS product with LLM filtering was identified in the searches performed.

---

## KQ6. Mutation testing combined with property-based tests or fuzzing harness quality

### Takeaway
The intersection is thin. LLM-written property-based tests have been evaluated for validity/soundness/property coverage (GPT-4 synthesises a correct PBT for 21% of documented properties; a valid and sound PBT in 2.4 samples on average), and PBT has been used as the closed-loop oracle for LLM *code* generation (+23–37% relative pass@1), but I found no paper that uses mutation score to grade LLM-generated properties, and nothing on mutation-based assessment of LLM-generated fuzz harnesses.

### Cited Findings
- "Can Large Language Models Write Good Property-Based Tests?" (Vikram, Lemieux, Sunshine, Padhye; arXiv Jul 2023): two prompting techniques; evaluates validity, soundness and property coverage; best model/prompt yields a valid and sound PBT in 2.4 samples on average; GPT-4 synthesises correct PBTs for 21% of properties extractable from API documentation. **[snippet]** — [arXiv 2307.04346](https://arxiv.org/pdf/2307.04346)
- "Property-Based Mutation Testing" (arXiv 2301.13615, Jan 2023; ICST 2023): formalises mutant killability in terms of a property being satisfied by the original and violated by the mutant — a non-LLM foundation for grading property suites by mutation. **[snippet]** — [arXiv 2301.13615](https://arxiv.org/abs/2301.13615)
- "From Prompts to Properties: Rethinking LLM Code Generation with Property-Based Testing" (FSE 2025 companion, DOI 10.1145/3696630.3728702): PBT applied to StarCoder/CodeLlama outputs on MBPP and HumanEval; 30–32% of solutions only partially satisfy correctness properties and 18–23% fail outright despite moderate pass@k. **[snippet]** — [ACM](https://dl.acm.org/doi/10.1145/3696630.3728702)
- "Use Property-Based Testing to Bridge LLM Code Generation and Validation" / Property-Generated Solver (arXiv 2506.18315, Jun 2025): PBT as the core validator in an iterative closed loop; +23.1% to +37.3% relative pass@1 over TDD-style methods. **[snippet]** — [arXiv 2506.18315](https://arxiv.org/html/2506.18315v1)
- "Understanding the Characteristics of LLM-Generated Property-Based Tests in Exploring Edge Cases" (arXiv 2510.25297, Oct 2025) — characterises LLM PBTs; numbers not retrieved. — [arXiv 2510.25297](https://arxiv.org/pdf/2510.25297)
- "LLM-Based Property-Based Test Generation for Guardrailing Cyber-Physical Systems" (Springer 2025): evaluates relevance (match to manual properties), executability, and effectiveness (input-partition coverage) — not mutation. **[snippet]** — [Springer](https://link.springer.com/chapter/10.1007/978-3-032-07132-3_3)
- "MR-Coupler: Automated Metamorphic Test Generation via Functional Coupling Analysis" (arXiv 2604.10126, Apr 2026): per-target-method cost $0.09 (GPT-4o-mini), $0.23 (Qwen3-coder-Flash), $0.10 (DeepSeek-V3.1), $0.40 (DeepSeek-V3.1-Think) — metamorphic relations are the closest relative to properties for which cost data was found. **[snippet]** — [arXiv 2604.10126](https://arxiv.org/pdf/2604.10126)

### Inferences
- Property-Based Mutation Testing (2023) plus LLM PBT generation (2023–2025) are the two halves of a "mutation-graded LLM properties" loop, but nobody appears to have published the combination; this is an open niche directly relevant to harness/property work.

### Gaps
- No paper found using mutation score (or killed-mutant sets) to evaluate LLM-generated properties or LLM-generated fuzz harnesses (e.g., OSS-Fuzz-gen style). Search budget ran out before a dedicated fuzzing-harness query could run.

---

## KQ7. Token / dollar cost of mutation-guided loops vs direct prompting

### Takeaway
Reported costs span three orders of magnitude depending on granularity: <US$0.001 and ≈5k tokens per mutant for a single-shot kill attempt; cents per target method for metamorphic/mutation loops with small models; ≈$0.72 vs $0.07 per target class for self-refinement vs zero-shot at frontier pricing ($5/$15 per M tokens). Iteration count saturates early (PRIMG: 5 rounds optimal, no gain at 10; scientific-debugging: 2.5–3.6 turns per success).

### Cited Findings
- Self-refinement vs zero-shot: at $5.00/M input and $15.00/M output tokens, self-refinement cost $46.62 vs $4.78 for zero-shot across the benchmark, i.e. ≈$0.72 vs $0.07 per target class. Source paper is one of the 2025–2026 LLM test-generation papers returned for the cost query (most likely the NLP-libraries study, arXiv 2609.14784); attribution flagged as uncertain. **[snippet]** — [arXiv 2609.14784](https://arxiv.org/pdf/2609.14784)
- Scientific-debugging mutation loop: baseline <US$0.001 and ≈5,000 tokens per mutant; iterative variants cache most input tokens because module and mutant are unchanged across turns; scientific variants are "significantly more expensive" for similar ≈60% success. **[snippet]** — [arXiv 2503.08182](https://arxiv.org/pdf/2503.08182)
- MutGen: fewer tokens than alternatives on HumanEval-Java, more on LeetCode-Java, "while achieving higher mutation scores as well as better line and branch coverage" (table values 125.9 vs 149.4, units not visible). **[snippet]** — [arXiv 2506.02954](https://arxiv.org/html/2506.02954v8)
- PRIMG: correct-test rate 2–5% single-shot → 28–40% at 5 refinement iterations, flat at 10; prioritisation lets a 50-test budget kill 300 mutants vs 8–200 for random selection. **[snippet]** — [arXiv 2505.05584](https://arxiv.org/abs/2505.05584)
- YATE: kills 20% more mutants than HITS/SymPrompt/TestSpark/CoverUp "at comparable cost". **[snippet]** — [arXiv 2507.18316](https://arxiv.org/html/2507.18316v1)
- Mutahunter example runs: $0.00060 for 7 mutants (29 s); $0.00167 for 30 mutants (127 s) with GPT-4o-mini-class models (vendor README examples, not a benchmark). **[fetched]** — [Mutahunter](https://github.com/codeintegrity-ai/mutahunter)
- MR-Coupler per target method: $0.09–$0.40 depending on model. **[snippet]** — [arXiv 2604.10126](https://arxiv.org/pdf/2604.10126)
- Meta ACH: no cost figures visible; the paper's design choice of generating "relatively few mutants" is itself a cost control. — [arXiv 2501.12862](https://arxiv.org/abs/2501.12862)

### Inferences
- A mutation-guided loop costs roughly (number of surviving mutants after equivalence filtering) × (2.5–5 LLM turns) × (per-turn tokens, mostly cacheable input). The dominant lever is therefore the equivalence/duplicate filter and mutant prioritisation (ACH, PRIMG), not the per-turn price.
- No paper was found that directly prices a mutation-guided loop against a "find the bugs by inspection" prompt on the same subjects; the closest proxies are self-refinement-vs-zero-shot (≈10×) and scientific-vs-iterative (more turns, same success).

### Gaps
- No direct cost comparison of mutation-guided generation vs a single bug-finding prompt.
- ACH, TestGen-LLM, LLMorpheus and AdverTest cost figures not retrieved.
- Exact source of the $46.62/$4.78 figure needs confirmation.

---

## Quick index of items (venue / date / URL)

| Item | Venue / date | URL |
|---|---|---|
| TestGen-LLM (Alshahwan et al.) | FSE 2024 industry; arXiv Feb 2024 | https://arxiv.org/abs/2402.09171 |
| ACH (Foster, Harman et al.) | FSE 2025 industry; arXiv Jan 2025; DOI 10.1145/3696630.3728544 | https://arxiv.org/abs/2501.12862 |
| Harden and Catch (Harman, O'Hearn, Sengupta) | FSE 2025 keynote paper; arXiv Apr 2025 | https://arxiv.org/abs/2504.16472 |
| Meta blog: LLM-powered bug catchers (ACH) | 5 Feb 2025 | https://engineering.fb.com/2025/02/05/security/revolutionizing-software-testing-llm-powered-bug-catchers-meta-ach/ |
| Meta blog: LLMs Are the Key to Mutation Testing… (Harman) | 30 Sep 2025 | https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/ |
| MuTAP (Dakhel et al.) | IST 171:107468, 2024; arXiv Aug 2023 | https://arxiv.org/abs/2308.16557 |
| LLMorpheus (Tip, Bell, Schäfer) | IEEE TSE 2025; arXiv Apr 2024 | https://www.arxiv.org/abs/2404.09952 |
| Comprehensive Study on LLMs for Mutation Testing (Wang, Chen et al.) | ACM TOSEM (DOI 10.1145/3805038); arXiv Jun 2024 | https://arxiv.org/abs/2406.09843 |
| LLMs for Equivalent Mutant Detection (Tian et al.) | ISSTA 2024, Distinguished Paper | https://arxiv.org/abs/2408.01760 |
| Multi-lingual EMD extended study (Shu et al.) | arXiv Jul 2026 | https://arxiv.org/abs/2607.00511 |
| GEM-LLM | Intelligent Systems with Applications 2026 | https://www.sciencedirect.com/science/article/pii/S2667305326000153 |
| CodaMosa (Lemieux et al.) | ICSE 2023 | https://www.semanticscholar.org/paper/f9b301daed4205af692a1b1389d86238610de270 |
| CoverUp (Altmayer Pizzorno, Berger) | FSE 2025 (DOI 10.1145/3729398); arXiv Mar 2024 | https://arxiv.org/abs/2403.16218 |
| TestPilot (Schäfer et al.) | TSE 2024; arXiv Feb 2023 | https://arxiv.org/abs/2302.06527 |
| HITS | arXiv Aug 2024 | https://arxiv.org/abs/2408.11324 |
| YATE | arXiv Jul 2025 | https://arxiv.org/abs/2507.18316 |
| MutGen | arXiv Jun 2025 (v8 2026) | https://arxiv.org/abs/2506.02954 |
| Beyond Coverage (test-suite augmentation) | OOPSLA1 2026 (PACMPL 10) | https://dl.acm.org/doi/10.1145/3798251 |
| AdverTest / Test vs Mutant | arXiv Feb 2026 | https://arxiv.org/abs/2602.08146 |
| PRIMG | arXiv May 2025; ACM DOI 10.1145/3756681.3756991 | https://arxiv.org/abs/2505.05584 |
| Scientific-debugging mutation loop | Mutation 2025 @ ICST; arXiv Mar 2025 | https://arxiv.org/abs/2503.08182 |
| Replicability: coverage/mutation vs effectiveness (Zhao, Zhou, Cohen) | ISSTA 2026 | https://arxiv.org/abs/2607.22880 |
| Misguidance effect of buggy code (Zhao et al.) | ISSTA 2026 | https://arxiv.org/abs/2607.22883 |
| Test generation under software evolution | arXiv Mar 2026 | https://arxiv.org/abs/2603.23443 |
| Class-level Python LLM test suites (Cosmic Ray) | arXiv Sep 2026 | https://arxiv.org/abs/2609.24341 |
| Can LLMs write good PBTs (Vikram et al.) | arXiv Jul 2023 | https://arxiv.org/abs/2307.04346 |
| Property-Based Mutation Testing | ICST 2023; arXiv Jan 2023 | https://arxiv.org/abs/2301.13615 |
| Google: Practical Mutation Testing at Scale | TSE 2021 (background) | https://arxiv.org/abs/2102.11378 |
| Mutahunter | GitHub, AGPL-3.0, ~2024–2025 | https://github.com/codeintegrity-ai/mutahunter |
| StrykerJS incremental | docs | https://github.com/stryker-mutator/stryker-js/blob/master/docs/incremental.md |
| Stryker.NET --diff | PR merged Nov 2019 | https://github.com/stryker-mutator/stryker-net/pull/708 |
| mutrim issue #63 (LLM mutant import / survivor export) | 22 Sep 2026 | https://github.com/illumination-k/mutrim/issues/63 |
| Oxide RFD 576 | Dec 2025 (unfetched) | https://rfd.shared.oxide.computer/rfd/0576 |
