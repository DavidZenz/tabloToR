# Stack Research

**Domain:** Production R package for large-scale CGE/TABLO compilation and sparse solving
**Researched:** 2026-08-22
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version policy | Purpose | Why Recommended |
|------------|----------------|---------|-----------------|
| R | Establish minimum through CI; test release, oldrel, devel | Public API, compiler, model state | Preserves the existing user workflow and ecosystem compatibility |
| Matrix | Declare a tested minimum; test current CRAN | Sparse CSC matrices and LU | Current correctness reference and native factor contract |
| Rcpp | Tested CRAN minimum | Registered R/C++ boundary | Already implemented, portable, and familiar to R package tooling |
| C++ | R default standard unless a feature requires newer | Native sparse kernels | Avoids unnecessary compiler restrictions |
| BLAS/LAPACK | R-provided libraries | Dense regional/global factors | Portable through R's standard link macros |
| OpenMP | Optional, guarded by `_OPENMP` | Bounded regional parallelism | Useful on Linux/Windows but unavailable in default Apple clang |

### Supporting Tools

| Tool | Purpose | Recommendation |
|------|---------|----------------|
| testthat 3 | Deterministic unit and contract tests | Keep current suite and split oversized sparse-core coverage by subsystem |
| roxygen2 | `.Rd` generation and explicit namespace | Replace broad `exportPattern()` with deliberate exports |
| r-lib/actions v2 | Cross-platform `R CMD check` | Test Linux, macOS, Windows, R-devel/oldrel, and serial capability |
| pkgdown | API, architecture, migration, and benchmark documentation | Add after exported API is stabilized |
| R-universe | Pre-CRAN binary distribution and continuous builds | First public package channel after legal clearance |

## Build and Installation Pattern

- Compile all required native code during package installation; do not call `Rcpp::sourceCpp()` during ordinary use.
- Use registered native symbols and keep implementation wrappers private.
- Link `$(SHLIB_OPENMP_CXXFLAGS)` in compile and link flags, but ensure the same sources compile with it empty.
- Link LAPACK/BLAS through R-provided make variables.
- Treat SuiteSparse as optional until configure-time, cross-platform detection is designed; keep Matrix as the portable baseline.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| One GEModelR package | Separate solver package | Only after compiler/solver metadata has a stable public C++-independent contract |
| Matrix factor ownership | Direct UMFPACK/KLU | After portable configure checks and representative benchmarks justify maintenance cost |
| GitHub + R-universe first | Immediate CRAN submission | Only after legal provenance, zero-warning checks, and portable dependency policy are complete |
| Reference class compatibility | Immediate R6/S7 rewrite | In a future major version with a formal adapter/deprecation period |

## What Not to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Runtime C++ compilation | Toolchains may be absent; violates predictable package behavior | Compile `src/` during installation |
| Mandatory OpenMP | Default Apple clang lacks native support | Serial build with optional OpenMP acceleration |
| Broad namespace export patterns | Makes internals accidental API | Roxygen-managed explicit exports |
| Proprietary data in package tests | Redistribution and package-size risk | Synthetic fixtures plus external benchmark harnesses |

## Compatibility Gates

- Matrix sparseLU slot compatibility is checked at runtime and across CI Matrix versions.
- Native and R structured backends must pass solution/residual equivalence tests.
- OpenMP thread counts must produce equivalent outputs; CRAN checks use at most two threads.
- Serialization must not retain external pointers or native workspaces.

## Sources

- [Writing R Extensions](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html) — OpenMP portability, native registration, compiled-code practices.
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) — portability, dependencies, legal provenance, check limits.
- [r-lib/actions](https://r-lib.github.io/actions/) — current R package CI actions.
- [roxygen2 namespace guidance](https://roxygen2.r-lib.org/articles/namespace.html) — explicit export/import management.
- [R-universe publishing setup](https://docs.r-universe.dev/publish/set-up.html) — Git-based package distribution.

---
*Stack research for: GEModelR*
*Researched: 2026-08-22*
