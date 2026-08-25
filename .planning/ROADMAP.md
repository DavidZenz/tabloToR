# Roadmap: GEModelR

## Overview

GEModelR reaches its first public release through seven auditable technical phases. The sequence first establishes whether and how the inherited code may be redistributed, freezes the proven API and numerical behavior, migrates identity without algorithm changes, narrows and documents the package surface, hardens native portability, qualifies release artifacts, and only then publishes through GitHub and R-universe.

## Phases

- [ ] **Phase 1: Provenance and Release Boundary** - Establish legal, naming, maintainership, and attribution prerequisites.
- [ ] **Phase 2: Compatibility and Numerical Baseline** - Freeze the behavior that the rename and refactors must preserve.
- [ ] **Phase 3: GEModelR Identity Migration** - Rename package and native identity without changing solver methodology.
- [ ] **Phase 4: Public API and Solver Boundaries** - Replace accidental exports with documented contracts and explicit dispatch.
- [ ] **Phase 5: Portable Native Build and CI** - Support major platforms, serial builds, and optional bounded OpenMP.
- [ ] **Phase 6: Documentation and Release Qualification** - Produce user/developer docs and clean, auditable release artifacts.
- [ ] **Phase 7: GitHub and R-universe Release** - Publish the legally cleared, qualified GEModelR package.

## Phase Details

### Phase 1: Provenance and Release Boundary

**Goal**: Establish an unambiguous legal and organizational basis for GEModelR and define what may be publicly released.
**Depends on**: Nothing
**Requirements**: PROV-01, PROV-02, PROV-03, PROV-04
**Release gate**: Public distribution is blocked until PROV-01 and PROV-02 are satisfied; private compatibility work may continue.
**Success Criteria**:

  1. Maintainers can point to a written license/permission record covering inherited source modification and redistribution, or to an approved alternative implementation strategy.
  2. An authorship/provenance inventory maps inherited and new code to correct contributors and copyright holders.
  3. An authoritative check reports no current or historical CRAN/Bioconductor collision for GEModelR at the time of repository reservation.
  4. Canonical maintainer, repository, issue tracker, package license, citation, and attribution decisions are recorded.

**Plans**: TBD
**Wave 1**

- [x] 01-01-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md
- [x] 01-03-PLAN.md
- [x] 01-04-PLAN.md

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 01-05-PLAN.md

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 01-06-PLAN.md

### Phase 2: Compatibility and Numerical Baseline

**Goal**: Create executable contracts for every user-visible and numerical behavior GEModelR must preserve.
**Depends on**: Phase 1 scope decisions; may proceed while external permission is pending
**Requirements**: COMP-01, COMP-02, COMP-03, NUM-01, NUM-02
**Success Criteria**:

  1. A compatibility manifest records supported exports, `GEModel` fields/methods, signatures, defaults, closure/shock semantics, outputs, and serialization behavior.
  2. Redistributable tests execute the complete documented workflow under legacy, Matrix sparse, structured R, and native C++ paths where applicable.
  3. Cross-backend solution and true-residual gates pass at documented tolerances before model state is updated.
  4. Baseline artifacts identify package source, fixture/model signatures, platform, and dependency versions.

**Plans**: TBD

### Phase 3: GEModelR Identity Migration

**Goal**: Convert package, native, runtime-option, diagnostic, benchmark, and documentation identity to GEModelR while keeping numerical code behavior fixed.
**Depends on**: Phase 2
**Requirements**: COMP-04, MIGR-01, MIGR-02
**Success Criteria**:

  1. A built and installed package reports `Package: GEModelR`, loads only its registered GEModelR native library, and exposes the approved namespace.
  2. Repository searches find no unsupported `tabloToR` identity except intentional historical attribution or migration examples.
  3. Pre/post-rename compatibility fixtures produce equivalent solutions, outputs, diagnostics, and serialization results.
  4. Users have exact installation and script migration instructions, including the fate of `tabloToR::` calls and old option names.

**Plans**: TBD

### Phase 4: Public API and Solver Boundaries

**Goal**: Make GEModelR maintainable through a deliberate public namespace and explicit internal backend contract.
**Depends on**: Phase 3
**Requirements**: API-01, API-02, DOCS-01
**Success Criteria**:

  1. `NAMESPACE` contains explicit exports and no broad alphabetic export pattern.
  2. Every supported export and package-level option has generated documentation and a contract test.
  3. Backend registration, capability checks, solve invocation, diagnostics, and cleanup follow one explicit internal interface.
  4. Legacy, Matrix, structured R, and native C++ implementations remain independently selectable correctness/performance references.

**Plans**: TBD

### Phase 5: Portable Native Build and CI

**Goal**: Make installation and native execution predictable on major R platforms with or without OpenMP.
**Depends on**: Phase 4
**Requirements**: PORT-01, PORT-02, PORT-03, CI-01
**Success Criteria**:

  1. Linux, macOS, and Windows CI installs the package and passes core tests with OpenMP unavailable or disabled.
  2. OpenMP-enabled jobs report capabilities, respect configured thread bounds, and match serial numerical results.
  3. Supported solve paths require no runtime compiler and no hard-coded Linux SuiteSparse include/library path.
  4. CI covers appropriate R release/oldrel/devel and Matrix compatibility variants while keeping long full-scale benchmarks external.

**Plans**: TBD

### Phase 6: Documentation and Release Qualification

**Goal**: Produce a publication-quality source package and auditable evidence for users and maintainers.
**Depends on**: Phase 5
**Requirements**: NUM-03, CI-02, DOCS-02, DOCS-03, REL-01, DATA-01
**Success Criteria**:

  1. Built source archives pass release checks without errors, warnings, or unexplained significant notes.
  2. Vignettes demonstrate first simulation, sparse migration, solver selection, diagnostics/memory budgeting, and external full-scale benchmarking using redistributable inputs where executed.
  3. Architecture and contributor guides describe subsystem ownership, numerical gates, native development, and proprietary-data restrictions.
  4. NEWS, semantic-versioning/lifecycle policy, citation/provenance text, and release checklist agree with actual package behavior.
  5. Signed full-scale benchmark summaries verify residuals, finiteness, no dense fallback, time, memory, hardware, and package/model fingerprints without bundling private inputs.

**Plans**: TBD

### Phase 7: GitHub and R-universe Release

**Goal**: Publish the first installable GEModelR release after all legal and technical gates pass.
**Depends on**: Phase 6 and cleared Phase 1 release gate
**Requirements**: REL-02
**Success Criteria**:

  1. The canonical Git repository contains a signed/tagged release whose source archive matches the qualified commit.
  2. A clean environment can install GEModelR from the documented Git and R-universe instructions and run the redistributable smoke workflow.
  3. Release notes state compatibility, supported platforms/backends, known limits, benchmark evidence, and migration steps.
  4. Maintainers have a documented support, issue-triage, and release cadence for the first public validation period.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Provenance and Release Boundary | 4/6 | In Progress|  |
| 2. Compatibility and Numerical Baseline | 0/TBD | Not started | - |
| 3. GEModelR Identity Migration | 0/TBD | Not started | - |
| 4. Public API and Solver Boundaries | 0/TBD | Not started | - |
| 5. Portable Native Build and CI | 0/TBD | Not started | - |
| 6. Documentation and Release Qualification | 0/TBD | Not started | - |
| 7. GitHub and R-universe Release | 0/TBD | Not started | - |
