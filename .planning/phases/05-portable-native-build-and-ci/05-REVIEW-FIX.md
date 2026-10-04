---
phase: 05-portable-native-build-and-ci
fixed_at: 2026-10-04T21:35:45Z
review_path: .planning/phases/05-portable-native-build-and-ci/05-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-10-04T21:35:45Z
**Source review:** `.planning/phases/05-portable-native-build-and-ci/05-REVIEW.md`
**Iteration:** 1

**Summary:** Two findings in scope, two fixed, zero skipped. These fixes and the successful local check do not establish hosted platform support or the final Matrix dependency floor.

## Fixed Issues

### CR-01: Ordinary serial package checks incorrectly require OpenMP

**Files modified:** `tests/testthat/helper-native-portability.R`, `tests/testthat/test-sparse-schur-openmp.R`, `tests/testthat/test-public-cpp-backend.R`
**Commit:** `4b9dbbe`
**Status:** fixed: requires human verification
**Applied fix:** Return measured capabilities for the permitted local NULL expectation. Skip the parallel-only comparison when an ordinary local build has no OpenMP; exercise the public serial default and unsupported-thread contract in that case. Preserve explicit required/forbidden assertions and reject missing expectations for either CI-library marker. Add a deterministic local serial helper regression assertion and ensure the capability test remains nonempty locally.

**Verification:** Modified sections were read and all three R files parsed successfully. Focused installed `public-cpp-backend` and `sparse-schur-openmp` groups passed with copied temporary installations and updated installed tests:

| Mode | Passes | Failures | Errors | Skips |
| --- | ---: | ---: | ---: | ---: |
| Ordinary serial, all CI/expectation/library markers unset | 103 | 0 | 0 | 1 |
| Explicit serial (`forbidden`) | 109 | 0 | 0 | 1 |
| OpenMP (`required`) | 80 | 0 | 0 | 0 |

The serial skips are solely the parallel-only comparison. Each invocation also passed seven negative guard checks: missing expectation under `CI`, `GITHUB_ACTIONS`, `GEModelR_TEST_LIBRARY`, or `GEModelR_CI_LIBRARY`; two invalid expectation values; and the wrong explicit expectation for the measured build. Script: `/tmp/gemodelr-reviewfix05-targeted.R`. Installed temporary copies: `/tmp/gemodelr-reviewfix05-targeted/serial` and `/tmp/gemodelr-reviewfix05-targeted/openmp`. Namespace paths were asserted before testing. The full ordinary serial package check below additionally exercises the freshly built package with all five CI/expectation/library markers unset.

### WR-01: Scheduled exact-version installs depend on a transient CRAN location

**Files modified:** `tools/ci/install-matrix-source.R`, `tools/ci/test-matrix-source-download.R` (new regression script)
**Commit:** `2ab0c28`
**Status:** fixed: requires human verification
**Applied fix:** Try the supplied URL first. Only an HTTP 404 at the official current source URL triggers one retry at the official Matrix Archive URL for the identical version. Remove any partial current download before retrying and log the URL that successfully supplied the source. Other failures, already archived inputs, and arbitrary hosts cannot trigger a fallback. Existing input validation, source-only archive validation, metadata/version checks, isolated-library checks, and exact installed-version verification remain in the install flow.

**Verification:** Modified sections were read and both R files parsed. `rtk proxy Rscript tools/ci/test-matrix-source-download.R` passed eleven deterministic mocked scenarios without network access or package installation: direct success; error-based 404 recovery and partial-file removal; no fallback for 403, 500, TLS failure, or timeout; no fallback from an Archive URL or arbitrary host; both official locations missing; status-based 404 recovery; and recovered source with a mismatched DESCRIPTION version rejected before target-library creation. Assertions verify the exact attempted URL sequence and actual-source log.

## Full Local Verification

After both atomic fixes, a fresh tracked-source copy excluded `.git`, `.planning`, `.gsd`, private runtime directories, and generated native objects/libraries. Serial compilation used a temporary Makevars file with `SHLIB_OPENMP_CXXFLAGS` empty. `R CMD check` used an explicitly created temporary library via `--library=...`; no build or install ran in the source checkout or user library.

All of `CI`, `GITHUB_ACTIONS`, `GEModelR_EXPECT_OPENMP`, `GEModelR_TEST_LIBRARY`, and `GEModelR_CI_LIBRARY` were unset throughout the check. R 4.3.0, Matrix 1.6.3, measured native `openmp=FALSE`, `max_threads=1L`.

**Result:** exit status **0**, **1,889 passes**, **0 failures**, **164 skips**, **0 ERROR**, **0 WARNING**, **3 NOTEs**. These ordinary-local counts differ from the earlier explicitly configured serial run because local capability measurements do not add required/forbidden CI assertions.

Artifacts retained separately at `/tmp/gemodelr-reviewfix05-ordinary-serial-check/`:

- `R-CMD-build.log`, `R-CMD-check.log`, `build-exit-status.txt`, `check-exit-status.txt`
- `job-summary.md`, `environment.txt`, source archive, `GEModelR.Rcheck/`
- Disposable source, explicit library, and serial Makevars

Check driver: `/tmp/gemodelr-reviewfix05-full-check.R`. Earlier Phase 05 check artifacts were preserved.

## Execution Context

The orchestrator authorized a temporary per-invocation `workflow.use_worktrees=false` opt-out to honor already negotiated sequential execution. All edits, syntax checks, and mocked-download checks ran in the main checkout; installed tests ran against disposable installation copies and the full package check ran entirely from its disposable source/library. No git worktree or temporary branch was created. No other agent edited the owned files during this invocation.

The exact pre-existing `.planning/config.json` bytes were saved to `/tmp/gemodelr-reviewfix05-config-original.json`, then restored and compared byte-for-byte after commits. Restored SHA256: `82f6914417d8d72357125cac248abd9f825077e3c7f25618f0d0cf5f049843a2`. Config was not committed; unrelated working-tree changes, existing native outputs, and the user library were preserved.

The per-finding status retains the fixer's required human-verification label for logic changes. Focused semantic regressions and the ordinary serial package check passed; hosted evidence and final phase verification remain pending.

---

_Fixed: 2026-10-04T21:35:45Z_
_Fixer: gsd-code-fixer_
_Iteration: 1_
