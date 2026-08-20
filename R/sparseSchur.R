# Standalone matrix-free Schur-complement prototype for square dgCMatrix systems.
# The retained local blocks are made block diagonal conservatively: every row or
# column incident to a cross-group structural entry is assigned to the separator.

sparse_schur_require_matrix = function() {
  if (!requireNamespace("Matrix", quietly = TRUE)) {
    stop("The sparse Schur prototype requires the Matrix package", call. = FALSE)
  }
}

sparse_schur_validate_input = function(A, rhs, row_group, column_group) {
  sparse_schur_require_matrix()
  if (!methods::is(A, "dgCMatrix")) {
    stop("A must be a Matrix::dgCMatrix", call. = FALSE)
  }
  if (nrow(A) != ncol(A) || nrow(A) < 1L) {
    stop("A must be a non-empty square sparse matrix", call. = FALSE)
  }
  if (length(A@x) && any(!is.finite(A@x))) {
    stop("A contains non-finite coefficients", call. = FALSE)
  }
  n = nrow(A)
  if (!is.numeric(rhs) || length(rhs) != n || any(!is.finite(rhs))) {
    stop("rhs must be a finite numeric vector with length nrow(A)",
         call. = FALSE)
  }
  normalize_group = function(value, name) {
    if (!is.integer(value)) {
      if (!is.numeric(value) || any(!is.finite(value))) {
        stop(sprintf("%s must be an integer vector", name), call. = FALSE)
      }
      integer_value = suppressWarnings(as.integer(value))
      if (anyNA(integer_value) || any(value != integer_value)) {
        stop(sprintf("%s must be an integer vector", name), call. = FALSE)
      }
      value = integer_value
    }
    if (length(value) != n || anyNA(value)) {
      stop(sprintf("%s must have length nrow(A) and no missing values", name),
           call. = FALSE)
    }
    value
  }
  list(
    A = A,
    rhs = as.numeric(rhs),
    row_group = normalize_group(row_group, "row_group"),
    column_group = normalize_group(column_group, "column_group")
  )
}

sparse_schur_group_layout = function(row_group, column_group) {
  # Avoid concatenating two full group vectors.  The number of group labels is
  # small relative to the number of equations in the intended application.
  levels = sort(unique(row_group))
  missing = setdiff(sort(unique(column_group)), levels)
  if (length(missing)) levels = sort(c(levels, missing))
  row_id = match(row_group, levels)
  column_id = match(column_group, levels)
  row_counts = tabulate(row_id, nbins = length(levels))
  column_counts = tabulate(column_id, nbins = length(levels))
  row_order = order(row_id, seq_along(row_id), method = "radix")
  column_order = order(column_id, seq_along(column_id), method = "radix")
  list(
    levels = levels,
    row_id = row_id,
    column_id = column_id,
    row_counts = row_counts,
    column_counts = column_counts,
    row_order = row_order,
    column_order = column_order
  )
}

sparse_schur_interface_flags = function(A, row_group, column_group,
                                        chunk_size = 4096L) {
  n = nrow(A)
  chunk_size = as.integer(chunk_size)[1L]
  if (is.na(chunk_size) || chunk_size < 1L) {
    stop("chunk_size must be a positive integer", call. = FALSE)
  }
  row_interface = rep(FALSE, n)
  column_interface = rep(FALSE, n)
  cross_entries = 0
  if (ncol(A)) {
    starts = seq.int(1L, ncol(A), by = chunk_size)
    for (first in starts) {
      last = min(ncol(A), first + chunk_size - 1L)
      first_entry = A@p[[first]] + 1L
      last_entry = A@p[[last + 1L]]
      if (first_entry > last_entry) next
      entries = seq.int(first_entry, last_entry)
      rows = A@i[entries] + 1L
      counts = diff(A@p[first:(last + 1L)])
      columns = rep.int(seq.int(first, last), counts)
      cross = row_group[rows] != column_group[columns]
      if (any(cross)) {
        cross_rows = rows[cross]
        cross_columns = columns[cross]
        row_interface[cross_rows] = TRUE
        column_interface[cross_columns] = TRUE
        cross_entries = cross_entries + sum(cross)
      }
    }
  }
  list(
    row = row_interface,
    column = column_interface,
    cross_entries = as.integer(cross_entries)
  )
}

