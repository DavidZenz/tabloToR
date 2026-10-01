# Phase 05: Portable Native Build and CI - Pattern Map

**Mapped:** 2026-10-01  
**Files analyzed:** 16 target files  
**Analogs found:** 15 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/R-CMD-check.yaml` | config | build-time | None | none |
| `.Rbuildignore` | config | build-time | `.Rbuildignore` | exact |
| `DESCRIPTION` | config | build-time | `DESCRIPTION` | exact |
| `README.md` | utility (package documentation) | transform | `R/apiDocumentation.R` | role-match |
| `R/sparseElimination.R` | utility (native bridge) | transform | `R/RcppExports.R` | role-match |
| `R/sparseSuiteSparse.R` | service (solver backend) | transform | `R/sparseSolver.R` backend registry | role-match |
| `R/sparseSolver.R` | service (solver dispatch) | request-response | `R/sparseSolver.R` | exact |
| `R/apiDocumentation.R` | utility (package documentation) | transform | `R/apiDocumentation.R` | exact |
| `src/Makevars` | config | build-time | `src/Makevars.win` | exact |
| `src/Makevars.win` | config | build-time | `src/Makevars` | exact |
| `tests/testthat/test-sparse-schur-openmp.R` | test | transform | same file | exact |
| `tests/testthat/test-public-cpp-backend.R` | test | request-response | same file | exact |
| `tests/testthat/test-public-solver-contract.R` | test | request-response | same file | exact |
| `tests/testthat/test-sparse-core.R` | test | transform | same file | exact (harness only) |
| `tests/testthat/test-api-documentation.R` | test | transform | same file | exact |
| `tests/testthat/test-native-portability.R` | test | file-I/O | `tests/testthat/test-installed-benchmark-execution.R` | role-match |

`DESCRIPTION` is implied by D-08 through D-10: it currently imports Matrix without a minimum version. `README.md` and `test-sparse-core.R` are also implied by D-13 and the existing documented SuiteSparse solve path/test. The new native portability test is proposed in RESEARCH.md.

## Pattern Assignments

### `.github/workflows/R-CMD-check.yaml` (config, build-time)

**Analog:** None. No `.github/workflows/` directory or existing workflow file was found.

Define the supported rows explicitly. Each row should identify OS, R, Matrix endpoint, and native expectation. Keep the expected OpenMP capability as a job input so an OpenMP row fails if capability is false; a serial row must assert false capability and a maximum of one thread. Run the same selected rows for pull requests, default-branch pushes, and the weekly schedule. Use the package install and installed test commands from RESEARCH.md; keep the representative full package check visibly separate from portability results.

### `.Rbuildignore` (config, build-time)

**Analog:** `.Rbuildignore`

**Archive exclusion pattern** (lines 1-7):

```text
^\.benchmark-data$
^\.git$
^\.planning$
^\.Rcheck$
^\.Rproj.user$
^benchmarks/\.
^rcpp-solver-acceleration-plan\.md$
```

If the source archive must exclude workflow metadata, add an exclusion here using the same anchored regular-expression style. The current file does not exclude `.github`.

### `DESCRIPTION` (config, build-time)

**Analog:** `DESCRIPTION`

**Dependency declaration** (lines 21-30):

```text
Imports:
    Matrix,
    Rcpp,
    SparseM,
    methods
LinkingTo:
    Rcpp
Suggests:
    testthat
Config/testthat/edition: 3
```

Use the existing `Imports` syntax for the selected Matrix lower bound. RESEARCH.md treats 1.6-5 as a candidate only; record the floor after confirming the oldest supported R/platform cells can install and pass the solver contract.

### `README.md` (utility, package documentation; transform)

**Analog:** `R/apiDocumentation.R`

The current user-facing text describes SuiteSparse as a usable optional solver and gives a solve example (README.md lines 181-188). Update that documentation consistently with the package-level backend list: retain `SuiteSparse` as a recognized ID, explain that supported installed builds report it unavailable pending portable support, and show explicit `backend = "Matrix"` remediation. Do not retain the current example as a supported installed workflow.

### `R/sparseElimination.R` (utility, native bridge; transform)

**Analog:** `R/RcppExports.R`

**Installed generated wrapper pattern** (lines 16-22):

```r
GEModelR_eliminate_blocks <- function(matrix_sexp, rhs, row_group, column_group, n_groups, pivot_tolerance) {
    .Call(`_GEModelR_GEModelR_eliminate_blocks`, matrix_sexp, rhs, row_group, column_group, n_groups, pivot_tolerance)
}

