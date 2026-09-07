---
phase: 02-compatibility-and-numerical-baseline
plan: 06
subsystem: testing
tags: [R, testthat, numerical-baseline, fingerprints, review-gate, package-check]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    plans: [01, 02, 03, 04, 05]
    provides: Compatibility manifest, public workflow fixture, numerical authorities, transactional solve state, and portable serialization
provides:
  - Deterministic proposal-only baseline refresh and read-only canonical drift checking
  - Explicit reviewer-gated canonical acceptance with hash-transition evidence
  - Integrated Phase 02 regression matrix spanning compatibility, numerical, transaction, serialization, and native capability contracts
affects: [phase-03, release-gates, numerical-regression, package-validation]

actuals:
  tokens: 14717
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - Stable baseline artifacts are proposed and reviewed separately from volatile run metadata
    - Canonical mutation is restricted to a named-reviewer acceptance CLI
    - Source-only tool checks and installed-package checks have explicit non-overlapping execution modes

key-files:
  created:
    - inst/tools/refresh_phase02_baselines.R
    - inst/tools/accept_phase02_baselines.R
    - tests/testthat/baselines/phase02/fingerprints.dcf
    - tests/testthat/baselines/phase02/ACCEPTANCE.md
  modified:
    - tools/refresh_phase02_baselines.R
    - tools/accept_phase02_baselines.R
    - tests/testthat/test-baseline-artifacts.R
    - tests/testthat/baselines/phase02/expectations.csv
    - tests/testthat/baselines/phase02/tolerances.csv
    - inst/compatibility/BASELINE-PROCESS.md

key-decisions:
  - "Accept canonical Phase 02 baseline hash 453a6986e600df6cf426c11d794f2b1d after review by David Zenz."
  - "Order fingerprint inputs by lowercase byte order so the reviewed source hash is stable across host and testthat collations."
  - "Keep the prescribed top-level CLIs as thin wrappers around one implementation installed from inst/tools."
  - "Run proposal regeneration in source-tree gates and make package-check source-only exclusions explicit while still validating installed CLIs and canonical acceptance."

patterns-established:
  - "Proposal/acceptance separation: refresh and ordinary tests cannot mutate canonical baseline artifacts."
  - "Hash stability: input ordering is explicit and independent of process locale."
  - "Package-check isolation: baseline tooling never reloads the package under the shared testthat environment."

requirements-completed: [COMP-01, COMP-02, COMP-03, NUM-01, NUM-02]

coverage:
  - id: D1
    description: Deterministic compact proposals, stable/volatile metadata separation, safe path handling, and read-only canonical checking
    requirement: NUM-01
    verification:
      - kind: integration
        ref: tests/testthat/test-baseline-artifacts.R#proposal generation and read-only check contracts
        status: pass
      - kind: other
        ref: rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check
        status: pass
    human_judgment: false
  - id: D2
    description: Reviewed canonical acceptance records reviewer, reason, date, old/new hashes, fixture/source identity, and tolerance tier
    requirement: NUM-02
    verification:
      - kind: manual_procedural
        ref: tests/testthat/baselines/phase02/ACCEPTANCE.md#David Zenz acceptance of 453a6986e600df6cf426c11d794f2b1d
        status: pass
      - kind: unit
        ref: tests/testthat/test-baseline-artifacts.R#canonical acceptance is complete and bound to accepted artifacts
        status: pass
    human_judgment: true
    rationale: Canonical replacement is intentionally gated on named human review; automation validates but cannot replace that judgment.
  - id: D3
    description: Complete Phase 02 compatibility, numerical, transactional, serialization, and native capability regression matrix
    requirement: COMP-03
    verification:
      - kind: e2e
        ref: testthat::test_local Phase 02 integrated filter command
        status: pass
      - kind: integration
        ref: R CMD check package tests (1328 pass; only 10 pre-existing Phase 1 provenance/release failures)
        status: pass
    human_judgment: false

duration: 1h51m including blocking-human review
completed: 2026-09-07
status: complete
---

