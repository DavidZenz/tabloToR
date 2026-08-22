# Aggregate diagnostics for both structured Schur implementations.

.sparse_reference_schur_metrics = new.env(parent = emptyenv())
.sparse_reference_schur_metrics$active = FALSE
.sparse_reference_schur_metrics$current = NULL
.sparse_reference_schur_metrics$history = list()

.sparse_factor_solve_diagnostics_dispatch = sparse_exact_schur_solve_factor
sparse_exact_schur_solve_factor = function(factor, rhs, name = "block") {
  started = proc.time()[[3L]]
  result = .sparse_factor_solve_diagnostics_dispatch(factor, rhs, name)
  elapsed = proc.time()[[3L]] - started
  metrics = .sparse_reference_schur_metrics
  if (isTRUE(metrics$active) && methods::is(factor, "sparseLU") &&
      length(dim(rhs)) == 2L) {
    metrics$current$panels_solved = metrics$current$panels_solved + 1L
    metrics$current$columns_solved = metrics$current$columns_solved + ncol(rhs)
    metrics$current$sparse_triangular_solve_seconds =
      metrics$current$sparse_triangular_solve_seconds + elapsed
  }
  result
}

.sparse_dense_factor_diagnostics_dispatch = sparse_dense_factor
sparse_dense_factor = function(block, order = 3L, name = "block") {
  started = proc.time()[[3L]]
  result = .sparse_dense_factor_diagnostics_dispatch(block, order, name)
  elapsed = proc.time()[[3L]] - started
  metrics = .sparse_reference_schur_metrics
  if (isTRUE(metrics$active)) {
    field = if (grepl("global", name, fixed = TRUE)) {
      "global_dense_factor_seconds"
    } else "regional_dense_factor_seconds"
    metrics$current[[field]] = metrics$current[[field]] + elapsed
  }
  result
}

.sparse_schur_build_diagnostics_dispatch = sparse_exact_schur_build
sparse_exact_schur_build = function(
    A, row_group, column_group, local_count, region_count,
    global_group = local_count + region_count, rhs = NULL,
    row_scale = NULL, column_scale = NULL, lu_order = 3L,
    region_batch_size = 8L, panel_size = 64L) {
  if (isTRUE(.sparse_schur_cpp_runtime$active)) {
    return(.sparse_schur_build_diagnostics_dispatch(
      A, row_group, column_group, local_count, region_count,
      global_group, rhs, row_scale, column_scale, lu_order,
      region_batch_size, panel_size
    ))
  }
  metrics = .sparse_reference_schur_metrics
  metrics$current = list(
    panels_solved = 0L,
    columns_solved = 0L,
    sparse_triangular_solve_seconds = 0,
    regional_dense_factor_seconds = 0,
    global_dense_factor_seconds = 0
  )
  metrics$active = TRUE
  started = proc.time()[[3L]]
  on.exit({ metrics$active = FALSE }, add = TRUE)
  result = .sparse_schur_build_diagnostics_dispatch(
    A, row_group, column_group, local_count, region_count,
    global_group, rhs, row_scale, column_scale, lu_order,
    region_batch_size, panel_size
  )
  build_seconds = proc.time()[[3L]] - started
  positions = result$external_group_positions
  global_size = length(result$global_position)
  inspected = 0L
  for (batch_start in seq.int(1L, region_count, by = region_batch_size)) {
    batch = seq.int(
      batch_start, min(region_count, batch_start + region_batch_size - 1L)
    )
    target_count = sum(vapply(positions[batch], length, integer(1))) +
      global_size
    inspected = inspected + local_count * ceiling(target_count / panel_size)
  }
  current = metrics$current
  current$build_calls = 1L
  current$panels_inspected = as.integer(inspected)
  current$zero_panels_skipped = as.integer(
    inspected - current$panels_solved
  )
  current$build_seconds = build_seconds
  current$panel_extract_seconds = NA_real_
  current$multiply_accumulate_seconds = max(
    0, build_seconds - current$sparse_triangular_solve_seconds -
      current$regional_dense_factor_seconds -
      current$global_dense_factor_seconds
  )
  current$peak_panel_buffer_bytes = max(vapply(
    result$local_rows, length, integer(1)
  )) * min(panel_size, length(result$external_columns)) * 16
  current$dense_full_system_operations = FALSE
  result$diagnostics = c(result$diagnostics, current)
  metrics$history[[length(metrics$history) + 1L]] = current
  result
}

.sparse_reference_schur_aggregate = function(values) {
  if (!length(values)) return(list())
  fields = c(
    "build_calls", "panels_inspected", "zero_panels_skipped",
    "panels_solved", "columns_solved", "build_seconds",
    "sparse_triangular_solve_seconds", "multiply_accumulate_seconds",
    "regional_dense_factor_seconds", "global_dense_factor_seconds"
  )
  result = lapply(fields, function(field) sum(vapply(values, function(value) {
    as.numeric(value[[field]])
  }, numeric(1)), na.rm = TRUE))
  names(result) = fields
  result$panel_extract_seconds = NA_real_
  result$peak_panel_buffer_bytes = max(vapply(
    values, function(value) as.numeric(value$peak_panel_buffer_bytes), numeric(1)
  ))
  result
}

.sparse_solve_model_diagnostics_dispatch = sparse_solve_model
sparse_solve_model = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix",
                              reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  collect_reference = isTRUE(diagnostics) &&
    identical(backend, "StructuredSchurFGMRES")
  if (collect_reference) .sparse_reference_schur_metrics$history = list()
  result = .sparse_solve_model_diagnostics_dispatch(
    model, iter, steps, postsim, diagnostics, output, variables,
    dimensions, backend, reduction, memory_budget
  )
  if (isTRUE(diagnostics)) {
    model$lastDiagnostics$diagnostics_schema_version = 2L
    if (is.null(model$lastDiagnostics$solver_backend_impl)) {
      model$lastDiagnostics$solver_backend_impl = "r"
    }
    if (is.null(model$lastDiagnostics$max_full_relative_residual)) {
      residuals = vapply(model$lastDiagnostics$true_residual_history,
                         function(value) value$metrics$relative_l2, numeric(1))
      model$lastDiagnostics$max_full_relative_residual = if (length(residuals)) {
        max(residuals)
      } else NA_real_
    }
    if (collect_reference) {
      model$lastDiagnostics$schur_build = .sparse_reference_schur_aggregate(
        .sparse_reference_schur_metrics$history
      )
    }
  }
  invisible(result)
}
