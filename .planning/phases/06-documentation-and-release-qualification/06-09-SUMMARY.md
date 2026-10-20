---
phase: 06-documentation-and-release-qualification
plan: 09
subsystem: release-qualification
tags: [R, testthat, release-gates, symlink]
requires:
  - phase: 06-08
    provides: Integrated release evidence and canonical repository-root checks
provides:
  - Root-bound reads for both integrated license decision records
  - Regression coverage for escaping decision-record symlinks
  - A complete blocked-evidence fixture that isolates a missing release decision
affects: [release-qualification, license-evidence]
actuals:
  tokens: 1073
  tasks: 1
  commits: 3
tech-stack:
  added: []
  patterns: [canonical root-bound evidence reads]
key-files:
  created: []
  modified:
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
key-decisions:
  - "Resolve both fixed license decision paths through the existing canonical evidence resolver before reading."
  - "Keep both intentional release blockers and their lifecycle meanings unchanged."
patterns-established:
  - "Fixed evidence paths are canonicalized under the selected root and required to be nonempty regular files before reading."
requirements-completed: [REL-01]
coverage:
  - id: D1
    description: Both integrated license decision readers reject escaping symlinks and fail license parsing.
    requirement: REL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#release gate rejects license decision targets outside root"
        status: pass
    human_judgment: false
  - id: D2
    description: The blocked assertion rejects a complete evidence tree missing only the release decision and accepts the intact blocked fixture.
    requirement: REL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#assert-blocked validates integrated evidence"
        status: pass
    human_judgment: false
duration: 2min
completed: 2026-10-20
status: complete
---

# Phase 06 Plan 09: License Evidence Boundary Summary

**Both integrated license decision records are read only after canonical in-root resolution, with regressions for escaping symlinks and an isolated missing-record assertion.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-10-20T07:42:08Z
- **Completed:** 2026-10-20T07:44:08Z
- **Tasks:** 1
- **Files modified:** 2 task files

## Accomplishments

- Both release and provenance decision readers now resolve their fixed relative paths through `release_gate_resolve_evidence_path()` before reading. Escaping symlinks map to each reader's existing missing-record reason and mark license parsing as failed.
- The escaping-symlink regression covers both decision records. Its RED run failed all four new reason-code and parse-status assertions against the prior raw fixed-path reads.
- The blocked-state regression now starts with complete integrated evidence, removes only the release decision, and verifies the specific missing-record reason, failed license parsing, and CLI status 1. The intact blocked fixture still has exactly the two intentional blockers, passing integrated parse statuses, and CLI status 0.

## Task Commits

1. **Task 1 RED:** `3148fda` — cover escaping license evidence symlinks and isolate blocked evidence
2. **Task 1 GREEN:** `e4f9b21` — bind license decision records to the selected evidence root

Plan metadata is included in the final close-out commit.

## Files Created/Modified

- `tools/check_release_gates.R` — resolve each integrated license decision record under the selected evidence root before reading.
- `tests/testthat/test-release-gates.R` — verify both escaping-symlink failures and the complete/missing-record blocked-state cases.

## Decisions Made

- Reuse the existing canonical resolver and preserve both decision readers' stable missing-record codes.
- Preserve `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED`; this plan changes no lifecycle policy.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The corrected `assert-blocked` fixture passed without a production-code change: it now reaches the integrated license parser and proves the existing CLI returns status 1 for a missing release record. The original malformed fixture did not isolate that boundary.

## Verification

- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", desc = "release gate rejects license decision targets outside root", reporter = "summary")'` — passed after implementation. Before implementation, the four new symlink reason-code and parse-status assertions failed as expected.
- `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", desc = "assert-blocked validates integrated evidence", reporter = "summary")'` — passed, including exact blocker IDs, all parse statuses, and CLI statuses 0 and 1.
- No baseline, full test suite, archive qualification, or benchmark was run, as scoped by the plan.

## Next Phase Readiness

The two decision-record paths are now confined to the selected evidence root. Release readiness remains blocked by the two intentionally preserved blockers; this focused plan does not complete the broader Phase 06 verification.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-20*

## Self-Check: PASSED

- The summary path exists.
- Both task commits are present in repository history.
- Both plan-specified focused regression groups pass.
