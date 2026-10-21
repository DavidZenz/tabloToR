---
phase: 06-documentation-and-release-qualification
plan: 19
subsystem: release-qualification
tags: [GitHub Actions, Windows, provenance, workflow_dispatch]
requires:
  - phase: 06
    provides: Focused Windows provenance regression steps and hosted archive qualification workflow.
provides:
  - A manually dispatchable native CI workflow preserving its existing triggers, matrix, and focused Windows regression steps.
  - An explicit rejected-dispatch record with Windows qualification blocked and no hosted evidence claimed.
affects: [CI-02, Windows provenance qualification, native-ci]
actuals:
  tokens: 4493
  tasks: 3
  commits: 3
tech-stack:
  added: []
  patterns:
    - Keep hosted qualification evidence bound to an explicitly authorized revision and record rejected dispatches as not started.
key-files:
  created:
    - .planning/phases/06-documentation-and-release-qualification/06-19-SUMMARY.md
  modified:
    - .github/workflows/native-ci.yaml
    - .planning/STATE.md
    - .planning/ROADMAP.md
key-decisions:
  - "Honor the existing local-only direction as rejection of a hosted Windows workflow dispatch."
  - "Keep Windows qualification blocked until both focused tests pass on an explicitly authorized hosted Windows tuple and SHA."
requirements-completed: []
coverage:
  - id: D1
    description: The native CI workflow exposes manual dispatch while preserving existing triggers and the focused Windows provenance steps.
    verification:
      - kind: integration
        ref: "R structural assertions for workflow_dispatch, existing triggers, scanner/source-install steps, and the Windows release/current/serial guards"
        status: pass
      - kind: other
        ref: "git diff --check -- .github/workflows/native-ci.yaml"
        status: pass
    human_judgment: false
  - id: D2
    description: Windows provenance qualification is bound to a hosted run on the authorized source revision.
    verification: []
    human_judgment: true
    rationale: "Dispatch authorization was rejected under the local-only direction, so the hosted Windows tests did not run."
duration: 9min
completed: 2026-10-21
status: complete
---

# Phase 06 Plan 19: Windows Provenance Dispatch Summary

**The native workflow now supports manual dispatch, while the rejected hosted run remains explicitly blocked with no Windows result claimed.**

## Performance

- **Duration:** 9 minutes
- **Started:** 2026-10-21T14:56:00Z (approximate)
- **Completed:** 2026-10-21T15:04:33Z
- **Tasks:** 3
- **Files modified:** 4, including this summary and planning state files

## Accomplishments

- Added only the `workflow_dispatch` trigger to the existing native CI workflow. The `push`, `pull_request`, and scheduled triggers, Matrix source-install steps, matrix entries, scanner steps, and focused Windows provenance test conditions remain intact.
- Verified the two provenance steps remain scoped to Windows / R release / Matrix current / serial and that workflow dispatch is present.
- Recorded rejection of a hosted run under the maintainer's existing local-only direction. Both Windows test statuses remain not run, and Windows qualification remains blocked.

## Verification

- The plan's R structural assertions passed for manual dispatch, preserved push and pull-request triggers, source-install and scanner steps, both focused test steps, and the Windows/release/current/serial guards.
- `git diff --check -- .github/workflows/native-ci.yaml` passed.
- No GitHub Actions dispatch, remote push, GitHub authentication check, Windows test, or hosted result inspection was performed. The prior local-only instruction explicitly rejects the remote action.

## Dispatch Decision and No-Run Record

The workflow revision is commit `1b57fb215a886466f01aba099fafdda01d05f022` on local branch `master`. Dispatch authorization was rejected to honor the maintainer's local-only direction, as recorded in Plan 06-18. The revision was not published, and no hosted run was authorized.

```text
target_branch=master
workflow_revision_sha=1b57fb215a886466f01aba099fafdda01d05f022
decision_checkpoint_head_sha=1b57fb215a886466f01aba099fafdda01d05f022
dispatch_authorization=rejected
authorized_head_sha=not_available
authorization_blocker=The maintainer's local-only instruction rejects publishing this revision and dispatching GitHub Actions; the Windows workflow remains local.
hosted_status=not_started
run_id=not_run
head_sha=not_available
windows_tuple=not_run
matrix_version=not_available
trailing_root_status=not_run
selected_root_status=not_run
windows_qualification_status=blocked
```

The precise blocker is the explicit local-only direction: the revision remains on local `master` and is not authorized for publication or hosted execution. No POSIX result was substituted for Windows evidence. CI-02 and the Windows provenance runtime gap remain open.

## Task Commits

1. **Task 1: Expose the existing native workflow to manual dispatch** — `1b57fb2` (`feat(06-19): add manual native workflow trigger`)
2. **Tasks 2–3: Record rejected authorization and the no-dispatch outcome** — `f1c653c` (`docs(06-19): record rejected Windows dispatch`)

**Plan metadata:** recorded in the final STATE/ROADMAP metadata commit.

## Files Created/Modified

- `.github/workflows/native-ci.yaml` — adds `workflow_dispatch` without changing existing jobs or triggers.
- `.planning/phases/06-documentation-and-release-qualification/06-19-SUMMARY.md` — records the exact workflow revision, rejected authorization, and required no-run fields.
- `.planning/STATE.md` — execution position, metric, decision, and Windows blocker.
- `.planning/ROADMAP.md` — plan progress for Phase 06.

## Decisions Made

- Honored the existing local-only direction as a rejection of one hosted Windows dispatch.
- Kept qualification blocked because no hosted result exists for the exact local workflow revision.

## Deviations from Plan

None. The plan explicitly permits rejected authorization and requires the no-dispatch outcome to be recorded without starting the hosted workflow.

## Issues Encountered

- Windows filesystem behavior remains unobserved. Both named tests are wired but were not run on a Windows host.

## User Setup Required

None. No external service configuration or hosted workflow action was performed.

## Next Phase Readiness

The local manual trigger is ready for a future explicitly authorized dispatch. Phase 06 remains incomplete: Windows behavior is unverified, and the existing archive, serialization, provenance, and benchmark blockers remain open.

## Self-Check: PASSED

- The native workflow trigger and focused Windows guards passed the plan's structural assertions.
- The dispatch authorization and every required no-run field are present exactly once.
- Windows qualification is recorded as blocked; no hosted pass is claimed.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-21*
