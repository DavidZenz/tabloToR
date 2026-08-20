# Numeric sparse execution helpers for GEModel.

sparse_state_data = function(state) {
  if (is.environment(state)) state$data else state
}

sparse_make_state = function(data) {
  state = new.env(parent = emptyenv())
  state$data = data
  state
}
sparse_process_tablo = function(tabloPath) {
  statements = tabloToStatements(tabloPath)
  sparse_spec = sparse_compile_spec(statements)
  # The sparse update evaluator initializes formula targets after indexing.
  # Keeping formulas out of the legacy skeleton avoids materializing large
  # derived arrays through the old vectorized generator.
  skeleton_statements = Filter(function(statement) {
    statement$class %in% c("set", "coefficient", "read") &&
      !grepl("^mapping\\s", statement$parsed$equation,
             ignore.case = TRUE)
  }, statements)
  base_generator = generateSkeleton(skeleton_statements)
  mapping_statements = Filter(function(statement) {
    statement$class == "formula" &&
      grepl("\\$pos", statement$parsed$equation, ignore.case = TRUE)
  }, statements)
  generator = function(input_data) {
    result = base_generator(input_data)
    for (statement in mapping_statements) {
      parsed = tryCatch(correctFormula(statement$parsed$equation),
                        error = function(e) NULL)
      if (is.null(parsed) || length(parsed) < 3L) next
      target = tryCatch(sparse_parse_ref(parsed[[2]]),
                        error = function(e) NULL)
      if (is.null(target) || !is.null(result[[target$name]])) next
      domains = lapply(
        statement$parsed$elements[
          grepl("^\\s*\\(all,", statement$parsed$elements,
               ignore.case = TRUE)
        ], sparse_parse_qualifier
      )
      domains = sparse_order_domains(domains, target$indices)
      dimensions = vapply(domains, function(domain) {
        length(sparse_find_set_values(result, domain$set))
      }, integer(1))
      if (length(dimensions)) {
        dim_names = lapply(domains, function(domain) {
          sparse_find_set_values(result, domain$set)
        })
        result[[target$name]] = array(
          NA_real_, dim = dimensions, dimnames = dim_names
        )
      } else {
        result[[target$name]] = NA_real_
      }
    }
    result
  }
  gem = generateEquationCoefficientMatrix(
    Filter(function(statement) statement$class == "variable", statements),
    Filter(function(statement) statement$class == "equation", statements)
  )
  gec = generateEquationCoefficients(
    Filter(function(statement) statement$class == "equation", statements)
  )
  gev = generateVariables(
    Filter(function(statement) statement$class == "variable", statements)
  )
  geq = generateEquationLevels(
    Filter(function(statement) statement$class == "equation", statements)
  )
  change = vapply(sparse_spec$variables, function(variable) {
    isTRUE(variable$change)
  }, logical(1))
  list(
    skeletonGenerator = generator,
    equationCoefficientMatrixGenerator = gem,
    equationCoefficientGenerator = gec,
    generateVariables = gev,
    generateUpdates = function(data) data,
    generateEquationLevelValues = geq,
    variables = sparse_spec$variable_names,
    changeVariables = sparse_spec$variable_names[change],
    statements = statements,
    sparseSpec = sparse_spec
  )
}

legacy_shocks_from_explicit = function(model) {
  explicit = model$explicitShocks
  if (is.null(explicit) || !length(explicit$labels)) return(numeric())
  inferred = sub("\\[.*$", "", explicit$labels)
  closure = unique(tolower(c(model$closure, inferred)))
  pieces = list()
  for (variable in closure) {
    values = model$variableValues[[variable]]
    if (is.null(values)) values = model$data[[variable]]
    if (is.null(values)) next
    piece = toVector(values, variable)
    piece[] = 0
    pieces[[length(pieces) + 1L]] = piece
  }
  shocks = if (length(pieces)) do.call(c, pieces) else numeric()
  if (!length(shocks)) {
    shocks = setNames(numeric(), character())
  }
  key = function(labels) gsub("[\\\"'[:space:]]", "", labels)
  positions = match(key(explicit$labels), key(names(shocks)))
  for (i in seq_along(explicit$labels)) {
    if (is.na(positions[[i]])) {
      shocks[[explicit$labels[[i]]]] = explicit$values[[i]]
    } else {
      shocks[[positions[[i]]]] = explicit$values[[i]]
    }
  }
  shocks[!is.na(shocks)]
}

sparse_normalize_shocks = function(shocks) {
  if (is.null(shocks)) {
    return(list(labels = character(), values = numeric()))
  }
  if (is.list(shocks) &&
      !is.null(shocks$labels) && !is.null(shocks$values)) {
    labels = as.character(shocks$labels)
    values = as.numeric(shocks$values)
  } else {
    values = as.numeric(shocks)
    labels = names(shocks)
    if (is.null(labels)) {
      stop("Sparse shocks must be a named numeric vector", call. = FALSE)
    }
  }
  keep = !is.na(values) & values != 0 & !is.na(labels) & nzchar(labels)
  labels = labels[keep]
  values = values[keep]
  if (!length(labels)) {
    return(list(labels = character(), values = numeric()))
  }
  unique_labels = unique(labels)
  values = vapply(unique_labels, function(label) {
    sum(values[labels == label])
  }, numeric(1))
  keep = !is.na(values) & values != 0
  list(labels = unique_labels[keep], values = values[keep])
}

sparse_set_closure_state = function(model, exogenous_variables) {
  if (is.null(exogenous_variables)) exogenous_variables = character()
  if (is.list(exogenous_variables) && !is.null(names(exogenous_variables))) {
    exogenous_variables = names(exogenous_variables)
  }
  exogenous_variables = as.character(exogenous_variables)
  exogenous_variables = sub("\\[.*$", "", exogenous_variables)
  exogenous_variables = sub("\\(.*$", "", exogenous_variables)
  exogenous_variables = tolower(unique(exogenous_variables[nzchar(exogenous_variables)]))
  model$closure = exogenous_variables
  if (!is.null(model$sparseIndex) && length(model$sparseIndex)) {
    model$sparseIndex = sparse_rebuild_columns(
      model$sparseIndex, exogenous_variables
    )
  }
  invisible(model)
}

sparse_set_shocks_state = function(model, shocks) {
  normalized = sparse_normalize_shocks(shocks)
  model$explicitShocks = normalized
  model$shocks = setNames(normalized$values, normalized$labels)
  invisible(model)
}

sparse_set_memory_budget_state = function(model, bytes) {
  if (is.null(bytes) || !length(bytes) || is.na(bytes)) {
    model$memoryBudget = numeric()
  } else {
    bytes = as.numeric(bytes)[1L]
    if (!is.finite(bytes) || bytes <= 0) {
      stop("Memory budget must be a positive number of bytes", call. = FALSE)
    }
    model$memoryBudget = bytes
  }
  invisible(model)
}

sparse_ref_value = function(expr, state, bindings, index) {
  if (is.name(expr) && !is.null(bindings[[as.character(expr)]])) {
    return(bindings[[as.character(expr)]])
  }
  if (is.character(expr) && length(expr) == 1L &&
      !is.null(bindings[[expr]])) {
    return(bindings[[expr]])
  }
  if (!is.language(expr) && length(expr) == 1L) return(expr)
  sparse_eval_expr(expr, state, bindings, index)
}

sparse_data_linear_index = function(ref, state, bindings, index) {
  data = sparse_state_data(state)
  array = data[[ref$name]]
  if (is.null(array)) {
    stop(sprintf("Data array %s is missing", ref$name), call. = FALSE)
  }
  dims = dim(array)
  if (is.null(dims) || !length(ref$indices)) return(1L)
  if (length(ref$indices) != length(dims)) {
    stop(sprintf("Data array %s expects %s indices, got %s",
                 ref$name, length(dims), length(ref$indices)),
         call. = FALSE)
  }
  positions = integer(length(dims))
  dim_names = dimnames(array)
  for (d in seq_along(dims)) {
    value = sparse_ref_value(ref$indices[[d]], state, bindings, index)
    source_set = if (is.name(ref$indices[[d]])) {
      bindings[[paste0(".set:", as.character(ref$indices[[d]]))]]
    } else NULL
    target_set = if (!is.null(dim_names) &&
                     !is.null(names(dim_names)) &&
                     d <= length(dim_names)) {
      names(dim_names)[[d]]
    } else NULL
    if (is.null(target_set)) {
      data_id = index$variable_by_name[[ref$name]]
      if (!is.null(data_id) && d <= length(index$variables[[data_id]]$sets)) {
        target_set = index$variables[[data_id]]$sets[[d]]
      }
    }
    if (!is.null(source_set) && !is.null(target_set) &&
        !identical(source_set, target_set) &&
        !is.null(index$sets[[source_set]]) &&
        is.numeric(value) && length(value) == 1L && !is.na(value) &&
        value >= 1L && value <= length(index$sets[[source_set]]$values)) {
      value = index$sets[[source_set]]$values[[as.integer(value)]]
    }
    if (is.numeric(value) && length(value) == 1L &&
        !is.na(value) && value == as.integer(value) &&
        value >= 1L && value <= dims[[d]]) {
      positions[[d]] = as.integer(value)
    } else if (!is.null(dim_names) && !is.null(dim_names[[d]])) {
      positions[[d]] = match(as.character(value), dim_names[[d]])
    } else {
      positions[[d]] = sparse_position_for_label(
        as.character(value),
        if (d <= length(index$sets)) names(index$sets)[[d]] else "",
        index
      )
    }
    if (is.na(positions[[d]]) || positions[[d]] < 1L ||
        positions[[d]] > dims[[d]]) {
      stop(sprintf("Cannot resolve data index %s[%s]", ref$name, d),
           call. = FALSE)
    }
  }
  linear = 1L
  stride = 1L
  for (d in seq_along(positions)) {
    linear = linear + (positions[[d]] - 1L) * stride
    stride = stride * dims[[d]]
  }
  as.integer(linear)
}

