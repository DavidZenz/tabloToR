test_that("public native backend is opt-in and numerically equivalent", {
  withr::local_options(GEModelR.sparse.schur_cpp_threads = NULL)
  reference <- make_cpp_structured_model()
  candidate <- make_cpp_structured_model()
  partition <- function(index, state) {
    list(
      stages = list(NULL),
      external = sparse_external_block_partition(index, state)
    )
  }

  testthat::with_mocked_bindings(
    reference$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, backend = "StructuredSchurFGMRES",
      output = "compact"
    ),
    sparse_gtap_elimination_partition = partition,
    .package = "GEModelR"
  )
  cpp_adapter <- .sparse_backend_registry$StructuredSchurFGMRESCpp
  original_cleanup <- cpp_adapter$cleanup
  cleanup_results <- list()
  cpp_adapter$cleanup <- function(...) {
    status <- original_cleanup(...)
    cleanup_results[[length(cleanup_results) + 1L]] <<- status
    status
  }
  .sparse_backend_registry$StructuredSchurFGMRESCpp <- cpp_adapter
  withr::defer(
    .sparse_backend_registry$StructuredSchurFGMRESCpp$cleanup <-
      original_cleanup
  )
  testthat::with_mocked_bindings(
    candidate$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, backend = "StructuredSchurFGMRESCpp",
      output = "compact"
    ),
    sparse_gtap_elimination_partition = partition,
    .package = "GEModelR"
  )

  expect_equal(candidate$solution, reference$solution, tolerance = 1e-8)
  expect_equal(candidate$solution, 1:7, tolerance = 1e-8)
  expect_identical(candidate$lastDiagnostics$solver_backend,
                   "StructuredSchurFGMRESCpp")
  expect_identical(candidate$lastDiagnostics$solver_backend_impl, "cpp")
  expect_identical(candidate$lastDiagnostics$schema_version, 1L)
  expect_identical(candidate$lastDiagnostics$engine, "sparse")
  expect_identical(candidate$lastDiagnostics$requested_backend,
                   "StructuredSchurFGMRESCpp")
  expect_identical(candidate$lastDiagnostics$implementation, "cpp")
  expect_identical(candidate$lastDiagnostics$status, "succeeded")
  expect_true(candidate$lastDiagnostics$accepted_numerical_state)
  expect_false(candidate$lastDiagnostics$retryable_postsim)
  expect_true(candidate$lastDiagnostics$capability_evidence$available)
  expect_identical(candidate$lastDiagnostics$effective_thread_count, 1L)
  expect_identical(candidate$lastDiagnostics$native$threads_requested, 1L)
  expect_identical(
    candidate$lastDiagnostics$capability_evidence$native_capabilities$threads_requested,
    1L
  )
  expect_identical(
    candidate$lastDiagnostics$effective_thread_count,
    candidate$lastDiagnostics$native$threads_effective_max
  )
  expect_identical(candidate$lastDiagnostics$cleanup_status$status, "complete")
  expect_identical(
    candidate$lastDiagnostics$cleanup_status$structural_metadata,
    "model-scoped cache retained"
  )
  expect_true(length(candidate$lastDiagnostics$true_residual_history) > 0L)
  expect_true(is.list(candidate$lastDiagnostics$phase_allocations))
  expect_true(is.list(candidate$lastDiagnostics$estimated_memory))
  expect_lte(candidate$lastDiagnostics$max_full_relative_residual, 2e-7)
  expect_false(candidate$lastDiagnostics$dense_fallback)
  expect_false(contains_external_pointer(candidate$lastDiagnostics))
  expect_false(contains_external_pointer(candidate$sparseState))
  expect_gt(length(cleanup_results), 0L)
  expect_identical(tail(cleanup_results, 1L)[[1L]]$status, "complete")
  expect_identical(tail(cleanup_results, 1L)[[1L]]$scope, "solve")
  expect_match(tail(cleanup_results, 1L)[[1L]]$resources, "released")
  expect_identical(
    tail(cleanup_results, 1L)[[1L]]$structural_metadata,
    "model-scoped cache retained"
  )
  cache <- candidate$sparseState$.solver_cache[["StructuredSchurFGMRESCpp"]]
  expect_true(is.list(cache))
  expect_identical(cache$abi, 1L)
  expect_identical(.sparse_schur_cpp_runtime$live_dense_factors, list())

  minimal <- make_cpp_structured_model()
  testthat::with_mocked_bindings(
    minimal$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = FALSE, backend = "StructuredSchurFGMRESCpp",
      output = "compact"
    ),
    sparse_gtap_elimination_partition = partition,
    .package = "GEModelR"
  )
  expect_identical(names(minimal$lastDiagnostics), .gemodelr_diagnostics_fields)
  expect_identical(minimal$lastDiagnostics$requested_backend,
                   "StructuredSchurFGMRESCpp")
  expect_identical(minimal$lastDiagnostics$implementation, "cpp")
  expect_identical(minimal$lastDiagnostics$status, "succeeded")
  expect_identical(minimal$lastDiagnostics$cleanup_status$status, "complete")
  expect_false("native" %in% names(minimal$lastDiagnostics))
  expect_false("true_residual_history" %in% names(minimal$lastDiagnostics))

  failed <- make_cpp_structured_model()
  cleanups_before_error <- length(cleanup_results)
  error <- tryCatch(testthat::with_mocked_bindings(
      failed$solveModel(
        iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
        diagnostics = TRUE, backend = "StructuredSchurFGMRESCpp",
        output = "compact"
      ),
      sparse_gtap_elimination_partition = partition,
      .GEModelR_dense_lu_solve = function(...) {
        stop("injected native factor solve failure", call. = FALSE)
      },
      .package = "GEModelR"
    ), error = identity)
  expect_match(conditionMessage(error), "injected native factor solve failure")
  expect_identical(class(error)[[1L]], "GEModelR_numerical_error")
  expect_identical(error$requested_engine, "sparse")
  expect_identical(error$requested_backend, "StructuredSchurFGMRESCpp")
  expect_identical(error$failure_phase, "candidate-acceptance")
  expect_false(error$accepted_numerical_state)
  expect_true(is.list(error$remediation))
  expect_identical(failed$lastDiagnostics$schema_version, 1L)
  expect_identical(failed$lastDiagnostics$status, "numerical_failed")
  expect_identical(failed$lastDiagnostics$requested_backend,
                   "StructuredSchurFGMRESCpp")
  expect_identical(failed$lastDiagnostics$implementation, "cpp")
  expect_identical(failed$lastDiagnostics$condition_class,
                   "GEModelR_numerical_error")
  expect_identical(failed$lastDiagnostics$cleanup_status$status, "complete")
  expect_true(is.list(failed$lastDiagnostics$capability_evidence))
  expect_gt(length(cleanup_results), cleanups_before_error)
  expect_identical(tail(cleanup_results, 1L)[[1L]]$status, "complete")
  expect_identical(tail(cleanup_results, 1L)[[1L]]$scope, "solve")
  expect_identical(.sparse_schur_cpp_runtime$live_dense_factors, list())
})

