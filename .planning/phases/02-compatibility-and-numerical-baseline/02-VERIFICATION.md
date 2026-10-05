---
phase: 02-compatibility-and-numerical-baseline
verified: 2026-09-09T11:58:00Z
status: passed
score: 25/25 must-haves verified
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "The documented workflow executes under the final GEModelR package identity."
    addressed_in: "Phase 3"
    evidence: "Phase 3 owns package identity migration and pre/post-rename compatibility; Phase 2 intentionally freezes the pre-rename tabloToR contract."
  - truth: "Installed-package R CMD check can locate the source-only benchmark driver scripts."
    addressed_in: "Phases 5 and 6"
    evidence: "Phase 5 owns package installation/CI portability and Phase 6 owns release checks. The failing benchmark path tests were introduced in commit 534f2fe before Phase 2 and pass in repository-source mode."
---

# Phase 2: Compatibility and Numerical Baseline Verification Report

**Phase Goal:** Create executable contracts for every user-visible and numerical behavior GEModelR must preserve.
**Verified:** 2026-09-09T11:58:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

Phase 2 achieves its contract-freeze goal. The compatibility surface is machine-readable and checked against the live package, the redistributable fixture exercises the complete public workflow, all required solver authorities are compared with independent residual gates before commit, failure paths are transactional, logical serialization is portable and fail-closed, and the accepted baseline is bound to the reviewed source and fixture fingerprints.

