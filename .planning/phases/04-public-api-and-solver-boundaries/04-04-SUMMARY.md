---
phase: 04-public-api-and-solver-boundaries
plan: 04
subsystem: api
tags: [sparse-solver, output-projection, memory-budget, closure]

# Dependency graph
requires:
  - phase: 04-public-api-and-solver-boundaries
    provides: [public sparse solver and lifecycle contracts]
provides:
  - Strict variable and named-dimension output selector validation.
  - Output allocation checks against the configured solve or model memory budget.
  - Closure-current full indexes retained separately from simulation-restricted indexes through postsimulation projection.
affects: [GEModel sparse solveModel output contract, Phase 04 Plans 05-06]

# Actuals (#2632)
actuals:
  tokens: 3117
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Validate selectors and estimated projection allocation before sparse solve work.
    - Keep full output indexes separate from simulation indexes for postsimulation updates and projection.

key-files:
  created: []
  modified:
    - R/sparseSolver.R
    - tests/testthat/test-documented-workflow.R

key-decisions:
  - "Validate variable names, named dimensions, dimension labels, and estimated output size before starting the solve."
  - "Retain the current full closure index beside the simulation-restricted index in retryable postsimulation records."

patterns-established:
  - "Compact output projections retain only requested data arrays and construct selected dimension labels on demand."
  - "Rebuild a missing or closure-stale sparse index from the current sparse specification and loaded state before solve dispatch."

requirements-completed: [API-02]
coverage:
  - id: D1
    description: "Invalid and over-budget sparse output selectors fail early with actionable remediation; explicit empty selections remain compatible."
    requirement: API-02
    verification:
      - kind: unit
        ref: "tests/testthat/test-documented-workflow.R#compact output selectors are validated before solving"
        status: pass
    human_judgment: false
  - id: D2
    description: "Compact and full projections preserve their established structures and use the current full index after closure changes."
    requirement: API-02
    verification:
      - kind: integration
        ref: "rtk Rscript --vanilla -e 'testthat::test_local(filter = \"documented-workflow\", reporter = \"summary\")'"
        status: pass
      - kind: integration
        ref: "rtk Rscript --vanilla -e 'testthat::test_local(filter = \"lifecycle-contract\", reporter = \"summary\")'"
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-09-30
status: complete
---

# Phase 04 Plan 04: Sparse Output Selector Validation Summary

**Strict sparse output selectors with allocation checks and closure-current full-index projection.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-09-30T18:46:20Z
- **Completed:** 2026-09-30T19:01:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Compact and explicitly selected outputs now reject malformed selectors, unknown variable or dimension names, unknown labels, and projections exceeding the configured memory budget before sparse solve work begins.
- Explicit empty selections and the documented full-output compatibility structure remain unchanged.
- Closure changes that leave the sparse index missing or stale rebuild it from the current loaded state. Full indexes remain available through postsimulation retries and projection, separate from simulation-restricted solve indexes.
- Compact projections retain requested arrays and selected dimension labels without materializing complete variable or equation label vectors.

## Task Commits

1. **Task 1: Validate compact variable and dimension selections** - `184b6e0` (`fix(04-04): validate sparse output selectors`)
2. **Task 2: Materialize requested compact labels and preserve full output** - `84b7434` (`fix(04-04): rebuild full index for output projection`)

**Plan metadata:** Included with the GSD close-out commit.

## Files Created/Modified

- `R/sparseSolver.R` - Strict selector validation, projection size estimation, on-demand dimension projection, and closure-current full-index handling.
- `tests/testthat/test-documented-workflow.R` - Coverage for invalid and empty selectors, budget rejection, compact output scope, and closure invalidation rebuild.

## Decisions Made

- Recognize loaded numeric and logical output arrays, including coefficient and update targets that are not equation variables, while rejecting absent names.
- Store the current full index separately from the numerical solve index so retryable updates, full output materialization, and compact projection use complete current model metadata.

## Deviations from Plan

None. The documented fixture confirmed that coefficient and update arrays outside the equation-variable index are valid output selectors; validation includes those loaded arrays.

## Issues Encountered

- The first selector implementation treated only equation-index variables as selectable and rejected the documented `stock` output. The focused workflow test exposed this; validation was corrected to include loaded numeric and logical arrays, and the workflow suite then passed.
- Both focused suites emit the existing ReferenceClass field-assignment warning at `R/GEModel.R:532`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- API-02 output selector and projection behavior is implemented and covered by the public workflow contract.
- Plan 04-05 can build on the stable full-index and postsimulation retry record behavior.

---
*Phase: 04-public-api-and-solver-boundaries*
*Completed: 2026-09-30*

## Self-Check: PASSED

- Summary file exists at the planned path.
- Task commits `184b6e0` and `84b7434` are present in git history.
