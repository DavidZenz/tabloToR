---
phase: 04-public-api-and-solver-boundaries
plan: 02
subsystem: sparse-solver
tags: [R, Matrix, SparseM, SuiteSparse, Rcpp, sparse-solver, backend-adapter]

requires:
  - phase: 04-01
    provides: Private adapter candidate evidence and central acceptance contract
provides:
  - Explicit private adapters for all six existing sparse backend identifiers
  - Native capability preflight before sparse system emission and model mutation
  - Solve-scoped native factor cleanup with model-scoped structural cache retention
affects: [04-03, 04-04, 04-05, sparse-backend-routing, native-resource-lifecycle]

actuals:
  tokens: 9284.25
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - Each exact backend ID resolves to a private preflight, solve, and cleanup adapter.
    - Native adapters preserve requested identity separately from implementation identity and return capability and cleanup evidence.

key-files:
  created:
    - .planning/phases/04-public-api-and-solver-boundaries/04-02-SUMMARY.md
  modified:
    - R/sparseSolver.R
    - R/zzzSparseSchurCpp.R
    - tests/testthat/test-public-solver-contract.R
    - tests/testthat/test-public-cpp-backend.R

key-decisions:
  - "Keep each caller-requested backend ID distinct from the adapter implementation identity."
  - "Keep native structure/order metadata on model state while releasing numerical factors and solve-scoped workspaces on every exit path."
  - "Run native symbol, wrapper arity, ABI, kernel, Matrix self-test, and thread checks before matrix emission."

patterns-established:
  - "Explicit backend lifecycle: exact-ID preflight, solve callback, and unconditional cleanup callback."
  - "Native preflight and cleanup results are observable in adapter capability and cleanup evidence."

requirements-completed: [API-02]

coverage:
  - id: D1
    description: "Every registered sparse backend ID routes through its exact adapter while preserving requested and implementation identity."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-solver-contract.R#each registered backend routes with its requested identity"
        status: pass
    human_judgment: false
  - id: D2
    description: "Native capability failures include the requested C++ backend and remediation and happen before matrix emission or model-state mutation."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-solver-contract.R#native backend preflight fails closed before solving"
        status: pass
    human_judgment: false
  - id: D3
    description: "Native factors are released after successful and failed solves while model-scoped structural cache metadata remains available."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-cpp-backend.R#public native backend is opt-in and numerically equivalent"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-30
status: complete
---

# Phase 04 Plan 02: Sparse Backend Adapter Lifecycle Summary

**All six sparse backend IDs use explicit adapters, with native fail-before-emission checks and solve-scoped factor cleanup.**

## Performance

- **Duration:** About 20 minutes.
- **Started:** 2026-09-30T17:59:53Z
- **Completed:** 2026-09-30T18:19:28Z
- **Tasks:** 2
- **Files modified:** 4 source and test files, plus this summary.

## Accomplishments

- Registered Matrix, SparseM, SuiteSparse, StructuredSchur, StructuredSchurFGMRES, and StructuredSchurFGMRESCpp through exact-ID preflight, solve, and cleanup callbacks.
- Moved C++ capability validation ahead of matrix emission and model mutation; failures report the requested backend, cause, and remediation.
- Verified cleanup evidence and pointer release after successful and failed native solves while retaining structural cache metadata across postsim state reconstruction.
- Kept generated Rcpp wrappers and C registration unchanged because native signatures did not change.

## Task Commits

Each task was committed atomically:

1. **Task 1: Register each existing R and compatibility backend ID** - `a3e5a87` (`feat(04-02): register explicit R backend adapters`)
2. **Task 2: Move native preflight into dispatch and close the resource lifecycle** - `085af90` (`feat(04-02): route native backend through adapter lifecycle`)

**Plan metadata:** Summary and state close-out commits follow the task commits.

## Files Created/Modified

- `R/sparseSolver.R` - Registers exact backend routing and preserves structural cache metadata when postsim retries reconstruct solver state.
- `R/zzzSparseSchurCpp.R` - Adds the native adapter, complete preflight evidence, and success/error cleanup behavior.
- `tests/testthat/test-public-solver-contract.R` - Covers all registered adapter identities and native failure before emission.
- `tests/testthat/test-public-cpp-backend.R` - Covers native cleanup evidence, factor release, and cache retention on success and error.
- `.planning/phases/04-public-api-and-solver-boundaries/04-02-SUMMARY.md` - Records the plan outcome, verification, and execution metadata.

## Decisions Made

- Preserve the requested backend ID independently of implementation identity, including `StructuredSchurFGMRESCpp` versus `cpp`.
- Keep the existing R orchestration and structured solver mathematics around native kernels.
- Retain only model-scoped structural metadata across solves; factors and numeric workspaces remain solve-scoped.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

The postsim retry path rebuilt solver state without carrying forward the validated structural cache. The state reconstruction now restores that model-scoped metadata; the native resources remain solve-scoped and are released. The focused suites also continue to report the existing ReferenceClass field-assignment warning in `GEModel$generateSolution()`.

## Validation

- `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` - passed.
- `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-cpp-backend", reporter = "summary")'` - passed.
- `rtk proxy git diff --check` - passed.
- No test skips or stub markers were found in the plan-touched source and test files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All existing sparse backends now share the private adapter contract, and native capability failures and cleanup are covered by focused contract tests. Plan 04-03 can proceed with the exact backend identity and acceptance boundaries established here.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- Task commits `a3e5a87` and `085af90` exist in Git history.
- Both planned focused contract suites passed.

---
*Phase: 04-public-api-and-solver-boundaries*
*Completed: 2026-09-30*