The report does not rely on SUMMARY.md claims. Evidence below comes from the current implementation, canonical artifacts, independent test execution, and direct data-flow inspection.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | A tiered compatibility manifest records the supported exports, GEModel fields/methods, exact signatures/defaults, backends, workflows, outputs, and serialization policy. | ✓ VERIFIED | `inst/compatibility/GEModel-contract.csv` has 234 contract rows; `test-compatibility-manifest.R` compares the manifest to the live namespace and ReferenceClass surface and passed. |
| 2 | Manifest tiers and traceability distinguish supported, compatibility-only, and internal behavior without duplicate or unclassified rows. | ✓ VERIFIED | `helper-compatibility.R` validates allowlists, tiers, duplicate keys, and normative-document references; tests passed. |
| 3 | Structural compatibility helpers preserve empty, singleton, NULL, array metadata, selector, encoding, and default-value behavior. | ✓ VERIFIED | `test-compatibility-helpers.R` exercises these edge cases and passed. |
| 4 | A redistributable fixture runs the complete documented public workflow and contains no private model data. | ✓ VERIFIED | `three-region.tab` is a transparent 11-line model; `PROVENANCE.md` identifies David Zenz/CC0 and its MD5. `helper-three-region.R` calls `GEModel$new()`, `loadTablo()`, `setClosure()`, `loadData()`, `setShocks()`, and `solveModel()`. |
| 5 | Both supported shock APIs have the same normalization, repeated-call, and clearing semantics. | ✓ VERIFIED | Named workflow tests exercise `setShocks()` and explicit `variableValues`, including repeats and clears; integrated Phase 2 tests passed. |
| 6 | Omitted and explicit public defaults produce equivalent results. | ✓ VERIFIED | Workflow/default tests compare omitted and explicit closure, solve, and selector arguments; passed. |
| 7 | Full, compact, and selected outputs preserve shape/order, post-simulation updates, missing/zero behavior, and stale-output clearing. | ✓ VERIFIED | `test-documented-workflow.R` covers all output modes and transition paths; passed. |
| 8 | The legacy solver remains a smoke/fallback contract rather than a numerical oracle. | ✓ VERIFIED | Manifest and `WORKFLOWS.md` classify legacy as smoke-only; the public legacy workflow test passes without being used as an equality authority. |
| 9 | Matrix sparse and structured R are the numerical authorities; native C++ is checked against the structured authority when available. | ✓ VERIFIED | `helper-numerical-baseline.R` defines the authority map and capability matrix; Matrix, structured R, native C++, and legacy smoke paths all ran in the integrated gate. |
| 10 | Candidate solutions must have exact structure, finite values, absolute/relative agreement, and an independently computed true residual before state mutation. | ✓ VERIFIED | `.sparse_accept_candidate()` in `R/sparseSolver.R` performs all four checks; rejection and pre-commit-state tests passed. |
| 11 | Tolerances vary only by fixture conditioning, never by backend. | ✓ VERIFIED | `tolerances.csv` has strict ordinary-fixture rows and one documented external ill-conditioned row; tests reject backend-specific exceptions. |
| 12 | Required and optional backend capability outcomes are explicit and auditable. | ✓ VERIFIED | Matrix, SparseM, structured R, and legacy are required; SuiteSparse/C++/OpenMP use explicit capability checks and skip reasons; capability tests passed. |
| 13 | Solve failures before acceptance leave all public and private model state unchanged for both sparse and legacy engines. | ✓ VERIFIED | `test-transactional-state.R` injects compilation, factorization, convergence, finiteness, residual, and update failures and compares full snapshots; passed. |
| 14 | An accepted solve remains accepted when post-simulation fails, with retryable status retained. | ✓ VERIFIED | Post-simulation failure/retry state-transition tests passed for R and C++ provenance paths. |
| 15 | Shock bookkeeping remains correct across failure and retry. | ✓ VERIFIED | Tests verify shocks are neither consumed on rejected solves nor reapplied during post-simulation retry; passed. |
| 16 | `retryPostsim()` is solve-free and commits only reconstructed post-simulation state. | ✓ VERIFIED | `.retry_postsim_from_record()` does not invoke a solver; tests instrument solver calls and verify zero calls during retry. |
| 17 | Portable state uses an explicit logical schema identifier/version and an allowlisted payload. | ✓ VERIFIED | `R/modelSerialization.R` defines schema `gemodel-logical-state`, version `1L`, and validates required/allowed fields; serialization tests passed. |
| 18 | Runtime caches, external pointers, compiled closures, and diagnostics are excluded from serialized state. | ✓ VERIFIED | Payload construction is allowlisted; policy tests inspect the saved object and pass. |
| 19 | A fresh process can restore and re-solve the same logical model. | ✓ VERIFIED | Child-process restore/re-solve tests pass and rebuild transient state from public model inputs. |
| 20 | Malformed, incompatible, source-mismatched, oversized, and corrupt state fails closed without mutating the receiver. | ✓ VERIFIED | Serialization tests cover schema/source/size checks, compressed expansion, corrupt accepted data, compact projections, and receiver isolation; passed. |
| 21 | Raw RDS is explicitly compatibility-only, not the supported persistence contract. | ✓ VERIFIED | Manifest, `SERIALIZATION.md`, and tests consistently classify raw RDS as compatibility-only. |
| 22 | Canonical baseline artifacts identify package source, fixture/model signatures, runtime/dependency context, and external evidence boundaries. | ✓ VERIFIED | `fingerprints.dcf` records source scope/count/fingerprint, fixture and model hashes, package signature, and external evidence; volatile run metadata is retained in proposals. |
| 23 | Baseline refresh is deterministic, proposal-only, bounded, and unable to overwrite canonical artifacts. | ✓ VERIFIED | The installed refresh implementation enforces explicit non-overlapping output paths, regular-file/size checks, deterministic stable artifacts, and `--check`; its focused tests and independent check passed. |
| 24 | Acceptance is a separate reviewed, source-bound, atomic operation with rollback and a durable acceptance record. | ✓ VERIFIED | `ACCEPTANCE.md` records David Zenz, timestamp, proposal/canonical hash `f6f2297a6ab257c9737a64354c82d7f1`, source fingerprint `f57c39e0bdd3020b48a602773c580a8d`, and strict tier. Tamper, lock, rollback, and source-binding tests passed. |
| 25 | The integrated regression matrix enforces the complete Phase 2 contract while keeping external GTAP data and full solutions outside the repository. | ✓ VERIFIED | 72 active Phase 2 `test_that` contracts passed; canonical artifacts contain only compact expectations/tolerances/fingerprints, and `External-Inputs-Committed: false`. |

**Score:** 25/25 truths verified (0 present, behavior-unverified)

