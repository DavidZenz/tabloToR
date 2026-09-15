---
phase: 03-gemodelr-identity-migration
reviewed: 2026-09-15T15:28:05Z
depth: standard
files_reviewed: 81
files_reviewed_list:
  - benchmarks/benchmark_config.R
  - benchmarks/benchmark_gtap12a.R
  - benchmarks/benchmark_gtap12a_run.R
  - benchmarks/benchmark_schur_cpp.R
  - benchmarks/benchmark_sparse_lu_cpp.R
  - CONTRIBUTORS.md
  - DESCRIPTION
  - docs/provenance/ATTRIBUTION.md
  - docs/provenance/EXPECTED-KEYS.csv
  - docs/provenance/PROVENANCE.csv
  - docs/release/RELEASE-GATES.md
  - .gitignore
  - inst/benchmarks/benchmark_config.R
  - inst/benchmarks/check_benchmark_gate.R
  - inst/benchmarks/run_gtap12a_scaling.R
  - inst/benchmarks/run_gtap12a_sweep.R
  - inst/CITATION
  - inst/compatibility/GEModel-contract.csv
  - inst/compatibility/MANIFEST.md
  - inst/compatibility/SERIALIZATION.md
  - inst/cpp/sparse-elimination.cpp
  - inst/migration/benchmark-identity-map.dcf
  - inst/migration/historical-evidence.dcf
  - inst/migration/old-identity-allowlist.csv
  - inst/migration/option-replacements.dcf
  - inst/migration/predecessor-fingerprints.dcf
  - inst/tools/accept_phase02_baselines.R
  - inst/tools/refresh_phase02_baselines.R
  - man/GEModelR-package.Rd
  - MIGRATION.md
  - NAMESPACE
  - NEWS.md
  - .Rbuildignore
  - rcpp-solver-acceleration-plan.md
  - README.md
  - R/GEModel.R
  - R/identityMigration.R
  - R/main.R
  - R/modelSerialization.R
  - R/RcppExports.R
  - R/sparseElimination.R
  - R/sparseSchurComplement.R
  - R/sparseSolver.R
  - R/sparseSuiteSparse.R
  - R/zzzSparseSchurCpp.R
  - R/zzzzSparseSchurOpenMP.R
  - src/dense-schur.cpp
  - src/RcppExports.cpp
  - src/sparse-elimination.cpp
  - src/sparse-lu.cpp
  - src/sparse-schur.cpp
  - src/sparse-schur-openmp.cpp
  - src/tablo-sparse-lu.h
  - tests/testthat/fixtures/serialization/tabloToR-schema1-lineage.rds
  - tests/testthat/helper-compatibility.R
  - tests/testthat/helper-numerical-baseline.R
  - tests/testthat/helper-serialization.R
  - tests/testthat/helper-three-region.R
  - tests/testthat/helper-transactional-state.R
  - tests/testthat.R
  - tests/testthat/test-attribution-contract.R
  - tests/testthat/test-baseline-artifacts.R
  - tests/testthat/test-benchmark-harness.R
  - tests/testthat/test-identity-migration.R
  - tests/testthat/test-model-serialization.R
  - tests/testthat/test-numerical-baseline.R
  - tests/testthat/test-phase03-qualification-harness.R
  - tests/testthat/test-provenance-inventory.R
  - tests/testthat/test-public-cpp-backend.R
  - tests/testthat/test-public-solver-contract.R
  - tests/testthat/test-release-gates.R
  - tests/testthat/test-sparse-core.R
  - tests/testthat/test-sparse-lu-cpp.R
  - tests/testthat/test-sparse-schur-cpp.R
  - tests/testthat/test-sparse-schur-openmp.R
  - tests/testthat/test-transactional-state.R
  - tools/check_identity_migration.R
  - tools/check_predecessor_bridge.R
  - tools/check_release_gates.R
  - tools/provenance_inventory.R
  - tools/qualify_phase03_migration.R
findings:
  critical: 5
  warning: 1
  info: 0
  total: 6
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-09-15T15:28:05Z
**Depth:** standard
**Files Reviewed:** 81
**Status:** issues_found

## Summary

The migration is not ready to ship. Five blocking correctness defects undermine installed benchmark execution, benchmark correctness gating, serialization type safety, the Phase 2 qualification chain, and the tracked-source identity audit. The full test suite completed with eight failures/errors: three expose stale Phase 2 source-baseline expectations and five expose the stale old-identity inventory. Native registration names/arities and the public solver/backend tests were consistent.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Installed benchmark drivers invoke a child script that is not installed

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/inst/benchmarks/run_gtap12a_sweep.R:33-50`; `/home/zenz/R/tabloToR/inst/benchmarks/run_gtap12a_scaling.R:28-45`

**Issue:** Both installed-resource drivers resolve `benchmark_gtap12a_run.R` beside themselves and invoke it for every real run. That child exists only under `benchmarks/`; it is absent from `inst/benchmarks/`. Consequently, `system.file("benchmarks", ...)` can locate the packaged sweep/scaling entry points, but every invocation without `--summarize-only=true` fails because the child path does not exist. The tests only exercise summarize-only mode, so they do not cover the installed execution path.

**Fix:** Install the child beside the drivers and test the installed path in execution mode. For example, add `inst/benchmarks/benchmark_gtap12a_run.R` with byte-equivalent driver logic, include it in `benchmark_driver_names()`, and add a smoke test that invokes an installed driver without `--summarize-only` using deterministic fixture inputs.

### CR-02: Qualification labels the same migration check as two independent Phase 2 gates

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/tools/qualify_phase03_migration.R:611-615`; `/home/zenz/R/tabloToR/tools/qualify_phase03_migration.R:1029-1056`; `/home/zenz/R/tabloToR/inst/tools/refresh_phase02_baselines.R:1004-1025`

