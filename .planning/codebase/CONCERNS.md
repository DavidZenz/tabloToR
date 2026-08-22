---
last_mapped: 2026-08-22
---

# Technical Concerns

## Release Blockers

- `DESCRIPTION` contains placeholder author, maintainer, and license values. Upstream licensing must be established before redistribution or a renamed public release.
- The package is still named `tabloToR` in R code, native symbols, benchmark signatures, README examples, and generated wrappers; renaming requires a coordinated migration.
- `NAMESPACE` uses `exportPattern("^[[:alpha:]]+")`, exposing many implementation details and making API stability difficult.
- There are no generated manual pages, package-level API documentation, NEWS, lifecycle policy, or semantic-versioning contract.

## Portability

- `R/sparseSuiteSparse.R` checks fixed Debian/Ubuntu paths and compiles UMFPACK code at runtime, which is unsuitable for a polished cross-platform package.
- OpenMP availability varies by compiler and operating system; serial builds must remain supported and tested.
- Native code relies on Matrix's `sparseLU` slot contract, protected by runtime ABI/self-tests but still sensitive to Matrix changes.
- CI does not yet exercise Linux, macOS, Windows, or OpenMP-disabled builds.

## Architecture Debt

- `R/GEModel.R` combines public orchestration with the dense legacy implementation and extensive `eval(parse())` updates.
- `R/sparseSolver.R` is over 2,000 lines and combines expression evaluation, matrix emission, memory estimation, solving, stepping, diagnostics, and output reconstruction.
- The C++ backend is installed through late load-order function wrapping in `R/zzzSparseSchurCpp.R`; this works but obscures backend registration and ownership.
- Mutable `setRefClass` fields expose internals broadly and complicate lifecycle guarantees.
- A three-element `steps` vector only extrapolates the last two levels; behavior is legacy-compatible but not full multi-level Richardson.

## Scope and Maintenance Risks

- Structured partition logic is GTAP-specific and should be clearly separated from generic TABLO compilation/Matrix solving.
- Full-scale correctness depends on external proprietary data, so public CI can only run reduced/synthetic fixtures.
- HARr is operationally required by documented workflows but not declared in package metadata.
- Hidden/staged benchmark experiments and `R/sparseKrylov.R` are not supported sources; migration work must avoid accidentally packaging or committing them.

## Productization Direction

- GEModelR should initially remain one package containing parser, model API, R reference solver, and optional C++ backend; extracting a standalone native solver now would expose tightly coupled internal metadata.
- Preserve the `GEModel` workflow and legacy/R reference backends while establishing a narrow exported API and compatibility tests.
- Treat licensing, provenance/attribution, package naming, native symbol migration, and cross-platform release checks as pre-release gates rather than cleanup after renaming.