sparse_global_for_ref = function(ref, state, bindings, index) {
  id = index$variable_by_name[[ref$name]]
  if (is.null(id)) {
    stop(sprintf("Unknown variable in sparse expression: %s", ref$name),
         call. = FALSE)
  }
  variable = index$variables[[id]]
  if (!length(variable$sets)) {
    return(as.integer(variable$global_start))
  }
  if (length(ref$indices) != length(variable$sets)) {
    stop(sprintf("Variable %s expects %s indices, got %s",
                 ref$name, length(variable$sets), length(ref$indices)),
         call. = FALSE)
  }
  positions = integer(length(variable$sets))
  for (d in seq_along(variable$sets)) {
    value = sparse_ref_value(ref$indices[[d]], state, bindings, index)
    set_name = variable$sets[[d]]
    set = index$sets[[set_name]]
    source_set = if (is.name(ref$indices[[d]])) {
      bindings[[paste0(".set:", as.character(ref$indices[[d]]))]]
    } else NULL
    if (!is.null(source_set) && !identical(source_set, set_name) &&
        !is.null(index$sets[[source_set]]) &&
        is.numeric(value) && length(value) == 1L && !is.na(value) &&
        value >= 1L && value <= length(index$sets[[source_set]]$values)) {
      value = index$sets[[source_set]]$values[[as.integer(value)]]
    }
    if (is.numeric(value) && length(value) == 1L &&
        !is.na(value) && value == as.integer(value) &&
        value >= 1L && value <= length(set$values)) {
      positions[[d]] = as.integer(value)
    } else {
      positions[[d]] = sparse_position_for_label(
        as.character(value), set_name, index
      )
    }
    if (is.na(positions[[d]])) {
      stop(sprintf("Cannot resolve index %s of %s",
                   paste(deparse(ref$indices[[d]]), collapse = " "),
                   ref$name), call. = FALSE)
    }
  }
  local = 1L
  stride = 1L
  for (d in seq_along(positions)) {
    local = local + (positions[[d]] - 1L) * stride
    stride = stride * variable$lengths[[d]]
  }
  as.integer(variable$global_start + local - 1L)
}

sparse_set_data_ref = function(ref, state, bindings, index, value) {
  data = sparse_state_data(state)
  linear = sparse_data_linear_index(ref, state, bindings, index)
  array = data[[ref$name]]
  array[[linear]] = as.numeric(value)[1L]
  data[[ref$name]] = array
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_initialize_update_target = function(update, state, index) {
  data = sparse_state_data(state)
  name = update$target$name
  if (!is.null(data[[name]])) return(invisible(NULL))
  domains = update$domains
  if (length(domains)) {
    dimensions = vapply(domains, function(domain) {
      length(index$sets[[domain$set]]$values)
    }, integer(1))
    dim_names = lapply(domains, function(domain) {
      index$sets[[domain$set]]$values
    })
    data[[name]] = array(
      NA_real_, dim = dimensions, dimnames = dim_names
    )
  } else {
    data[[name]] = NA_real_
  }
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_initialize_update_targets = function(state, index, spec,
                                            updates = NULL) {
  if (is.null(spec)) return(invisible(NULL))
  if (is.null(updates)) {
    updates = if (!is.null(spec$simulation_updates)) {
      spec$simulation_updates
    } else spec$updates
  }
  if (!length(updates)) return(invisible(NULL))
  for (update in updates) {
    sparse_initialize_update_target(update, state, index)
  }
  invisible(NULL)
}
sparse_variable_label = function(variable, local, index) {
  if (!length(variable$sets)) return(sprintf("%s[]", variable$name))
  positions = arrayInd(local, .dim = variable$lengths)
  values = vapply(seq_along(variable$sets), function(d) {
    index$sets[[variable$sets[[d]]]]$values[[positions[[d]]]]
  }, character(1))
  sprintf("%s[%s]", variable$name,
          paste(sprintf("\"%s\"", values), collapse = ","))
}

sparse_endogenous_labels = function(index) {
  labels = character(index$endogenous_count)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous)) next
    for (local in seq_len(variable$n)) {
      labels[[variable$endo_start + local - 1L]] =
        sparse_variable_label(variable, local, index)
    }
  }
  labels
}

sparse_shocks_from_variable_values = function(model, state, index) {
  values_list = model$variableValues
  if (is.null(values_list) || !length(values_list)) {
    values_list = sparse_state_data(state)
  }
  labels = character()
  values = numeric()
  for (variable in index$variables) {
    if (!isTRUE(variable$exogenous)) next
    array = values_list[[variable$name]]
    if (is.null(array)) array = sparse_state_data(state)[[variable$name]]
    if (is.null(array)) next
    flat = as.numeric(array)
    positions = which(!is.na(flat) & flat != 0)
    if (!length(positions)) next
    labels = c(labels, vapply(positions, function(local) {
      sparse_variable_label(variable, local, index)
    }, character(1)))
    values = c(values, flat[positions])
  }
  sparse_normalize_shocks(setNames(values, labels))
}

sparse_resolve_shocks = function(model, state, index) {
  explicit = model$explicitShocks
  if (is.null(explicit) || !length(explicit$labels)) {
    explicit = sparse_shocks_from_variable_values(model, state, index)
  }
  if (!length(explicit$labels)) {
    return(list(positions = integer(), values = numeric(),
                labels = character()))
  }
  positions = integer(length(explicit$labels))
  for (i in seq_along(explicit$labels)) {
    ref = sparse_parse_label(explicit$labels[[i]])
    id = index$variable_by_name[[ref$name]]
    if (is.null(id)) {
      stop(sprintf("Shock references unknown variable %s", ref$name),
           call. = FALSE)
    }
    variable = index$variables[[id]]
    if (!isTRUE(variable$exogenous)) {
      stop(sprintf("Shock variable %s is not in the configured closure",
                   ref$name), call. = FALSE)
    }
    positions[[i]] = sparse_global_for_ref(ref, state, list(), index)
  }
  unique_positions = unique(positions)
  values = vapply(unique_positions, function(position) {
    sum(explicit$values[positions == position])
  }, numeric(1))
  keep = !is.na(values) & values != 0
  list(
    positions = as.integer(unique_positions[keep]),
    values = values[keep],
    labels = explicit$labels[match(unique_positions, positions)][keep]
  )
}

sparse_shock_map = function(shocks) {
  map = new.env(hash = TRUE, parent = emptyenv())
  if (length(shocks$positions)) {
    for (i in seq_along(shocks$positions)) {
      map[[as.character(shocks$positions[[i]])]] = shocks$values[[i]]
    }
  }
  map
}

sparse_shock_lookup = function(map, position) {
  value = map[[as.character(position)]]
  if (is.null(value)) 0 else as.numeric(value)
}

sparse_triplet_capacity = function(index) {
  if (!length(index$equations)) return(0L)
  total = 0
  for (equation in index$equations) {
    if (!length(equation$terms) || equation$n == 0L) next
    for (term in equation$terms) {
      multiplier = if (length(term$sums)) {
        prod(vapply(term$sums, function(sum_spec) {
          length(index$sets[[sum_spec$set]]$values)
        }, numeric(1)))
      } else 1
      total = total + equation$n * multiplier
    }
  }
  as.numeric(total)
}

sparse_aggregate_triplets = function(i, j, x) {
  if (!length(i)) return(list(i = integer(), j = integer(), x = numeric()))
  order_value = order(i, j)
  sorted_i = i[order_value]
  sorted_j = j[order_value]
  sorted_x = x[order_value]
  if (anyNA(sorted_i) || anyNA(sorted_j) || anyNA(sorted_x)) {
    stop("Sparse triplet emission produced missing indices or values", call. = FALSE)
  }
  if (any(!is.finite(sorted_x))) {
    stop("Sparse triplet emission produced non-finite coefficients", call. = FALSE)
  }
  starts = c(TRUE, sorted_i[-1L] != sorted_i[-length(sorted_i)] |
                   sorted_j[-1L] != sorted_j[-length(sorted_j)])
  starts = which(starts)
  ends = c(starts[-1L] - 1L, length(sorted_i))
  groups = cumsum(c(TRUE, sorted_i[-1L] != sorted_i[-length(sorted_i)] |
                            sorted_j[-1L] != sorted_j[-length(sorted_j)]))
  aggregated = as.numeric(rowsum(sorted_x, groups, reorder = FALSE))
  if (any(!is.finite(aggregated))) {
    stop("Sparse triplet aggregation produced non-finite coefficients", call. = FALSE)
  }
  keep = aggregated != 0
  list(
    i = as.integer(sorted_i[starts][keep]),
    j = as.integer(sorted_j[starts][keep]),
    x = aggregated[keep]
  )
}

