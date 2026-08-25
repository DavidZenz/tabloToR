---
phase: 01-provenance-and-release-boundary
plan: 04
subsystem: release-governance
tags: [r, testthat, name-availability, governance, github, release-boundary]

requires:
  - phase: 01-01
    provides: Fail-closed release-gate contracts and intentional blocked-state assertion
provides:
  - Signed six-source point-in-time GEModelR exact-name collision evidence
  - Human-approved maintainer, contact, security route, owner slug, canonical URL, and issue tracker
  - Private-development governance with separate not-authorized reservation, mutation, settings, and publication gates
affects: [01-05, 01-06, package-metadata, repository-reservation, release-qualification]

actuals:
  tokens: 14454
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - Fixed-source point-in-time evidence with raw-response hashes and exact ASCII case-folded matching
    - Human-approved marker records separated from external-action authorization
    - Derived GitHub URL parity enforced from approved owner slug and repository name

key-files:
  created:
    - tools/check_name_availability.R
    - tests/testthat/test-name-availability.R
    - docs/release/NAME-CHECK.md
    - GOVERNANCE.md
    - docs/release/REPOSITORY.md
  modified: []

key-decisions:
  - "Approve the initial GEModelR report as point-in-time exact-name collision evidence only, not trademark clearance or reservation."
  - "Use David Zenz / DavidZenz with zenz@wiiw.ac.at and mailto:zenz@wiiw.ac.at as the exact approved v1 identity values."
  - "Keep repository reservation, visibility or detachment, branch settings, and release or publication separately not-authorized."

patterns-established:
  - "Name evidence: all six required sources must be available, hashable, ordered, and free of case-insensitive exact collisions."
  - "Identity parity: governance and repository records share approved reviewer/date markers while URLs derive exactly from Owner-Slug and GEModelR."
  - "External boundary: identity approval never implies repository mutation or release authority."

requirements-completed: [PROV-03, PROV-04]

coverage:
  - id: D1
    description: "The initial GEModelR report records six available authoritative sources, UTC time, raw hashes, zero exact collisions, and an approved reviewer signature."
    requirement: PROV-03
    verification:
      - kind: integration
        ref: "tests/testthat/test-name-availability.R#clean source, collision, malformed, unavailable, and signed-report contracts"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_name_availability.R --verify-report docs/release/NAME-CHECK.md"
        status: pass
      - kind: manual_procedural
        ref: "David Zenz approval on 2026-08-25 of Initial-Name-Report: approved"
        status: pass
    human_judgment: true
    rationale: "The report is point-in-time evidence whose reviewer identity and scope limitation required explicit human approval."
  - id: D2
    description: "Governance and repository records carry the exact approved contact, security route, owner slug, canonical URL, issue tracker, reviewer, and review date."
    requirement: PROV-04
    verification:
      - kind: integration
        ref: "tests/testthat/test-name-availability.R#checked-in identity records match exact human-approved values"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_name_availability.R --verify-identity GOVERNANCE.md docs/release/REPOSITORY.md --expect approved"
        status: pass
      - kind: manual_procedural
        ref: "Maintainer confirmation of DavidZenz profile/display name and supplied durable contact"
        status: pass
    human_judgment: true
    rationale: "Personal public identity and contact values cannot be inferred and were explicitly supplied and approved by the maintainer."
  - id: D3
    description: "Reservation, visibility or detachment, branch-setting, and release or publication actions remain separately not-authorized and release readiness remains blocked."
    requirement: PROV-04
    verification:
      - kind: integration
        ref: "tests/testthat/test-name-availability.R#exact not-authorized marker contract"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false

duration: 53 min
completed: 2026-08-25
status: complete
---

# Phase 1 Plan 4: Name, Governance, and Repository Identity Summary

**Signed six-source GEModelR collision evidence with approved maintainer/repository identity and fail-closed external-action boundaries.**

## Performance

- **Duration:** 53 min
- **Started:** 2026-08-25T10:56:47Z
- **Completed:** 2026-08-25T11:49:23Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Implemented deterministic offline fixtures and a live six-source checker for CRAN current/archive, Bioconductor current/history, R-universe, and GitHub.
- Signed the initial no-exact-collision report as point-in-time evidence while explicitly excluding trademark clearance, reservation, and future availability claims.
- Recorded the exact human-approved maintainer, contact, security, GitHub owner, canonical repository, issue tracker, reviewer, and review date values.
- Preserved private development and separate fresh blocking-human gates for repository reservation, visibility or detachment, branch settings, and release or publication.

