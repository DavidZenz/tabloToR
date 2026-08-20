# Exact structured elimination for large GTAP-like TABLO systems.

sparse_elimination_cpp = local({
  compiled = NULL
  function() {
    if (!is.null(compiled)) return(compiled)
    if (!requireNamespace("Rcpp", quietly = TRUE)) {
      stop(
        "The structured sparse backend requires the optional Rcpp package",
        call. = FALSE
      )
    }
    path = system.file(
      "cpp/sparse-elimination.cpp", package = "tabloToR"
    )
    if (!nzchar(path)) path = file.path(
      "inst", "cpp", "sparse-elimination.cpp"
    )
    if (!file.exists(path)) {
      stop("The structured sparse elimination helper is unavailable",
           call. = FALSE)
    }
    environment = new.env(parent = parent.frame())
    Rcpp::sourceCpp(file = path, env = environment, showOutput = FALSE)
    compiled <<- list(
      eliminate = get("tabloToR_eliminate_blocks", environment),
      reconstruct = get("tabloToR_reconstruct_blocks", environment)
    )
    compiled
  }
})

sparse_elimination_sequence = function(domains, index, selected_sets, n,
                                       variable = FALSE) {
  n = as.integer(n)
  if (!length(domains)) return(integer(n))
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  seen = list()
  values = vector("list", length(selected_sets))
  for (id in seq_along(selected_sets)) {
    set_name = selected_sets[[id]]
    occurrence = if (is.null(seen[[set_name]])) 1L else seen[[set_name]] + 1L
    seen[[set_name]] = occurrence
    positions = which(vapply(domains, function(domain) {
      identical(domain$set, set_name)
    }, logical(1)))
    if (length(positions) < occurrence) return(integer(n))
    position = positions[[occurrence]]
    before = if (position == 1L) 1 else {
      prod(lengths[seq_len(position - 1L)])
    }
    after = if (position == length(lengths)) 1 else {
      prod(lengths[(position + 1L):length(lengths)])
    }
    values[[id]] = if (variable) {
      as.integer(rep(rep(seq_len(lengths[[position]]), each = before),
                     times = after))
    } else {
      as.integer(rep(rep(seq_len(lengths[[position]]), each = after),
                     times = before))
    }
  }
  code = numeric(n)
  multiplier = 1
  for (id in seq_along(selected_sets)) {
    code = code + values[[id]] * multiplier
    multiplier = multiplier * (
      length(index$sets[[selected_sets[[id]]]]$values) + 1
    )
  }
  as.integer(code)
}

sparse_elimination_family = function(index, state, selected_sets,
                                     variable_names, equation_names) {
  inverse = integer(index$endogenous_count)
  inverse[index$column_order] = seq_along(index$column_order)
  row_group = rep.int(-1L, index$equation_count)
  column_group = rep.int(-1L, index$endogenous_count)
  for (equation in index$equations) {
    if (!(equation$name %in% equation_names)) next
    if (any(vapply(equation$domains, function(domain) {
      !is.null(domain$predicate)
    }, logical(1)))) {
      stop(sprintf(
        "Structured elimination does not support conditional block %s",
        equation$name
      ), call. = FALSE)
    }
    rows = seq.int(equation$row_start, equation$row_end)
    values = sparse_elimination_sequence(
      equation$domains, index, selected_sets, equation$n
    )
    if (length(values) != equation$n || any(values == 0L)) {
      stop(sprintf("Cannot map equation family %s to elimination blocks",
                   equation$name), call. = FALSE)
    }
    row_group[rows] = values
  }
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous) ||
        !(variable$name %in% variable_names)) next
    positions = seq.int(variable$endo_start, length.out = variable$n)
    columns = inverse[positions]
    values = sparse_elimination_sequence(
      variable$domains, index, selected_sets, variable$n, variable = TRUE
    )
    if (length(values) != variable$n || any(values == 0L)) {
      stop(sprintf("Cannot map variable family %s to elimination blocks",
                   variable$name), call. = FALSE)
    }
    column_group[columns] = values
  }
  row_values = sort(unique(row_group[row_group >= 0L]))
  column_values = sort(unique(column_group[column_group >= 0L]))
  if (!identical(row_values, column_values)) {
    stop("Structured elimination row/column block IDs do not match",
         call. = FALSE)
  }
  remap = integer(max(row_values) + 1L)
  remap[row_values + 1L] = seq_along(row_values) - 1L
  row_group[row_group >= 0L] = remap[row_group[row_group >= 0L] + 1L]
  column_group[column_group >= 0L] =
    remap[column_group[column_group >= 0L] + 1L]
  list(
    row_group = as.integer(row_group),
    column_group = as.integer(column_group),
    n_groups = length(row_values)
  )
}

