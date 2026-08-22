---
last_mapped: 2026-08-22
---

# Repository Structure

## Root Package Files

- `DESCRIPTION` declares package identity and dependencies but still contains placeholder authorship and license fields.
- `NAMESPACE` registers the native library and currently exports almost every alphabetic symbol with `exportPattern()`.
- `README.md` documents legacy, sparse, structured R, and experimental C++ workflows.
- `AGENTS.md` contains repository-specific contributor instructions and must be preserved.
- `rcpp-solver-acceleration-plan.md` records the completed native-acceleration design and acceptance gates.

## R Implementation

- `R/GEModel.R`: reference-class public API and legacy execution loop.
- `R/processTablo.R`, `R/tabloToStatements.R`, `R/process*Statement.R`: parser entry points and statement handlers.
- `R/*Generator.R`, `R/*Processing.R`, `R/helpers.R`: legacy code/data generation.
- `R/sparseCompiler.R`: sparse equation/update compilation.
- `R/sparseSolver.R`: core indexed runtime and generic backends.
- `R/sparsePartition.R`, `R/sparseElimination.R`, `R/sparseSchur*.R`: structured decomposition and R reference solver.
- `R/zzzSparseSchurCpp.R`, `R/zzzzSparseSchurOpenMP.R`, `R/zzzzzSchurDiagnostics.R`: load-order wrappers for optional native behavior and metrics.
- `R/RcppExports.R`: generated private native wrappers.

## Native Sources

- `src/tablo-sparse-lu.h`: shared Matrix sparse-factor views and triangular-solve helpers.
- `src/sparse-lu.cpp`: capabilities, multi-RHS solve, pattern hash.
- `src/sparse-schur.cpp`: serial fused Schur kernels.
- `src/sparse-schur-openmp.cpp`: bounded OpenMP regional batches.
- `src/dense-schur.cpp`: LAPACK regional/global factor handles.
- `src/sparse-elimination.cpp`: native exact block elimination/reconstruction.

## Validation Assets

- `tests/testthat/fixtures/`: small redistributable TABLO fixtures.
- `tests/testthat/helper-*.R`: synthetic model and native-kernel fixtures.
- `tests/testthat/test-*.R`: compiler, API, backend, cache, OpenMP, and benchmark-harness tests.
- `benchmarks/`: separate-process GTAP runs, A/B gates, parameter sweeps, and durable results.
- Hidden files under `benchmarks/` and experimental files such as `R/sparseKrylov.R` are user work and are not part of the supported package surface.
