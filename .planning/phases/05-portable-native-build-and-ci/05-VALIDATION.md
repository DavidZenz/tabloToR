---
phase: 05
slug: portable-native-build-and-ci
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-01
---

# Phase 05 — Validation Strategy

> Validation contract for portable native installation, optional OpenMP, and installed solver behavior.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat, edition 3 |
| **Config file** | `DESCRIPTION`, `tests/testthat.R` |
| **Quick run command** | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "native-portability|sparse-schur-openmp|public-cpp-backend", reporter = "summary")'` |
| **Full suite command** | `rtk Rscript --vanilla -e 'testthat::test_local(reporter = "summary")'` |
| **Package gate** | `rtk R CMD check .` |
| **Estimated runtime** | Focused tests target ≤60 seconds; full suite approximately 5 minutes based on Phase 04 |

## Sampling Rate

- After each task: run the focused test group for the changed native or solver boundary.
- After each plan wave: run the full testthat suite in a clean R process.
- In each CI matrix cell: install GEModelR, then run the installed package's core tests.
- Before `$gsd-verify-work`: run `rtk R CMD check .` in the designated representative cell and report existing check findings accurately.
- Keep focused feedback near 60 seconds; record actual timings during execution.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-T1 | 05-01 | 1 | PORT-03 | — | Installed structured solves use registered package DLL routines and do not invoke a runtime compiler. | installed integration | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "native-portability", reporter = "summary")'` | ❌ W0 | ⬜ pending |
| 05-02-T1 | 05-02 | 2 | PORT-03 | — | Explicit SuiteSparse selection fails before matrix emission or model-state mutation, with `backend="Matrix"` remediation and no `sourceCpp()` call. | contract integration | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "native-portability|public-solver-contract", reporter = "summary")'` | ❌ W0 | ⬜ pending |
| 05-03-T1 | 05-03 | 3 | PORT-02 | — | Expected OpenMP jobs fail if capability is absent; capability, thread bounds, and serial/two-thread numerical parity are asserted. | native integration | `rtk Rscript --vanilla -e 'testthat::test_local(filter = "sparse-schur-openmp|public-cpp-backend", reporter = "summary")'` | ⚠️ existing coverage needs expected-job assertion | ⬜ pending |
| 05-04-T1 | 05-04 | 4 | PORT-01 | — | Explicit serial builds on Linux, macOS, and Windows report `openmp == FALSE`, one maximum thread, a working one-thread solve, and a clear error above one thread. | installed integration | Install with the CI serial build settings, then `Rscript --vanilla -e 'testthat::test_package("GEModelR")'` | ❌ W0 | ⬜ pending |
| 05-05-T1 | 05-05 | 5 | CI-01, PORT-01, PORT-02 | — | Pull requests, default-branch pushes, and weekly runs execute all supported serial cells and OpenMP cells where the toolchain supports it; every cell installs and runs core tests. | workflow integration | Validate workflow triggers and explicit supported matrix rows; inspect install and test results for every row. | ❌ W0 | ⬜ pending |
| 05-06-T1 | 05-06 | 6 | CI-01 | — | Release/oldrel/devel and Matrix minimum/current endpoints are tested in valid pairings; one representative cell records the full package-check result. | compatibility integration | Assert installed `packageVersion("Matrix")` per endpoint cell; run `rtk R CMD check .` in the selected representative cell. | ❌ W0 | ⬜ pending |

## Wave 0 Requirements

- [ ] Add focused coverage for installed structured solving outside the checkout and prove it does not call `Rcpp::sourceCpp()`.
- [ ] Add an explicit SuiteSparse capability-error assertion, including no matrix emission and no model-state mutation.
- [ ] Extend OpenMP tests so an expected OpenMP job fails when capability is false; retain skip behavior only for explicit serial jobs.
- [ ] Reuse the existing testthat edition 3 setup; no test framework installation is needed.
- [ ] Keep fixtures deterministic and small; do not add proprietary TABLO/HAR inputs.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Review the representative full package-check report against the Phase 04 baseline. | CI-01 | The package currently has separately documented check failures; CI must disclose their counts and categories without implying Phase 05 resolved them. | Compare the saved Phase 05 `R CMD check` log with Phase 04's 2,364 passes, 19 failures, 65 skips, 1 ERROR, 4 WARNINGs, and 4 NOTEs; identify only newly introduced or resolved items. |

## Validation Sign-Off

- [ ] Every final plan task has a focused automated verification command or a Wave 0 dependency.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers missing references without replacing installed-package CI assertions.
- [ ] No watch-mode flags.
- [ ] Set `wave_0_complete` and `nyquist_compliant` true only after execution evidence satisfies this contract.

**Approval:** pending
