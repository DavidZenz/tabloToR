---
phase: 02-compatibility-and-numerical-baseline
plan: 03
subsystem: numerical-validation
tags: [R, Matrix, SparseM, SuiteSparse, structured-schur, Rcpp, OpenMP, testthat]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    plan: 02
    provides: Redistributable three-region workflow and stable shock/output semantics
provides:
  - Backend-neutral pre-mutation candidate acceptance with unconditional sparse true-residual validation
  - Layered Matrix and structured-R authority comparisons across required and optional backends
  - Reviewable fixture-conditioning tolerances, compact expectations, and explicit capability skip reasons
affects: [02-04, 02-06, solver-backends, transactional-state, release-regression-gates]

actuals:
  tokens: 8824
  tasks: 2
  commits: 5

tech-stack:
  added: []
  patterns:
    - Backend candidates are accepted before state mutation through one dot-prefixed sparse gate
    - Numerical equivalence compares exact structure before finite values and absolute-plus-relative tolerances
    - Optional capabilities carry deterministic human-readable unavailability reasons

key-files:
  created:
    - tests/testthat/helper-numerical-baseline.R
    - tests/testthat/test-numerical-baseline.R
    - tests/testthat/baselines/phase02/tolerances.csv
    - tests/testthat/baselines/phase02/expectations.csv
  modified:
    - R/sparseSolver.R
    - R/zzzSparseSchurCpp.R
    - inst/compatibility/GEModel-contract.csv

key-decisions:
  - "Run one backend-neutral structure, finiteness, value, and full-system true-residual gate before any sparse candidate mutates model state; diagnostics only control retained evidence."
  - "Keep Matrix as generic numerical authority, StructuredSchurFGMRES as native structured authority, and legacy as compatibility smoke only."
  - "Select tolerances only by fixture and conditioning metadata; keep the 2e-7 exception confined to named external full-GTAP evidence."

patterns-established:
  - "Candidate/commit separation: .sparse_solve_one_step_impl accepts or rejects a complete sparse candidate before applying solution, shocks, or updates."
  - "Layered comparator: class, type, names, dimensions, dimnames, order, and missingness precede finite/value checks and independent residual recomputation."

requirements-completed: [NUM-01, NUM-02]

coverage:
  - id: D1
    description: Universal pre-mutation finiteness and full-system true-residual acceptance for sparse backend candidates
    requirement: NUM-02
    verification:
      - kind: unit
        ref: tests/testthat/test-numerical-baseline.R#bad finite candidates are rejected before state mutation
        status: pass
      - kind: integration
        ref: tests/testthat/test-numerical-baseline.R#Matrix candidate passes backend-neutral true residual acceptance
        status: pass
    human_judgment: false
  - id: D2
    description: Matrix generic authority and structured-R native authority with exact structure, finite values, abs-plus-relative equivalence, and independent residuals
    requirement: NUM-01
    verification:
      - kind: integration
        ref: tests/testthat/test-numerical-baseline.R#required generic backends execute against Matrix authority
        status: pass
      - kind: integration
        ref: tests/testthat/test-numerical-baseline.R#optional structured C++ is accepted against structured R
        status: pass
    human_judgment: false
  - id: D3
    description: Reviewable conditioning tiers, compact expectations, and explicit SuiteSparse/C++/OpenMP capability contracts
    requirement: NUM-01
    verification:
      - kind: unit
        ref: tests/testthat/test-numerical-baseline.R#conditioning tiers are explicit and never backend-specific
        status: pass
      - kind: unit
        ref: tests/testthat/test-numerical-baseline.R#mocked optional unavailability emits the exact skip reason
        status: pass
      - kind: integration
        ref: tests/testthat/test-numerical-baseline.R#optional OpenMP path matches serial native accumulation
        status: pass
    human_judgment: false

duration: 33min
completed: 2026-09-02
status: complete
---

# Phase 02 Plan 03: Numerical Authority and Residual Contracts Summary

**Every sparse backend candidate now crosses one pre-mutation structure, finiteness, equivalence, and full-system residual boundary, with Matrix and structured R serving as explicit layered authorities.**

## Performance

- **Duration:** 33 min
- **Started:** 2026-09-02T13:56:59Z
- **Completed:** 2026-09-02T14:30:21Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Centralized sparse candidate acceptance so diagnostics-off Matrix solves and all structured paths recompute the full sparse-system residual before solution, shock, or update mutation.
- Added exact structural, finite-value, absolute-plus-relative, and independently recomputed residual comparisons for Matrix, SparseM, SuiteSparse, structured R, native C++, and OpenMP paths.
- Added compact transparent expectations, ordinary strict tolerance rows, one named external conditioning exception, and deterministic optional-capability skip reasons.

## Task Commits

Both TDD tasks preserve RED-before-GREEN history, followed by one compatibility correction:

1. **Task 1 RED: Candidate acceptance contract** - `a4b1411`
2. **Task 1 GREEN: Universal pre-mutation sparse acceptance** - `21b93e5`
3. **Task 2 RED: Backend equivalence and capability contracts** - `83b2747`
4. **Task 2 GREEN: Native candidate acceptance evidence** - `00d0315`
5. **Compatibility fix: Keep fault injection internal** - `9fcee45`