sparse_emit_system_scalar = function(state, index, shocks) {
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(NULL, index, state)
  }
  capacity = sparse_triplet_capacity(index)
  raw_i = if (capacity) integer(capacity) else integer()
  raw_j = if (capacity) integer(capacity) else integer()
  raw_x = if (capacity) numeric(capacity) else numeric()
  raw_count = 0L
  inverse_order = if (length(index$column_order)) {
    inverse = integer(index$endogenous_count)
    inverse[index$column_order] = seq_along(index$column_order)
    inverse
  } else integer()
  rhs = numeric(index$equation_count)
  shock_map = sparse_shock_map(shocks)
  row = 0L

  append_term = function(row_number, variable_position, value) {
    raw_count <<- raw_count + 1L
    if (raw_count > length(raw_x)) {
      raw_i <<- c(raw_i, integer(max(1024L, length(raw_i))))
      raw_j <<- c(raw_j, integer(max(1024L, length(raw_j))))
      raw_x <<- c(raw_x, numeric(max(1024L, length(raw_x))))
    }
    raw_i[[raw_count]] <<- row_number
    raw_j[[raw_count]] <<- if (length(inverse_order)) {
      inverse_order[[variable_position]]
    } else variable_position
    raw_x[[raw_count]] <<- value
  }

  for (equation in index$equations) {
    sparse_for_each_domain(
      equation$domains, state, index, callback = function(bindings) {
        row <<- row + 1L
        for (term in equation$terms) {
          sparse_for_each_sum(
            term$sums, state, index, bindings,
            callback = function(sum_bindings) {
              guard_ok = TRUE
              if (length(term$guards)) {
                guard_ok = all(vapply(term$guards, function(guard) {
                  isTRUE(as.logical(sparse_eval_expr(
                    guard, state, sum_bindings, index
                  )))
                }, logical(1)))
              }
              value = if (guard_ok) sparse_eval_expr(
                term$coefficient, state, sum_bindings, index
              ) else 0
              if (guard_ok && (length(value) != 1L ||
                               !is.finite(value[[1L]]))) {
                stop(sprintf(
                  "Sparse coefficient for %s -> %s is not a finite scalar",
                  equation$name, term$ref$name
                ), call. = FALSE)
              }
              value = if (guard_ok) as.numeric(value[[1L]]) else 0
              ref_position = sparse_global_for_ref(
                term$ref, state, sum_bindings, index
              )
              variable_id = index$variable_by_name[[term$ref$name]]
              variable = index$variables[[variable_id]]
              if (isTRUE(variable$exogenous)) {
                rhs[[row]] <<- rhs[[row]] -
                  value * sparse_shock_lookup(shock_map, ref_position)
              } else {
                append_term(
                  row, variable$endo_start +
                    ref_position - variable$global_start, value
                )
              }
            }
          )
        }
      }
    )
  }
  if (row != index$equation_count) {
    stop(sprintf("Sparse row layout generated %s rows, expected %s",
                 row, index$equation_count), call. = FALSE)
  }
  if (raw_count) {
    raw_i = raw_i[seq_len(raw_count)]
    raw_j = raw_j[seq_len(raw_count)]
    raw_x = raw_x[seq_len(raw_count)]
  }
  triplets = sparse_aggregate_triplets(raw_i, raw_j, raw_x)
  if (any(!is.finite(rhs))) {
    stop("Sparse emission produced a non-finite right-hand side", call. = FALSE)
  }
  key = sparse_pattern_key(index)
  cached = index$pattern_cache
  if (!is.null(cached) && identical(cached$key, key) &&
      length(cached$i) == length(triplets$i) &&
      identical(cached$i, triplets$i) &&
      identical(cached$j, triplets$j)) {
    triplets$i = cached$i
    triplets$j = cached$j
  } else {
    index$pattern_cache = list(
      key = key, i = triplets$i, j = triplets$j,
      raw_count = raw_count, nnz = length(triplets$x)
    )
  }
  A = Matrix::sparseMatrix(
    i = triplets$i, j = triplets$j, x = triplets$x,
    dims = c(index$equation_count, index$endogenous_count),
    repr = "C"
  )
  list(A = A, rhs = rhs, index = index, nnz = length(triplets$x))
}

sparse_vectorized_expr_supported = function(expr) {
  if (is.null(expr) || is.name(expr) ||
      (!is.language(expr) && length(expr) == 1L)) return(TRUE)
  if (!is.language(expr) || length(expr) == 0L) return(TRUE)
  op = tolower(as.character(expr[[1]]))
  supported = c(
    "[", "(", "sum", "setpos", "isin", "ifelse", "!", "+", "-", "*", "/", "^",
    "==", "!=", "<", ">", "<=", ">=", "&", "|",
    "exp", "loge", "log", "sqrt", "abs"
  )
  if (!(op %in% supported) &&
      (!grepl("^[A-Za-z][A-Za-z0-9_.]*$", op) || length(expr) < 2L)) {
    return(FALSE)
  }
  if (length(expr) <= 1L) return(TRUE)
  all(vapply(as.list(expr)[-1L], sparse_vectorized_expr_supported,
             logical(1)))
}

sparse_vectorized_bindings = function(domains, index) {
  if (!length(domains)) return(list(bindings = list(), n = 1L))
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  n = as.numeric(prod(lengths))
  bindings = list()
  for (d in seq_along(domains)) {
    before = if (d == 1L) 1 else prod(lengths[seq_len(d - 1L)])
    after = if (d == length(domains)) 1 else
      prod(lengths[(d + 1L):length(domains)])
    values = rep(
      rep(seq_len(lengths[[d]]), each = after),
      times = before
    )
    bindings[[domains[[d]]$index]] = values
    bindings[[paste0(".set:", domains[[d]]$index)]] =
      domains[[d]]$set
  }
  list(bindings = bindings, n = n)
}

sparse_vectorized_index_value = function(expr, bindings, state, index, n) {
  if (is.name(expr) && !is.null(bindings[[as.character(expr)]])) {
    return(rep(bindings[[as.character(expr)]], length.out = n))
  }
  if (is.character(expr) && length(expr) == 1L &&
      !is.null(bindings[[expr]])) {
    return(rep(bindings[[expr]], length.out = n))
  }
  if (!is.language(expr)) return(rep(expr, length.out = n))
  sparse_eval_expr_vectorized(expr, state, bindings, index, n)
}

sparse_vectorized_positions = function(value, dimension, dim_names = NULL,
                                       set_name = NULL, source_set = NULL,
                                       index, n) {
  value = rep(value, length.out = n)
  if (!is.null(source_set) && !is.null(set_name) &&
      !identical(source_set, set_name) &&
      !is.null(index$sets[[source_set]]) &&
      !is.null(index$sets[[set_name]])) {
    source_values = index$sets[[source_set]]$values
    source_numeric = suppressWarnings(as.numeric(value))
    source_positions = suppressWarnings(as.integer(value))
    source_valid = !is.na(source_positions) &
      !is.na(source_numeric) & source_numeric == source_positions &
      source_positions >= 1L & source_positions <= length(source_values)
    if (any(source_valid)) {
      value[source_valid] = source_values[source_positions[source_valid]]
    }
  }
  numeric_value = suppressWarnings(as.numeric(value))
  positions = suppressWarnings(as.integer(value))
  valid = !is.na(positions) & !is.na(numeric_value) &
    numeric_value == positions &
    positions >= 1L & positions <= dimension
  if (any(!valid)) {
    lookup = NULL
    if (!is.null(dim_names)) {
      lookup = dim_names
    } else if (!is.null(set_name) && !is.null(index$sets[[set_name]])) {
      lookup = index$sets[[set_name]]$values
    }
    if (!is.null(lookup)) {
      positions[!valid] = match(as.character(value[!valid]), lookup)
    }
  }
  as.integer(positions)
}

