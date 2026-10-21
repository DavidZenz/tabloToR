# Phase 06: User Setup Required

**Generated:** 2026-10-21  
**Phase:** 06 — Documentation and Release Qualification  
**Status:** Incomplete

The qualification workflow is prepared locally. Hosted qualification requires maintainer authorization and an enabled GitHub Actions runner. No push or workflow run has been performed.

## Environment Variables

None.

## Account Setup

No account creation is required. Use the repository account that owns the approved private GEModelR target.

## Dashboard Configuration

- [ ] In **Repository Settings → Actions → General**, confirm GitHub Actions and an `ubuntu-latest` hosted runner are available for this repository.
- [ ] Review the Task 2 checkpoint and explicitly authorize or reject a fast-forward push of the exact local `master` head to `origin/master`. The local branch contains other previously committed work as well as the qualification workflow change; review the complete outgoing commit list before authorizing.
- [ ] Only after that push is separately authorized and complete, authorize one `workflow_dispatch` run of **Source archive qualification** on the exact approved `master` SHA. This is a human authorization checkpoint, not an instruction to dispatch now.

## Verification

In **Actions → Source archive qualification**, confirm the run uses the authorized SHA, records Matrix at or above the DESCRIPTION floor, builds and scans one archive, checks that exact archive, retains the check and test logs, and uploads evidence only after the evidence scan succeeds. The run has a 60-minute timeout.

Expected result for qualification is a clean `R CMD check --as-cran` with exact `Status: OK`, passing current URL checks, and retained installed-package test output. Any unavailable or failed gate keeps CI-02 open.

---

Mark this setup complete only after the repository runner configuration is confirmed and the authorized hosted run has finished.
