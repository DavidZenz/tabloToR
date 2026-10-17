test_that("prepared factors own immutable validated snapshots and reusable scratch", {
  set.seed(171019)
  A = Matrix::rsparsematrix(40L, 40L, .15) + Matrix::Diagonal(40L, 40)
  for (order in 0:3) {
    factor = Matrix::lu(A, order = order)
    prepared = .GEModelR_sparse_lu_solve(factor, NULL)
    on.exit(.GEModelR_sparse_lu_solve(prepared, NULL), add = TRUE)
    for (width in c(1L, 0L, 33L, 2L)) {
      rhs = matrix(rnorm(40L * width), 40L, width,
                    dimnames = list(paste0("r", 1:40), NULL))
      result = .GEModelR_sparse_lu_solve(prepared, rhs)
      expect_equal(result, as.matrix(Matrix::solve(factor, rhs)), tolerance = 1e-12,
                    ignore_attr = TRUE)
      expect_identical(dimnames(result), dimnames(rhs))
    }
    rhs = rnorm(40)
    expected = as.numeric(Matrix::solve(factor, rhs))
    factor@U@x[] = factor@U@x * 2
    gc()
    expect_equal(.GEModelR_sparse_lu_solve(prepared, rhs), expected,
                  tolerance = 1e-12)
    expect_error(.GEModelR_sparse_lu_solve(prepared, rep(Inf, 40)), "non-finite")
    expect_error(.GEModelR_sparse_lu_solve(prepared, 1), "length")
    restored = unserialize(serialize(prepared, NULL))
    expect_error(.GEModelR_sparse_lu_solve(restored, rhs), "released")
    .GEModelR_sparse_lu_solve(prepared, NULL)
    expect_error(.GEModelR_sparse_lu_solve(prepared, rhs), "released")
    expect_null(.GEModelR_sparse_lu_solve(prepared, NULL))
  }
  expect_error(.GEModelR_sparse_lu_solve(new("externalptr"), 1), "Invalid")
  bad = Matrix::lu(A)
  bad@U@x[1] = NaN
  expect_error(.GEModelR_sparse_lu_solve(bad, NULL), "invalid")
})
