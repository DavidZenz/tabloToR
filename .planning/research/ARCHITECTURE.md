# Architecture Research

**Domain:** Brownfield R package productization and compatibility migration
**Researched:** 2026-08-22
**Confidence:** HIGH

## Recommended Architecture

### System Overview

```text
GEModel public compatibility facade
  |
  +-- TABLO compiler
  |     +-- parser/statement IR
  |     +-- legacy generators
  |     `-- sparse numeric templates
  |
  +-- model runtime
  |     +-- immutable source data
  |     +-- mutable simulation state
  |     `-- closure/shock/output contracts
  |
  `-- solver registry
        +-- legacy reference
        +-- Matrix sparse reference
        +-- structured R reference
        `-- optional structured C++ backend
```

The initial successor should remain a single package. Productization should create explicit internal boundaries and a solver registry without forcing a premature package split or public object rewrite.

## Component Responsibilities

| Component | Responsibility | Existing Basis |
|-----------|----------------|----------------|
| Public facade | Stable `GEModel` lifecycle and compatibility | `R/GEModel.R` |
| Parser/compiler | TABLO syntax to legacy generators and sparse IR | `R/process*.R`, `R/sparseCompiler.R` |
| Indexed runtime | Sets, columns, rows, state, updates, outputs | `R/sparseSolver.R` |
| Solver registry | Capability checks and explicit backend dispatch | Currently distributed across solver/wrapper files |
| Structured solver | GTAP-aware partition, Schur operator, FGMRES | `R/sparsePartition.R`, `R/sparseSchur*.R` |
| Native kernels | Sparse solve, accumulation, LAPACK factors | `src/` and `R/zzzSparseSchurCpp.R` |
| Verification layer | Residuals, equivalence, memory/performance gates | `tests/`, `benchmarks/` |

## Migration Pattern

### Strangler-by-contract

1. Inventory and test the existing public surface.
2. Introduce explicit internal backend registration behind unchanged methods.
3. Rename package/native identity mechanically with dual-name compatibility decisions documented.
4. Narrow exports only after tests identify supported symbols.
5. Deprecate or remove internals in later versions, not during the first rename.

This avoids a simultaneous rename, API redesign, and solver refactor—the combination most likely to create untraceable numerical divergence.

## Recommended Package Structure

```text
R/
  api-*.R                 # GEModel and documented helpers
  compiler-*.R            # TABLO parser and IR
  runtime-*.R             # sparse state, updates, outputs
  solver-*.R              # registry and generic contracts
  solver-matrix.R         # portable sparse reference
  solver-structured-r.R   # structured correctness reference
  solver-structured-cpp.R # native adapter/capabilities
src/                      # registered native implementation
tests/testthat/           # unit and compatibility contracts
tests/fixtures/           # redistributable fixtures
benchmarks/               # external long-running gates
vignettes/                # user, migration, architecture guides
```

This is a target organization, not a required one-shot file move. Refactor by subsystem with tests and focused commits.

## Key Data Flows

1. **Compilation:** TABLO text → parsed statements → sparse numeric specification plus optional legacy generators.
2. **Preparation:** HAR-derived lists → validated source arrays → indexed mutable runtime state.
3. **Solve:** closure + sparse shocks → sparse triplets/RHS → explicit backend → true-residual gate → streamed updates.
4. **Output:** selected/full variables → labels generated only at the output boundary.
5. **Benchmark:** isolated installed package + signed model inputs → result artifacts → correctness/performance gate.

## Internal Boundaries

- Backend adapters receive a sparse system/partition/control contract and return solution plus diagnostics; they do not mutate the model directly.
- The runtime applies a solution only after residual validation.
- GTAP-specific partitioning remains optional and identifiable; generic TABLO models retain Matrix/SparseM paths.
- Native pointers and workspaces remain solve-scoped; only serializable structural metadata can enter model state.

## Release Architecture

- GitHub is the source and issue tracker.
- GitHub Actions runs standard package checks across major platforms plus targeted native/serial jobs.
- R-universe builds binaries and serves the first public repository after legal clearance.
- Full GTAP benchmarks run manually/on a controlled high-memory machine and attach compact signed summaries, never proprietary data.

## Anti-Patterns

- **Big-bang rewrite:** obscures whether regressions come from identity, API, compiler, or solver changes.
- **Late compatibility shim:** renaming first and testing compatibility afterward misses hidden exported behavior.
- **Backend-by-load-order as permanent architecture:** `zzz*` wrapping is acceptable during transition but should become explicit dispatch.
- **Direct Matrix internals without a contract check:** keep runtime self-tests and CI version coverage.

## Sources

- [Writing R Extensions](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html) — package/native boundaries and portability.
- [Roxygen2 namespace guidance](https://roxygen2.r-lib.org/articles/namespace.html) — explicit API exports.
- [r-lib/actions](https://r-lib.github.io/actions/) — multi-platform R package CI.
- Existing `.planning/codebase/ARCHITECTURE.md` and public solver-contract tests.

---
*Architecture research for: GEModelR*
*Researched: 2026-08-22*