sparse_schur_greedy_matching = function(block) {
  n_rows = nrow(block)
  n_columns = ncol(block)
  used = rep(FALSE, n_rows)
  matched_rows = integer()
  matched_columns = integer()
  if (!n_rows || !n_columns) {
    return(list(rows = matched_rows, columns = matched_columns,
                method = "greedy"))
  }
  for (column in seq_len(n_columns)) {
    first = block@p[[column]] + 1L
    last = block@p[[column + 1L]]
    if (first > last) next
    rows = block@i[first:last] + 1L
    available = rows[!used[rows]]
    if (!length(available)) next
    row = available[[1L]]
    used[[row]] = TRUE
    matched_rows = c(matched_rows, row)
    matched_columns = c(matched_columns, column)
  }
  list(rows = matched_rows, columns = matched_columns, method = "greedy")
}

sparse_schur_dmperm_matching = function(block) {
  if (!nrow(block) || !ncol(block)) {
    return(list(rows = integer(), columns = integer(), method = "dmperm"))
  }
  # The square fine blocks are structurally matched; rectangular blocks stay in S.
  decomposition = Matrix::dmperm(block, nAns = 4L, seed = 0L)
  block_count = min(length(decomposition$r), length(decomposition$s)) - 1L
  matched_rows = list()
  matched_columns = list()
  if (block_count > 0L) {
    for (part in seq_len(block_count)) {
      row_start = decomposition$r[[part]] + 1L
      row_end = decomposition$r[[part + 1L]]
      column_start = decomposition$s[[part]] + 1L
      column_end = decomposition$s[[part + 1L]]
      row_size = row_end - row_start + 1L
      column_size = column_end - column_start + 1L
      if (row_size > 0L && row_size == column_size) {
        matched_rows[[length(matched_rows) + 1L]] =
          decomposition$p[row_start:row_end]
        matched_columns[[length(matched_columns) + 1L]] =
          decomposition$q[column_start:column_end]
      }
    }
  }
  list(
    rows = if (length(matched_rows)) unlist(matched_rows, use.names = FALSE)
      else integer(),
    columns = if (length(matched_columns)) {
      unlist(matched_columns, use.names = FALSE)
    } else integer(),
    method = "dmperm"
  )
}

sparse_schur_local_matching = function(block, method = "dmperm") {
  # Greedy is a documented conservative fallback when dmperm is unavailable.
  if (method == "greedy") return(sparse_schur_greedy_matching(block))
  tryCatch(
    sparse_schur_dmperm_matching(block),
    error = function(error) {
      fallback = sparse_schur_greedy_matching(block)
      fallback$method = "greedy-fallback"
      fallback$error = conditionMessage(error)
      fallback
    }
  )
}

