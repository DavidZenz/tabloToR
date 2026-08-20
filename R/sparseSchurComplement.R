# Matrix-free Schur complement solve for the structured sparse backend.

sparse_external_block_partition = function(index, state) {
  if (is.null(index$column_order) ||
      length(index$column_order) != index$endogenous_count ||
      anyNA(index$column_order)) {
    stop("External Schur partition requires a complete column order",
         call. = FALSE)
  }
  if (!all(c("comm", "reg") %in% names(index$sets))) {
    stop("External Schur partition requires comm and reg sets",
         call. = FALSE)
  }
  layout = sparse_structured_block_partition(
    index, state, sets = c("comm", "reg")
  )
  if (is.null(layout)) {
    stop("Could not construct a structured comm/reg partition",
         call. = FALSE)
  }
  commodity_count = length(index$sets$comm$values)
  region_count = length(index$sets$reg$values)
  stride = commodity_count + 1L
  code_group = vapply(layout$codes, function(code) {
    commodity = code %% stride
    region = code %/% stride
    if (commodity > 0L && region > 0L) {
      -1L
    } else if (commodity > 0L) {
      as.integer(commodity - 1L)
    } else if (region > 0L) {
      as.integer(commodity_count + region - 1L)
    } else {
      as.integer(commodity_count + region_count)
    }
  }, integer(1))
  row_group = code_group[layout$row_group + 1L]
  column_group = code_group[layout$column_group + 1L]
  list(
    row_group = as.integer(row_group),
    column_group = as.integer(column_group),
    n_groups = as.integer(commodity_count + region_count + 1L),
    commodity_count = as.integer(commodity_count),
    region_count = as.integer(region_count),
    global_group = as.integer(commodity_count + region_count),
    codes = layout$codes
  )
}

sparse_scale_dgCMatrix = function(A, row_scale, column_scale) {
  scaled = Matrix::drop0(A)
  entry_rows = scaled@i + 1L
  entry_columns = rep.int(seq_len(ncol(scaled)), diff(scaled@p))
  if (length(scaled@x)) {
    scaled@x = scaled@x * row_scale[entry_rows] *
      column_scale[entry_columns]
  }
  scaled
}

sparse_dense_factor = function(block, order = 3L, name = "block") {
  if (!length(block) || any(!is.finite(block))) {
    stop(sprintf("%s contains no finite coefficients", name), call. = FALSE)
  }
  if (nrow(block) <= 16L && ncol(block) <= 16L) {
    factor = tryCatch(
      qr(as.matrix(block), tol = 1e-12, LAPACK = TRUE),
      error = function(error) error
    )
    if (inherits(factor, "error")) {
      stop(sprintf("Dense QR factorization failed for %s: %s",
                   name, conditionMessage(factor)), call. = FALSE)
    }
    if (factor[["rank"]] < min(dim(block))) {
      stop(sprintf("Dense QR factorization found a rank-deficient %s", name),
           call. = FALSE)
    }
    return(structure(list(qr = factor),
                     class = "tabloToR_dense_qr_factor"))
  }
  factor = tryCatch(
    Matrix::lu(block, order = order),
    error = function(error) error
  )
  if (inherits(factor, "error")) {
    stop(sprintf("Dense factorization failed for %s: %s",
                 name, conditionMessage(factor)), call. = FALSE)
  }
  factor
}

