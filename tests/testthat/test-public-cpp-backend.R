test_that("public native backend is opt-in and numerically equivalent", {
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
  expect_gt(length(cleanup_results), cleanups_before_error)
  expect_identical(tail(cleanup_results, 1L)[[1L]]$status, "complete")
  expect_identical(tail(cleanup_results, 1L)[[1L]]$scope, "solve")
  expect_identical(.sparse_schur_cpp_runtime$live_dense_factors, list())
})
