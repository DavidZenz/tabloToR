---
phase: 03-gemodelr-identity-migration
plan: 09
subsystem: testing
tags: [R, testthat, Rcpp, native-registration, sparse-solvers, identity-migration]

requires:
  - phase: 03-08
    provides: GEModelR benchmark identity, installed resources, and the 16-failure installed-suite baseline
provides:
  - GEModelR package, namespace, option, mock-binding, and private-wrapper identity across the public/native solver family
  - Exact registration and arity coverage for all eleven GEModelR native routines
  - Installed-suite evidence that all six stale public/native producer failures are resolved
affects: [03-10, 03-11, 03-12, identity-audit, installed-qualification]

tech-stack:
  added: []
  patterns:
    - Exact registered-routine arity maps split across LU and Schur native tests
    - Identity-only test migration with numerical fixtures and tolerances unchanged

key-files:
  created: []
  modified:
    - tests/testthat/test-public-cpp-backend.R
    - tests/testthat/test-public-solver-contract.R
    - tests/testthat/test-sparse-core.R
    - tests/testthat/test-sparse-lu-cpp.R
    - tests/testthat/test-sparse-schur-cpp.R
    - tests/testthat/test-sparse-schur-openmp.R

key-decisions:
  - "Validate the complete eleven-routine native registration surface through exact GEModelR symbol names, arities, and routine count without adding predecessor literals."
  - "Keep the Phase 2 fingerprint-protected serialization helper semantics unchanged; defer its installed source-path qualification rather than weakening or refreshing the migration baseline."
  - "Treat the remaining installed-suite source-only baseline, documentation, bridge, and transactional failures as later qualification work after proving all six Plan 03-09 stale-identity failures are gone."

patterns-established:
  - "Native identity tests pair exact registered symbol names with their unchanged argument counts."
  - "Identity migrations leave solver inputs, ordering, residual checks, receiver snapshots, outputs, and tolerances byte-for-byte unchanged."

requirements-completed: [COMP-04, MIGR-01, MIGR-02]

coverage:
  - id: D1
    description: "All active public, sparse-core, LU, Schur, and OpenMP test producers use GEModelR identity."
    requirement: MIGR-01
    verification:
      - kind: integration
        ref: "focused public/native/model-serialization testthat command"
        status: pass
    human_judgment: false
  - id: D2
    description: "All eleven registered native routines retain exact GEModelR symbols and arities."
    requirement: MIGR-02
    verification:
      - kind: unit
        ref: "tests/testthat/test-sparse-lu-cpp.R#GEModelR registers the exact LU native routines and arities"
        status: pass
      - kind: unit
        ref: "tests/testthat/test-sparse-schur-cpp.R#GEModelR registers the exact Schur native routines and arities"
        status: pass
    human_judgment: false
  - id: D3
    description: "Phase 2 numerical and historical contracts remain unchanged through the identity migration."
    requirement: COMP-04
    verification:
      - kind: other
        ref: "tools/refresh_phase02_baselines.R --check-migration-source"
        status: pass
      - kind: other
        ref: "tools/check_identity_migration.R --historical-only"
        status: pass
    human_judgment: false

duration: 16min
completed: 2026-09-15
status: complete
---

# Phase 03 Plan 09: Helper and Native Solver Test Migration Summary

**GEModelR public/native solver tests with exact eleven-routine registration coverage and unchanged numerical, ordering, residual, output, and tolerance contracts.**

## Performance

- **Duration:** 16min
- **Started:** 2026-09-15T08:26:30Z
- **Completed:** 2026-09-15T08:42:26Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Migrated all 22 active predecessor references in the owned public/native test producers to GEModelR package, namespace, option, mock-binding, and private-wrapper identity.
- Added explicit registration checks for all eleven native routines, preserving arities 1, 2, 1, 6, 7, 0, 2, 1, 9, 7, and 9.
- Preserved every solver fixture, matrix, vector, ordering loop, capability/OpenMP branch, residual check, failure mode, output assertion, and tolerance.
- Reduced the installed full-suite failures from 16 to 10; no public/native test owned by this plan remains among the failures.

## Task Commits

1. **Task 1 RED: Add failing native identity contracts** — `789dfc7`
2. **Task 1 GREEN: Migrate helper and native test identity** — `df52048`

## Test Results

