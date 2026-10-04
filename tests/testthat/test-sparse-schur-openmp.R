test_that("native job expectation rejects missing and invalid CI values", {
  expect_identical(nativeOpenmpExpectation("required", ci = TRUE), "required")
  expect_identical(nativeOpenmpExpectation("forbidden", ci = TRUE), "forbidden")
  expect_null(nativeOpenmpExpectation("", ci = FALSE))
  for (value in c("", "auto", "TRUE", "Required")) {
    expect_error(nativeOpenmpExpectation(value, ci = TRUE),
                 "GEModelR_EXPECT_OPENMP.*required or forbidden")
  }
  expect_error(nativeOpenmpExpectation("auto", ci = FALSE),
               "GEModelR_EXPECT_OPENMP.*required or forbidden")
})

test_that("native capability matches the explicit job expectation", {
  nativeOpenmpCapabilities()
})

test_that("bounded OpenMP Schur batches match serial execution", {
  expectation = nativeOpenmpExpectation()
  capabilities = nativeOpenmpCapabilities(expectation = expectation)
  if (identical(expectation, "forbidden")) {
    skip("Explicit serial job forbids OpenMP-only execution")
  }
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

  serial_time = system.time(serial <- .GEModelR_schur_accumulate_batch_serial(
    list(factor), list(L), list(R), D, external_regions,
    external_global, 1:2, 2L, 1L
  ))[["elapsed"]]
  parallel_time = system.time(parallel <- .GEModelR_schur_accumulate_batch(
    list(factor), list(L), list(R), D, external_regions,
    external_global, 1:2, 2L, 2L
  ))[["elapsed"]]
  cat(sprintf("\nSchur elapsed seconds: serial=%.6f, two-thread=%.6f\n",
              serial_time, parallel_time))

  expect_equal(parallel$regional, serial$regional, tolerance = 1e-10)
  expect_equal(parallel$global_region, serial$global_region,
               tolerance = 1e-10)
  expect_equal(parallel$diagnostics$threads_effective, 2L)
  expect_gte(parallel$diagnostics$threads_effective, 1L)
  expect_lte(parallel$diagnostics$threads_effective,
             capabilities$max_threads)
  expect_equal(
    parallel$diagnostics$panels_inspected,
    parallel$diagnostics$zero_panels_skipped +
      parallel$diagnostics$panels_solved
  )
})
