# Requirements: GEModelR

**Defined:** 2026-08-22
**Core Value:** Users can run numerically trustworthy, full-scale TABLO/GTAP simulations in R without dense-memory failure and without sacrificing compatibility.

## v1 Requirements

### Provenance and Identity

- [x] **PROV-01**: Maintainers have a documented legal basis to modify and publicly redistribute all inherited source code.
- [x] **PROV-02**: GEModelR records accurate upstream authorship, current contributors, copyright holders, and required attribution in package metadata and source documentation.
- [x] **PROV-03**: The GEModelR name is checked against current and historical CRAN and Bioconductor packages before repository reservation and release.
- [x] **PROV-04**: GEModelR has a named human maintainer, valid contact address, canonical repository URL, and issue tracker.

### Compatibility

- [x] **COMP-01**: Existing users can perform the documented `GEModel$new()`, `loadTablo()`, `loadData()`, closure/shock, `solveModel()`, and output workflow under GEModelR.
- [x] **COMP-02**: Omitted engine/backend arguments preserve the legacy engine and Matrix sparse backend defaults already protected by tests.
- [x] **COMP-03**: Supported model fields, method signatures, closure/shock semantics, output names, compact/full output behavior, and serialization behavior are documented and regression-tested.
- [x] **COMP-04**: The rename provides explicit installation and namespace migration instructions for scripts using `tabloToR::`.

### Numerical Integrity

- [x] **NUM-01**: Legacy, Matrix sparse, structured R, and optional structured C++ paths satisfy documented solution-equivalence and true-residual tolerances on redistributable fixtures.
- [x] **NUM-02**: Solver results are applied to mutable model state only after the selected backend passes its required residual and finiteness checks.
- [ ] **NUM-03**: The full GTAP benchmark records package/model signatures, residuals, finiteness, dense-fallback status, time, memory, and hardware without distributing proprietary inputs.

### Package Migration and API

- [x] **MIGR-01**: Package metadata, namespace, native initialization/registration symbols, private wrappers, options, diagnostics, benchmark signatures, tests, and documentation consistently use the GEModelR identity.
- [x] **MIGR-02**: Package renaming does not alter solver algorithms or numerical defaults in the same change set.
- [x] **API-01**: GEModelR exports a deliberate documented public API instead of `exportPattern("^[[:alpha:]]+")`.
- [x] **API-02**: Backend selection and capability checks use an explicit internal dispatch contract while preserving the R reference implementations.

### Portability and Quality

- [x] **PORT-01**: The package installs and passes its core tests on Linux, macOS, and Windows with OpenMP unavailable.
- [x] **PORT-02**: OpenMP acceleration is optional, capability-reported, bounded, and numerically equivalent across supported thread counts.
- [x] **PORT-03**: Supported installed workflows do not compile native code at solve time or depend on hard-coded Linux SuiteSparse paths.
- [x] **CI-01**: CI checks R release, oldrel, and devel across an appropriate Linux/macOS/Windows matrix and exercises native/serial capability paths.
- [ ] **CI-02**: Built source archives pass package checks without errors, warnings, or unexplained significant notes before release.

### Documentation and Release

- [x] **DOCS-01**: All supported exports, the package, and native/backend options have generated R documentation.
- [ ] **DOCS-02**: Vignettes cover first simulation, legacy-to-sparse migration, backend selection, diagnostics/memory budgeting, and external full-scale benchmarking.
- [ ] **DOCS-03**: Contributor and architecture documentation explains subsystem boundaries, numerical gates, data restrictions, and cross-platform native development.
- [ ] **REL-01**: NEWS, semantic-versioning policy, lifecycle/deprecation rules, citation/provenance text, and release checklists exist.
- [ ] **REL-02**: A tagged GEModelR release is installable from its canonical Git repository and R-universe after all legal and technical gates pass.
- [ ] **DATA-01**: Source archives and public CI contain no proprietary model data, private credentials, giant solutions, or unsupported benchmark scratch files.

## v2 Requirements

### Future Architecture

- **ARCH-01**: GEModelR may offer a new object system with a versioned compatibility adapter.
- **ARCH-02**: GEModelR may select a backend automatically using validated and inspectable preflight rules.
- **ARCH-03**: Native kernels may be extracted into a separate package after a stable solver metadata contract exists.
- **PORT-04**: Optional direct SuiteSparse integration may use configure-time portable detection and packaged fallback behavior.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Public release before legal clearance | Redistribution rights and attribution must be unambiguous |
| C++ backend as the immediate default | Portability and downstream validation are not mature enough |
| Full proprietary GTAP data in the package | Licensing, privacy, size, and check-runtime constraints |
| DuckDB as a numerical solver dependency | It does not replace sparse factorization or indexed numeric access |
| Big-bang `GEModel` object rewrite | Unnecessary compatibility and numerical risk for v1 |
| Immediate CRAN submission | GitHub/R-universe validation should precede CRAN maintenance obligations |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROV-01 | Phase 1 | Complete |
| PROV-02 | Phase 1 | Complete |
| PROV-03 | Phase 1 | Complete |
| PROV-04 | Phase 1 | Complete |
| COMP-01 | Phase 2 | Complete |
| COMP-02 | Phase 2 | Complete |
| COMP-03 | Phase 2 | Complete |
| COMP-04 | Phase 3 | Complete |
| NUM-01 | Phase 2 | Complete |
| NUM-02 | Phase 2 | Complete |
| NUM-03 | Phase 6 | Pending |
| MIGR-01 | Phase 3 | Complete |
| MIGR-02 | Phase 3 | Complete |
| API-01 | Phase 4 | Complete |
| API-02 | Phase 4 | Complete |
| PORT-01 | Phase 5 | Complete |
| PORT-02 | Phase 5 | Complete |
| PORT-03 | Phase 5 | Complete |
| CI-01 | Phase 5 | Complete |
| CI-02 | Phase 6 | Pending |
| DOCS-01 | Phase 4 | Complete |
| DOCS-02 | Phase 6 | Pending |
| DOCS-03 | Phase 6 | Pending |
| REL-01 | Phase 6 | Pending |
| REL-02 | Phase 7 | Pending |
| DATA-01 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-22*
*Last updated: 2026-08-25 after Plan 01-03 completion*
