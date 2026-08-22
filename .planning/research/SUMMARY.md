# Project Research Summary

**Project:** GEModelR
**Domain:** Production scientific R package and sparse CGE solver
**Researched:** 2026-08-22
**Confidence:** HIGH technically; legal clearance remains unresolved

## Executive Summary

GEModelR should be built as a productization and compatibility migration of the validated codebase, not as a new solver rewrite. The parser, `GEModel` facade, R reference paths, sparse indexed runtime, structured solver, C++ kernels, and benchmark harness belong together in the first package because their contracts are still tightly coupled. The right architecture is one package with explicit internal subsystem and backend boundaries.

The first gate is legal, not technical. The upstream public repository contains no license file and has placeholder license/authorship metadata. Public visibility grants repository viewing/forking under platform terms, but does not establish permission to reproduce, modify, and distribute an open-source derivative. GEModelR may be planned and developed privately, but a renamed public release must wait for explicit upstream permission/license or a qualified alternative strategy.

After that gate, sequencing matters: freeze compatibility and numerical baselines; validate the GEModelR name; migrate identity mechanically; narrow/document the API; harden serial/OpenMP/native builds across platforms; then publish through GitHub and R-universe. CRAN should remain a later milestone after zero-warning checks, dependency portability, and sustained downstream use.

## Key Findings

### Recommended Stack

- R remains the public/compiler runtime; determine the minimum supported R version through CI evidence.
- Matrix remains the portable sparse reference and factor owner.
- Rcpp plus R-provided LAPACK/BLAS remain the native boundary.
- OpenMP remains optional with a serial build and explicit capability diagnostics.
- testthat, roxygen2, r-lib/actions, pkgdown, and R-universe provide the standard quality/release toolchain.

### Must-Have Features

- Clear legal provenance, authorship, license, and attribution.
- Stable documented `GEModel` and backend contracts.
- Legacy/R reference availability and numerical equivalence gates.
- Major-platform installation with OpenMP-disabled support.
- Explicit memory, capability, residual, and dense-fallback diagnostics.
- Redistributable examples, migration guides, NEWS, architecture docs, and contributor guidance.
- Reproducible external full-scale benchmark process.

### Architecture Approach

Use a compatibility facade over parser/compiler, indexed runtime, solver registry, structured decomposition, native kernels, and verification layers. Introduce explicit backend registration behind current methods. Defer a new object system and standalone native package until stable boundaries are demonstrated by use.

### Critical Pitfalls

1. **Releasing without rights** — obtain and record upstream permission/license first.
2. **Big-bang migration** — isolate baseline, identity, API, build, and release phases.
3. **OpenMP/runtime compilation assumptions** — require serial builds and installation-time compilation.
4. **Accidental API breakage** — inventory broad exports before narrowing them.
5. **Unverifiable performance claims** — preserve signed isolated benchmark gates.

## Implications for Roadmap

### Phase 1: Provenance, Name, and Release Boundary

Establish rights, attribution, package-name availability, maintainership, repository strategy, and exact v1/out-of-scope boundary. This phase can block public release without blocking private compatibility work.

### Phase 2: Compatibility and Numerical Baseline

Snapshot exports, method signatures, object serialization, output names, examples, engine defaults, and representative legacy/R/C++ solutions. Produce the migration contract before renaming.

### Phase 3: GEModelR Identity Migration

Rename package metadata, native symbols, options, diagnostics, benchmark signatures, docs, and installation examples in controlled commits. Add transitional compatibility decisions without changing numerical algorithms.

### Phase 4: API and Internal Boundaries

Replace broad exports with a documented public API, introduce explicit solver dispatch, modularize the oversized runtime, and retain reference backends. Avoid an object-system rewrite.

### Phase 5: Portable Build and CI

Remove normal-use runtime compilation, establish serial/OpenMP capability paths, and run Linux/macOS/Windows plus R-version and Matrix-version checks.

### Phase 6: Documentation and Release Qualification

Add roxygen/manuals, vignettes, NEWS, pkgdown, migration examples, source-archive checks, security/proprietary-data audits, and signed numerical/benchmark reports.

### Phase 7: GitHub and R-universe Release

Tag the first pre-CRAN release, publish installable binaries, collect downstream feedback, and define the criteria for CRAN consideration.

### Ordering Rationale

- Legal and naming decisions precede public identity investment.
- Compatibility evidence precedes mechanical renaming and namespace narrowing.
- Build portability precedes binary distribution.
- Documentation is finalized against stable API/build behavior.
- CRAN remains outside the initial release milestone until external use validates maintenance capacity.

## Research Flags

- **Phase 1:** Requires direct upstream/legal coordination and authoritative name checks.
- **Phase 3:** Requires exhaustive identity/native-symbol search and package-install experiments.
- **Phase 5:** Requires current platform-specific R build research and real CI feedback.
- **Phase 7:** Requires current R-universe/release policy verification at execution time.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Based on existing validated implementation and official R guidance |
| Features | HIGH | Derived from R package release expectations and current gaps |
| Architecture | HIGH | Incremental boundaries fit the brownfield implementation |
| Pitfalls | HIGH | Most are directly observable; legal resolution itself is external |

### Gaps to Address

- Identify all upstream copyright holders and obtain written licensing/permission.
- Run authoritative current/past CRAN and Bioconductor name checks before reserving GEModelR.
- Decide the package maintainer identity, organization, and public repository location.
- Determine minimum supported R/Matrix versions from the CI matrix, not local versions alone.
- Decide whether optional SuiteSparse is redesigned, demoted to experimental, or removed from v1 support.

## Sources

### Primary

- [Upstream tabloToR repository](https://github.com/mivanic/tabloToR)
- [Upstream `DESCRIPTION`](https://raw.githubusercontent.com/mivanic/tabloToR/master/DESCRIPTION)
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
- [Writing R Extensions](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html)
- [R-universe documentation](https://docs.r-universe.dev/)
- [r-lib/actions](https://r-lib.github.io/actions/)
- [Roxygen2 namespace guidance](https://roxygen2.r-lib.org/articles/namespace.html)

### Supporting

- [GitHub licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
- Existing repository maps, tests, and `benchmarks/GTAP12A_CPP_RESULTS.md`

---
*Research completed: 2026-08-22*
*Ready for roadmap: yes, subject to legal gate*
