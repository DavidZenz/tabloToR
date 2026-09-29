---
phase: 04
slug: public-api-and-solver-boundaries
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-29
---

# Phase 04 — Validation Strategy

> Validation contract for the public namespace and internal backend boundary.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2, edition 3 |
| **Config file** | `DESCRIPTION`, `tests/testthat.R` |
| **Quick run command** | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` |
| **Full suite command** | `rtk Rscript --vanilla -e 'testthat::test_local(reporter = "summary")'` |
| **Package gate** | `rtk R CMD check .` |
| **Estimated runtime** | Focused tests target 60 seconds; full suite/check latency is not measured and must be recorded during execution. |

## Sampling Rate

- After each task: run the focused contract test relevant to the changed boundary.
- After each plan wave: run the full testthat suite in a clean R process.
- Before `$gsd-verify-work`: run `rtk R CMD check .` and resolve errors and warnings; document any remaining notes.
- Keep focused feedback near 60 seconds; record actual timings during execution.

## Per-Task Verification Map

Task IDs and waves are assigned when the plans are created; the planner must map every task to one or more rows below.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | API-01 | — | Internal parser/compiler/solver/native names are absent from the public namespace. | contract | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` | Existing contract test; extend as planned | pending |
| TBD | TBD | TBD | DOCS-01 | — | Generated help covers every supported export, package topic, and supported option/backend control. | package check | `rtk R CMD check .` | Existing package docs; update as planned | pending |
| TBD | TBD | TBD | API-02 | T-04-01, T-04-03 | Invalid requests fail before matrix construction or state mutation; requested backend identity, central residual acceptance, and cleanup remain observable. | unit/integration | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` | Existing contract/native tests; extend as planned | pending |
| TBD | TBD | TBD | API-02 | T-04-02 | Logical-state size/schema failures preserve the receiving model and existing serialization behavior. | regression | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "model-serialization", reporter = "summary")'` | Existing serialization tests; confirm or extend as planned | pending |

## Wave 0 Requirements

- [ ] Reuse the existing testthat edition 3 setup; no framework installation is needed.
- [ ] Extend the namespace/backend contract tests and documented-workflow tests with deterministic cases for the planned API boundaries.
- [ ] Keep test inputs small and redistributable; do not add proprietary TABLO/HAR fixtures.
- [ ] Record task IDs, test ownership, and observed feedback timings after plans are finalized.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Review the exact public export and option allowlists against the compatibility manifest and Phase 4 decisions. | API-01, DOCS-01 | The context leaves the final list to a deliberate manifest/docs audit. | Confirm every supported entry has generated documentation and every accidental helper remains private. |

## Validation Sign-Off

- [ ] Every plan task has an automated verification command or an explicit Wave 0 dependency.
- [ ] No three consecutive tasks lack automated verification.
- [ ] Wave 0 covers missing references and preserves existing numerical/state gates.
- [ ] Full-suite and package-check timings are recorded during execution.
- [ ] Set `wave_0_complete` and `nyquist_compliant` true only after execution evidence satisfies the validation contract.

**Approval:** pending execution
