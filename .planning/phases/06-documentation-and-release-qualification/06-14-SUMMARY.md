---
phase: 06-documentation-and-release-qualification
plan: 14
subsystem: testing
tags: [R, testthat, GitHub-Actions, Windows, provenance]
requires:
  - phase: 06
    provides: Portable provenance path regressions and release qualification evidence.
provides:
  - Two isolated provenance regression steps in the existing Windows native CI job.
  - Fresh-process POSIX results for both focused provenance test groups.
affects: [phase-06-release-qualification, native-ci, provenance]
actuals:
  tokens: 1700
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - Run platform-specific regressions in separate, success-guarded CI processes.
key-files:
  created:
    - .planning/phases/06-documentation-and-release-qualification/06-14-SUMMARY.md
  modified:
    - .github/workflows/native-ci.yaml
    - .planning/STATE.md
    - .planning/ROADMAP.md
key-decisions:
  - "Reuse the Windows release/current/serial native CI matrix entry and run each provenance group in a fresh R process."
  - "Treat local POSIX passes as test-code evidence only; require a hosted Windows trailing-root pass to close the platform gap."
patterns-established:
  - "Platform-specific path regressions use narrow CI steps guarded by successful runtime and dependency setup."
requirements-completed: [REL-01]
coverage:
  - id: D1
    description: Two provenance regressions are wired as separate steps in the existing Windows release/current/serial job.
    requirement: REL-01
    verification:
      - kind: integration
        ref: ".github/workflows/native-ci.yaml YAML structural assertions: exact tuple, setup guards, IDs, and separate test invocations"
        status: pass
      - kind: integration
        ref: "Hosted Windows native-core run: trailing-root step result"
        status: unknown
    human_judgment: true
    rationale: "The workflow has not run on hosted Windows; the trailing-root step must pass there before the platform gap can close."
  - id: D2
    description: Both focused provenance test groups pass locally in independent fresh R processes.
    requirement: REL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#provenance relative paths accept trailing roots"
        status: pass
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#provenance sources stay within selected root"
        status: pass
    human_judgment: false
duration: 12 min
completed: 2026-10-20
status: complete
---

# Phase 06 Plan 14: Windows Provenance Regression Summary

**The native CI workflow now runs both focused provenance regressions separately on the Windows release/current/serial tuple.**

## Performance

- **Duration:** 12 minutes
- **Started:** 2026-10-20T14:31:00Z
- **Completed:** 2026-10-20T14:43:00Z
- **Tasks:** 2
- **Files modified:** 4, including this summary and GSD state artifacts

## Accomplishments

- Added a dependency step ID and two isolated provenance regression steps to the existing Windows native CI job. Both use `always()` and require successful R setup and dependency installation, so they can run after unrelated installed-core test failures.
- Ran each test group locally in its own `Rscript --vanilla` process. Both passed on POSIX with no skips.
- Recorded hosted Windows as pending. Only a successful hosted trailing-root step closes the Windows evidence gap; a selected-root symlink skip does not.

## Verification

- Parsed `.github/workflows/native-ci.yaml` with the R `yaml` package and asserted the exact two step names/IDs, distinct run commands, `Rscript --vanilla -e` invocation, single matching `testthat::test_file()` group per step, exact Windows/release/current/serial tuple, and successful setup/dependency guards — passed.
- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", desc = "provenance relative paths accept trailing roots", reporter = "summary", stop_on_failure = TRUE)'` — passed in a fresh process (4 expectations).
- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", desc = "provenance sources stay within selected root", reporter = "summary", stop_on_failure = TRUE)'` — passed in a separate fresh process (19 expectations).
- The local host is POSIX. These results validate the current test code but do not establish Windows behavior. No hosted workflow was started.
- No full suite, `R CMD check`, R baseline, or full-scale benchmark was run, as directed.

## Task Commits

1. **Task 1: Add focused provenance tests to the existing Windows CI job** — `948a0ff` (`Add focused Windows provenance regressions`)
2. **Task 2: Run focused tests and record hosted evidence status** — summary and local verification recorded in this plan metadata commit.

## Files Created/Modified

- `.github/workflows/native-ci.yaml` — two separate, success-guarded focused test steps on the existing Windows matrix tuple.
- `.planning/phases/06-documentation-and-release-qualification/06-14-SUMMARY.md` — local results and hosted evidence status.
- `.planning/STATE.md` — execution position, metrics, and remaining gaps.
- `.planning/ROADMAP.md` — plan execution progress; Phase 06 remains in progress.

## Decisions Made

- Reused the existing Windows release/current/serial entry; no workflow, secret, artifact upload, or broader test matrix was added.
- Kept hosted Windows evidence explicitly pending. A selected-root skip caused by unavailable symlink support is not a passing trailing-root result.

## Deviations from Plan

None. The execution ran inline at the user's direction after the available agent interface could not represent the configured worktree isolation.

## Issues Encountered

- The workflow has not yet run on hosted Windows. The Windows evidence gap remains open until its trailing-root regression step succeeds.
- Other Phase 06 blockers remain: exact source-archive qualification, matched full-scale R/C++ benchmark evidence, the live `PROVENANCE_KEY_MISMATCH`, hosted predecessor serialization behavior, and the Phase 1 dependency compatibility and attribution identity decisions.

## User Setup Required

None.

## Next Phase Readiness

Phase 06 remains in progress. This plan adds an auditable Windows test path but provides no hosted result and does not resolve the other release and environment blockers listed above. Do not mark the phase complete until its remaining verification gaps are resolved.

## Self-Check: PASSED

- Both focused test groups pass in independent fresh R processes.
- YAML structure and step guards match the plan.
- The summary distinguishes local POSIX results from pending hosted Windows evidence and retains the other Phase 06 blockers.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-20*