sparse_eval_expr_vectorized = function(expr, state, bindings, index, n = NULL) {
  if (is.null(n)) {
    n = if (length(bindings)) {
      max(vapply(bindings, length, integer(1)))
    } else 1L
  }
  if (is.null(expr)) return(rep(NA_real_, n))
  if (is.name(expr)) {
    name = as.character(expr)
    if (!is.null(bindings[[name]])) {
      return(rep(bindings[[name]], length.out = n))
    }
    data = if (!is.null(state)) sparse_state_data(state)[[tolower(name)]] else NULL
    if (is.null(data)) return(rep(name, n))
    return(rep(as.numeric(data), length.out = n))
  }
  if (!is.language(expr)) return(rep(expr, length.out = n))
  if (length(expr) == 0L) return(rep(NA_real_, n))

  op = tolower(as.character(expr[[1]]))
  if (!(op %in% c(
    "[", "(", "sum", "setpos", "isin", "ifelse", "!",
    "+", "-", "*", "/", "^", "==", "!=", "<", ">",
    "<=", ">=", "&", "|", "exp", "loge", "log", "sqrt", "abs"
  )) && !is.null(sparse_state_data(state)[[op]])) {
    ref = as.call(c(
      list(as.name("["), as.name(op)),
      as.list(expr)[-1L]
    ))
    return(sparse_eval_expr_vectorized(ref, state, bindings, index, n))
  }
  if (op == "[") {
    ref = sparse_parse_ref(expr)
    data = sparse_state_data(state)[[ref$name]]
    if (is.null(data)) {
      stop(sprintf("Data array %s is missing", ref$name), call. = FALSE)
    }
    dims = dim(data)
    if (is.null(dims) || !length(ref$indices)) {
      return(rep(as.numeric(data), length.out = n))
    }
    if (length(ref$indices) != length(dims)) {
      stop(sprintf("Data array %s expects %s indices, got %s",
                   ref$name, length(dims), length(ref$indices)),
           call. = FALSE)
    }
    data_dim_names = dimnames(data)
    positions = lapply(seq_along(dims), function(d) {
      value = sparse_vectorized_index_value(
        ref$indices[[d]], bindings, state, index, n
      )
      dim_names = if (!is.null(data_dim_names) &&
                     d <= length(data_dim_names)) {
        data_dim_names[[d]]
      } else NULL
      set_name = if (!is.null(data_dim_names) &&
                     !is.null(names(data_dim_names)) &&
                     d <= length(names(data_dim_names))) {
        names(data_dim_names)[[d]]
      } else NULL
      source_set = bindings[[paste0(".set:", as.character(ref$indices[[d]]))]]
      sparse_vectorized_positions(
        value, dims[[d]], dim_names, set_name, source_set, index, n
      )
    })
    linear = rep(1, n)
    stride = 1
    for (d in seq_along(dims)) {
      linear = linear + (positions[[d]] - 1) * stride
      stride = stride * dims[[d]]
    }
    return(as.numeric(data)[linear])
  }
  if (op == "(" && length(expr) >= 2L) {
    return(sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    ))
  }


  if (op == "setpos" && length(expr) >= 2L) {
    value = sparse_vectorized_index_value(
      expr[[2]], bindings, state, index, n
    )
    source_name = bindings[[paste0(".set:", as.character(expr[[2]]))]]
    if (is.numeric(value) && !is.null(source_name) &&
        !is.null(index$sets[[source_name]])) {
      source_values = index$sets[[source_name]]$values
      labels = source_values[as.integer(value)]
      result = rep(NA_real_, n)
      candidates = names(index$sets)
      candidates = c(setdiff(candidates, source_name), source_name)
      for (candidate in candidates) {
        positions = match(labels, index$sets[[candidate]]$values)
        take = is.na(result) & !is.na(positions)
        result[take] = positions[take]
      }
      return(result)
    }
    return(as.numeric(value))
  }

  if (op == "isin" && length(expr) >= 3L) {
    value = sparse_vectorized_index_value(
      expr[[2]], bindings, state, index, n
    )
    set_name = tolower(as.character(expr[[3]]))
    set = index$sets[[set_name]]
    if (is.null(set)) {
      stop(sprintf("Unknown membership set %s", set_name), call. = FALSE)
    }
    source_name = bindings[[paste0(".set:", as.character(expr[[2]]))]]
    if (is.numeric(value) && !is.null(source_name) &&
        !is.null(index$sets[[source_name]])) {
      value = index$sets[[source_name]]$values[as.integer(value)]
    }
    return(as.character(value) %in% as.character(set$values))
  }

  if (op == "sum" && length(expr) >= 4L) {
    set_name = tolower(as.character(expr[[3]]))
    set = index$sets[[set_name]]
    if (is.null(set)) {
      stop(sprintf("Unknown sum set %s", set_name), call. = FALSE)
    }
    sum_value = numeric(n)
    index_name = as.character(expr[[2]])
    for (position in seq_along(set$values)) {
      next_bindings = bindings
      next_bindings[[index_name]] = rep(position, n)
      next_bindings[[paste0(".set:", index_name)]] = set_name
      term_value = sparse_eval_expr_vectorized(
        expr[[4]], state, next_bindings, index, n
      )
      sum_value = sum_value +
        rep(as.numeric(term_value), length.out = n)
    }
    return(sum_value)
  }

  if (op == "ifelse") {
    condition = sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    )
    yes = sparse_eval_expr_vectorized(expr[[3]], state, bindings, index, n)
    no = if (length(expr) >= 4L) {
      sparse_eval_expr_vectorized(expr[[4]], state, bindings, index, n)
    } else 0
    return(ifelse(condition, yes, no))
  }

  if (op == "!") {
    return(!sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    ))
  }

  if (op %in% c("+", "-", "*", "/", "^", "==", "!=", "<", ">",
                "<=", ">=", "&", "|")) {
    args = lapply(as.list(expr)[-1L], sparse_eval_expr_vectorized,
                  state = state, bindings = bindings, index = index, n = n)
    if (op == "-" && length(args) == 1L) return(-args[[1]])
    if (op == "/" && length(args) == 2L) {
      return(ifelse(args[[2]] == 0, 0, args[[1]] / args[[2]]))
    }
    return(do.call(op, args))
  }

  if (op %in% c("exp", "loge", "log", "sqrt", "abs")) {
    value = sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    )
    if (op == "loge") op = "log"
    return(get(op)(value))
  }

  stop(sprintf("Unsupported sparse expression operator: %s", op),
       call. = FALSE)
}

sparse_vectorized_ref_positions = function(ref, bindings, state, index, n) {
  id = index$variable_by_name[[ref$name]]
  if (is.null(id)) {
    stop(sprintf("Unknown variable in sparse expression: %s", ref$name),
         call. = FALSE)
  }
  variable = index$variables[[id]]
  if (!length(variable$sets)) return(rep(variable$global_start, n))
  if (length(ref$indices) != length(variable$sets)) {
    stop(sprintf("Variable %s expects %s indices, got %s",
                 ref$name, length(variable$sets), length(ref$indices)),
         call. = FALSE)
  }
  positions = lapply(seq_along(variable$sets), function(d) {
    value = sparse_vectorized_index_value(
      ref$indices[[d]], bindings, state, index, n
    )
    sparse_vectorized_positions(
      value, variable$lengths[[d]], set_name = variable$sets[[d]],
      source_set = bindings[[paste0(".set:",
                                      as.character(ref$indices[[d]]))]],
      index = index, n = n
    )
  })
  linear = rep(1, n)
  stride = 1
  for (d in seq_along(positions)) {
    linear = linear + (positions[[d]] - 1) * stride
    stride = stride * variable$lengths[[d]]
  }
  as.numeric(variable$global_start) + linear - 1
}

sparse_emit_system_vectorized = function(state, index, shocks) {
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(NULL, index, state)
  }
  supported = all(vapply(index$equations, function(equation) {
    all(vapply(equation$domains, function(domain) {
      is.null(domain$predicate)
    }, logical(1))) &&
      all(vapply(equation$terms, function(term) {
        sparse_vectorized_expr_supported(term$coefficient) &&
          all(vapply(term$guards, sparse_vectorized_expr_supported,
                     logical(1)))
      }, logical(1)))
  }, logical(1)))
  if (!supported) return(sparse_emit_system_scalar(state, index, shocks))

  capacity = sparse_triplet_capacity(index)
  raw_i = if (capacity) integer(capacity) else integer()
  raw_j = if (capacity) integer(capacity) else integer()
  raw_x = if (capacity) numeric(capacity) else numeric()
  raw_count = 0L
  inverse_order = if (length(index$column_order)) {
    inverse = integer(index$endogenous_count)
    inverse[index$column_order] = seq_along(index$column_order)
    inverse
  } else integer()
  rhs = numeric(index$equation_count)
  shock_positions = shocks$positions
  shock_values = shocks$values

  append_term = function(row_number, variable_position, value) {
    count = length(value)
    if (!count) return(invisible(NULL))
    start = raw_count + 1
    end = raw_count + count
    if (end > length(raw_i)) {
      growth = max(1024, end - length(raw_i), length(raw_i))
      raw_i <<- c(raw_i, integer(growth))
      raw_j <<- c(raw_j, integer(growth))
      raw_x <<- c(raw_x, numeric(growth))
    }
    raw_i[start:end] <<- as.integer(row_number)
    raw_j[start:end] <<- if (length(inverse_order)) {
      inverse_order[as.integer(variable_position)]
    } else as.integer(variable_position)
    raw_x[start:end] <<- as.numeric(value)
    raw_count <<- end
    invisible(NULL)
  }

  for (equation in index$equations) {
    for (term in equation$terms) {
      all_domains = c(
        equation$domains,
        lapply(term$sums, function(sum_spec) {
          list(index = sum_spec$index, set = sum_spec$set,
               predicate = NULL)
        })
      )
      vectorized = sparse_vectorized_bindings(all_domains, index)
      bindings = vectorized$bindings
      n = vectorized$n
      rows = if (length(term$sums)) {
        sum_multiplier = prod(vapply(term$sums, function(sum_spec) {
          length(index$sets[[sum_spec$set]]$values)
        }, numeric(1)))
        rep(seq.int(equation$row_start, equation$row_end),
            each = sum_multiplier)
      } else {
        seq.int(equation$row_start, equation$row_end)
      }
      value = sparse_eval_expr_vectorized(
        term$coefficient, state, bindings, index, n
      )
      value = rep(value, length.out = n)
      guard_ok = rep(TRUE, n)
      if (length(term$guards)) {
        for (guard in term$guards) {
          valid = as.logical(sparse_eval_expr_vectorized(
            guard, state, bindings, index, n
          ))
          valid = rep(valid, length.out = n)
          valid[is.na(valid)] = FALSE
          guard_ok = guard_ok & valid
        }
        value[!guard_ok] = 0
      }
      invalid = guard_ok & !is.finite(value)
      if (any(invalid)) {
        position = which(invalid)[[1L]]
        stop(sprintf(
          "Sparse coefficient for %s -> %s is not finite at position %s",
          equation$name, term$ref$name, position
        ), call. = FALSE)
      }
      value[!guard_ok] = 0
      ref_position = sparse_vectorized_ref_positions(
        term$ref, bindings, state, index, n
      )
      if (anyNA(rows) || any(guard_ok & is.na(ref_position))) {
        missing = which(is.na(rows) |
                        (guard_ok & is.na(ref_position)))[1L]
        stop(sprintf(
          "Sparse vectorized index failure in %s -> %s at position %s",
          equation$name, term$ref$name, missing
        ), call. = FALSE)
      }
      variable = index$variables[[index$variable_by_name[[term$ref$name]]]]
      if (isTRUE(variable$exogenous)) {
        hit = match(ref_position, shock_positions, nomatch = 0L)
        active = guard_ok & !is.na(hit) & hit > 0L
        if (any(active)) {
          contribution = sparse_aggregate_triplets(
            rows[active], rows[active],
            value[active] * shock_values[hit[active]]
          )
          rhs[contribution$i] <- rhs[contribution$i] -
            contribution$x
        }
      } else {
        append_term(
          rows[guard_ok],
          variable$endo_start + ref_position[guard_ok] -
            variable$global_start,
          value[guard_ok]
        )
      }
    }
  }
  if (raw_count) {
    raw_i = raw_i[seq_len(raw_count)]
    raw_j = raw_j[seq_len(raw_count)]
    raw_x = raw_x[seq_len(raw_count)]
  }
  triplets = sparse_aggregate_triplets(raw_i, raw_j, raw_x)
  if (any(!is.finite(rhs))) {
    stop("Sparse emission produced a non-finite right-hand side", call. = FALSE)
  }
  key = sparse_pattern_key(index)
  cached = index$pattern_cache
  if (!is.null(cached) && identical(cached$key, key) &&
      length(cached$i) == length(triplets$i) &&
      identical(cached$i, triplets$i) &&
      identical(cached$j, triplets$j)) {
    triplets$i = cached$i
    triplets$j = cached$j
  } else {
    index$pattern_cache = list(
      key = key, i = triplets$i, j = triplets$j,
      raw_count = raw_count, nnz = length(triplets$x)
    )
  }
  A = Matrix::sparseMatrix(
    i = triplets$i, j = triplets$j, x = triplets$x,
    dims = c(index$equation_count, index$endogenous_count),
    repr = "C"
  )
  list(A = A, rhs = rhs, index = index, nnz = length(triplets$x))
}

