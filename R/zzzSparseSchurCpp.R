# Experimental native acceleration for the structured Schur solver.

.sparse_schur_cpp_runtime = new.env(parent = emptyenv())
.sparse_schur_cpp_runtime$active = FALSE
.sparse_schur_cpp_runtime$initialized = FALSE
.sparse_schur_cpp_runtime$capabilities = NULL
.sparse_schur_cpp_runtime$live_dense_factors = list()
.sparse_schur_cpp_runtime$build_diagnostics = list()

.sparse_schur_cpp_symbols = c(
  "_tabloToR_tabloToR_schur_cpp_capabilities",
  "_tabloToR_tabloToR_sparse_lu_solve",
  "_tabloToR_tabloToR_sparse_pattern_hash",
  "_tabloToR_tabloToR_schur_accumulate_global",
  "_tabloToR_tabloToR_schur_accumulate_batch",
  "_tabloToR_tabloToR_dense_lu_factor",
  "_tabloToR_tabloToR_dense_lu_solve",
  "_tabloToR_tabloToR_dense_lu_release",
  "_tabloToR_tabloToR_eliminate_blocks",
  "_tabloToR_tabloToR_reconstruct_blocks"
)

.sparse_schur_cpp_reset = function() {
  .sparse_schur_cpp_runtime$initialized = FALSE
  .sparse_schur_cpp_runtime$capabilities = NULL
  invisible(NULL)
}

.sparse_schur_cpp_require_impl = function(expected_abi = 1L, threads = 1L) {
  threads = suppressWarnings(as.integer(threads)[1L])
  fail = function(message) {
    stop(sprintf(
      paste0(
        "backend='StructuredSchurFGMRESCpp' initialization failed: %s. ",
        "No fallback was attempted."
      ), message
    ), call. = FALSE)
  }
  if (is.na(threads) || threads < 1L) fail("thread count must be positive")
  if (isTRUE(.sparse_schur_cpp_runtime$initialized)) {
    capabilities = .sparse_schur_cpp_runtime$capabilities
  } else {
    missing = .sparse_schur_cpp_symbols[!vapply(
      .sparse_schur_cpp_symbols,
      is.loaded, logical(1), PACKAGE = "tabloToR"
    )]
    if (length(missing)) {
      fail(sprintf("registered native routine is missing: %s", missing[[1L]]))
    }
    wrappers = list(
      .tabloToR_schur_cpp_capabilities = 0L,
      .tabloToR_sparse_lu_solve = 2L,
      .tabloToR_sparse_pattern_hash = 1L,
      .tabloToR_schur_accumulate_global = 7L,
      .tabloToR_schur_accumulate_batch = 9L,
      .tabloToR_dense_lu_factor = 1L,
      .tabloToR_dense_lu_solve = 2L,
      .tabloToR_dense_lu_release = 1L
    )
    for (name in names(wrappers)) {
      fun = get0(name, mode = "function", inherits = TRUE)
      if (!is.function(fun) || length(formals(fun)) != wrappers[[name]]) {
        fail(sprintf("private wrapper %s has an incompatible arity", name))
      }
    }
    capabilities = tryCatch(
      .tabloToR_schur_cpp_capabilities(),
      error = function(error) fail(conditionMessage(error))
    )
    required = c("abi", "matrix_contract", "lapack", "openmp",
                 "max_threads", "kernels")
    if (!is.list(capabilities) ||
        !all(required %in% names(capabilities))) {
      fail("native capability payload is incomplete")
    }
    if (!identical(as.integer(capabilities$abi), as.integer(expected_abi))) {
      fail(sprintf("ABI %s is incompatible with expected ABI %s",
                   capabilities$abi, expected_abi))
    }
    if (!identical(as.character(capabilities$matrix_contract),
                   "sparseLU-v1") || !isTRUE(capabilities$lapack)) {
      fail("Matrix sparseLU or LAPACK capability is incompatible")
    }
    required_kernels = c("sparse_lu_solve", "schur_global", "schur_batch",
                         "dense_lu", "pattern_hash")
    if (!all(required_kernels %in% as.character(capabilities$kernels))) {
      fail("required native kernels are unavailable")
    }
    contract = tryCatch({
      A = Matrix::sparseMatrix(
        i = c(1L, 1L, 2L), j = c(1L, 2L, 2L),
        x = c(4, 1, 3), dims = c(2L, 2L)
      )
      factor = Matrix::lu(A, order = 1L)
      rhs = c(5, 6)
      native = as.numeric(.tabloToR_sparse_lu_solve(factor, rhs))
      reference = as.numeric(Matrix::solve(factor, rhs))
      isTRUE(max(abs(native - reference)) <= 1e-12)
    }, error = function(error) error)
    if (inherits(contract, "error") || !isTRUE(contract)) {
      message = if (inherits(contract, "error")) {
        conditionMessage(contract)
      } else "deterministic sparseLU self-test disagreed with Matrix"
      fail(message)
    }
    .sparse_schur_cpp_runtime$capabilities = capabilities
    .sparse_schur_cpp_runtime$initialized = TRUE
  }
  maximum = suppressWarnings(as.integer(capabilities$max_threads)[1L])
  if (threads > 1L && !isTRUE(capabilities$openmp)) {
    fail("multiple threads were requested from a serial build")
  }
  if (is.na(maximum) || maximum < 1L || threads > maximum) {
    fail(sprintf("requested %s threads but the native maximum is %s",
                 threads, maximum))
  }
  capabilities$threads_requested = threads
  capabilities$threads_effective = threads
  capabilities
}