GEModelR_reconstruct_blocks <- function(matrix_sexp, rhs, reduced_solution, row_group, column_group, n_groups, pivot_tolerance) {
    .Call(`_GEModelR_GEModelR_reconstruct_blocks`, matrix_sexp, rhs, reduced_solution, row_group, column_group, n_groups, pivot_tolerance)
}
```

Route structured elimination through these package DLL wrappers. `R/sparseElimination.R` lines 3-45 currently searches the old `tabloToR` package identity and can call `Rcpp::sourceCpp()`; do not copy that loader. Keep the generated wrappers generated, rather than editing `R/RcppExports.R` or the registration table by hand.

### `R/sparseSuiteSparse.R` (service, solver backend; transform)

**Analog:** `R/sparseSolver.R` structured backend registry and unavailable helper.

**Structured capability error pattern** (`R/sparseSolver.R`, lines 59-70):

```r
.sparse_backend_unavailable = function(requested_backend, cause,
                                       remediation) {
  message = sprintf(
    "Requested backend '%s' is unavailable: %s. Remediation: %s",
    requested_backend, cause, remediation
  )
  stop(.gemodelr_solve_condition(
    simpleError(message), "sparse", requested_backend,
    primary_class = "GEModelR_capability_error",
    failure_phase = "capability-preflight",
    remediation = list(action = remediation)
  ))
}
```

The current `sparse_suite_sparse_available()` checks hard-coded Linux paths, and `sparse_suite_sparse_solver()` can invoke `Rcpp::sourceCpp()` (lines 3-13 and 89-138). Remove those paths from supported installed behavior. Preserve the recognized ID in the registry and fail in preflight with a cause that names SuiteSparse and remediation that says `backend="Matrix"`.

### `R/sparseSolver.R` (service, solver dispatch; request-response)

**Analog:** the existing SuiteSparse registry entry in this file.

**Current registry and preflight shape** (lines 145-167):

```r
.sparse_backend_registry$SuiteSparse = list(
  requested_backend = "SuiteSparse",
  implementation = "solve_sparse_system(SuiteSparse/UMFPACK)",
  preflight = function(requested_backend = "SuiteSparse", ...) {
    if (!exists("sparse_suite_sparse_available", mode = "function",
                inherits = TRUE) ||
        !isTRUE(sparse_suite_sparse_available())) {
      .sparse_backend_unavailable(
        requested_backend,
        "Rcpp or a supported 64-bit SuiteSparse/UMFPACK installation is unavailable",
        paste(
          "install Rcpp and SuiteSparse with umfpack.h and libumfpack,",
          "or select another explicit backend"
        )
      )
    }
```

Replace host-file detection with the locked always-unavailable installed contract and use the exact explicit Matrix remediation. Preserve the existing public selector so the request reaches preflight as `"SuiteSparse"`.

**Preflight-before-matrix pattern** (lines 3182-3203):

```r
.sparse_solve_one_step_impl = function(state, model, index, shocks, backend,
                                 reduction, measure = FALSE,
                                 structured_partition = NULL,
                                 candidate_transform = NULL) {
  backend_preflight = .sparse_backend_preflight(
    backend, model = model, structured_partition = structured_partition
  )
  ...
  emitted = sparse_emit_system(state, index, shocks)
```

Keep unavailable backend checks ahead of `sparse_emit_system()` and model-state changes.

### `R/apiDocumentation.R` (utility, package documentation; transform)

**Analog:** `R/apiDocumentation.R`

**Backend list** (lines 50-66):

```r
#' @section Runtime engines and sparse backends:
#' The \code{engine} argument chooses the model runtime: \code{legacy} uses the
#' established in-memory solver and \code{sparse} uses sparse execution. The
#' sparse \code{backend} argument independently chooses a solver implementation
#' and defaults to \code{"Matrix"}. The supported backend identifiers and
#' tiers are:
#' \describe{
#'   \item{\code{Matrix}}{Supported general sparse backend and default.}
#'   \item{\code{StructuredSchur} and
#'     \code{StructuredSchurFGMRES}}{Supported structured R backends.}
#'   \item{\code{SparseM}, \code{SuiteSparse}, and
#'     \code{StructuredSchurFGMRESCpp}}{Compatibility-only backend requests.}
#' }
```

Keep the roxygen-to-generated-help convention. Clarify SuiteSparse's recognized-but-unavailable status in this list and preserve the existing explicit-backend/fail-closed language around it. `tests/testthat/test-api-documentation.R` is the adjacent assertion pattern for package help text.

### `src/Makevars` and `src/Makevars.win` (config, build-time)

**Analogs:** each platform file mirrors the other.

**Compile and link flags** (`src/Makevars:1-2`, identical in `src/Makevars.win:1-2`):

```make
PKG_CXXFLAGS = $(SHLIB_OPENMP_CXXFLAGS)
PKG_LIBS = $(SHLIB_OPENMP_CXXFLAGS) $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)
```

Keep R's OpenMP macro in both compile and link flags. Make a job-local serial override in CI and verify the installed capability payload; do not infer serial/OpenMP mode from flags or skip counts alone.

### `tests/testthat/test-sparse-schur-openmp.R` (test, transform)

**Analog:** same file.

**Current capability gate and serial/two-thread comparison** (lines 1-4, 24-41):

```r
test_that("bounded OpenMP Schur batches match serial execution", {
  capabilities <- .GEModelR_schur_cpp_capabilities()
  skip_if_not(isTRUE(capabilities$openmp))
  fixture <- make_cpp_schur_fixture()
  ...
  expect_equal(parallel$regional, serial$regional, tolerance = 1e-10)
  expect_equal(parallel$global_region, serial$global_region,
               tolerance = 1e-10)
  expect_equal(parallel$diagnostics$threads_effective, 2L)
```

Keep the deterministic fixture and parity tolerances. Make the test distinguish an expected OpenMP row from an explicitly serial row: an expected OpenMP row must fail if capability is false or `max_threads < 2`; only a serial row may skip parallel-only assertions. Report timing without a speedup gate.

### `tests/testthat/test-public-cpp-backend.R` (test, request-response)

**Analog:** same file.

**Capability and effective-thread assertions** (lines 56-66):

```r
expect_true(candidate$lastDiagnostics$capability_evidence$available)
expect_identical(
  candidate$lastDiagnostics$effective_thread_count,
  candidate$lastDiagnostics$native$threads_effective_max
)
expect_true(length(candidate$lastDiagnostics$true_residual_history) > 0L)
expect_lte(candidate$lastDiagnostics$max_full_relative_residual, 2e-7)
```

Reuse the public solve fixture/diagnostics pattern for native capability visibility, bounded effective threads, and serial/two-thread correctness. Preserve the one-thread default.

### `tests/testthat/test-public-solver-contract.R` (test, request-response)

**Analog:** same file.

**Fail before emission and preserve state** (lines 529-545; current native-backend contract):

```r
error <- tryCatch(model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    backend = "StructuredSchurFGMRESCpp"
  ), error = identity)
expect_match(
  conditionMessage(error),
  "Requested backend 'StructuredSchurFGMRESCpp'.*injected preflight failure.*Remediation:"
)
expect_identical(class(error)[[1L]], "GEModelR_capability_error")
expect_false(emitted)
expect_identical(sparse_state_data(model$sparseState), before)
```

Use this contract for explicit SuiteSparse rejection: assert the ID and `backend="Matrix"` remediation, prove matrix emission/runtime compilation were not reached, and compare model state before/after.

### `tests/testthat/test-sparse-core.R` (test, transform)

**Analog:** same file.

**Existing SuiteSparse success path** (lines 280-294):

```r
test_that("SuiteSparse backend uses sparse LU without densifying", {
  skip_if_not(sparse_suite_sparse_available())
  ...
  solution <- solve_sparse_system(
    A, c(5, 4), backend = "SuiteSparse", reduction = "off"
  )
  expect_equal(solution, c(1.5, 2), tolerance = 1e-12)
})
```

This is an old success-path assumption, not a behavior to copy. Replace it with an unavailable-capability assertion if this low-level test remains; covered behavior must match the public fail-closed contract.

### `tests/testthat/test-api-documentation.R` (test, transform)

**Analog:** same file.

**Generated help contract** (lines 28-37, 63-72):

```r
help_text <- paste(rd_text(package_rd), rd_text(class_rd))
backend_ids <- c(
  "Matrix", "SparseM", "SuiteSparse", "StructuredSchur",
  "StructuredSchurFGMRES", "StructuredSchurFGMRESCpp"
)
for (contract_item in c(supported_methods, backend_ids, option_defaults,
                        diagnostic_fields, diagnostic_statuses,
                        condition_classes, ...)) {
  expect_true(grepl(contract_item, help_text, fixed = TRUE))
}
```

Keep parsing the generated Rd and asserting public contract strings. Extend the assertions to require the recognized/unavailable SuiteSparse wording and explicit Matrix remediation.

### `tests/testthat/test-native-portability.R` (test, file-I/O)

**Analog:** `tests/testthat/test-installed-benchmark-execution.R`

**Isolated build/install fixture** (lines 46-96):

```r
benchmark_gap_build_install = function() {
  source_root = benchmark_gap_source_root()
  root = tempfile("GEModelR-installed-benchmark-")
  build_root = file.path(root, "build")
  library = file.path(root, "library")
  workdir = file.path(root, "unrelated-working-directory")
  ...
  install = benchmark_gap_process(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", paste0("--library=", shQuote(library)),
      shQuote(archives[[1L]])),
    directory = build_root
  )
```

Reuse the temporary-library/unrelated-working-directory setup to prove installed behavior without source-tree discovery. The focused test should make `Rcpp::sourceCpp()` fail if reached, check installed capability and thread bounds for the selected job expectation, and assert SuiteSparse fails before emission or state mutation. CI can then use `R CMD INSTALL --preclean --install-tests .` and `testthat::test_package()` as described in RESEARCH.md.

---

## Shared Patterns

### Optional OpenMP build and runtime capability

**Sources:** `src/Makevars:1-2`, `src/sparse-lu.cpp:13-32`, `R/zzzSparseSchurCpp.R:140-152`, `tests/testthat/test-sparse-schur-openmp.R:1-41`  
**Apply to:** build variants, CI assertions, and native tests.

Use R's compile-and-link macros, report the capability from the installed DLL, bound requests against `max_threads`, and compare serial and two-thread results. Preserve the one-thread default and never accept an expected OpenMP test that only skipped.

### Backend preflight and structured errors

**Sources:** `R/sparseSolver.R:59-70,145-167,3182-3203`; `tests/testthat/test-public-solver-contract.R:511-557`  
**Apply to:** explicit optional backend requests.

Keep the requested backend ID, capability cause, and actionable remediation in `GEModelR_capability_error`. Run preflight before matrix emission and before model-state mutation. SuiteSparse remediation must explicitly say `backend="Matrix"`.

### Installed native calls

**Sources:** `R/RcppExports.R:16-22`; `tests/testthat/test-installed-benchmark-execution.R:46-98`  
**Apply to:** structured elimination and installed-package coverage.

Call registered package DLL wrappers generated by Rcpp. Keep compile work at install time and run portability checks from a temporary working directory, outside the source checkout.

### Package and help metadata

**Sources:** `DESCRIPTION:21-30`, `R/apiDocumentation.R:50-66`, `tests/testthat/test-api-documentation.R:28-72`  
**Apply to:** Matrix support floor and backend documentation.

Keep dependency declarations in `Imports`, user-facing backend statements in roxygen, and generated-help assertions in testthat. Treat the Matrix minimum as unresolved until the selected old-R install evidence supports it.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/workflows/R-CMD-check.yaml` | config | build-time | No existing GitHub Actions workflow or `.github/workflows/` directory exists. Use the matrix and installed-test requirements in `05-RESEARCH.md`. |

## Metadata

**Analog search scope:** `R/`, `src/`, `tests/testthat/`, root package metadata, and `.github/` presence.  
**Files scanned:** Focused searches around native build flags, backend registration/preflight, Rcpp compilation, SuiteSparse references, OpenMP tests, installed-package tests, and package documentation.  
**Pattern extraction date:** 2026-10-01