sparse_emit_system = function(state, index, shocks) {
  if (isTRUE(getOption("tabloToR.sparse.vectorized", TRUE))) {
    return(sparse_emit_system_vectorized(state, index, shocks))
  }
  sparse_emit_system_scalar(state, index, shocks)
}
sparse_lhs_column_order = function(index, state) {
  n = as.integer(index$endogenous_count)
  if (!n || index$equation_count != n ||
      !isTRUE(index$row_layout_ready)) {
    return(NULL)
  }
  if (!is.null(index$column_order) &&
      length(index$column_order) == n &&
      !anyNA(index$column_order)) {
    return(as.integer(index$column_order))
  }

  # TABLO often orders equations by economic identity rather than by the
  # variable columns.  Use left-hand-side variables as cheap structural pivots
  # before SuperLU chooses its fill-reducing ordering.  Composite left sides
  # and repeated identities are handled as a partial matching; the remaining
  # rows receive the remaining columns so this is always a permutation.
  column_order = rep(NA_integer_, n)
  used = rep(FALSE, n)
  for (equation in index$equations) {
    if (any(vapply(equation$domains, function(domain) {
      !is.null(domain$predicate)
    }, logical(1)))) {
      return(NULL)
    }
    rows = seq.int(equation$row_start, equation$row_end)
    candidates = equation$lhs_terms
    if (is.null(candidates) || !length(candidates)) {
      candidates = if (length(equation$terms)) {
        equation$terms[1L]
      } else list()
    }
    if (!length(candidates)) next
    vectorized = sparse_vectorized_bindings(equation$domains, index)
    mapped = lapply(candidates, function(term) {
      id = index$variable_by_name[[term$ref$name]]
      if (is.null(id)) return(rep(NA_integer_, length(rows)))
      variable = index$variables[[id]]
      if (isTRUE(variable$exogenous)) {
        return(rep(NA_integer_, length(rows)))
      }
      global = sparse_vectorized_ref_positions(
        term$ref, vectorized$bindings, state, index, vectorized$n
      )
      local = global - variable$global_start + 1
      result = rep(NA_integer_, length(global))
      valid = !is.na(local) &
        local == as.integer(local) &
        local >= 1 & local <= variable$n
      result[valid] = as.integer(variable$endo_start + local[valid] - 1L)
      result
    })
    scores = vapply(mapped, function(candidate) {
      valid = !is.na(candidate) & candidate >= 1L & candidate <= n
      if (!any(valid)) return(0L)
      unique_candidate = candidate[valid][!duplicated(candidate[valid])]
      as.integer(sum(!used[unique_candidate]))
    }, integer(1))
    if (!length(scores) || max(scores) == 0L) next
    candidate = mapped[[which.max(scores)]]
    valid = !is.na(candidate) & candidate >= 1L & candidate <= n
    take = rep(FALSE, length(candidate))
    if (any(valid)) {
      valid_rows = which(valid)
      take[valid_rows] = !duplicated(candidate[valid_rows]) &
        !used[candidate[valid_rows]]
    }
    if (any(take)) {
      column_order[rows[take]] = candidate[take]
      used[candidate[take]] = TRUE
    }
  }
  unmatched_rows = which(is.na(column_order))
  remaining_columns = which(!used)
  if (length(unmatched_rows) != length(remaining_columns)) return(NULL)
  column_order[unmatched_rows] = remaining_columns
  if (anyNA(column_order) || anyDuplicated(column_order)) return(NULL)
  as.integer(column_order)
}
sparse_as_sparsem_csr = function(A) {
  if (!requireNamespace("SparseM", quietly = TRUE)) {
    stop("backend='SparseM' requires the SparseM package", call. = FALSE)
  }
  entries = Matrix::summary(A)
  keep = !is.na(entries$x) & entries$x != 0
  entries$i = as.integer(entries$i[keep])
  entries$j = as.integer(entries$j[keep])
  entries$x = as.numeric(entries$x[keep])
  counts = tabulate(entries$i, nbins = nrow(A))
  methods::new(
    "matrix.csr",
    ra = entries$x,
    ja = entries$j,
    ia = as.integer(c(1L, 1L + cumsum(counts))),
    dimension = as.integer(dim(A))
  )
}
solve_sparse_system = function(A, rhs, backend = "Matrix",
                               reduction = c("auto", "off", "on")) {
  backend = match.arg(backend, c("Matrix", "SuiteSparse", "SparseM"))
  reduction = match.arg(reduction)
  if (!inherits(A, "sparseMatrix")) {
    stop("Sparse solver received a non-sparse coefficient matrix", call. = FALSE)
  }
  if (nrow(A) != ncol(A)) {
    stop(sprintf("Sparse system is not square: %s x %s", nrow(A), ncol(A)),
         call. = FALSE)
  }
  rhs = as.numeric(rhs)
  if (length(rhs) != nrow(A) || anyNA(rhs) || any(!is.finite(rhs))) {
    stop("Sparse system received an invalid right-hand side", call. = FALSE)
  }
  if (!any(rhs != 0)) return(numeric(ncol(A)))
  reduced = if (reduction == "off") {
    list(A = A, rhs = rhs, stages = list())
  } else {
    sparse_reduce_system(A, rhs)
  }
  if (!nrow(reduced$A)) {
    reduced_solution = numeric()
  } else if (backend == "Matrix") {
    lu_order = getOption("tabloToR.sparse.lu_order", 3L)
    lu_order = suppressWarnings(as.integer(lu_order)[1L])
    if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
      stop("tabloToR.sparse.lu_order must be an integer from 0 to 3",
           call. = FALSE)
    }
    factor = tryCatch(
      Matrix::lu(Matrix::drop0(reduced$A), order = lu_order),
      error = function(error) {
        stop(sprintf(
          paste(
            "Sparse LU factorization failed (ordering %s): %s.",
            "Try a different fill-reducing ordering with",
            "options(tabloToR.sparse.lu_order = 1L/2L/3L),",
            "or reduce the model before factorization."
          ),
          lu_order, conditionMessage(error)
        ), call. = FALSE)
      }
    )
    reduced_solution = as.numeric(Matrix::solve(factor, reduced$rhs))
  } else if (backend == "SuiteSparse") {
    reduced_solution = sparse_suite_sparse_solver(
      reduced$A, reduced$rhs
    )
  } else {
    csr = sparse_as_sparsem_csr(reduced$A)
    reduced_solution = as.numeric(SparseM::solve(csr, reduced$rhs))
  }
  if (length(reduced$stages)) {
    for (stage in rev(reduced$stages)) {
      stage_solution = numeric(length(stage$keep) +
                                 length(stage$eliminated$columns))
      if (length(stage$keep)) {
        stage_solution[stage$keep] = reduced_solution
      }
      if (length(stage$eliminated$columns)) {
        matrix = stage$eliminated$matrix
        contribution = if (!is.null(matrix) && nrow(matrix) &&
                            ncol(matrix)) {
          as.numeric(matrix %*% reduced_solution)
        } else numeric(length(stage$eliminated$columns))
        stage_solution[stage$eliminated$columns] = (
          stage$eliminated$rhs - contribution
        ) / stage$eliminated$pivots
      }
      reduced_solution = stage_solution
    }
  }
  reduced_solution
}
sparse_true_residual = function(A, solution, rhs) {
  if (!inherits(A, "sparseMatrix")) {
    stop("Residual check received a non-sparse coefficient matrix", call. = FALSE)
  }
  solution = as.numeric(solution)
  rhs = as.numeric(rhs)
  if (length(solution) != ncol(A) || length(rhs) != nrow(A)) {
    stop("Residual check received vectors with incompatible dimensions",
         call. = FALSE)
  }
  if (any(!is.finite(solution)) || any(!is.finite(rhs))) {
    stop("Residual check received non-finite values", call. = FALSE)
  }
  lhs = as.numeric(A %*% solution)
  residual = lhs - rhs
  residual_norm = if (length(residual)) {
    sqrt(sum(residual * residual))
  } else 0
  rhs_norm = if (length(rhs)) sqrt(sum(rhs * rhs)) else 0
  result = list(
    infinity_norm = if (length(residual)) max(abs(residual)) else 0,
    l2_norm = residual_norm,
    relative_l2 = residual_norm / max(1, rhs_norm)
  )
  rm(lhs, residual)
  result
}


