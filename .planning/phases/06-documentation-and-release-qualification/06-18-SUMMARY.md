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
  - A recorded local-only dispatch rejection with hosted qualification and CI-02 explicitly left open
affects: [CI-02, release qualification]
actuals:
  tokens: 7161
  tasks: 3
  commits: 3
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
    - .planning/ROADMAP.md
key-decisions:
  - "Do not alter URL fields from a historical 404 without a retained authoritative check log proving the declared target is wrong."
  - "Honor the maintainer's local-only direction as rejection of the branch push and hosted dispatch; keep CI-02 open."
patterns-established:
  - "Bind archive check evidence to the source SHA, resolved Matrix version, exact archive digest, and passing evidence scan."
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
duration: 23min
completed: 2026-10-21
status: complete
---

# Phase 06 Plan 18: Hosted Archive Qualification Workflow Summary

**The workflow records Matrix and archive identity, preserves check/test logs, and uploads only scanned evidence; the requested hosted run was rejected to keep the work local, leaving CI-02 open.**

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
- `git diff --check` passed for the scoped workflow, summary, state, and roadmap changes.
- The Task 3 machine-readable no-dispatch conditions were checked: authorization is rejected, hosted workflow is not started, run identity is unavailable, required hosted evidence is not run, URL check is not run, and CI-02 remains open.
- No package check, archive build, hosted workflow, or URL recheck was run because the maintainer directed that the work stay local.

## URL Diagnosis and Prior 404 Evidence

The 06-06 summary says the canonical repository and documentation-site URLs returned 404 while publication was unauthorized. It does not include the raw HTTP log or identify the exact request/response details. The current package fields declare `https://github.com/DavidZenz/GEModelR` and `https://davidzenz.github.io/GEModelR/`; the repository identity record approves the repository URL, but the missing raw log prevents diagnosing the old response. No URL change is justified from this evidence.

## Task 2: Dispatch Authorization Rejected

The workflow commit is `5f4bbb7085823278c4bcced060aefaff142c65df` on local branch `master`. At the decision checkpoint, local HEAD was `c3c03ebf740e29b680842c2c38b9b40d4a563489`; `origin/master` was `ac1d8e3b0e1439894864552012acec8cda314a9c`, leaving the local branch nine commits ahead. The maintainer's earlier instruction to keep the work local is treated as rejection of publishing this branch and dispatching a hosted workflow. No push or dispatch was performed.

The declined action was one manual **workflow_dispatch** of **Source archive qualification** on the exact local `master` SHA. The hosted job would have had a 60-minute timeout and used `ubuntu-latest`; it would install R dependencies, Pandoc, and PDF-manual tools, then perform one source build, the exact-archive privacy scan, full `R CMD check --as-cran`, and a second scan before retaining the evidence artifact. It would not publish the package.

Current checkpoint record:

```text
target_branch=master
target_remote=origin/master
workflow_commit_sha=5f4bbb7085823278c4bcced060aefaff142c65df
decision_checkpoint_head_sha=c3c03ebf740e29b680842c2c38b9b40d4a563489
dispatch_authorization=rejected
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

The exact blocker is the maintainer's local-only direction: making the workflow runnable would require pushing all nine commits ahead of `origin/master`, which was not authorized, and no GitHub Actions run can be dispatched against an unpublished SHA. Therefore `hosted_workflow_status=not_started`, all hosted run and test evidence remains `not_run` or `not_available`, and CI-02 remains open. No local Matrix upgrade, archive build, package check, or URL recheck was performed.

## Task 3: No-Dispatch Qualification Record

The rejected authorization followed the plan's no-dispatch branch. The exact required hosted-result fields are recorded above as unavailable or not run; no hosted serialization result or CI-02 pass is claimed. The canonical repository and site URLs remain unchanged because the historical 404 log is unavailable and repository-owned evidence does not prove the repository target wrong.

## Task Commits

1. **Task 1: Bind the hosted archive check to supported Matrix and retain scanned evidence** — `5f4bbb7` (`fix(06-18): retain scanned archive qualification evidence`)
2. **Checkpoint metadata** — `c3c03eb` (`docs(06-18): record hosted dispatch checkpoint`)
3. **Task 2/3 no-dispatch closeout** — this summary, STATE, and ROADMAP closeout commit.

## User Setup Required

No user setup was performed because hosted dispatch was rejected. The pre-existing [06-USER-SETUP.md](./06-USER-SETUP.md) is retained as a local checkpoint artifact and does not indicate dispatch authorization.

## Deviations from Plan

**1. Retained checkpoint setup artifact outside the plan file list**
- **Found during:** Checkpoint metadata preparation
- **Reason:** `.planning/phases/06-documentation-and-release-qualification/06-USER-SETUP.md` was added in the preceding checkpoint commit but is outside this plan's `files_modified` list.
- **Outcome:** Retained it as a small workflow checkpoint artifact without further changes.
- **Files modified:** `.planning/phases/06-documentation-and-release-qualification/06-USER-SETUP.md` (prior checkpoint commit)

## Issues Encountered

- `actionlint` is not installed in this environment; Ruby is also unavailable. The workflow was instead parsed with the installed R `yaml` package and its shell blocks were validated with `bash -n`.
- The historical raw URL check log is absent, so the old 404 cause cannot be established.

## Next Phase Readiness

Plan 06-18 is complete through its no-dispatch branch. Hosted qualification, hosted serialization, and CI-02 remain open; the workflow is local and no publication or remote change is authorized.

## Self-Check: PASSED

- This summary and `06-USER-SETUP.md` exist.
- Task 1 commit `5f4bbb7085823278c4bcced060aefaff142c65df` is present.
- Checkpoint commit `c3c03ebf740e29b680842c2c38b9b40d4a563489` is present.
- Workflow and no-dispatch verifications passed; State advances to Plan 19, Roadmap marks Plan 18 complete, and CI-02 remains unchecked/open.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-21 (dispatch rejected; Task 3 no-dispatch outcome recorded)*
