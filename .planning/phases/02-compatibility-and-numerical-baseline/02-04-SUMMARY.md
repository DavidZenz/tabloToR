---
phase: 02-compatibility-and-numerical-baseline
plan: 04
subsystem: solver-transactions
tags: [R, reference-classes, sparse-solver, transactions, retry, testthat]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    plan: 03
    provides: Backend-neutral candidate acceptance and true-residual gates
provides:
  - Transactionally isolated sparse and legacy solve mutation
  - Accepted numerical-state commit before atomic post-simulation publication
  - Public solve-free retryPostsim contract with structured retry diagnostics
affects: [02-05, 02-06, serialization, solver-reliability, public-api]

actuals:
  tokens: 7318
  tasks: 2
  commits: 5

tech-stack:
  added: []
  patterns:
    - Sparse copy-on-write working state committed only after numerical acceptance
    - Legacy deep reference-class copy committed only after all lifecycle gates
    - Accepted numerical record drives atomic solve-free post-simulation retries

key-files:
  created:
    - tests/testthat/helper-transactional-state.R
    - tests/testthat/test-transactional-state.R
    - inst/compatibility/FAILURE-SEMANTICS.md
  modified:
    - R/GEModel.R
    - R/sparseSolver.R
    - inst/compatibility/GEModel-contract.csv

key-decisions:
  - "Commit accepted sparse numerical state before post-simulation while preserving the last complete data/output until post publication succeeds."
  - "Run legacy solves on a deep reference-class copy and publish only after compilation, factorization, convergence, finiteness, residual, and update boundaries succeed."
  - "Expose retryPostsim(diagnostics = FALSE) as a solve-free retry over stored accepted state and immutable post inputs; clear the record only after complete publication."

requirements-completed: [NUM-02, COMP-03]

coverage:
  - id: D1
    description: Sparse and legacy pre-commit failures preserve every caller-visible accepted state field except structured failure diagnostics
    requirement: NUM-02
    verification:
      - kind: integration
        ref: tests/testthat/test-transactional-state.R#sparse numerical rejection matrix preserves committed state
        status: pass
      - kind: integration
        ref: tests/testthat/test-transactional-state.R#legacy rejection matrix runs on an isolated copy
        status: pass
    human_judgment: false
  - id: D2
    description: Accepted sparse levels survive post failures while prior complete output remains intact and retry publishes atomically
    requirement: NUM-02
    verification:
      - kind: integration
        ref: tests/testthat/test-transactional-state.R#post failures preserve accepted solve and prior complete output
        status: pass
    human_judgment: false
  - id: D3
    description: retryPostsim is solve-free, rejects missing records before any lifecycle stage, and preserves both documented shock-source workflows
    requirement: COMP-03
    verification:
      - kind: integration
        ref: tests/testthat/test-transactional-state.R#retryPostsim without an accepted record never enters the solver
        status: pass
      - kind: integration
        ref: tests/testthat/test-transactional-state.R#failed legacy solves do not consume either public shock source
        status: pass
      - kind: unit
        ref: tests/testthat/test-transactional-state.R#post retry API and internal helper are tiered explicitly
        status: pass
    human_judgment: false

duration: 4d17h including approved checkpoint wait
completed: 2026-09-07
status: complete
---

# Phase 02 Plan 04: Transactional Solve and Post-Simulation Retry Summary

**Sparse and legacy solves now isolate mutable work until acceptance, while accepted sparse levels survive reporting failures through an atomic, solve-free `retryPostsim()` transaction.**

## Performance

- **Duration:** 4d17h including approved checkpoint wait
- **Resumed:** 2026-09-07T07:15:17Z
- **Completed:** 2026-09-07T07:34:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added a copy-on-write sparse transaction that keeps compilation, factorization, convergence, finiteness, residual, substep, and simulation-update failures out of committed caller state.
- Added deep-copy isolation for the legacy compatibility engine, preserving closure, shock sources, levels, outputs, and derived state until the complete working solve is accepted.
- Split accepted numerical commit from post updates and output projection, preserving solved levels and diagnostics alongside the last complete output when reporting fails.
- Added `model$retryPostsim(diagnostics = FALSE)`, backed by accepted numerical state and immutable post inputs, with explicit incomplete/retryable diagnostics and no numerical re-solve.
- Documented and tested D-14, D-15, and D-17 behavior across sparse/legacy engines and preferred/direct shock APIs.

## Task Commits

Both tasks preserve RED-before-GREEN history:

1. **Task 1 RED: Sparse transaction contracts** - `11673fc`
2. **Task 1 GREEN: Transactional sparse accepted-state commit** - `22c2ef2`
3. **Task 2 RED: Legacy isolation and post retry contracts** - `4d2122a`
4. **Task 2 GREEN: Legacy isolation and retryable post transaction** - `4701477`
5. **Correctness fix: Preserve older retry eligibility after rejection** - `bdc4f3b`

## Files Created/Modified

