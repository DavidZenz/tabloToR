# Roadmap: GEModelR

## Overview

GEModelR reaches its first public release through seven auditable technical phases. The sequence first establishes whether and how the inherited code may be redistributed, freezes the proven API and numerical behavior, migrates identity without algorithm changes, narrows and documents the package surface, hardens native portability, qualifies release artifacts, and only then publishes through GitHub and R-universe.

## Phases

- [x] **Phase 1: Provenance and Release Boundary** - Establish legal, naming, maintainership, and attribution prerequisites. (completed 2026-08-31)
- [x] **Phase 2: Compatibility and Numerical Baseline** - Freeze the behavior that the rename and refactors must preserve. (completed 2026-09-09)
- [x] **Phase 3: GEModelR Identity Migration** - Rename package and native identity without changing solver methodology. (completed 2026-09-25)
- [ ] **Phase 4: Public API and Solver Boundaries** - Replace accidental exports with documented contracts and explicit dispatch.
- [ ] **Phase 5: Portable Native Build and CI** - Support major platforms, serial builds, and optional bounded OpenMP.
- [ ] **Phase 6: Documentation and Release Qualification** - Produce user/developer docs and clean, auditable release artifacts.
- [ ] **Phase 7: GitHub and R-universe Release** - Publish the legally cleared, qualified GEModelR package.

## Phase Details

### Phase 1: Provenance and Release Boundary

**Goal**: Establish an unambiguous legal and organizational basis for GEModelR and define what may be publicly released.
**Depends on**: Nothing
**Requirements**: PROV-01, PROV-02, PROV-03, PROV-04
**Release gate**: Public distribution remains blocked by DEPENDENCY_COMPATIBILITY_AUDIT_PENDING and ATTRIBUTION_IDENTITY_UNRESOLVED; private compatibility work may continue.
**Success Criteria**:

  1. Maintainers can point to a written license/permission record covering inherited source modification and redistribution, or to an approved alternative implementation strategy.
  2. An authorship/provenance inventory maps inherited and new code to correct contributors and copyright holders.
  3. An authoritative check reports no current or historical CRAN/Bioconductor collision for GEModelR at the time of repository reservation.
  4. Canonical maintainer, repository, issue tracker, package license, citation, and attribution decisions are recorded.

**Plans**: 11/11 plans executed; gap closure complete and ready for phase re-verification
**Wave 1**

- [x] 01-01-PLAN.md

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md
- [x] 01-03-PLAN.md
- [x] 01-04-PLAN.md

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-05-PLAN.md

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 01-06-PLAN.md

**Wave 5** *(gap closure; blocked on Wave 4 completion)*

- [x] 01-08-PLAN.md
- [x] 01-09-PLAN.md

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 01-07-PLAN.md

**Wave 7** *(blocked on Wave 6 completion)*

- [x] 01-10-PLAN.md

**Wave 8** *(blocked on Wave 7 completion)*

- [x] 01-11-PLAN.md

### Phase 2: Compatibility and Numerical Baseline

**Goal**: Create executable contracts for every user-visible and numerical behavior GEModelR must preserve.
**Depends on**: Phase 1 scope decisions; may proceed while external permission is pending
**Requirements**: COMP-01, COMP-02, COMP-03, NUM-01, NUM-02
**Success Criteria**:

  1. A compatibility manifest records supported exports, `GEModel` fields/methods, signatures, defaults, closure/shock semantics, outputs, and serialization behavior.
  2. Redistributable tests execute the complete documented workflow under legacy, Matrix sparse, structured R, and native C++ paths where applicable.
  3. Cross-backend solution and true-residual gates pass at documented tolerances before model state is updated.
  4. Baseline artifacts identify package source, fixture/model signatures, platform, and dependency versions.