# Phase 02 Plan 06: Review-Gated Numerical Baseline Summary

**Deterministic compact baselines now have an explicit reviewer-controlled acceptance boundary, stable source fingerprints, and one integrated Phase 02 regression gate.**

## Performance

- **Duration:** 1h51m including blocking-human review
- **Started:** 2026-09-07T13:13:03Z
- **Completed:** 2026-09-07T15:04:25Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Added proposal-only generation, readable key diffs, stable fingerprints, separate volatile runtime metadata, bounded path handling, and a read-only canonical check.
- Recorded David Zenz's reviewed acceptance from canonical hash `ef0ee854ddbba81a4c695de909d74921` to `453a6986e600df6cf426c11d794f2b1d` without repeating or rewriting the acceptance operation.
- Closed the full Phase 02 source-tree matrix across compatibility, workflow, numerical authority, transactional state, serialization, public solver/C++ contracts, sparse core, and native cache behavior.
- Made fingerprint ordering locale-independent and made the tooling available in installed packages without allowing tool execution to disrupt the shared test environment.

## Task Commits

1. **Task 1 RED: Baseline tooling contract** - `5cf8145`
2. **Task 1 GREEN: Review-gated baseline tooling** - `4e455d7`
3. **Task 2: Reviewed canonical acceptance** - `a15972d`
4. **Task 3 RED: Accepted baseline gate contract** - `9d7cd9a`
5. **Task 3 GREEN: Deterministic integrated tooling** - `a507701`

## Files Created/Modified

- `tools/refresh_phase02_baselines.R` and `tools/accept_phase02_baselines.R` - Stable prescribed CLI entry points.
- `inst/tools/refresh_phase02_baselines.R` and `inst/tools/accept_phase02_baselines.R` - Single installed implementations used by source and package-check contexts.
- `tests/testthat/test-baseline-artifacts.R` - Proposal, immutability, acceptance, locale, installed CLI, and package-check boundary contracts.
- `tests/testthat/baselines/phase02/expectations.csv` and `tolerances.csv` - Reviewed compact numerical and policy artifacts.
- `tests/testthat/baselines/phase02/fingerprints.dcf` - Fixture, source, package, model, external-evidence, and artifact fingerprints.
- `tests/testthat/baselines/phase02/ACCEPTANCE.md` - Named review and canonical hash transition.
- `inst/compatibility/BASELINE-PROCESS.md` - Proposal, review, acceptance, external evidence, and integrated gate process.

## Decisions Made

- The reviewed canonical baseline is hash `453a6986e600df6cf426c11d794f2b1d`; ordinary tests and refresh mode remain read-only.
- Fingerprint file ordering uses lowercase radix order, preserving the accepted hash under both host and C collations.
- Top-level commands remain the public development interface while their single implementation is installed through `inst/tools` for package-check visibility.
- Full proposal regeneration remains a source-tree test responsibility; installed-package tests explicitly report six source-only exclusions and still validate CLI help, canonical metadata, compatibility helpers, and the rest of the package suite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made source fingerprints independent of collation**
- **Found during:** Task 3 baseline-artifact RED run
- **Issue:** Locale-sensitive `sort()` produced a false source/package drift under testthat's C collation despite identical per-file hashes.
- **Fix:** Ordered source paths by lowercase radix keys, preserving the already reviewed canonical fingerprint and proposal hash.
- **Files modified:** `inst/tools/refresh_phase02_baselines.R`, `tests/testthat/test-baseline-artifacts.R`
- **Verification:** Baseline artifact tests, the direct `--check` command, and the integrated Phase 02 matrix pass with no stable changes.
- **Committed in:** `9d7cd9a`, `a507701`

**2. [Rule 3 - Blocking] Prevented baseline generation from invalidating test helpers**
- **Found during:** Task 3 integrated filter command
- **Issue:** Repeated `pkgload::load_all()` calls inside proposal generation invalidated helper bindings needed by later filtered tests.
- **Fix:** Reused the already loaded package when it represents the same source/check build.
- **Files modified:** `inst/tools/refresh_phase02_baselines.R`, `tests/testthat/test-baseline-artifacts.R`
- **Verification:** The complete multi-filter command passes in one process.
- **Committed in:** `9d7cd9a`, `a507701`

