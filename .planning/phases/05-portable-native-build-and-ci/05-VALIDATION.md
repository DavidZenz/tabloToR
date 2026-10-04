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
| 05-01-T1 | 05-01 | 1 | PORT-03 | T-05-01-01 | Installed structured solves use registered package DLL wrappers and the compiler tripwire remains untouched from an unrelated working directory. | installed integration | rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && rtk Rscript --vanilla -e 'testthat::test_package("GEModelR", filter = "native-portability", reporter = "summary", lib.loc = "/tmp/ge-modelr-lib")' | ❌ W0 | ⬜ pending |
| 05-01-T2 | 05-01 | 1 | CI-01 | T-05-01-02 | The initial Linux serial job has PR/default-push/weekly triggers, immutable action references, read-only permission, installation, and installed testing. | workflow integration | rtk git diff --check && rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && rtk Rscript --vanilla -e 'testthat::test_package("GEModelR", filter = "native-portability", reporter = "summary", lib.loc = "/tmp/ge-modelr-lib")' | ❌ W0 | ⬜ pending |
| 05-02-T1 | 05-02 | 1 | PORT-03 | T-05-02-01 | SuiteSparse remains recognized but fails before compilation, matrix emission, or state mutation with explicit Matrix remediation; the low-level direct entry uses the same fail-closed no-compile contract. | contract integration | rtk Rscript --vanilla -e 'testthat::test_local(filter = "suite-sparse-unsupported|public-solver-contract|sparse-core", reporter = "summary")' | ❌ W0 | ⬜ pending |
| 05-02-T2 | 05-02 | 1 | PORT-03 | T-05-02-02 | API help and README call SuiteSparse recognized but unavailable, remove its supported solve example, and recommend explicit Matrix selection. | documentation test | rtk Rscript --vanilla -e 'testthat::test_local(filter = "api-documentation|suite-sparse-unsupported", reporter = "summary")' && rtk rg -n 'SuiteSparse.*unavailable|recognized.*SuiteSparse|backend[[:space:]]*=[[:space:]]*"Matrix"' README.md | ✅ existing docs test, extend assertions | ⬜ pending |
| 05-03-T1 | 05-03 | 1 | PORT-02 | T-05-03-02 | Required OpenMP cells assert capability, bounds, two-thread execution and numerical parity, and print timing without a speed gate. | native integration | GEModelR_EXPECT_OPENMP=required rtk Rscript --vanilla -e 'testthat::test_local(filter = "sparse-schur-openmp|public-cpp-backend", reporter = "summary")' | ⚠️ existing coverage needs expected-job assertion | ⬜ pending |
| 05-03-T2 | 05-03 | 1 | PORT-01, PORT-02 | T-05-03-01 | Explicit serial cells report no OpenMP, one maximum thread, a one-thread default, and an error above one thread. | native integration | GEModelR_EXPECT_OPENMP=forbidden rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-cpp-backend|sparse-schur-openmp", reporter = "summary")' | ⚠️ existing coverage needs serial contract | ⬜ pending |
| 05-04-T1 | 05-04 | 1 | PORT-01, CI-01 | T-05-04-02 | Installed compatibility tests enforce explicit Matrix endpoints and any declared package floor, without requiring a final floor before evidence exists. | package-version contract | rtk Rscript --vanilla -e 'testthat::test_local(filter = "matrix-compatibility", reporter = "summary")' | ❌ W0 | ⬜ pending |
| 05-04-T2 | 05-04 | 1 | CI-01 | T-05-04-01 | The candidate installer source-installs the exact requested archive in an isolated library, rejects version mismatches, and supports a no-network dry run. | source-install utility | rtk Rscript --vanilla tools/ci/install-matrix-source.R --dry-run https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_1.6-5.tar.gz 1.6-5 /tmp/ge-modelr-matrix-floor | ❌ W0 | ⬜ pending |
| 05-05-T1 | 05-05 | 2 | CI-01, PORT-01 | T-05-05-01, T-05-05-02 | Every OS has a serial cell and each OpenMP-capable Linux/Windows toolchain has a required-capability cell on all event triggers. | workflow integration | rtk git diff --check && rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && rtk Rscript --vanilla -e 'testthat::test_package("GEModelR", filter = "native-portability|suite-sparse-unsupported|sparse-schur-openmp|public-cpp-backend", reporter = "summary", lib.loc = "/tmp/ge-modelr-lib")' | ❌ W0 | ⬜ pending |
| 05-05-T2 | 05-05 | 2 | PORT-01, PORT-02, PORT-03 | T-05-05-03 | The installed runner checks OpenMP/Matrix expectations and executes native, SuiteSparse, sparse solver, and compatibility contracts on every platform. | installed integration | rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && GEModelR_EXPECT_OPENMP=forbidden GEModelR_EXPECT_MATRIX_VERSION=installed R_LIBS=/tmp/ge-modelr-lib rtk Rscript --vanilla tools/ci/run-installed-core-tests.R | ❌ W0 | ⬜ pending |
| 05-06-T1 | 05-06 | 3 | CI-01, PORT-01, PORT-02, PORT-03 | T-05-06-01 | Six provisional R/Matrix pairs are source-installed and solver-tested across 18 serial and 12 Linux/Windows OpenMP rows; the five oldrel-1 floor rows record exact alias/version, OS/build, Matrix version, source-install and solver-test outcomes for 05-07 fallback evaluation. | compatibility matrix | rtk git diff --check && rtk Rscript --vanilla -e 'testthat::test_local(filter = "matrix-compatibility|native-portability|suite-sparse-unsupported", reporter = "summary")' | ❌ W0 | ⬜ pending |
| 05-06-T2 | 05-06 | 3 | CI-01 | T-05-06-02 | The report formatter's fast self-test validates current-result, inherited-baseline, and original exit-status reporting without running R CMD check. | reporting contract | rtk Rscript --vanilla tools/ci/summarize-r-cmd-check.R --self-test | ❌ W0 | ⬜ pending |
| 05-06-T3 | 05-06 | 3 | CI-01 | T-05-06-02, T-05-06-03 | The separately named non-required baseline job reports current full-check results, preserves the original exit status/raw artifacts, and labels exact Phase 04 counts as inherited only. | package check | rtk Rscript --vanilla tools/ci/summarize-r-cmd-check.R --run | ❌ W0 | ⬜ pending |
| 05-07-T1 | 05-07 | 4 | CI-01, PORT-01 | T-05-07-01 | The selected Matrix candidate passes all five oldrel-1 platform/build source-install and installed-solver rows; any failed provisional candidate has row-specific fallback evidence. | evidence validation | rtk Rscript --vanilla tools/ci/verify-matrix-floor-evidence.R --input .planning/phases/05-portable-native-build-and-ci/matrix-candidate-evidence.csv --output .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE.md | ❌ W0 | ⬜ pending |
| 05-07-T2 | 05-07 | 4 | CI-01, PORT-01 | T-05-07-02 | DESCRIPTION and README match the evidence-validated Matrix floor/current interval, and the installed compatibility contract enforces the final floor. | metadata contract | rtk git diff --check && rtk Rscript --vanilla tools/ci/verify-matrix-floor-evidence.R --verify-final-metadata --evidence .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE.md | ❌ W0 | ⬜ pending |

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
