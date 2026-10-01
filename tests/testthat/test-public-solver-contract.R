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
  for (model in list(omitted, explicit)) {
    expect_identical(model$lastDiagnostics$schema_version, 1L)
    expect_identical(model$lastDiagnostics$engine, "sparse")
    expect_identical(model$lastDiagnostics$requested_backend, "Matrix")
    expect_identical(model$lastDiagnostics$implementation, "r")
    expect_identical(model$lastDiagnostics$status, "succeeded")
    expect_null(model$lastDiagnostics$condition_class)
    expect_true(model$lastDiagnostics$accepted_numerical_state)
    expect_false(model$lastDiagnostics$retryable_postsim)
    expect_identical(model$lastDiagnostics$cleanup_status$status, "complete")
    expect_false("true_residual_history" %in% names(model$lastDiagnostics))
  }
})

test_that("solve and lifecycle validation conditions share a stable class", {
  capture_error <- function(expression) {
    tryCatch(force(expression), error = identity)
  }
  unloaded <- GEModel$new()
  lifecycle_error <- capture_error(unloaded$solveModel(engine = "sparse"))
  expect_identical(class(lifecycle_error)[[1L]],
                   "GEModelR_validation_error")
  expect_identical(lifecycle_error$failure_phase, "validation")
  expect_true(is.list(lifecycle_error$remediation))

  model <- make_synthetic_model()
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = FALSE
  )
  selector_error <- capture_error(model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    backend = "not-a-backend"
  ))
  expect_identical(class(selector_error)[[1L]],
                   "GEModelR_validation_error")
  expect_identical(selector_error$argument, "backend")
  expect_identical(selector_error$requested_engine, "sparse")
  expect_identical(selector_error$requested_backend, "not-a-backend")
  expect_identical(selector_error$failure_phase, "validation")
  expect_false(selector_error$accepted_numerical_state)
  expect_false(selector_error$retryable_postsim)
  expect_true(is.list(selector_error$remediation))
  expect_identical(model$lastDiagnostics$schema_version, 1L)
  expect_identical(model$lastDiagnostics$status, "validation_failed")
  expect_identical(model$lastDiagnostics$engine, "sparse")
  expect_identical(model$lastDiagnostics$requested_backend, "not-a-backend")
  expect_identical(
    model$lastDiagnostics$condition_class, "GEModelR_validation_error"
  )
  expect_null(model$lastDiagnostics$implementation)
  expect_false(model$lastDiagnostics$accepted_numerical_state)
  expect_identical(model$lastDiagnostics$cleanup_status$status, "not-run")

  invalid_engine <- make_synthetic_model()
  invalid_engine_error <- capture_error(
    invalid_engine$solveModel(engine = "unknown")
  )
  expect_identical(class(invalid_engine_error)[[1L]],
                   "GEModelR_validation_error")
  expect_identical(invalid_engine$lastDiagnostics$status, "validation_failed")
  expect_identical(invalid_engine$lastDiagnostics$engine, "unknown")
  expect_identical(
    invalid_engine$lastDiagnostics$requested_backend, "Matrix"
  )
  expect_null(invalid_engine$lastDiagnostics$implementation)
})

test_that("legacy shock labels resolve declared positions without evaluation", {
  model <- make_three_region_model(engine = "legacy")
  injected_name <- "GEModelR.test.shock.label.injected"
  had_prior_value <- exists(injected_name, envir = .GlobalEnv,
                            inherits = FALSE)
  prior_value <- if (had_prior_value) {
    get(injected_name, envir = .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    if (had_prior_value) {
      assign(injected_name, prior_value, envir = .GlobalEnv)
    } else if (exists(injected_name, envir = .GlobalEnv, inherits = FALSE)) {
      rm(list = injected_name, envir = .GlobalEnv)
    }
  }, add = TRUE)
  assign(injected_name, FALSE, envir = .GlobalEnv)

  malicious_label <- paste0(
    'a["r1"]; assign("', injected_name,
    '", TRUE, envir = .GlobalEnv); a["r1"]'
  )
  error <- tryCatch(
    model$setShocks(setNames(5, malicious_label)),
    error = identity
  )

  expect_identical(class(error)[[1L]], "GEModelR_validation_error")
  expect_identical(error$argument, "shocks")
  expect_identical(get(injected_name, envir = .GlobalEnv), FALSE)
  expect_length(model$explicitShocks$labels, 0L)
})

