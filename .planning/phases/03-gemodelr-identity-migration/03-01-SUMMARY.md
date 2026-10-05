---
phase: 03-gemodelr-identity-migration
plan: 01
subsystem: testing
tags: [R, testthat, identity-migration, numerical-baseline, sha256, evidence-gate]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    provides: Reviewed Phase 02 baseline artifacts, solver contracts, and accepted predecessor fingerprints
provides:
  - Non-circular identity-aware Phase 02 source comparison
  - Independent SHA-256 registry for immutable baseline and benchmark evidence
  - Exact historical predecessor occurrence audit and protected numerical-source gates
affects: [phase-03-plans, identity-migration, numerical-regression, release-gates]

actuals:
  tokens: 13694
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - Exact predecessor/current literals normalize to reviewed canonical identity tokens before source hashing
    - Immutable historical evidence uses independent whole-file SHA-256 digests
    - Intentional predecessor occurrences require exact path, count, line digest, and file digest records

key-files:
  created:
    - inst/migration/benchmark-identity-map.dcf
    - inst/migration/historical-evidence.dcf
    - inst/migration/old-identity-allowlist.csv
    - tools/check_identity_migration.R
    - tests/testthat/test-identity-migration.R
  modified:
    - inst/tools/refresh_phase02_baselines.R
    - tests/testthat/test-baseline-artifacts.R

key-decisions:
  - "Keep the original Phase 02 check proposal-only and add identity-aware comparison as an independent read-only mode."
  - "Freeze the four accepted Phase 02 files and reviewed GTAP result with independent SHA-256 digests outside baseline generation."
  - "Permit historical predecessor identity only through exact path, count, line-digest, and whole-file-digest records; broad patterns fail closed."

patterns-established:
  - "Identity-only source migration: exact reviewed old/new literals canonicalize before protected source digests are compared."
  - "Historical evidence boundary: accepted predecessor bytes are never regenerated or relabeled."
  - "Numerical preservation: public signature, defaults, ordering, tolerances, true-residual logic, solver sources, and GEModel line 228 remain continuously checked."

requirements-completed: [MIGR-01, MIGR-02]

coverage:
  - id: D1
    description: Non-circular identity-aware Phase 02 gate accepts exact reviewed identity substitutions and rejects non-identity drift
    requirement: MIGR-02
    verification:
      - kind: integration
        ref: tests/testthat/test-baseline-artifacts.R#identity-aware migration source gate
        status: pass
      - kind: other
        ref: rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check-migration-source
        status: pass
    human_judgment: false
  - id: D2
    description: Immutable Phase 02 and GTAP evidence plus protected numerical sources are independently SHA-256 frozen
    requirement: MIGR-02
    verification:
      - kind: unit
        ref: tests/testthat/test-baseline-artifacts.R#accepted Phase 2 bytes have independent SHA-256 evidence
        status: pass
      - kind: integration
        ref: tests/testthat/test-identity-migration.R#historical registry freezes evidence and numerical source
        status: pass
    human_judgment: false
  - id: D3
    description: Historical predecessor occurrences are exact, reviewable, and fail closed on malformed, broad, duplicate, stale, count, line, or file-digest records
    requirement: MIGR-01
    verification:
      - kind: integration
        ref: tests/testthat/test-identity-migration.R#historical old-identity records reject broad or stale entries
        status: pass
      - kind: other
        ref: rtk Rscript --vanilla tools/check_identity_migration.R --historical-only
        status: pass
    human_judgment: false

duration: 22h10m including blocking-human review
completed: 2026-09-11
status: complete
---

# Phase 03 Plan 01: Identity-Aware Historical and Numerical Gates Summary

**Reviewed identity-only substitutions can now proceed without letting the GEModelR rename regenerate its own numerical oracle or rewrite predecessor evidence.**

## Performance

- **Duration:** 22h10m including blocking-human review
- **Started:** 2026-09-10T14:42:41Z
- **Completed:** 2026-09-11T12:52:11Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added a strict two-row predecessor/current identity map and a separate read-only migration-source mode that accepts only exact reviewed identity substitutions.
- Pinned the four accepted Phase 02 artifacts and reviewed GTAP result with independent SHA-256 digests, plus identity-normalized digests for all four protected solver sources and an exact digest for the warning-bearing R/GEModel.R line-228 region.
- Added a historical-only audit whose exact CSV records reject path escapes, globs, duplicates, stale rows, count drift, matching-line drift, and whole-file drift while preserving all five flagged-unverified assumptions.

## Task Commits

1. **Task 1 RED: Identity-aware baseline gate contract** - `ece6aa4`
2. **Task 1 GREEN: Non-circular Phase 02 source gate** - `754f529`
3. **Task 2 RED: Historical evidence and numerical invariant contract** - `805ba39`
4. **Task 2 GREEN: Immutable evidence and exact predecessor audit** - `52debf2`

## Files Created/Modified

- `inst/migration/benchmark-identity-map.dcf` - Strict reviewed predecessor/current literal map and normalized source fingerprint.
- `inst/migration/historical-evidence.dcf` - Independent immutable-file, normalized-source, and line-region SHA-256 registry.
- `inst/migration/old-identity-allowlist.csv` - Exact intentional historical predecessor occurrence record.
- `tools/check_identity_migration.R` - Read-only historical evidence, numerical contract, safe-path, and occurrence audit.
- `inst/tools/refresh_phase02_baselines.R` - Separate identity-aware source gate without an acceptance writer path.
- `tests/testthat/test-baseline-artifacts.R` - Identity mutation and independent historical digest coverage.
- `tests/testthat/test-identity-migration.R` - Registry, allowlist, numerical invariant, and unresolved-assumption mutation matrix.

