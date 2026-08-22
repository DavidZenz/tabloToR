test_that("native structural cache reuses patterns and refactors values", {
  fixture <- make_cpp_schur_fixture()
  runtime <- .sparse_schur_cpp_runtime
  old <- runtime$active
  state <- sparse_make_state(list())
  runtime$active <- TRUE
  runtime$state <- state
  runtime$index_key <- "cache-test"
  on.exit({
    runtime$active <- old
    runtime$state <- NULL
    runtime$index_key <- NULL
    .sparse_cpp_release_live_factors()
  }, add = TRUE)

  build <- function(A) {
    system <- .sparse_exact_schur_build_cpp(
      A, fixture$row_group, fixture$column_group,
      fixture$local_count, fixture$region_count, fixture$global_group,
      rhs = fixture$rhs, panel_size = 2L
    )
    .sparse_cpp_release_live_factors()
    system$diagnostics
  }
  first <- build(fixture$A)
  changed <- fixture$A
  changed@x <- changed@x * 1.01
  second <- build(changed)

  expect_equal(first$structural_cache_misses, 1L)
  expect_equal(second$structural_cache_hits, 1L)
  expect_equal(second$numeric_refactorizations, 1L)

  changed_pattern <- Matrix::drop0(fixture$A)
  changed_pattern[1, 2] <- 0
  changed_pattern <- Matrix::drop0(changed_pattern)
  third <- build(changed_pattern)
  expect_equal(third$structural_cache_misses, 1L)
  expect_true("pattern" %in% third$structural_cache_rebuild_reasons)
})

test_that("closure and serialization do not retain native factors", {
  model <- make_synthetic_model()
  model$sparseState$.solver_cache[["StructuredSchurFGMRESCpp"]] <- list(x = 1)
  model$setClosure("a")
  expect_length(model$sparseState$.solver_cache, 0L)

  restored <- unserialize(serialize(model, NULL))
  expect_false(contains_external_pointer(restored$sparseState))
  expect_false(contains_external_pointer(restored$lastDiagnostics))
})
