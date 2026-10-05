---
phase: 05-portable-native-build-and-ci
plan: 03
subsystem: testing
tags: [R, testthat, OpenMP, native, portability]
requires:
  - phase: 05-01
    provides: Installed native portability workflow and explicit serial build flags
  - phase: 05-02
    provides: Installed native backend boundary without runtime compilation
provides:
  - Explicit required/forbidden OpenMP expectation parsing and capability assertions
  - Bounded two-thread Schur parity and informational timing output
  - Public one-thread defaults and serial over-request capability errors
affects: [05-04, 05-05, 05-06, 05-07]
tech-stack:
  added: []
  patterns: [Explicit CI capability expectations, disposable installed native tests]
key-files:
  created: [tests/testthat/helper-native-portability.R]
  modified:
    - tests/testthat/test-sparse-schur-openmp.R
    - tests/testthat/test-public-cpp-backend.R
    - R/zzzSparseSchurCpp.R
key-decisions:
  - Reject missing capability expectations in CI or explicit installed-library runs; reject invalid values everywhere.
  - Permit the OpenMP-only skip exclusively for an explicitly forbidden serial job.
  - Name unsupported serial thread requests in the existing structured capability error without changing backend selection or remediation.
requirements-completed: [PORT-01, PORT-02]
actuals:
  tokens: 4617
  tasks: 2
  commits: 3
coverage:
  - id: D1
    description: Explicit capability expectation rejects misconfigured native jobs
    requirement: PORT-02
    verification:
      - kind: integration
        ref: tests/testthat/test-sparse-schur-openmp.R#native job expectation rejects missing and invalid CI values
        status: pass
      - kind: integration
        ref: Installed negative checks reject required-on-serial, forbidden-on-OpenMP, CI missing and CI auto expectations
        status: pass
    human_judgment: false
  - id: D2
    description: OpenMP capability, two-thread bounds, numerical parity and timing visibility
    requirement: PORT-02
    verification:
      - kind: integration
        ref: tests/testthat/test-sparse-schur-openmp.R#bounded OpenMP Schur batches match serial execution
        status: pass
    human_judgment: false
  - id: D3
    description: Serial default remains one thread and unsupported requests fail explicitly
    requirement: PORT-01
    verification:
      - kind: integration
        ref: tests/testthat/test-public-cpp-backend.R#explicit serial jobs preserve default threads and reject over-requests
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-10-04
status: complete
---

# Phase 05 Plan 03: Native Thread Contracts Summary

**Installed serial and OpenMP tests enforce explicit capability expectations, bounded two-thread Schur parity, and one-thread defaults with clear over-request errors.**

## Performance

- **Duration:** 6min
- **Started:** 2026-10-04T20:41Z (recorded to minute precision)
- **Completed:** 2026-10-04T20:47Z (recorded to minute precision)
- **Tasks:** 2
- **Implementation files:** 4

## Accomplishments

- Added shared `GEModelR_EXPECT_OPENMP=required|forbidden` parsing, including errors for missing CI/installed-library expectations and invalid values.
- Required jobs assert native OpenMP capability, a maximum of at least two threads, an effective count of exactly two within that bound, and parity at `1e-10`. Serial and parallel elapsed times are printed without a performance gate.
- Public native solves assert one requested/effective thread by default. Explicit serial jobs additionally assert absent OpenMP, maximum one, and structured errors for both two- and three-thread requests while preserving the selected backend, caller option and solution state.

## Task Commits

1. **Task 05-03-T1: Require OpenMP capability and prove two-thread numerical parity** — `ebf1df1` (`test`).
2. **Task 05-03-T2: Assert serial defaults and reject thread over-requesting** — `2247fc0` (`test`, including the scoped error-message correction).

## Files Created/Modified

- `tests/testthat/helper-native-portability.R` — Parses explicit job expectations and asserts matching compiled capability.
- `tests/testthat/test-sparse-schur-openmp.R` — Exercises expectation parsing, capability, thread bounds, numerical parity and timing output.
- `tests/testthat/test-public-cpp-backend.R` — Asserts default diagnostics and serial failure behavior.
- `R/zzzSparseSchurCpp.R` — Includes the actual unsupported requested count in the serial capability error.