sparse_schur_factor_block = function(A, rows, columns, lu_order = 3L,
                                     factor_tolerance = 1e-8) {
  block = A[rows, columns, drop = FALSE]
  result = list(ok = FALSE, reason = NULL, factor = NULL)
  if (!length(block@x) || all(block@x == 0)) {
    result$reason = "local matched block has no nonzero numerical entries"
    return(result)
  }
  factor_warning = NULL
  factor = tryCatch(
    withCallingHandlers(
      Matrix::lu(block, order = lu_order),
      warning = function(warning) {
        factor_warning <<- conditionMessage(warning)
        invokeRestart("muffleWarning")
      }
    ),
    error = function(error) error
  )
  if (inherits(factor, "error")) {
    result$reason = conditionMessage(factor)
    return(result)
  }
  if (!is.null(factor_warning)) {
    result$reason = factor_warning
    return(result)
  }
  probe = rep.int(1, nrow(block))
  probe_solution = tryCatch(
    as.numeric(Matrix::solve(factor, probe)),
    error = function(error) error
  )
  if (inherits(probe_solution, "error")) {
    result$reason = paste("factor solve failed:", conditionMessage(probe_solution))
    return(result)
  }
  if (length(probe_solution) != length(probe) ||
      any(!is.finite(probe_solution))) {
    result$reason = "factor solve returned non-finite values"
    return(result)
  }
  probe_residual = as.numeric(block %*% probe_solution) - probe
  relative_residual = sqrt(as.numeric(crossprod(probe_residual))) /
    max(1, sqrt(as.numeric(crossprod(probe))))
  if (!is.finite(relative_residual) || relative_residual > factor_tolerance) {
    result$reason = sprintf(
      "local factor probe residual %.3e exceeds %.3e",
      relative_residual, factor_tolerance
    )
    return(result)
  }
  result$ok = TRUE
  result$factor = factor
  result
}