.sparse_schur_cpp_runtime$require = .sparse_schur_cpp_require_impl

.sparse_make_state_reference = sparse_make_state
sparse_make_state = function(data) {
  state = .sparse_make_state_reference(data)
  state$.solver_cache = list()
  state
}

.sparse_set_closure_state_reference = sparse_set_closure_state
sparse_set_closure_state = function(model, exogenous_variables) {
  result = .sparse_set_closure_state_reference(model, exogenous_variables)
  if (is.environment(model$sparseState)) {
    model$sparseState$.solver_cache = list()
  }
  result
}

.sparse_cpp_pattern_entry = function(
    A, row_group, column_group, local_count, region_count, global_group,
    panel_size, region_batch_size) {
  state = .sparse_schur_cpp_runtime$state
  if (!is.environment(state)) {
    stop("C++ Schur structural cache has no state owner", call. = FALSE)
  }
  if (is.null(state$.solver_cache)) state$.solver_cache = list()
  key = "StructuredSchurFGMRESCpp"
  pattern_hash = as.character(.tabloToR_sparse_pattern_hash(A))
  index_key = .sparse_schur_cpp_runtime$index_key
  previous = state$.solver_cache[[key]]
  reasons = character()
  if (is.null(previous)) reasons = "empty"
  if (!is.null(previous)) {
    checks = list(
      abi = identical(previous$abi, 1L),
      index = identical(previous$index_key, index_key),
      pattern = identical(previous$pattern_hash, pattern_hash),
      rows = identical(previous$row_group, row_group),
      columns = identical(previous$column_group, column_group),
      local_count = identical(previous$local_count, as.integer(local_count)),
      region_count = identical(previous$region_count, as.integer(region_count)),
      global_group = identical(previous$global_group, as.integer(global_group)),
      panel_size = identical(previous$panel_size, as.integer(panel_size)),
      batch_size = identical(
        previous$region_batch_size, as.integer(region_batch_size)
      )
    )
    reasons = names(checks)[!unlist(checks, use.names = FALSE)]
  }
  if (!length(reasons)) {
    .sparse_schur_cpp_runtime$cache_event = list(
      hit = 1L, miss = 0L, reasons = character()
    )
    return(previous)
  }
  local_ids = seq.int(0L, local_count - 1L)
  region_ids = seq.int(local_count, local_count + region_count - 1L)
  external_ids = c(region_ids, global_group)
  local_rows = sparse_exact_schur_group_positions(row_group, local_ids)
  local_columns = sparse_exact_schur_group_positions(column_group, local_ids)
  external_rows_by_group = sparse_exact_schur_group_positions(
    row_group, external_ids
  )
  external_columns_by_group = sparse_exact_schur_group_positions(
    column_group, external_ids
  )
  entry = list(
    abi = 1L,
    index_key = index_key,
    pattern_hash = pattern_hash,
    row_group = as.integer(row_group),
    column_group = as.integer(column_group),
    local_count = as.integer(local_count),
    region_count = as.integer(region_count),
    global_group = as.integer(global_group),
    panel_size = as.integer(panel_size),
    region_batch_size = as.integer(region_batch_size),
    local_rows = local_rows,
    local_columns = local_columns,
    external_rows_by_group = external_rows_by_group,
    external_columns_by_group = external_columns_by_group
  )
  state$.solver_cache[[key]] = entry
  .sparse_schur_cpp_runtime$cache_event = list(
    hit = 0L, miss = 1L, reasons = reasons
  )
  entry
}