sparse_reduce_system = function(A, rhs) {
  if (length(A@x) && any(!is.finite(A@x) | A@x == 0)) {
    A = Matrix::drop0(A)
  }
  stages = list()
  current_A = A
  current_rhs = as.numeric(rhs)
  A = NULL

  repeat {
    # A row singleton directly solves its only variable.  Substitute that
    # value into the other rows before removing the row and column.
    row_count = tabulate(current_A@i + 1L, nbins = nrow(current_A))
    singleton_entries = which(row_count[current_A@i + 1L] == 1L)
    if (length(singleton_entries)) {
      singleton_columns = findInterval(singleton_entries - 1L, current_A@p)
      singleton_column_count = tabulate(
        singleton_columns, nbins = ncol(current_A)
      )
      take = singleton_column_count[singleton_columns] == 1L &
        is.finite(current_A@x[singleton_entries]) &
        current_A@x[singleton_entries] != 0
      if (any(take)) {
        eliminate_entries = singleton_entries[take]
        eliminate_rows = as.integer(current_A@i[eliminate_entries] + 1L)
        eliminate_columns = as.integer(singleton_columns[take])
        pivots = as.numeric(current_A@x[eliminate_entries])
        keep_rows = setdiff(seq_len(nrow(current_A)), eliminate_rows)
        keep_columns = setdiff(seq_len(ncol(current_A)), eliminate_columns)
        eliminated_values = current_rhs[eliminate_rows] / pivots
        next_rhs = current_rhs[keep_rows]
        cross = current_A[
          keep_rows, eliminate_columns, drop = FALSE
        ] %*% eliminated_values
        next_rhs = next_rhs - as.numeric(cross)
        stages[[length(stages) + 1L]] = list(
          keep = keep_columns,
          eliminated = list(
            columns = eliminate_columns,
            pivots = pivots,
            rhs = current_rhs[eliminate_rows],
            matrix = NULL
          )
        )
        current_A = current_A[keep_rows, keep_columns, drop = FALSE]
        current_rhs = next_rhs
        next
      }
    }

    column_count = diff(current_A@p)
    candidate_columns = which(column_count == 1L)
    if (!length(candidate_columns)) break

    # A column singleton can be solved from its only row.  It is safe to
    # remove that row and column only when the row has no second singleton;
    # otherwise removing the row would strand the other singleton column.
    entry = current_A@p[candidate_columns] + 1L
    candidate_rows = current_A@i[entry] + 1L
    singleton_count = tabulate(
      candidate_rows, nbins = nrow(current_A)
    )
    take = singleton_count[candidate_rows] == 1L &
      is.finite(current_A@x[entry]) & current_A@x[entry] != 0
    if (!any(take)) break

    eliminate_columns = as.integer(candidate_columns[take])
    eliminate_rows = as.integer(candidate_rows[take])
    pivots = as.numeric(current_A@x[entry[take]])
    keep_rows = setdiff(seq_len(nrow(current_A)), eliminate_rows)
    keep_columns = setdiff(seq_len(ncol(current_A)), eliminate_columns)

    # Keep the non-pivot coefficients needed to reconstruct each eliminated
    # variable after the reduced solve.  Both matrices remain sparse.
    reconstruction = current_A[
      eliminate_rows, keep_columns, drop = FALSE
    ]
    stages[[length(stages) + 1L]] = list(
      keep = keep_columns,
      eliminated = list(
        columns = eliminate_columns,
        pivots = pivots,
        rhs = current_rhs[eliminate_rows],
        matrix = reconstruction
      )
    )

    current_A = current_A[keep_rows, keep_columns, drop = FALSE]
    current_rhs = current_rhs[keep_rows]
  }

  list(A = current_A, rhs = current_rhs, stages = stages)
}

sparse_apply_solution = function(state, index, solution) {
  data = sparse_state_data(state)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous)) next
    values = solution[seq.int(variable$endo_start,
                              length.out = variable$n)]
    array = data[[variable$name]]
    if (is.null(array)) next
    if (length(array) == length(values)) {
      array[] = values
      data[[variable$name]] = array
    }
  }
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_set_global_value = function(state, index, global_position, value) {
  for (variable in index$variables) {
    if (global_position < variable$global_start ||
        global_position > variable$global_end) next
    local = global_position - variable$global_start + 1L
    data = sparse_state_data(state)
    array = data[[variable$name]]
    if (!is.null(array)) {
      array[[local]] = value
      data[[variable$name]] = array
      if (is.environment(state)) state$data = data
    }
    return(invisible(NULL))
  }
  stop(sprintf("Unknown global variable position %s", global_position),
       call. = FALSE)
}

sparse_apply_shocks = function(state, index, shocks) {
  if (length(shocks$positions)) {
    for (i in seq_along(shocks$positions)) {
      sparse_set_global_value(
        state, index, shocks$positions[[i]], shocks$values[[i]]
      )
    }
  }
  invisible(NULL)
}

sparse_apply_updates = function(state, index, spec, updates = NULL) {
  if (is.null(spec)) return(invisible(NULL))
  if (is.null(updates)) updates = spec$updates
  if (!length(updates)) return(invisible(NULL))
  for (update_id in seq_along(updates)) {
    update = updates[[update_id]]
    sparse_initialize_update_target(update, state, index)
    vectorized = tryCatch(
      sparse_apply_update_vectorized(update, state, index),
      error = function(error) FALSE
    )
    result = if (isTRUE(vectorized)) {
      NULL
    } else tryCatch({
      sparse_for_each_domain(
        update$domains, state, index, callback = function(bindings) {
          value = sparse_eval_expr(
            update$expression, state, bindings, index
          )
          sparse_set_data_ref(
            update$target, state, bindings, index, value
          )
        }
      )
      NULL
    }, error = function(error) error)
    if (inherits(result, "error")) {
      stop(sprintf(
        "Sparse update %s (%s) failed: %s",
        update_id, update$target$name, conditionMessage(result)
      ), call. = FALSE)
    }
  }
  invisible(NULL)
}

sparse_checkpoint_state = function(state, index, spec) {
  updates = if (!is.null(spec$simulation_updates)) {
    spec$simulation_updates
  } else spec$updates
  names_to_save = unique(c(
    vapply(index$variables, function(x) x$name, character(1)),
    vapply(updates, function(x) x$target$name, character(1))
  ))
  names_to_save = intersect(names_to_save, names(sparse_state_data(state)))
  list(
    names = names_to_save,
    values = lapply(names_to_save, function(name) sparse_state_data(state)[[name]])
  )
}

sparse_restore_checkpoint = function(state, checkpoint) {
  data = sparse_state_data(state)
  for (i in seq_along(checkpoint$names)) {
    data[[checkpoint$names[[i]]]] = checkpoint$values[[i]]
  }
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_apply_update_vectorized = function(update, state, index) {
  domains = update$domains
  if (!sparse_vectorized_expr_supported(update$expression)) return(FALSE)
  if (any(vapply(domains, function(domain) {
    !is.null(domain$predicate) &&
      !sparse_vectorized_expr_supported(domain$predicate)
  }, logical(1)))) {
    return(FALSE)
  }

  lengths = if (length(domains)) {
    vapply(domains, function(domain) {
      length(index$sets[[domain$set]]$values)
    }, integer(1))
  } else integer()
  n = if (length(lengths)) as.numeric(prod(lengths)) else 1
  vectorized = sparse_vectorized_bindings(domains, index)
  value = sparse_eval_expr_vectorized(
    update$expression, state, vectorized$bindings, index, n
  )
  value = rep(as.numeric(value), length.out = n)
  active = rep(TRUE, n)
  for (domain in domains) {
    if (!is.null(domain$predicate)) {
      predicate = sparse_eval_expr_vectorized(
        domain$predicate, state, vectorized$bindings, index, n
      )
      predicate = rep(as.logical(predicate), length.out = n)
      predicate[is.na(predicate)] = FALSE
      active = active & predicate
    }
  }

  data = sparse_state_data(state)
  array = data[[update$target$name]]
  if (is.null(array)) return(FALSE)
  dimensions = dim(array)
  target_indices = update$target$indices
  if (is.null(dimensions) ||
      length(dimensions) != length(target_indices)) return(FALSE)
  if (!length(target_indices)) {
    if (length(array) != 1L) return(FALSE)
    if (active[[1L]]) data[[update$target$name]] = value[[1L]]
  } else {
    array_dim_names = dimnames(array)
    positions = lapply(seq_along(target_indices), function(d) {
      item = target_indices[[d]]
      source_set = if (is.name(item)) {
        vectorized$bindings[[paste0(".set:", as.character(item))]]
      } else NULL
      set_name = if (!is.null(array_dim_names) &&
                     !is.null(names(array_dim_names)) &&
                     d <= length(names(array_dim_names))) {
        names(array_dim_names)[[d]]
      } else NULL
      sparse_vectorized_positions(
        sparse_vectorized_index_value(
          item, vectorized$bindings, state, index, n
        ),
        dimensions[[d]],
        if (!is.null(array_dim_names)) array_dim_names[[d]] else NULL,
        set_name,
        source_set,
        index,
        n
      )
    })
    if (any(vapply(positions, anyNA, logical(1)))) return(FALSE)
    target_linear = rep(1, n)
    target_stride = 1
    for (d in seq_along(positions)) {
      target_linear = target_linear +
        (positions[[d]] - 1) * target_stride
      target_stride = target_stride * dimensions[[d]]
    }
    array[as.integer(target_linear[active])] = value[active]
    data[[update$target$name]] = array
  }
  if (is.environment(state)) state$data = data
  TRUE
}

sparse_change_mask = function(index) {
  mask = logical(index$endogenous_count)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous) || !isTRUE(variable$change)) next
    mask[seq.int(variable$endo_start, length.out = variable$n)] = TRUE
  }
  mask
}

