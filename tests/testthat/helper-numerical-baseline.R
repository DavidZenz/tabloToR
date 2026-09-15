numericalBaselinePath = function(name) {
  normalizePath(
    testthat::test_path("baselines", "phase02", name),
    mustWork = TRUE
  )
}

loadNumericalTolerances = function(
    path = numericalBaselinePath("tolerances.csv")) {
  tolerances = read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = character()
  )
  required = c(
    "fixture", "conditioning", "tier", "solution_atol",
    "solution_rtol", "residual_rtol", "rationale", "reviewer"
  )
  missing_columns = setdiff(required, names(tolerances))
  if (length(missing_columns)) {
    stop(sprintf(
      "Numerical tolerances are missing column(s): %s",
      paste(missing_columns, collapse = ", ")
    ), call. = FALSE)
  }
  keys = paste(tolerances$fixture, tolerances$conditioning, sep = ":")
  if (anyDuplicated(keys)) {
    stop("Numerical tolerances contain duplicate fixture tiers",
         call. = FALSE)
  }
  numeric_columns = c("solution_atol", "solution_rtol", "residual_rtol")
  if (any(!vapply(tolerances[numeric_columns], is.numeric, logical(1))) ||
      any(!is.finite(as.matrix(tolerances[numeric_columns]))) ||
      any(as.matrix(tolerances[numeric_columns]) < 0)) {
    stop("Numerical tolerances must be finite non-negative values",
         call. = FALSE)
  }
  tolerances
}

numericalToleranceFor = function(fixture, conditioning = "ordinary") {
  tolerances = loadNumericalTolerances()
  selected = tolerances[
    tolerances$fixture == fixture &
      tolerances$conditioning == conditioning,
    , drop = FALSE
  ]
  if (nrow(selected) != 1L) {
    stop(sprintf(
      "Expected one numerical tolerance row for %s/%s, found %s",
      fixture, conditioning, nrow(selected)
    ), call. = FALSE)
  }
  selected
}

threeRegionMatrixCandidate = function(values = c(1, 2, -1)) {
  model = make_three_region_model()
  set_three_region_shocks(model, "preferred", values)
  state = model$sparseState
  index = sparse_rebuild_columns(model$sparseIndex, model$closure)
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(model$sparseSpec, index, state)
  }
  index = sparse_select_simulation_index(
    index, model$sparseSpec, state, postsim = FALSE
  )
  index$column_order = sparse_lhs_column_order(index, state)
  shocks = sparse_resolve_shocks(model, state, index)
  emitted = sparse_emit_system(state, index, shocks)
  solution = solve_sparse_system(
    emitted$A, emitted$rhs, backend = "Matrix", reduction = "off"
  )
  list(
    model = model,
    state = state,
    index = emitted$index,
    shocks = shocks,
    candidate = list(
      backend = "Matrix",
      solution = solution,
      coefficient_matrix = emitted$A,
      rhs = emitted$rhs,
      output_structure = describeCompatibilityStructure(solution)
    )
  )
}

loadNumericalExpectations = function(
    path = numericalBaselinePath("expectations.csv")) {
  expectations = read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = character()
  )
  required = c("fixture", "authority", "kind", "key", "value", "rationale")
  missing_columns = setdiff(required, names(expectations))
  if (length(missing_columns)) {
    stop(sprintf(
      "Numerical expectations are missing column(s): %s",
      paste(missing_columns, collapse = ", ")
    ), call. = FALSE)
  }
  keys = paste(
    expectations$fixture, expectations$authority,
    expectations$kind, expectations$key, sep = ":"
  )
  if (anyDuplicated(keys) || any(!nzchar(expectations$rationale))) {
    stop("Numerical expectations must have unique reviewed rows",
         call. = FALSE)
  }
  expectations
}

