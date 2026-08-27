---
phase: 01-provenance-and-release-boundary
plan: 11
subsystem: release-governance
tags: [verification-overrides, provenance, release-gates, r-cmd-check]

requires:
  - phase: 01-08
    provides: approved exhaustive name evidence
  - phase: 01-09
    provides: accepted native provenance hash migration
  - phase: 01-10
    provides: enforceable clean-room evidence
provides:
  - explicit maintainer outcomes for three historical deviations
  - exact one-to-one canonical verification overrides
  - successful unchanged final package integrity verification
affects: [phase-01-verification, release-qualification, toolchain-portability]

actuals:
  tokens: 6628
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - complete explicit decision tuples before override creation
    - exact must-have text for fuzzy-match-safe verification overrides
    - failed package integrity gates remain blocking

key-files:
  created:
    - .planning/phases/01-provenance-and-release-boundary/01-11-SUMMARY.md
  modified:
    - .planning/phases/01-provenance-and-release-boundary/01-OVERRIDE-DECISIONS.md
    - .planning/phases/01-provenance-and-release-boundary/01-VERIFICATION.md

key-decisions:
  - "David Zenz accepted the superseded Plan 01-01 blocked-rights marker deviation."
  - "David Zenz accepted the superseded Plan 01-02 request-posting deviation."
  - "David Zenz accepted the historical D-03 sequential-execution deviation."
  - "The repaired host toolchain satisfies the unchanged package-check gate; its 5 warnings and 4 notes remain future package-quality work rather than release clearance."

patterns-established:
  - "Override scope: one exact target, one specific reason, one supplied identity, and one UTC timestamp per accepted deviation."
  - "Release blockers and package-check failures cannot be converted into override success."

requirements-completed: [PROV-01, PROV-02]

coverage:
  - id: D1
    description: "All three historical deviations have explicit accepted outcomes recorded for David Zenz."
    requirement: PROV-01
    verification:
      - kind: manual_procedural
        ref: "rights=accept; request=accept; d03=accept; accepted_by=David Zenz"
        status: pass
      - kind: integration
        ref: "01-11 decision tuple and override-count assertion"
        status: pass
    human_judgment: true
    rationale: "The three historical deviations required an explicit blocking-human maintainer decision."
  - id: D2
    description: "Exactly three canonical overrides map to the accepted historical deviations without touching implementation findings or release blockers."
    requirement: PROV-02
    verification:
      - kind: integration
        ref: "01-11 decision tuple and override-count assertion"
        status: pass
      - kind: integration
        ref: "tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false
  - id: D3
    description: "The final package integrity command exits zero without suppressing environment failures."
    verification:
      - kind: integration
        ref: "rtk R CMD check ."
        status: pass
    human_judgment: false

duration: 2h 55m including checkpoint and environment repair
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 11: Historical Override Decisions Summary

**Three explicit David Zenz decisions map one-to-one to exact historical verification overrides, and the repaired host toolchain now passes the unchanged package integrity gate.**

## Performance

- **Duration:** 2h 55m including the blocking-human checkpoint and external environment repair
- **Started:** 2026-08-27T11:07:02Z
- **Completed:** 2026-08-27T14:02:00Z
- **Tasks complete:** 2 of 2
- **Files modified:** 3

## Accomplishments

- Recorded `rights=accept`, `request=accept`, and `d03=accept` exactly with `Accepted-By: David Zenz` and one ISO UTC timestamp.
- Added exactly three canonical overrides using the exact target must-have text, specific rationale, supplied identity, and response timestamp.
- Preserved `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED` as the exact canonical release blockers.
- Passed the exact unchanged final command `rtk R CMD check .`, including native compilation/install, tests, and PDF manual generation.

## Task Commits

1. **Task 1: Present exact pending override record** - `9efdf9d`
2. **Task 2 decision artifacts: Record accepted historical overrides** - `af5ddd3`

Task 2 is complete because its decision/override assertion and required unchanged `rtk R CMD check .` acceptance gate both exited zero.

## Files Created/Modified