sparse_schur_build = function(A, row_group, column_group,
                               matching = c("dmperm", "greedy"),
                               lu_order = 3L,
                               factor_tolerance = 1e-8,
                               interface_chunk_size = 4096L) {
  input = sparse_schur_validate_input(A, numeric(nrow(A)),
                                      row_group, column_group)
  matching = match.arg(matching)
  lu_order = as.integer(lu_order)[1L]
  if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
    stop("lu_order must be an integer from 0 through 3", call. = FALSE)
  }
  if (!is.numeric(factor_tolerance) || length(factor_tolerance) != 1L ||
      !is.finite(factor_tolerance) || factor_tolerance <= 0) {
    stop("factor_tolerance must be a positive finite number", call. = FALSE)
  }
  A = input$A
  row_group = input$row_group
  column_group = input$column_group
  layout = sparse_schur_group_layout(row_group, column_group)
  interface = sparse_schur_interface_flags(
    A, row_group, column_group, chunk_size = interface_chunk_size
  )
  group_count = length(layout$levels)
  summary_group = data.frame(
    group = layout$levels,
    rows = layout$row_counts,
    columns = layout$column_counts,
    interface_rows = integer(group_count),
    interface_columns = integer(group_count),
    candidate_matched = integer(group_count),
    retained_matched = integer(group_count),
    stringsAsFactors = FALSE
  )
  blocks = list()
  block_failures = list()
  row_parts = list()
  column_parts = list()
  fallback_count = 0L

  for (group in seq_len(group_count)) {
    row_start = if (group == 1L) 1L else {
      sum(layout$row_counts[seq_len(group - 1L)]) + 1L
    }
    column_start = if (group == 1L) 1L else {
      sum(layout$column_counts[seq_len(group - 1L)]) + 1L
    }
    row_end = row_start + layout$row_counts[[group]] - 1L
    column_end = column_start + layout$column_counts[[group]] - 1L
    group_rows = if (layout$row_counts[[group]]) {
      layout$row_order[row_start:row_end]
    } else integer()
    group_columns = if (layout$column_counts[[group]]) {
      layout$column_order[column_start:column_end]
    } else integer()
    summary_group$interface_rows[[group]] =
      if (length(group_rows)) sum(interface$row[group_rows]) else 0L
    summary_group$interface_columns[[group]] =
      if (length(group_columns)) sum(interface$column[group_columns]) else 0L
    safe_rows = group_rows[!interface$row[group_rows]]
    safe_columns = group_columns[!interface$column[group_columns]]
    if (!length(safe_rows) || !length(safe_columns)) next
    local_block = A[safe_rows, safe_columns, drop = FALSE]
    local_match = sparse_schur_local_matching(local_block, matching)
    if (identical(local_match$method, "greedy-fallback")) {
      fallback_count = fallback_count + 1L
    }
    if (length(local_match$rows) != length(local_match$columns) ||
        !length(local_match$rows)) next
    matched_rows = safe_rows[local_match$rows]
    matched_columns = safe_columns[local_match$columns]
    summary_group$candidate_matched[[group]] = length(matched_rows)
    factor_result = sparse_schur_factor_block(
      A, matched_rows, matched_columns,
      lu_order = lu_order, factor_tolerance = factor_tolerance
    )
    if (!isTRUE(factor_result$ok)) {
      block_failures[[length(block_failures) + 1L]] = data.frame(
        group = layout$levels[[group]],
        matched = length(matched_rows),
        reason = factor_result$reason,
        stringsAsFactors = FALSE
      )
      next
    }
    block = list(
      group = layout$levels[[group]],
      rows = as.integer(matched_rows),
      columns = as.integer(matched_columns),
      factor = factor_result$factor
    )
    blocks[[length(blocks) + 1L]] = block
    row_parts[[length(row_parts) + 1L]] = block$rows
    column_parts[[length(column_parts) + 1L]] = block$columns
    summary_group$retained_matched[[group]] = length(matched_rows)
  }

  local_rows = if (length(row_parts)) {
    as.integer(unlist(row_parts, use.names = FALSE))
  } else integer()
  local_columns = if (length(column_parts)) {
    as.integer(unlist(column_parts, use.names = FALSE))
  } else integer()
  row_in_local = rep(FALSE, nrow(A))
  column_in_local = rep(FALSE, ncol(A))
  if (length(local_rows)) row_in_local[local_rows] = TRUE
  if (length(local_columns)) column_in_local[local_columns] = TRUE
  separator_rows = which(!row_in_local)
  separator_columns = which(!column_in_local)
  if (length(separator_rows) != length(separator_columns)) {
    stop("local matching left a nonsquare separator", call. = FALSE)
  }
  row_position = 0L
  column_position = 0L
  for (block_id in seq_along(blocks)) {
    block_size = length(blocks[[block_id]]$rows)
    blocks[[block_id]]$row_positions =
      row_position + seq_len(block_size)
    blocks[[block_id]]$column_positions =
      column_position + seq_len(block_size)
    row_position = row_position + block_size
    column_position = column_position + block_size
  }
  failure_table = if (length(block_failures)) {
    do.call(rbind, block_failures)
  } else {
    data.frame(
      group = layout$levels[integer()], matched = integer(),
      reason = character(), stringsAsFactors = FALSE
    )
  }
  workspace = new.env(parent = emptyenv())
  workspace$buffer = numeric(nrow(A))
  diagnostics = list(
    dimension = nrow(A),
    structural_entries = length(A@x),
    group_count = group_count,
    block_summary = summary_group,
    matched_rows = length(local_rows),
    matched_columns = length(local_columns),
    unmatched_rows = length(separator_rows),
    unmatched_columns = length(separator_columns),
    separator_size = length(separator_rows),
    interface_rows = sum(interface$row),
    interface_columns = sum(interface$column),
    cross_group_structural_entries = interface$cross_entries,
    local_factor_count = length(blocks),
    local_factor_failures = failure_table,
    matching = matching,
    matching_fallback_blocks = fallback_count,
    local_factor_order = lu_order,
    factor_tolerance = factor_tolerance
  )
  structure(
    list(
      A = A,
      row_group = row_group,
      column_group = column_group,
      rows = local_rows,
      columns = local_columns,
      separator_rows = as.integer(separator_rows),
      separator_columns = as.integer(separator_columns),
      blocks = blocks,
      workspace = workspace,
      diagnostics = diagnostics
    ),
    class = "sparseSchurSystem"
  )
}