**Issue:** `phase02-original` and `phase02-migration` both call the same helper, which always passes `--check-migration-source`, and both assert the same migration-gate output. The refresh tool exposes distinct `--check` and `--check-migration-source` paths, but qualification never invokes the former or any equivalent independent original-artifact gate. This contradicts the Phase 03 plan's requirement to run every original read-only and migration-source gate, while producing two manifest stages that falsely appear independent. The omission is observable now: the working-tree suite reports three Phase 2 baseline failures, including source fingerprint drift from `f57c...` to `7d6d...`, yet this qualification stage cannot detect them.

**Fix:** Give each stage a genuinely distinct command and assertion. Invoke `--check` for the original read-only gate if it is expected to remain valid; if identity migration necessarily invalidates that mode, add a dedicated immutable-original-artifact check that verifies canonical artifact bytes/digests without recomputing migrated identity. Keep `--check-migration-source` only for the migration stage, and add a test proving that corrupting either gate can fail only its corresponding stage.

### CR-03: The committed old-identity allowlist is stale against the committed tree

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/inst/migration/old-identity-allowlist.csv:5`

**Issue:** The allowlist records the old `.planning/STATE.md` occurrence digest (`4e649...`) and omits the three migration-instruction occurrences now tracked in `03-12-SUMMARY.md`. Running `Rscript --vanilla tools/check_identity_migration.R --tracked-source` exits 1 with `UNEXPECTED_OLD_IDENTITY_MISSING`, and five identity-migration tests fail/error. Because the final summary was added after the recorded qualification, the checked-in evidence no longer describes the HEAD being reviewed.

**Fix:** Regenerate and review the occurrence inventory from the final committed tree, update the `STATE.md` digest to `b7636...`, and add the `03-12-SUMMARY.md` row (count 3, digest `40ddfc...`). Make the tracked-source audit the final post-summary gate so later evidence commits cannot silently invalidate qualification.

### CR-04: Serialization accepts logical arrays as numeric model state

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/R/modelSerialization.R:663-668`; `/home/zenz/R/tabloToR/R/modelSerialization.R:909-912`

**Issue:** Structural validation deliberately treats numeric and logical templates/values as interchangeable. After that check, sparse restoration installs `payload$levels` directly. A payload replacing numeric `stock = c(100, 200, 300)` with a same-shaped logical array loads successfully and restores `TRUE, TRUE, TRUE`; it is not rejected or converted. This violates the documented exact type/class contract and permits silent corruption of accepted model levels.

**Fix:** Require exact `typeof()` and `class()` for model-state leaves (or explicitly whitelist and perform a lossless integer-to-double conversion before installation). Add transactional tests for logical-for-double and integer-for-double payloads that assert an error and an unchanged receiver. For example:

```r
if (!identical(typeof(value), typeof(template)) ||
    !identical(class(value), class(template))) {
  .serialization_stop(sprintf(
    "%s type does not match the reconstructed model", path
  ))
}
```

### CR-05: Benchmark comparison passes when correctness artifacts are absent

**Classification:** BLOCKER

**File:** `/home/zenz/R/tabloToR/inst/benchmarks/check_benchmark_gate.R:46-71`; `/home/zenz/R/tabloToR/inst/benchmarks/check_benchmark_gate.R:87-92`

**Issue:** With no `.rds` solution files, `differences` remains empty, the maximum solution difference becomes `NA`, and the final predicate explicitly skips the solution threshold when the value is `NA`. A synthetic A/B input containing passing timing/RSS/residual CSV rows and no solution artifacts exits 0 and writes `max_abs_solution_difference = NA`. When artifacts do exist, they are paired by list order rather than a stable run/repetition key, so missing or reordered runs can also compare the wrong pair.

**Fix:** Fail closed unless both backends have non-empty, equal, uniquely keyed artifact sets. Join reference and candidate artifacts by an explicit run/repetition pairing key, verify matching signatures and dimensions, and require `is.finite(maximum_solution_difference)` before applying the tolerance.

## Warnings

### WR-01: Reviewed R CMD check NOTE allowlist is locale- and machine-specific

**Classification:** WARNING

**File:** `/home/zenz/R/tabloToR/tools/qualify_phase03_migration.R:344-357`

**Issue:** Qualification requires byte-identical NOTE text containing German diagnostics and hard-coded installed sizes (`8.9Mb`, `libs 7.9Mb`). The same archive checked under another locale, platform, compiler, or link configuration can produce semantically identical reviewed NOTES with different text or sizes and will be rejected. This makes the claimed portable qualification harness brittle and prevents reproducible cross-platform release checks.

**Fix:** Force and record a deterministic locale where possible, and normalize environment-dependent size/language fragments before comparison. Prefer matching reviewed NOTE categories plus stable normalized content, while continuing to reject any unexpected NOTE category.

---

_Reviewed: 2026-09-15T15:28:05Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
