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
    .package = "tabloToR"
  )
  testthat::with_mocked_bindings(
    candidate$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, backend = "StructuredSchurFGMRESCpp",
      output = "compact"
    ),
    sparse_gtap_elimination_partition = partition,
    .package = "tabloToR"
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
})
