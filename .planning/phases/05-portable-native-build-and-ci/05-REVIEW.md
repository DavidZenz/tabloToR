---
phase: 05-portable-native-build-and-ci
reviewed: 2026-10-05T07:56:36Z
depth: standard
files_reviewed: 29
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
  - .gitattributes
  - tools/ci/normalize-matrix-provenance.py
  - tools/ci/collect-matrix-catalog.py
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 05: Code Review Report

**Reviewed:** 2026-10-05T07:56:36Z
**Depth:** standard
**Files Reviewed:** 29
**Status:** clean

## Summary

All reviewed files meet quality standards within the stated scope. No active issues found.

This is a bounded final re-review of the CR-02 and CR-03 repairs and their necessary adjuncts. The preceding complete standard-depth analysis of the explicit 26-file scope against `8c684f5` is retained; unchanged package implementation and workflow files were not rereviewed from scratch. The scope now adds `.gitattributes`, the provenance normalizer, and the official catalog collector. The earlier findings and their evidence remain in Git history.

The authentic five oldrel-1 pairings continue to establish Matrix 1.6-5 as the floor, with current endpoint 1.7-6. No fallback was exercised for that floor. The known six source-install exclusions remain individually evidenced. The reported successful latest hosted metadata run does not replace the retained evidence used here; collecting and normalizing its final artifacts remains the orchestrator's continuation work.

No structural pre-pass was supplied. This reviewer modified only this report, performed no commits, package installations, builds, full package checks, remote mutations, or hosted execution, and preserved unrelated working-tree changes, native outputs, and libraries.

## Narrative Findings (AI reviewer)

No active BLOCKER or WARNING findings.

### Resolved findings

- **CR-02 — provenance binding:** Reviewed the strict JSON and artifact SHA256 collection path in `normalize-matrix-provenance.py` and the offline base-R validation path in `verify-matrix-floor-evidence.R`. Checked normalized DCF/CSV metadata binds the original manifest, table, exact artifact row payloads, job/step outcomes, and failed-source logs. Exclusion reasons now come from the retained checked logs. The former malformed-manifest reproduction is rejected.
- **CR-03 — complete eligible fallback history:** Reviewed the official archive/source DESCRIPTION collector and retained eight-release catalog, then followed catalog validation into floor selection. The validator derives eligibility from actual source R requirements and requires the complete eligible candidate prefix with all five pairings for each earlier rejection. The former skipped-release reproduction is rejected.
- **Earlier CR-01 and WR-01:** The previous local serial/OpenMP and exact-version CRAN relocation fixes remain resolved; these were unchanged by the evidence repairs.

### Verification and limits

Read `05-REVIEW-FIX.md`, both complete Python adjuncts, the changed R validator and regression probe script, normalized provenance samples, and the retained catalog metadata. The narrow `-text` attributes protect checksum-bound evidence against checkout newline conversion; the fixer also reports an 84-file byte-preserving export with `core.autocrlf=true`. That Windows conversion export was not repeated in this bounded re-review.

Ran:

```sh
rtk proxy Rscript --vanilla -e 'source("tools/ci/test-matrix-floor-evidence.R"); stopifnot(!"Matrix" %in% loadedNamespaces())' --expect-final-metadata
```

All **71 probes passed**, including malformed JSON, changed run/attempt/outcome/digest, changed normalized outcomes, changed or missing artifact payloads/logs, omitted or renumbered catalog/history entries, forged R requirements, and the former incomplete fallback prefix. Final DESCRIPTION/README metadata verification passed, and Matrix was not loaded. Mutation probes used disposable copies or in-memory synthetic rows; they did not alter retained evidence.

The offline gate relies on the checked normalization produced at collection, bound by exact local digests to retained original manifests and payloads. Coordinated replacement of all trusted provenance is outside this contract. A candidate beyond the retained catalog endpoint requires a fresh official snapshot; unsupported run attempts fail closed. This review does not independently rerun hosted jobs or assert compatibility for invalid R/Matrix/platform cross-products. Known inherited representative-check failures and pending final artifact collection are not introduced implementation findings.

---

_Reviewer: gsd-code-reviewer_
_Depth: standard_
