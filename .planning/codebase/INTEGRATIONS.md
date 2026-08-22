---
last_mapped: 2026-08-22
---

# External Integrations

## Model and Data Inputs

- `GEModel$loadTablo()` consumes GEMPACK-style TABLO source files through `R/tabloToStatements.R`, `R/processTablo.R`, and statement-specific processors.
- `GEModel$loadData()` consumes named R lists representing HAR datasets; users normally create these objects with `HARr::read_har()` as shown in `README.md`.
- GTAP benchmark scripts expect sets, base data, parameters, a TABLO file, a closure RDS, and optionally shock data supplied outside the repository.
- Proprietary GTAP data and full solution artifacts are intentionally not committed.

## Numerical Libraries

- The default sparse backend delegates factorization and solves to `Matrix`.
- `SparseM` remains an explicitly selected comparison/compatibility backend.
- `R/sparseSuiteSparse.R` provides an optional Linux-specific UMFPACK integration using system SuiteSparse headers and libraries.
- Native structured solving reuses Matrix sparse factors, invokes LAPACK for dense regional/global factors, and optionally uses OpenMP.
- No database is used in the numerical path; DuckDB was evaluated as data staging rather than a solver dependency.

## Native Boundary

- Native symbols are registered in `src/RcppExports.cpp` and loaded with `useDynLib(tabloToR, .registration=TRUE)` from `NAMESPACE`.
- `R/zzzSparseSchurCpp.R` performs ABI, symbol, Matrix-contract, LAPACK, and OpenMP capability checks before native execution.
- An explicit `StructuredSchurFGMRESCpp` request fails closed; it does not silently substitute an R backend.
- Native factor pointers are released after solving and excluded from serialized model state.

## Development and Distribution

- Installation uses standard R package tooling (`R CMD build`, `R CMD INSTALL`, `R CMD check`).
- The README still points installation at the original upstream repository and package name.
- No GitHub Actions, R-universe configuration, pkgdown site, DOI/archive integration, or CRAN release automation exists.
- `DESCRIPTION` lacks valid author, maintainer, URL, bug tracker, and license metadata, which blocks responsible redistribution as GEModelR.
