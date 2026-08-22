test_that("bounded OpenMP Schur batches match serial execution", {
  capabilities <- .tabloToR_schur_cpp_capabilities()
  skip_if_not(isTRUE(capabilities$openmp))
  fixture <- make_cpp_schur_fixture()
  local <- which(fixture$row_group == 0L)
  regions <- list(
    which(fixture$row_group == 1L),
    which(fixture$row_group == 2L)
  )
  global <- which(fixture$row_group == 3L)
  external <- unlist(c(regions, list(global)), use.names = FALSE)
  B <- fixture$A[local, local, drop = FALSE]
  L <- fixture$A[external, local, drop = FALSE]
  R <- fixture$A[local, external, drop = FALSE]
  D <- fixture$A[external, external, drop = FALSE]
  factor <- Matrix::lu(B, order = 1L)
  external_regions <- list(
    seq_along(regions[[1L]]),
    length(regions[[1L]]) + seq_along(regions[[2L]])
  )
  external_global <- sum(vapply(regions, length, integer(1))) +
    seq_along(global)

  serial <- .tabloToR_schur_accumulate_batch_serial(
    list(factor), list(L), list(R), D, external_regions,
    external_global, 1:2, 2L, 1L
  )
  parallel <- .tabloToR_schur_accumulate_batch(
    list(factor), list(L), list(R), D, external_regions,
    external_global, 1:2, 2L, 2L
  )

  expect_equal(parallel$regional, serial$regional, tolerance = 1e-10)
  expect_equal(parallel$global_region, serial$global_region,
               tolerance = 1e-10)
  expect_equal(parallel$diagnostics$threads_effective, 2L)
  expect_equal(
    parallel$diagnostics$panels_inspected,
    parallel$diagnostics$zero_panels_skipped +
      parallel$diagnostics$panels_solved
  )
})