sparse_compact_elimination_partition = function(row_group, column_group,
                                                n_groups) {
  row_group = as.integer(row_group)
  column_group = as.integer(column_group)
  n_groups = as.integer(n_groups)
  if (length(row_group) != length(column_group) || n_groups < 1L) {
    stop("Invalid structured elimination partition", call. = FALSE)
  }
  if (any(row_group < -1L | row_group >= n_groups) ||
      any(column_group < -1L | column_group >= n_groups)) {
    stop("Structured elimination partition contains an invalid block",
         call. = FALSE)
  }
  row_counts = tabulate(row_group[row_group >= 0L] + 1L,
                        nbins = n_groups)
  column_counts = tabulate(column_group[column_group >= 0L] + 1L,
                           nbins = n_groups)
  if (any(row_counts != column_counts)) {
    stop("Structured elimination partition has non-square blocks",
         call. = FALSE)
  }
  keep = which(row_counts > 0L)
  if (!length(keep)) return(NULL)
  remap = rep.int(-1L, n_groups)
  remap[keep] = seq_along(keep) - 1L
  take = row_group >= 0L
  row_group[take] = remap[row_group[take] + 1L]
  take = column_group >= 0L
  column_group[take] = remap[column_group[take] + 1L]
  list(
    row_group = row_group,
    column_group = column_group,
    n_groups = as.integer(length(keep))
  )
}

sparse_gtap_elimination_partition = function(index, state) {
  production = sparse_elimination_family(
    index, state, c("comm", "acts", "reg"),
    c("qfd", "qfm", "pfd", "pfm", "ps", "qca", "pca", "pfa",
      "qfa", "afa"),
    c("e_qfa", "e_qfd", "e_qfm", "e_pfa", "e_afa", "e_qca",
      "e_ps", "e_pca", "e_pfd", "e_pfm")
  )
  bilateral = sparse_elimination_family(
    index, state, c("comm", "reg", "reg"),
    c("qxs", "pfob", "pcif", "pmds", "ptrans", "qtmfsd", "atmfsd"),
    c("e_qxs", "e_ptrans", "e_pfob", "e_pcif", "e_pmds",
      "e_qtmfsd", "e_atmfsd")
  )
  row_group = production$row_group
  column_group = production$column_group
  offset = production$n_groups
  take = bilateral$row_group >= 0L
  if (any(row_group[take] >= 0L)) {
    stop("Production and bilateral elimination families overlap",
         call. = FALSE)
  }
  row_group[take] = bilateral$row_group[take] + offset
  take = bilateral$column_group >= 0L
  if (any(column_group[take] >= 0L)) {
    stop("Production and bilateral elimination variables overlap",
         call. = FALSE)
  }
  column_group[take] = bilateral$column_group[take] + offset
  first = list(
    row_group = as.integer(row_group),
    column_group = as.integer(column_group),
    n_groups = as.integer(production$n_groups + bilateral$n_groups),
    production_groups = production$n_groups,
    bilateral_groups = bilateral$n_groups
  )
  endowment = tryCatch(
    sparse_elimination_family(
      index, state, c("acts", "reg"),
      c("pes", "qes", "peb", "qfe", "pfe", "afe"),
      c("e_qfe", "e_afe", "e_pfe", "e_pes", "e_peb",
        "e_qes1", "e_qes2", "e_qes3")
    ),
    error = function(error) NULL
  )
  list(
    row_group = first$row_group,
    column_group = first$column_group,
    n_groups = first$n_groups,
    production_groups = production$n_groups,
    bilateral_groups = bilateral$n_groups,
    stages = c(
      list(first = first),
      if (is.null(endowment)) list() else list(endowment = endowment)
    ),
    external = tryCatch(
      sparse_external_block_partition(index, state),
      error = function(error) NULL
    )
  )
}