### Deferred Items

These are real repository concerns, but the roadmap explicitly assigns them to later phases; neither weakens the Phase 2 pre-rename contract baseline.

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Execute the preserved workflow under the final `GEModelR` identity. | Phase 3 | Phase 3 goal and success criteria own package identity migration and pre/post-rename compatibility. |
| 2 | Make installed-package checks resolve benchmark scripts from the check sandbox. | Phases 5–6 | Clean `HEAD` check fails only the two pre-Phase-2 benchmark path tests; Phase 5 owns installation/CI portability and Phase 6 owns release checks. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `inst/compatibility/GEModel-contract.csv` | Executable public/compatibility contract | ✓ VERIFIED | Substantive 234-row manifest; exact live-surface checks pass. |
| `inst/compatibility/WORKFLOWS.md` | Workflow and backend authority contract | ✓ VERIFIED | Normative behavior, defaults, selectors, outputs, and authority roles documented and referenced by tests. |
| `tests/testthat/helper-compatibility.R` and compatibility tests | Manifest loader and structural checks | ✓ VERIFIED | Loaded and used by active tests; no orphan helpers. |
| `tests/testthat/fixtures/three-region.tab` and `PROVENANCE.md` | Redistributable deterministic fixture | ✓ VERIFIED | Real public workflow input, provenance and MD5 recorded. |
| `tests/testthat/helper-three-region.R` and `test-documented-workflow.R` | Complete public workflow contract | ✓ VERIFIED | Calls real GEModel methods and renders/compares real model outputs. |
| `tests/testthat/helper-numerical-baseline.R` and `test-numerical-baseline.R` | Cross-backend authorities and residual gates | ✓ VERIFIED | Real solver candidates compared with structure/value/residual assertions. |
| `R/sparseSolver.R` | Acceptance gate, transaction boundary, retry | ✓ VERIFIED | Candidate gate at line 1515, acceptance call at 2207, single accepted-state commit at 2499, retry entry at 2507. |
| `R/zzzSparseSchurCpp.R` | Native backend state isolation/provenance | ✓ VERIFIED | Native one-step execution writes to private working state and restores runtime binding; regression tests pass. |
| `R/GEModel.R` | Public solve/retry/save/load methods | ✓ VERIFIED | Methods call transactional solver/serialization implementations and are manifest-checked. |
| `tests/testthat/helper-transactional-state.R` and `test-transactional-state.R` | Full-state failure matrix | ✓ VERIFIED | Public/private snapshots and injected failures exercise both engines and postsim retry. |
| `inst/compatibility/FAILURE-SEMANTICS.md` | Normative transactional semantics | ✓ VERIFIED | Matches implementation and tested state transitions. |
| `R/modelSerialization.R` | Versioned logical persistence | ✓ VERIFIED | Allowlisted save, isolated reconstruction, validation, and bounded decoding are substantive and wired. |
| `tests/testthat/helper-serialization.R` and `test-model-serialization.R` | Round-trip and fail-closed persistence tests | ✓ VERIFIED | Includes fresh-process, malformed, incompatible, corruption, and cache rebuild cases. |
| `inst/compatibility/SERIALIZATION.md` | Supported persistence and trust boundary | ✓ VERIFIED | Documents logical schema, exclusions, limits, local-trust boundary, and raw-RDS compatibility status. |
| `inst/tools/refresh_phase02_baselines.R` and top-level wrapper | Deterministic proposal generator | ✓ VERIFIED | Wrapper sources the single installed implementation; independent `--check` reports no changes. |
| `inst/tools/accept_phase02_baselines.R` and top-level wrapper | Reviewed atomic acceptance | ✓ VERIFIED | Source-bound validation, locking, staging, backup, rollback, and acceptance record are tested. |
| `tests/testthat/baselines/phase02/*` | Canonical compact baseline | ✓ VERIFIED | All four expected files exist; hashes and source/fixture identity are mutually consistent. |
| `tests/testthat/test-baseline-artifacts.R` | Baseline tamper/refresh/acceptance gate | ✓ VERIFIED | Active tests cover deterministic generation, immutability, source binding, locks, and rollback. |
| `inst/compatibility/BASELINE-PROCESS.md` | Human review and refresh policy | ✓ VERIFIED | Proposal/acceptance separation and external evidence policy match tooling. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Live namespace and GEModel generator | Compatibility manifest | Exact set/formals/default comparisons | ✓ WIRED | Tests fail on an added, removed, or reclassified export, field, method, backend, or helper. |
| Three-region fixture/helper | Public GEModel workflow | Direct calls to all documented public stages | ✓ WIRED | No static fixture result bypasses parsing/loading/closure/shocks/solve. |
| Public solve methods | Backend authority map | Requested engine dispatch and diagnostics | ✓ WIRED | Matrix, structured R, C++ where available, and legacy smoke are reached by public calls. |
| Solver candidate | Acceptance gate | `.sparse_accept_candidate()` before apply/commit | ✓ WIRED | Failed candidates cannot reach `.commit_accepted_state()`. |
| Accepted solve record | Post-simulation retry | `.retry_postsim_from_record()` | ✓ WIRED | Retry validates the record, replays only post stages, then commits. |
| `saveState()` / `loadState()` | Logical schema | serialization build/validate/reconstruct functions | ✓ WIRED | Restored state is reconstructed in isolation and installed only after full validation. |
| Refresh wrapper | Proposal artifacts | Single installed implementation | ✓ WIRED | Stable files plus volatile proposal metadata come from an actual fixture solve. |
| Acceptance wrapper | Canonical baseline | Source-bound validation and atomic publication | ✓ WIRED | Canonical state changes only after review metadata, hashes, schemas, and current-source regeneration agree. |
| Canonical baseline | Integrated tests | expectations/tolerance/fingerprint readers | ✓ WIRED | Tests consume the canonical files and independently recompute current model results/residuals. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| Public workflow helper | `solution`, compact outputs, selected outputs | Parsed `three-region.tab` + loaded numeric data + public closure/shocks | Yes | ✓ FLOWING |
| Matrix authority | candidate solution and residual | Actual sparse equation matrix/RHS assembled from model state | Yes | ✓ FLOWING |
| Structured R/C++ authorities | structured candidate and diagnostics | Deterministic structured system through real backend entry points | Yes | ✓ FLOWING |
| Transaction layer | committed model state | Accepted private working-state record | Yes | ✓ FLOWING |
| Logical serialization | restored closure/data/shocks/solution | Validated schema payload plus reconstructed source model | Yes | ✓ FLOWING |
| Baseline proposal | expectations/tolerances/fingerprints | Fresh fixture solve, runtime metadata, source and fixture hashes | Yes | ✓ FLOWING |

