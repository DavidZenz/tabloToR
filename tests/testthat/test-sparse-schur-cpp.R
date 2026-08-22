test_that("native Schur blocks match an independent exact oracle", {
  fixture <- make_cpp_schur_fixture()
  A <- fixture$A
  local <- which(fixture$row_group == 0L)
  regions <- list(
    which(fixture$row_group == 1L),
    which(fixture$row_group == 2L)
  )
  global <- which(fixture$row_group == 3L)
  external <- unlist(c(regions, list(global)), use.names = FALSE)
  B <- A[local, local, drop = FALSE]
  L <- A[external, local, drop = FALSE]
  R <- A[local, external, drop = FALSE]
  D <- A[external, external, drop = FALSE]
  oracle <- as.matrix(D) -
    as.matrix(L) %*% solve(as.matrix(B), as.matrix(R))
  factor <- Matrix::lu(B, order = 1L)
  external_regions <- list(seq_along(regions[[1L]]),
                           length(regions[[1L]]) + seq_along(regions[[2L]]))
  external_global <- sum(vapply(regions, length, integer(1))) +
    seq_along(global)

  native_global <- .tabloToR_schur_accumulate_global(
    list(factor), list(L), list(R), D,
    external_regions, external_global, 2L
  )
  native_batch <- .tabloToR_schur_accumulate_batch(
    list(factor), list(L), list(R), D,
    external_regions, external_global, 1:2, 2L, 1L
  )

  expect_equal(native_batch$regional[[1L]],
               oracle[external_regions[[1L]], external_regions[[1L]]],
               tolerance = 1e-10)
  expect_equal(native_batch$regional[[2L]],
               oracle[external_regions[[2L]], external_regions[[2L]]],
               tolerance = 1e-10)
  expect_equal(native_global$region_global[[1L]],
               oracle[external_regions[[1L]], external_global, drop = FALSE],
               tolerance = 1e-10)
  expect_equal(native_batch$global_region[[2L]],
               oracle[external_global, external_regions[[2L]], drop = FALSE],
               tolerance = 1e-10)
  expect_equal(native_global$global_global,
               oracle[external_global, external_global, drop = FALSE],
               tolerance = 1e-10)
  expect_equal(
    native_global$diagnostics$panels_inspected,
    native_global$diagnostics$zero_panels_skipped +
      native_global$diagnostics$panels_solved
  )
  # Cross-region slices are present in the exact operator but deliberately
  # absent from the arrowhead preconditioner outputs.
  expect_true(any(abs(oracle[external_regions[[1L]],
                             external_regions[[2L]]]) > 0))
})

test_that("native Schur solve preserves the exact sparse operator", {
  fixture <- make_cpp_schur_fixture()
  runtime <- .sparse_schur_cpp_runtime
  old <- runtime$active
  runtime$active <- TRUE
  runtime$state <- sparse_make_state(list())
  runtime$index_key <- "native-oracle-test"
  on.exit({
    runtime$active <- old
    runtime$state <- NULL
    runtime$index_key <- NULL
    .sparse_cpp_release_live_factors()
  }, add = TRUE)

  result <- sparse_exact_schur_solve(
    fixture$A, fixture$rhs,
    fixture$row_group, fixture$column_group,
    fixture$local_count, fixture$region_count, fixture$global_group,
    panel_size = 2L, restart = 10L, max_iterations = 40L,
    tolerance = 1e-10, true_residual_frequency = 1L
  )

  expect_true(result$converged)
  expect_equal(result$solution, solve(fixture$dense, fixture$rhs),
               tolerance = 1e-8)
  expect_lt(result$diagnostics$true_relative_residual, 1e-10)
  expect_false(result$diagnostics$dense_full_system_operations)
  expect_null(result$system)
})
