---
phase: 01-provenance-and-release-boundary
plan: 05
subsystem: attribution
tags: [r, testthat, provenance, authorship, citation, release-boundary]

requires:
  - phase: 01-03
    provides: Deterministic reviewed provenance inventory and exact expected-key oracle
  - phase: 01-04
    provides: Reviewed governance evidence, rights findings, and unresolved identity blockers
provides:
  - MD5-bound evidence-to-role attribution contract
  - Consistent reviewed credit across all six required attribution destinations
  - Direct fail-closed tests for attribution parity and stale evidence keys
affects: [01-06, package-metadata, release-qualification]

actuals:
  tokens: 6574
  tasks: 2
  commits: 6

tech-stack:
  added: []
  patterns:
    - Evidence keys join reviewed provenance records to every public attribution destination
    - Attribution tests parse Markdown, CSV, DCF, and CITATION files independently

key-files:
  created:
    - docs/provenance/ATTRIBUTION.md
    - CONTRIBUTORS.md
    - NEWS.md
    - inst/CITATION
    - tests/testthat/test-attribution-contract.R
  modified:
    - DESCRIPTION
    - README.md

key-decisions:
  - "Assign David Zenz aut/cre/cph and Maros Ivanic aut only from reviewed source and governance evidence."
  - "Credit the upstream public-domain/CC0 baseline voluntarily while keeping mivanicERS unresolved."
  - "Keep the package named tabloToR and defer final package licensing and standalone Maintainer metadata to Plan 01-06."

patterns-established:
  - "Evidence-key parity: every destination carries the same reviewed key set and rejects stale keys."
  - "Fail-closed credit: missing evidence, unreviewed roles, or destination drift emits a named attribution error."

requirements-completed: [PROV-02]

coverage:
  - id: D1
    description: Reviewed people, roles, evidence keys, and blockers are recorded against the immutable 250-row provenance snapshot.
    requirement: PROV-02
    verification:
      - kind: unit
        ref: tests/testthat/test-attribution-contract.R#reviewed attribution record
        status: pass
      - kind: integration
        ref: Rscript --vanilla tools/provenance_inventory.R --check --expected docs/provenance/EXPECTED-KEYS.csv
        status: pass
    human_judgment: false
  - id: D2
    description: DESCRIPTION, README, CITATION, PROVENANCE, CONTRIBUTORS, and NEWS expose one consistent reviewed attribution key set.
    requirement: PROV-02
    verification:
      - kind: unit
        ref: tests/testthat/test-attribution-contract.R#destination parity
        status: pass
    human_judgment: false
  - id: D3
    description: Attribution drift and stale evidence fail closed while the public release boundary remains blocked.
    requirement: PROV-02
    verification:
      - kind: unit
        ref: tests/testthat/test-attribution-contract.R#negative attribution cases
        status: pass
      - kind: integration
        ref: Rscript --vanilla tools/check_release_gates.R --assert-blocked
        status: pass
    human_judgment: false

duration: 20 min
completed: 2026-08-25
status: complete
---

# Phase 1 Plan 5: Attribution Propagation Summary

**MD5-bound reviewed authorship and CC0 predecessor credit propagated consistently across package metadata, documentation, citation, provenance, contributor, and release-note destinations.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-25T11:52:57Z
- **Completed:** 2026-08-25T12:12:34Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Bound David Zenz and Maros Ivanic's reviewed roles to the exact 250-row provenance snapshot (`90940fa1b5bdc223b6829255f5e87e71`) and explicit evidence keys.
- Propagated the same attribution contract through `DESCRIPTION`, `README.md`, `inst/CITATION`, `docs/provenance/PROVENANCE.csv`, `CONTRIBUTORS.md`, and `NEWS.md`.
- Added 40 direct assertions that parse every destination independently and reject missing evidence, unreviewed roles, destination drift, and stale evidence keys.
- Preserved the fail-closed release boundary and left Apache-2.0 provisional pending the dependency compatibility audit.

## Task Commits

Each task was committed atomically using TDD:

1. **Task 1 RED: Add failing reviewed-attribution contract tests** - `b18251c` (test)
2. **Task 1 GREEN: Record reviewed attribution and credits** - `56637a0` (feat)
3. **Task 2 RED: Add failing destination-parity tests** - `62bc592` (test)
4. **Task 2 GREEN: Propagate reviewed package attribution** - `0a8a8ca` (feat)
5. **Overall verification fix: Retain explicit reviewed Author metadata** - `773933a` (fix)

## Files Created/Modified

