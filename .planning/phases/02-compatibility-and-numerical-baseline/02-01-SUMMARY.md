---
phase: 02-compatibility-and-numerical-baseline
plan: 01
subsystem: testing
tags: [R, testthat, compatibility, reference-classes, contract-manifest]

requires:
  - phase: 01-provenance-and-release-boundary
    provides: Audited public-source and no-proprietary-data boundary
provides:
  - Complete tiered inventory of 171 alphabetic exports, 24 GEModel fields, 8 declared methods, and 6 backend values
  - Exact source-formal and default regression contract for GEModel methods
  - Reusable structural descriptors and encoding-aware equality/default helpers
affects: [02-02, 02-03, package-migration, public-api]

actuals:
  tokens: 10706
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns: [manifest-driven compatibility checks, structural-first comparisons, TDD red-green commits]

key-files:
  created:
    - inst/compatibility/GEModel-contract.csv
    - tests/testthat/helper-compatibility.R
    - tests/testthat/test-compatibility-manifest.R
    - tests/testthat/test-compatibility-helpers.R
  modified: []

key-decisions:
  - "Keep GEModel as the supported namespace entry point while recording other alphabetic exports as observed internal surface without narrowing NAMESPACE."
  - "Treat raw saveRDS(model) persistence as compatibility-only same-version best effort and keep legacy execution as workflow smoke rather than numerical authority."

patterns-established:
  - "Observed-surface completeness: runtime namespace/class enumeration must match exactly one tiered manifest row."
  - "Structural-first comparison: class, type, names, dimensions, dimnames, missingness, and encoding precede later numerical comparisons."

requirements-completed: [COMP-01, COMP-02, COMP-03]

coverage:
  - id: D1
    description: Tiered machine-readable GEModel compatibility manifest with exact observed-surface coverage
    requirement: COMP-03
    verification:
      - kind: unit
        ref: tests/testthat/test-compatibility-manifest.R#compatibility manifest covers the observed package surface
        status: pass
    human_judgment: false
  - id: D2
    description: Exact omitted engine and backend defaults remain legacy and Matrix
    requirement: COMP-02
    verification:
      - kind: unit
        ref: tests/testthat/test-compatibility-manifest.R#method signatures and source defaults are exact
        status: pass
      - kind: integration
        ref: tests/testthat/test-public-solver-contract.R#solver defaults and reference backend remain unchanged
        status: pass
    human_judgment: false
  - id: D3
    description: Structural helpers preserve empty singleton NULL indexed encoding and selector contracts
    requirement: COMP-03
    verification:
      - kind: unit
        ref: tests/testthat/test-compatibility-helpers.R
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-02
status: complete
---

# Phase 02 Plan 01: Compatibility Manifest and Structural Helpers Summary

**A 219-row tiered GEModel contract now freezes the observed package/class surface, exact defaults, serialization scope, and structural edge cases in executable testthat checks.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-02T12:25:14Z
- **Completed:** 2026-09-02T12:45:21Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Classified every observed alphabetic export, declared GEModel field/method, backend label, authority role, serialization disposition, and structural case without changing NAMESPACE or package behavior.
- Added exact signature/default checks that freeze legacy engine, Matrix backend, full output, reduction, and NULL selector defaults.
- Added reusable descriptors and deterministic tests for empty, singleton, NULL, indexed, missing, encoded-character, selector, equality, and omitted-versus-explicit cases.

## Task Commits

Each TDD task was committed as a RED/GREEN pair:

1. **Task 1 RED: Freeze observed GEModel contract tests** - `9b78518`
2. **Task 1 GREEN: Manifest and loader implementation** - `6cadba3`
3. **Task 2 RED: Structural compatibility edge cases** - `5646414`
4. **Task 2 GREEN: Structural descriptors and equality/default helpers** - `d2d153d`

## Files Created/Modified

- `inst/compatibility/GEModel-contract.csv` - Tiered 219-row observed-surface and compatibility contract.
- `tests/testthat/helper-compatibility.R` - Manifest validation, observed-surface enumeration, structural descriptions, equality, and default helpers.
- `tests/testthat/test-compatibility-manifest.R` - Completeness, tier, traceability, signature/default, serialization, and numerical-authority assertions.
- `tests/testthat/test-compatibility-helpers.R` - Deterministic structural, selector, encoding/equality, and default-equivalence assertions.

## Decisions Made

- Only `GEModel` is recorded as the supported namespace entry point in this plan; other broad-pattern exports remain inventoried as internal until the deliberate Phase 4 API narrowing.
- Raw reference-object persistence is explicitly compatibility-only and same-version best effort; the future logical serialization contract remains separate.
- `Matrix` is the generic numerical reference and `StructuredSchurFGMRES` is the structured-R reference; legacy is recorded only as a compatibility smoke path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected required-formal serialization**
- **Found during:** Task 1 GREEN verification
- **Issue:** Required method arguments initially serialized as an empty string instead of `<required>`.
- **Fix:** Made formal serialization detect empty deparse output and regenerated method rows.
- **Files modified:** `tests/testthat/helper-compatibility.R`, `inst/compatibility/GEModel-contract.csv`
- **Verification:** The exact loadData and solveModel formal/default assertions pass.
- **Committed in:** `6cadba3`

---

**Total deviations:** 1 auto-fixed bug
**Impact on plan:** The fix is limited to contract correctness; package behavior and solver methodology are unchanged.

## Issues Encountered

- The patch helper could add files but could not update them because the host disallows its `bwrap` namespace setup. Scoped R/perl writes were used only for the generated CSV and targeted helper updates after the patch helper failed; all resulting diffs were reviewed with `git diff --check`.
- The known pre-existing GEModel reference-class warning about local assignment to `data$eqcoeff` remains unchanged and outside this plan.

## Verification

- `testthat::test_local(filter = "compatibility-helpers|compatibility-manifest", reporter = "summary")` — PASS (45 expectations).
- `testthat::test_local(filter = "compatibility-helpers|compatibility-manifest|public-solver-contract", reporter = "summary")` — PASS (new contract plus existing public defaults/preflight checks).
- Manifest inventory check — PASS (219 rows: 171 exports, 24 fields, 8 methods, 6 backends, and 10 documented contract rows).

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02-02 can consume the manifest loader and structural helpers for full workflow, shock, output, and legacy-smoke characterization.
- No new blocker was introduced; full package check remains the Phase 02 integrated gate as planned.

---
*Phase: 02-compatibility-and-numerical-baseline*
*Completed: 2026-09-02*

## Self-Check: PASSED

All four key artifacts and all four task commits were verified on disk.
