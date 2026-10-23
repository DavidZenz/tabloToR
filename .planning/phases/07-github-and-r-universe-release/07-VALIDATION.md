---
phase: 07
slug: github-and-r-universe-release
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-23
---

# Phase 07 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Existing Node built-in tests and fresh-process installed R smoke |
| Existing scanner tests | `tools/ci/check-public-content.test.cjs` |
| Existing installed boundary | `tools/ci/run-installed-core-tests.R`; deterministic first-simulation fixture |
| Quick command | Focused checks for the changed release tool or static document/JSON consistency |
| Existing scanner command | `rtk node --test tools/ci/check-public-content.test.cjs` when scanner integration changes |
| Installation boundary | A clean supported R/Matrix library; an unrelated working directory; public GEModel facade |
| Runtime | Static checks target under 60 seconds; build/install timings are measured when executed |

No checks have run during planning. Matrix 1.6.3 is below the declared minimum, so supported-runtime execution is currently unavailable. This is an accurately reported preparation limitation, not a reason to reopen Phase 06 or prevent local drafts and tooling work.

## Sampling Rate

- Validate new executable release logic with focused tests covering source identity, artifact mismatch, unsafe destinations, and preservation of dirty/untracked inputs.
- Verify prose/JSON edits through parsing, link/identity consistency, and the staged diff; avoid tests that merely mirror prose.
- Scan every exact staged public archive/site/evidence artifact with the existing policy.
- Run the same deterministic installed smoke after each authorized distribution path is available; compare the expected three-region solution `c(0, 6, 0)` within `1e-12`.
- A missing supported runtime or external publication is `not_run`/`unavailable`, never an installation pass.

## Per-Task Verification Map

| Task ID | Wave | Requirement | Threat Ref | Verification | Command / evidence | File status |
|---------|------|-------------|------------|--------------|--------------------|-------------|
| 07-01-01 | 1 | REL-02 | T-07-01/02 | Real local packet end-to-end fixture | `rtk node --test tools/release/prepare-release.test.cjs` | Created by this task |
| 07-01-02 | 1 | REL-02 | T-07-01/02 | Invalid input, mutation, ordering, canaries, scanner seam | `rtk node --test tools/release/prepare-release.test.cjs tools/ci/check-public-content.test.cjs` | New test in 07-01-01; scanner tests exist |
| 07-01-03 | 1 | REL-02 | T-07-03 | R parse and CLI failure tests; actual numerical branch only in supported library | `rtk Rscript --vanilla -e 'parse(file="tools/ci/run-installed-release-smoke.R")'`; packet Node tests | Runner created in 07-01-01 |
| 07-02-01 | 1 | REL-02 | T-07-04/06 | JSON identity/schema parse and scoped diff | Exact Node JSON assertions in PLAN02; `rtk git diff --check` on its four draft paths | Created by this task |
| 07-02-02 | 1 | REL-02 | T-07-05 | Documentation identity/status review and scoped diff | `rtk git diff --check -- README.md NEWS.md GOVERNANCE.md docs/release/VERSION-LIFECYCLE.md` | Existing files |
| 07-02-03 | 1 | REL-02 | T-07-06 | Exact trigger filter assertion and preservation review | Exact Node filter assertions in PLAN02; scoped workflow diff | Existing workflows |
| 07-03-01 | 2 | REL-02 | T-07-07/08/09 | Projection/public-commit build source, one retained archive for scan/check/install, archive_source_commit equality, runtime/readiness negative fixtures | `rtk node --test tools/release/prepare-release.test.cjs tools/ci/check-public-content.test.cjs` | Expanded existing Phase07 tests |
| 07-03-02 | 2 | REL-02 | T-07-07/08/09 | Actual local packet verification and honest real qualification outcome | `rtk node tools/release/prepare-release.cjs verify --packet "$GEModelR_RELEASE_PACKET"` | Tool from 07-01/03; packet generated externally here |
| 07-04-01 | 3 | REL-02 | T-07-10 | Local packet verification plus exact maintainer disposition | Same packet verify command; digest-bound decision | Approval record created by this task |
| 07-04-02 | 3 | REL-02 | T-07-10/11/13 | Actual stricter readiness, remote ref, draft asset/registry identities | `verify --for-publication`; exact `gh release view` and `git ls-remote` commands in PLAN04; asset digest comparison | Requires actual approval/readiness; otherwise not_run |
| 07-04-03 | 3 | REL-02 | T-07-12/13 | Two real fresh installed numerical smokes and final release identities | Exact two `rtk proxy env ... Rscript --vanilla` invocations and final `gh release view` in PLAN04 | Runner from 07-01; channels/libraries require authorized distribution |

All commands in this map are planned verification, not executed results. The first task of Plan01 creates the focused test/runner infrastructure before expansion. Node fixtures prove release-tool behavior only; they do not qualify actual package installations. Full package/benchmark suites are not repeated for prose changes or the same accepted Phase06 limitations.

## Wave 0 Requirements

- Reuse the existing Node/R tools; no new test framework or dependency installation is planned.
- Add focused fixtures/tests only for newly introduced executable release logic; the planner records concrete paths and creating task IDs.
- Reuse the deterministic redistributable three-region fixture without source-tree namespace reloads.

## Manual and External Verification

| Behavior | Requirement | Boundary |
|----------|-------------|----------|
| Approve exact public source, tag type, version, destinations, notes, and remaining limitations | REL-02 | One concrete maintainer decision after the local release packet is reviewable |
| GitHub release/tag/assets and R-universe registry publication | REL-02 | Explicit authorization required under the local-only direction |
| Public installation and numerical smoke | REL-02 | Run against the approved published revision in clean supported libraries; retain source identity and results |
| Support/triage/release cadence | REL-02 | A concrete draft for maintainer review; no invented service guarantee |

## Validation Sign-Off

- [x] Final task map matches every plan
- [x] Focused tests are assigned for new release logic
- [x] No new framework installation or watch mode
- [x] Source/artifact identity and public-content boundaries are covered
- [x] Publication remains after concrete approval
- [x] No accepted Phase 06 gap is reopened automatically
- [ ] Final execution evidence accurately distinguishes pass, failure, and unavailable checks

Approval: pending execution; this file is a planning contract, not a check result.