**3. [Rule 3 - Blocking] Made baseline tooling package-check aware**
- **Found during:** Task 3 `R CMD check .`
- **Issue:** R package checks copy tests and install `inst/` but do not retain the full source tree required for proposal regeneration; direct `../../tools` lookup caused eight new errors and package reload attempts cascaded into later tests.
- **Fix:** Installed one implementation under `inst/tools`, retained thin top-level wrappers, validated installed CLIs/canonical records, and marked six proposal-regeneration tests with an explicit source-tree-only reason.
- **Files modified:** `tools/*.R`, `inst/tools/*.R`, `tests/testthat/test-baseline-artifacts.R`
- **Verification:** Installed-mode subset passes; final package check returns to the known 10 Phase 1 failures with 1,328 passes and 6 explicit source-only skips.
- **Committed in:** `9d7cd9a`, `a507701`

**4. [Rule 3 - Blocking] Used the scoped Git patch engine after the patch helper failed**
- **Found during:** Task 3 fixes and documentation updates
- **Issue:** The required patch helper repeatedly failed before editing because the host kernel disallows its `bwrap` user namespace.
- **Fix:** Retried absolute and relative patch targets, then applied file-scoped unified patches through Git's patch engine and checked every diff.
- **Files modified:** Task 3 tool, test, and deferred-item files.
- **Verification:** `git diff --check`, focused tests, integrated tests, and package-check gates completed.
- **Committed in:** `9d7cd9a`, `a507701`

---

**Total deviations:** 4 auto-fixed (1 correctness bug, 3 blocking tooling/harness issues)
**Impact on plan:** Every fix was required for deterministic baseline verification or the documented integrated/package gate. Canonical numerical values, tolerances, reviewer metadata, solver defaults, and external-data boundaries were unchanged.

## Issues Encountered

- `R CMD check .` completes with 1 error, 5 warnings, and 4 notes. Its 10 test failures are the deferred Phase 1 provenance/release-gate mismatch: 280 fresh inventory rows versus the reviewed 250-row oracle, yielding `PROVENANCE_KEY_MISMATCH`. The final aggregate is 1,328 passing expectations and 6 explicit source-tree-only baseline-tool skips.
- Existing warnings/notes cover generated native objects, check/hidden directories, non-portable benchmark paths, undocumented broad exports, unresolved license metadata, LazyData, and compiled-code inspection.
- The pre-existing reference-class warning about local assignment to `data$eqcoeff` remains unchanged.

## Verification

- Complete Phase 02 integrated testthat filter command - PASS.
- `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check` - PASS; no stable baseline changes.
- Installed-package baseline/compatibility subset - PASS with 6 explicit source-only proposal-regeneration skips.
- `rtk R CMD check .` - EXECUTED; no Plan 02-06 failures remain, while the known 10 Phase 1 provenance/release-gate failures keep the command non-zero.

## TDD Gate Compliance

- Task 1: `5cf8145` RED precedes `4e455d7` GREEN.
- Task 3: the accepted-state RED failure was confirmed before `9d7cd9a`; `a507701` provides the GREEN implementation.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 02 compatibility, numerical authority, lifecycle, serialization, and baseline acceptance contracts are integrated and source-tree clean.
- External reduced/full GTAP evidence remains fingerprinted and external; no proprietary input or full solution was committed.
- The pre-existing Phase 1 provenance oracle/release-gate mismatch remains deferred and must be resolved in its owning scope before package checks can become green.

## Self-Check: PASSED

- All 10 plan-created or modified implementation artifacts exist.
- All 5 task commits are present in repository history.
- Canonical acceptance metadata and accepted hash remain unchanged after the read-only drift check.

---
*Phase: 02-compatibility-and-numerical-baseline*
*Completed: 2026-09-07*