**Plans**: 6/6 plans executed

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Freeze the observed GEModel contract and structural compatibility helpers

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Exercise redistributable workflows, shock APIs, defaults, outputs, and legacy smoke

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-03-PLAN.md — Enforce numerical authority, equivalence, and true-residual acceptance

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 02-04-PLAN.md — Make solve state transactional and post-simulation retryable

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 02-05-PLAN.md — Add versioned logical serialization and fresh-process restore

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 02-06-PLAN.md — Add proposal-only baseline tooling and integrated regression gates

### Phase 3: GEModelR Identity Migration

**Goal**: Convert package, native, runtime-option, diagnostic, benchmark, and documentation identity to GEModelR while keeping numerical code behavior fixed.
**Depends on**: Phase 2
**Requirements**: COMP-04, MIGR-01, MIGR-02
**Success Criteria**:

  1. A built and installed package reports `Package: GEModelR`, loads only its registered GEModelR native library, and exposes the approved namespace.
  2. Repository searches find no unsupported `tabloToR` identity except intentional historical attribution or migration examples.
  3. Pre/post-rename compatibility fixtures produce equivalent solutions, outputs, diagnostics, and serialization results.
  4. Users have exact installation and script migration instructions, including the fate of `tabloToR::` calls and old option names.

**Plans**: 19/20 plans executed; eight append-only gap-closure plans independently checked and ready to execute

**Wave 1**

- [x] 03-01-PLAN.md — Adapt the predecessor baseline checker and freeze immutable Phase 2 evidence (depends on Phase 2)

**Wave 2**

- [x] 03-02-PLAN.md — Create the tagged predecessor bridge and genuine fingerprinted fixture (depends on 03-01)

**Wave 3**

- [x] 03-03-PLAN.md — Obtain blocking human approval of a reachable immutable predecessor bridge (depends on 03-02)

**Wave 4**

- [x] 03-04-PLAN.md — Apply the atomic load-critical Package, namespace, native, wrapper, and launcher switch (depends on 03-03)

**Wave 5**

- [x] 03-05-PLAN.md — Migrate current package and documentation identity (depends on 03-04)

**Wave 6**

- [x] 03-06-PLAN.md — Migrate runtime options, private hooks, attributes, and diagnostics (depends on 03-05)

**Wave 7**

- [x] 03-07-PLAN.md — Validate predecessor lineage and normalize current logical state without mutating approved inputs (depends on 03-06)

**Wave 8**

- [x] 03-08-PLAN.md — Migrate active benchmark and baseline producers (depends on 03-07)

**Wave 9**

- [x] 03-09-PLAN.md — Migrate test helpers and native solver tests (depends on 03-08)

**Wave 10**

- [x] 03-10-PLAN.md — Classify old-token hits and migrate provenance, tooling, and historical maps (depends on 03-09)

**Wave 11**

- [x] 03-11-PLAN.md — Complete non-load-critical identity cleanup and exhaustive audit (depends on 03-10)

**Wave 12**

- [x] 03-12-PLAN.md — Qualify clean tracked source, archive, installation, fresh public/native workflow, full suite, and immutable evidence (depends on 03-11)

**Wave 13** *(gap closure; depends on executed 03-12)*

- [x] 03-13-PLAN.md — Install the benchmark child and exercise real installed sweep/scaling runs
- [x] 03-15-PLAN.md — Propose and obtain explicit approval for the fingerprint-protected serialization bugfix
- [x] 03-17-PLAN.md — Separate original-artifact and migration-source gates and repair both stale source-baseline tests
- [x] 03-18-PLAN.md — Propose and review the narrowly scoped, noncircular workflow-evidence identity policy

**Wave 14** *(gap closure; blocked on respective Wave 13 prerequisites)*

- [x] 03-14-PLAN.md — Require complete, uniquely keyed, finite benchmark solution comparisons (depends on 03-13)
- [x] 03-16-PLAN.md — Apply only the approved exact-type serialization fix and verify transactional restoration (depends on 03-15)

**Wave 15** *(gap closure; blocked on all repair/policy prerequisites)*

- [x] 03-19-PLAN.md — Review and apply the exact identity inventory reseal and post-evidence audit lifecycle (depends on 03-13 through 03-18)

