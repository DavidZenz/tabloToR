---
phase: 06-documentation-and-release-qualification
plan: 18
subsystem: release-qualification
tags: [GitHub Actions, R CMD check, Matrix, archive evidence, CI-02]
requires:
  - phase: 06-16
    provides: Installed serialization prerequisite status
  - phase: 06-17
    provides: Exact archive qualification boundary
provides:
  - A hosted archive workflow that records Matrix and commit identity, hashes and scans the exact archive, captures check/test logs, and uploads only scanned evidence
  - A blocking authorization checkpoint before hosted workflow dispatch
affects: [CI-02, release qualification]
actuals:
  tokens: 7486
  tasks: 1
  commits: 2
tech-stack:
  added: []
  patterns:
    - Parse dependency floors from DESCRIPTION and fail closed before archive build
    - Upload hosted qualification logs only after the public-content scan succeeds
key-files:
  created:
    - .planning/phases/06-documentation-and-release-qualification/06-18-SUMMARY.md
    - .planning/phases/06-documentation-and-release-qualification/06-USER-SETUP.md
  modified:
    - .github/workflows/release-qualification.yaml
    - .planning/STATE.md
key-decisions:
  - "Do not alter URL fields from a historical 404 without a retained authoritative check log proving the declared target is wrong."
  - "Do not push or dispatch without explicit maintainer authorization for the exact branch head."
patterns-established:
  - "Bind archive check evidence to the source SHA, resolved Matrix version, exact archive digest, and passing evidence scan."
requirements-completed: [CI-02]
coverage:
  - id: D1
    description: "The workflow records source and archive identity, checks the declared Matrix floor, and gates artifact upload on the evidence scan."
    requirement: CI-02
    verification:
      - kind: other
        ref: "Workflow ordering/metadata assertions, YAML parse, and bash -n on all 11 shell blocks"
        status: pass
      - kind: other
        ref: "R package-version comparison confirms 1.6.3 is below and 1.6-5 meets the DESCRIPTION floor"
        status: pass
    human_judgment: false
  - id: D2
    description: "The cause of the historical canonical URL 404s is established and current URL behavior is verified."
    verification: []
    human_judgment: true
    rationale: "The repository-owned historical raw URL check log is unavailable and no hosted current URL check ran."
duration: 13min
completed: 2026-10-21
status: halted
---

# Phase 06 Plan 18: Hosted Archive Qualification Workflow Summary

**The workflow now records Matrix and archive identity, preserves check/test logs, and uploads only scanned evidence; hosted qualification awaits authorization.**

## Task 1: Bind the hosted archive check to supported Matrix and retain scanned evidence

- Added a hosted preflight that reads the Matrix minimum from `DESCRIPTION`, records the resolved version and source commit, and stops before building if the installed version is below the floor.
- The workflow builds once, records the exact archive path and SHA-256, scans that archive, checks the same archive, and records scanner/check/URL statuses.
- The full R CMD check output, `00check.log`, and generated `testthat.Rout` / `testthat.Rout.fail` files are retained in the evidence directory.
- Added a SHA-pinned `actions/upload-artifact` step that runs only if the staged evidence passes the existing public-content scan. The artifact contains qualification evidence, not the package archive or model data.
- The declared URL fields were not changed. `docs/release/REPOSITORY.md` confirms `https://github.com/DavidZenz/GEModelR` as the approved repository target; the historical check did not retain raw URL evidence to establish that the target was wrong.

## Verification

- The plan's workflow marker/order assertions passed.
- YAML parsing passed and all 11 workflow shell blocks passed `bash -n`.
- The Matrix version comparison accepted `1.6-5` and rejected the installed `1.6-3` against the declared `1.6-5` minimum.
- `git diff --check` passed for the workflow change.
- No package check, archive build, hosted workflow, or URL recheck was run. Those are outside Task 1 and the hosted run is behind the authorization checkpoint.

## URL Diagnosis and Prior 404 Evidence

Machine-readable status:

```text
raw_url_check_log=not_available
url_diagnosis_status=evidence_insufficient
url_check_status=not_run
```

The 06-06 summary says the canonical repository and documentation-site URLs returned 404 while publication was unauthorized. It does not include the raw HTTP log or identify the exact request/response details. The current package fields declare `https://github.com/DavidZenz/GEModelR` and `https://davidzenz.github.io/GEModelR/`; the repository identity record approves the repository URL, but the missing raw log prevents diagnosing the old response. No URL change is justified from this evidence.

## Task 2 Checkpoint: One Exact Hosted Dispatch

The workflow commit is `5f4bbb7085823278c4bcced060aefaff142c65df` on local branch `master`. The target remote branch is `origin/master`, currently at `ac1d8e3b0e1439894864552012acec8cda314a9c`. The current local branch is not available on the remote. Making the exact final head runnable will require a separately authorized fast-forward push; that push would include all commits currently ahead of `origin/master`, not only this workflow change.

The intended action is one manual **workflow_dispatch** of **Source archive qualification** on the exact approved `master` SHA. The hosted job has a 60-minute timeout and uses `ubuntu-latest`; it installs R dependencies, Pandoc, and PDF-manual tools, then performs one source build, the exact-archive privacy scan, full `R CMD check --as-cran`, and a second scan before retaining the evidence artifact. It does not publish the package.

Current checkpoint record:

```text
target_branch=master
target_remote=origin/master
workflow_commit_sha=5f4bbb7085823278c4bcced060aefaff142c65df
dispatch_authorization=blocked
authorized_head_sha=not_available
raw_url_check_log=not_available
url_diagnosis_status=evidence_insufficient
url_check_status=not_run
hosted_workflow_status=not_started
hosted_run_id=not_run
head_sha=not_available
matrix_version=not_available
archive_sha256=not_available
archive_scan_sha256=not_available
check_exit_status=not_run
check_status_line=not_run
check_error_count=not_run
check_warning_count=not_run
unexplained_significant_note_count=not_run
hosted_serialization_status=not_run
serialization_test_status=not_run
ci_02_status=open
```

No remote push or hosted dispatch was performed. CI-02 remains open. Continue only after the maintainer explicitly authorizes or rejects the exact push/dispatch request; do not install or upgrade local Matrix.

## Task Commits

1. **Task 1: Bind the hosted archive check to supported Matrix and retain scanned evidence** — `5f4bbb7` (`fix(06-18): retain scanned archive qualification evidence`)

## User Setup Required

GitHub Actions runner availability and the exact push/dispatch authorization are recorded in [06-USER-SETUP.md](./06-USER-SETUP.md).

## Deviations from Plan

None. Task 1 is complete; the plan is intentionally halted at its blocking-human Task 2 checkpoint.

## Issues Encountered

- `actionlint` is not installed in this environment; Ruby is also unavailable. The workflow was instead parsed with the installed R `yaml` package and its shell blocks were validated with `bash -n`.
- The historical raw URL check log is absent, so the old 404 cause cannot be established.

## Next Phase Readiness

Awaiting explicit maintainer authorization for a fast-forward push of the local branch head and one workflow dispatch for that exact SHA. Until the hosted run returns complete evidence, hosted serialization and CI-02 remain open.

## Self-Check: PASSED

- This summary and `06-USER-SETUP.md` exist.
- Task 1 commit `5f4bbb7085823278c4bcced060aefaff142c65df` is present.
- Task 1 workflow verifications passed; the hosted workflow was not started.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-21 (halted at Task 2 authorization checkpoint)*
