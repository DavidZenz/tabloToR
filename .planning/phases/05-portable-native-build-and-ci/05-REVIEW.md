---
phase: 05-portable-native-build-and-ci
reviewed: 2026-10-04T21:27:01Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - .github/workflows/native-ci.yaml
  - R/apiDocumentation.R
  - R/sparseElimination.R
  - R/sparseSolver.R
  - R/sparseSuiteSparse.R
  - R/zzzSparseSchurCpp.R
  - README.md
  - man/GEModel.Rd
  - man/GEModelR-package.Rd
  - tests/testthat/helper-native-portability.R
  - tests/testthat/test-api-documentation.R
  - tests/testthat/test-matrix-compatibility.R
  - tests/testthat/test-native-portability.R
  - tests/testthat/test-public-cpp-backend.R
  - tests/testthat/test-sparse-core.R
  - tests/testthat/test-sparse-schur-openmp.R
  - tests/testthat/test-suite-sparse-unsupported.R
  - tools/ci/install-matrix-source.R
  - tools/ci/record-matrix-candidate.R
  - tools/ci/run-installed-core-tests.R
  - tools/ci/summarize-r-cmd-check.R
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-10-04T21:27:01Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Reviewed the explicitly submitted Phase 05 files against `8c684f5`, reading their complete contents and following the installed native wrappers, backend preflight, test helpers, dependency installation, candidate reporting, and representative package-check flow. Findings concern a reproduced serial-build test failure and the lifetime of the pinned CRAN source URL used by scheduled jobs.

This is a preparatory source review before hosted execution. The thirty provisional hosted rows, their downloaded artifacts, and Plan 05-07 floor validation/final metadata remain deliberately pending. Their absence is not a finding, and this report makes no Matrix floor or hosted platform support claim. The supplied successful local full-check result used explicit serial expectations; it does not exercise the missing-expectation defect below.

No structural pre-pass was supplied. Existing native artifacts, temporary installations, user libraries, unrelated working-tree changes, and source files were preserved. One focused reproduction used the existing disposable serial installation and an unrelated temporary working directory; no package installation or full check was performed by this reviewer.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Ordinary serial package checks incorrectly require OpenMP

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/tests/testthat/helper-native-portability.R:19-24`

**Affected callers:** `/home/zenz/R/tabloToR/tests/testthat/test-sparse-schur-openmp.R:13-21`, `/home/zenz/R/tabloToR/tests/testthat/test-sparse-schur-openmp.R:47-50`, and `/home/zenz/R/tabloToR/tests/testthat/test-public-cpp-backend.R:148-151`.

**Issue:** `nativeOpenmpExpectation()` intentionally returns `NULL` when an ordinary local test run has no expectation and is not in CI. `nativeOpenmpCapabilities()` nevertheless sends that `NULL` through its `else` branch, asserting `openmp = TRUE` and at least two native threads. The parallel comparison skips only for the literal `"forbidden"`, so the same local serial run subsequently calls the unavailable two-thread kernel. Supported serial installations therefore fail their package tests unless the caller supplies a bespoke CI expectation. The new serial public-backend test also fails its helper assertions and returns before exercising the local serial contract. This is a test-reliability defect, not a numerical mismatch.

**Evidence:** Reproduced using the existing serial installation at `/tmp/gemodelr-05-05-od9s1kub/library`, which reports `openmp = FALSE` and `max_threads = 1L`. Unsetting all CI/expectation/library markers and running the installed `sparse-schur-openmp` group produced four failed assertions and one error: `Parallel Schur accumulation is unavailable in this build`.

```r
Sys.unsetenv(c(
  "CI", "GITHUB_ACTIONS", "GEModelR_EXPECT_OPENMP",
  "GEModelR_CI_LIBRARY", "GEModelR_TEST_LIBRARY"
))
lib = "/tmp/gemodelr-05-05-od9s1kub/library"
.libPaths(c(lib, .libPaths()))
library(GEModelR, lib.loc = lib)
setwd(tempdir())
testthat::test_package(
  "GEModelR", filter = "^sparse-schur-openmp$",
  reporter = "summary", stop_on_failure = FALSE
)
```

**Fix:** Preserve the existing missing/invalid expectation rejection in CI and explicitly selected CI-library runs. For the permitted local `NULL` expectation, return measured capabilities without asserting an OpenMP build; skip only the parallel-only comparison when that local capability is absent. Run the serial default/over-request contract locally when measured capability is serial. Required CI jobs must still fail on absent OpenMP, and forbidden jobs must still assert a serial DLL before their sole allowed parallel-test skip. For example, add this handling to the helper before its required/forbidden assertions:

```r
if (is.null(expectation)) return(capabilities)
```

Then use this additional local-only guard in the parallel comparison after capability validation:

```r
if (is.null(expectation) && !isTRUE(capabilities$openmp)) {
  skip("Local serial build has no OpenMP-only execution")
}
```

## Warnings

### WR-01: Scheduled exact-version installs depend on a transient CRAN location

**Classification:** WARNING

**File:** `/home/zenz/R/tabloToR/tools/ci/install-matrix-source.R:108-111`

**Affected configuration:** `/home/zenz/R/tabloToR/.github/workflows/native-ci.yaml:29-33`, the remaining `candidate: current` rows, and `/home/zenz/R/tabloToR/.github/workflows/native-ci.yaml:197-199`.

**Issue:** The workflow pins the current snapshot to `Matrix_1.7-6.tar.gz` in CRAN's `src/contrib` location, while its PR, push, and weekly events reuse that literal URL. There is no per-run endpoint refresh. The installer makes only one `download.file()` call. When a newer Matrix release supersedes this snapshot, the pinned source remains obtainable from CRAN Archive but its original current-package URL can return HTTP 404. All fifteen current candidate jobs then fail before GEModelR installation and installed solver testing; the representative job fails before its informational full-check step as well. This is an avoidable dependency-location failure rather than evidence that those R/Matrix combinations are incompatible. Earlier Matrix releases are retained in the official [Matrix source archive](https://cran.r-project.org/src/contrib/Archive/Matrix/).

**Evidence:** The current rows and representative job contain literal `src/contrib/Matrix_1.7-6.tar.gz` inputs. `matrixSourceInstall()` has no recovery path before a download error reaches its CLI error handler. Matrix URL validation already admits both the current location and `Archive/Matrix/` for exactly the same version, so location recovery can retain the existing source/version contract. This review does not assert that the current URL has already disappeared; the trigger is a routine subsequent CRAN release while scheduled runs or reruns still use this pinned workflow.

**Fix:** Try the supplied official exact-version source URL first. If that current-package location is missing, retry only its canonical `https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_<same-version>.tar.gz` location, record the actual URL, and apply the existing source-content, DESCRIPTION, installed-version, and isolated-library checks. Never substitute another version, a binary, or an ambient installation. Keep any deliberate endpoint-version refresh explicit and ensure recorded expectations/evidence use that same resolved version.

---

_Reviewed: 2026-10-04T21:27:01Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
