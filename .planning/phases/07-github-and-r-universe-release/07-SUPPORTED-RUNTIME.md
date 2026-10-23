---
phase: 07-github-and-r-universe-release
recorded: 2026-10-23T13:04:28Z
status: qualification_failed
runtime_status: supported
matrix_version: 1.6-5
shared_matrix_version: 1.6-3
archive_build: passed
archive_scan: passed
archive_check: failed
independent_installed_smoke: passed
publication_authorized: false
---

# Supported Matrix runtime and actual archive qualification

The maintainer selected “Set up an isolated supported Matrix library and run qualification” after resuming the Phase 07 checkpoint. This authorizes the isolated installation and local checks; the existing keep-local direction remains active. Phase 06 acceptance is unchanged.

## Runtime

Matrix 1.6-5 was downloaded from the exact [official CRAN archive](https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_1.6-5.tar.gz) and compiled with the repository's `tools/ci/install-matrix-source.R` under R 4.3.0 on x86_64 Debian 10. `MAKEFLAGS=-j2` bounded compilation. The helper validated the source metadata, installed package version, and loaded namespace path.

- Release library: `/tmp/GEModelR-release-runtime-PVoXZ7/library`.
- Matrix namespace: `/tmp/GEModelR-release-runtime-PVoXZ7/library/Matrix`; version reported by R is `1.6.5`.
- Shared user-library Matrix remains `1.6.3`; no shared package was installed or upgraded.
- Existing Rcpp, SparseM, and suggested dependencies were available through read-only fallback library paths. The isolated Matrix library was first in `R_LIBS`; qualification selected it explicitly.
- Raw setup logs: `/tmp/GEModelR-release-runtime-PVoXZ7/logs/matrix-install.log` and `runtime-verification.log`.

The library and evidence are temporary local files. If removed by system cleanup, rebuild the runtime and create a new qualification packet; do not treat a missing temporary artifact as retained evidence.

## Exact candidate and archive

A new packet was prepared from the same explicitly selected committed source; earlier frozen packets were not modified. No unrelated working-tree edits were included.

| Identity | Value |
|----------|-------|
| Packet | `/tmp/GEModelR-release-runtime-PVoXZ7/packet` |
| Development source commit | `e46ea70e737bc709880458ab1548244a2fd525cd` |
| Public source/archive commit | `ee8f5d26c9565db3407567e065633a0b0252da9a` |
| Public source tree | `cb74d2a4000c3d84ae005d05c63769597988d24a` |
| Archive | `public/GEModelR_0.1.0.tar.gz` (305500 bytes) |
| Archive SHA-256 | `6e67efd755634735a67bf8fb9cfcf3b95421694f9709d2e3418d8b61e9c1b317` |
| Review-content digest | `3af1f9e1531fb4f1bbd4b928b2c4142d4937135acccf411501316d23aa8a4ba5` |
| Private manifest file SHA-256 | `47b9f90590eafc97e690844f62552bfcf2e8bfa93133a4e115c015077486a7e6` |
| Public manifest file SHA-256 | `47cec1df5139c4aa192df924407084dd7eabed772d902bebc9b63075826ba8c0` |

Local packet verification passed after qualification and the separate installed smoke. `verify --for-publication` still returns exit 1, `PUBLICATION_NOT_READY`.

## Actual checks

| Check | Result |
|-------|--------|
| Runtime probe | Supported, Matrix 1.6-5 |
| Package build and vignette rendering | Passed; exact retained archive built from the verified public commit |
| Archive public-content scan | Passed; 194 archive entries scanned |
| Archive installation inside `R CMD check` | Passed; selected package loads/unloads, native compilation checks pass |
| `R CMD check --as-cran` | **1 ERROR, 2 WARNINGs, 7 NOTEs** |
| Testthat results | **3036 pass, 10 fail, 102 skip**, zero testthat warnings |
| Vignette rebuild, PDF manual | Passed |
| Pipeline's later install/smoke and dedicated URL steps | Not run because the archive check failed; original packet statuses retained |
| Separate fresh-process installed smoke | Passed against the package installed by the archive check, Matrix 1.6-5, expected finite solution `c(0, 6, 0)` within `1e-12` |
| Offline canonical release guard | Invalid, exit 1, `PROVENANCE_KEY_MISMATCH` |
| GitHub/R-universe installation and publication | Not run |

The independent smoke used the exact package already installed by `R CMD check` at `packet/private/work/library/GEModelR`; it did not load the development namespace. The runner checked that namespace's path and reported `PASS installed-release-smoke`. Its recorded source basis remains `caller_attested_source`; the surrounding archive/check records bind this local installed copy to the retained archive. This separate diagnostic pass does not override the failed archive check or change the frozen packet's gated `installed_smoke=not_run`.

## Ten observed test errors

- Four cases in `test-baseline-artifacts.R` (lines 106, 125, 425, 445) cannot locate installed baseline tools: `.Rbuildignore` excludes `inst/tools`, so `system.file()` yields an empty path and `normalizePath(..., mustWork=TRUE)` fails.
- Five cases in `test-gtap12a-reference-preflight.R` (lines 175, 205, 219, 236, 257) attempt to source missing `../../benchmarks/preflight_gtap12a_reference.R` from the built-package test context. The benchmark script is present in the source archive and public-source policy; the relative test lookup assumes a development-tree layout that is absent in the installed test context.
- One case in `test-model-serialization.R` (line 713) tries to replace the installed namespace's locked `.serialization_object_fingerprint` binding with `assign()`.

These are observed on the selected frozen distribution and are not proof of a new numerical regression caused by the runtime installation. No package source or tests were changed in this task. Repairs need to preserve meaningful source/installed coverage and the public-source boundary, rather than suppressing assertions merely to obtain a pass.

## Warnings and notes

The two warnings are missing `qpdf` for PDF size checks and undeclared `withr::`/`withr:::` use in tests. The seven notes cover CRAN incoming/new-submission information and four unpublished canonical URLs returning 404; installed library size (9.3 MB, 8.1 MB native library); inability to verify current time; Author versus Authors@R text; top-level files/external pandoc discovery; `class(expr) == "name"`; and missing HTML `tidy`. Consult the raw log for exact wording. `rmarkdown::pandoc_available()` was true in the initial process, while the check reported that it could not discover the external pandoc command for README/NEWS checks; those observations are retained separately.

The build also warned that the retained serialized predecessor fixture requires R >=3.5.0 and added that dependency to the built archive. This did not prevent building or installing under R 4.3.0.

## Evidence and reproduction

All raw outputs remain external under `packet/private/evidence/` and `packet/private/work/check/GEModelR.Rcheck/`. The complete test failure report is `tests/testthat.Rout.fail`; the check summary is `00check.log`. The separate smoke log is `/tmp/GEModelR-release-runtime-PVoXZ7/logs/independent-installed-smoke.log`.

Use the existing installer with the exact CRAN URL, version `1.6-5`, and a fresh empty isolated library. Prepare a new packet from the selected commit, stage its public source, then run `qualify --library <isolated-library>` with the isolated library first in `R_LIBS` and the existing dependency libraries as read-only fallbacks. A packet accepts one qualification attempt; never rewrite the retained result. No GTAP or R baseline benchmark was rerun, and no hosted action, tag, push, publication, or canonical provenance change occurred.
