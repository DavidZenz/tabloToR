# GEModelR

## What This Is

GEModelR is a maintained R package for parsing GEMPACK-style TABLO models and solving large computable general equilibrium models. It evolves the existing `tabloToR` codebase into a production-quality package while preserving the established `GEModel` workflow and offering validated low-memory R and native C++ sparse solvers.

## Core Value

Users can run numerically trustworthy, full-scale TABLO/GTAP simulations in R without dense-memory failure and without sacrificing compatibility with established model workflows.

## Requirements

### Validated

- ✓ Parse TABLO sets, coefficients, variables, formulas, equations, reads, and updates — existing.
- ✓ Load HAR-derived model data and run models through the `GEModel` API — existing.
- ✓ Preserve the legacy execution engine and its default numerical behavior — existing.
- ✓ Compile and execute integer-indexed sparse models without full-system dense allocation — validated on synthetic and GTAP models.
- ✓ Solve unaggregated GTAP 12a (163 regions × 65 commodities) with bounded memory — validated full-scale.
- ✓ Offer an opt-in native structured backend with fail-closed preflight and residual verification — existing.
- ✓ Produce reproducible A/B, tuning, scaling, memory, and residual benchmarks — existing.
- ✓ Establish a documented modification and redistribution basis for the audited inherited source — Phase 1.
- ✓ Record reviewed provenance, attribution, GEModelR name availability, maintainer identity, and repository governance — Phase 1.

### Active

- [ ] Rename package identity, native symbols, options, diagnostics, documentation, and benchmark metadata from `tabloToR` to `GEModelR` through an auditable migration.
- [ ] Preserve source-level compatibility for the `GEModel` workflow and explicitly document intentional changes.
- [ ] Define a narrow supported API while keeping legacy and R sparse implementations as correctness references.
- [ ] Make installation and native compilation reliable on Linux, macOS, Windows, and builds without OpenMP.
- [ ] Replace release-blocking metadata, namespace, documentation, and runtime-compilation weaknesses.
- [ ] Add CI and release gates for checks, numerical equivalence, native capabilities, serialization, and benchmark schemas.
- [ ] Publish migration, architecture, solver-selection, reproducibility, and contributor documentation.
- [ ] Prepare a versioned public release through GitHub and R-universe before considering CRAN submission.

### Out of Scope

- Extracting the C++ solver into a separate package in the first release — it is coupled to TABLO compilation, indexed state, and structured metadata.
- Replacing the R reference or legacy solver immediately — both are required for compatibility and numerical comparison.
- Automatically selecting the C++ backend by default — native execution remains explicit until portability and downstream validation mature.
- Bundling proprietary GTAP inputs or full-scale solution artifacts — public tests use redistributable synthetic/reduced fixtures.
- Introducing DuckDB into the numerical solver — database staging is optional downstream work, not part of sparse factorization.
- Rewriting the public API around a new object system in v1 — migration risk outweighs immediate benefit.

## Context

The upstream package began as a compact in-memory TABLO implementation. This fork now contains a separate sparse compiler/runtime, structured Schur/FGMRES algorithms, Rcpp kernels, OpenMP batching, native LAPACK factors, diagnostics, tests, and benchmark harnesses. A validated full GTAP 12a run solved 26,781,398 positions with at most 80,306,307 nonzeros in 4,662 seconds and 25.34 GiB peak RSS: 3.99× faster and 14.4% lower-memory than the R structured baseline, with a `9.014e-8` residual.

The implementation is therefore already beyond a toy extension, but distribution quality lags technical capability. `DESCRIPTION` still has placeholder identity/license fields, `NAMESPACE` exports too broadly, documentation is incomplete, SuiteSparse support is Linux/runtime-compiled, and no cross-platform CI exists. The repository also contains private experimental benchmark files that must remain untouched and outside the supported package surface.

## Constraints

- **Compatibility**: `GEModel`, closures, shocks, output names, legacy engine defaults, and Matrix backend defaults remain supported unless a versioned migration explicitly says otherwise.
- **Numerical integrity**: every optimized solve must satisfy full-system residual and equivalence gates before state is applied.
- **Memory**: no sparse full-scale path may create a dense full-system matrix, dense solution history, or giant indexed label expansion.
- **Legal**: no renamed public release occurs until upstream licensing and derivative-work obligations are resolved and documented.
- **Portability**: the package must install and test without OpenMP; platform-specific optional capabilities fail clearly.
- **Data**: proprietary GTAP/HAR inputs remain external and are never committed.
- **Scope**: parser, model API, R reference solver, and C++ backend remain in one package for the initial GEModelR releases.
- **Repository safety**: preserve the existing `AGENTS.md` and unrelated staged/untracked experiments.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Name the successor package GEModelR | Clear professional identity centered on the stable public abstraction | ✓ Validated in Phase 1 |
| Productize the existing repository incrementally | The implementation and benchmark evidence are already substantial | — Pending |
| Keep one package initially | Compiler, state, partition metadata, and native kernels are tightly coupled | — Pending |
| Keep legacy and R sparse backends | They provide compatibility and trusted numerical reference behavior | — Pending |
| Keep C++ opt-in initially | Portability and downstream validation should precede default promotion | — Pending |
| Make licensing a release preflight gate | Current metadata does not establish redistribution rights | ✓ Validated in Phase 1; dependency audit remains blocking |
| Publish GitHub/R-universe before CRAN | Enables controlled validation before stricter public distribution | — Pending |
| Accept the upstream public-domain/CC0 response for the audited baseline | The upstream author explicitly confirmed public-domain status and modification/redistribution rights | ✓ Validated in Phase 1 |
| Keep public release fail-closed | Dependency compatibility and the unresolved attribution alias still require reviewed dispositions | ✓ Validated in Phase 1 |
| Separate technical readiness from repository/publication authority | Passing package and release checks must not mutate or publish external resources | ✓ Validated in Phase 1 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition**:
1. Move shipped and verified requirements to Validated.
2. Move invalidated requirements to Out of Scope with rationale.
3. Add newly discovered active requirements and significant decisions.
4. Recheck whether the package description and core value remain accurate.

**After each milestone**:
1. Review the complete scope and compatibility policy.
2. Reassess default backend readiness and platform support.
3. Audit release, licensing, and data-distribution constraints.
4. Update benchmark evidence and maintenance context.

---
*Last updated: 2026-08-31 after Phase 1*