## Files Created/Modified

- `R/sparseSolver.R` - Backend-neutral candidate construction, exact structure/finiteness/value checks, unconditional sparse residual acceptance, and internal fault injection.
- `R/zzzSparseSchurCpp.R` - Native candidate identity routing and retained C++ acceptance evidence.
- `inst/compatibility/GEModel-contract.csv` - Internal rows for both dot-prefixed acceptance seams.
- `tests/testthat/helper-numerical-baseline.R` - Authority declarations, capability checks, structural/value/residual comparator, and backend runners.
- `tests/testthat/test-numerical-baseline.R` - Matrix/structured authority, corruption rejection, optional capability, tolerance, and expectation coverage.
- `tests/testthat/baselines/phase02/tolerances.csv` - Strict ordinary tiers and the named external ill-conditioning exception.
- `tests/testthat/baselines/phase02/expectations.csv` - Compact three-region and tiny structured expectations.
- `.planning/phases/02-compatibility-and-numerical-baseline/deferred-items.md` - Out-of-scope package-check provenance mismatch.

## Decisions Made

- Candidate correctness is unconditional; `diagnostics` controls only whether acceptance evidence is retained in public diagnostics.
- Matrix remains the generic authority, structured R remains the C++ authority, and legacy is never promoted beyond workflow smoke.
- Tolerances are fixture/conditioning policy, not backend policy; no C++-specific tolerance exists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worked around the host patch-helper namespace failure**
- **Found during:** Task 1 GREEN and subsequent tracked-file updates
- **Issue:** The required patch helper could add files but could not update tracked files because the host kernel rejects its `bwrap` user namespace.
- **Fix:** Retried both absolute and relative patch paths, then applied the same scoped unified patches through Git's patch engine and reviewed every diff with `git diff --check`.
- **Files modified:** All tracked implementation/test files updated after the initial RED additions
- **Verification:** Focused tests and diff checks passed after each patch.
- **Committed in:** `21b93e5`, `83b2747`, `00d0315`, `9fcee45`

**2. [Rule 1 - Bug] Kept the fault-injection hook outside broad alphabetic exports**
- **Found during:** Integrated compatibility review after Task 2
- **Issue:** The initial hook argument was added to `sparse_solve_one_step`, whose alphabetic name is currently exported by the broad NAMESPACE pattern.
- **Fix:** Moved the hook to `.sparse_solve_one_step_impl`, restored the existing exported formal signature, added the internal manifest row, and tested that neither dot seam is exported.
- **Files modified:** `R/sparseSolver.R`, `R/zzzSparseSchurCpp.R`, `inst/compatibility/GEModel-contract.csv`, `tests/testthat/test-numerical-baseline.R`
- **Verification:** Numerical, public C++, sparse-core, and compatibility-manifest filters all pass.
- **Committed in:** `9fcee45`

---

**Total deviations:** 2 auto-fixed (1 blocking tooling issue, 1 compatibility bug)
**Impact on plan:** Both corrections preserve the intended internal numerical boundary and existing public signature; no solver defaults, methodology, or backend authority changed.

## Issues Encountered

- `R CMD check .` completed with 1 error, 5 warnings, and 4 notes from pre-existing repository state. The test error is 10 provenance/release-gate failures caused by a 251-row fresh inventory versus the Phase 1 canonical expectation of 250 (`PROVENANCE_KEY_MISMATCH`). Warnings/notes cover the explicitly excluded native object files, hidden benchmark/planning directories, broad undocumented exports, placeholder license metadata, and existing check directories. These are unrelated to Plan 02-03 and are recorded in `deferred-items.md`.
- The known GEModel reference-class warning about local assignment to `data$eqcoeff` remains pre-existing and out of scope.

## Verification

- `testthat::test_local(filter = "numerical-baseline", reporter = "summary")` - PASS for the tracer and final task state.
- `testthat::test_local(filter = "numerical-baseline|public-cpp-backend|sparse-core", reporter = "summary")` - PASS after all commits.
- `testthat::test_local(filter = "numerical-baseline|public-cpp-backend|sparse-core|compatibility-manifest", reporter = "summary")` - PASS after internal signature correction.
- `R CMD check .` - EXECUTED; focused numerical tests pass, but the unrelated Phase 1 provenance mismatch leaves the package-wide check non-zero.

## TDD Gate Compliance

- Task 1: `a4b1411` RED precedes `21b93e5` GREEN.
- Task 2: `83b2747` RED precedes `00d0315` GREEN.
- Compatibility correction: `9fcee45` follows GREEN and keeps the public signature unchanged.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02-04 can make the broader solve lifecycle transactional around the now-universal candidate acceptance boundary.
- Numerical authority and capability behavior are executable and reviewable; the unrelated Phase 1 provenance mismatch remains deferred to its owning release-gate scope.

---
*Phase: 02-compatibility-and-numerical-baseline*
*Completed: 2026-09-02*

## Self-Check: PASSED

All six created artifacts, seven task files, five task commits, required frontmatter fields, and coverage classification were verified on disk.
