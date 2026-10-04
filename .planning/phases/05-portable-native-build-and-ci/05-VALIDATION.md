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

All 15 final tasks are mapped below. Local verification references the corresponding 05-01 through 05-05 summaries and the 05-06 execution notes; it does not prove hosted platform support or a final Matrix floor.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-T1 | 05-01 | 1 | PORT-03 | T-05-01-01 | Installed structured solves use registered package DLL wrappers and the compiler tripwire remains untouched from an unrelated working directory. | installed integration | [Exact task command](#05-01-t1) | Present | Local installed verification passed (05-01 summary). |
| 05-01-T2 | 05-01 | 1 | CI-01 | T-05-01-02 | The initial Linux serial job has PR/default-push/weekly triggers, immutable action references, read-only permission, installation, and installed testing. | workflow integration | [Exact task command](#05-01-t2) | Present | Local authoring/install verified; hosted event pending. |
| 05-02-T1 | 05-02 | 1 | PORT-03 | T-05-02-01 | SuiteSparse remains recognized but fails before compilation, matrix emission, or state mutation with explicit Matrix remediation; the low-level direct entry uses the same fail-closed no-compile contract. | contract integration | [Exact task command](#05-02-t1) | Present | Local installed contract passed (05-02 summary); hosted OS rows pending. |
| 05-02-T2 | 05-02 | 1 | PORT-03 | T-05-02-02 | API help and README call SuiteSparse recognized but unavailable, remove its supported solve example, and recommend explicit Matrix selection. | documentation test | [Exact task command](#05-02-t2) | Present | Local documentation contract passed (05-02 summary). |
| 05-03-T1 | 05-03 | 1 | PORT-02 | T-05-03-02 | Required OpenMP cells assert capability, bounds, two-thread execution and numerical parity, and print timing without a speed gate. | native integration | [Exact task command](#05-03-t1) | Present | Local Linux OpenMP passed (05-03 summary); hosted Linux/Windows pending. |
| 05-03-T2 | 05-03 | 1 | PORT-01, PORT-02 | T-05-03-01 | Explicit serial cells report no OpenMP, one maximum thread, a one-thread default, and an error above one thread. | native integration | [Exact task command](#05-03-t2) | Present | Local Linux serial passed (05-03 summary); hosted OS rows pending. |
| 05-04-T1 | 05-04 | 1 | PORT-01, CI-01 | T-05-04-02 | Installed compatibility tests enforce explicit Matrix endpoints and any declared package floor, without requiring a final floor before evidence exists. | package-version contract | [Exact task command](#05-04-t1) | Present | Local installed endpoints passed (05-04 summary); final floor pending. |
| 05-04-T2 | 05-04 | 1 | CI-01 | T-05-04-01 | The candidate installer source-installs the exact requested archive in an isolated library, rejects version mismatches, and supports a no-network dry run. | source-install utility | [Exact task command](#05-04-t2) | Present | Dry run and exact 1.6-5 local source install passed (05-04 summary). |
| 05-05-T1 | 05-05 | 2 | CI-01, PORT-01 | T-05-05-01, T-05-05-02 | Every OS has a serial cell and each OpenMP-capable Linux/Windows toolchain has a required-capability cell on all event triggers. | workflow integration | [Exact task command](#05-05-t1) | Present | Local Linux serial/OpenMP passed (05-05 summary); hosted platforms pending. |
| 05-05-T2 | 05-05 | 2 | PORT-01, PORT-02, PORT-03 | T-05-05-03 | The installed runner checks OpenMP/Matrix expectations and executes native, SuiteSparse, sparse solver, and compatibility contracts on every platform. | installed integration | [Exact task command](#05-05-t2) | Present | Local installed runner passed all six groups (05-05 summary); hosted pending. |
| 05-06-T1 | 05-06 | 3 | CI-01, PORT-01, PORT-02, PORT-03 | T-05-06-01 | Six provisional R/Matrix pairs are source-installed and solver-tested across 18 serial and 12 Linux/Windows OpenMP rows; the five oldrel-1 floor rows record exact alias/version, OS/build, Matrix version, source-install and solver-test outcomes for 05-07 fallback evaluation. | compatibility matrix | [Exact task command](#05-06-t1) | Present | Local authoring and 57 installed assertions passed; all 30 hosted rows pending. |
| 05-06-T2 | 05-06 | 3 | CI-01 | T-05-06-02 | The report formatter's fast self-test validates current-result, inherited-baseline, and original exit-status reporting without running R CMD check. | reporting contract | [Exact task command](#05-06-t2) | Present | Fast formatter self-test passed locally; hosted step pending. |
| 05-06-T3 | 05-06 | 3 | CI-01 | T-05-06-02, T-05-06-03 | The separately named non-required baseline job reports current full-check results, preserves the original exit status/raw artifacts, and labels exact Phase 04 counts as inherited only. | package check | [Exact task command](#05-06-t3) | Present | Local full report verified (check exit 1); hosted release/current check pending. |
| 05-07-T1 | 05-07 | 4 | CI-01, PORT-01 | T-05-07-01 | The selected Matrix candidate passes all five oldrel-1 platform/build source-install and installed-solver rows; any failed provisional candidate has row-specific fallback evidence. | evidence validation | [Exact task command](#05-07-t1) | Pending 05-07 helper | Pending genuine hosted candidate artifacts and validator implementation. |
| 05-07-T2 | 05-07 | 4 | CI-01, PORT-01 | T-05-07-02 | DESCRIPTION and README match the evidence-validated Matrix floor/current interval, and the installed compatibility contract enforces the final floor. | metadata contract | [Exact task command](#05-07-t2) | Pending 05-07 helper | Pending validated floor evidence and final hosted metadata verification. |

### Exact automated task commands

These commands are copied verbatim from each final task, with XML entities decoded. Build/install and source-loading commands are recorded as the planned contracts. Execute them from disposable `/tmp` source copies with pre-created isolated libraries; installed `test_package()` equivalents select `.libPaths()` explicitly. This protects checkout native files and the user library. The outcome column distinguishes local evidence from hosted obligations.

#### 05-01-T1

```sh
rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && rtk Rscript --vanilla -e '.libPaths(c("/tmp/ge-modelr-lib", .libPaths())); library(GEModelR, lib.loc = "/tmp/ge-modelr-lib"); stopifnot(identical(normalizePath(find.package("GEModelR")), normalizePath("/tmp/ge-modelr-lib/GEModelR"))); testthat::test_package("GEModelR", filter = "native-portability", reporter = "summary")'
```

#### 05-01-T2

```sh
rtk git diff --check && rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && rtk Rscript --vanilla -e '.libPaths(c("/tmp/ge-modelr-lib", .libPaths())); library(GEModelR, lib.loc = "/tmp/ge-modelr-lib"); stopifnot(identical(normalizePath(find.package("GEModelR")), normalizePath("/tmp/ge-modelr-lib/GEModelR"))); testthat::test_package("GEModelR", filter = "native-portability", reporter = "summary")'
```

#### 05-02-T1

```sh
rtk Rscript --vanilla -e 'testthat::test_local(filter = "suite-sparse-unsupported|public-solver-contract|sparse-core", reporter = "summary")'
```

#### 05-02-T2

```sh
rtk Rscript --vanilla -e 'testthat::test_local(filter = "api-documentation|suite-sparse-unsupported", reporter = "summary")' && rtk rg -n 'SuiteSparse.*unavailable|recognized.*SuiteSparse|backend[[:space:]]*=[[:space:]]*"Matrix"' README.md
```

#### 05-03-T1

```sh
GEModelR_EXPECT_OPENMP=required rtk Rscript --vanilla -e 'testthat::test_local(filter = "sparse-schur-openmp|public-cpp-backend", reporter = "summary")'
```

#### 05-03-T2

```sh
GEModelR_EXPECT_OPENMP=forbidden rtk Rscript --vanilla -e 'testthat::test_local(filter = "public-cpp-backend|sparse-schur-openmp", reporter = "summary")'
```

#### 05-04-T1

```sh
rtk Rscript --vanilla -e 'testthat::test_local(filter = "matrix-compatibility", reporter = "summary")'
```

#### 05-04-T2

```sh
rtk Rscript --vanilla tools/ci/install-matrix-source.R --dry-run https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_1.6-5.tar.gz 1.6-5 /tmp/ge-modelr-matrix-floor
```

#### 05-05-T1

```sh
rtk git diff --check && rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && rtk Rscript --vanilla -e '.libPaths(c("/tmp/ge-modelr-lib", .libPaths())); library(GEModelR, lib.loc = "/tmp/ge-modelr-lib"); stopifnot(identical(normalizePath(find.package("GEModelR")), normalizePath("/tmp/ge-modelr-lib/GEModelR"))); testthat::test_package("GEModelR", filter = "native-portability|suite-sparse-unsupported|sparse-schur-openmp|public-cpp-backend", reporter = "summary")'
```

#### 05-05-T2

```sh
rtk R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-lib . && GEModelR_EXPECT_OPENMP=forbidden GEModelR_EXPECT_MATRIX_VERSION=installed R_LIBS=/tmp/ge-modelr-lib rtk Rscript --vanilla tools/ci/run-installed-core-tests.R
```

#### 05-06-T1

```sh
rtk git diff --check && rtk Rscript --vanilla -e 'testthat::test_local(filter = "matrix-compatibility|native-portability|suite-sparse-unsupported", reporter = "summary")'
```

#### 05-06-T2

```sh
rtk Rscript --vanilla tools/ci/summarize-r-cmd-check.R --self-test
```

#### 05-06-T3

```sh
rtk Rscript --vanilla tools/ci/summarize-r-cmd-check.R --run
```

#### 05-07-T1

```sh
rtk Rscript --vanilla tools/ci/verify-matrix-floor-evidence.R --input .planning/phases/05-portable-native-build-and-ci/matrix-candidate-evidence.csv --output .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE.md
```

#### 05-07-T2

```sh
rtk git diff --check && rtk Rscript --vanilla tools/ci/verify-matrix-floor-evidence.R --verify-final-metadata --evidence .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE.md
```

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

**Approval:** pending — genuine hosted compatibility artifacts, the representative hosted report, and 05-07 evidence/finalization remain outstanding.

## Execution evidence and outstanding hosted checks

- 2026-10-04: CRAN's official `src/contrib/PACKAGES.gz` identifies Matrix 1.7-6 as the current ordinary source endpoint (R >= 4.4); its exact source URL responds successfully. Matrix 1.6-5 remains provisional.
- 05-06-T1: YAML inspection confirms 30 unique tuples: 18 serial and 12 OpenMP, including five explicit oldrel-1/1.6-5 rows. The row recorder was exercised with synthetic success and failure outcomes in `/tmp`; these contract-only rows are not hosted evidence. The equivalent installed focused tests outside the checkout passed 57 assertions without skips.
- 05-06-T2: `rtk Rscript --vanilla tools/ci/summarize-r-cmd-check.R --self-test` passes, including exact inherited baseline labels and original exit-status reporting; it runs no package check.
- 05-06-T3: Full local package check completed from `/tmp/gemodelr-05-06-full-check/source` with explicit `/tmp/gemodelr-05-06-full-check/library`, serial Makevars, R 4.3.0 and local Matrix 1.6-3. It recorded 1,876 passes, 3 failures, 164 skips, 1 ERROR, 0 WARNINGs and 3 NOTEs, and preserved/returned original exit status 1. The final formatter/parser reproduced those observed counts from the preserved check files. Complete raw logs, the source archive, status files, Markdown report and check directory remain in `/tmp/gemodelr-05-06-full-check`. This is local report-path evidence, not a hosted release/current-Matrix result.
- The three current failures are predecessor `suite_sparse_ordering` migration-message assertions at `tests/testthat/test-transactional-state.R:498`: the earlier Phase 05 SuiteSparse capability preflight masks that obsolete-option message. They are not attributed to the inherited Phase 04 baseline or the CI/report authoring. This out-of-scope discovery remains deferred to the parent executor. The 164 skips include explicitly source-only provenance/release/migration tooling excluded from the built archive. The differing packaged/serial result does not establish that Phase 04 findings were resolved.
- Hosted runs: the read-only repository Actions API returned no runs on 2026-10-04; local source was 319 commits ahead of origin/master before these authoring commits. No push, dispatch or other remote mutation was performed. The 30 hosted candidate outcomes and representative hosted summary/artifact remain pending. Combine authentic row CSVs from one reviewed run, preserving their exact nine-column header, into `matrix-candidate-evidence.csv` for 05-07; do not substitute local or synthetic rows.
- The hosted full-check command uses plain `Rscript`: RTK is the local output proxy, not a hosted runtime dependency. Local automated commands above preserve their exact `rtk` prefixes.