**Wave 16** *(gap closure; blocked on reviewed reseal)*

- [x] 03-20-PLAN.md — Run the clean-HEAD 18-stage qualification and require the post-verifier final-tree audit (depends on 03-19)

Gap execution: `$gsd-execute-phase 03 --gaps-only`. Approval checkpoints in 03-15, 03-18 and 03-19 remain mandatory. Canonical numerical/predecessor evidence stays immutable; the exact current-host NOTE policy and both independent release blockers remain in force. Planning verification is not phase completion.

### Phase 4: Public API and Solver Boundaries

**Goal**: Make GEModelR maintainable through a deliberate public namespace and explicit internal backend contract.
**Depends on**: Phase 3
**Requirements**: API-01, API-02, DOCS-01
**Success Criteria**:

  1. `NAMESPACE` contains explicit exports and no broad alphabetic export pattern.
  2. Every supported export and package-level option has generated documentation and a contract test.
  3. Backend registration, capability checks, solve invocation, diagnostics, and cleanup follow one explicit internal interface.
  4. Legacy, Matrix, structured R, and native C++ implementations remain independently selectable correctness/performance references.

**Plans**: 4/6 plans executed

Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Prove the Matrix backend adapter path end to end

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — Register backend IDs and native preflight/cleanup

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 04-03-PLAN.md — Enforce lifecycle and state invalidation
- [x] 04-04-PLAN.md — Validate selectors and materialize output on demand

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 04-05-PLAN.md — Add stable diagnostics and condition contracts

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 04-06-PLAN.md — Publish the deliberate namespace and generated docs

**Execution waves**

- Wave 1: 04-01
- Wave 2: 04-02 (depends on 04-01)
- Wave 3: 04-03 and 04-04 (both depend on 04-02)
- Wave 4: 04-05 (depends on 04-03 and 04-04)
- Wave 5: 04-06 (depends on 04-05)

### Phase 5: Portable Native Build and CI

**Goal**: Make installation and native execution predictable on major R platforms with or without OpenMP.
**Depends on**: Phase 4
**Requirements**: PORT-01, PORT-02, PORT-03, CI-01
**Success Criteria**:

  1. Linux, macOS, and Windows CI installs the package and passes core tests with OpenMP unavailable or disabled.
  2. OpenMP-enabled jobs report capabilities, respect configured thread bounds, and match serial numerical results.
  3. Supported solve paths require no runtime compiler and no hard-coded Linux SuiteSparse include/library path.
  4. CI covers appropriate R release/oldrel/devel and Matrix compatibility variants while keeping long full-scale benchmarks external.

**Plans**: 6 plans

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

**Plans**: 6 plans

### Phase 7: GitHub and R-universe Release

**Goal**: Publish the first installable GEModelR release after all legal and technical gates pass.
**Depends on**: Phase 6 and cleared Phase 1 release gate
**Requirements**: REL-02
**Success Criteria**:

  1. The canonical Git repository contains a signed/tagged release whose source archive matches the qualified commit.
  2. A clean environment can install GEModelR from the documented Git and R-universe instructions and run the redistributable smoke workflow.
  3. Release notes state compatibility, supported platforms/backends, known limits, benchmark evidence, and migration steps.
  4. Maintainers have a documented support, issue-triage, and release cadence for the first public validation period.

**Plans**: 6 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Provenance and Release Boundary | 11/11 | Complete    | 2026-08-31 |
| 2. Compatibility and Numerical Baseline | 6/6 | Complete    | 2026-09-09 |
| 3. GEModelR Identity Migration | 21/21 | Complete    | 2026-09-25 |
| 4. Public API and Solver Boundaries | 4/6 | In Progress|  |
| 5. Portable Native Build and CI | 0/TBD | Not started | - |
| 6. Documentation and Release Qualification | 0/TBD | Not started | - |
| 7. GitHub and R-universe Release | 0/TBD | Not started | - |