No rendered or asserted value terminates in an unexplained empty prop, static API return, or mock-only production path. The compact baseline values are deliberately frozen review artifacts, but numerical correctness is separately checked at runtime by cross-backend comparisons and independently computed residuals.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Integrated Phase 2 contract matrix | `R --vanilla -q -e 'testthat::test_local(filter = "compatibility|numerical-baseline|transactional-state|model-serialization|baseline-artifacts|public-solver-contract|public-cpp-backend|sparse-core|sparse-cpp-cache", reporter = "summary")'` | All selected suites completed; exit 0 | ✓ PASS |
| Canonical baseline is current | `Rscript --vanilla tools/refresh_phase02_baselines.R --check` | `No stable baseline changes`; exit 0 | ✓ PASS |
| Phase 1 compatibility regression | `testthat::test_local(filter = "release-gates|provenance-inventory|name-availability|attribution-contract")` | All selected suites completed; exit 0 | ✓ PASS |
| Benchmark harness works in its source-mode contract | `testthat::test_local(filter = "benchmark-harness")` | 8 expectations passed; exit 0 | ✓ PASS |
| Full clean-archive package check | `R CMD check --no-manual .` from a clean `git archive HEAD` | Installation succeeds; 674 tests pass, 101 skip, 2 pre-Phase-2 benchmark path tests fail | ⚠ DEFERRED to Phases 5–6 |

