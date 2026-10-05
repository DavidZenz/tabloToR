# Phase 4: Public API and Solver Boundaries - Pattern Map

**Mapped:** 2026-09-29  
**Files analyzed:** 10 likely implementation and contract-test touchpoints  
**Analogs found:** 9 / 10

The phase artifacts define architectural contracts but do not give a definitive changed-file list. The table maps likely touchpoints inferred from CONTEXT.md and RESEARCH.md. The new `man/GEModel.Rd` topic is a documentation target if generated help is split out; it can instead be combined into the package topic. A separate backend registry file is optional and has no existing direct analog.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `R/GEModel.R` | controller | request-response | `R/GEModel.R` | exact |
| `R/sparseSolver.R` | service | request-response, transform | `R/sparseSolver.R` | exact |
| `R/zzzSparseSchurCpp.R` | service | request-response | `R/zzzSparseSchurCpp.R` | exact |
| `R/zzzzzSchurDiagnostics.R` | utility | transform, request-response | `R/zzzzzSchurDiagnostics.R` | exact |
| `NAMESPACE` | config | request-response contract | `NAMESPACE` | role-match; current export directive is the behavior being replaced |
| `man/GEModelR-package.Rd` | config (generated documentation) | request-response contract | `man/GEModelR-package.Rd` | role-match; existing aliases/details are stale |
| `man/GEModel.Rd` (or equivalent generated topic) | config (generated documentation) | request-response | `man/GEModelR-package.Rd` | partial; no dedicated class topic exists |
| `tests/testthat/test-public-solver-contract.R` | test | request-response | same file | exact |
| `tests/testthat/test-documented-workflow.R` | test | request-response | same file | exact |
| `tests/testthat/test-public-cpp-backend.R` | test | request-response | same file | exact |

## Pattern Assignments

### `R/GEModel.R` (controller, request-response)

**Analog:** `R/GEModel.R` — `GEModel` is already the reference-class facade. Keep user workflow and state mutation on this object; delegate solver internals to private helpers.

**Facade and solver-relevant fields** (lines 7-35):

```r
GEModel = setRefClass(
  "GEModel",
  fields = list(
    shocks = "numeric",
    skeletonGenerator = 'function',
    sparseSkeletonGenerator = 'function',
    equationCoefficientMatrixGenerator = 'function',
    equationCoefficientGenerator = 'function',
    generateVariables = 'function',
    generateUpdates = 'function',
    data = 'list',
    solution = 'numeric',
    changeVariables = 'character',
    variables = 'character',
    basicChangeVariables = 'character',
    variableValues = 'list',
    tabloStatements = 'list',
    sparseSpec = 'list',
    sparseIndex = 'list',
    sparseState = 'environment',
    loadedEngine = 'character',
    closure = 'character',
    explicitShocks = 'list',
    sourceData = 'list',
    memoryBudget = 'numeric',
    lastDiagnostics = 'list',
    compactOutput = 'list',
    .postsimRecord = 'list'
  ),
  methods = list(
```

**Lifecycle and validation** (`loadData`, lines 74-120):

```r
loadData = function(inputData, engine = c("legacy", "sparse")) {
  engine = match.arg(engine)
  .postsimRecord <<- list()
  source_record = sourceData
  source_record$loaded_data = inputData
  source_record$data_fingerprint =
    .serialization_object_fingerprint(inputData)
  if (engine == "sparse" && length(sparseSpec$compile_errors)) {
    errors = unique(as.character(sparseSpec$compile_errors))
    stop(sprintf(
      "Sparse TABLO compilation failed for %s equation(s): %s",
      length(errors), paste(errors, collapse = "; ")
    ), call. = FALSE)
  }
```

The solver entry point also uses `match.arg(engine)` and forwards sparse requests through `sparse_solve_model(.self, ...)` (`solveModel`, lines 277-294). Preserve the documented `loadTablo()`, `setClosure()`, `loadData()`, `setShocks()`, `solveModel()` sequence and the `variableValues` compatibility workflow. Setters currently delegate: `setShocks()` stores the values and normalized labels; `setClosure()` calls `sparse_set_closure_state()` (lines 121-126).

**Error/lifecycle limitation:** current facade failures use `stop(..., call.=FALSE)`; there are no GEModelR condition subclasses yet. Sparse solve validates that an index exists, but there is not a complete, shared engine-state validator at the facade boundary. Use the facade shape, while adding the locked lifecycle checks and stable conditions centrally.

