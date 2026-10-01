---
phase: 04-public-api-and-solver-boundaries
verified: 2026-10-01T08:09:35Z
status: passed
score: "24/24 must-haves verified"
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 16
  total: 16
  not_honored: []
human_verification: []
---

# Phase 04: Public API and Solver Boundaries — Verification Report

**Phase Goal:** Make GEModelR maintainable through a deliberate public namespace and explicit internal backend contract.

**Verified:** 2026-10-01T08:09:35Z

**Status:** passed
**Re-verification:** No previous Phase 04 verification report existed.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | NAMESPACE contains explicit exports and no broad alphabetic export pattern. | ✓ VERIFIED | NAMESPACE exports only GEModel and retains required imports/native registration. The public-binding contract test asserts the exact export set. |
| 2 | Every supported export and package-level option has generated documentation and a contract test. | ✓ VERIFIED | GEModel and package Rd topics exist. The generated-help contract test checks the supported method, backend, option, diagnostic, status, and condition-class allowlists; R CMD check's Rd checks passed. |
| 3 | Backend registration, capability checks, solve invocation, diagnostics, and cleanup follow one explicit internal interface. | ✓ VERIFIED | sparseSolver.R uses registered adapter records, preflight evidence, candidate validation, central acceptance/commit, and cleanup. Native C++ participates through the same contract; contract and C++ tests cover success and failure paths. |
| 4 | Legacy, Matrix, structured R, and native C++ implementations remain independently selectable correctness/performance references. | ✓ VERIFIED | GEModel selects legacy versus sparse runtime; sparse IDs map to separate registry entries, and the public native-backend test compares the C++ result with StructuredSchurFGMRES and an independent expected solution. |
| 5 | A public GEModel sparse solve using backend Matrix resolves through a private adapter and returns the established solution. | ✓ VERIFIED | The Matrix adapter is registered in sparseSolver.R; the public-solver contract exercises the solve and accepted result. |
| 6 | The requested adapter preflight completes before sparse_emit_system constructs the model matrix. | ✓ VERIFIED | .sparse_solve_one_step_impl calls .sparse_backend_preflight before sparse_emit_system; the Matrix preflight-order test covers this boundary. |
| 7 | Candidate acceptance and the existing single commit seam remain the only route for applying a numerical result. | ✓ VERIFIED | Backend results pass .sparse_accept_candidate and .commit_accepted_state; transactional and solver-contract tests check acceptance, rejection, and one-time commit behavior. |
| 8 | Every existing sparse backend ID dispatches to its own registered implementation and keeps its requested ID observable. | ✓ VERIFIED | sparseSolver.R registers Matrix, SparseM, SuiteSparse, StructuredSchur, and StructuredSchurFGMRES; zzzSparseSchurCpp.R registers StructuredSchurFGMRESCpp. Tests assert requested identity and routing. |
| 9 | Native capability and ABI checks run before system matrix construction and fail with the requested backend, cause, and remediation. | ✓ VERIFIED | Native preflight validates capability payload, ABI, Matrix contract, kernels, and threads; the preflight-failure test checks fail-closed behavior before solving. |
| 10 | Validated structural metadata may persist while factors and solve-scoped buffers are released on success and error. | ✓ VERIFIED | Native cleanup is solve-scoped; public-cpp-backend assertions check cleanup status, retained model-scoped metadata, and released factors after both successful and injected-error solves. |
| 11 | The selected engine matches the runtime initialized by loadData(), and changing engines requires data reload. | ✓ VERIFIED | GEModel$solveModel validates against loadedEngine; lifecycle tests exercise mismatch rejection and the reload path. |
| 12 | Lifecycle validation failures use the stable GEModelR_validation_error class and identify the next required action. | ✓ VERIFIED | Central condition construction and runtime/TABLO guards provide class and remediation fields; lifecycle tests assert both. |
| 13 | Failed loadTablo() and loadData() setup preserve the complete prior model state, including an already loaded model. | ✓ VERIFIED | Loaders prepare state before publishing; lifecycle tests compare complete model snapshots after injected setup failures. |
| 14 | Closure and shock setters invalidate only the dependent solve state while retaining the established variableValues, source-data, and compiled-structure workflows. | ✓ VERIFIED | Setter code separates closure and shock invalidation; lifecycle and documented-workflow tests cover the retained state and invalidated caches. |
| 15 | Compact output rejects unknown variable and dimension selectors with actionable errors before postsimulation materialization. | ✓ VERIFIED | sparse_validate_output_selectors is called before projection/postsimulation; documented-workflow selector tests exercise invalid names and budget rejection. |
| 16 | An explicit empty selection preserves the established empty projection behavior. | ✓ VERIFIED | The documented-workflow contract exercises explicit empty variables/dimensions and checks the resulting projection. |
| 17 | Compact output materializes labels only for the requested projection, while full output retains the complete compatibility structure. | ✓ VERIFIED | sparse_project_outputs validates and subsets the request before sparse_materialize_labels; workflow tests check compact projection and full-output parity. |
| 18 | After closure invalidation, sparse solve rebuilds and retains the current full output index before compact projection. | ✓ VERIFIED | The solve path rebuilds the closure-current index before projection; lifecycle and documented-workflow tests cover valid closure rebuilds and post-closure output. |
| 19 | Every solve attempt replaces lastDiagnostics with a versioned envelope, including validation, capability, numerical, postsimulation, and committed-state failures. | ✓ VERIFIED | solveModel initializes a version-1 running envelope before validation and finalizes it on normal success/error paths; solver, transactional, and native tests assert status replacement. |
| 20 | diagnostics=TRUE adds residual history, timing, allocations, capabilities, cleanup, and memory evidence. | ✓ VERIFIED | The opt-in diagnostics path adds details; public solver and native tests assert detailed fields while the compact envelope omits them when diagnostics are false. |
| 21 | Callers distinguish validation, capability, numerical, postsimulation, retryable, and committed-state outcomes through stable condition classes and the envelope status. | ✓ VERIFIED | GEModelR condition classes/status mapping is explicit in diagnostics code; public solver and transactional tests assert representative outcomes and envelope fields. |
| 22 | NAMESPACE explicitly exports the deliberate GEModel facade and retains native registration/import directives. | ✓ VERIFIED | NAMESPACE has export(GEModel), required imports, and useDynLib registration; there is no exportPattern directive. |
| 23 | The package topic, every supported export, and each supported backend/native option have generated R help. | ✓ VERIFIED | R/apiDocumentation.R generates package and class topics; generated Rd contains the public methods and the 12-option allowlist. test-api-documentation checks those option names and values. |
| 24 | The public help describes the established workflow, separate engine/backend selectors, diagnostics, and option defaults without exposing implementation internals. | ✓ VERIFIED | Generated package help documents the load/configure/solve flow, selectors, backends, diagnostics, defaults, and supported option scope. The namespace/help contracts keep internal helpers private. |

