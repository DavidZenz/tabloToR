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

The commands below are planned gates copied from the 13 executable tasks. They were not run while revising the plans.

| Task ID | Plan | Wave | Requirement(s) | Threat Ref | Focused evidence | Automated command | Status |
|---------|------|------|---------------|------------|------------------|-------------------|--------|
| 04-01-T1 | 04-01 | 1 | API-02 | T-04-01 | Matrix public workflow verifies preflight precedes system emission and accepted state commits once. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` | planned |
| 04-01-T2 | 04-01 | 1 | API-02 | T-04-01 | Adapter result contract rejects missing/inconsistent/non-finite/residual-failing evidence before commit. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` | planned |
| 04-02-T1 | 04-02 | 2 | API-02 | T-04-01 | Every stable R/compatibility backend ID routes explicitly and is never silently substituted. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract", reporter = "summary")'` | planned |
| 04-02-T2 | 04-02 | 2 | API-02 | T-04-01, T-04-03 | Native capability preflight precedes emission; success/error paths clean solve-scoped factors and buffers. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-cpp-backend", reporter = "summary")'` | planned |
| 04-03-T1 | 04-03 | 3 | API-02 | T-04-01 | Failed loadTablo/loadData preserve a complete preloaded-model snapshot; engine/order errors expose GEModelR_validation_error and remediation. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "lifecycle-contract", reporter = "summary")'` | planned |
| 04-03-T2 | 04-03 | 3 | API-02 | T-04-01, T-04-02 | Closure/shock invalidation is selective and malformed/oversized state loads preserve the receiver. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "lifecycle-contract|model-serialization", reporter = "summary")'` | planned |
| 04-04-T1 | 04-04 | 3 | API-02 | T-04-01 | Unknown/malformed selectors and over-budget projections fail before output construction; explicit empty selections retain their contract. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "documented-workflow", reporter = "summary")'` | planned |
| 04-04-T2 | 04-04 | 3 | API-02 | T-04-01 | Full/compact output parity holds and a post-closure solve rebuilds the current full index before projection. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "documented-workflow", reporter = "summary")'` | planned |
| 04-05-T1 | 04-05 | 4 | API-02 | T-04-01, T-04-03 | Lifecycle and solve validation share a stable primary class; capability, numerical, postsim, retryable, and committed-state paths have exact classes/fields. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract|transactional-state|public-cpp-backend", reporter = "summary")'` | planned |
| 04-05-T2 | 04-05 | 4 | API-02 | T-04-01 | Each solve attempt replaces lastDiagnostics with the exact running/final status envelope; validation/capability/numerical/postsim failures cannot leave stale success. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract|transactional-state", reporter = "summary")'` | planned |
| 04-05-T3 | 04-05 | 4 | API-02 | T-04-03 | Native capabilities, effective threads, cleanup, and exact small-envelope serialization roundtrip are verified. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-cpp-backend|model-serialization", reporter = "summary")'` | planned |
| 04-06-T1 | 04-06 | 5 | API-01, DOCS-01 | T-04-01 | roxygen generation produces only the deliberate GEModel namespace and docs for options, backend selectors, diagnostics, and statuses. | `rtk Rscript --vanilla -e 'roxygen2::roxygenise()'` | planned |
| 04-06-T2 | 04-06 | 5 | API-01, DOCS-01 | T-04-01 | Exact export and generated Rd tests cover methods, package topic, options, backends, envelope fields/statuses, and condition classes. | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-solver-contract|api-documentation", reporter = "summary")'` | planned |

## Wave 0 Requirements

- [ ] Reuse the existing testthat edition 3 setup; no framework installation is needed.
- [ ] Plan tasks 04-01 through 04-06 own the namespace/backend and documented-workflow contract changes; no separate Wave 0 test scaffold is required.
- [ ] Keep test inputs small and redistributable; do not add proprietary TABLO/HAR fixtures.
- [ ] Record observed feedback timings during execution; each planned task and focused command is mapped above.

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
