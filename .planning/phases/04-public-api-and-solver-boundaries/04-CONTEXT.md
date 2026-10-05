# Phase 4: Public API and Solver Boundaries - Context

**Gathered:** 2026-09-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the accidental broad namespace with a deliberate GEModelR facade and define one explicit internal contract for R and native solver backends. Document and test the supported exports, high-level runtime options, lifecycle boundaries, output selectors, diagnostics, and failure conditions without changing solver algorithms, numerical defaults, or the established GEModel workflow. Portability/CI, full release documentation, and publication remain later phases.

</domain>

<decisions>
## Implementation Decisions

### Public namespace

- **D-01:** Use a facade-first namespace centered on the `GEModel` reference-class entry point. Export only deliberate user-facing helpers if implementation proves one is needed; keep parser, compiler, solver, and native wrappers internal.
- **D-02:** Do not export low-level solver helpers or add a public capability probe in this phase. Users select backends through `GEModel$solveModel()` and inspect capabilities/results through documented model diagnostics.
- **D-03:** Stabilize only high-level `GEModelR.*` options: memory, tolerance, ordering, batching, and thread controls. Transaction/fault hooks and cache internals remain private.
- **D-04:** Apply a hard boundary to functions formerly reachable through `exportPattern()`: remove accidental exports without aliases or deprecation wrappers. The supported contract is the documented `GEModel` workflow.

### Backend contract

- **D-05:** Retain stable explicit backend IDs, including the existing Matrix, SparseM, SuiteSparse, structured R, and explicit `StructuredSchurFGMRESCpp` paths. A requested backend is never silently replaced by another backend.
- **D-06:** Run capability and ABI preflight before matrix construction or mutable state changes. Missing native symbols, incompatible capabilities, and unavailable optional features fail closed with the requested backend, cause, and remediation.
- **D-07:** Allow validated structural sparsity/order metadata to persist on the model, but scope factors, RHS buffers, and numerical workspaces to one solve and release them on success or error.
- **D-08:** Require every backend to return a candidate plus structural metadata, finiteness/residual evidence, timing, and cleanup information. A central orchestrator owns acceptance, transaction boundaries, and state mutation.

### Model lifecycle boundaries

- **D-09:** Make methods the supported mutation surface while preserving the established `variableValues`, closure, and shock workflows. Compiler, source-data, index, and cache fields are implementation state rather than supported direct mutation inputs.
- **D-10:** Setters use conservative invalidation. Closure changes invalidate structural/index/backend caches and accepted outputs; shock changes invalidate pending solve/post-simulation state and diagnostics while retaining compiled structures and source data.
- **D-11:** Keep engine selection coherent: `loadData(engine=...)` selects the runtime, `solveModel(engine=...)` must match it, and switching engines requires reloading data.
- **D-12:** Validate lifecycle order explicitly. Calls made before their prerequisites, and failures during loading or setup, report the next required action and preserve the prior model state.

### Output and diagnostics

- **D-13:** Validate `variables=` and `dimensions=` strictly for compact output. Unknown variables, dimensions, and oversized selections produce actionable errors; explicit empty selections retain their established behavior.
- **D-14:** Materialize labels and full model data on demand. Compact output reconstructs labels only for requested variables/dimensions; full output explicitly materializes the compatibility structure.
- **D-15:** Keep a small documented diagnostic envelope after every solve, with `diagnostics=TRUE` adding residual history, timings, allocations, capabilities, cleanup, and memory detail.
- **D-16:** Use stable GEModelR condition classes and a versioned diagnostic envelope so callers can distinguish validation, capability, numerical, post-simulation, retryable, and committed-state outcomes without parsing messages.

### the agent's Discretion

- Choose the exact explicit export list after auditing the compatibility manifest and generated documentation needs.
- Choose the internal registry/result-record shape, cache invalidation implementation, condition class names, and exact diagnostic field names while preserving the decisions above and Phase 2 numerical/state gates.
- Choose which high-level `GEModelR.*` keys are formally supported after inventorying existing options; private transaction and cache keys must remain unexported and undocumented.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and requirements

- `.planning/PROJECT.md` — GEModelR product direction, compatibility constraints, backend policy, and deferred portability/release work.
- `.planning/REQUIREMENTS.md` — API-01, API-02, DOCS-01, and the compatibility/numerical requirements this phase must preserve.
- `.planning/ROADMAP.md` — Phase 4 goal, success criteria, dependencies, and boundaries with Phases 5–7.