**Score:** 24/24 truths verified; 0 present-but-behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| R/sparseSolver.R | Backend adapter registry, preflight, candidate acceptance, selectors, output projection, closure validation | ✓ VERIFIED | Substantive implementations are called by the public solve path; tests cover routing, ordering, validation, and output behavior. |
| R/zzzSparseSchurCpp.R | Native backend contract, capability/ABI checks, cleanup, cache invalidation | ✓ VERIFIED | Registered native adapter is reached by the explicit C++ backend; tests assert preflight and cleanup behavior. |
| R/GEModel.R | Public facade, lifecycle boundaries, engine checks, diagnostics persistence | ✓ VERIFIED | GEModel methods call the internal solver boundary; lifecycle and solver tests exercise the public entry points. |
| R/zzzzzSchurDiagnostics.R | Stable versioned diagnostic envelope and detailed telemetry | ✓ VERIFIED | Wired into sparse and public solve paths; tests check baseline and opt-in fields. |
| R/modelSerialization.R | Validated state serialization and atomic checkpoint replacement | ✓ VERIFIED | saveState calls the atomic replacement helper; serialization tests check successful round trips and failed replacement preservation. |
| R/apiDocumentation.R | Roxygen source for the public API and supported options | ✓ VERIFIED | Generates both package and class topics. |
| NAMESPACE | Explicit export and required imports/native registration | ✓ VERIFIED | Only GEModel is exported; imports and useDynLib registration remain explicit. |
| man/GEModel.Rd | Generated GEModel help | ✓ VERIFIED | Present, substantive, and parsed by the documentation contract. |
| man/GEModelR-package.Rd | Generated package help | ✓ VERIFIED | Present, substantive, and parsed by the documentation contract. |
| tests/testthat/test-public-solver-contract.R | Namespace, backend, solve, diagnostics, condition contracts | ✓ VERIFIED | Active testthat tests exercise the public solve path and numerical/state assertions. |
| tests/testthat/test-public-cpp-backend.R | Native backend selection and cleanup contract | ✓ VERIFIED | Active test exercises C++ against the structured R reference and checks success/error cleanup. |
| tests/testthat/test-lifecycle-contract.R | Lifecycle and mutation atomicity contracts | ✓ VERIFIED | Active multi-step tests cover load failure, engine mismatch, closure, and shock transitions. |
| tests/testthat/test-documented-workflow.R | Public workflow and output selector contracts | ✓ VERIFIED | Active tests execute representative public load/solve/output flows. |
| tests/testthat/test-transactional-state.R | Accepted-state commit and rollback boundaries | ✓ VERIFIED | Active tests cover successful commit and failure preservation. |
| tests/testthat/test-model-serialization.R | Logical-state and checkpoint contracts | ✓ VERIFIED | Active tests cover round trips, limits, and atomic replacement. |
| tests/testthat/test-api-documentation.R | Generated-help parity contract | ✓ VERIFIED | Requires the supported options, methods, backends, diagnostic fields/statuses, and condition classes in parsed Rd. |
| tests/testthat/test-compatibility-manifest.R | Exact supported package surface and signatures | ✓ VERIFIED | Compares observed exports, methods, and backend identifiers to the compatibility manifest. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| GEModel$solveModel(engine='sparse', backend='Matrix') | sparse_solve_model() and requested adapter | Public solve dispatch | ✓ WIRED | Public solver test exercises the Matrix path. |
| Matrix adapter result | .sparse_accept_candidate() and .commit_accepted_state() | Central acceptance/commit | ✓ WIRED | Acceptance tests cover valid candidate commit and rejection. |
| Explicit backend ID | Adapter preflight, solve, acceptance, and commit | Registry dispatch | ✓ WIRED | Each selectable ID remains observable in solver contract tests. |
| StructuredSchurFGMRESCpp request | Native capability record and C++ implementation | Native adapter registration | ✓ WIRED | Public C++ test checks implementation and capability evidence. |
| Native factors and buffers | Solve-scoped cleanup | Adapter cleanup callback | ✓ WIRED | Cleanup status and empty live-factor state asserted after success and error. |
| loadData(engine) | loadedEngine and solveModel(engine) validation | Runtime lifecycle guard | ✓ WIRED | Lifecycle mismatch/reload test covers the transition. |
| loadTablo()/loadData() staged setup | Atomic publication after successful preparation | Staging and publish seam | ✓ WIRED | Failure snapshot test confirms old state remains intact. |
| setClosure() | Closure/index/native-cache invalidation and output invalidation | Setter and sparse closure state | ✓ WIRED | Valid/invalid closure state tests exercise both engines. |
| setShocks() | Pending solve/postsim/diagnostic invalidation | Setter state transition | ✓ WIRED | Shock lifecycle test confirms dependent state is cleared. |
| solveModel selectors and memory budget | Selector validation then postsim projection | Sparse solve boundary | ✓ WIRED | Invalid/over-budget selector tests fail before projection. |
| Requested compact variables/dimensions | Subset labels and output data | Projection/materialization helpers | ✓ WIRED | Compact output tests assert requested result shape and labels. |
| setClosure() invalidation | Rebuilt full closure-current index | Sparse solve index rebuild | ✓ WIRED | Post-closure solve test verifies current output index. |
| Full output request | Complete compatibility structure | Full-output projection branch | ✓ WIRED | Workflow test checks complete output compatibility. |
| Public solve entry | Running then final diagnostic envelope | GEModel diagnostics boundary | ✓ WIRED | Tests check replacement on success and error. |
| Adapter evidence and accepted state | Diagnostics envelope | Result/diagnostic aggregation | ✓ WIRED | Backend and diagnostics tests assert evidence fields. |
| Failure phase and commit state | Stable condition and envelope fields | Condition builder | ✓ WIRED | Transaction failure tests assert class and state fields. |
| Native capability and cleanup outcomes | Optional diagnostics detail | C++ diagnostics wrapper | ✓ WIRED | Native success/error test checks capability and cleanup detail. |
| GEModel roxygen tags | Export and GEModel help topic | Roxygen generation | ✓ WIRED | NAMESPACE and generated class Rd agree. |
| Package option documentation | Runtime option names/defaults/scopes | Roxygen package topic and test list | ✓ WIRED | Twelve documented options are asserted by help contract tests. |
| Generated Rd aliases | Exact supported export and package topic | Documentation contract test | ✓ WIRED | Alias checks verify GEModel and GEModelR package topic. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| GEModel load/compile and solve path | TABLO model, loaded input data, sparse state/index, emitted matrix, candidate solution | Caller-provided model/data and deterministic test fixtures | Yes; solver tests assert concrete solution values and state transitions | ✓ FLOWING |
| Compact/full output path | Selected variable/dimension labels and output arrays | Accepted solution plus closure-current sparse index | Yes; documented-workflow tests assert actual projections and full-output structures | ✓ FLOWING |
| Native backend path | Candidate solution and native capability/cleanup evidence | Registered C++ kernels and model input | Yes; C++ test compares with Structured R and expected values | ✓ FLOWING |

