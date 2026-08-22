---
last_mapped: 2026-08-22
---

# Technology Stack

## Package Runtime

- The project is an R package named `tabloToR`, currently version `0.1.0`; package metadata lives in `DESCRIPTION`.
- Public R code is under `R/`; the primary API is the `methods::setRefClass` object `GEModel` in `R/GEModel.R`.
- Sparse matrices use the `Matrix` package. `SparseM` is retained as a compatibility backend.
- Native acceleration uses Rcpp and compiled C++ under `src/`.
- Tests use testthat edition 3 through `tests/testthat.R` and `tests/testthat/`.

## Native Toolchain

- `src/Makevars` and `src/Makevars.win` link OpenMP, LAPACK, BLAS, and Fortran runtime flags supplied by R.
- `src/sparse-lu.cpp` implements native sparse-LU triangular solves and structural hashing against Matrix's `sparseLU` representation.
- `src/sparse-schur.cpp` and `src/sparse-schur-openmp.cpp` implement serial and bounded-parallel Schur accumulation.
- `src/dense-schur.cpp` owns LAPACK LU factors through finalizable external pointers.
- `src/RcppExports.cpp` and `R/RcppExports.R` contain generated registered wrappers.

## Dependencies

- Imports: `Matrix`, `Rcpp`, `SparseM`, `methods`.
- LinkingTo: `Rcpp`.
- Suggested test dependency: `testthat`.
- HAR input is read by callers with `HARr::read_har()`; HARr is currently documented and benchmarked but absent from `DESCRIPTION`.
- The optional SuiteSparse path in `R/sparseSuiteSparse.R` assumes Linux headers/libraries and compiles UMFPACK code at runtime with `Rcpp::sourceCpp()`.

## Configuration

- Solver controls are R options prefixed `tabloToR.sparse.*`, including LU ordering, residual tolerance, panel size, batch size, FGMRES controls, and native thread count.
- Runtime memory limits are configured through `GEModel$setMemoryBudget()` or `solveModel(memory_budget=)`.
- No CI workflow, formatter, linter, or coverage service is currently checked in.
