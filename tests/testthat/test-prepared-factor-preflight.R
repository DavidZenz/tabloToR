test_that("native preflight requires the prepared-factor protocol before emission", {
  runtime = .sparse_schur_cpp_runtime
  old_initialized = runtime$initialized
  old_capabilities = runtime$capabilities
  on.exit({
    runtime$initialized = old_initialized
    runtime$capabilities = old_capabilities
  }, add = TRUE)
  .sparse_schur_cpp_reset()
  solve = .GEModelR_sparse_lu_solve
  error = with_mocked_bindings(
    tryCatch(.sparse_schur_cpp_require_impl(), error = identity),
    .GEModelR_sparse_lu_solve = function(factor, rhs) {
      if (is.null(rhs)) stop("prepared factors unavailable in this library")
      solve(factor, rhs)
    }, .package = "GEModelR")
  expect_s3_class(error, "GEModelR_capability_error")
  expect_match(conditionMessage(error), "prepared factors unavailable")
  expect_match(conditionMessage(error), "No fallback was attempted")
})
