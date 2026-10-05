---
phase: 01-provenance-and-release-boundary
plan: 02
subsystem: release-governance
tags: [r, testthat, provenance, public-domain, cc0, clean-room]

requires:
  - phase: 01-01
    provides: Fail-closed rights records, release checker, and synthetic evidence fixtures
provides:
  - Hash-bound public-domain/CC0 evidence for the audited upstream baseline
  - Strict behavior-only clean-room replacement protocol and component schema
  - Fail-closed provenance coverage boundary for unrelated third-party components
affects: [01-03, 01-04, 01-05, 01-06, release-qualification]

actuals:
  tokens: 19663
  tasks: 3
  commits: 7

tech-stack:
  added: []
  patterns:
    - Hash-bound public response evidence with exact offline metadata parity
    - Scoped rights clearance separated from repository release readiness
    - Three-role clean-room evidence with exact provenance-key coverage

key-files:
  created:
    - docs/provenance/UPSTREAM-REQUEST.md
    - docs/provenance/UPSTREAM-RESPONSE.md
    - docs/provenance/CLEANROOM.md
    - specs/cleanroom/README.md
  modified:
    - docs/provenance/RIGHTS.md
    - docs/release/RELEASE-GATES.md
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R

key-decisions:
  - "Accept the upstream public-domain/CC0 response as sufficient modification and redistribution evidence for upstream-authored inherited source at the audited commit."
  - "Supersede the redundant request-posting checkpoint; retain the draft only as historical do-not-post evidence."
  - "Treat GEModelR as an independently selected successor identity while deferring authoritative name availability and governance to Plan 01-04."
  - "Keep release readiness blocked until Plan 01-03 proves a rights basis for every distributable component."

patterns-established:
  - "Scoped clearance: Rights-Status may be cleared for a named baseline while provenance coverage still blocks release readiness."
  - "Evidence integrity: the checker verifies the exact response statement, source metadata, supporting references, and whole-document hash."
  - "Third-party fail-closed rule: public-domain evidence never implicitly covers unrelated components."

requirements-completed: [PROV-01]

coverage:
  - id: D1
    description: "The accepted public-domain/CC0 response is hash-bound to the audited upstream repository and commit with exact source metadata and scope."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#the public-domain response is accepted with limited scope"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false
  - id: D2
    description: "The clean-room fallback enforces distinct roles, source-access eligibility, attestations, behavior tests, and exact provenance-key coverage."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#clean-room evidence tests"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_release_gates.R --self-test"
        status: pass
    human_judgment: false
  - id: D3
    description: "Repository release readiness remains blocked on incomplete provenance coverage without requiring a second upstream request or claiming third-party rights."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#public-domain evidence remains blocked until provenance is complete"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false

duration: 2h 56m
completed: 2026-08-25
status: complete
---

# Phase 1 Plan 2: Rights Evidence and Clean-Room Boundary Summary

**Hash-bound public-domain/CC0 clearance for the audited upstream baseline, with strict clean-room evidence and third-party provenance coverage still fail-closed.**

## Performance

- **Duration:** 2h 56m
- **Started:** 2026-08-25T07:23:57Z
- **Completed:** 2026-08-25T10:19:56Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Recorded the upstream author's exact public-domain/CC0 statement in a dedicated hash-bound response artifact and accepted it for upstream-authored inherited source at commit 7e063c65a19713857ed13023f8b77dad45b15c90.
- Defined and executable-tested a strict clean-room replacement path with behavior-only specifications, source-unexposed implementers, independent review, and exact provenance-key coverage.
- Replaced the redundant second-post gate with PROVENANCE_COVERAGE_INCOMPLETE, preserving a release block until all third-party and inherited components have reviewed provenance evidence.
- Framed GEModelR as an independently selected successor identity whose availability and governance remain a separate Plan 01-04 gate.

## Task Commits

1. **Task 01-02-01 RED: upstream request contract** - c31c64b (test)
2. **Task 01-02-01 GREEN: hash-bound blocked request evidence** - d35ed90 (feat)
3. **Task 01-02-02 RED: clean-room evidence contract** - 0049d7e (test)
4. **Task 01-02-02 GREEN: enforce independent clean-room evidence** - ca7e36b (feat)
5. **Task 01-02-03 evidence capture: public response metadata** - fea721d (docs)
6. **Task 01-02-03 adaptation: accept scoped public-domain evidence** - e3b7267 (feat)

