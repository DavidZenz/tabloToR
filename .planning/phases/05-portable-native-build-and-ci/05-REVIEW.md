---
phase: 05-portable-native-build-and-ci
reviewed: 2026-10-05T07:30:12Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - .github/workflows/native-ci.yaml
  - DESCRIPTION
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
  - tools/ci/resolve-matrix-current.R
  - tools/ci/run-installed-core-tests.R
  - tools/ci/summarize-r-cmd-check.R
  - tools/ci/test-matrix-floor-evidence.R
  - tools/ci/test-matrix-source-download.R
  - tools/ci/verify-matrix-floor-evidence.R
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-10-05T07:30:12Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

Reviewed the explicit 26-file scope against `8c684f5`, including runtime dispatch, installed tests, exact source installation, the shared per-run endpoint resolver, workflow reporting, floor selection, and final metadata verification. Two reproduced validator defects remain: provenance manifests are only checked for existence, and fallback history can omit an eligible earlier release.

The authentic five oldrel-1 pairings for Matrix 1.6-5 establish the current floor. These findings do not invalidate those passing outcomes or the genuine six source-install exclusions in the candidate run. The fallback defect applies if the provisional floor fails and a successor is selected. Pending artifacts for the latest metadata CI run are not an implementation finding. Informational representative-check failures identified as inherited are outside the introduced-defect scope.

The previous local serial/OpenMP finding and same-version CRAN relocation warning were repaired in `4b9dbbe` and `2ab0c28`; neither remains active. The current workflow resolves the current endpoint once per run and shares its exact version and URL. Local serial capability handling preserves strict explicit CI expectations.

No structural pre-pass was supplied. Complete file reads from the earlier review were retained for unchanged scoped files; newly added and changed files were read in this review, with cross-file contract tracing. Bounded R probes used copied evidence in temporary storage or in-memory data frames. Official CRAN release metadata was consulted read-only. No package installation, full package check, hosted execution, source change, or commit was performed by this reviewer. Existing native outputs, libraries, and unrelated working-tree changes were preserved.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-02: Floor and metadata validation never inspect retained provenance manifests

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/tools/ci/verify-matrix-floor-evidence.R:141-155`

**Affected flow:** `matrixFloorRecord()` and `verifyMatrixFinalMetadata()` at lines 200-202; exclusion reporting at line 185.

**Issue:** The provenance gate requires a JSON manifest to exist but never reads it. It compares the submitted CSV only with another retained CSV. A malformed manifest, mismatched run/attempt, inconsistent job outcomes, or artifact CSV digest mismatch therefore cannot cause rejection. The fast metadata verifier regenerates the record through this same gate, so it also accepts this missing provenance validation. The retained manifests already contain run, job, artifact, and file-hash information, but none of that binds the accepted rows to their recorded hosted outcomes. In addition, every accepted source failure is labeled `OBJECT undeclared` without checking the retained failure reason.

**Evidence:** Copied the genuine candidate CSV and the two retained run CSVs into a temporary directory, replaced both required manifest files with the literal non-JSON text `invalid JSON; no run/job/artifact metadata`, and called `matrixFloorRecord(input, supported)`. It succeeded and returned `Selected floor: 1.6-5`. No original evidence file was changed. This proves that manifest contents are outside the validation gate; it does not imply the actual retained manifests or current floor are false.

**Fix:** Keep the validator offline and usable with base R, without consulting installed Matrix. Parse a checked provenance representation, or retain normalized DCF/CSV provenance alongside the JSON. Require valid matching run/attempt metadata; bind each accepted tuple/version/outcome to its retained job and artifact; verify the artifact CSV digest and compare the accepted row against its retained payload. Record and validate exclusion reasons tied to that source artifact before emitting a specific compiler-error claim. Reject malformed or mismatched manifests and digests. This requires consistency with the retained provenance, not an impossible guarantee against coordinated replacement of all trusted local files.

### CR-03: Fallback selection can skip eligible earlier releases and claim the oldest passing floor

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/tools/ci/verify-matrix-floor-evidence.R:46-66`

**Affected flow:** Candidate iteration and early acceptance at lines 69-77; fallback record claim at line 182.

**Issue:** The validator derives its candidate list entirely from supplied test rows. Its history then only has to repeat that same list, assert eligibility, and number those entries consecutively. Nothing checks that the list includes every official eligible Matrix release between 1.6-5 and the selected successor, or that the supplied R requirements came from the actual source descriptions. Dropping an intervening candidate and renumbering the remaining history therefore passes. The resulting record claims ascending eligible rejection history even though an earlier eligible release was never tried, contradicting the promised oldest eligible passing floor.

**Evidence:** Starting with copies of the genuine candidate rows, changed one minimum oldrel-1 solver outcome to failure and relabeled the genuine current 1.7-6 rows as fallback. Supplied a two-entry history containing only 1.6-5 and 1.7-6, with canonical archive URLs, R requirements 3.5 and 4.4, and release orders 1 and 2. `selectMatrixFloor()` accepted it, selected 1.7-6, and recorded only 1.6-5 as rejected. These were in-memory changes, not modifications to retained evidence.

At least Matrix 1.7-0 is an actual omitted eligible release: the [official CRAN archive](https://cran.r-project.org/src/contrib/Archive/Matrix/) lists it after 1.6-5, and its [archived source DESCRIPTION](https://raw.githubusercontent.com/cran/Matrix/1.7-0/DESCRIPTION) requires R >= 4.4.0, which the recorded oldrel-1 R 4.5.3 satisfies. No assumption that a release named 1.6-6 exists is needed to establish this gap.

**Fix:** At evidence collection, retain an authoritative ordered CRAN release catalog and source DESCRIPTION R requirements, together with provenance for that snapshot. The offline base-R validator should derive eligibility for the recorded oldrel-1 R from that catalog and require a complete prefix of eligible releases through the selected floor. Every earlier eligible candidate must have the five required rejecting outcomes; reject omissions, nonexistent versions, or unsupported eligibility assertions. Keep exact version/source URLs and the prohibition on binary or version substitution. The final metadata check should consume this retained evidence without loading ambient Matrix.

---

_Reviewer: gsd-code-reviewer_
_Depth: standard_