### Behavioral Spot-Checks

No tests were rerun during this verification, per the orchestrator instruction. The following post-fix evidence was already produced for the current code:

| Behavior | Evidence | Result | Status |
|---|---|---|---|
| Lifecycle, failure atomicity, and closure/shock transitions | Focused lifecycle-contract run: 201 assertions | Passed | ✓ PASS |
| Public documented workflow and selector projection | Focused documented-workflow run: 156 assertions | Passed | ✓ PASS |
| Backend, diagnostic, and solver contracts | Focused public-solver-contract run: 295 assertions | Passed | ✓ PASS |
| Sparse-core lifecycle and numerical behavior | Focused sparse-core run: 94 assertions | Passed | ✓ PASS |
| Native C++ backend parity and cleanup | Installed/package test run; no failure in public-cpp-backend test | Passed | ✓ PASS |

The four focused groups total 746 passing assertions. R CMD check also reports package installation, namespace, R-code, and Rd checks passing.

### Probe Execution

Not applicable. Phase 04 is a package API/library boundary phase; its plans declare no verification probes or probe scripts.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| API-01 | 04-06 | Deliberate documented public API | ✓ SATISFIED | Exact GEModel export, generated help, and namespace/help contract tests. |
| API-02 | 04-01 through 04-05 | Explicit backend dispatch while preserving R reference implementations | ✓ SATISFIED | Adapter registry, lifecycle/diagnostics/transaction code, and focused solver/C++ tests. |
| DOCS-01 | 04-06 | Generated docs for supported exports, package, and native/backend options | ✓ SATISFIED | Generated Rd topics and parsed documentation contract test. |