.sparse_cpp_dense_factor = function(matrix, name) {
  started = proc.time()[[3L]]
  pointer = tryCatch(
    .tabloToR_dense_lu_factor(as.matrix(matrix)),
    error = function(error) {
      stop(sprintf("Dense factorization failed for %s: %s",
                   name, conditionMessage(error)), call. = FALSE)
    }
  )
  .sparse_schur_cpp_runtime$live_dense_factors[[
    length(.sparse_schur_cpp_runtime$live_dense_factors) + 1L
  ]] = pointer
  attr(pointer, "factor_seconds") = proc.time()[[3L]] - started
  pointer
}

.sparse_cpp_release_live_factors = function() {
  factors = .sparse_schur_cpp_runtime$live_dense_factors
  if (length(factors)) for (factor in factors) {
    try(.tabloToR_dense_lu_release(factor), silent = TRUE)
  }
  .sparse_schur_cpp_runtime$live_dense_factors = list()
  invisible(NULL)
}

.sparse_exact_schur_solve_factor_reference = sparse_exact_schur_solve_factor
sparse_exact_schur_solve_factor = function(factor, rhs, name = "block") {
  if (inherits(factor, "tabloToR_dense_lu")) {
    result = tryCatch(
      .tabloToR_dense_lu_solve(factor, rhs),
      error = function(error) error
    )
    if (inherits(result, "error")) {
      stop(sprintf("Factor solve failed for %s: %s",
                   name, conditionMessage(result)), call. = FALSE)
    }
    result = as.matrix(result)
    if (any(!is.finite(result))) {
      stop(sprintf("Factor solve returned non-finite values for %s", name),
           call. = FALSE)
    }
    return(result)
  }
  if (isTRUE(.sparse_schur_cpp_runtime$active) &&
      methods::is(factor, "sparseLU")) {
    result = tryCatch(
      .tabloToR_sparse_lu_solve(factor, rhs),
      error = function(error) error
    )
    if (inherits(result, "error")) {
      stop(sprintf("Native sparse factor solve failed for %s: %s",
                   name, conditionMessage(result)), call. = FALSE)
    }
    result = as.matrix(result)
    if (any(!is.finite(result))) {
      stop(sprintf("Native factor solve returned non-finite values for %s", name),
           call. = FALSE)
    }
    return(result)
  }
  .sparse_exact_schur_solve_factor_reference(factor, rhs, name)
}

.sparse_cpp_sum_counters = function(values) {
  if (!length(values)) return(list())
  sum_fields = c(
    "calls", "panels_inspected", "zero_panels_skipped", "panels_solved",
    "columns_solved", "panel_extract_seconds",
    "sparse_triangular_solve_seconds", "multiply_accumulate_seconds"
  )
  result = lapply(sum_fields, function(name) {
    sum(vapply(values, function(value) as.numeric(value[[name]]), numeric(1)))
  })
  names(result) = sum_fields
  result$peak_panel_buffer_bytes = max(vapply(
    values, function(value) as.numeric(value$peak_panel_buffer_bytes), numeric(1)
  ))
  result
}

