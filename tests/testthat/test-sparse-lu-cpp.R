test_that("private native sparseLU solves match Matrix", {
  skip_if_not_installed("Matrix")
  set.seed(17)
  A <- Matrix::rsparsematrix(40L, 40L, 0.12) + Matrix::Diagonal(40L, 15)
  vector_rhs <- rnorm(40L)
  matrix_rhs <- matrix(rnorm(40L * 64L), 40L, 64L)

  for (ordering in 0:3) {
    factor <- Matrix::lu(A, order = ordering)
    expect_equal(
      .tabloToR_sparse_lu_solve(factor, vector_rhs),
      as.numeric(Matrix::solve(factor, vector_rhs)),
      tolerance = 1e-10
    )
    expect_equal(
      .tabloToR_sparse_lu_solve(factor, matrix_rhs),
      as.matrix(Matrix::solve(factor, matrix_rhs)),
      tolerance = 1e-10
    )
  }
})

test_that("private sparseLU solve preserves zero columns and rejects bad input", {
  A <- Matrix::sparseMatrix(
    i = c(1L, 1L, 2L, 3L), j = c(1L, 3L, 2L, 3L),
    x = c(4, 1, 3, 5), dims = c(3L, 3L)
  )
  factor <- Matrix::lu(A, order = 1L)
  rhs <- cbind(c(1, 2, 3), numeric(3L))

  expect_equal(
    .tabloToR_sparse_lu_solve(factor, rhs),
    as.matrix(Matrix::solve(factor, rhs)),
    tolerance = 1e-10
  )
  expect_error(
    .tabloToR_sparse_lu_solve(factor, c(1, NA, 3)),
    "non-finite"
  )
  expect_error(.tabloToR_sparse_lu_solve(factor, 1:2), "incompatible")
})

test_that("native dense factors solve and release deterministically", {
  set.seed(18)
  A <- matrix(rnorm(100), 10L, 10L)
  diag(A) <- diag(A) + 10
  rhs <- matrix(rnorm(30), 10L, 3L)
  factor <- .tabloToR_dense_lu_factor(A)

  expect_equal(
    .tabloToR_dense_lu_solve(factor, rhs),
    solve(A, rhs), tolerance = 1e-10
  )
  .tabloToR_dense_lu_release(factor)
  expect_error(.tabloToR_dense_lu_solve(factor, rhs), "released")
  expect_error(.tabloToR_dense_lu_factor(matrix(0, 2L, 2L)), "singular")
})