sparse_schur_reuse_structure = function(system, A,
                                      lu_order = 3L,
                                      factor_tolerance = 1e-8) {
  if (!inherits(system, c("sparseSchurSystem", "sparseExactSchurSystem"))) {
    stop("system must be a sparse Schur system", call. = FALSE)
  }
  if (nrow(A) != nrow(system$A) || ncol(A) != ncol(system$A) ||
      !identical(system$A@i, A@i) ||
      !identical(system$A@p, A@p)) {
    return(NULL)
  }
  if (length(A@x) && any(!is.finite(A@x))) {
    stop("A contains non-finite coefficients", call. = FALSE)
  }
  lu_order = as.integer(lu_order)[1L]
  if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
    stop("lu_order must be an integer from 0 through 3", call. = FALSE)
  }
  updated_blocks = system$blocks
  for (id in seq_along(updated_blocks)) {
    block = updated_blocks[[id]]
    factor_result = sparse_schur_factor_block(
      A, block$rows, block$columns,
      lu_order = lu_order, factor_tolerance = factor_tolerance
    )
    if (!isTRUE(factor_result$ok)) {
      stop(sprintf(
        "local Schur refactor for group %s failed: %s",
        block$group, factor_result$reason
      ), call. = FALSE)
    }
    updated_blocks[[id]]$factor = factor_result$factor
  }
  system$A = A
  system$blocks = updated_blocks
  system$diagnostics$structural_entries = length(A@x)
  system$diagnostics$local_factor_order = lu_order
  system$diagnostics$factor_tolerance = factor_tolerance
  refactor_count = system$diagnostics$refactor_count
  if (is.null(refactor_count)) refactor_count = 0L
  system$diagnostics$refactor_count = as.integer(refactor_count + 1L)
  system
}

sparse_schur_block_multiply = function(system, input_columns, value,
                                        output_rows) {
  if (length(input_columns) != length(value)) {
    stop("block multiply input has incompatible length", call. = FALSE)
  }
  if (!length(output_rows)) return(numeric())
  if (!length(input_columns)) return(numeric(length(output_rows)))
  # Products use A directly and only one reusable full-length vector workspace.
  buffer = system$workspace$buffer
  buffer[] = 0
  buffer[input_columns] = value
  product = as.numeric(system$A %*% buffer)
  result = product[output_rows]
  rm(product)
  result
}

sparse_schur_local_solve = function(system, value) {
  if (length(value) != length(system$rows)) {
    stop("local solve input has incompatible length", call. = FALSE)
  }
  result = numeric(length(system$columns))
  if (!length(system$blocks)) return(result)
  for (block in system$blocks) {
    local_value = value[block$row_positions]
    local_solution = tryCatch(
      as.numeric(Matrix::solve(block$factor, local_value)),
      error = function(error) {
        stop(sprintf(
          "local Schur factor for group %s failed during solve: %s",
          block$group, conditionMessage(error)
        ), call. = FALSE)
      }
    )
    if (length(local_solution) != length(block$column_positions) ||
        any(!is.finite(local_solution))) {
      stop(sprintf(
        "local Schur factor for group %s returned invalid values", block$group
      ), call. = FALSE)
    }
    result[block$column_positions] = local_solution
  }
  result
}

sparse_schur_apply = function(system, value) {
  if (!inherits(system, "sparseSchurSystem")) {
    stop("system must be a sparseSchurSystem returned by sparse_schur_build",
         call. = FALSE)
  }
  if (length(value) != length(system$separator_columns) ||
      any(!is.finite(value))) {
    stop("Schur input must be a finite separator-length vector", call. = FALSE)
  }
  if (!length(value)) return(numeric())
  local_rhs = sparse_schur_block_multiply(
    system, system$separator_columns, value, system$rows
  )
  local_solution = sparse_schur_local_solve(system, local_rhs)
  direct_part = sparse_schur_block_multiply(
    system, system$separator_columns, value, system$separator_rows
  )
  coupling_part = sparse_schur_block_multiply(
    system, system$columns, local_solution, system$separator_rows
  )
  direct_part - coupling_part
}

sparse_schur_norm = function(value) {
  sqrt(as.numeric(crossprod(value)))
}

