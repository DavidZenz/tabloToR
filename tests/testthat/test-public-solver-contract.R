test_that("solver defaults and reference backend remain unchanged", {
  expect_identical(formals(GEModel$methods("solveModel"))$backend, "Matrix")
  omitted <- make_synthetic_model()
  explicit <- make_synthetic_model()
  shocks <- setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]"))
  omitted$setShocks(shocks)
  explicit$setShocks(shocks)
  omitted$solveModel(iter = 1, steps = 1, engine = "sparse",
                     postsim = FALSE, diagnostics = FALSE)
  explicit$solveModel(iter = 1, steps = 1, engine = "sparse",
                      postsim = FALSE, diagnostics = FALSE,
                      backend = "Matrix")

  expect_equal(omitted$solution, explicit$solution, tolerance = 1e-12)
  expect_identical(omitted$lastDiagnostics, list())
  expect_identical(explicit$lastDiagnostics, list())
})

test_that("native backend preflight fails closed before solving", {
  model <- make_synthetic_model()
  runtime <- .sparse_schur_cpp_runtime
  old_require <- runtime$require
  runtime$require <- function(...) stop("injected preflight failure",
                                        call. = FALSE)
  on.exit(runtime$require <- old_require, add = TRUE)
  before <- sparse_state_data(model$sparseState)

  expect_error(
    model$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      backend = "StructuredSchurFGMRESCpp"
    ),
    "injected preflight failure"
  )
  expect_identical(sparse_state_data(model$sparseState), before)
  expect_false(isTRUE(runtime$active))
})

test_that("private native wrappers do not expand the exported namespace", {
  exported <- getNamespaceExports("tabloToR")
  expect_false(any(startsWith(exported, ".tabloToR_")))
  expect_true(all(c("GEModel", "solve_sparse_system",
                    "sparse_exact_schur_solve") %in% exported))
})