test_that("true residual metrics remain finite at large magnitudes", {
  coefficient_matrix <- Matrix::sparseMatrix(
    i = 1:2, j = 1:2, x = c(1, 1), dims = c(2L, 2L)
  )
  solution <- c(2e200, 0)
  rhs <- c(1e200, 0)

  metrics <- sparse_true_residual(coefficient_matrix, solution, rhs)
  expect_true(all(is.finite(unlist(metrics))))
  expect_equal(metrics$relative_l2, 1)
  expect_error(
    .sparse_accept_candidate(list(
      backend = "Matrix",
      solution = solution,
      coefficient_matrix = coefficient_matrix,
      rhs = rhs
    )),
    "true residual"
  )

  overflowing_product <- Matrix::sparseMatrix(
    i = 1L, j = 1L, x = 1e308, dims = c(1L, 1L)
  )
  expect_error(
    sparse_true_residual(overflowing_product, 2, 0),
    "non-finite A"
  )
  expect_error(
    sparse_true_residual(overflowing_product, 1, -1e308),
    "non-finite residual"
  )
})

test_that("diagnostic details are opt-in for sparse and legacy solves", {
  sparse <- make_synthetic_model()
  sparse$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, backend = "Matrix"
  )
  expect_identical(sparse$lastDiagnostics$status, "succeeded")
  expect_true(length(sparse$lastDiagnostics$true_residual_history) > 0L)
  expect_true(is.list(sparse$lastDiagnostics$phase_allocations))
  expect_true(is.list(sparse$lastDiagnostics$capability_evidence))
  expect_true(is.list(sparse$lastDiagnostics$estimated_memory))

  legacy <- make_three_region_model(engine = "legacy")
  set_three_region_shocks(legacy, "preferred", c(1, 0, 0))
  legacy$solveModel(
    iter = 1, steps = 1, engine = "legacy", diagnostics = TRUE
  )
  expect_identical(legacy$lastDiagnostics$status, "succeeded")
  expect_identical(legacy$lastDiagnostics$implementation, "r")
  expect_true(is.list(legacy$lastDiagnostics$capability_evidence))
  expect_true(is.list(legacy$lastDiagnostics$phase_allocations))
  expect_true(is.list(legacy$lastDiagnostics$estimated_memory))

  minimal <- make_three_region_model(engine = "legacy")
  minimal$solveModel(
    iter = 1, steps = 1, engine = "legacy", diagnostics = FALSE
  )
  expect_identical(names(minimal$lastDiagnostics), .gemodelr_diagnostics_fields)
})

test_that("each registered backend routes with its requested identity", {
  backend_ids <- c(
    "Matrix", "SparseM", "SuiteSparse", "StructuredSchur",
    "StructuredSchurFGMRES", "StructuredSchurFGMRESCpp"
  )
  expect_setequal(ls(.sparse_backend_registry), backend_ids)
  original_adapters <- lapply(backend_ids, function(backend) {
    .sparse_backend_registry[[backend]]
  })
  names(original_adapters) <- backend_ids
  withr::defer({
    for (backend in backend_ids) {
      .sparse_backend_registry[[backend]] <- original_adapters[[backend]]
    }
  })

  preflight_calls <- stats::setNames(integer(length(backend_ids)), backend_ids)
  solve_calls <- stats::setNames(vector("list", length(backend_ids)),
                                 backend_ids)
  cleanup_calls <- stats::setNames(integer(length(backend_ids)), backend_ids)
  for (backend in backend_ids) {
    adapter <- .sparse_backend_registry[[backend]]
    implementation <- adapter$implementation
    expect_true(is.function(adapter$cleanup))
    adapter$preflight <- local({
      backend_id <- backend
      implementation_id <- implementation
      function(requested_backend = backend_id, ...) {
        expect_identical(requested_backend, backend_id)
        preflight_calls[[backend_id]] <<- preflight_calls[[backend_id]] + 1L
        list(
          requested_backend = requested_backend,
          implementation = implementation_id,
          available = TRUE,
          capability = "routing contract probe"
        )
      }
    })
    adapter$solve <- local({
      backend_id <- backend
      implementation_id <- implementation
      function(coefficient_matrix, rhs, reduction, requested_backend,
               implementation, capability_evidence, ...) {
        expect_identical(requested_backend, backend_id)
        expect_identical(implementation, implementation_id)
        solve_calls[[backend_id]] <<- implementation
        solution <- as.numeric(Matrix::solve(coefficient_matrix, rhs))
        .sparse_backend_candidate_record(
          solution, coefficient_matrix, rhs, requested_backend,
          implementation, capability_evidence, 0
        )
      }
    })
    adapter$cleanup <- local({
      backend_id <- backend
      function(...) {
        cleanup_calls[[backend_id]] <<- cleanup_calls[[backend_id]] + 1L
        .sparse_backend_noop_cleanup()
      }
    })
    .sparse_backend_registry[[backend]] <- adapter
  }

  coefficient_matrix <- Matrix::Matrix(
    c(3, 0, 0, 5), nrow = 2L, sparse = TRUE
  )
  rhs <- c(3, 5)
  for (backend in backend_ids) {
    preflight <- .sparse_backend_preflight(backend)
    candidate <- .sparse_backend_solve(
      preflight, coefficient_matrix, rhs, reduction = "off"
    )
    expect_identical(candidate$requested_backend, backend)
    expect_identical(
      candidate$implementation,
      original_adapters[[backend]]$implementation
    )
    expect_equal(candidate$solution, c(1, 1), tolerance = 1e-12)
  }
  expect_identical(unname(preflight_calls), rep(1L, length(backend_ids)))
  expect_identical(
    unname(solve_calls),
    unname(lapply(original_adapters, `[[`, "implementation"))
  )
  expect_identical(unname(cleanup_calls), rep(1L, length(backend_ids)))
})