No additional requirements are mapped to Phase 04 without a plan.

### Test Quality Audit

| Test File | Linked Requirement | Active | Circular | Assertion Level | Verdict |
|---|---|---:|---:|---|---|
| test-public-solver-contract.R | API-02, API-01 | Yes | No | Value, class/status, and state-transition assertions | Adequate |
| test-public-cpp-backend.R | API-02 | Yes | No | Numerical parity, expected value, diagnostics, and cleanup assertions | Adequate |
| test-lifecycle-contract.R | API-02 | Yes | No | Multi-step state and failure-atomicity assertions | Adequate |
| test-documented-workflow.R | API-02 | Yes | No | Public workflow and full/compact output assertions | Adequate |
| test-compatibility-manifest.R | API-01, API-02 | Yes | No | Exact surface/signature/backend equality assertions | Adequate |
| test-api-documentation.R | DOCS-01, API-01 | Yes | No | Parsed generated-help contract assertions | Adequate |
| test-model-serialization.R and test-transactional-state.R | API-02 | Yes | No | Round-trip, atomicity, candidate rejection, and commit-state assertions | Adequate |

No requirement-linked disabled tests or circular expected-value generation were found. Test-file writes are temporary serialization/fault fixtures, not expected outputs generated by the system under test.

### Decision Coverage