sparse_btf_solve = function(A, rhs, lu_order = 3L) {
  if (!inherits(A, "sparseMatrix") || nrow(A) != ncol(A)) {
    stop("BTF solver requires a square sparse matrix", call. = FALSE)
  }
  rhs = as.numeric(rhs)
  if (length(rhs) != nrow(A) || any(!is.finite(rhs))) {
    stop("BTF solver received an invalid right-hand side", call. = FALSE)
  }
  decomposition = Matrix::dmperm(A, nAns = 4L, seed = 0L)
  row_sizes = diff(decomposition$r)
  column_sizes = diff(decomposition$s)
  if (!identical(row_sizes, column_sizes)) {
    stop("BTF decomposition has non-square diagonal blocks", call. = FALSE)
  }
  permuted = A[decomposition$p, decomposition$q, drop = FALSE]
  permuted_rhs = rhs[decomposition$p]
  solution = numeric(nrow(A))
  for (block in rev(seq_along(row_sizes))) {
    row_start = decomposition$r[[block]] + 1L
    row_end = decomposition$r[[block + 1L]]
    column_start = decomposition$s[[block]] + 1L
    column_end = decomposition$s[[block + 1L]]
    size = row_end - row_start + 1L
    if (size == 1L) {
      column = column_start
      row = row_start
      first = permuted@p[[column]] + 1L
      last = permuted@p[[column + 1L]]
      if (first > last) stop("BTF singleton has no coefficient", call. = FALSE)
      positions = first:last
      diagonal = sum(permuted@x[positions][
        permuted@i[positions] == row - 1L
      ])
      if (!is.finite(diagonal) || diagonal == 0) {
        stop(sprintf("BTF singleton block %s has a zero pivot", block),
             call. = FALSE)
      }
      value = permuted_rhs[[row]] / diagonal
      solution[[column]] = value
      earlier = positions[permuted@i[positions] < row - 1L]
      if (length(earlier)) {
        permuted_rhs[permuted@i[earlier] + 1L] =
          permuted_rhs[permuted@i[earlier] + 1L] -
          permuted@x[earlier] * value
      }
    } else {
      rows = row_start:row_end
      columns = column_start:column_end
      local = permuted[rows, columns, drop = FALSE]
      factor = tryCatch(
        Matrix::lu(Matrix::drop0(local), order = lu_order),
        error = function(error) error
      )
      if (inherits(factor, "error")) {
        stop(sprintf(
          "BTF factorization failed in block %s (size %s): %s",
          block, size, conditionMessage(factor)
        ), call. = FALSE)
      }
      local_solution = tryCatch(
        as.numeric(Matrix::solve(factor, permuted_rhs[rows])),
        error = function(error) error
      )
      if (inherits(local_solution, "error") ||
          any(!is.finite(local_solution))) {
        message = if (inherits(local_solution, "error")) {
          conditionMessage(local_solution)
        } else "non-finite block solution"
        stop(sprintf("BTF solve failed in block %s: %s", block, message),
             call. = FALSE)
      }
      solution[columns] = local_solution
      if (row_start > 1L) {
        update = permuted[seq_len(row_start - 1L), columns, drop = FALSE] %*%
          local_solution
        permuted_rhs[seq_len(row_start - 1L)] =
          permuted_rhs[seq_len(row_start - 1L)] - as.numeric(update)
      }
      rm(local, factor, local_solution)
    }
  }
  result = numeric(length(solution))
  result[decomposition$q] = solution
  if (any(!is.finite(result))) stop("BTF returned a non-finite solution",
                                   call. = FALSE)
  result
}