The repeated ReferenceClass diagnostic about local assignment to `data$eqcoeff` in compatibility-only `generateSolution()` is the known legacy warning supplied for this verification. It does not coincide with a failed legacy workflow or a Phase 2 debt marker, and changing it now would alter the accepted source fingerprint. It remains visible below rather than being treated as a silent pass.

### Probe Execution

No `scripts/**/probe-*.sh` files or phase-declared probes exist. Phase 2 uses executable `testthat` contracts and baseline CLI checks instead.

| Probe | Command | Result | Status |
|---|---|---|---|
| N/A | Probe discovery | No conventional or declared probes | SKIPPED — none defined |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| COMP-01 | 02-01, 02-02, 02-06 | Preserve the documented end-to-end workflow | ✓ SATISFIED | Redistributable public-workflow tests pass across the required matrix; final package-name execution is explicitly Phase 3. |
| COMP-02 | 02-01, 02-02, 02-04, 02-05 | Preserve supported public API shape and semantics | ✓ SATISFIED | Live surface, signatures/defaults, shocks, outputs, failure semantics, and persistence are manifest-backed and tested. |
| COMP-03 | 02-02, 02-04 | Preserve legacy behavior needed for fallback compatibility | ✓ SATISFIED | Legacy public smoke path and transactional failure matrix pass; legacy is correctly not a numerical oracle. |
| NUM-01 | 02-02, 02-03, 02-04, 02-06 | Preserve cross-backend numerical solutions and true residuals | ✓ SATISFIED | Required authorities and available native C++ pass strict structure/value/residual checks before commit. |
| NUM-02 | 02-03, 02-06 | Document and enforce tolerance policy | ✓ SATISFIED | Conditioning-scoped tolerances, rationale, reviewer, and strict canonical tier are present and actively validated. |

No Phase 2 requirements are orphaned: all five roadmap mappings appear in at least one Phase 2 plan and have implementation evidence.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| All Phase 2 implementation/test/artifact files | — | `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, placeholder text, or user-visible empty stubs | None | No blocker debt markers or hollow implementations found. |
| `R/GEModel.R` | 228 | ReferenceClass checker warns that local `data$eqcoeff = ...` may have intended `<<-` | ℹ INFO | Known legacy-path warning; legacy workflow tests pass and the method is compatibility-only. Deliberately left visible for post-baseline work. |
| `tests/testthat/test-benchmark-harness.R` | 1–13 | Relative source-tree path search fails inside installed-package check layout | ⚠ WARNING / deferred | Predates Phase 2; source-mode tests pass. Installation/CI and release-check portability are owned by Phases 5–6. |

### Test Quality and Decision Coverage

- The Phase 2 files contain 72 active `test_that` contracts; there are no disabled requirement tests.
- Optional backend skips are capability-driven and report a reason. Required Matrix, SparseM, structured R, and legacy paths do not silently skip.
- Canonical expected values are human-reviewed preservation data, not the sole oracle: transparent fixture algebra, cross-backend equality, exact structure, finiteness, and independently recomputed residuals provide separate correctness evidence.
- All 17 phase context decisions are represented in plans and implementation; no decision contradictions were found.
- The historical Plan 02-06 human checkpoint is already resolved by the canonical acceptance record from David Zenz. No new visual, real-time, external-service, or untested transition check remains for human verification.

### Human Verification Required

None. Every behavior-dependent must-have has a passing test that exercises its state transition, failure cleanup, retry, ordering, or publication invariant. The sole planned human gate—baseline review—has durable accepted evidence in `ACCEPTANCE.md`.

### Gaps Summary

No Phase 2 blockers or warnings remain against the phase goal. The goal is achieved and the baseline is suitable for the Phase 3 identity migration.

Two out-of-phase concerns remain deliberately visible: the final `GEModelR` identity is Phase 3 work, and installed-package benchmark-script path portability is Phase 5/6 work. Neither is required to establish the current executable compatibility and numerical baseline.

---

_Verified: 2026-09-09T11:58:00Z_
_Verifier: the agent (gsd-verifier)_
