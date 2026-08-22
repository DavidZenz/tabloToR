---
last_mapped: 2026-08-22
---

# Architecture

## Overall Pattern

The package is a compiler-plus-runtime. TABLO text is parsed into statements, transformed into either legacy generators or a compact sparse specification, bound to HAR-derived data, and solved through a `GEModel` reference-class facade.

## Main Layers

1. **Parsing:** `R/tabloToStatements.R` and `R/process*Statement.R` convert TABLO text into structured statement records.
2. **Legacy generation:** `R/skeletonGenerator.R`, `R/equationMatrixProcessing.R`, `R/coefficientProcessing.R`, and related generators create string-heavy R functions and expanded model structures.
3. **Sparse compilation:** `R/sparseCompiler.R` converts equations, qualifiers, sums, formulas, and updates into compact expression metadata and integer-indexed templates.
4. **Indexed runtime:** `R/sparseSolver.R` owns state construction, closure/shock resolution, triplet emission, sparse system solving, Euler stepping, updates, diagnostics, and outputs.
5. **Structured solving:** `R/sparsePartition.R`, `R/sparseElimination.R`, `R/sparseSchur.R`, and `R/sparseSchurComplement.R` exploit GTAP commodity/region block structure.
6. **Native acceleration:** `R/zzzSparseSchurCpp.R` wraps the R structured algorithm with native sparse solves, fused accumulation, dense factors, caching, and diagnostics implemented in `src/`.

## Public Orchestration

- `R/GEModel.R` stores parsed recipes, source/model state, closure, shocks, diagnostics, and outputs.
- `loadTablo()` attempts both legacy and sparse compilation while retaining compatibility.
- `loadData(engine=)` materializes either legacy expanded state or sparse mutable state.
- `solveModel(engine=, backend=)` keeps `engine="legacy"` and `backend="Matrix"` as defaults; C++ remains opt-in.

## Sparse Data Flow

`loadTablo()` → `sparse_process_tablo()` → `sparseSpec` → `loadData(engine="sparse")` → `sparseIndex`/`sparseState` → closure and nonzero shocks → numeric triplets/RHS → selected sparse backend → residual gate → streamed Euler update → optional post-simulation formulas/output.

## State and Caching

- Immutable input is conceptually separated from mutable arrays through `sparseState`, although the reference class still exposes broad mutable fields.
- Structural index and row layout are rebuilt when closure or dimensions change.
- `StructuredSchurFGMRESCpp` stores reusable structural metadata in `sparseState$.solver_cache`; numeric factors are refreshed as coefficients change.
- Human-readable labels are delayed for diagnostics and requested outputs on the sparse path.