.sparse_exact_schur_build_cpp = function(
    A, row_group, column_group, local_count, region_count,
    global_group = local_count + region_count, rhs = NULL,
    row_scale = NULL, column_scale = NULL, lu_order = 3L,
    region_batch_size = 8L, panel_size = 64L) {
  sparse_schur_require_matrix()
  if (!methods::is(A, "dgCMatrix")) A = methods::as(A, "dgCMatrix")
  partition = sparse_exact_schur_validate_partition(
    A, row_group, column_group, local_count, region_count, global_group
  )
  n = nrow(A)
  if (!is.null(rhs)) {
    rhs = as.numeric(rhs)
    if (length(rhs) != n || any(!is.finite(rhs))) {
      stop("Exact Schur rhs must be a finite vector of matrix length",
           call. = FALSE)
    }
  }
  lu_order = suppressWarnings(as.integer(lu_order)[1L])
  region_batch_size = suppressWarnings(as.integer(region_batch_size)[1L])
  panel_size = suppressWarnings(as.integer(panel_size)[1L])
  threads = suppressWarnings(as.integer(getOption(
    "tabloToR.sparse.schur_cpp_threads", 1L
  ))[1L])
  if (is.na(lu_order) || lu_order < 0L || lu_order > 3L ||
      is.na(region_batch_size) || region_batch_size < 1L ||
      is.na(panel_size) || panel_size < 1L || is.na(threads) || threads < 1L) {
    stop("Invalid native Schur controls", call. = FALSE)
  }
  if (is.null(row_scale)) {
    row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(A))), 1e-12)
  }
  if (is.null(column_scale)) {
    column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(A))), 1e-12)
  }
  row_scale = as.numeric(row_scale)
  column_scale = as.numeric(column_scale)
  if (length(row_scale) != n || length(column_scale) != n ||
      any(!is.finite(row_scale)) || any(!is.finite(column_scale)) ||
      any(row_scale <= 0) || any(column_scale <= 0)) {
    stop("Schur row and column scales must be positive finite vectors",
         call. = FALSE)
  }
  structure = .sparse_cpp_pattern_entry(
    A, partition$row_group, partition$column_group,
    local_count, region_count, global_group, panel_size, region_batch_size
  )
  local_rows = structure$local_rows
  local_columns = structure$local_columns
  external_rows_by_group = structure$external_rows_by_group
  external_columns_by_group = structure$external_columns_by_group
  external_rows = unlist(external_rows_by_group, use.names = FALSE)
  external_columns = unlist(external_columns_by_group, use.names = FALSE)
  if (!identical(length(external_rows), length(external_columns))) {
    stop("Exact Schur partition has inconsistent external dimensions",
         call. = FALSE)
  }
  scaled = sparse_scale_dgCMatrix(A, row_scale, column_scale)
  local_factor_start = proc.time()[[3L]]
  local_factors = lapply(seq_len(local_count), function(id) {
    block = Matrix::drop0(
      scaled[local_rows[[id]], local_columns[[id]], drop = FALSE]
    )
    tryCatch(
      Matrix::lu(block, order = lu_order),
      error = function(error) {
        stop(sprintf("Commodity block %s factorization failed: %s",
                     id, conditionMessage(error)), call. = FALSE)
      }
    )
  })
  local_factor_seconds = proc.time()[[3L]] - local_factor_start
  D = Matrix::drop0(scaled[external_rows, external_columns, drop = FALSE])
  right = lapply(seq_len(local_count), function(id) {
    Matrix::drop0(scaled[local_rows[[id]], external_columns, drop = FALSE])
  })
  left = lapply(seq_len(local_count), function(id) {
    Matrix::drop0(scaled[external_rows, local_columns[[id]], drop = FALSE])
  })
  scaled = NULL
  region_positions = lapply(seq_len(region_count), function(id) {
    seq_len(length(external_rows_by_group[[id]])) +
      sum(vapply(external_rows_by_group[seq_len(id - 1L)],
                 length, integer(1)))
  })
  global_position = seq.int(
    sum(vapply(external_rows_by_group[seq_len(region_count)],
               length, integer(1))) + 1L,
    length.out = length(external_rows_by_group[[region_count + 1L]])
  )
  native_start = proc.time()[[3L]]
  global_result = .tabloToR_schur_accumulate_global(
    local_factors, left, right, D, region_positions,
    as.integer(global_position), panel_size
  )
  regional_blocks = vector("list", region_count)
  global_region = vector("list", region_count)
  batch_diagnostics = list(global_result$diagnostics)
  batch_starts = seq.int(1L, region_count, by = region_batch_size)
  for (batch_start in batch_starts) {
    batch = seq.int(
      batch_start, min(region_count, batch_start + region_batch_size - 1L)
    )
    result = .tabloToR_schur_accumulate_batch(
      local_factors, left, right, D, region_positions,
      as.integer(global_position), as.integer(batch), panel_size, threads
    )
    regional_blocks[batch] = result$regional
    global_region[batch] = result$global_region
    batch_diagnostics[[length(batch_diagnostics) + 1L]] = result$diagnostics
  }
  native_build_seconds = proc.time()[[3L]] - native_start
  region_global = global_result$region_global
  global_global = global_result$global_global
  regional_factor_start = proc.time()[[3L]]
  regional_factors = lapply(seq_len(region_count), function(id) {
    .sparse_cpp_dense_factor(
      regional_blocks[[id]], sprintf("regional Schur block %s", id)
    )
  })
  regional_dense_factor_seconds = proc.time()[[3L]] - regional_factor_start
  regional_solve_start = proc.time()[[3L]]
  global_correction = global_global
  for (region_id in seq_len(region_count)) {
    regional_to_global = sparse_exact_schur_solve_factor(
      regional_factors[[region_id]], region_global[[region_id]],
      sprintf("regional Schur block %s", region_id)
    )
    global_correction = global_correction -
      global_region[[region_id]] %*% regional_to_global
  }
  regional_dense_solve_seconds = proc.time()[[3L]] - regional_solve_start
  global_factor_start = proc.time()[[3L]]
  global_factor = .sparse_cpp_dense_factor(
    global_correction, "global Schur arrowhead block"
  )
  global_dense_factor_seconds = proc.time()[[3L]] - global_factor_start
  rhs_scaled = if (is.null(rhs)) NULL else rhs * row_scale
  reduced_rhs = NULL
  if (!is.null(rhs_scaled)) {
    reduced_rhs = rhs_scaled[external_rows]
    for (local_id in seq_len(local_count)) {
      local_solution = sparse_exact_schur_solve_factor(
        local_factors[[local_id]], rhs_scaled[local_rows[[local_id]]],
        sprintf("commodity block %s", local_id)
      )
      reduced_rhs = reduced_rhs - as.numeric(left[[local_id]] %*% local_solution)
    }
  }
  counters = .sparse_cpp_sum_counters(batch_diagnostics)
  cache_event = .sparse_schur_cpp_runtime$cache_event
  diagnostics = c(list(
    dimension = n,
    external_dimension = length(external_rows),
    local_block_count = local_count,
    regional_block_count = region_count,
    global_block_size = length(global_position),
    structural_nnz = length(A@x),
    panel_size = panel_size,
    region_batch_size = region_batch_size,
    dense_full_system_operations = FALSE,
    local_sparse_factor_seconds = local_factor_seconds,
    native_schur_build_seconds = native_build_seconds,
    regional_dense_factor_seconds = regional_dense_factor_seconds,
    regional_dense_solve_seconds = regional_dense_solve_seconds,
    global_dense_factor_seconds = global_dense_factor_seconds,
    global_dense_solve_seconds = 0,
    structural_cache_hits = cache_event$hit,
    structural_cache_misses = cache_event$miss,
    structural_cache_rebuild_reasons = cache_event$reasons,
    numeric_refactorizations = 1L,
    threads_requested = threads,
    threads_effective = threads
  ), counters)
  .sparse_schur_cpp_runtime$build_diagnostics[[
    length(.sparse_schur_cpp_runtime$build_diagnostics) + 1L
  ]] = diagnostics
  structure(list(
    dimension = n,
    local_count = local_count,
    region_count = region_count,
    global_group = as.integer(global_group),
    row_scale = row_scale,
    column_scale = column_scale,
    local_rows = local_rows,
    local_columns = local_columns,
    local_factors = local_factors,
    external_rows = as.integer(external_rows),
    external_columns = as.integer(external_columns),
    external_group_positions = region_positions,
    D = D,
    left = left,
    right = right,
    regional_factors = regional_factors,
    region_global = region_global,
    global_region = global_region,
    global_factor = global_factor,
    global_position = global_position,
    reduced_rhs = reduced_rhs,
    diagnostics = diagnostics
  ), class = "sparseExactSchurSystem")
}