test_that("optional R backend preflights preserve exact IDs", {
  check_preflight <- function(backend) {
    result <- tryCatch(
      .sparse_backend_preflight(backend),
      error = function(error) error
    )
    if (inherits(result, "error")) {
      expect_match(
        conditionMessage(result),
        sprintf("Requested backend '%s'.*Remediation:", backend)
      )
    } else {
      expect_identical(result$requested_backend, backend)
      expect_identical(
        result$capability_evidence$requested_backend, backend
      )
      expect_true(result$capability_evidence$available)
    }
  }
  check_preflight("SparseM")
  check_preflight("SuiteSparse")
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

    error <- tryCatch(model$solveModel(
        iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
        diagnostics = TRUE, backend = "Matrix", reduction = "off"
      ), error = identity)
    expect_match(conditionMessage(error), expected_error)
    expect_identical(class(error)[[1L]], "GEModelR_numerical_error")
    expect_identical(error$requested_engine, "sparse")
    expect_identical(error$requested_backend, "Matrix")
    expect_identical(error$failure_phase, "candidate-acceptance")
    expect_false(error$accepted_numerical_state)
    expect_false(error$retryable_postsim)
    expect_true(is.list(error$remediation))
    expect_identical(commits, 0L)
    expectTransactionalStateIdentical(before, model)
  }

  reject_adapter_result(function(result) {
    result$output_structure <- NULL
    result
  }, "missing field.*output_structure")

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
  emitted <- FALSE
  original_emit <- getFromNamespace("sparse_emit_system", "GEModelR")
  testthat::local_mocked_bindings(
    sparse_emit_system = function(...) {
      emitted <<- TRUE
      original_emit(...)
    },
    .package = "GEModelR"
  )

  error <- tryCatch(model$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      backend = "StructuredSchurFGMRESCpp"
    ), error = identity)
  expect_match(
    conditionMessage(error),
    "Requested backend 'StructuredSchurFGMRESCpp'.*injected preflight failure.*Remediation:"
  )
  expect_identical(class(error)[[1L]], "GEModelR_capability_error")
  expect_identical(error$requested_engine, "sparse")
  expect_identical(error$requested_backend, "StructuredSchurFGMRESCpp")
  expect_identical(error$failure_phase, "capability-preflight")
  expect_false(error$accepted_numerical_state)
  expect_true(is.list(error$remediation))
  expect_false(emitted)
  expect_identical(sparse_state_data(model$sparseState), before)
  expect_false(isTRUE(runtime$active))
  expect_identical(model$lastDiagnostics$status, "capability_failed")
  expect_identical(
    model$lastDiagnostics$requested_backend,
    "StructuredSchurFGMRESCpp"
  )
  expect_identical(model$lastDiagnostics$implementation, "cpp")
  expect_identical(
    model$lastDiagnostics$condition_class, "GEModelR_capability_error"
  )
  expect_false(model$lastDiagnostics$accepted_numerical_state)
})

test_that("GEModel is the only exported package binding", {
  exported <- sort(getNamespaceExports("GEModelR"))
  expect_identical(exported, "GEModel")

  namespace_path <- testthat::test_path("..", "..", "NAMESPACE")
  if (!file.exists(namespace_path)) {
    namespace_path <- file.path(
      getNamespaceInfo(asNamespace("GEModelR"), "path"), "NAMESPACE"
    )
  }
  namespace <- readLines(namespace_path)
  expect_true(any(grepl("^export\\(GEModel\\)$", namespace)))
  expect_false(any(grepl("exportPattern", namespace, fixed = TRUE)))

  private_helpers <- c(
    "processTablo", "sparse_compile_spec", "sparse_solve_model",
    "solve_sparse_system", "sparse_exact_schur_solve"
  )
  expect_false(any(private_helpers %in% exported))
  expect_false(any(startsWith(exported, ".GEModelR_")))
})