sparse_exact_schur_solve_factor = function(factor, rhs, name = "block") {
  result = tryCatch(
    if (inherits(factor, "tabloToR_dense_qr_factor")) {
      qr.coef(factor[["qr"]], rhs)
    } else Matrix::solve(factor, rhs),
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
  result
}

sparse_exact_schur_group_positions = function(group, ids) {
  lapply(ids, function(id) which(group == id))
}

sparse_exact_schur_validate_partition = function(A, row_group, column_group,
                                                 local_count, region_count,
                                                 global_group) {
  n = nrow(A)
  if (!inherits(A, "sparseMatrix") || nrow(A) != ncol(A)) {
    stop("Exact Schur solver requires a square sparse matrix", call. = FALSE)
  }
  if (length(row_group) != n || length(column_group) != n) {
    stop("Exact Schur groups must match the coefficient matrix", call. = FALSE)
  }
  row_group = as.integer(row_group)
  column_group = as.integer(column_group)
  expected_groups = as.integer(local_count + region_count + 1L)
  if (local_count < 1L || region_count < 1L ||
      global_group != local_count + region_count ||
      any(row_group < 0L | row_group >= expected_groups) ||
      any(column_group < 0L | column_group >= expected_groups)) {
    stop("Exact Schur groups contain invalid local or external ids",
         call. = FALSE)
  }
  row_counts = tabulate(row_group + 1L, nbins = expected_groups)
  column_counts = tabulate(column_group + 1L, nbins = expected_groups)
  if (any(row_counts != column_counts) || any(row_counts == 0L)) {
    stop("Exact Schur partition must contain non-empty square groups",
         call. = FALSE)
  }
  validation_chunk_size = suppressWarnings(as.integer(getOption(
    "tabloToR.sparse.schur_validation_chunk_size", 4096L
  ))[1L])
  if (is.na(validation_chunk_size) || validation_chunk_size < 1L) {
    stop("tabloToR.sparse.schur_validation_chunk_size must be positive",
         call. = FALSE)
  }
  for (first_column in seq.int(1L, n, by = validation_chunk_size)) {
    last_column = min(n, first_column + validation_chunk_size - 1L)
    first_entry = A@p[[first_column]] + 1L
    last_entry = A@p[[last_column + 1L]]
    if (first_entry > last_entry) next
    entry_rows = A@i[seq.int(first_entry, last_entry)] + 1L
    entry_columns = rep.int(
      seq.int(first_column, last_column),
      diff(A@p[first_column:(last_column + 1L)])
    )
    row_ids = row_group[entry_rows]
    column_ids = column_group[entry_columns]
    coupled = row_ids < local_count & column_ids < local_count &
      row_ids != column_ids
    if (any(coupled)) {
      bad = which(coupled)[[1L]]
      stop(sprintf(
        paste(
          "Exact Schur local blocks %s and %s are coupled",
          "at matrix row %s, column %s"
        ),
        row_ids[[bad]], column_ids[[bad]],
        entry_rows[[bad]], entry_columns[[bad]]
      ), call. = FALSE)
    }
  }
  list(row_group = row_group, column_group = column_group,
       row_counts = row_counts)
}

sparse_exact_schur_build = function(
    A, row_group, column_group, local_count, region_count,
    global_group = local_count + region_count, rhs = NULL,
    row_scale = NULL, column_scale = NULL, lu_order = 3L,
    region_batch_size = 8L, panel_size = 64L) {
  sparse_schur_require_matrix()
  if (!methods::is(A, "dgCMatrix")) {
    A = methods::as(A, "dgCMatrix")
  }
  partition = sparse_exact_schur_validate_partition(
    A, row_group, column_group, local_count, region_count, global_group
  )
  n = nrow(A)
  if (is.null(rhs)) rhs = NULL else {
    rhs = as.numeric(rhs)
    if (length(rhs) != n || any(!is.finite(rhs))) {
      stop("Exact Schur rhs must be a finite vector of matrix length",
           call. = FALSE)
    }
  }
  lu_order = suppressWarnings(as.integer(lu_order)[1L])
  region_batch_size = suppressWarnings(as.integer(region_batch_size)[1L])
  panel_size = suppressWarnings(as.integer(panel_size)[1L])
  if (is.na(lu_order) || lu_order < 0L || lu_order > 3L ||
      is.na(region_batch_size) || region_batch_size < 1L ||
      is.na(panel_size) || panel_size < 1L) {
    stop("Invalid Schur factorization or batching controls", call. = FALSE)
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

  local_ids = seq.int(0L, local_count - 1L)
  region_ids = seq.int(local_count, local_count + region_count - 1L)
  external_ids = c(region_ids, global_group)
  local_rows = sparse_exact_schur_group_positions(
    partition$row_group, local_ids
  )
  local_columns = sparse_exact_schur_group_positions(
    partition$column_group, local_ids
  )
  external_rows_by_group = sparse_exact_schur_group_positions(
    partition$row_group, external_ids
  )
  external_columns_by_group = sparse_exact_schur_group_positions(
    partition$column_group, external_ids
  )
  external_rows = unlist(external_rows_by_group, use.names = FALSE)
  external_columns = unlist(external_columns_by_group, use.names = FALSE)
  if (length(external_rows) != n - sum(partition$row_counts[local_ids + 1L]) ||
      !identical(length(external_rows), length(external_columns))) {
    stop("Exact Schur partition has inconsistent external dimensions",
         call. = FALSE)
  }

  scaled = sparse_scale_dgCMatrix(A, row_scale, column_scale)
  local_factors = vector("list", local_count)
  for (id in seq_len(local_count)) {
    block = scaled[local_rows[[id]], local_columns[[id]], drop = FALSE]
    local_factors[[id]] = tryCatch(
      Matrix::lu(Matrix::drop0(block), order = lu_order),
      error = function(error) error
    )
    if (inherits(local_factors[[id]], "error")) {
      stop(sprintf("Commodity block %s factorization failed: %s", id,
                   conditionMessage(local_factors[[id]])), call. = FALSE)
    }
    rm(block)
  }

  external_group = rep.int(NA_integer_, length(external_rows))
  external_local = integer(length(external_rows))
  cursor = 0L
  for (id in seq_along(external_ids)) {
    positions = seq.int(cursor + 1L,
                        length.out = length(external_rows_by_group[[id]]))
    external_group[positions] = external_ids[[id]]
    external_local[positions] = seq_along(positions)
    cursor = cursor + length(positions)
  }
  D = Matrix::drop0(scaled[external_rows, external_columns, drop = FALSE])
  right = lapply(seq_len(local_count), function(id) {
    Matrix::drop0(scaled[local_rows[[id]], external_columns, drop = FALSE])
  })
  left = lapply(seq_len(local_count), function(id) {
    Matrix::drop0(scaled[external_rows, local_columns[[id]], drop = FALSE])
  })
  scaled = NULL
  gc(verbose = FALSE)

  regional_blocks = vector("list", region_count)
  regional_factors = vector("list", region_count)
  region_global = vector("list", region_count)
  global_region = vector("list", region_count)
  global_position = which(external_ids == global_group)
  global_position = seq.int(
    sum(vapply(external_rows_by_group[seq_len(region_count)], length, integer(1))) + 1L,
    length.out = length(external_rows_by_group[[region_count + 1L]])
  )
  global_size = length(global_position)
  global_global = as.matrix(D[global_position, global_position, drop = FALSE])

  batch_starts = seq.int(1L, region_count, by = region_batch_size)
  for (batch_start in batch_starts) {
    batch_end = min(region_count, batch_start + region_batch_size - 1L)
    batch_regions = seq.int(batch_start, batch_end)
    target_positions = unlist(c(
      lapply(batch_regions, function(id) {
        offset = sum(vapply(external_rows_by_group[seq_len(id - 1L)],
                            length, integer(1)))
        seq.int(offset + 1L, length.out = length(
          external_columns_by_group[[id]]
        ))
      }),
      list(global_position)
    ), use.names = FALSE)
    target_groups = c(
      rep(region_ids[batch_regions],
          vapply(external_columns_by_group[batch_regions], length, integer(1))),
      rep.int(global_group, global_size)
    )
    target_local = c(
      unlist(lapply(batch_regions, function(id) {
        seq_along(external_columns_by_group[[id]])
      }), use.names = FALSE),
      seq_len(global_size)
    )
    batch_blocks = lapply(batch_regions, function(id) {
      positions = sparse_exact_schur_group_positions(
        external_group, region_ids[id]
      )[[1L]]
      # external_group is in grouped coordinates; this lookup is cheap and
      # avoids retaining another full set of block labels.
      as.matrix(D[positions, positions, drop = FALSE])
    })
    batch_region_global = lapply(batch_regions, function(id) {
      positions = which(external_group == region_ids[id])
      as.matrix(D[positions, global_position, drop = FALSE])
    })
    batch_global_region = lapply(batch_regions, function(id) {
      positions = which(external_group == region_ids[id])
      as.matrix(D[global_position, positions, drop = FALSE])
    })
    for (local_id in seq_len(local_count)) {
      for (panel_start in seq.int(1L, length(target_positions),
                                  by = panel_size)) {
        panel_end = min(length(target_positions), panel_start + panel_size - 1L)
        panel_positions = target_positions[panel_start:panel_end]
        rhs_panel = as.matrix(right[[local_id]][, panel_positions, drop = FALSE])
        if (!length(rhs_panel) || !any(rhs_panel != 0)) next
        solution_panel = sparse_exact_schur_solve_factor(
          local_factors[[local_id]], rhs_panel,
          sprintf("commodity block %s", local_id)
        )
        panel_groups = target_groups[panel_start:panel_end]
        panel_local = target_local[panel_start:panel_end]
        global_hits = which(panel_groups == global_group)
        for (batch_position in seq_along(batch_regions)) {
          region_id = batch_regions[[batch_position]]
          rows = which(external_group == region_ids[region_id])
          hits = which(panel_groups == region_ids[region_id])
          if (length(hits)) {
            target_columns = panel_local[hits]
            correction = as.matrix(left[[local_id]][rows, , drop = FALSE] %*%
                                   solution_panel[, hits, drop = FALSE])
            batch_blocks[[batch_position]][, target_columns] =
              batch_blocks[[batch_position]][, target_columns] - correction
            correction = as.matrix(left[[local_id]][global_position, , drop = FALSE] %*%
                                   solution_panel[, hits, drop = FALSE])
            batch_global_region[[batch_position]][, target_columns] =
              batch_global_region[[batch_position]][, target_columns] - correction
          }
          if (length(global_hits)) {
            correction = as.matrix(left[[local_id]][rows, , drop = FALSE] %*%
                                   solution_panel[, global_hits, drop = FALSE])
            batch_region_global[[batch_position]] =
              batch_region_global[[batch_position]] - correction
          }
        }
        global_hits = which(panel_groups == global_group)
        if (length(global_hits) && batch_start == 1L) {
          correction = as.matrix(
            left[[local_id]][global_position, , drop = FALSE] %*%
              solution_panel[, global_hits, drop = FALSE]
          )
          global_global = global_global - correction
        }
      }
    }
    for (batch_position in seq_along(batch_regions)) {
      regional_blocks[[batch_regions[[batch_position]]]] =
        batch_blocks[[batch_position]]
      region_global[[batch_regions[[batch_position]]]] =
        batch_region_global[[batch_position]]
      global_region[[batch_regions[[batch_position]]]] =
        batch_global_region[[batch_position]]
    }
    rm(batch_blocks, batch_region_global, batch_global_region,
       target_positions, target_groups, target_local)
    gc(verbose = FALSE)
    if (isTRUE(getOption("tabloToR.sparse.schur_progress", FALSE))) {
      cat("Schur regional batch ", batch_start, "-", batch_end,
          "/", region_count, "\n", sep = "")
    }
  }

  for (region_id in seq_len(region_count)) {
    block = regional_blocks[[region_id]]
    regional_factors[[region_id]] = sparse_dense_factor(
      block, order = lu_order, name = sprintf("regional Schur block %s", region_id)
    )
  }
  global_correction = global_global
  for (region_id in seq_len(region_count)) {
    regional_to_global = sparse_exact_schur_solve_factor(
      regional_factors[[region_id]], region_global[[region_id]],
      sprintf("regional Schur block %s", region_id)
    )
    global_correction = global_correction -
      global_region[[region_id]] %*% regional_to_global
  }
  global_factor = sparse_dense_factor(
    global_correction, order = lu_order, name = "global Schur arrowhead block"
  )

  rhs_scaled = if (is.null(rhs)) NULL else rhs * row_scale
  reduced_rhs = NULL
  if (!is.null(rhs_scaled)) {
    reduced_rhs = rhs_scaled[external_rows]
    for (local_id in seq_len(local_count)) {
      local_solution = sparse_exact_schur_solve_factor(
        local_factors[[local_id]], rhs_scaled[local_rows[[local_id]]],
        sprintf("commodity block %s", local_id)
      )
      reduced_rhs = reduced_rhs - as.numeric(
        left[[local_id]] %*% local_solution
      )
    }
  }
  structure(
    list(
      dimension = n,
      row_group = partition$row_group,
      column_group = partition$column_group,
      local_count = as.integer(local_count),
      region_count = as.integer(region_count),
      global_group = as.integer(global_group),
      row_scale = row_scale,
      column_scale = column_scale,
      local_rows = local_rows,
      local_columns = local_columns,
      local_factors = local_factors,
      external_rows = as.integer(external_rows),
      external_columns = as.integer(external_columns),
      external_group = as.integer(external_group),
      external_local = as.integer(external_local),
      external_group_positions = lapply(external_ids, function(id) {
        which(external_group == id)
      }),
      D = D,
      left = left,
      right = right,
      regional_factors = regional_factors,
      region_global = region_global,
      global_region = global_region,
      global_factor = global_factor,
      global_position = global_position,
      reduced_rhs = reduced_rhs,
      diagnostics = list(
        dimension = n,
        external_dimension = length(external_rows),
        local_block_count = local_count,
        regional_block_count = region_count,
        global_block_size = global_size,
        structural_nnz = length(A@x),
        panel_size = panel_size,
        region_batch_size = region_batch_size,
        dense_full_system_operations = FALSE
      )
    ),
    class = "sparseExactSchurSystem"
  )
}

sparse_exact_schur_apply = function(system, value) {
  if (!inherits(system, "sparseExactSchurSystem")) {
    stop("Invalid exact Schur system", call. = FALSE)
  }
  value = as.numeric(value)
  if (length(value) != length(system$external_columns) ||
      any(!is.finite(value))) {
    stop("Exact Schur input has an invalid length or value", call. = FALSE)
  }
  result = as.numeric(system$D %*% value)
  for (local_id in seq_len(system$local_count)) {
    local_rhs = as.numeric(system$right[[local_id]] %*% value)
    local_solution = sparse_exact_schur_solve_factor(
      system$local_factors[[local_id]], local_rhs,
      sprintf("commodity block %s", local_id)
    )
    result = result - as.numeric(system$left[[local_id]] %*% local_solution)
  }
  if (any(!is.finite(result))) {
    stop("Exact Schur operator produced non-finite values", call. = FALSE)
  }
  result
}

sparse_exact_schur_apply_preconditioner = function(system, value) {
  value = as.numeric(value)
  if (length(value) != length(system$external_columns) ||
      any(!is.finite(value))) {
    stop("Exact Schur preconditioner input is invalid", call. = FALSE)
  }
  regional_positions = system$external_group_positions[seq_len(
    system$region_count
  )]
  global_value = value[system$global_position]
  local_values = vector("list", system$region_count)
  global_rhs = global_value
  for (region_id in seq_len(system$region_count)) {
    positions = regional_positions[[region_id]]
    local_value = sparse_exact_schur_solve_factor(
      system$regional_factors[[region_id]], value[positions],
      sprintf("regional Schur block %s", region_id)
    )
    local_values[[region_id]] = local_value
    global_rhs = global_rhs - system$global_region[[region_id]] %*% local_value
  }
  global_value = as.numeric(sparse_exact_schur_solve_factor(
    system$global_factor, global_rhs, "global Schur arrowhead block"
  ))
  result = numeric(length(value))
  for (region_id in seq_len(system$region_count)) {
    positions = regional_positions[[region_id]]
    correction = system$region_global[[region_id]] %*% global_value
    result[positions] = as.numeric(sparse_exact_schur_solve_factor(
      system$regional_factors[[region_id]],
      value[positions] - correction,
      sprintf("regional Schur block %s", region_id)
    ))
  }
  result[system$global_position] = global_value
  if (any(!is.finite(result))) {
    stop("Exact Schur preconditioner produced non-finite values",
         call. = FALSE)
  }
  result
}

sparse_exact_schur_reconstruct = function(system, reduced_solution, rhs) {
  reduced_solution = as.numeric(reduced_solution)
  rhs = as.numeric(rhs)
  if (length(reduced_solution) != length(system$external_columns) ||
      length(rhs) != system$dimension) {
    stop("Exact Schur reconstruction received incompatible vectors",
         call. = FALSE)
  }
  rhs_scaled = rhs * system$row_scale
  result_scaled = numeric(system$dimension)
  result_scaled[system$external_columns] = reduced_solution
  for (local_id in seq_len(system$local_count)) {
    local_rhs = rhs_scaled[system$local_rows[[local_id]]] - as.numeric(
      system$right[[local_id]] %*% reduced_solution
    )
    result_scaled[system$local_columns[[local_id]]] = as.numeric(
      sparse_exact_schur_solve_factor(
        system$local_factors[[local_id]], local_rhs,
        sprintf("commodity block %s", local_id)
      )
    )
  }
  result_scaled * system$column_scale
}

sparse_exact_schur_reduce_rhs = function(system, rhs) {
  rhs = as.numeric(rhs)
  if (length(rhs) != system[["dimension"]] || any(!is.finite(rhs))) {
    stop("Exact Schur rhs has an invalid length or value", call. = FALSE)
  }
  rhs_scaled = rhs * system[["row_scale"]]
  reduced_rhs = rhs_scaled[system[["external_rows"]]]
  for (local_id in seq_len(system[["local_count"]])) {
    local_solution = sparse_exact_schur_solve_factor(
      system[["local_factors"]][[local_id]],
      rhs_scaled[system[["local_rows"]][[local_id]]],
      sprintf("commodity block %s", local_id)
    )
    reduced_rhs = reduced_rhs - as.numeric(
      system[["left"]][[local_id]] %*% local_solution
    )
  }
  reduced_rhs
}

sparse_exact_schur_solve = function(
    A, rhs, row_group, column_group, local_count, region_count,
    global_group = local_count + region_count, lu_order = 3L,
    region_batch_size = 8L, panel_size = 64L, restart = 80L,
    max_iterations = 500L, tolerance = 2e-7,
    true_residual_frequency = 1L) {
  system = sparse_exact_schur_build(
    A, row_group, column_group, local_count, region_count, global_group,
    rhs = rhs, lu_order = lu_order, region_batch_size = region_batch_size,
    panel_size = panel_size
  )
  reduced = sparse_schur_fgmres(
    system, system$reduced_rhs, restart = restart,
    max_iterations = max_iterations, tolerance = tolerance,
    preconditioner = function(value, iteration) {
      sparse_exact_schur_apply_preconditioner(system, value)
    }, true_residual_frequency = true_residual_frequency
  )
  solution = sparse_exact_schur_reconstruct(system, reduced$solution, rhs)
  residual = as.numeric(A %*% solution) - rhs
  residual_absolute = sparse_schur_norm(residual)
  residual_relative = residual_absolute / max(1, sparse_schur_norm(rhs))
  refinement_iterations = 0L
  refinement_history = numeric()
  refinement_limit = suppressWarnings(as.integer(
    getOption("tabloToR.sparse.schur_refinement_iterations", 3L)
  )[1L])
  if (is.na(refinement_limit) || refinement_limit < 0L) {
    stop("tabloToR.sparse.schur_refinement_iterations must be non-negative",
         call. = FALSE)
  }
  refinement_tolerance = max(
    .Machine$double.eps * 10,
    min(tolerance * 0.01, 1e-11)
  )
  if (residual_relative > tolerance && refinement_limit > 0L) {
    for (refinement_id in seq_len(refinement_limit)) {
      correction_rhs = rhs - as.numeric(A %*% solution)
      correction = sparse_schur_fgmres(
        system, sparse_exact_schur_reduce_rhs(system, correction_rhs),
        restart = restart, max_iterations = max_iterations,
        tolerance = refinement_tolerance,
        preconditioner = function(value, iteration) {
          sparse_exact_schur_apply_preconditioner(system, value)
        }, true_residual_frequency = true_residual_frequency
      )
      correction_solution = sparse_exact_schur_reconstruct(
        system, correction[["solution"]], correction_rhs
      )
      if (any(!is.finite(correction_solution))) {
        stop("Exact Schur refinement produced non-finite values",
             call. = FALSE)
      }
      solution = solution + correction_solution
      residual = as.numeric(A %*% solution) - rhs
      residual_absolute = sparse_schur_norm(residual)
      residual_relative = residual_absolute / max(1, sparse_schur_norm(rhs))
      refinement_iterations = refinement_id
      refinement_history = c(refinement_history, residual_relative)
      if (residual_relative <= tolerance) break
    }
  }
  diagnostics = system[["diagnostics"]]
  diagnostics$reduced_converged = reduced$converged
  diagnostics$reduced_iterations = reduced$iterations
  diagnostics$reduced_residual_history = reduced$residual_history
  diagnostics$true_residual = residual_absolute
  diagnostics$true_relative_residual = residual_relative
  diagnostics[["refinement_iterations"]] = refinement_iterations
  diagnostics[["refinement_relative_history"]] = refinement_history
  list(
    solution = solution,
    converged = is.finite(residual_relative) &&
      residual_relative <= tolerance,
    system = system,
    diagnostics = diagnostics
  )
}
