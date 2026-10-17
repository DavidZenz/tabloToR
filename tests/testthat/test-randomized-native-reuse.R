test_that("randomized scaled elimination and prepared solves agree with Matrix", {
  set.seed(171018)
  for (case in seq_len(200L)) {
    local_count = sample.int(4L, 1L)
    sizes = sample.int(6L, local_count, replace = TRUE)
    retained = sample(0:8, 1L)
    group = c(rep(seq_len(local_count) - 1L, sizes), rep(-1L, retained))
    n = length(group)
    dense = matrix(rnorm(n * n), n)
    dense[matrix(runif(n * n) > .3, n)] = 0
    dense[outer(group, group, function(r, c) r >= 0 & c >= 0 & r != c)] = 0
    diag(dense) = rowSums(abs(dense)) + 5
    rp = sample.int(n)
    cp = sample.int(n)
    scale = c(1e-150, 1, 1e150)[(case - 1L) %% 3L + 1L]
    A = as(as(Matrix::Matrix(dense[rp, cp, drop = FALSE], sparse = TRUE),
                "generalMatrix"), "CsparseMatrix") * scale
    rhs = rnorm(n) * scale
    rg = group[rp]
    cg = group[cp]
    reduced = GEModelR_eliminate_blocks(A, rhs, rg, cg, local_count, 1e-12)
    expect_true(reduced$ok)
    answer = if (retained) as.numeric(Matrix::solve(reduced$A, reduced$rhs)) else
      numeric()
    actual = GEModelR_reconstruct_blocks(A, rhs, answer, rg, cg,
                                          local_count, 1e-12)
    reference = as.numeric(Matrix::solve(A, rhs))
    expect_equal(actual, reference, tolerance = 1e-12)
    expect_lte(sparse_relative_l2(as.numeric(A %*% actual) - rhs, rhs), 1e-12)
    factor = Matrix::lu(A, order = (case - 1L) %% 4L)
    prepared = .GEModelR_sparse_lu_solve(factor, NULL)
    # Every factor sees multiple RHS values; no results or factors are shared
    # with the next random matrix, even when its dimensions are the same.
    for (multiplier in c(1, -2)) {
      result = .GEModelR_sparse_lu_solve(prepared, rhs * multiplier)
      expect_equal(as.numeric(result), reference * multiplier, tolerance = 1e-12)
    }
    .GEModelR_sparse_lu_solve(prepared, NULL)
  }
})
