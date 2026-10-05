test_that("installed structured elimination runs outside the checkout without compiling", {
  workdir = tempfile("GEModelR-native-portability-")
  dir.create(workdir)
  original_workdir = getwd()
  on.exit(setwd(original_workdir), add = TRUE)
  setwd(workdir)

  package_path = normalizePath(
    find.package("GEModelR"), winslash = "/", mustWork = TRUE
  )
  expect_true(dir.exists(package_path))
  expect_false(startsWith(
    normalizePath(getwd(), winslash = "/", mustWork = TRUE),
    package_path
  ))

  rcpp_namespace = asNamespace("Rcpp")
  trace(
    "sourceCpp", where = rcpp_namespace,
    tracer = quote(stop(
      "unexpected Rcpp::sourceCpp() during installed solve", call. = FALSE
    )),
    print = FALSE
  )
  on.exit(untrace("sourceCpp", where = rcpp_namespace), add = TRUE)

  coefficient_matrix = Matrix::sparseMatrix(
    i = c(1L, 1L, 2L, 2L, 3L, 3L, 4L, 4L, 1L, 2L, 3L, 4L,
          5L, 5L, 5L),
    j = c(1L, 2L, 1L, 2L, 3L, 4L, 3L, 4L, 5L, 5L, 5L, 5L,
          1L, 3L, 5L),
    x = c(4, 1, 2, 3, 5, 1, 2, 4, 0.2, 0.3, 0.4, 0.1,
          0.5, 0.2, 2),
    dims = c(5L, 5L)
  )
  expected = c(1, -2, 0.5, 3, 4)
  rhs = as.numeric(coefficient_matrix %*% expected)
  partition = list(
    row_group = as.integer(c(0L, 0L, 1L, 1L, -1L)),
    column_group = as.integer(c(0L, 0L, 1L, 1L, -1L)),
    n_groups = 2L
  )

  result = sparse_exact_structured_solve(
    coefficient_matrix, rhs, partition
  )

  expect_equal(result$reduced_dimension, 1L)
  expect_equal(result$solution, expected, tolerance = 1e-10)
  expect_lt(
    sparse_true_residual(
      coefficient_matrix, result$solution, rhs
    )$relative_l2,
    1e-10
  )
})