- `.planning/phases/01-provenance-and-release-boundary/01-OVERRIDE-DECISIONS.md` - Complete three-choice decision tuple with identity and UTC time.
- `.planning/phases/01-provenance-and-release-boundary/01-VERIFICATION.md` - Three exact accepted historical-deviation overrides; status and score remain unchanged pending re-verification.
- `.planning/phases/01-provenance-and-release-boundary/01-11-SUMMARY.md` - Complete execution record and final verification evidence.

## Decisions Made

- Accepted the superseded Plan 01-01 blocked-rights marker deviation because reviewed scoped public-domain/CC0 evidence replaced the initial marker while separate blockers remain fail-closed.
- Accepted the superseded Plan 01-02 posting deviation because the existing reviewed response satisfies the rights intent and the retained draft is explicitly do-not-post.
- Accepted the immutable D-03 sequential chronology because both evidence streams completed and Plans 01-07 through 01-10 revalidated their integrated links.
- Did not infer any release, repository, request-posting, publication, or additional approval.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reconciled halted-plan progress metadata**

- **Found during:** Halted summary state update
- **Issue:** The roadmap updater recognized `status: halted` but still marked Plan 01-11 executed and raised completed plans to 11.
- **Fix:** Restored STATE and ROADMAP to 10/11 while the gate was blocked, then advanced both to 11/11 only after the unchanged check passed.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Verification:** STATE and ROADMAP report 11/11 after the final package command exited zero; neither canonical release blocker was removed.

**Total deviations:** 1 auto-fixed blocking metadata issue. No implementation, override, or release-boundary scope changed.

## Verification

- Decision tuple and override-count assertion: **pass**; 3 accepted choices and 3 overrides.
- API coverage pre-gate: **pass**; 19 capabilities, 11 integrated, 8 opted out.
- Provenance tests: **98 passed**, 0 failed, warned, or skipped.
- Attribution tests: **43 passed**, 0 failed, warned, or skipped.
- Name-availability tests: **85 passed**, 0 failed, warned, or skipped.
- Release-gate tests: **466 passed**, 0 failed, warned, or skipped.
- Inventory check: **reviewed**, 250 rows / 250 expected keys.
- Signed name report: **approved**.
- Release self-test: **pass**.
- Canonical blocked assertion: **pass** with exactly `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED`.
- `git diff --check`: **pass**.
- `rtk R CMD check .`: **pass (exit 0)**. Native compilation/install, package tests, compiled-code checks, and the PDF manual passed. R reported 5 WARNINGs and 4 NOTEs for pre-existing source-package hygiene, portable-name, check-directory, documentation, license/LazyData, and installed-size concerns; these remain later package-quality work and do not imply release readiness.

## Known Stubs

No new stubs were introduced. The unchanged verification body references the pre-existing canonical DESCRIPTION/license-decision placeholders already tracked as open release blockers in `.planning/WINDOWS.md`.

## Issues Encountered

- The direct patch helper could not create an unprivileged namespace; exact repository-scoped rewrites were applied through RTK and verified by Git diff plus plan assertions.
- A combined nested-RTK verification wrapper hit the same namespace restriction before running any checker; every checker was then run individually through RTK.
- The generated `..Rcheck` directory was moved intact to `/tmp/tabloToR-01-11-Rcheck-20260827T120039Z`; the pre-existing `tabloToR.Rcheck` directory was untouched.
- The first final package check failed because R selected Linuxbrew binutils that require newer GLIBC symbols, and a later attempt lacked `pdflatex`. Outside-repository environment repair exposed `/usr/bin/as` and the existing TinyTeX 2026 installation; the exact command then passed unchanged.

## Authentication Gates

None.

## User Setup Required

None. The host build environment was repaired outside the repository; no additional approval or repository configuration is required for this plan.

## Next Phase Readiness

- Historical override decisions are fully recorded and the package integrity gate passes; Plan 01-11 and Phase 01 gap execution are complete.
- Public release remains intentionally blocked by the dependency compatibility audit and unresolved attribution identity regardless of the package-check environment.

---
*Phase: 01-provenance-and-release-boundary*
*Completed: 2026-08-27*

## Self-Check: PASSED

All three claimed files exist, both Plan 01-11 task commits resolve in Git history, the decision/override assertion passes, and the exact package command exits zero.
