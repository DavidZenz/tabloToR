# Phase 2: Compatibility and Numerical Baseline - Context

**Gathered:** 2026-09-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Create executable contracts for the existing GEModel workflow, supported model state, outputs, serialization, sparse numerical equivalence, and mutation safety before any package rename or API narrowing. This phase may repair unintended divergence needed to establish one coherent baseline, but it does not rename the package, redesign solver methodology, make C++ the default, publish proprietary data, or perform release work.

</domain>

<decisions>
## Implementation Decisions

### Compatibility boundary

- **D-01:** Freeze an explicit supported contract covering the documented workflow and an enumerated set of GEModel methods, fields, arguments, defaults, outputs, and serialization behavior.
- **D-02:** Classify the observed surface into `supported`, `compatibility-only`, and `internal`. Compatibility-only behavior remains tested but may later follow a documented deprecation path.
- **D-03:** Guarantee both closure/shock workflows. Preserve the `variableValues` workflow exactly while making `setClosure()` and `setShocks()` the preferred documented workflow.
- **D-04:** Freeze full output structure: names, classes, dimensions, ordering, compact/full selection behavior, and missing/zero conventions. Compare numeric values under the separate numerical tolerance policy.

### Numerical authority

- **D-05:** Use sparse-first layered authority. Matrix sparse is the reference for generic sparse solves; structured R is the reference for structured C++ solves. Legacy is only a small-fixture public-workflow compatibility smoke path, not a numerical oracle.
- **D-06:** Every accepted backend result must independently pass a full-system true-residual gate.
- **D-07:** Use fixture/conditioning tolerance tiers: one strict default for ordinary redistributable fixtures and explicit, justified exceptions for ill-conditioned cases. Tolerances must not be loosened merely because a backend is C++.
- **D-08:** Backend equivalence requires exact structural output parity, finite values, absolute-plus-relative solution comparison, and independently recomputed true residuals.
- **D-09:** Fixtures declare required and optional backends. Required paths must execute; unavailable optional C++ or OpenMP paths must emit explicit, tested skip reasons rather than silently passing.

### Fixture and artifact portfolio

- **D-10:** Use a layered fixture portfolio: tiny algebraic systems for exact edge cases, a redistributable synthetic three-region TABLO workflow, SmallAg/debug only after redistribution is verified, and fingerprinted external reduced/full GTAP benchmarks.
- **D-11:** Commit compact, transparent artifacts: fixture fingerprints, solver metadata, structural expectations, selected canonical output values, and tolerances in reviewable text or CSV formats. Regenerate full solutions during tests; do not commit opaque complete solved-model snapshots as numerical goldens.
- **D-12:** Baseline changes require an explicit reviewed refresh. A deterministic command must generate proposed old/new artifacts and a readable diff; tests never rewrite canonical baselines automatically. Acceptance records the reason and reviewer.
- **D-13:** Tiny and synthetic three-region fixtures gate ordinary package checks. Redistributable SmallAg may gate extended checks after clearance. Reduced/full GTAP remain external benchmark and release gates.

### Failure and state semantics

- **D-14:** Compilation, factorization, convergence, finiteness, or residual failure is transactional. Caller-visible closure, shocks, levels, applied-shock progress, prior successful outputs, and caches remain unchanged; only structured failure diagnostics may be recorded.
- **D-15:** If the numerical solve is accepted but requested post-simulation processing fails, preserve the valid solved levels and diagnostics, mark post-simulation output failed/incomplete, and support retrying post-simulation without solving again. Never expose partial post-simulation updates.
- **D-16:** Serialization preserves portable logical state: source/model identity, loaded mutable levels, closure, shocks, accepted solution/output state, and diagnostics. Native pointers, factors, caches, and workspaces are excluded and rebuilt lazily.
- **D-17:** Characterize current consecutive-solve and shock-consumption behavior, then require `variableValues` and `setShocks()` to follow one explicitly documented application rule. Repair unintended divergence before accepting the baseline rather than preserving backend-specific behavior.

### the agent's Discretion

- Choose the exact compatibility-manifest schema and test organization while preserving the three contract tiers.
- Derive strict default and documented ill-conditioned tolerances from existing evidence and characterization; current `1e-8` synthetic and `2e-7` full-GTAP gates are starting evidence, not automatic final values.
- Choose reviewable baseline file formats, fingerprint algorithms, and deterministic refresh tooling.
- Choose a portable serialization implementation and an efficient transactional-state mechanism that does not violate the sparse-path memory constraint.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product, requirements, and prior decisions