## Files Created/Modified

- docs/provenance/UPSTREAM-REQUEST.md - Historical D-01 draft marked superseded and do-not-post.
- docs/provenance/UPSTREAM-RESPONSE.md - Exact public response, source metadata, scope, and supporting authoritative interpretation.
- docs/provenance/CLEANROOM.md - Strict role separation, input restrictions, attestations, and acceptance protocol.
- specs/cleanroom/README.md - Behavior-only specification schema and forbidden input boundary.
- docs/provenance/RIGHTS.md - Scoped public-domain/CC0 basis, exclusions, reviewer decision, and successor-name boundary.
- docs/release/RELEASE-GATES.md - Public-domain evidence predicates and provenance coverage blocker.
- tools/check_release_gates.R - Offline public-domain evidence evaluator, synthetic fixtures, and exact blocked assertion.
- tests/testthat/test-release-gates.R - Positive and negative public-domain, request, clean-room, hash, scope, and coverage tests.

## Decisions Made

- The maintainer accepted the linked public-domain/CC0 response as sufficient rights evidence for the audited upstream-authored baseline.
- No additional upstream request will be posted; the prepared request remains historical evidence only.
- Unrelated third-party components are explicitly excluded from this decision and remain subject to Plan 01-03 inventory coverage.
- GEModelR naming does not depend on upstream copyright permission; Plan 01-04 retains the authoritative name and governance checks.

## Deviations from Plan

### Maintainer-Approved Adaptation

**1. Superseded the Task 3 posting checkpoint with the authoritative public response**
- **Found during:** Task 01-02-03 continuation
- **Original plan:** Required the maintainer to post the exact broader D-01 request before completing the plan.
- **Decision:** The maintainer accepted the existing public-domain/CC0 response as sufficient and explicitly directed that no redundant request be posted.
- **Adaptation:** Added hash-bound response evidence, marked the draft do-not-post, and removed second-posting as a release predicate.
- **Files modified:** rights/request/response records, release policy, checker, and focused tests.
- **Verification:** 181 focused assertions, checker self-test, and canonical blocked assertion pass.
- **Committed in:** e3b7267

### Auto-Fixed Issues

**2. [Rule 2 - Missing Critical] Added a component-coverage blocker for scope-limited evidence**
- **Found during:** Task 01-02-03 adaptation
- **Issue:** Treating scoped upstream evidence as repository-wide clearance could claim rights over unrelated third-party components.
- **Fix:** Added exact covered/excluded component markers and required complete provenance coverage before release readiness.
- **Files modified:** rights record, release policy, checker, and focused tests.
- **Verification:** Scope-corruption fixtures return RIGHTS_SCOPE_INCOMPLETE; pending coverage returns PROVENANCE_COVERAGE_INCOMPLETE.
- **Committed in:** e3b7267

---

**Total deviations:** 2 (1 maintainer-approved plan adaptation, 1 missing-critical auto-fix)
**Impact on plan:** The authoritative response now satisfies the upstream rights-evidence objective while the broader release boundary is stricter for unknown or third-party provenance.

## Issues Encountered

- The dedicated patch editor could not create its sandbox namespace. The repository-safe patch fallback was used; every generated .orig/.rej file was inspected, the rejected assertion hunk was applied explicitly, and all patch artifacts were removed before commit.
- R CMD check . reached the pre-existing Linuxbrew assembler/GLIBC incompatibility documented in Plan 01-01 and stopped during native compilation. Focused evidence tests and all checker commands passed; no Plan 01-02 evidence file caused the toolchain failure.

## Known Stubs

None. pending-plan-01-03 and pending-plan-01-04 are intentional fail-closed workflow states, not implementation placeholders.

## User Setup Required

None - no external communication, package license change, or publication action was performed.

## Next Phase Readiness

- Plan 01-03 can replace the temporary coverage-status blocker with the reviewed function/file provenance inventory while preserving exact public-domain evidence scope.
- Plan 01-04 remains responsible for authoritative GEModelR name availability, governance, maintainer identity, and repository checks.
- Public release remains blocked until provenance coverage and all later Phase 1 gates pass.

## Self-Check: PASSED