sparse_add_solution = function(accumulator, current, change_mask) {
  if (is.null(accumulator)) return(current)
  changed = change_mask
  regular = !change_mask
  if (any(changed)) accumulator[changed] =
    accumulator[changed] + current[changed]
  if (any(regular)) accumulator[regular] =
    ((1 + accumulator[regular] / 100) *
       (1 + current[regular] / 100) - 1) * 100
  accumulator
}

sparse_substep_shocks = function(total, applied, denominator) {
  if (!length(total$values)) return(total)
  if (is.list(applied)) applied = applied$values
  remaining = ((1 + total$values / 100) /
                (1 + applied / 100) - 1) * 100
  list(
    positions = total$positions,
    values = remaining / denominator,
    labels = total$labels
  )
}

sparse_advance_applied_shocks = function(applied, substep) {
  if (!length(applied$values)) return(applied)
  applied$values = ((1 + applied$values / 100) *
                    (1 + substep$values / 100) - 1) * 100
  applied
}

sparse_extrapolate_steps = function(step_results, steps) {
  if (length(step_results) == 1L) return(step_results[[1L]])
  if (length(step_results) == 2L) {
    return((step_results[[1L]] * steps[[1L]] -
              step_results[[2L]] * steps[[2L]]) /
             (steps[[1L]] - steps[[2L]]))
  }
  if (length(step_results) == 3L) {
    return((step_results[[2L]] * steps[[2L]] -
              step_results[[3L]] * steps[[3L]]) /
             (steps[[2L]] - steps[[3L]]))
  }
  stop("Sparse solver supports one, two, or three Euler step counts",
       call. = FALSE)
}

sparse_subset_output = function(array, dimensions) {
  if (is.null(dimensions) || !length(dimensions) || is.null(dim(array))) {
    return(array)
  }
  dim_names = dimnames(array)
  selectors = vector("list", length(dim(array)))
  for (d in seq_along(selectors)) {
    set_name = if (!is.null(dim_names) && !is.null(names(dim_names))) {
      names(dim_names)[[d]]
    } else NULL
    selector = if (!is.null(set_name)) dimensions[[set_name]] else NULL
    if (is.null(selector) && d <= length(dimensions)) {
      selector = dimensions[[d]]
    }
    if (is.null(selector)) selector = TRUE
    if (is.character(selector) && !is.null(dim_names[[d]])) {
      selector = match(selector, dim_names[[d]])
    }
    selectors[[d]] = selector
  }
  do.call("[", c(list(array), selectors, list(drop = FALSE)))
}

sparse_project_outputs = function(state, index, variables = NULL,
                                  dimensions = NULL, solution = NULL) {
  data = sparse_state_data(state)
  if (is.null(variables) || !length(variables)) {
    variables = character()
  }
  variables = tolower(sub("\\[.*$", "", as.character(variables)))
  variables = intersect(unique(variables), names(data))
  result = list()
  for (name in variables) {
    result[[name]] = sparse_subset_output(data[[name]], dimensions)
  }
  if (!is.null(solution)) result$solution = solution
  result
}

sparse_gc_bytes = function() {
  info = gc()
  as.numeric(sum(info[, "used"])) * 8
}

sparse_restrict_index = function(index, equation_ids, state) {
  active = index
  active$equations = index$equations[equation_ids]
  references = unique(unlist(lapply(active$equations, function(equation) {
    vapply(equation$terms, function(term) term$ref$name, character(1))
  }), use.names = FALSE))
  references = union(references, index$closure_names)
  variable_ids = which(vapply(index$variables, function(variable) {
    variable$name %in% references
  }, logical(1)))
  active$variables = index$variables[variable_ids]
  active$variable_by_name = setNames(
    as.list(seq_along(active$variables)),
    vapply(active$variables, function(variable) variable$name, character(1))
  )

  global_start = 1L
  endo_start = 1L
  for (id in seq_along(active$variables)) {
    variable = active$variables[[id]]
    variable$global_start = as.integer(global_start)
    variable$global_end = as.integer(global_start + variable$n - 1L)
    variable$exogenous = variable$name %in% index$closure_names
    if (variable$exogenous) {
      variable$endo_start = NA_integer_
    } else {
      variable$endo_start = as.integer(endo_start)
      endo_start = endo_start + variable$n
    }
    active$variables[[id]] = variable
    global_start = global_start + variable$n
  }

  active$variable_count = as.integer(global_start - 1L)
  active$endogenous_count = as.integer(endo_start - 1L)
  active$equation_ids = as.integer(equation_ids)
  active$full_equation_count = index$equation_count
  active$full_endogenous_count = index$endogenous_count
  active$row_layout_ready = FALSE
  active$pattern_cache = NULL
  active$column_order = NULL
  sparse_build_row_layout(NULL, active, state)
}

sparse_select_simulation_index = function(index, spec, state,
                                          postsim = TRUE) {
  if (isTRUE(postsim) || is.null(spec) ||
      !length(spec$simulation_equation_candidates)) {
    return(index)
  }
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(spec, index, state)
  }
  for (cut in spec$simulation_equation_candidates) {
    candidate = sparse_restrict_index(
      index, seq_len(as.integer(cut)), state
    )
    if (candidate$equation_count == candidate$endogenous_count &&
        candidate$equation_count > 0L) {
      candidate$simulation_boundary = as.integer(cut)
      return(candidate)
    }
  }
  index
}

sparse_estimate_memory = function(model, index, engine = "sparse",
                                  budget = NULL, postsim = TRUE,
                                  state = NULL) {
  if (is.null(state)) state = model$sparseState
  data = if (!is.null(state)) sparse_state_data(state) else model$data
  input_bytes = as.numeric(object.size(data))
  variable_bytes = sum(vapply(index$variables, function(variable) {
    8 * variable$n
  }, numeric(1)))
  equation_positions = as.numeric(index$equation_count)
  triplets = sparse_triplet_capacity(index)
  triplet_bytes = triplets * (8 + 4 + 4)
  matrix_bytes = triplet_bytes + equation_positions * 8
  factor_bytes = triplet_bytes * 2
  rhs_bytes = equation_positions * 8
  metadata_bytes = as.numeric(object.size(index))
  peak = input_bytes + variable_bytes + triplet_bytes + matrix_bytes +
    factor_bytes + rhs_bytes + metadata_bytes
  list(
    engine = engine,
    har_input_bytes = input_bytes,
    model_variable_bytes = variable_bytes,
    equation_positions = equation_positions,
    variable_positions = as.numeric(index$variable_count),
    endogenous_positions = as.numeric(index$endogenous_count),
    estimated_sparse_triplets = triplets,
    estimated_triplet_bytes = triplet_bytes,
    estimated_sparse_matrix_bytes = matrix_bytes,
    estimated_factor_workspace_bytes = factor_bytes,
    estimated_rhs_bytes = rhs_bytes,
    estimated_metadata_bytes = metadata_bytes,
    estimated_peak_bytes = peak,
    post_simulation_retained = isTRUE(postsim),
    dense_fallback = FALSE,
    budget_bytes = budget
  )
}

sparse_check_budget = function(estimate, budget) {
  if (is.null(budget) || !length(budget) || is.na(budget)) return(invisible(NULL))
  if (estimate$estimated_peak_bytes > budget) {
    stop(sprintf(
      paste(
        "Sparse preflight estimates %.2f GB peak allocation,",
        "above the configured %.2f GB budget.",
        "Increase setMemoryBudget(), reduce retained outputs,",
        "or use a smaller closure/data slice."
      ),
      estimate$estimated_peak_bytes / 1024^3, budget / 1024^3
    ), call. = FALSE)
  }
  invisible(NULL)
}