numericalBackendDeclarations = function() {
  data.frame(
    backend = c(
      "Matrix", "SparseM", "SuiteSparse", "StructuredSchurFGMRES",
      "StructuredSchurFGMRESCpp", "OpenMP", "legacy"
    ),
    authority = c(
      "Matrix", "Matrix", "Matrix", "StructuredSchurFGMRES",
      "StructuredSchurFGMRES", "StructuredSchurFGMRESCpp", "none"
    ),
    role = c(
      "generic-authority", "generic-candidate", "generic-candidate",
      "structured-authority", "structured-candidate", "acceleration",
      "compatibility-smoke"
    ),
    required = c(TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
}

numericalBackendCapability = function(backend, available = NULL,
                                       reason = NULL) {
  declarations = numericalBackendDeclarations()
  declaration = declarations[
    declarations$backend == backend, , drop = FALSE
  ]
  if (nrow(declaration) != 1L) {
    stop(sprintf("Unknown numerical backend capability: %s", backend),
         call. = FALSE)
  }
  if (!is.null(available)) {
    return(list(
      name = backend,
      available = isTRUE(available),
      required = declaration$required,
      reason = if (is.null(reason)) "mocked capability" else as.character(reason)
    ))
  }
  result = switch(
    backend,
    Matrix = list(available = requireNamespace("Matrix", quietly = TRUE),
                  reason = "Matrix package is unavailable"),
    SparseM = list(available = requireNamespace("SparseM", quietly = TRUE),
                   reason = "SparseM package is unavailable"),
    SuiteSparse = list(
      available = sparse_suite_sparse_available(),
      reason = paste(
        "Rcpp or the 64-bit SuiteSparse umfpack.h/libumfpack",
        "capability is unavailable"
      )
    ),
    StructuredSchurFGMRES = list(
      available = exists("sparse_exact_structured_solve", mode = "function"),
      reason = "structured R solver helpers are unavailable"
    ),
    StructuredSchurFGMRESCpp = {
      checked = tryCatch(
        .sparse_schur_cpp_runtime$require(expected_abi = 1L, threads = 1L),
        error = function(error) error
      )
      list(
        available = !inherits(checked, "error"),
        reason = if (inherits(checked, "error")) {
          conditionMessage(checked)
        } else "native structured capability is available"
      )
    },
    OpenMP = {
      checked = tryCatch(
        .sparse_schur_cpp_runtime$require(expected_abi = 1L, threads = 1L),
        error = function(error) error
      )
      if (inherits(checked, "error")) {
        list(available = FALSE, reason = conditionMessage(checked))
      } else {
        list(
          available = isTRUE(checked$openmp) &&
            as.integer(checked$max_threads) >= 2L,
          reason = if (isTRUE(checked$openmp)) {
            "OpenMP build exposes fewer than two threads"
          } else "native structured backend was built without OpenMP"
        )
      }
    },
    legacy = list(
      available = TRUE,
      reason = "legacy is compatibility smoke only"
    )
  )
  list(
    name = backend,
    available = isTRUE(result$available),
    required = declaration$required,
    reason = as.character(result$reason)
  )
}

optionalCapabilitySkipMessage = function(capability) {
  sprintf(
    "optional capability %s unavailable: %s",
    capability$name, capability$reason
  )
}

skipOptionalCapability = function(capability) {
  if (isTRUE(capability$required)) {
    if (!isTRUE(capability$available)) {
      stop(sprintf(
        "required capability %s unavailable: %s",
        capability$name, capability$reason
      ), call. = FALSE)
    }
    return(invisible(capability))
  }
  if (!isTRUE(capability$available)) {
    testthat::skip(optionalCapabilitySkipMessage(capability))
  }
  invisible(capability)
}

expectNumericalEquivalent = function(reference, candidate, tolerance,
                                      reference_system, candidate_system,
                                      info = NULL) {
  reference_structure = describeCompatibilityStructure(reference)
  candidate_structure = describeCompatibilityStructure(candidate)
  testthat::expect_identical(
    candidate_structure, reference_structure, info = info
  )
  reference_finite = !is.na(reference)
  candidate_finite = !is.na(candidate)
  testthat::expect_true(
    all(is.finite(reference[reference_finite])), info = info
  )
  testthat::expect_true(
    all(is.finite(candidate[candidate_finite])), info = info
  )
  comparable = reference_finite & candidate_finite
  difference = abs(candidate[comparable] - reference[comparable])
  limit = tolerance$solution_atol + tolerance$solution_rtol *
    pmax(abs(reference[comparable]), abs(candidate[comparable]))
  testthat::expect_true(all(difference <= limit), info = info)

  reference_residual = sparse_true_residual(
    reference_system$A, reference_system$solution, reference_system$rhs
  )
  candidate_residual = sparse_true_residual(
    candidate_system$A, candidate_system$solution, candidate_system$rhs
  )
  testthat::expect_true(
    reference_residual$relative_l2 <= tolerance$residual_rtol, info = info
  )
  testthat::expect_true(
    candidate_residual$relative_l2 <= tolerance$residual_rtol, info = info
  )
  invisible(list(
    reference_residual = reference_residual,
    candidate_residual = candidate_residual
  ))
}

runThreeRegionBackend = function(backend) {
  prepared = threeRegionMatrixCandidate()
  model = prepared$model
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", backend = backend,
    reduction = "off"
  )
  order = prepared$index$column_order
  system_solution = unname(model$solution)
  if (length(order)) system_solution = system_solution[order]
  list(
    model = model,
    output = model$solution,
    system = list(
      A = prepared$candidate$coefficient_matrix,
      rhs = prepared$candidate$rhs,
      solution = system_solution
    )
  )
}

phase02StructuredPartition = function(index, state) {
  list(
    stages = list(NULL),
    external = sparse_external_block_partition(index, state)
  )
}

runStructuredBackend = function(backend) {
  model = make_cpp_structured_model()
  state = model$sparseState
  index = sparse_rebuild_columns(model$sparseIndex, model$closure)
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(model$sparseSpec, index, state)
  }
  index = sparse_select_simulation_index(
    index, model$sparseSpec, state, postsim = FALSE
  )
  index$column_order = sparse_lhs_column_order(index, state)
  shocks = sparse_resolve_shocks(model, state, index)
  emitted = sparse_emit_system(state, index, shocks)
  testthat::with_mocked_bindings(
    model$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, backend = backend, output = "compact"
    ),
    sparse_gtap_elimination_partition = phase02StructuredPartition,
    .package = "GEModelR"
  )
  system_solution = unname(model$solution)
  if (length(index$column_order)) {
    system_solution = system_solution[index$column_order]
  }
  list(
    model = model,
    output = model$solution,
    system = list(
      A = emitted$A,
      rhs = emitted$rhs,
      solution = system_solution
    )
  )
}