### `R/sparseSolver.R` (service, request-response and transform)

**Analog:** this file owns current backend selection, the one-step solve, candidate acceptance, output projection, and transaction boundary. Keep the backend adapter contract private here or in a small helper; do not let adapters mutate `GEModel` state.

**Candidate acceptance** (`.sparse_accept_candidate`, lines 1520-1622):

```r
required = c("backend", "solution", "coefficient_matrix", "rhs")
missing_fields = setdiff(required, names(candidate))
if (!is.list(candidate) || length(missing_fields)) {
  stop(sprintf(
    "Sparse candidate is missing field(s): %s",
    paste(missing_fields, collapse = ", ")
  ), call. = FALSE)
}
coefficient_matrix = candidate$coefficient_matrix
if (!inherits(coefficient_matrix, "sparseMatrix")) {
  stop("Sparse candidate coefficient matrix must remain sparse",
       call. = FALSE)
}
finite = all(is.finite(candidate$solution)) &&
  all(is.finite(candidate$rhs)) &&
  all(is.finite(coefficient_matrix@x))
```

The same gate calculates the true residual with `sparse_true_residual()`, rejects candidates over tolerance, and sets `output_structure`, `finite`, `true_residual`, and `accepted` before returning. D-08 extends this natural central boundary: adapters should also provide structural metadata, timing, and cleanup evidence, while the central gate remains responsible for validation and the only commit path.

**One-step dispatch** (`.sparse_solve_one_step_impl`, lines 2128-2230) builds the sparse matrix, selects the Matrix/SparseM/SuiteSparse or structured R solve, creates a candidate, and calls `.sparse_accept_candidate()`. Current selection is explicit and `match.arg()` validates backend IDs; retain requested and actual backend identity in the result and diagnostics. Do not copy the current order blindly for D-06: research identifies that native preflight must happen before matrix construction.

**Output projection** (`sparse_project_outputs`, lines 1986-1994):

```r
if (is.null(variables) || !length(variables)) {
  variables = character()
}
variables = tolower(sub("\\[.*$", "", as.character(variables)))
variables = intersect(unique(variables), names(data))
result = list()
for (name in variables) {
  result[[name]] = sparse_subset_output(data[[name]], dimensions)
}
```

This is the closest projection analog, but `intersect()` silently drops unknown names. Replace that behavior with pre-projection validation for unknown variables/dimensions and selection-size limits; preserve explicit empty selections.

**Failure boundary** (`sparse_solve_model`, lines 2525-2557) delegates into `.sparse_solve_model_impl()` and catches failures to store transaction diagnostics. It preserves an already accepted numerical state using the `GEModelR.accepted_numerical_state` attribute. Follow this wrapper pattern for cleanup/failure classification, then attach stable condition classes without relying on message parsing.

### `R/zzzSparseSchurCpp.R` (service, request-response and resource lifecycle)

**Analog:** private native adapter and runtime. The `zzz` file layering captures the prior implementation before wrapping it; use the same technique when extending an existing helper, and keep generated `R/RcppExports.R` wrappers internal.

**Capability preflight** (`.sparse_schur_cpp_require_impl`, lines 30-120):

```r
fail = function(message) {
  stop(sprintf(
    paste0(
      "backend='StructuredSchurFGMRESCpp' initialization failed: %s. ",
      "No fallback was attempted."
    ), message
  ), call. = FALSE)
}
if (is.na(threads) || threads < 1L) fail("thread count must be positive")
missing = .sparse_schur_cpp_symbols[!vapply(
  .sparse_schur_cpp_symbols,
  is.loaded, logical(1), PACKAGE = "GEModelR"
)]
if (length(missing)) {
  fail(sprintf("registered native routine is missing: %s", missing[[1L]]))
}
```

The full preflight checks wrapper arity, ABI, capability payload, required kernels, a deterministic Matrix comparison, and requested thread limits. Preserve its fail-closed shape and requested backend in errors; change condition construction to use the new stable class contract.

**Backend boundary and cleanup** (`sparse_solve_model`, lines 578-620):

