test_that("FGMRES solves finite identity systems across scales", {
  system = structure(list(external_columns = 1:4,
                           D = as(Matrix::Diagonal(4L), "generalMatrix"),
                           local_count = 0L), class = "sparseExactSchurSystem")
  for (scale in c(0, 1e-300, 1e-14, 1, 1e200, 1e308)) {
    rhs = rep(c(scale, -scale), 2L)
    result = sparse_schur_fgmres(system, rhs)
    expect_true(result$converged)
    if (scale != 0) {
      expect_equal(result$solution / scale, rhs / scale, tolerance = 1e-12)
    } else expect_equal(result$solution, rhs)
    expect_lte(tail(result$residual_history$true_relative, 1L), 1e-8)
  }
  system$D = system$D * 1e200
  result = sparse_schur_fgmres(system, rep(1e200, 4L))
  expect_true(result$converged)
  expect_equal(result$solution, rep(1, 4L), tolerance = 1e-12)
  expect_error(sparse_schur_fgmres(system, c(Inf, 1, 1, 1)), "finite")
  expect_error(sparse_schur_fgmres(system, rep(1, 4),
                                 preconditioner = function(...) rep(NaN, 4)),
               "invalid values")
})

test_that("tiny public shocks survive both engines and substeps", {
  for (engine in c("legacy", "sparse")) {
    for (shock in c(1e-14, -1e-14, 1e-100)) {
      model = make_synthetic_model()
      if (engine == "legacy") {
        model$loadData(make_shared_synthetic_data(), engine = engine)
      }
      model$setShocks(setNames(shock, "a[r1]"))
      suppressMessages(model$solveModel(iter = 2, steps = c(1, 2), engine = engine,
                                        postsim = FALSE, output = "full"))
      expect_equal(as.numeric(model$solution[[1L]]) / shock, 1,
                   tolerance = 1e-12, info = engine)
    }
  }
  expect_equal(sparse_compound_percent(c(10, -100, 1e308), c(20, 4, -100)),
                c(32, -100, -100))
  expect_equal(sparse_remaining_percent(-100, -100), 0)
  near_zero_base = -100 + 2^-45
  expect_equal(sparse_remaining_percent(near_zero_base + 2^-45, near_zero_base),
                100, tolerance = 1e-14)
  expect_error(sparse_remaining_percent(1, -100), "finite")
  expect_error(sparse_remaining_percent(NaN, 0), "non-finite")
  expect_error(sparse_compound_percent(1, Inf), "non-finite")
})

test_that("small scaled pivots and shocks survive native reconstruction", {
  for (scale in c(1e-200, 1, 1e200)) {
    A = Matrix::sparseMatrix(i = c(1L, 1L, 2L, 2L),
                             j = c(1L, 2L, 1L, 2L), x = c(4, 1, 1, 3) * scale)
    expected = c(1e-14, -2e-14)
    rhs = as.numeric(A %*% expected)
    groups = c(0L, -1L)
    reduced = GEModelR_eliminate_blocks(A, rhs, groups, groups, 1L, 1e-12)
    external = as.numeric(Matrix::solve(reduced$A, reduced$rhs))
    result = GEModelR_reconstruct_blocks(A, rhs, external, groups, groups,
                                          1L, 1e-12)
    expect_equal(result / 1e-14, expected / 1e-14, tolerance = 1e-12)
  }
})

test_that("full structured convergence uses a finite scaled residual ratio", {
  A = as(Matrix::Diagonal(4L), "generalMatrix")
  groups = c(0L, 0L, 1L, 2L)
  result = .sparse_exact_schur_solve_reference(
    A, rep(1e308, 4L), groups, groups, 1L, 1L, 2L)
  expect_true(result$converged)
  expect_equal(result$solution / 1e308, rep(1, 4L), tolerance = 1e-12)
  expect_equal(result$diagnostics$true_relative_residual, 0)
})