## Verification Results

Both installations used separate disposable source copies under `/tmp/gemodelr-05-03`, excluding checkout objects/shared libraries. Each target library was created before `R CMD INSTALL --preclean --install-tests --library=/tmp/...`. The serial build used a user Makevars containing `SHLIB_OPENMP_CXXFLAGS =`. No package or dependency was installed into the user library.

Tests ran outside the checkout after `.libPaths()` selection and explicit `library(GEModelR, lib.loc = lib)`, with an assertion that the loaded package path matched the selected temporary library. The focused installed equivalent of the plan's source commands was `testthat::test_package("GEModelR", filter = "sparse-schur-openmp|public-cpp-backend", reporter = "summary", stop_on_failure = TRUE)`. OpenMP installed test files were refreshed after the task 2 diagnostic assertions were added; the serial build compiled the final error-message correction.

Local environment: Linux, R 4.3.0, Matrix 1.6.3, testthat 3.3.2.

| Build / expectation | Native capability | Final assertions | Outcome |
|---|---|---|---|
| Default OpenMP / required | `openmp=TRUE`, `max_threads=12` | 78 passes, 0 failures, 0 errors, 0 skips | Two effective threads; parity `1e-10`; default public solve one thread |
| Explicit serial / forbidden | `openmp=FALSE`, `max_threads=1` | 107 passes, 0 failures, 0 errors, 1 intentional skip | Default one thread; requests 2 and 3 rejected with requested count and capability class |

The sole intentional serial skip is the two-thread OpenMP-only batch test; capability assertions run before that skip. Final OpenMP timing output was serial `0.001000` seconds and two-thread `0.002000` seconds. These short measurements establish reporting, with no speed requirement.

Separate installed negative runs confirmed rejection of required-on-serial, forbidden-on-OpenMP, missing expectation under `CI=true`, and invalid `auto` under `CI=true`. Their expected test failures were caught and explicitly asserted by the negative-run harness. A verification invocation issued before the first install had finished found no package in the empty target library; it was rerun after successful installation and all reported final results use the completed builds.

Full package checking is assigned to 05-06. Installation emitted the existing reference-class local-field warning in `generateSolution`; focused test runs emitted no warnings.

## Decisions Made

Capability comes from the installed DLL and is checked against the explicit job expectation. A missing local expectation permits assertions on a capable OpenMP build; only an explicit forbidden expectation permits skipping parallel execution.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical error detail] Name the unsupported serial thread count**
- **Found during:** Task 05-03-T2.
- **Issue:** The existing serial preflight error said multiple threads were requested but omitted the requested unsupported number required by the task's error contract.
- **Fix:** Include the requested count and serial maximum in the existing error cause. Preserve the structured error class, backend identity, preflight phase and remediation.
- **Files modified:** `R/zzzSparseSchurCpp.R`.
- **Verification:** Installed serial public requests for `2L` and `3L` fail with `GEModelR_capability_error`, each naming its exact count; backend, option and pre-solve solution remain unchanged.
- **Commit:** `2247fc0`.

The orchestrator required installed tests from disposable builds instead of `test_local()`, avoiding modification or reuse of pre-existing checkout native artifacts. State, roadmap, requirements, windows ledger and configuration updates remain owned by the orchestrator.

## Issues Encountered

The namespace sandbox could not start (`bwrap` unprivileged namespace error). Approved execution outside that sandbox was used for read-only context, disposable builds, focused tests and scoped commits. No package install failure, authentication gate or backend substitution occurred.

## Next Phase Readiness

Ready for the subsequent Matrix and CI plans to set the shared required/forbidden expectation in every installed job. The local evidence covers Linux only; platform-wide qualification remains with the CI matrix and subsequent phase verification.

## Self-Check: PASSED

The helper and both test artifacts exist. Task commits `ebf1df1` and `2247fc0` exist and contain no tracked file deletions. Changed code introduces no unfinished stubs or new security surface; existing thread/capability trust boundaries are tested directly.