```r
.sparse_solve_model_reference = sparse_solve_model
sparse_solve_model = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix",
                              reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  if (!identical(backend, "StructuredSchurFGMRESCpp")) {
    return(.sparse_solve_model_reference(
      model, iter, steps, postsim, diagnostics, output, variables,
      dimensions, backend, reduction, memory_budget
    ))
  }
  .identity_guard_old_options("tabloToR.sparse.schur_cpp_threads")
  threads = getOption("GEModelR.sparse.schur_cpp_threads", 1L)
  capabilities = .sparse_schur_cpp_runtime$require(
    expected_abi = 1L, threads = threads
  )
  .sparse_schur_cpp_runtime$active = TRUE
  on.exit({
    .sparse_schur_cpp_runtime$active = FALSE
    .sparse_schur_cpp_runtime$state = NULL
    .sparse_schur_cpp_runtime$index_key = NULL
    .sparse_cpp_release_live_factors()
  }, add = TRUE)
```

Preflight occurs before the wrapper activates runtime state and before delegating to the implementation that constructs the matrix. The `on.exit()` block releases numerical resources and clears temporary runtime ownership on either success or error. Structural cache metadata is deliberately stored separately on the model state.

### `R/zzzzzSchurDiagnostics.R` (utility, transform and request-response)

**Analog:** late diagnostics wrapper for structured solvers. It captures the previous solver entry point, delegates, then decorates the result; private telemetry uses a small environment and resets active state with `on.exit()` (`sparse_exact_schur_build`, lines 40-92).

**Diagnostics wrapper** (lines 121-159):

```r
.sparse_solve_model_diagnostics_dispatch = sparse_solve_model
sparse_solve_model = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix", reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  result = .sparse_solve_model_diagnostics_dispatch(
    model, iter, steps, postsim, diagnostics, output, variables,
    dimensions, backend, reduction, memory_budget
  )
  if (isTRUE(diagnostics)) {
    model$lastDiagnostics$diagnostics_schema_version = 2L
```

This layer already centralizes optional diagnostic enrichment and preserves the solver return invisibly. D-15 changes the storage contract: write the small versioned envelope after every solve, then add the detailed telemetry only when requested. Current schema version is only added in the detailed branch, so this is a behavior to change, not copy unchanged.

### `NAMESPACE` (config, request-response contract)

**Analog:** current namespace lines 1-6. Preserve native registration and only necessary imports, but replace the alphabetic export rule with explicit public exports after the compatibility-manifest audit.

```r
useDynLib(GEModelR, .registration=TRUE)
importFrom(Rcpp, evalCpp)
exportPattern("^[[:alpha:]]+")
importFrom(methods, new)
importFrom(stats, setNames)
importFrom(utils, object.size)
```

`exportPattern()` is the unwanted behavior and must not be copied. The phase recommendation is `GEModel` only unless the audit proves a deliberate helper belongs in the public facade. Keep `.GEModelR_*` native wrappers private.

### `man/GEModelR-package.Rd` and generated `man/GEModel.Rd` (documentation config, request-response)

**Closest existing file:** `man/GEModelR-package.Rd` (186 lines). It is an export index, not a useful per-method documentation pattern: it aliases many parser/compiler/solver internals, and its details say API narrowing is deferred (lines 1-8, 173-184). Remove stale aliases when regenerating package help. There is no dedicated GEModel reference-class topic in `man/`, so a new `GEModel` topic or equivalent package-level section has no direct analog.

`R/main.R` contains a legacy commented block beginning `#' #' @export` (lines 1-3); it is not a reliable roxygen pattern. Add valid roxygen tags for the facade/options and generate Rd rather than preserving its malformed comment form or hand-maintaining a helper alias catalogue.

### `tests/testthat/test-public-solver-contract.R` (test, request-response)

**Analog:** same file, 44 lines. Use small synthetic models, direct contract assertions, and deterministic monkey-patching for preflight failures.

```r
runtime <- .sparse_schur_cpp_runtime
old_require <- runtime$require
runtime$require <- function(...) stop("injected preflight failure",
                                      call. = FALSE)
on.exit(runtime$require <- old_require, add = TRUE)
before <- sparse_state_data(model$sparseState)

expect_error(
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    backend = "StructuredSchurFGMRESCpp"
  ),
  "injected preflight failure"
)
expect_identical(sparse_state_data(model$sparseState), before)
expect_false(isTRUE(runtime$active))
```

Update the current exact-export assertion: it presently expects `solve_sparse_system` and `sparse_exact_schur_solve` to be public (lines 39-44). Add coverage for deliberate exports, preflight-before-mutation, error classes, and the always-present diagnostic envelope.

### `tests/testthat/test-documented-workflow.R` (test, request-response)

