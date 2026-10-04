---
phase: 05-portable-native-build-and-ci
plan: 05
subsystem: ci
tags: [r, github-actions, installed-tests, openmp, matrix, portability]
requires:
  - phase: 05-01
    provides: Installed native portability tracer and pinned Linux serial workflow
  - phase: 05-02
    provides: Fail-closed SuiteSparse installed contracts
  - phase: 05-03
    provides: Explicit serial and required OpenMP tests
  - phase: 05-04
    provides: Installed Matrix compatibility contracts
provides:
  - Five explicit platform/build rows using the same triggers and installed core contracts
  - Installed-only core runner with required capability, library and Matrix expectations
affects: [05-06, 05-07]
tech-stack:
  added: []
  patterns: [job-local serial Makevars override, explicit installed library, exact core-group coverage]
key-files:
  created: [tools/ci/run-installed-core-tests.R]
  modified: [.github/workflows/native-ci.yaml]
key-decisions:
  - Require GEModelR_TEST_LIBRARY and verify the loaded namespace path before running installed tests.
  - Require every selected test file to exist and report passing assertions; allow only the explicit serial parallel-comparison skip.
requirements-completed: [CI-01, PORT-01, PORT-02, PORT-03]
coverage:
  - id: D1
    description: Configure Linux/macOS/Windows serial and Linux/Windows OpenMP rows with identical triggers and protected action execution
    verification:
      - kind: other
        ref: Rscript --vanilla /tmp/validate-gemodelr-native-workflow.R
        status: pass
      - kind: integration
        ref: Embedded installed core suite against the disposable serial build
        status: pass
    human_judgment: false
  - id: D2
    description: Enforce installed package identity, capability and Matrix expectations and execute all six core groups
    verification:
      - kind: integration
        ref: tools/ci/run-installed-core-tests.R with forbidden OpenMP and installed Matrix expectations
        status: pass
      - kind: integration
        ref: tools/ci/run-installed-core-tests.R with required OpenMP and exact Matrix 1.6-3 expectations
        status: pass
      - kind: other
        ref: Missing/invalid expectations, capability/version mismatches and absent/empty installed-group rejection probes
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-10-04
status: complete
actuals:
  tokens: 4533
  tasks: 2
  commits: 3
---

# Phase 05 Plan 05: Cross-platform Installed Core CI Summary

**Five explicit serial/OpenMP platform rows share an installed-package runner that rejects missing expectations and absent or empty core test groups.**

## Performance

- **Duration:** 5min
- **Started:** 2026-10-04T20:56:42Z
- **Completed:** 2026-10-04T21:01:28Z
- **Tasks:** 2
- **Implementation files modified:** 2
- **Actual token scale:** chars/4 of the realized diff, including this summary.

## Accomplishments

- Linux, macOS and Windows serial rows clear R's OpenMP C++ macro through a job-local Makevars file. Linux and Windows OpenMP rows retain R's native flags and require compiled OpenMP support. All five release rows run on pull requests, master pushes and the weekly Monday 04:23 UTC schedule.
- The workflow retains immutable reviewed checkout/r-lib action pins, contents-only read permission, disabled persisted checkout credentials, and fixed install/test steps without secrets or routine full-scale benchmarks.
- The runner loads GEModelR from the explicitly selected installed library, checks its namespace path, loads Matrix, verifies exact endpoint versions or the installed package's declared minimum, and runs native portability, SuiteSparse unsupported, sparse Schur/OpenMP, public C++ backend, public solver contract and Matrix compatibility groups.
- Missing group files, empty groups, missing/invalid expectations, version/capability mismatches and unexpected test skips fail the runner. Tests run from an unrelated temporary working directory through testthat::test_package(), never checkout-loaded package code.

## Task Commits

1. **Task 05-05-T1: Add serial and supported OpenMP cells for every platform** — `9be7a41` (feat)
2. **Task 05-05-T2: Run installed core contracts uniformly in each CI cell** — `795be49` (feat)

The separate docs commit records this summary; the orchestrator owns STATE, ROADMAP and requirement progress updates.

## Files Created/Modified

- `.github/workflows/native-ci.yaml` — Five explicit native build rows, common install/test steps and explicit expectations.
- `tools/ci/run-installed-core-tests.R` — Installed namespace, OpenMP, Matrix and six-group test enforcement.

## Decisions Made

- Require GEModelR_TEST_LIBRARY in addition to the two required expectations to prevent an arbitrary existing GEModelR installation from satisfying CI.
- Verify both installed test-file presence and observed per-file passing assertions to prevent testthat from reporting an empty suite as success.
- Keep default Apple clang macOS builds explicitly serial; require OpenMP only on supported Linux and Windows toolchains.
- Support the ordinary Matrix `installed` sentinel while checking any declared floor; exact endpoint lanes accept canonical numeric version spelling such as `1.6-3` / `1.6.3`.

## Verification Results

- YAML inspection passed for all five OS/build/expectation rows, unchanged events, read-only permissions, 40-character action pins, disabled checkout credentials, common installed runner and the lack of conditional event exclusions or error suppression. Embedded R scripts parsed and Bash scripts passed `bash -n`. `git diff --check` passed.
- A fresh serial package built from tracked source copied to `/tmp/gemodelr-05-05-od9s1kub/source`, excluding native objects and shared libraries, installed with `--install-tests --library=/tmp/gemodelr-05-05-od9s1kub/library`. Compile/link logs had no OpenMP flags. Runtime capability was `openmp=FALSE`, `max_threads=1`.
- The task-1 embedded installed suite passed all six groups. The shared runner then passed **25 tests / 457 assertions**, with only the planned serial-only OpenMP comparison skip.
- The shared runner passed against the prior fresh OpenMP installation at `/tmp/gemodelr-05-04-lm6cbytu/library`: **25 tests / 428 assertions / zero skips**, `openmp=TRUE`, `max_threads=12`, and exact requested Matrix `1.6-3` matched loaded `1.6.3`. Serial/two-thread numerical parity passed with timing logged and no speed threshold.
- Negative probes rejected absent OpenMP/Matrix/library variables, invalid OpenMP/Matrix values, a wrong exact Matrix endpoint, required OpenMP against a serial DLL, an absent installed SuiteSparse group, and an installed SuiteSparse file containing no tests. The last two used a disposable copied installation.
- All task commits exist, neither task deleted tracked files, and no stub patterns were introduced. Pre-existing repository native objects/shared libraries and the user's R library were preserved.

## Deviations from Plan

**[Rule 3 - Blocking] Isolate install verification from existing native build artifacts.** The plan's direct checkout install command would preclean pre-existing user objects. Verification instead used a disposable tracked-source copy and an explicitly created temporary library. Test selection, installed identity and capability checks remained equivalent or stronger. No production files beyond the planned two changed.

## Issues Encountered

No implementation issues. The existing GEModel reference-class local-field assignment warning appeared during installation and is outside this plan's scope. Hosted macOS/Windows execution is evidence work scheduled in 05-06; local success does not claim those hosted jobs have run.

## User Setup Required

None. No remote writes, workflow dispatches, pushes or PRs were performed.

## Next Phase Readiness

Ready for 05-06 to extend supported R/Matrix endpoints and collect hosted platform evidence. Full package checks remain assigned to its representative evidence lane; existing Phase 04 package-check findings are not resolved or hidden by these portability results. The Matrix floor is still declared only after 05-07's evidence gate.

## Self-Check: PASSED

Both implementation files exist and both task commits are present in git history. The summary is written and committed separately before the orchestrator updates global planning state.
