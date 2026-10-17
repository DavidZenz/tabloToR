test_that("residual acceptance cannot be authorized by an overflowing norm", {
  A = as(Matrix::Diagonal(4L), "generalMatrix")
  rhs = rep(1e308, 4L)
  solution = rhs
  solution[1L] = solution[1L] * (1 - 1e-4)
  candidate = list(backend = "Matrix", solution = solution,
                   coefficient_matrix = A, rhs = rhs)
  metrics = sparse_true_residual(A, solution, rhs)
  expect_equal(metrics$relative_l2, 5e-5, tolerance = 1e-12)
  expect_error(.sparse_accept_candidate(candidate), "exceeds tolerance")
  candidate$solution = rhs
  expect_true(.sparse_accept_candidate(candidate)$accepted)

  # An overflowing absolute norm is honest diagnostic evidence, not a zero
  # relative residual. Acceptance is determined by the finite scaled ratio.
  expect_equal(sparse_relative_l2(rep(1e308, 4), rhs), 1)
  expect_equal(sparse_scaled_l2(rep(1e308, 4)), Inf)
})

test_that("scaled residuals preserve absolute tolerance and fail closed", {
  A = as(Matrix::Diagonal(2L), "generalMatrix")
  for (scale in c(0, 1e-300, 1, 1e200)) {
    rhs = c(scale, -scale)
    expect_equal(sparse_true_residual(A, rhs, rhs)$relative_l2, 0)
    expect_equal(sparse_relative_l2(rhs, c(0, 0)), sparse_scaled_l2(rhs))
  }
  expect_gt(sparse_scaled_l2(c(1e-300, -1e-300)), 0)
  expect_gt(sparse_relative_l2(1e-300, 1e300), 0)
  for (value in c(NA_real_, NaN, Inf, -Inf)) {
    expect_error(sparse_true_residual(A, c(value, 0), c(0, 0)), "non-finite")
    expect_error(sparse_relative_l2(value, 1), "non-finite")
  }
  candidate = list(backend = "Matrix", solution = c(1e300, 1e-300),
                   coefficient_matrix = A, rhs = c(1e300, 0))
  expect_error(.sparse_accept_candidate(candidate, residual_tolerance = 0),
               "exceeds tolerance")
})