- `docs/provenance/ATTRIBUTION.md` - Reviewed evidence-to-role mapping, snapshot identity, blockers, and destination contract.
- `CONTRIBUTORS.md` - Public reviewed contributor credit and evidence threshold.
- `NEWS.md` - Release-relevant provenance and authorship credit using the same evidence keys.
- `inst/CITATION` - Package and predecessor citations derived from package metadata where applicable.
- `tests/testthat/test-attribution-contract.R` - Direct parsers and fail-closed attribution contract tests.
- `DESCRIPTION` - Reviewed `Authors@R`, explicit `Author`, and attribution configuration fields without finalizing the package license.
- `README.md` - Upstream baseline, commit, CC0 basis, authorship boundary, release blocker, and provenance links.

## Decisions Made

- Assigned David Zenz `aut`, `cre`, and `cph`; assigned Maros Ivanic `aut` for the audited predecessor. No role was inferred from an unreviewed Git identity.
- Credited the public-domain/CC0 upstream baseline even though attribution is not legally required, because accurate provenance is part of the release contract.
- Kept `mivanicERS` unresolved as an alias instead of merging it into a person record without evidence.
- Kept the package name `tabloToR`; GEModelR remains the independently selected successor identity for a later authorized transition.
- Did not finalize Apache-2.0 or replace the standalone Maintainer placeholder because Plan 01-06 owns dependency compatibility and final metadata application.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added explicit direct parity markers**
- **Found during:** Task 2 GREEN (propagate reviewed package attribution)
- **Issue:** Direct destination parsing exposed capitalization and structured-name differences that could make equivalent credit appear inconsistent.
- **Fix:** Added explicit attribution people metadata, exact blocked-release wording, and a predecessor author note so each destination has deterministic markers.
- **Files modified:** `DESCRIPTION`, `README.md`, `inst/CITATION`
- **Verification:** All destination-parity and stale-key assertions pass.
- **Committed in:** `0a8a8ca`

**2. [Rule 3 - Blocking] Added explicit Author compatibility metadata**
- **Found during:** Overall `R CMD check .`
- **Issue:** The available R 4.3 direct-directory checker rejected the package as missing mandatory `Author` metadata despite valid `Authors@R`.
- **Fix:** Added an explicit `Author` field rendered from the reviewed role assignments and protected it with a test.
- **Files modified:** `DESCRIPTION`, `tests/testthat/test-attribution-contract.R`
- **Verification:** DESCRIPTION metadata validation passed and package checking advanced to compilation.
- **Committed in:** `773933a`

**3. [Rule 3 - Blocking] Repaired skipped GSD progress derivation**
- **Found during:** Post-task state update
- **Issue:** `state.update-progress` skipped the unscoped in-progress phase and left progress, velocity, and latest-activity text stale after recording Plan 01-05.
- **Fix:** Reconciled the derived STATE fields to the five summaries and per-plan metrics already present on disk.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE reports Plan 6 of 6, 5 completed plans, 83% progress, and 289 minutes total execution time.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking issues)
**Impact on plan:** Both fixes make attribution parity deterministic and compatible with the available checker; neither broadens the reviewed people or roles.

## Issues Encountered

- The patch helper became unavailable because its sandbox could not create a namespace. Repository-scoped noninteractive R edits were used and every resulting diff was inspected.
- `R CMD check .` advanced through package metadata, then the pre-existing Linuxbrew assembler failed to run against the host GLIBC while compiling `RcppExports.o`. This environment mismatch also affected earlier phase plans; attribution-specific tests and deterministic release/provenance checks passed.
- The checker also surfaced pre-existing source-check artifacts and a portable filename warning; they are outside this plan's attribution scope.

## Known Stubs

| File | Line | Stub | Resolution |
|------|------|------|------------|
| `DESCRIPTION` | 12 | Pre-existing standalone Maintainer placeholder | Plan 01-06 applies the approved David Zenz contact. |
| `DESCRIPTION` | 16 | Pre-existing License placeholder | Plan 01-06 completes the dependency compatibility audit before finalizing licensing. |

Both entries are recorded as open in `.planning/WINDOWS.md`; neither prevents this plan's attribution goal, but both continue to block shipping.

## Authentication Gates

None.

## TDD Gate Compliance

- Task 1 has a failing-test commit (`b18251c`) followed by its implementation commit (`56637a0`).
- Task 2 has a failing-test commit (`62bc592`) followed by its implementation commit (`0a8a8ca`).
- The compatibility correction is isolated in `773933a` and all 40 assertions pass afterward.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01-06 can consume one deterministic attribution contract and exact six-destination evidence-key parity.
- Final release qualification remains intentionally blocked until provenance coverage, dependency licensing, approved Maintainer metadata, and the unresolved Git alias are handled by their owning gates.


## Self-Check: PASSED

- All eight claimed implementation and summary files exist.
- All five task/TDD commit hashes exist in repository history.

---
*Phase: 01-provenance-and-release-boundary*
*Completed: 2026-08-25*