sparse_schur_fgmres = function(system, rhs, x0 = NULL, restart = 30L,
                                max_iterations = 200L, tolerance = 1e-8,
                                preconditioner = NULL,
                                true_residual_frequency = 1L) {
  if (!inherits(system, c("sparseSchurSystem", "sparseExactSchurSystem"))) {
    stop("system must be a sparse Schur system", call. = FALSE)
  }
  n = if (inherits(system, "sparseExactSchurSystem")) {
    length(system$external_columns)
  } else length(system$separator_columns)
  if (length(rhs) != n || any(!is.finite(rhs))) {
    stop("Schur rhs must be a finite separator-length vector", call. = FALSE)
  }
  restart = as.integer(restart)[1L]
  max_iterations = as.integer(max_iterations)[1L]
  true_residual_frequency = as.integer(true_residual_frequency)[1L]
  if (is.na(restart) || restart < 1L || is.na(max_iterations) ||
      max_iterations < 1L || is.na(true_residual_frequency) ||
      true_residual_frequency < 1L) {
    stop("restart, max_iterations, and true_residual_frequency must be positive",
         call. = FALSE)
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1L ||
      !is.finite(tolerance) || tolerance <= 0) {
    stop("tolerance must be a positive finite number", call. = FALSE)
  }
  if (!is.null(preconditioner) && !is.function(preconditioner)) {
    stop("preconditioner must be NULL or a function", call. = FALSE)
  }
  if (is.null(x0)) x0 = numeric(n)
  if (length(x0) != n || any(!is.finite(x0))) {
    stop("x0 must be a finite separator-length vector", call. = FALSE)
  }
  x = as.numeric(x0)
  rhs_scale = max(1, sparse_schur_norm(rhs))
  apply_operator = function(value) {
    result = if (inherits(system, "sparseExactSchurSystem")) {
      sparse_exact_schur_apply(system, value)
    } else sparse_schur_apply(system, value)
    if (length(result) != n || any(!is.finite(result))) {
      stop("Schur operator returned non-finite or incompatible values",
           call. = FALSE)
    }
    result
  }
  residual = rhs - apply_operator(x)
  true_absolute = sparse_schur_norm(residual)
  true_relative = true_absolute / rhs_scale
  history_iteration = 0L
  history_estimated = NA_real_
  history_absolute = true_absolute
  history_relative = true_relative
  history_restart = 0L
  if (!n || true_relative <= tolerance) {
    return(list(
      solution = x,
      converged = TRUE,
      iterations = 0L,
      residual_history = data.frame(
        iteration = history_iteration,
        estimated_relative = history_estimated,
        true_absolute = history_absolute,
        true_relative = history_relative,
        restart = history_restart
      )
    ))
  }

  converged = FALSE
  iterations = 0L
  while (iterations < max_iterations && !converged) {
    beta = sparse_schur_norm(residual)
    if (!is.finite(beta) || beta == 0) break
    V = list(residual / beta)
    Z = list()
    H = matrix(0, nrow = restart + 1L, ncol = restart)
    cosine = numeric(restart)
    sine = numeric(restart)
    g = numeric(restart + 1L)
    g[[1L]] = beta
    cycle_solution = x
    cycle_length = min(restart, max_iterations - iterations)
    cycle_finished = FALSE
    for (j in seq_len(cycle_length)) {
      candidate_basis = V[[j]]
      z = if (is.null(preconditioner)) {
        candidate_basis
      } else {
        preconditioned = tryCatch(
          preconditioner(candidate_basis, iterations + 1L),
          error = function(error) error
        )
        if (inherits(preconditioned, "error")) {
          stop(sprintf("FGMRES preconditioner failed: %s",
                       conditionMessage(preconditioned)), call. = FALSE)
        }
        as.numeric(preconditioned)
      }
      if (length(z) != n || any(!is.finite(z))) {
        stop("FGMRES preconditioner returned invalid values", call. = FALSE)
      }
      Z[[j]] = z
      w = apply_operator(z)
      h = numeric(j)
      # Two modified Gram-Schmidt passes keep the Arnoldi basis orthogonal.
      for (pass in 1:2) {
        for (i in seq_len(j)) {
          projection = as.numeric(crossprod(V[[i]], w))
          h[[i]] = h[[i]] + projection
          w = w - projection * V[[i]]
        }
      }
      h_next = sparse_schur_norm(w)
      H[seq_len(j), j] = h
      H[j + 1L, j] = h_next
      for (i in seq_len(j - 1L)) {
        rotated_top = cosine[[i]] * H[i, j] + sine[[i]] * H[i + 1L, j]
        H[i + 1L, j] = -sine[[i]] * H[i, j] + cosine[[i]] * H[i + 1L, j]
        H[i, j] = rotated_top
      }
      rotation_norm = sqrt(H[j, j]^2 + H[j + 1L, j]^2)
      if (rotation_norm == 0 || !is.finite(rotation_norm)) {
        cosine[[j]] = 1
        sine[[j]] = 0
      } else {
        cosine[[j]] = H[j, j] / rotation_norm
        sine[[j]] = H[j + 1L, j] / rotation_norm
      }
      rotated_rhs = cosine[[j]] * g[[j]] + sine[[j]] * g[[j + 1L]]
      g[[j + 1L]] = -sine[[j]] * g[[j]] + cosine[[j]] * g[[j + 1L]]
      g[[j]] = rotated_rhs
      H[j, j] = rotation_norm
      H[j + 1L, j] = 0
      upper = H[seq_len(j), seq_len(j), drop = FALSE]
      coefficients = tryCatch(
        backsolve(upper, g[seq_len(j)]),
        error = function(error) error
      )
      if (inherits(coefficients, "error") || any(!is.finite(coefficients))) {
        coefficients = tryCatch(qr.solve(upper, g[seq_len(j)]),
                                error = function(error) error)
      }
      if (inherits(coefficients, "error") || any(!is.finite(coefficients))) {
        stop("FGMRES least-squares solve failed", call. = FALSE)
      }
      candidate = x
      for (i in seq_len(j)) candidate = candidate + coefficients[[i]] * Z[[i]]
      cycle_solution = candidate
      iterations = iterations + 1L
      estimated_relative = abs(g[[j + 1L]]) / rhs_scale
      need_true = iterations %% true_residual_frequency == 0L ||
        iterations == max_iterations || h_next == 0
      if (need_true) {
        true_residual = rhs - apply_operator(candidate)
        true_absolute = sparse_schur_norm(true_residual)
        true_relative = true_absolute / rhs_scale
      } else {
        true_residual = NULL
        true_absolute = NA_real_
        true_relative = NA_real_
      }
      history_iteration = c(history_iteration, iterations)
      history_estimated = c(history_estimated, estimated_relative)
      history_absolute = c(history_absolute, true_absolute)
      history_relative = c(history_relative, true_relative)
      history_restart = c(history_restart, ceiling(iterations / restart))
      if (!is.null(true_residual) && true_relative <= tolerance) {
        x = candidate
        converged = TRUE
        cycle_finished = TRUE
        break
      }
      if (h_next == 0 || iterations >= max_iterations) {
        x = candidate
        cycle_finished = TRUE
        break
      }
      V[[j + 1L]] = w / h_next
    }
    if (converged) break
    x = if (cycle_finished) cycle_solution else candidate
    residual = rhs - apply_operator(x)
    true_absolute = sparse_schur_norm(residual)
    true_relative = true_absolute / rhs_scale
    if (true_relative <= tolerance) converged = TRUE
  }
  list(
    solution = x,
    converged = converged,
    iterations = iterations,
    residual_history = data.frame(
      iteration = history_iteration,
      estimated_relative = history_estimated,
      true_absolute = history_absolute,
      true_relative = history_relative,
      restart = history_restart
    )
  )
}

