---
phase: 02
slug: compatibility-and-numerical-baseline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-02
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2, edition 3 |
| **Config file** | `DESCRIPTION`; launcher `tests/testthat.R` |
| **Quick run command** | `rtk R --vanilla -q -e 'testthat::test_local(filter = "compatibility|numerical-baseline|transactional-state|model-serialization|baseline-artifacts", reporter = "summary")'` |
| **Full suite command** | `rtk R CMD check .` |
| **Estimated runtime** | ~30 seconds focused; package check varies by host |

## Sampling Rate

- **After every task commit:** Run the new focused test plus `public-solver-contract` and the directly affected sparse/native test.
- **After every plan wave:** Run all Phase 2 filters and the focused existing regression suite.
- **Before `$gsd-verify-work`:** Run `rtk R CMD check .` and `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check`.
- **Max feedback latency:** 60 seconds for focused tests.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-TBD-01 | TBD | TBD | COMP-01 | T-02-01 | Fixtures are bounded and provenance-recorded | integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="documented-workflow")'` | ❌ W0 | ⬜ pending |
| 02-TBD-02 | TBD | TBD | COMP-02 | — | Defaults and explicit selections remain equivalent | contract | `rtk R --vanilla -q -e 'testthat::test_local(filter="public-solver-contract|compatibility-manifest")'` | Partial | ⬜ pending |
| 02-TBD-03 | TBD | TBD | COMP-03 | T-02-02 | Serialized payload excludes native/cache state | contract/integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="compatibility-manifest|model-serialization|documented-workflow")'` | ❌ W0 | ⬜ pending |
| 02-TBD-04 | TBD | TBD | NUM-01 | T-02-03 | Baseline acceptance is review-gated and read-only in tests | numerical integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="numerical-baseline|public-cpp-backend")'` | Partial | ⬜ pending |
| 02-TBD-05 | TBD | TBD | NUM-02 | T-02-04 | Failed solves do not mutate accepted model state | fault-injection integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="transactional-state")'` | ❌ W0 | ⬜ pending |

*Task IDs, plan numbers, and waves are finalized after planning. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky.*

## Wave 0 Requirements

- [ ] `tests/testthat/fixtures/three-region.tab` and fixture provenance record.
- [ ] `inst/compatibility/GEModel-contract.csv` with complete observed-surface tiers.
- [ ] `tests/testthat/helper-compatibility.R` for structural descriptors, backend capabilities, tolerances, and state snapshots.
- [ ] Characterization tests for manifest, documented workflows, numerical baselines, transactional state, serialization, and baseline artifacts.
- [ ] Proposal-only baseline refresh/check tooling under `tools/`.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| External reduced/full GTAP evidence | NUM-01 | Data is private and too large for repository fixtures | Run the external benchmark profile and retain fingerprints, residuals, capability report, and host metadata. |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency remains below 60 seconds.
- [ ] `nyquist_compliant: true` is set in frontmatter.

**Approval:** pending