sparse_exact_structured_solve = function(A, rhs, partition,
                                         lu_order = 3L,
                                         pivot_tolerance = 1e-12,
                                         reduced_solver = c("btf", "schur")) {
  compiled = sparse_elimination_cpp()
  reduced_solver = match.arg(reduced_solver)
  rhs = as.numeric(rhs)
  if (length(rhs) != nrow(A) || nrow(A) != ncol(A)) {
    stop("Structured sparse solve received incompatible dimensions",
         call. = FALSE)
  }
  stages = if (!is.null(partition$stages) &&
               length(partition$stages)) {
    partition$stages
  } else list(partition)
  current_A = A
  current_rhs = rhs
  original_rows = seq_len(nrow(A))
  original_columns = seq_len(ncol(A))
  records = list()
  stage_diagnostics = vector("list", length(stages))
  product_upper = 0
  max_block = 0L
  for (stage_id in seq_along(stages)) {
    stage = stages[[stage_id]]
    if (is.null(stage) || is.null(stage$row_group)) next
    if (length(stage$row_group) != nrow(A) ||
        length(stage$column_group) != ncol(A)) {
      stop("Structured elimination stages must use original coordinates",
           call. = FALSE)
    }
    row_group = stage$row_group[original_rows]
    column_group = stage$column_group[original_columns]
    effective = tryCatch(
      sparse_compact_elimination_partition(
        row_group, column_group, stage$n_groups
      ),
      error = function(error) error
    )
    if (inherits(effective, "error")) {
      if (stage_id == 1L) stop(conditionMessage(effective), call. = FALSE)
      stage_diagnostics[[stage_id]] = list(
        applied = FALSE, reason = conditionMessage(effective)
      )
      next
    }
    if (is.null(effective)) {
      stage_diagnostics[[stage_id]] = list(applied = FALSE,
                                           reason = "empty")
      next
    }
    result = tryCatch(
      compiled$eliminate(
        current_A, current_rhs, effective$row_group,
        effective$column_group, effective$n_groups,
        as.numeric(pivot_tolerance)
      ),
      error = function(error) error
    )
    if (inherits(result, "error")) {
      if (stage_id == 1L) stop(conditionMessage(result), call. = FALSE)
      stage_diagnostics[[stage_id]] = list(
        applied = FALSE, reason = conditionMessage(result)
      )
      next
    }
    singular = if (isTRUE(result$ok)) integer() else {
      sort(unique(as.integer(result$singular_groups)))
    }
    if (length(singular)) {
      effective$row_group[effective$row_group %in% singular] = -1L
      effective$column_group[effective$column_group %in% singular] = -1L
      effective = sparse_compact_elimination_partition(
        effective$row_group, effective$column_group,
        effective$n_groups
      )
      if (is.null(effective)) {
        stage_diagnostics[[stage_id]] = list(
          applied = FALSE, reason = "all local blocks singular",
          singular_groups = length(singular)
        )
        next
      }
      result = tryCatch(
        compiled$eliminate(
          current_A, current_rhs, effective$row_group,
          effective$column_group, effective$n_groups,
          as.numeric(pivot_tolerance)
        ),
        error = function(error) error
      )
      if (inherits(result, "error") || !isTRUE(result$ok)) {
        message = if (inherits(result, "error")) {
          conditionMessage(result)
        } else sprintf("%s singular local block(s)", result$singular_count)
        if (stage_id == 1L) stop(message, call. = FALSE)
        stage_diagnostics[[stage_id]] = list(
          applied = FALSE, reason = message,
          singular_groups = length(singular)
        )
        next
      }
    }
    records[[length(records) + 1L]] = list(
      A = current_A, rhs = current_rhs,
      row_group = effective$row_group,
      column_group = effective$column_group,
      n_groups = effective$n_groups
    )
    stage_diagnostics[[stage_id]] = list(
      applied = TRUE, eliminated_groups = effective$n_groups,
      reduced_dimension = result$kept_dimension,
      reduced_nnz = length(result$A@x),
      singular_groups = length(singular)
    )
    product_upper = product_upper + result$product_upper
    max_block = max(max_block, result$max_block)
    current_A = result$A
    current_rhs = result$rhs
    original_rows = original_rows[effective$row_group < 0L]
    original_columns = original_columns[effective$column_group < 0L]
    rm(result)
  }
  reduced_diagnostics = list()
  if (identical(reduced_solver, "schur")) {
    external = partition$external
    if (is.null(external)) {
      stop("Structured Schur solver requires an external comm/reg partition",
           call. = FALSE)
    }
    external_rows = external$row_group[original_rows]
    external_columns = external$column_group[original_columns]
    if (any(external_rows < 0L) || any(external_columns < 0L)) {
      stop("Structured Schur solver found mixed groups after elimination",
           call. = FALSE)
    }
    reduced_result = sparse_exact_schur_solve(
      current_A, current_rhs, external_rows, external_columns,
      external$commodity_count, external$region_count,
      external$global_group,
      lu_order = lu_order,
      region_batch_size = getOption("tabloToR.sparse.schur_region_batch_size", 8L),
      panel_size = getOption("tabloToR.sparse.schur_panel_size", 64L),
      restart = getOption("tabloToR.sparse.schur_restart", 80L),
      max_iterations = getOption("tabloToR.sparse.schur_max_iterations", 500L),
      tolerance = getOption("tabloToR.sparse.schur_tolerance", 2e-7),
      true_residual_frequency = getOption(
        "tabloToR.sparse.schur_true_residual_frequency", 1L
      )
    )
    if (!isTRUE(reduced_result$converged)) {
      stop(sprintf(
        "Structured Schur FGMRES did not converge: true residual %.3e",
        reduced_result$diagnostics$true_relative_residual
      ), call. = FALSE)
    }
    reduced_solution = reduced_result$solution
    reduced_diagnostics = reduced_result$diagnostics
    rm(reduced_result)
    gc(verbose = FALSE)
  } else {
    reduced_solution = sparse_btf_solve(current_A, current_rhs, lu_order)
  }
  solution = reduced_solution
  if (length(records)) for (stage_id in rev(seq_along(records))) {
    record = records[[stage_id]]
    solution = compiled$reconstruct(
      record$A, record$rhs, solution,
      record$row_group, record$column_group,
      as.integer(record$n_groups), as.numeric(pivot_tolerance)
    )
  }
  list(
    solution = as.numeric(solution),
    reduced_dimension = nrow(current_A),
    reduced_nnz = length(current_A@x),
    eliminated_groups = if (length(records)) {
      sum(vapply(records, function(record) record$n_groups, integer(1)))
    } else 0L,
    product_upper = product_upper,
    max_block = max_block,
    stage_count = length(records),
    reduced_solver = reduced_solver,
    reduced_diagnostics = reduced_diagnostics,
    stage_diagnostics = stage_diagnostics
  )
}