- `R/GEModel.R` - Private retry record field, public `retryPostsim()`, and deep-copy legacy transaction wrapper with lifecycle gates.
- `R/sparseSolver.R` - Failure diagnostics, numerical/post commit seams, solve-free retry worker, legacy commit helper, and call-local post-failure classification.
- `inst/compatibility/GEModel-contract.csv` - Supported retry method plus internal field and commit/retry helper rows.
- `tests/testthat/helper-transactional-state.R` - Portable state snapshots and deterministic lifecycle phase recording/fault injection.
- `tests/testthat/test-transactional-state.R` - Sparse/legacy failure matrices, post-failure preservation, retry, shock-source, and export-boundary contracts.
- `inst/compatibility/FAILURE-SEMANTICS.md` - Normative sparse, legacy, post-failure, diagnostics, and retry semantics.

## Decisions Made

- Accepted sparse numerical work is durable before post-simulation begins; `data` and `compactOutput` remain the last complete publication until the post transaction succeeds.
- The retry record stores accepted state plus original `postsim`, output mode, variable selector, and dimension selector, and is cleared only after atomic post publication.
- Legacy remains a compatibility smoke path, but its mutation safety now matches the same caller-visible transaction contract as sparse execution.
- Post failure classification is carried on the current error rather than inferred from prior public diagnostics, preventing stale retry status from misclassifying a later pre-commit failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the scoped Git patch engine after the patch helper failed**
- **Found during:** Task 2 RED continuation
- **Issue:** The required patch helper could not create its `bwrap` namespace on this host and failed before reliably applying edits.
- **Fix:** Applied equivalent scoped unified patches through `rtk proxy git apply`, reviewed the resulting diffs, and ran `git diff --check`.
- **Files modified:** Task 2 implementation, test, contract, and documentation files.
- **Verification:** Focused and integrated regression filters pass; staged changes were restricted to Plan 02-04 files.
- **Committed in:** `4d2122a`, `4701477`

**2. [Rule 1 - Bug] Made post-failure detection call-local**
- **Found during:** Task 2 GREEN review
- **Issue:** Inferring a current post failure from `model$lastDiagnostics` could treat a new pre-commit failure as retryable when an older retry record was already present.
- **Fix:** Marked errors rethrown from the current post transaction and made the outer sparse wrapper consult that error-local marker.
- **Files modified:** `R/sparseSolver.R`
- **Verification:** Transactional and integrated regression matrices pass.
- **Committed in:** `4701477`

**3. [Rule 1 - Bug] Preserved retry eligibility after later numerical rejection**
- **Found during:** Post-GREEN lifecycle review
- **Issue:** A later pre-commit numerical failure preserved an older accepted retry record but reported `retryable_postsim = FALSE`.
- **Fix:** Derived retry eligibility from the stored record when constructing numerical-failure diagnostics and added a regression covering the state transition.
- **Files modified:** `R/sparseSolver.R`, `tests/testthat/test-transactional-state.R`
- **Verification:** Task 2 and integrated compatibility/numerical filters pass.
- **Committed in:** `bdc4f3b`

---

**Total deviations:** 3 auto-fixed (1 blocking tooling issue, 2 correctness bugs)
**Impact on plan:** These changes preserve the planned transaction architecture and public behavior; no solver method, default, equation, or numerical tolerance changed.

## Issues Encountered

- A duplicate continuation process briefly ran the same RED suite in the shared main tree. Only this executor's duplicate test processes were interrupted; related edits were preserved, reviewed, and committed atomically.
- `R CMD check .` completed with 1 error, 5 warnings, and 4 notes from pre-existing repository state. The test error remains the known 251-row fresh provenance inventory versus the 250-row Phase 1 canonical expectation (`PROVENANCE_KEY_MISMATCH`): 10 release-gate failures and 1,232 passing expectations. Warnings/notes cover excluded native object files, hidden benchmark/planning directories, non-portable benchmark paths, broad undocumented exports, placeholder license metadata, and existing check directories.
- The pre-existing reference-class warning about local assignment to `data$eqcoeff` remains unchanged.

## Verification

- `testthat::test_local(filter = "transactional-state", reporter = "summary")` - PASS.
- `testthat::test_local(filter = "transactional-state|documented-workflow|public-solver-contract", reporter = "summary")` - PASS.
- `testthat::test_local(filter = "transactional-state|numerical-baseline|sparse-core|documented-workflow|public-solver-contract|compatibility-manifest", reporter = "summary")` - PASS.
- `R CMD check .` - EXECUTED; Plan 02-04 and focused regression coverage pass, while the documented unrelated Phase 1 provenance mismatch leaves the package-wide check non-zero.

## TDD Gate Compliance

- Task 1: `11673fc` RED precedes `22c2ef2` GREEN.
- Task 2: `4d2122a` RED precedes `4701477` GREEN.
- Correctness fix: `bdc4f3b` follows GREEN and preserves retry-state diagnostics.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02-05 can serialize accepted/retry state against an explicit transactional contract.
- Plan 02-06 can include lifecycle failures and solve-free post retry in the integrated regression gate.
- No new release blocker was introduced; the pre-existing provenance and licensing blockers remain unchanged.

---
*Phase: 02-compatibility-and-numerical-baseline*
*Completed: 2026-09-07*

## Self-Check: PASSED

All seven key artifacts and all five task commits were verified on disk.