.sparse_exact_schur_build_reference = sparse_exact_schur_build
sparse_exact_schur_build = function(...) {
  if (isTRUE(.sparse_schur_cpp_runtime$active)) {
    .sparse_exact_schur_build_cpp(...)
  } else {
    .sparse_exact_schur_build_reference(...)
  }
}

.sparse_exact_schur_solve_reference = sparse_exact_schur_solve
sparse_exact_schur_solve = function(...) {
  if (!isTRUE(.sparse_schur_cpp_runtime$active)) {
    return(.sparse_exact_schur_solve_reference(...))
  }
  .sparse_schur_cpp_runtime$live_dense_factors = list()
  on.exit(.sparse_cpp_release_live_factors(), add = TRUE)
  result = .sparse_exact_schur_solve_reference(...)
  result$system = NULL
  result
}

.sparse_solve_one_step_reference = sparse_solve_one_step
sparse_solve_one_step = function(state, model, index, shocks, backend,
                                 reduction, measure = FALSE,
                                 structured_partition = NULL) {
  result = .sparse_solve_one_step_reference(
    state, model, index, shocks, backend, reduction, measure,
    structured_partition
  )
  if (isTRUE(.sparse_schur_cpp_runtime$active) &&
      !is.null(result$solver_diagnostics)) {
    result$solver_diagnostics$solution = NULL
  }
  result
}