All 16 trackable Phase 04 CONTEXT decisions are represented in shipped code, tests, plans, or summaries. The GSD decision-coverage query reported 16/16 honored and no unhonored decisions.

### Anti-Patterns Found

No unreferenced TBD, FIXME, XXX, TODO, HACK, or placeholder markers were found in the Phase 04 implementation, docs, or requirement-linked tests. The “skipped test” search only matched unlink cleanup calls in serialization tests; no disabled requirement test was found.

### Human Verification Required

N/A — this is a package API and solver-boundary phase with no user-facing UI or external service. The manual allowlist review in 04-VALIDATION.md was completed against the compatibility manifest, Phase 04 decisions, generated help, and tests. State-transition behavior is covered by the focused contract tests.

### Out-of-Scope Package and Release Blockers

These findings do not falsify the Phase 04 roadmap truths above, but the checkout is not package-check clean or release-ready:

- Full source testthat exits nonzero on the explicitly deferred Phase 02 package identity-map drift: mixed-case 416/328, uppercase 2/2. Phase 04’s deferred-items record says to preserve the reviewed Phase 02/03 map and handle any refresh as a separate reviewed identity-baseline change. The existing GEModel ReferenceClass assignment warning is also recorded as pre-existing.
- Latest R CMD check ran the package tests with 2,364 passes, 19 failures, and 65 skips, ending with 1 ERROR, 4 WARNINGs, and 4 NOTEs. Six benchmark tests fail because the installed-check context cannot locate the source tree. Four provenance-inventory failures report 320 fresh source keys against the reviewed 291-row snapshot, including new Phase 04 helper keys and a duplicate .sparse_accept_candidate key. Nine release-gate failures reflect stale/duplicate provenance and release records. The API, namespace, R-code, and Rd checks pass.
- The provenance mismatch includes a source delta introduced during Phase 04, but provenance inventory/review refresh is not a Phase 04 roadmap truth or plan must-have. Its canonical review artifacts were not edited; a separate reviewed provenance update is needed before the package-wide check can become green.
- DESCRIPTION still carries the placeholder license declaration exactly as required by docs/provenance/LICENSE-DECISION.md while its decision status remains pending. No license was selected or changed.

## Gaps Summary

No Phase 04 must-have gaps remain. The deliberate namespace, documented API/options, and explicit backend/lifecycle/diagnostics boundaries exist, are wired, and have focused behavioral evidence. Status is passed for Phase 04 scope only; the recorded package-wide identity/provenance/release blockers remain open outside this phase.

---

_Verified: 2026-10-01T08:09:35Z_
_Verifier: the agent (gsd-verifier)_
