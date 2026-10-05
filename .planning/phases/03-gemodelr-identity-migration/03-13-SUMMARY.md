---
phase: 03-gemodelr-identity-migration
plan: 13
subsystem: testing
tags: [R, GEModelR, installed-resources, benchmark, scaling, native-solver]

# Dependency graph
requires:
  - phase: 03-12
    provides: Qualified Phase 2 identity migration and canonical package/test fixtures
provides:
  - Fresh-process installed sweep and native scaling regressions using packaged resources
  - Exact source/inst benchmark mirrors with fail-closed input, child, and resource checks
affects: [03-14, 03-20, benchmark qualification, package installation]

# Actuals (#2632)
actuals:
  tokens: 8548
  tasks: 2
  commits: 5

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Installed subprocesses resolve scripts and sibling resources through system.file.
    - Optional plain-list input RDS mode preserves the existing HAR workflow and defaults.
    - Fresh temporary package libraries isolate installed-resource and package-identity checks.

key-files:
  created:
    - inst/benchmarks/benchmark_gtap12a_run.R
    - tests/testthat/test-installed-benchmark-execution.R
  modified:
    - benchmarks/benchmark_gtap12a_run.R
    - benchmarks/run_gtap12a_sweep.R
    - inst/benchmarks/run_gtap12a_sweep.R
    - benchmarks/run_gtap12a_scaling.R
    - inst/benchmarks/run_gtap12a_scaling.R
    - tests/testthat/test-benchmark-harness.R

key-decisions:
  - Preserve the public HAR path and existing defaults; the plain-list RDS adapter is explicit and optional.
  - Keep the installed child and all four drivers/config resources byte-identical between source and inst paths.
  - Use a temporary GTAP-shaped native fixture for scaling while reusing the redistributable input RDS; repository fixtures and solver code remain unchanged.

patterns-established:
  - Installed benchmark tests run from an unrelated working directory against a task-owned isolated library.
  - Measured child success requires finite solution evidence, current package identity, and matching CSV/RDS metadata.

requirements-completed: [COMP-04, MIGR-01, MIGR-02]

# Coverage metadata
coverage:
  - id: D1
    description: Installed sweep launches its packaged child in a fresh process and completes a measured Matrix solve.
    requirement: MIGR-01
    verification:
      - kind: integration
        ref: tests/testthat/test-installed-benchmark-execution.R installed sweep coverage
        status: pass
    human_judgment: false
  - id: D2
    description: Installed one-thread scaling performs a real native solve and writes finite schema-2 solution evidence.
    requirement: MIGR-02
    verification:
      - kind: integration
        ref: tests/testthat/test-installed-benchmark-execution.R installed scaling coverage
        status: pass
    human_judgment: false
  - id: D3
    description: All five installed resources mirror source bytes and missing, invalid, or failed child inputs fail closed.
    requirement: COMP-04
    verification:
      - kind: unit
        ref: tests/testthat/test-benchmark-harness.R and installed execution failure coverage
        status: pass
    human_judgment: false

# Metrics
duration: 7h 13m
completed: 2026-09-17
status: complete
---

# Phase 03 Plan 13: Installed benchmark execution gap closure Summary

**Fresh installed sweep and native scaling subprocesses now execute real packaged GEModelR resources with fail-closed input and child-error coverage**

## Performance

- **Duration:** 7h 13m
- **Started:** 2026-09-17T14:07:36+02:00
- **Completed:** 2026-09-17T19:19:52Z
- **Tasks:** 2
- **Files modified:** 8 implementation and test files

## Accomplishments

- Installed sweep execution now resolves and launches the packaged child from an isolated library and unrelated working directory, completing a measured Matrix solve with finite residual evidence.
- Installed scaling forwards the optional plain-list input RDS, performs the reviewed one-thread native solve, and verifies finite nonempty schema-2 RDS and CSV pairing metadata.
- Resource parity, missing child/config, malformed input, and child-failure regressions prove the installed path fails closed without changing HAR defaults or historical benchmark artifacts.

## Task Commits

Each task was committed atomically with TDD red and green gates:

1. **Task 1: Execute one installed sweep through the packaged child and public solve** - `f8cdacf` (test), `dc08aef` (feat)
2. **Task 2: Expand installed execution coverage to scaling and the complete resource list** - `b28fdaf` (test), `78e4ca3` (feat)

**Plan metadata:** final documentation commit is created with this summary.

## Files Created/Modified

- `benchmarks/benchmark_gtap12a_run.R` - Adds explicit validated plain-list input RDS execution while retaining HAR behavior.
- `inst/benchmarks/benchmark_gtap12a_run.R` - Installed child mirror used by fresh subprocesses.
- `benchmarks/run_gtap12a_sweep.R` and `inst/benchmarks/run_gtap12a_sweep.R` - Forward the optional input RDS to the installed child.
- `benchmarks/run_gtap12a_scaling.R` and `inst/benchmarks/run_gtap12a_scaling.R` - Forward the same input RDS in the scaling path.
- `tests/testthat/test-installed-benchmark-execution.R` - Fresh-process sweep/scaling, metadata, parity, malformed-input, missing-resource, and child-failure coverage.
- `tests/testthat/test-benchmark-harness.R` - Includes the installed child in the complete resource list.

## Decisions Made

- The existing HAR workflow, public defaults, canonical historical bytes, and accepted hash remain unchanged.
- Installed execution is verified only through isolated package resources and `system.file` resolution; source-checkout lookup is not a success path.
- The scaling smoke creates a temporary native-compatible TABLO/closure/shock fixture because the redistributable three-region TABLO does not expose the structured native partition; it still reuses the same temporary input RDS and performs a real native solve.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Fixture compatibility] Native scaling smoke needed a structured temporary fixture**
- **Found during:** Task 2
- **Issue:** The existing small three-region TABLO fixture did not produce the `comm`/`acts`/`reg` structure required by the native Schur partition, so the planned native solve could not provide valid evidence with that TABLO alone.
- **Fix:** Added a test-local temporary GTAP-shaped TABLO plus closure and shock RDS under the allocated temporary root, while reusing the existing three-region input RDS. No repository fixture, solver, or public default changed.
- **Files modified:** `tests/testthat/test-installed-benchmark-execution.R`
- **Verification:** The installed scaling smoke completed the one-thread native solve and passed the combined focused verification.
- **Committed in:** `78e4ca3`

**Total deviations:** 1 auto-fixed (Rule 1 fixture compatibility)
**Impact on plan:** The deviation is isolated to temporary test data and strengthens the required native execution evidence; no scope creep or production solver change was introduced.

## Issues Encountered

- The focused verification emits an existing R6 field-assignment warning from package initialization. It is unrelated to this plan and does not affect the passing test result.
- The environment rejected the preferred patch helper because its sandbox namespace could not start. Scoped repository edits used the available `rtk` fallback; file scope and commits remained atomic.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Plan 03-14 can pair measured CSV and solution RDS evidence by `pair_signature` and repetition.
- Plan 03-20 can repeat the installed execution qualification with the five-resource mirror and fail-closed coverage in place.
- No execution blocker remains.

---
*Phase: 03-gemodelr-identity-migration*
*Completed: 2026-09-17*
## Self-Check: PASSED

- Summary file exists on disk.
- Task commits f8cdacf, dc08aef, b28fdaf, and 78e4ca3 are present in git history.
- Committed plan diff passes git diff --check.