sparse_solve_one_step = function(state, model, index, shocks, backend,
                                 reduction, measure = FALSE,
                                 structured_partition = NULL) {
  if (isTRUE(measure)) {
    before_bytes = sparse_gc_bytes()
    matrix_start = proc.time()[[3L]]
  }
  column_order = sparse_lhs_column_order(index, state)
  index$column_order = column_order
  emitted = sparse_emit_system(state, index, shocks)
  index = emitted$index
  coefficient_matrix = emitted$A
  if (isTRUE(measure)) {
    matrix_end = proc.time()[[3L]]
    matrix_bytes = sparse_gc_bytes()
    solve_start = proc.time()[[3L]]
  }
  solver_diagnostics = NULL
  if (backend %in% c("StructuredSchur", "StructuredSchurFGMRES")) {
    if (is.null(structured_partition)) {
      stop("StructuredSchur backend requires a model-specific partition",
           call. = FALSE)
    }
    exact_result = sparse_exact_structured_solve(
      coefficient_matrix, emitted$rhs, structured_partition,
      lu_order = getOption("tabloToR.sparse.lu_order", 3L),
      pivot_tolerance = getOption(
        "tabloToR.sparse.elimination_pivot_tolerance", 1e-12
      ),
      reduced_solver = if (identical(backend, "StructuredSchurFGMRES")) {
        "schur"
      } else "btf"
    )
    solution = exact_result$solution
    solver_diagnostics = exact_result
  } else {
    solution = solve_sparse_system(
      coefficient_matrix, emitted$rhs, backend = backend,
      reduction = reduction
    )
  }
  true_residual = if (
    isTRUE(measure) ||
      backend %in% c("StructuredSchur", "StructuredSchurFGMRES") ||
      isTRUE(getOption("tabloToR.sparse.check_residual", FALSE))
  ) sparse_true_residual(coefficient_matrix, solution, emitted$rhs) else NULL
  if (backend %in% c("StructuredSchur", "StructuredSchurFGMRES")) {
    residual_tolerance = getOption(
      "tabloToR.sparse.structured_residual_tolerance", 2e-7
    )
    if (!is.numeric(residual_tolerance) || length(residual_tolerance) != 1L ||
        !is.finite(residual_tolerance) || residual_tolerance < 0) {
      stop(
        "tabloToR.sparse.structured_residual_tolerance must be a non-negative finite scalar",
        call. = FALSE
      )
    }
    if (true_residual$relative_l2 > residual_tolerance) {
      stop(sprintf(
        paste(
          "StructuredSchur residual %.3e exceeds tolerance %.3e;",
          "the solution was not applied."
        ), true_residual$relative_l2, residual_tolerance
      ), call. = FALSE)
    }
  }
  if (length(column_order)) {
    original_solution = numeric(length(solution))
    original_solution[column_order] = solution
    solution = original_solution
  }
  coefficient_matrix = NULL
  if (isTRUE(measure)) {
    solve_end = proc.time()[[3L]]
    solve_bytes = sparse_gc_bytes()
    update_start = proc.time()[[3L]]
  }
  sparse_apply_solution(state, index, solution)
  sparse_apply_shocks(state, index, shocks)
  sparse_apply_updates(
    state, index, model$sparseSpec,
    updates = model$sparseSpec$simulation_updates
  )
  if (isTRUE(measure)) {
    update_end = proc.time()[[3L]]
    update_bytes = sparse_gc_bytes()
    phase = list(
      matrix_seconds = matrix_end - matrix_start,
      factor_solve_seconds = solve_end - solve_start,
      update_seconds = update_end - update_start,
      matrix_alloc_bytes = max(0, matrix_bytes - before_bytes),
      factor_solve_alloc_bytes = max(0, solve_bytes - matrix_bytes),
      update_alloc_bytes = max(0, update_bytes - solve_bytes)
    )
  } else {
    phase = NULL
  }
  list(
    solution = solution,
    nnz = emitted$nnz,
    true_residual = true_residual,
    solver_diagnostics = solver_diagnostics,
    column_permuted = length(column_order) > 0L,
    phase = phase,
    index = index
  )
}

sparse_solve_model = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix",
                              reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  if (!is.numeric(iter) || length(iter) != 1L || iter < 1 ||
      iter != as.integer(iter)) {
    stop("iter must be a positive integer", call. = FALSE)
  }
  if (!length(steps) || any(steps < 1) ||
      any(steps != as.integer(steps))) {
    stop("steps must contain positive integers", call. = FALSE)
  }
  output = match.arg(output)
  reduction = match.arg(reduction)
  backend = match.arg(backend, c(
    "Matrix", "SuiteSparse", "SparseM", "StructuredSchur", "StructuredSchurFGMRES"
  ))
  index = model$sparseIndex
  if (is.null(index) || !length(index)) {
    stop("Sparse engine is not loaded; call loadTablo() and loadData() first",
         call. = FALSE)
  }
  state = model$sparseState
  if (is.null(state) || !is.environment(state)) {
    state = sparse_make_state(model$data)
  }
  closure = model$closure
  if (is.null(closure)) closure = character()
  index = sparse_rebuild_columns(index, closure)
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(model$sparseSpec, index, state)
  }
  full_index = index
  index = sparse_select_simulation_index(
    index, model$sparseSpec, state, postsim = postsim
  )
  if (index$equation_count != index$endogenous_count) {
    stop(sprintf(
      "Sparse system is not square: %s equations, %s endogenous variables.",
      index$equation_count, index$endogenous_count
    ), call. = FALSE)
  }
  structured_partition = NULL
  if (backend %in% c("StructuredSchur", "StructuredSchurFGMRES")) {
    if (!exists("sparse_gtap_elimination_partition", mode = "function")) {
      stop("Structured sparse elimination helpers are unavailable",
           call. = FALSE)
    }
    index$column_order = sparse_lhs_column_order(index, state)
    if (is.null(index$column_order)) {
      stop("StructuredSchur backend could not construct a column order",
           call. = FALSE)
    }
    structured_partition = sparse_gtap_elimination_partition(index, state)
  }
  model$sparseIndex = full_index
  budget = memory_budget
  if (is.null(budget) || !length(budget)) budget = model$memoryBudget
  estimate = sparse_estimate_memory(
    model, index, budget = budget, postsim = postsim, state = state
  )
  sparse_check_budget(estimate, budget)
  phase_metrics = list(
    matrix_seconds = 0,
    factor_solve_seconds = 0,
    update_seconds = 0,
    matrix_alloc_bytes = 0,
    factor_solve_alloc_bytes = 0,
    update_alloc_bytes = 0
  )
  start_time = proc.time()[[3L]]
  shocks = sparse_resolve_shocks(model, state, index)
  change_mask = sparse_change_mask(index)
  final_solution = NULL
  applied_shocks = list(
    positions = shocks$positions,
    values = numeric(length(shocks$values)),
    labels = shocks$labels
  )
  max_nnz = 0
  residual_history = list()
  solver_diagnostics_history = list()
  for (iteration in seq_len(iter)) {
    outer_checkpoint = sparse_checkpoint_state(
      state, index, model$sparseSpec
    )
    remaining = sparse_substep_shocks(
      shocks, applied_shocks, iter - iteration + 1L
    )
    applied_shocks = sparse_advance_applied_shocks(
      applied_shocks, remaining
    )
    step_results = vector("list", length(steps))
    for (step_id in seq_along(steps)) {
      sparse_restore_checkpoint(state, outer_checkpoint)
      step_count = as.integer(steps[[step_id]])
      applied_subshocks = list(
        positions = shocks$positions,
        values = numeric(length(shocks$values)),
        labels = shocks$labels
      )
      step_result = numeric(index$endogenous_count)
      for (current_step in seq_len(step_count)) {
        substep = sparse_substep_shocks(
          remaining, applied_subshocks, step_count - current_step + 1L
        )
        applied_subshocks = sparse_advance_applied_shocks(
          applied_subshocks, substep
        )
        solved = sparse_solve_one_step(
          state, model, index, substep, backend, reduction,
          measure = diagnostics,
          structured_partition = structured_partition
        )
        index = solved$index
        if (!is.null(solved$solver_diagnostics)) {
          solver_diagnostics_history[[
            length(solver_diagnostics_history) + 1L
          ]] = solved$solver_diagnostics
        }
        if (!is.null(solved$phase)) {
          for (metric in names(phase_metrics)) {
            if (grepl("_seconds$", metric)) {
              phase_metrics[[metric]] = phase_metrics[[metric]] +
                solved$phase[[metric]]
            } else {
              phase_metrics[[metric]] = max(
                phase_metrics[[metric]], solved$phase[[metric]]
              )
            }
          }
        }
        max_nnz = max(max_nnz, solved$nnz)
        if (!is.null(solved$true_residual)) {
          residual_history[[length(residual_history) + 1L]] = list(
            iteration = iteration, step = step_id, substep = current_step,
            metrics = solved$true_residual
          )
        }
        step_result = sparse_add_solution(
          step_result, solved$solution, change_mask
        )
      }
      step_results[[step_id]] = step_result
    }
    iteration_solution = sparse_extrapolate_steps(step_results, steps)
    sparse_restore_checkpoint(state, outer_checkpoint)
    sparse_apply_solution(state, index, iteration_solution)
    sparse_apply_shocks(state, index, remaining)
    sparse_apply_updates(
      state, index, model$sparseSpec,
      updates = model$sparseSpec$simulation_updates
    )
    final_solution = sparse_add_solution(
      final_solution, iteration_solution, change_mask
    )
  }
  if (is.null(final_solution)) final_solution = numeric(index$endogenous_count)
  sparse_apply_solution(state, index, final_solution)
  sparse_apply_shocks(state, index, shocks)
  sparse_apply_updates(
    state, index, model$sparseSpec,
    updates = model$sparseSpec$simulation_updates
  )
  if (postsim) {
    sparse_apply_updates(
      state, index, model$sparseSpec,
      updates = model$sparseSpec$post_updates
    )
  }
  solution = final_solution
  if (output == "full") names(solution) = sparse_endogenous_labels(index)
  selected = if (output == "compact" || !is.null(variables) ||
                 !is.null(dimensions)) {
    sparse_project_outputs(
      state, index, variables, dimensions,
      if (output == "compact") solution else NULL
    )
  } else NULL
  if (!is.null(selected)) model$compactOutput = selected
  if (postsim) {
    model$data = if (output == "full") {
      sparse_materialize_labels(state, index, equations = TRUE, variables = TRUE)
    } else {
      sparse_state_data(state)
    }
  } else {
    model$data = list()
  }
  model$sparseState = state
  model$sparseIndex = full_index
  model$solution = solution
  model$loadedEngine = "sparse"
  diagnostics_result = list(
    engine = "sparse",
    iterations = iter,
    steps = steps,
    elapsed_seconds = proc.time()[[3L]] - start_time,
    estimated_memory = estimate,
    max_sparse_nonzeros = max_nnz,
    true_residual_history = residual_history,
    solver_backend = backend,
    solver_diagnostics = if (length(solver_diagnostics_history)) {
      solver_diagnostics_history[[length(solver_diagnostics_history)]]
    } else NULL,
    phase_allocations = phase_metrics,
    phase_seconds = phase_metrics[c("matrix_seconds",
                                    "factor_solve_seconds", "update_seconds")],
    dense_fallback = FALSE,
    post_simulation_retained = isTRUE(postsim),
    peak_gc_bytes = if (isTRUE(diagnostics)) sparse_gc_bytes() else NA_real_
  )
  model$lastDiagnostics = if (isTRUE(diagnostics)) diagnostics_result else list()
  invisible(model)
}
