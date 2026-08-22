---
last_mapped: 2026-08-22
---

# Testing and Verification

## Automated Tests

- The package uses testthat edition 3, configured in `DESCRIPTION` and launched by `tests/testthat.R`.
- `tests/testthat/test-sparse-core.R` covers compilation, implicit exogenous zeros, sparse RHS/triplets, reduction, closures, memory budgets, updates, Euler streaming, postsimulation, backend equivalence, partitions, and residuals.
- `tests/testthat/test-public-solver-contract.R` protects default behavior and fail-closed native preflight.
- `tests/testthat/test-public-cpp-backend.R` compares the opt-in C++ backend with the R reference solver.
- Native unit tests cover Matrix sparseLU compatibility, Schur block equality, OpenMP equality, cache invalidation, pointer serialization, and benchmark schema/gates.
- Small TABLO fixtures live under `tests/testthat/fixtures/`; synthetic systems avoid proprietary HAR files.

## Standard Commands

- `R CMD build .` creates a source archive.
- `R CMD INSTALL .` compiles native code and installs the package.
- `R CMD check --no-manual .` validates package structure, compiled code, tests, and examples.
- `Rscript benchmarks/benchmark_sparse_lu_cpp.R` gates native multi-RHS correctness/performance.
- `Rscript benchmarks/benchmark_schur_cpp.R` compares fused R and C++ Schur construction.

## Full-Scale Verification

- `benchmarks/run_gtap12a_ab.R` runs fresh-process R/native comparisons with package/model signatures.
- `benchmarks/run_gtap12a_sweep.R` validates panel and regional-batch choices.
- `benchmarks/run_gtap12a_scaling.R` validates 1/2/4/8-thread equality and speedup.
- `benchmarks/GTAP12A_CPP_RESULTS.md` records the validated 163-region × 65-commodity outcome: 3.99× faster, 25.34 GiB peak RSS, and residual `9.014e-8`.
- Benchmark inputs and solution artifacts remain local and are fingerprinted to prevent invalid comparisons.

## Quality Gates and Gaps

- Sparse/C++ equivalence tolerances are generally `1e-8` for synthetic systems; the ill-conditioned full GTAP guard is `2e-7`.
- Explicit dense-full-system fallback detection is part of diagnostics and benchmark gates.
- There is no formal coverage percentage target or hosted CI matrix.
- The current `R CMD check` baseline has package-documentation/metadata notes that productization must eliminate before release.
