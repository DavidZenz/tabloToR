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
