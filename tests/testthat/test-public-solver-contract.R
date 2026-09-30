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

test_that("Matrix adapter preflights before emission and commits accepted state", {
  model <- make_synthetic_model()
  model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
  events <- character()
  commits <- 0L

  adapter <- .sparse_backend_registry$Matrix
  old_adapter <- adapter
  original_preflight <- adapter$preflight
  original_solve <- adapter$solve
  adapter_result <- NULL
  adapter$preflight <- function(...) {
    events <<- c(events, "preflight")
    original_preflight(...)
  }
  adapter$solve <- function(...) {
    adapter_result <<- original_solve(...)
    adapter_result
  }
  .sparse_backend_registry$Matrix <- adapter
  withr::defer(.sparse_backend_registry$Matrix <- old_adapter)

  original_emit <- getFromNamespace("sparse_emit_system", "GEModelR")
  testthat::local_mocked_bindings(
    sparse_emit_system = function(...) {
      events <<- c(events, "emit")
      original_emit(...)
    },
    .package = "GEModelR"
  )
  localTransactionFault(function(phase, context) {
    if (identical(phase, "commit-accepted-state")) {
      commits <<- commits + 1L
    }
    invisible(NULL)
  })

  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", backend = "Matrix",
    reduction = "off"
  )

  expect_identical(events[[1L]], "preflight")
  expect_true(any(events == "emit"))
  expect_lt(match("preflight", events), match("emit", events))
  expect_identical(commits, 1L)
  expect_equal(unname(model$solution), c(8, 3), tolerance = 1e-12)
  expect_equal(as.numeric(sparse_state_data(model$sparseState)$x), c(8, 3),
               tolerance = 1e-12)
  expect_true(model$lastDiagnostics$accepted_numerical_state)
  expect_identical(adapter_result$requested_backend, "Matrix")
  expect_identical(adapter_result$backend, "Matrix")
  expect_identical(
    adapter_result$implementation, "solve_sparse_system(Matrix)"
  )
  expect_s4_class(adapter_result$coefficient_matrix, "sparseMatrix")
  expect_true(all(c(
    "output_structure", "structural_metadata", "finiteness_evidence",
    "residual_evidence_inputs", "timing", "capability_evidence",
    "cleanup_status"
  ) %in% names(adapter_result)))
  expect_lt(
    model$lastDiagnostics$true_residual_history[[1L]]$metrics$relative_l2,
    2e-7
  )
})

test_that("Matrix adapter records fail closed before accepted-state commit", {
  reject_adapter_result <- function(mutate_result, expected_error) {
    model <- make_synthetic_model()
    model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
    before <- transactionalModelSnapshot(model, include_diagnostics = FALSE)
    commits <- 0L

    adapter <- .sparse_backend_registry$Matrix
    old_adapter <- adapter
    original_solve <- adapter$solve
    adapter$solve <- function(...) {
      mutate_result(original_solve(...))
    }
    .sparse_backend_registry$Matrix <- adapter
    withr::defer(.sparse_backend_registry$Matrix <- old_adapter)
    localTransactionFault(function(phase, context) {
      if (identical(phase, "commit-accepted-state")) {
        commits <<- commits + 1L
      }
      invisible(NULL)
    }, env = environment())

    expect_error(
      model$solveModel(
        iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
        diagnostics = TRUE, backend = "Matrix", reduction = "off"
      ),
      expected_error
    )
    expect_identical(commits, 0L)
    expectTransactionalStateIdentical(before, model)
  }

  reject_adapter_result(function(result) {
    result$cleanup_status <- NULL
    result
  }, "missing field.*cleanup_status")

  reject_adapter_result(function(result) {
    result$output_structure$length <- result$output_structure$length + 1L
    result
  }, "output structure metadata is inconsistent")

  reject_adapter_result(function(result) {
    result$solution[[1L]] <- Inf
    result
  }, "contains non-finite values")

  reject_adapter_result(function(result) {
    result$solution <- result$solution + 1
    result
  }, "true residual.*solution was not applied")
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
  exported <- getNamespaceExports("GEModelR")
  expect_false(any(startsWith(exported, ".GEModelR_")))
  expect_true(all(c("GEModel", "solve_sparse_system",
                    "sparse_exact_schur_solve") %in% exported))
})