.sparse_cpp_aggregate_diagnostics = function(values) {
  if (!length(values)) return(list())
  sum_names = c(
    "local_sparse_factor_seconds", "native_schur_build_seconds",
    "regional_dense_factor_seconds", "regional_dense_solve_seconds",
    "global_dense_factor_seconds", "global_dense_solve_seconds",
    "calls", "panels_inspected", "zero_panels_skipped", "panels_solved",
    "columns_solved", "panel_extract_seconds",
    "sparse_triangular_solve_seconds", "multiply_accumulate_seconds",
    "structural_cache_hits", "structural_cache_misses",
    "numeric_refactorizations"
  )
  result = lapply(sum_names, function(name) {
    sum(vapply(values, function(value) {
      item = value[[name]]
      if (is.null(item)) 0 else as.numeric(item)
    }, numeric(1)))
  })
  names(result) = sum_names
  result$peak_panel_buffer_bytes = max(vapply(values, function(value) {
    as.numeric(value$peak_panel_buffer_bytes)
  }, numeric(1)))
  result$structural_cache_rebuild_reasons = unique(unlist(lapply(
    values, function(value) value$structural_cache_rebuild_reasons
  ), use.names = FALSE))
  result
}

.sparse_solve_model_reference = sparse_solve_model
sparse_solve_model = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix",
                              reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  if (!identical(backend, "StructuredSchurFGMRESCpp")) {
    return(.sparse_solve_model_reference(
      model, iter, steps, postsim, diagnostics, output, variables,
      dimensions, backend, reduction, memory_budget
    ))
  }
  threads = getOption("tabloToR.sparse.schur_cpp_threads", 1L)
  capabilities = .sparse_schur_cpp_runtime$require(
    expected_abi = 1L, threads = threads
  )
  .sparse_schur_cpp_runtime$active = TRUE
  .sparse_schur_cpp_runtime$state = model$sparseState
  .sparse_schur_cpp_runtime$index_key = sparse_pattern_key(model$sparseIndex)
  .sparse_schur_cpp_runtime$build_diagnostics = list()
  on.exit({
    .sparse_schur_cpp_runtime$active = FALSE
    .sparse_schur_cpp_runtime$state = NULL
    .sparse_schur_cpp_runtime$index_key = NULL
    .sparse_cpp_release_live_factors()
  }, add = TRUE)
  result = .sparse_solve_model_reference(
    model, iter, steps, postsim, diagnostics, output, variables,
    dimensions, "StructuredSchurFGMRES", reduction, memory_budget
  )
  if (isTRUE(diagnostics)) {
    builds = .sparse_schur_cpp_runtime$build_diagnostics
    aggregate = .sparse_cpp_aggregate_diagnostics(builds)
    residuals = vapply(model$lastDiagnostics$true_residual_history,
                       function(value) value$metrics$relative_l2, numeric(1))
    model$lastDiagnostics$diagnostics_schema_version = 2L
    model$lastDiagnostics$solver_backend = "StructuredSchurFGMRESCpp"
    model$lastDiagnostics$solver_backend_impl = "cpp"
    model$lastDiagnostics$max_full_relative_residual = if (length(residuals)) {
      max(residuals)
    } else NA_real_
    model$lastDiagnostics$schur_build = aggregate
    model$lastDiagnostics$native = list(
      requested = TRUE,
      available = TRUE,
      initialized = TRUE,
      abi_version = capabilities$abi,
      openmp_compiled = capabilities$openmp,
      threads_requested = capabilities$threads_requested,
      threads_effective_max = capabilities$threads_effective,
      structural_cache_hits = aggregate$structural_cache_hits,
      structural_cache_misses = aggregate$structural_cache_misses,
      structural_cache_rebuild_reasons =
        aggregate$structural_cache_rebuild_reasons,
      numeric_refactorizations = aggregate$numeric_refactorizations,
      workspace_peak_bytes = aggregate$peak_panel_buffer_bytes
    )
  }
  invisible(result)
}
