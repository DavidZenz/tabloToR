---
phase: 04-public-api-and-solver-boundaries
plan: 01
subsystem: sparse-solver
tags: [R, Matrix, sparse-solver, backend-adapter, candidate-acceptance]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    provides: Backend-neutral candidate acceptance and full-system true-residual gate
provides:
  - Validated Matrix adapter candidate records with separate requested-backend and implementation identities
  - Fail-closed adapter evidence validation before the existing accepted-state commit
affects: [04-02, sparse-backend-routing, numerical-acceptance]

actuals:
  tokens: 4263.75
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - Adapter candidates carry structural, finiteness, residual-input, timing, capability, and cleanup evidence.
    - Adapter numerical evidence remains diagnostic; central candidate acceptance recomputes finiteness and full-system true residual.

key-files:
  created:
    - .planning/phases/04-public-api-and-solver-boundaries/04-01-SUMMARY.md
  modified:
    - R/sparseSolver.R
    - tests/testthat/test-public-solver-contract.R

key-decisions:
  - "Keep the caller-requested backend ID distinct from the adapter implementation identity."
  - "Keep .sparse_accept_candidate() as the authority for independent structure, finiteness, and true-residual acceptance before commit."

requirements-completed: [API-02]

coverage:
  - id: D1
    description: "The public Matrix solve dispatches through the private adapter and commits only the centrally accepted candidate."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-solver-contract.R#Matrix adapter preflights before emission and commits accepted state"
        status: pass
    human_judgment: false
  - id: D2
    description: "Missing fields, inconsistent output structure, non-finite solutions, and failed true residuals are rejected before accepted-state commit."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-solver-contract.R#Matrix adapter records fail closed before accepted-state commit"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-09-30
status: complete
---

# Phase 04 Plan 01: Matrix Adapter Contract Summary

**The public Matrix solve now returns a fully validated adapter candidate, with independent finiteness and true-residual checks still gating the single accepted-state commit.**

## Performance

- **Duration:** About 11 minutes for this continuation; Task 1 was already committed and verified before it began.
- **Started:** 2026-09-30, continuation start time not captured.
- **Completed:** 2026-09-30
- **Tasks:** 2
- **Files modified:** 3, including this summary.

## Accomplishments

- Completed the Matrix adapter result contract with requested backend, implementation identity, sparse system, output structure, structural metadata, finiteness evidence, residual evidence inputs, timing, capability evidence, and cleanup status.
- Added fail-closed validation for candidate identity and contents before numerical acceptance or model-state commit.
- Added deterministic public-workflow regressions for missing fields, inconsistent structure, non-finite output, and true-residual rejection. The commit hook remains untouched in every failure case.
- Preserved Phase 2 authority: `.sparse_accept_candidate()` still recomputes solution structure, finiteness, and full-system true residual.

## Task Commits

1. **Task 1: Trace one explicit Matrix solve through the private adapter** - `b24fc1d` (`feat(04-01): add private Matrix adapter path`)
2. **Task 2: Enforce the candidate and adapter evidence contract** - `4687983` (`feat(04-01): enforce adapter candidate evidence contract`)

**Plan metadata:** Summary and state close-out commits follow the task commits.

## Files Created/Modified

- `R/sparseSolver.R` - Complete Matrix adapter candidate record and strict adapter result validator; central acceptance shares the output-structure helper.
- `tests/testthat/test-public-solver-contract.R` - Verifies candidate evidence fields, separate backend and implementation identity, and four fail-closed cases before commit.
- `.planning/phases/04-public-api-and-solver-boundaries/04-01-SUMMARY.md` - Records plan outcome, verification, and execution metadata.

## Decisions Made

- Preserve the requested backend ID in its own field, independently of the selected implementation identity.
- Treat adapter-supplied numerical evidence as diagnostic only; independently recomputed checks remain authoritative.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

The focused test run reports the existing ReferenceClass warning about local assignment to `data$eqcoeff` in `GEModel$generateSolution()`. All focused assertions pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The Matrix adapter contract is ready for Plan 04-02 to add explicit backend routing while preserving the same fail-closed acceptance boundary.

## Self-Check: PASSED

- Summary file exists at the required phase path.
- Task commits `b24fc1d` and `4687983` exist in Git history.
- Both plan tasks have passing focused contract-test evidence.

---
*Phase: 04-public-api-and-solver-boundaries*
*Completed: 2026-09-30*