### Prior decisions and contracts

- `.planning/phases/01-provenance-and-release-boundary/01-CONTEXT.md` — provenance, maintainer, and release-boundary decisions inherited by the package.
- `.planning/phases/02-compatibility-and-numerical-baseline/02-CONTEXT.md` — supported workflow, backend authority, residual gates, transaction semantics, output structure, and serialization rules.
- `.planning/phases/03-gemodelr-identity-migration/03-CONTEXT.md` — GEModelR identity, immediate replacement policy, and the explicit decision that API narrowing belongs here.
- `inst/compatibility/GEModel-contract.csv` — observed export/method tiers and frozen method signatures to reconcile with the new namespace.

### Package and runtime integration points

- `NAMESPACE` — current broad export pattern and native registration.
- `DESCRIPTION` — package imports, generated documentation dependencies, and package-level metadata.
- `R/GEModel.R` — reference-class facade, lifecycle methods, solver entry point, and public defaults.
- `R/sparseSolver.R` — sparse dispatch, backend names, transaction flow, output projection, diagnostics, and memory checks.
- `R/zzzSparseSchurCpp.R` — native capability preflight, structured C++ dispatch, cache ownership, and cleanup hooks.
- `R/RcppExports.R` — generated private native wrappers that must remain outside the public facade.
- `src/RcppExports.cpp` — registered native symbols and ABI-facing initialization.

### Tests and codebase maps

- `tests/testthat/test-public-solver-contract.R` — current default, preflight, and export-surface contracts.
- `tests/testthat/test-documented-workflow.R` — public workflow, compact/full output, and post-simulation behavior.
- `.planning/codebase/STACK.md` — R/Matrix/Rcpp/SparseM stack and runtime options.
- `.planning/codebase/ARCHITECTURE.md` — compiler/runtime layers and sparse-to-native integration points.
- `.planning/codebase/CONVENTIONS.md` — naming, generated-wrapper, error, and testing conventions.

No external specifications were referenced during discussion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `GEModel` already centralizes load, closure, shock, solve, memory, serialization, and retry-postsim entry points.
- `inst/compatibility/GEModel-contract.csv` and existing testthat contracts provide the source of truth for supported methods and signatures.
- Sparse transaction helpers, residual gates, `sparse_project_outputs()`, and native preflight/cache environments can be adapted behind the new internal backend interface.

### Established Patterns

- `GEModel` is a `methods::setRefClass` facade; implementation files are collated in R and `zzz*` wrappers intentionally replace earlier definitions.
- Matrix is the generic sparse authority and C++ is opt-in; native requests currently fail closed rather than silently falling back.
- Solver results are accepted transactionally only after finiteness and residual checks, while full-scale sparse paths delay labels and avoid dense system copies.
- Rcpp wrapper and registration files are generated artifacts and must be regenerated rather than hand-maintained.

### Integration Points

- Narrowing exports affects `NAMESPACE`, roxygen/man generation, namespace-based tests, and any documented examples.
- Backend dispatch spans `GEModel$solveModel()`, `sparse_solve_model()`, structured R helpers, `zzzSparseSchurCpp.R`, and native registration/capability checks.
- Lifecycle and diagnostics changes must preserve serialization, retry-postsim, benchmark metadata, and Phase 2 numerical/state evidence.

</code_context>

<specifics>
## Specific Ideas

- Keep the C++ structured backend explicitly selectable while Matrix, structured R, and legacy remain independent correctness/performance references.
- Make the sparse path suitable for full-scale work without exposing low-level solver internals or retaining numerical workspaces after a solve.
- Treat labels and diagnostics as demand-driven so the public API remains useful without recreating the large dense/string allocations that motivated the sparse engine.

</specifics>

<deferred>
## Deferred Ideas

- Cross-platform native builds, OpenMP portability, and CI belong to Phase 5.
- Complete user/developer documentation, release qualification, and the final package license/release gates belong to Phase 6.
- Automatic backend selection, a new object system, and a standalone native solver package remain v2 architecture work.
- GitHub/R-universe publication belongs to Phase 7.

</deferred>

---

*Phase: 4-Public API and Solver Boundaries*
*Context gathered: 2026-09-28*