# Stable integration wrapper. It returns a sparseSchurResult list by default;
# set return_diagnostics = FALSE when only the numeric solution is needed.
sparse_schur_solve = function(A, rhs, row_group, column_group,
                              matching = c("dmperm", "greedy"),
                              lu_order = 3L,
                              factor_tolerance = 1e-8,
                              interface_chunk_size = 4096L,
                              restart = 30L,
                              max_iterations = 200L,
                              tolerance = 1e-8,
                              preconditioner = NULL,
                              true_residual_frequency = 1L,
                              return_diagnostics = TRUE,
                              system = NULL) {
  if (length(return_diagnostics) != 1L || !is.logical(return_diagnostics) ||
      is.na(return_diagnostics)) {
    stop("return_diagnostics must be TRUE or FALSE", call. = FALSE)
  }
  input = sparse_schur_validate_input(A, rhs, row_group, column_group)
  if (is.null(system)) {
    system = sparse_schur_build(
      input$A, input$row_group, input$column_group,
      matching = matching, lu_order = lu_order,
      factor_tolerance = factor_tolerance,
      interface_chunk_size = interface_chunk_size
    )
  } else {
    if (!inherits(system, "sparseSchurSystem") ||
        !identical(system$row_group, input$row_group) ||
        !identical(system$column_group, input$column_group)) {
      stop("Cached sparse Schur structure does not match the current system",
           call. = FALSE)
    }
    system = sparse_schur_reuse_structure(
      system, input$A, lu_order = lu_order,
      factor_tolerance = factor_tolerance
    )
    if (is.null(system)) {
      stop("Cached sparse Schur structure is invalid for the current matrix",
           call. = FALSE)
    }
  }
  rhs_local = input$rhs[system$rows]
  local_rhs_solution = sparse_schur_local_solve(system, rhs_local)
  reduced_rhs = input$rhs[system$separator_rows] -
    sparse_schur_block_multiply(
      system, system$columns, local_rhs_solution, system$separator_rows
    )
  full_rhs_scale = max(1, sparse_schur_norm(input$rhs))
  reduced_rhs_scale = max(1, sparse_schur_norm(reduced_rhs))
  reduced_tolerance = tolerance * min(1, full_rhs_scale / reduced_rhs_scale)
  reduced = sparse_schur_fgmres(
    system, reduced_rhs, restart = restart,
    max_iterations = max_iterations, tolerance = reduced_tolerance,
    preconditioner = preconditioner,
    true_residual_frequency = true_residual_frequency
  )
  solution_local = sparse_schur_local_solve(
    system,
    rhs_local - sparse_schur_block_multiply(
      system, system$separator_columns, reduced$solution, system$rows
    )
  )
  solution = numeric(nrow(input$A))
  if (length(system$columns)) solution[system$columns] = solution_local
  if (length(system$separator_columns)) {
    solution[system$separator_columns] = reduced$solution
  }
  full_residual = as.numeric(input$A %*% solution) - input$rhs
  full_absolute = sparse_schur_norm(full_residual)
  full_relative = full_absolute / max(1, sparse_schur_norm(input$rhs))
  diagnostics = system$diagnostics
  diagnostics$residual_history = reduced$residual_history
  diagnostics$reduced_converged = reduced$converged
  diagnostics$reduced_iterations = reduced$iterations
  diagnostics$reduced_tolerance = reduced_tolerance
  diagnostics$full_rhs_scale = full_rhs_scale
  diagnostics$reduced_rhs_scale = reduced_rhs_scale
  diagnostics$full_true_residual = full_absolute
  diagnostics$full_true_relative_residual = full_relative
  diagnostics$dense_full_system_operations = FALSE
  class_result = list(
    solution = solution,
    converged = isTRUE(reduced$converged) && is.finite(full_relative) && full_relative <= tolerance,
    iterations = reduced$iterations,
    system = system,
    reduced_solution = reduced$solution,
    diagnostics = diagnostics
  )
  class(class_result) = c("sparseSchurResult", "list")
  if (!isTRUE(return_diagnostics)) return(class_result[["solution"]])
  class_result
}
