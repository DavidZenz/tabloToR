---
phase: 05-portable-native-build-and-ci
plan: 02
subsystem: solver
tags: [SuiteSparse, capability-preflight, installed-tests, documentation]
requires:
  - phase: 04-public-api-and-solver-boundaries
    provides: Explicit sparse backend registry and structured capability errors
provides:
  - Recognized SuiteSparse backend rejected before emission, compilation or accepted-state mutation
  - Direct solver guards covering zero right-hand sides and reduction shortcuts
  - Installed help and README explaining explicit Matrix remediation
affects: [05-05, 05-06, 05-07]
actuals:
  tokens: 7370
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Unconditional shared capability rejection at preflight and direct entry points
    - Installed tests with compiler and matrix-emission tripwires
key-files:
  created:
    - tests/testthat/test-suite-sparse-unsupported.R
  modified:
    - R/sparseSuiteSparse.R
    - R/sparseSolver.R
    - R/apiDocumentation.R
    - man/GEModel.Rd
    - man/GEModelR-package.Rd
    - README.md
    - tests/testthat/test-sparse-core.R
    - tests/testthat/test-api-documentation.R
key-decisions:
  - Keep SuiteSparse recognized but unconditionally unavailable until portable installed support exists.
  - Reject direct SuiteSparse selection before input evaluation, reduction, or zero-RHS success shortcuts.
  - Preserve backend-specific structured remediation when wrapping preflight errors.
  - Verify disposable installed packages outside the checkout with an explicit temporary library.
requirements-completed: [PORT-03]
coverage:
  - id: D1
    description: SuiteSparse rejects supported and direct requests before solver side effects.
    requirement: PORT-03
    verification:
      - kind: integration
        ref: tests/testthat/test-suite-sparse-unsupported.R#public SuiteSparse requests fail before emission, compilation or state commit
        status: pass
      - kind: unit
        ref: tests/testthat/test-sparse-core.R#SuiteSparse low-level backend fails closed without compilation
        status: pass
      - kind: integration
        ref: Installed public-solver-contract, sparse-core and suite-sparse-unsupported groups
        status: pass
    human_judgment: false
  - id: D2
    description: Installed help and README describe unavailable SuiteSparse and explicit Matrix remediation.
    requirement: PORT-03
    verification:
      - kind: integration
        ref: tests/testthat/test-api-documentation.R#generated help covers the deliberate GEModel API
        status: pass
      - kind: other
        ref: README and SuiteSparse source acceptance assertions
        status: pass
    human_judgment: false
duration: 4 min
completed: 2026-10-04
status: complete
---

# Phase 05 Plan 02: Fail-Closed SuiteSparse Summary

**SuiteSparse now rejects explicit requests through a shared capability error before matrix emission or runtime compilation, with explicit Matrix remediation in runtime errors and installed help.**

## Performance

- **Started:** 2026-10-04T20:35:23Z
- **Completed:** 2026-10-04T20:39:12Z
- **Duration:** Approximately 4 minutes.
- **Tasks:** 2 of 2.
- **Files changed:** 9 implementation/documentation/verification files plus this summary.
- **Actuals basis:** Rounded-up characters divided by four over the realized implementation diff and this summary; not harness token usage.

## Accomplishments

- Kept SuiteSparse registered while rejecting it unconditionally in capability preflight. Removed fixed Linux include/library probes, embedded UMFPACK C++ code, environment mutations and the solve-time sourceCpp route.
- Guarded both sparse_suite_sparse_solver() and solve_sparse_system() before evaluating inputs or accepting zero-RHS/reduction shortcuts. Error messages and structured remediation explicitly recommend backend="Matrix".
- Added installed regression coverage that spies on sourceCpp and sparse_emit_system, counts accepted-state commits and compares serialized transactional model state. Both diagnostics settings reject without emission, compilation or numerical/state commits; failure diagnostics retain the existing public contract.
- Updated class/package help and README with the recognized-but-unavailable status, removed the SuiteSparse solve example and marked its ordering option reserved.

## Task Commits

1. **Task 05-02-T1: Fail closed before solver side effects** — `822ff7a` (fix).
2. **Task 05-02-T2: Document unavailable installed SuiteSparse** — `372e1a5` (docs).

The summary is committed separately after both task commits. Shared STATE/ROADMAP/REQUIREMENTS/WINDOWS updates are owned by the execute-phase orchestrator.

## Verification

- R CMD INSTALL --preclean --install-tests into /tmp/gemodelr-05-02-tqr6hfyh/library from a disposable source copy excluding native build outputs: passed.
- Installed test_package("GEModelR", filter="suite-sparse-unsupported|public-solver-contract|sparse-core", reporter="summary"): passed with no failures or skips after final task-1 changes.
- Installed test_package("GEModelR", filter="api-documentation|suite-sparse-unsupported", reporter="summary"): passed with no failures or skips after final documentation changes.
- Test processes explicitly set .libPaths, load GEModelR with lib.loc pointing to the temporary library and change to an unrelated temporary directory.
- README acceptance assertions require recognized/unavailable wording and explicit Matrix selection, and reject the former SuiteSparse solve example: passed.
- Source acceptance asserts no sourceCpp or hard-coded /usr/ and /lib/ paths remain in R/sparseSuiteSparse.R: passed.
- git diff --check and post-commit deletion scans: passed; no tracked files deleted.
- A full R CMD check remains scheduled in 05-06. This plan does not claim the inherited Phase 04 check findings are resolved.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserve backend-specific structured remediation**
- **Found during:** Task 1.
- **Issue:** Preflight wrapping replaced the actionable backend remediation with generic installation advice.
- **Fix:** Preserve an existing remediation object before using the generic fallback; assert explicit Matrix remediation on the public condition.
- **Files modified:** R/sparseSolver.R, tests/testthat/test-suite-sparse-unsupported.R.
- **Commit:** 822ff7a.

**2. [Rule 3 - Blocking] Update the actual generated backend help destination**
- **Found during:** Task 2.
- **Issue:** The plan names man/GEModel.Rd, but R/apiDocumentation.R generates backend/option help in man/GEModelR-package.Rd. Editing only the declared class page would leave installed package help contradictory.
- **Fix:** Make the matching scoped package Rd edit as well as the declared class Rd edit.
- **Files modified:** man/GEModelR-package.Rd, man/GEModel.Rd.
- **Commit:** 372e1a5.

### Verification Adjustment

The plan's source-tree test_local commands were replaced with equivalent focused installed test_package runs. The orchestrator requires disposable source copies and explicit temporary libraries to preserve pre-existing native output and the user library. This additionally proves the supported installed workflow outside the checkout. No verification group was omitted.

## Issues Encountered

The first new public regression referenced a fixture function local to another test file. It was corrected to the shared make_synthetic_model helper, then the full focused task-1 groups passed. A transient sandbox namespace failure on one shell invocation was avoided by changing the R process working directory inside R. Package installation repeats the known ReferenceClass assignment warning in generateSolution; that pre-existing warning is outside this plan's scope.

## Known Stubs

None. SuiteSparse unavailability is the deliberate completed capability contract, not an unfinished solver implementation. No new skipped tests, placeholder data sources or TODO/FIXME items were introduced.

## Next Phase Readiness

Ready for the remaining Phase 05 native/CI plans. New SuiteSparse coverage can run in every platform cell without requiring external SuiteSparse libraries. No package dependencies, public backend IDs or numerical algorithms changed.

## Self-Check: PASSED

Created regression and summary files exist; both task commits are present. Focused installed tests and acceptance checks passed. Existing native build outputs and unrelated planning/user files were preserved.