- Focused public/native/model-serialization suite — PASS after migration and again at the tracer feedback gate.
- Phase 02 migration-source gate — PASS; normalized fingerprint `aee225f16707f20978a4f4318bffb4fe`, raw fingerprint `f183603b643e74a48e1a81723211df6d`, accepted canonical hash `f6f2297a6ab257c9737a64354c82d7f1`.
- Historical-only identity audit — PASS: 5 immutable records, 4 protected numerical sources, 1 protected region, and 1 immutable predecessor occurrence.
- Archive build — PASS for `GEModelR_0.1.0.tar.gz` in an isolated temporary directory.
- Full installed archive check — NONZERO with 10 residual failures, 820 assertions passing, 113 skips, 1 warning, and 4 notes. The prior six stale public/native failures are absent.

## TDD Gate Compliance

- RED commit `789dfc7` added exact current native symbol/arity contracts while the focused suite still failed at six stale producer paths.
- GREEN commit `df52048` migrated only identity-bearing references and passes the focused suite plus both continuous migration gates.
- No refactor commit was needed; the final diff is registration coverage plus mechanical identity substitution.

## Files Created/Modified

- `tests/testthat/test-public-cpp-backend.R` — GEModelR namespace for mocked partition bindings.
- `tests/testthat/test-public-solver-contract.R` — GEModelR namespace and private-export prefix contract.
- `tests/testthat/test-sparse-core.R` — GEModelR vectorized-emitter option identity.
- `tests/testthat/test-sparse-lu-cpp.R` — current LU/dense private wrappers plus exact five-routine registration/arity coverage.
- `tests/testthat/test-sparse-schur-cpp.R` — current Schur private wrappers plus exact six-routine registration/arity coverage.
- `tests/testthat/test-sparse-schur-openmp.R` — current capability, serial, and parallel wrapper identities.

The three owned helper files already used current GEModelR identity at plan start and required no final content change.

## Decisions Made

- Split the eleven native arity assertions by solver family so LU and Schur tests each prove the routines they exercise.
- Assert the exact total routine count without introducing new predecessor literals that would create migration-source occurrence drift.
- Preserve the protected serialization helper's source-only bridge lookup because an installed-first experiment changed the Phase 2 normalized fingerprint and was correctly rejected by the gate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the approved file-scoped Git patch fallback**
- **Found during:** Task 1 RED and GREEN edits
- **Issue:** The required patch helper could not initialize because the host kernel disallows unprivileged user namespaces.
- **Fix:** Applied only task-owned unified patches through the approved `rtk proxy ... git apply` fallback.
- **Files modified:** The six changed public/native test files.
- **Verification:** `git diff --check`, focused tests, migration-source gate, historical audit, and installed archive check.
- **Committed in:** `789dfc7`, `df52048`

---

**Total deviations:** 1 auto-fixed blocking tooling issue.
**Impact on plan:** The fallback changed only the editing mechanism; test and numerical scope remained exact.

## Issues Encountered

- The full installed archive check remains nonzero on 10 source-only baseline, documentation, predecessor-bridge, and transactional test-path failures assigned to later phase qualification. No Plan 03-09 public/native producer failure remains.
- An attempted installed fallback for the fingerprint-protected serialization helper was not retained because the migration-source gate detected normalized source drift. The final helper and all accepted Phase 2 fingerprints remain unchanged.
- The host RTK wrapper cannot be nested inside `rtk proxy`; the tracer verification was therefore rerun as three individually wrapped commands with identical ordering and all passed.
- Pre-existing package warnings/notes remain for hidden and non-portable planning paths, license metadata, undocumented exports, and installed size.

## Known Stubs

None.

## User Setup Required

None - no external service, credentials, or manual migration action is required.

## Next Phase Readiness

- Plan 03-10 can classify the retained predecessor occurrence against the exact occurrence-level allowlist.
- Later qualification plans retain the 10 installed source-path failures recorded in `deferred-items.md`.
- Release blockers for dependency compatibility, attribution identity, and the fresh release-kind check remain unchanged.

## Self-Check: PASSED

- The summary and all six modified test files exist.
- RED commit `789dfc7` and GREEN commit `df52048` exist in repository history in the required order.
- Final focused, migration-source, and historical gates pass with no stubs or unintended deletions.

---
*Phase: 03-gemodelr-identity-migration*
*Completed: 2026-09-15*