## Task Commits

1. **Task 01-04-01 RED: name availability contracts** - `9344b86` (test)
2. **Task 01-04-01 GREEN: authoritative name evidence** - `b268985` (feat)
3. **Task 01-04-02: governance and repository boundaries** - `2248173` (feat)
4. **Task 01-04-03: approved identity evidence** - `3dfb751` (feat)

## Files Created/Modified

- `tools/check_name_availability.R` - Base-R exact-name checker, live source retrieval, report generation, and identity/report verification.
- `tests/testthat/test-name-availability.R` - Deterministic name-source, report, identity, URL-parity, and external-authorization contracts.
- `docs/release/NAME-CHECK.md` - Signed initial six-source point-in-time collision report.
- `GOVERNANCE.md` - Approved sole-maintainer authority, contact/security responsibility, contribution policy, and succession process.
- `docs/release/REPOSITORY.md` - Approved canonical identity plus private-development, migration/recovery, and separate external-action gates.

## Decisions Made

- Approved `David Zenz` as maintainer, release authority, and reviewer; `zenz@wiiw.ac.at` as durable contact; and `mailto:zenz@wiiw.ac.at` as security route.
- Approved owner slug `DavidZenz`, canonical URL `https://github.com/DavidZenz/GEModelR`, and issue tracker `https://github.com/DavidZenz/GEModelR/issues`.
- Treated `Initial-Name-Report: approved` as a signature over the existing 2026-08-25 point-in-time evidence, not a fresh check, trademark determination, or reservation.
- Performed no external action and retained all four external authorization markers as `not-authorized`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Transitioned the checked-in identity test from checkpoint state to approved state**
- **Found during:** Task 01-04-03 focused verification
- **Issue:** The focused suite still required the canonical checked-in records to be `unapproved`, so it failed after applying the approved values.
- **Fix:** Updated only the canonical-state assertion to require approved mode and every exact human-approved marker; retained reusable unapproved fixture tests unchanged.
- **Files modified:** `tests/testthat/test-name-availability.R`
- **Verification:** All 46 focused assertions and both approved report/identity CLI verifiers pass.
- **Committed in:** `3dfb751`

**2. [Rule 3 - Blocking] Repaired skipped GSD progress derivation**
- **Found during:** Plan close-out
- **Issue:** `state.update-progress` skipped the in-progress phase as unscoped, leaving prose progress, velocity, activity, and the prior name concern stale despite `completed_plans: 4`.
- **Fix:** Updated only the derived STATE fields to match the four on-disk summaries and the completed initial name evidence.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE reports Plan 5 of 6, 67% progress, four completed plans, 269 minutes total, and the fresh reservation/release check concern.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking issue).
**Impact on plan:** The test suite now represents the completed checkpoint state and directly protects every approved value without broadening external authority.

## Issues Encountered

- The sandboxed patch helper could not create a Linux namespace. Repository-scoped non-interactive mechanical edits were used, followed by exact diff inspection, focused tests, and `git diff --check`.

## Known Stubs

None. `awaiting-human-approval` remains only in report-generation defaults and isolated unapproved fixtures that test the fail-closed checkpoint state; no canonical identity artifact contains a pending value.

## Authentication Gates

None.

## User Setup Required

None - no repository reservation, visibility/detachment change, branch-setting change, release, publication, or other external mutation was performed.

## Next Phase Readiness

- Plan 01-05 can consume the approved maintainer identity while deriving attribution from reviewed provenance evidence.
- Plan 01-06 can integrate the signed name/governance/repository records into the complete release checker.
- Reservation and release each still require a fresh correctly typed six-source name check plus explicit blocking-human authorization.

## TDD Gate Compliance

- RED commit `9344b86` established failing exact-name source and report contracts.
- GREEN commit `b268985` implemented the checker and point-in-time evidence; Task 01-04-03 later signed that fixed report without rerunning or mutating an external repository.


## Self-Check: PASSED

- All five Plan 01-04 artifacts exist.
- Task commits `9344b86`, `b268985`, `2248173`, and `3dfb751` are present.
- Required status, requirement, deviation, and known-stub metadata is present.

---
*Phase: 01-provenance-and-release-boundary*
*Completed: 2026-08-25*
