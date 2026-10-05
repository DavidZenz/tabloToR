---
phase: 02
slug: compatibility-and-numerical-baseline
status: draft
nyquist_compliant: true
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
| 02-01-01 | 02-01 | 1 | COMP-01, COMP-02, COMP-03 | T-02-01 | Observed surface is complete, tiered, and default-preserving | contract | rtk R --vanilla -q -e 'testthat::test_local(filter="compatibility-manifest")' | ❌ W0 | ⬜ pending |
| 02-01-02 | 02-01 | 1 | COMP-02, COMP-03 | T-02-01 | Empty/single/NULL and encoding/equality contracts are explicit | contract | rtk R --vanilla -q -e 'testthat::test_local(filter="compatibility-helpers|compatibility-manifest")' | ❌ W0 | ⬜ pending |
| 02-02-01 | 02-02 | 2 | COMP-01 | T-02-05, T-02-07 | Redistributable fixture is bounded and provenance-recorded | integration | rtk R --vanilla -q -e 'testthat::test_local(filter="documented-workflow")' | ❌ W0 | ⬜ pending |
| 02-02-02 | 02-02 | 2 | COMP-01, COMP-03 | T-02-06 | Both shock APIs normalize and consume shocks deterministically | integration | rtk R --vanilla -q -e 'testthat::test_local(filter="documented-workflow|sparse-core")' | ❌ W0 | ⬜ pending |
| 02-02-03 | 02-02 | 2 | COMP-01, COMP-02, COMP-03 | T-02-08 | Workflow IDs expose defaults, output branches, legacy smoke, and unclassified coverage | contract/integration | rtk R --vanilla -q -e 'testthat::test_local(filter="documented-workflow|public-solver-contract|compatibility-manifest")' | ❌ W0 | ⬜ pending |
| 02-03-01 | 02-03 | 3 | NUM-01, NUM-02 | T-02-09 | Matrix candidate acceptance always includes finiteness and true residual | numerical integration | rtk R --vanilla -q -e 'testthat::test_local(filter="numerical-baseline")' | ❌ W0 | ⬜ pending |
| 02-03-02 | 02-03 | 3 | NUM-01 | T-02-09, T-02-10 | Authority mapping and optional capability skips are explicit | numerical integration | rtk R --vanilla -q -e 'testthat::test_local(filter="numerical-baseline|public-cpp-backend|sparse-core")' | Partial | ⬜ pending |
| 02-04-01 | 02-04 | 4 | NUM-02 | T-02-12 | Sparse failures after substeps preserve caller-visible state | fault-injection integration | rtk R --vanilla -q -e 'testthat::test_local(filter="transactional-state|numerical-baseline|sparse-core")' | ❌ W0 | ⬜ pending |
| 02-04-02 | 02-04 | 4 | NUM-02, COMP-03 | T-02-12, T-02-14 | Legacy isolation and post-simulation retry are atomic and observable | fault-injection integration | rtk R --vanilla -q -e 'testthat::test_local(filter="transactional-state|documented-workflow|public-solver-contract")' | ❌ W0 | ⬜ pending |
| 02-05-01 | 02-05 | 5 | COMP-03 | T-02-15 | One accepted logical payload restores and solves in a fresh process | serialization integration | rtk R --vanilla -q -e 'testthat::test_local(filter="model-serialization")' | ❌ W0 | ⬜ pending |
| 02-05-02 | 02-05 | 5 | COMP-03 | T-02-15, T-02-16 | Invalid payloads fail closed and caches rebuild lazily | serialization contract | rtk R --vanilla -q -e 'testthat::test_local(filter="model-serialization|compatibility-manifest|sparse-cpp-cache")' | ❌ W0 | ⬜ pending |
| 02-06-01 | 02-06 | 6 | COMP-01, COMP-02, COMP-03, NUM-01, NUM-02 | T-02-18, T-02-19 | Proposal artifacts carry source, fixture, model, package, and runtime provenance | artifact integration | rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check | ❌ W0 | ⬜ pending |
| 02-06-02 | 02-06 | 6 | COMP-01, COMP-02, COMP-03, NUM-01, NUM-02 | T-02-18, T-02-20 | Integrated acceptance and package gate behavior covers all Phase 2 filters, read-only baseline check, and package check close the phase | package/integration | rtk R --vanilla -q -e 'testthat::test_local(filter="compatibility|numerical-baseline|transactional-state|model-serialization|baseline-artifacts|public-solver-contract|public-cpp-backend|sparse-core|sparse-cpp-cache")' | ❌ W0 | ⬜ pending |
| 02-06-03 | 02-06 | 6 | COMP-01, COMP-02, COMP-03, NUM-01, NUM-02 | T-02-18, T-02-20 | Acceptance CLI safe/dry/error paths and integrated acceptance/package gate behavior are reviewable and remain canonical-output protected | package/integration | rtk Rscript --vanilla tools/accept_phase02_baselines.R --help; rtk R --vanilla -q -e 'testthat::test_local(filter="compatibility|numerical-baseline|transactional-state|model-serialization|baseline-artifacts|public-solver-contract|public-cpp-backend|sparse-core|sparse-cpp-cache")' | ❌ W0 | ⬜ pending |

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