- `.planning/PROJECT.md` — Product direction, compatibility constraints, backend policy, and phase boundaries.
- `.planning/REQUIREMENTS.md` — COMP-01 through COMP-03 and NUM-01 through NUM-02 acceptance requirements.
- `.planning/ROADMAP.md` — Phase 2 goal and success criteria.
- `.planning/phases/01-provenance-and-release-boundary/01-CONTEXT.md` — Data-distribution, public-release, package-identity, and provenance boundaries inherited from Phase 1.

### Existing package and public workflow

- `README.md` — Current documented end-to-end workflow and solver selection examples to characterize.
- `DESCRIPTION` — Current package dependencies, test framework, and serialization-relevant package metadata.
- `NAMESPACE` — Current broad reachable surface; Phase 2 classifies it but does not narrow it.
- `R/GEModel.R` — Public reference-class methods, fields, defaults, state mutation, and legacy workflow.
- `R/sparseSolver.R` — Sparse public/runtime behavior, backend dispatch, residual checks, closure/shock translation, outputs, and diagnostics.

### Existing tests and numerical evidence

- `tests/testthat/test-public-solver-contract.R` — Current default-engine/backend and fail-closed public contracts.
- `tests/testthat/test-public-cpp-backend.R` — Current opt-in C++ versus R-reference comparisons.
- `tests/testthat/test-sparse-core.R` — Sparse compiler/runtime, updates, Euler streaming, post-simulation, output, and residual coverage.
- `benchmarks/GTAP12A_CPP_RESULTS.md` — Existing full-scale timing, memory, residual, and conditioning evidence.

### Codebase maps

- `.planning/codebase/TESTING.md` — Current test inventory, commands, tolerance evidence, and gaps.
- `.planning/codebase/CONVENTIONS.md` — Existing compatibility, fail-closed, residual, naming, and fixture conventions.
- `.planning/codebase/STRUCTURE.md` — Relevant public API, sparse runtime, native backend, fixture, and benchmark locations.

No external specifications were referenced during discussion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `tests/testthat/test-public-solver-contract.R` already protects omitted engine/backend defaults and native preflight behavior.
- `tests/testthat/test-public-cpp-backend.R` and `tests/testthat/test-sparse-core.R` provide backend-equivalence, residual, update, post-simulation, and output scaffolding.
- `tests/testthat/fixtures/` and existing helper files provide small redistributable systems without proprietary HAR data.
- The benchmark harness already records package/model signatures, residuals, finiteness, dense-fallback status, elapsed time, memory, and hardware.

### Established Patterns

- Legacy and Matrix remain defaults; native execution is explicit and fail-closed.
- Full-system true residual and finiteness checks precede sparse result application.
- Large sparse paths avoid dense full-system conversion, full dimnames, and dense substep histories.
- Test fixtures are small and deterministic; proprietary GTAP inputs and complete solutions remain external.
- Public methods use camelCase while sparse internals use `sparse_`-prefixed snake_case.

### Integration Points

- `R/GEModel.R` owns the public compatibility manifest inputs, mutable model state, solve lifecycle, and serialization boundary.
- `R/sparseSolver.R` owns generic sparse comparison, diagnostics, residual validation, and shock/update semantics.
- Structured R and C++ Schur/elimination modules supply the paired reference/optimized numerical paths.
- `tests/testthat/` receives executable compatibility and numerical contracts; `benchmarks/` retains external full-scale release evidence.

</code_context>

<specifics>
## Specific Ideas

- The production direction is sparse and C++; legacy exists to protect established public workflow behavior, not to define numerical truth.
- Preserve an expensive accepted numerical solve when post-simulation alone fails, while making incomplete post-simulation state explicit and retryable.
- Prefer compact, reviewable baselines and generated full comparisons over committed opaque model snapshots.

</specifics>

<deferred>
## Deferred Ideas

- Package/native identity migration remains Phase 3.
- Public API narrowing and backend interface cleanup remain Phase 4.
- Cross-platform native build and CI remain Phase 5.
- Signed full-scale benchmark qualification and public release artifacts remain Phases 6 and 7.

</deferred>

---

*Phase: 2-Compatibility and Numerical Baseline*
*Context gathered: 2026-09-02*
