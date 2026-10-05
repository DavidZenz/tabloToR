---
phase: 03-gemodelr-identity-migration
plan: 18
subsystem: migration
tags: [identity-migration, workflow-evidence, policy, R, testthat]

requires:
  - phase: 03-gemodelr-identity-migration
    provides: D-09 and CR-03 identity-audit context plus the reviewed predecessor fingerprint registry
provides:
  - Fail-closed exact-line workflow evidence policy and validator
  - Human-bound approval record for the exact 12-path policy scope
  - Executor-summary-state-verifier lifecycle handoff documentation and regression coverage
affects: [03-19 policy activation, 03-20 final qualification, identity migration audit]

actuals:
  tokens: 8176
  tasks: 2
  commits: 5

tech-stack:
  added: []
  patterns:
    - Exact UTF-8 trailing-LF line hashes instead of line-number or directory exclusions
    - Separate orchestrator and verifier ownership with explicit approved review metadata

key-files:
  created:
    - tools/check_workflow_identity_policy.R
    - inst/migration/workflow-evidence-policy.csv
    - inst/migration/workflow-evidence-policy-review.dcf
    - docs/migration/PHASE03-EVIDENCE-LIFECYCLE.md
    - tests/testthat/test-workflow-identity-policy.R
  modified:
    - inst/migration/workflow-evidence-policy-review.dcf
    - tests/testthat/test-workflow-identity-policy.R

key-decisions:
  - "Approve only the exact 12 enumerated workflow evidence paths and 19 exact line-hash rows."
  - "Bind approval to reviewer David Zenz at 2026-09-18T09:59:34Z and policy SHA-256 882f3f92a8afe84fdd50b4565ed189af5242afd8cfc2bfd72a22db4553f2ce1e."
  - "Keep policy activation, row expansion, source BUGFIX approval, release, and publication outside this plan."

patterns-established:
  - "Workflow evidence is accepted only when path, category, owner, line hash, and count bound all match."
  - "Policy review is recorded separately from later policy activation."

requirements-completed: [COMP-04, MIGR-01, MIGR-02]

coverage:
  - id: D1
    description: "Fail-closed exact-line workflow evidence validator covering lifecycle writes and hostile path/content cases."
    requirement: COMP-04
    verification:
      - kind: unit
        ref: "tests/testthat/test-workflow-identity-policy.R#workflow identity policy suite"
        status: pass
      - kind: other
        ref: "Rscript --vanilla tools/check_workflow_identity_policy.R --verify-approved"
        status: pass
    human_judgment: false
  - id: D2
    description: "Human-approved exact workflow-evidence policy review record."
    requirement: MIGR-01
    verification:
      - kind: other
        ref: "inst/migration/workflow-evidence-policy-review.dcf"
        status: pass
    human_judgment: true
    rationale: "The exact policy scope and reviewer identity require an explicit human decision."

duration: 35min
completed: 2026-09-18
status: complete
---

# Phase 03 Plan 18: Workflow Evidence Policy Summary

**Human-approved exact-line workflow evidence policy with fail-closed R validation and identity-migration lifecycle handoff**

## Performance

- **Duration:** 35 min
- **Started:** 2026-09-18T09:28:34Z
- **Completed:** 2026-09-18T10:03:38Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a validator and exact CSV policy for 12 enumerated workflow evidence paths, 19 exact UTF-8 trailing-LF line hashes, two allowed owners, and bounded counts.
- Added lifecycle documentation and tests covering summary/state/verifier handoffs, code-fence rejection, source-path rejection, symlink escape, arbitrary planning paths, novel identity lines, and over-counts.
- Bound the exact policy digest to David Zenz at the supplied UTC timestamp while leaving policy activation and the active five-category source auditor unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Prove narrow workflow line classification across a real evidence-write lifecycle** - `6fba2b3` (test), `e7358c8` (feat)
2. **Task 2: Review and approve only the exact workflow-evidence policy scope** - `f27815f` (docs)
3. **Rule 1 test correction for approved review metadata** - `297f0ce` (fix)

## Files Created/Modified

- `tools/check_workflow_identity_policy.R` - Validates the exact policy and checks repository lines fail closed.
- `inst/migration/workflow-evidence-policy.csv` - Enumerates the approved path, category, line hash, count, and owner rows.
- `inst/migration/workflow-evidence-policy-review.dcf` - Records the approved digest, reviewer, UTC, and unchanged scope.
- `docs/migration/PHASE03-EVIDENCE-LIFECYCLE.md` - Documents executor-summary-state-verifier handoff and activation boundaries.
- `tests/testthat/test-workflow-identity-policy.R` - Covers the real lifecycle and rejection cases.

## Decisions Made

The approved policy is limited to the exact digest `882f3f92a8afe84fdd50b4565ed189af5242afd8cfc2bfd72a22db4553f2ce1e`, its 12 enumerated paths, and its 19 exact rows. It does not activate the policy or authorize later scope expansion, source BUGFIX approval, release, or publication.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated stale approval-state test expectations**

- **Found during:** Task 2 post-approval verification
- **Issue:** The checked-in test still expected the review DCF to remain `proposed` with pending reviewer metadata after the explicitly approved review was bound.
- **Fix:** Updated the assertions to require `approved`, reviewer `David Zenz`, and the supplied review UTC.
- **Files modified:** `tests/testthat/test-workflow-identity-policy.R`
- **Verification:** Focused workflow-identity-policy suite passed; both policy CLI modes passed.
- **Committed in:** `297f0ce`

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)  
**Impact on plan:** The correction keeps tests aligned with the approved-but-not-activated lifecycle and does not broaden policy scope.

## Issues Encountered

- The repository patch helper was unavailable because the sandbox could not create its namespace; a narrow file edit was used for the approval record and summary.
- The pre-existing active auditor still reports `UNEXPECTED_OLD_IDENTITY_UNCLASSIFIED tools/check_serialization_bugfix.R`; Plan 03-18 did not modify that auditor or source, and the remaining classification belongs to later gap-closure work.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-19 may activate only the approved policy digest and exact rows after its separate activation controls.
- Plan 03-20 must still perform clean-HEAD qualification and final read-only sealing.
- No policy activation, row expansion, source BUGFIX approval, release, or publication was performed here.

---
*Phase: 03-gemodelr-identity-migration*
*Completed: 2026-09-18*

## Self-Check: PASSED

- All five plan files and the summary exist.
- Task commits `6fba2b3`, `e7358c8`, `f27815f`, and `297f0ce` exist in git history.
- Focused workflow-identity-policy tests and `--verify-approved` passed.