**Analog:** same file. It uses a small redistributable fixture and helper-built models to freeze the public workflow, state transitions, full/compact output structures, and legacy compatibility. A representative public call is:

```r
model$solveModel(
  iter = 1, steps = 1, engine = "sparse",
  postsim = TRUE, diagnostics = TRUE, output = "compact",
  variables = "stock", dimensions = list(reg = "south"),
  backend = "Matrix", reduction = "off"
)
```

Add strict selector tests beside the existing full/compact selection cases (lines 218-336), including unknown variable/dimension errors and explicit empty selections. Keep assertions on the established `GEModel` workflow and compatibility structure.

### `tests/testthat/test-public-cpp-backend.R` (test, request-response)

**Analog:** same file, currently a compact reference-vs-C++ numerical-equivalence test. It verifies an explicitly selected C++ backend, backend identity in diagnostics, residual bounds, and absence of retained pointers. Extend it for the internal adapter/result contract, requested-versus-actual identity, preflight ordering, and cleanup after errors; keep the structured R implementation as the authority/reference.

## Shared Patterns

### Facade and mutation boundary

**Sources:** `R/GEModel.R:9-35, 74-126, 277-294`  
**Apply to:** public workflow and lifecycle changes.

Keep public mutations on `GEModel` methods. Existing `setClosure()`/`setShocks()` delegate to focused state helpers. Preserve `variableValues` as the supported legacy workflow, but avoid expanding support for direct compiler/index/cache field mutation.

### Backend identity, preflight, and acceptance

**Sources:** `R/zzzSparseSchurCpp.R:30-120, 578-620`; `R/sparseSolver.R:1520-1622, 2128-2230`  
**Apply to:** every backend adapter and the central orchestrator.

Preflight the requested adapter before system construction or model mutation. Adapters produce candidates; the central accept gate checks sparse structure, finite values, solution structure, and true residual before the state-commit path. Keep requested backend ID separate from implementation ID; there is no automatic fallback.

### Resource ownership and temporary state

**Sources:** `R/zzzSparseSchurCpp.R:506-535, 579-620`; `R/zzzzzSchurDiagnostics.R:40-92`  
**Apply to:** factors, RHS/numerical buffers, native runtime activation, and timing instrumentation.

Use `on.exit(..., add = TRUE)` for runtime flags, temporary owner references, and native factor release. Keep validated structural cache data distinct from per-solve numerical resources.

### Errors, conditions, and diagnostics

**Sources:** `R/sparseSolver.R:38-65, 2525-2557`; `R/zzzzzSchurDiagnostics.R:121-159`  
**Apply to:** capability, validation, numerical, and post-simulation outcomes.

Existing code creates plain errors and transaction metadata; it has no stable GEModelR condition-class pattern. Retain the structured fields and failure phases as the data source, then add explicit classes and the small versioned envelope locked by D-15/D-16. Do not make callers parse the message text.

### Options and strict validation

**Sources:** `R/sparseSuiteSparse.R:19-40`; `R/zzzSparseSchurCpp.R:30-120, 313-320`; `R/sparseSolver.R:2134-2145`  
**Apply to:** supported `GEModelR.*` options only.

Existing controls use `getOption(name, default)`, explicit integer/range checks, and actionable `stop(..., call.=FALSE)` errors. `sparse_suite_sparse_ordering()` demonstrates a named allowlist and rejects unsupported values. Do not document every prefixed option: keep transaction/fault hooks and cache settings private.

## No Analog Found

| File or contract | Role | Data Flow | Reason |
|------------------|------|-----------|--------|
| `R/sparseBackendRegistry.R` (only if a separate file is chosen) | service | request-response | No backend registry exists. The closest pattern is the explicit branch in `R/sparseSolver.R`; research recommends avoiding a new top-level subsystem unless separation is needed. |
| Stable GEModelR condition subclasses | utility | request-response | Existing failures use plain `stop()` calls and diagnostic attributes; no class taxonomy exists to copy. |
| Dedicated `man/GEModel.Rd` and supported-options topic | config (generated documentation) | request-response | The repository has only an aggregate package Rd file with stale broad aliases. |

## Metadata

**Analog search scope:** `R/`, `NAMESPACE`, `man/`, and relevant `tests/testthat/` contract/workflow/native-backend files.  
**Files scanned:** 10 likely touchpoints plus supporting `R/sparseSuiteSparse.R`, `R/main.R`, and `DESCRIPTION`.  
**Pattern extraction date:** 2026-09-29