## Decisions Made

- The original `--check` remains proposal-only; `--check-migration-source` is a separate read-only gate.
- Immutable evidence is pinned with SHA-256 independently of the Phase 02 MD5-based baseline generator.
- Protected solver sources are hashed only after exact DCF-reviewed identity normalization; all other source bytes remain authoritative.
- Historical predecessor occurrences use exact record-level evidence. No directory, glob, or broad exclusion is accepted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the scoped Git patch engine after the patch helper failed**
- **Found during:** Task 2 RED test authoring
- **Issue:** The required patch helper could not initialize because the host kernel disallows its bubblewrap user namespace, and no standalone helper was available.
- **Fix:** Applied file-scoped unified patches through Git's patch engine and checked every resulting diff.
- **Files modified:** Task 2 test, registry, allowlist, and audit-tool files.
- **Verification:** Focused tests, `git diff --check`, plan gates, and `R CMD check .` completed.
- **Committed in:** `805ba39`, `52debf2`

**2. [Rule 1 - Bug] Removed OpenSSL hash class attributes before exact comparison**
- **Found during:** Task 2 GREEN focused tests
- **Issue:** `openssl::sha256()` rendered the correct hexadecimal digest with `hash` and `sha256` classes, causing strict character equality to fail.
- **Fix:** Returned the unclassed hexadecimal character value from the hash helper.
- **Files modified:** `tools/check_identity_migration.R`
- **Verification:** All independent artifact digest assertions and historical registry checks pass.
- **Committed in:** `52debf2`

**3. [Rule 1 - Bug] Kept expectation calls compatible with the installed testthat**
- **Found during:** Task 2 GREEN focused tests
- **Issue:** The installed testthat version rejects the unsupported `info` argument on `expect_length()`.
- **Fix:** Removed only that optional argument while retaining exact per-assumption assertions.
- **Files modified:** `tests/testthat/test-identity-migration.R`
- **Verification:** The identity migration test file passes all 41 expectations.
- **Committed in:** `52debf2`

**4. [Rule 3 - Blocking] Reconciled progress after the state updater skipped an unscoped phase**
- **Found during:** Plan close-out
- **Issue:** `state.update-progress` reported the phase scope as unscoped and left the global progress text and velocity totals stale.
- **Fix:** Reconciled the completed-plan count, 62% global progress, Phase 03 metrics, and current activity while preserving the SDK-updated plan position and session fields.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE records 18 of 29 plans complete and ROADMAP records Phase 03 at 1/12.
- **Committed in:** plan metadata commit

---

**Total deviations:** 4 auto-fixed (2 correctness bugs, 2 blocking tooling issues)
**Impact on plan:** The fixes were limited to patch delivery, strict test compatibility, and execution-state bookkeeping. Historical bytes, solver algorithms, signatures, defaults, tolerances, ordering, and residual logic were unchanged.

## Issues Encountered

- `R CMD check .` exits successfully with 5 warnings and 4 notes from pre-existing repository state: compiled objects/shared library, hidden benchmark/check directories, non-portable private benchmark paths, placeholder license metadata, broad undocumented exports, LazyData without data, and compiled-code inspection.
- The pre-existing ReferenceClass warning about local assignment to `data$eqcoeff` remains unchanged and is emitted by baseline generation.
- The source tree already contained unrelated dirty Phase 3 tracking, proposal, cache, and compiled artifacts. None were staged or committed.

## Verification

- `rtk Rscript --vanilla tools/check_identity_migration.R --historical-only` - PASS: 5 immutable records, 4 protected sources, 1 protected region, 1 historical predecessor occurrence.
- `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check` - PASS: no stable baseline changes.
- `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check-migration-source` - PASS: normalized fingerprint `e4e8b11927023136491ed86c064d811f`, raw predecessor fingerprint `f57c39e0bdd3020b48a602773c580a8d`, accepted canonical hash `f6f2297a6ab257c9737a64354c82d7f1`.
- Focused baseline and identity-migration test files - PASS.
- Independent SHA-256 verification of all five immutable evidence files - PASS.
- `rtk R CMD check .` - PASS with 5 pre-existing warnings and 4 pre-existing notes.

## TDD Gate Compliance

- Task 1: `ece6aa4` RED precedes `754f529` GREEN.
- Task 2: `805ba39` RED failed on the absent historical gate before `52debf2` GREEN implemented it.

## Known Stubs

None. The conditional source-tree skip in the identity test is inactive in source/check validation and intentionally prevents an installed-only context from pretending top-level development tooling exists.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-02 can add predecessor serialization lineage while the package still identifies as tabloToR.
- Every later Phase 03 identity edit can run independent historical-byte and normalized numerical-source gates.
- Release remains intentionally blocked by the existing dependency-license audit and unresolved attribution alias; this plan does not alter those governance gates.

## Self-Check: PASSED

- All 7 plan-created or modified implementation artifacts exist.
- All 4 TDD task commits are present in repository history.
- The four accepted Phase 02 artifacts and reviewed GTAP result retain their recorded SHA-256 digests.
- No plan commit deleted a tracked file or included excluded user-owned dirty artifacts.

---
*Phase: 03-gemodelr-identity-migration*
*Completed: 2026-09-11*