test_that("explicit serial jobs preserve default threads and reject over-requests", {
  expectation = nativeOpenmpExpectation()
  capabilities = nativeOpenmpCapabilities(expectation = expectation)
  if (!identical(expectation, "forbidden")) return(invisible(NULL))
  expect_identical(capabilities$openmp, FALSE)
  expect_identical(capabilities$max_threads, 1L)
  withr::local_options(GEModelR.sparse.schur_cpp_threads = NULL)
  candidate = make_cpp_structured_model()
  partition = function(index, state) {
    list(stages = list(NULL),
         external = sparse_external_block_partition(index, state))
  }
  testthat::with_mocked_bindings(
    candidate$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, backend = "StructuredSchurFGMRESCpp",
      output = "compact"
    ),
    sparse_gtap_elimination_partition = partition,
    .package = "GEModelR"
  )
  diagnostics = candidate$lastDiagnostics
  expect_identical(diagnostics$requested_backend, "StructuredSchurFGMRESCpp")
  expect_identical(diagnostics$solver_backend, "StructuredSchurFGMRESCpp")
  expect_identical(diagnostics$implementation, "cpp")
  expect_identical(diagnostics$effective_thread_count, 1L)
  expect_identical(diagnostics$native$threads_requested, 1L)
  expect_identical(diagnostics$native$threads_effective_max, 1L)
  expect_identical(diagnostics$native$openmp_compiled, FALSE)
  expect_identical(
    diagnostics$capability_evidence$effective_capabilities$threads_requested, 1L
  )
  expect_equal(candidate$solution, 1:7, tolerance = 1e-8)

  for (threads in c(2L, 3L)) {
    options(GEModelR.sparse.schur_cpp_threads = threads)
    failed = make_cpp_structured_model()
    solution_before = failed$solution
    error = tryCatch(failed$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, backend = "StructuredSchurFGMRESCpp",
      output = "compact"
    ), error = identity)
    expect_s3_class(error, "GEModelR_capability_error")
    expect_match(conditionMessage(error), sprintf("requested %s threads", threads))
    expect_match(conditionMessage(error), "serial build")
    expect_identical(error$requested_backend, "StructuredSchurFGMRESCpp")
    expect_identical(error$failure_phase, "capability-preflight")
    expect_identical(failed$lastDiagnostics$status, "capability_failed")
    expect_identical(failed$lastDiagnostics$requested_backend,
                     "StructuredSchurFGMRESCpp")
    expect_identical(failed$lastDiagnostics$implementation, "cpp")
    expect_false(failed$lastDiagnostics$accepted_numerical_state)
    expect_false(failed$lastDiagnostics$capability_evidence$available)
    expect_identical(getOption("GEModelR.sparse.schur_cpp_threads"), threads)
    expect_identical(failed$solution, solution_before)
  }
})
