# Integer-indexed TABLO compilation used by the sparse execution engine.

normalizeTabloExpression = function(text) {
  text = paste(as.character(text), collapse = " ")
  text = gsub("<>", "!=", text, fixed = TRUE)
  text = gsub("\\bge\\b", ">=", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\ble\\b", "<=", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\bgt\\b", ">", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\blt\\b", "<", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\bne\\b", "!=", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\beq\\b", "==", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\band\\b", "&", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\bor\\b", "|", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("([A-Za-z][A-Za-z0-9_.]*)\\s+in\\s+([A-Za-z][A-Za-z0-9_.]*)", "isin(\\1,\\2)", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\$pos\\s*\\(", "setpos(", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\bIF\\s*\\[", "ifelse(", text, ignore.case = TRUE, perl = TRUE)
  text = gsub("\\bIF\\s*\\(", "ifelse(", text, ignore.case = TRUE, perl = TRUE)
  text
}

sparse_parse_qualifier = function(element) {
  element = trimws(element)
  element = sub("^\\(", "", element)
  element = sub("\\)$", "", element)
  element = gsub(":", ",", element, fixed = TRUE)
  element = normalizeTabloExpression(element)
  element = gsub("(?<![<>=!])=(?!=)", "==", element, perl = TRUE)
  if (grepl("^all\\s*,", element, ignore.case = TRUE)) {
    element = paste0(sub("^all\\s*,", "all(", element, ignore.case = TRUE), ")")
  }
  parsed = tryCatch(str2lang(element), error = function(e) NULL)
  if (is.null(parsed) || length(parsed) < 3 ||
      !identical(as.character(parsed[[1]]), "all")) {
    stop(sprintf("Unsupported TABLO qualifier: %s", element), call. = FALSE)
  }
  list(
    index = as.character(parsed[[2]]),
    set = tolower(as.character(parsed[[3]])),
    predicate = if (length(parsed) >= 4) parsed[[4]] else NULL
  )
}

sparse_parse_ref = function(expr) {
  if (is.name(expr) || (is.atomic(expr) && length(expr) == 1L)) {
    return(list(name = tolower(as.character(expr)), indices = list()))
  }
  if (is.language(expr) && identical(as.character(expr[[1]]), "[")) {
    return(list(
      name = tolower(as.character(expr[[2]])),
      indices = if (length(expr) > 2L) as.list(expr[3:length(expr)]) else list()
    ))
  }
  stop(sprintf("Expected an indexed TABLO reference, got %s",
               paste(deparse(expr), collapse = " ")), call. = FALSE)
}

sparse_ref_is_variable = function(expr, variable_names) {
  ref = tryCatch(sparse_parse_ref(expr), error = function(e) NULL)
  !is.null(ref) && ref$name %in% variable_names
}

sparse_expr_has_variable = function(expr, variable_names) {
  if (sparse_ref_is_variable(expr, variable_names)) return(TRUE)
  if (!is.language(expr) || length(expr) <= 1L) return(FALSE)
  any(vapply(as.list(expr)[-1L], sparse_expr_has_variable,
             logical(1), variable_names = variable_names))
}
sparse_expr_set_names = function(expr) {
  if (!is.language(expr) || is.name(expr) || length(expr) == 0L) return(character())
  op = tolower(as.character(expr[[1]]))
  result = character()
  if (op %in% c("isin", "sum") && length(expr) >= 3L) {
    result = c(result, tolower(as.character(expr[[3]])))
  }
  if (length(expr) > 1L) result = c(result, unlist(lapply(as.list(expr)[-1L], sparse_expr_set_names), use.names = FALSE))
  unique(result)
}

sparse_expr_data_names = function(expr) {
  if (is.null(expr)) return(character())
  if (is.name(expr)) return(tolower(as.character(expr)))
  if (!is.language(expr) || length(expr) == 0L) return(character())
  op = tolower(as.character(expr[[1]]))
  if (op == "[" && length(expr) >= 2L) {
    ref = expr[[2]]
    result = if (is.name(ref) || (is.atomic(ref) && length(ref) == 1L)) {
      tolower(as.character(ref))
    } else character()
    if (length(expr) > 2L) {
      result = c(
        result,
        unlist(lapply(as.list(expr)[-c(1L, 2L)], sparse_expr_data_names),
               use.names = FALSE)
      )
    }
    return(unique(result))
  }
  if (length(expr) <= 1L) return(character())
  unique(unlist(lapply(as.list(expr)[-1L], sparse_expr_data_names),
                use.names = FALSE))
}

sparse_required_formula_names = function(equations, updates) {
  formulas = Filter(function(update) update$class == "formula", updates)
  if (!length(formulas)) return(character())
  formula_names = unique(vapply(
    formulas, function(update) update$target$name, character(1)
  ))
  formula_targets = vapply(
    formulas, function(update) update$target$name, character(1)
  )
  dependencies = lapply(
    split(seq_along(formulas), formula_targets),
    function(ids) unique(unlist(lapply(formulas[ids], function(update) {
      intersect(sparse_expr_data_names(update$expression), formula_names)
    }), use.names = FALSE))
  )
  needed = unique(unlist(lapply(equations, function(equation) {
    unlist(lapply(equation$terms, function(term) {
      sparse_expr_data_names(term$coefficient)
    }), use.names = FALSE)
  }), use.names = FALSE))
  update_needed = unique(unlist(lapply(
    Filter(function(update) update$class == "update", updates),
    function(update) sparse_expr_data_names(update$expression)
  ), use.names = FALSE))
  needed = intersect(union(needed, update_needed), formula_names)
  repeat {
    more = unique(unlist(dependencies[needed], use.names = FALSE))
    next_needed = union(needed, more)
    if (length(next_needed) == length(needed)) break
    needed = next_needed
  }
  needed
}
sparse_order_domains = function(domains, indices) {
  if (!length(domains) || !length(indices)) return(domains)
  domain_indices = vapply(domains, function(domain) {
    tolower(domain$index)
  }, character(1))
  index_names = vapply(indices, function(index) {
    tolower(as.character(index))
  }, character(1))
  if (length(domain_indices) == length(index_names) &&
      all(index_names %in% domain_indices)) {
    return(unname(domains[match(index_names, domain_indices)]))
  }
  domains
}
sparse_mul_expr = function(left, right) {
  if (identical(left, quote(1))) return(right)
  if (identical(right, quote(1))) return(left)
  call("*", left, right)
}

sparse_neg_expr = function(expr) call("-", expr)

sparse_terms_from_expr = function(expr,
                                  variable_names,
                                  coefficient = quote(1),
                                  guards = list(),
                                  sums = list()) {
  if (is.null(expr) || (!is.language(expr) && length(expr) == 1L)) {
    return(list())
  }

  if (sparse_ref_is_variable(expr, variable_names)) {
    return(list(list(
      ref = sparse_parse_ref(expr),
      coefficient = coefficient,
      guards = guards,
      sums = sums
    )))
  }

  if (!is.language(expr) || length(expr) == 0L) return(list())
  op = as.character(expr[[1]])

  if (op == "=" && length(expr) >= 3L) {
    return(c(
      sparse_terms_from_expr(expr[[2]], variable_names, coefficient, guards, sums),
      sparse_terms_from_expr(expr[[3]], variable_names,
                             sparse_neg_expr(coefficient), guards, sums)
    ))
  }

  if (op == "+" && length(expr) >= 3L) {
    return(c(
      sparse_terms_from_expr(expr[[2]], variable_names, coefficient, guards, sums),
      sparse_terms_from_expr(expr[[3]], variable_names, coefficient, guards, sums)
    ))
  }

  if (op == "-" && length(expr) == 3L) {
    return(c(
      sparse_terms_from_expr(expr[[2]], variable_names, coefficient, guards, sums),
      sparse_terms_from_expr(expr[[3]], variable_names,
                             sparse_neg_expr(coefficient), guards, sums)
    ))
  }

  if (op == "-" && length(expr) == 2L) {
    return(sparse_terms_from_expr(expr[[2]], variable_names,
                                  sparse_neg_expr(coefficient), guards, sums))
  }

  if (op == "(" && length(expr) >= 2L) {
    return(sparse_terms_from_expr(expr[[2]], variable_names,
                                  coefficient, guards, sums))
  }

  if (op == "sum" && length(expr) >= 4L) {
    sum_spec = list(
      index = as.character(expr[[2]]),
      set = tolower(as.character(expr[[3]]))
    )
    return(sparse_terms_from_expr(
      expr[[4]], variable_names, coefficient, guards,
      c(sums, list(sum_spec))
    ))
  }

  if (op == "ifelse" && length(expr) >= 4L) {
    yes_terms = sparse_terms_from_expr(
      expr[[3]], variable_names, coefficient,
      c(guards, list(expr[[2]])), sums
    )
    no_terms = sparse_terms_from_expr(
      expr[[4]], variable_names, coefficient,
      c(guards, list(call("!", expr[[2]]))), sums
    )
    return(c(yes_terms, no_terms))
  }

  if (op == "*" && length(expr) == 3L) {
    left_has = sparse_expr_has_variable(expr[[2]], variable_names)
    right_has = sparse_expr_has_variable(expr[[3]], variable_names)
    if (left_has && !right_has) {
      return(sparse_terms_from_expr(
        expr[[2]], variable_names,
        sparse_mul_expr(coefficient, expr[[3]]), guards, sums
      ))
    }
    if (!left_has && right_has) {
      return(sparse_terms_from_expr(
        expr[[3]], variable_names,
        sparse_mul_expr(coefficient, expr[[2]]), guards, sums
      ))
    }
    stop(sprintf(
      "Non-linear or ambiguous variable product in TABLO expression: %s",
      paste(deparse(expr), collapse = " ")
    ), call. = FALSE)
  }

  if (sparse_expr_has_variable(expr, variable_names)) {
    stop(sprintf(
      "Unsupported variable expression in sparse compiler: %s",
      paste(deparse(expr), collapse = " ")
    ), call. = FALSE)
  }

  list()
}

sparse_infer_simulation_equation_candidates = function(equations) {
  n = length(equations)
  if (n < 3L) return(integer())
  references = lapply(equations, function(equation) {
    unique(vapply(equation$terms, function(term) term$ref$name,
                  character(1)))
  })
  definitions = list()
  for (equation_id in seq_along(equations)) {
    lhs = unique(vapply(
      equations[[equation_id]]$lhs_terms,
      function(term) term$ref$name,
      character(1)
    ))
    for (name in lhs) {
      if (is.null(definitions[[name]])) {
        definitions[[name]] = equation_id
      }
    }
  }
  candidates = integer()
  prefix_references = character()
  for (cut in seq_len(n - 1L)) {
    prefix_references = union(prefix_references, references[[cut]])
    later = vapply(prefix_references, function(name) {
      definition = definitions[[name]]
      !is.null(definition) && definition > cut
    }, logical(1))
    if (any(later)) next
    suffix_references = unique(unlist(
      references[seq.int(cut + 1L, n)], use.names = FALSE
    ))
    if (length(intersect(prefix_references, suffix_references))) {
      candidates = c(candidates, cut)
    }
  }
  as.integer(candidates)
}

sparse_compile_spec = function(statements) {
  variable_statements = Filter(function(s) s$class == "variable", statements)
  equation_statements = Filter(function(s) s$class == "equation", statements)
  update_statements = Filter(function(s) s$class %in% c("update", "formula"), statements)

  variable_names = unique(vapply(variable_statements, function(s) {
    ref = correctFormula(s$parsed$equation)
    sparse_parse_ref(ref)$name
  }, character(1)))

  variables = list()
  variable_by_name = list()
  for (s in variable_statements) {
    ref = sparse_parse_ref(correctFormula(s$parsed$equation))
    domains = lapply(
      s$parsed$elements[grepl("^\\s*\\(all,", s$parsed$elements, ignore.case = TRUE)],
      sparse_parse_qualifier
    )
    domains = sparse_order_domains(domains, ref$indices)
    if (is.null(variable_by_name[[ref$name]])) {
      variable = list(
        name = ref$name,
        indices = ref$indices,
        domains = domains,
        change = any(grepl("change", s$parsed$elements, ignore.case = TRUE))
      )
      variables[[length(variables) + 1L]] = variable
      variable_by_name[[ref$name]] = length(variables)
    } else {
      old = variables[[variable_by_name[[ref$name]]]]
      old_sets = vapply(old$domains, function(x) x$set, "")
      new_sets = vapply(domains, function(x) x$set, "")
      if (length(old$domains) != length(domains) ||
          !identical(old_sets, new_sets)) {
        stop(sprintf("Variable %s has incompatible TABLO declarations",
                     ref$name), call. = FALSE)
      }
      old$change = old$change ||
        any(grepl("change", s$parsed$elements, ignore.case = TRUE))
      variables[[variable_by_name[[ref$name]]]] = old
    }
  }

  equations = list()
  compile_errors = character()
  for (s in equation_statements) {
    domains = lapply(
      s$parsed$elements[grepl("^\\s*\\(all,", s$parsed$elements, ignore.case = TRUE)],
      sparse_parse_qualifier
    )
    formula = tryCatch(
      correctFormula(s$parsed$equation),
      error = function(e) {
        compile_errors <<- c(
          compile_errors,
          sprintf("%s: %s", s$parsed$equationName, conditionMessage(e))
        )
        NULL
      }
    )
    if (!is.null(formula) && length(formula) >= 3L) {
      equation_ref = tryCatch(sparse_parse_ref(formula[[2]]),
                              error = function(e) NULL)
      if (!is.null(equation_ref)) {
        domains = sparse_order_domains(domains, equation_ref$indices)
      }
    }
    terms = if (is.null(formula)) list() else tryCatch(
      sparse_terms_from_expr(formula, variable_names),
      error = function(e) {
        compile_errors <<- c(
          compile_errors,
          sprintf("%s: %s", s$parsed$equationName, conditionMessage(e))
        )
        list()
      }
    )
    lhs_terms = if (!is.null(formula) && length(formula) >= 3L) {
      tryCatch(
        sparse_terms_from_expr(formula[[2]], variable_names),
        error = function(e) list()
      )
    } else list()
    equations[[length(equations) + 1L]] = list(
      name = tolower(s$parsed$equationName),
      domains = domains,
      terms = terms,
      lhs_terms = lhs_terms
    )
  }

  updates = list()
  for (s in update_statements) {
    is_initial = any(grepl("\\(initial\\)", s$parsed$elements,
                           ignore.case = TRUE))
    formula = tryCatch(correctFormula(s$parsed$equation),
                       error = function(e) NULL)
    if (is.null(formula) || length(formula) < 3L) next
    target = tryCatch(sparse_parse_ref(formula[[2]]),
                      error = function(e) NULL)
    if (is.null(target)) next
    rhs = formula[[3]]
    if (s$class == "update") {
      is_change = any(grepl("\\(change\\)", s$parsed$elements,
                             ignore.case = TRUE))
      if (is_change) {
        rhs = call("+", formula[[2]], rhs)
      } else if (length(rhs) == 1L) {
        rhs = call("*", formula[[2]],
                   call("+", quote(1), call("/", rhs, quote(100))))
      } else if (is.language(rhs) && identical(as.character(rhs[[1]]), "*") &&
                 length(rhs) == 3L) {
        rhs = call(
          "*", formula[[2]],
          call("*",
               call("+", quote(1), call("/", rhs[[2]], quote(100))),
               call("+", quote(1), call("/", rhs[[3]], quote(100))))
        )
      } else {
        rhs = call("*", formula[[2]],
                   call("+", quote(1), call("/", rhs, quote(100))))
      }
    }
    update_domains = lapply(
      s$parsed$elements[grepl("^\\s*\\(all,", s$parsed$elements,
                              ignore.case = TRUE)],
      sparse_parse_qualifier
    )
    update_domains = sparse_order_domains(update_domains, target$indices)
    updates[[length(updates) + 1L]] = list(
      class = s$class,
      target = target,
      expression = rhs,
      initial = is_initial,
      domains = update_domains
    )
  }

  formula_names = unique(vapply(
    Filter(function(update) update$class == "formula", updates),
    function(update) update$target$name, character(1)
  ))
  required_formula_names = sparse_required_formula_names(equations, updates)
  simulation_equation_candidates =
    sparse_infer_simulation_equation_candidates(equations)
  initial_updates = Filter(function(update) {
    update$class == "formula" &&
      isTRUE(update$initial) &&
      update$target$name %in% required_formula_names
  }, updates)
  simulation_updates = Filter(function(update) {
    update$class == "update" ||
      (update$class == "formula" &&
         !isTRUE(update$initial) &&
         update$target$name %in% required_formula_names)
  }, updates)
  formula_initialization_updates = Filter(function(update) {
    update$class == "formula" &&
      update$target$name %in% required_formula_names
  }, updates)
  post_updates = Filter(function(update) {
    update$class == "formula" && !isTRUE(update$initial)
  }, updates)
  list(
    variables = variables,
    variable_by_name = variable_by_name,
    equations = equations,
    updates = updates,
    initial_updates = initial_updates,
    simulation_updates = simulation_updates,
    formula_initialization_updates = formula_initialization_updates,
    post_updates = post_updates,
    formula_names = formula_names,
    required_formula_names = required_formula_names,
    simulation_equation_candidates = simulation_equation_candidates,
    variable_names = variable_names,
    compile_errors = unique(compile_errors),
    statements = statements
  )
}

sparse_find_set_values = function(data, set_name) {
  set_name = tolower(set_name)
  if (!is.null(data[[set_name]])) {
    value = data[[set_name]]
  } else if (!is.null(data[[toupper(set_name)]])) {
    value = data[[toupper(set_name)]]
  } else {
    value = NULL
    for (candidate in names(data)) {
      item = data[[candidate]]
      if (is.list(item) && !is.null(item[[set_name]])) {
        value = item[[set_name]]
        break
      }
      if (is.list(item) && !is.null(item[[toupper(set_name)]])) {
        value = item[[toupper(set_name)]]
        break
      }
    }
  }
  if (is.null(value)) {
    stop(sprintf("TABLO set %s is missing from loaded data",
                 set_name), call. = FALSE)
  }
  value = as.character(value)
  value[!is.na(value)]
}

sparse_build_index = function(spec, data) {
  sets = list()
  all_domains = unlist(lapply(c(spec$variables, spec$equations), function(x) x$domains),
                       recursive = FALSE)
  set_names = unique(vapply(all_domains, function(x) x$set, ""))
  set_expressions = list()
  for (definition in c(spec$variables, spec$equations)) {
    for (domain in definition$domains) {
      if (!is.null(domain$predicate)) {
        set_expressions[[length(set_expressions) + 1L]] = domain$predicate
      }
    }
  }
  for (equation in spec$equations) {
    for (term in equation$terms) {
      for (guard in term$guards) {
        set_expressions[[length(set_expressions) + 1L]] = guard
      }
    }
  }
  set_names = unique(c(
    set_names,
    unlist(lapply(set_expressions, sparse_expr_set_names), use.names = FALSE)
  ))
  for (update in spec$updates) {
    for (domain in update$domains) {
      set_names = c(set_names, domain$set)
      if (!is.null(domain$predicate)) {
        set_expressions[[length(set_expressions) + 1L]] = domain$predicate
      }
    }
    set_expressions[[length(set_expressions) + 1L]] = update$expression
  }
  set_names = unique(c(
    set_names, unlist(lapply(set_expressions, sparse_expr_set_names),
                      use.names = FALSE)))
  for (set_name in set_names) {
    values = sparse_find_set_values(data, set_name)
    sets[[set_name]] = list(
      name = set_name,
      values = values,
      positions = setNames(seq_along(values), values)
    )
  }

  variables = list()
  global_start = 1L
  for (id in seq_along(spec$variables)) {
    definition = spec$variables[[id]]
    set_names_for_var = vapply(definition$domains, function(x) x$set, "")
    lengths = if (length(set_names_for_var)) {
      vapply(set_names_for_var, function(s) length(sets[[s]]$values), integer(1))
    } else integer()
    n = if (length(lengths)) prod(lengths) else 1L
    variables[[id]] = c(
      definition,
      list(
        id = id,
        sets = set_names_for_var,
        lengths = lengths,
        n = as.integer(n),
        global_start = as.integer(global_start),
        global_end = as.integer(global_start + n - 1L)
      )
    )
    global_start = global_start + n
  }

  equations = list()
  equation_start = 1L
  for (id in seq_along(spec$equations)) {
    definition = spec$equations[[id]]
    set_names_for_eq = vapply(definition$domains, function(x) x$set, "")
    lengths = if (length(set_names_for_eq)) {
      vapply(set_names_for_eq, function(s) length(sets[[s]]$values), integer(1))
    } else integer()
    n = if (length(lengths)) prod(lengths) else 1L
    equations[[id]] = c(
      definition,
      list(
        id = id,
        sets = set_names_for_eq,
        lengths = lengths,
        n = as.integer(n),
        row_start = as.integer(equation_start),
        row_end = as.integer(equation_start + n - 1L)
      )
    )
    equation_start = equation_start + n
  }

  index = list(
    sets = sets,
    variables = variables,
    equations = equations,
    variable_by_name = spec$variable_by_name,
    equation_count = as.integer(equation_start - 1L),
    variable_count = as.integer(global_start - 1L),
    closure_names = character(),
    endogenous_count = as.integer(global_start - 1L),
    pattern_cache = NULL,
    column_order = NULL,
    row_layout_ready = FALSE
  )
  sparse_rebuild_columns(index, character())
}

sparse_rebuild_columns = function(index, closure_names) {
  closure_names = tolower(unique(as.character(closure_names)))
  unknown = setdiff(closure_names, names(index$variable_by_name))
  if (length(unknown)) {
    stop(sprintf("Unknown closure variable(s): %s",
                 paste(unknown, collapse = ", ")), call. = FALSE)
  }

  endo_start = 1L
  for (id in seq_along(index$variables)) {
    variable = index$variables[[id]]
    variable$exogenous = variable$name %in% closure_names
    if (variable$exogenous) {
      variable$endo_start = NA_integer_
    } else {
      variable$endo_start = as.integer(endo_start)
      endo_start = endo_start + variable$n
    }
    index$variables[[id]] = variable
  }
  index$closure_names = closure_names
  index$endogenous_count = as.integer(endo_start - 1L)
  index$pattern_cache = NULL
  index$column_order = NULL
  index$row_layout_ready = FALSE
  index
}

sparse_parse_label = function(label) {
  label = trimws(as.character(label))
  match = regexec("^([A-Za-z][A-Za-z0-9_.]*)\\[(.*)\\]$", label)
  parts = regmatches(label, match)[[1]]
  if (!length(parts)) {
    stop(sprintf("Shock name is not an indexed TABLO label: %s", label),
         call. = FALSE)
  }
  indices = trimws(strsplit(parts[[3]], ",", fixed = TRUE)[[1]])
  indices = gsub("^['\"]|['\"]$", "", indices)
  list(name = tolower(parts[[2]]), indices = indices)
}

sparse_position_for_label = function(label, set_name, index) {
  if (length(label) == 0L || is.na(label)) return(NA_integer_)
  set = index$sets[[tolower(set_name)]]
  if (!is.null(set$positions[[label]])) {
    return(as.integer(set$positions[[label]]))
  }
  numeric_label = suppressWarnings(as.integer(label))
  if (!is.na(numeric_label) && numeric_label >= 1L &&
      numeric_label <= length(set$values)) {
    return(numeric_label)
  }
  NA_integer_
}

sparse_ref_global_position = function(ref, bindings, index) {
  id = index$variable_by_name[[ref$name]]
  if (is.null(id)) {
    stop(sprintf("Unknown variable in sparse expression: %s", ref$name),
         call. = FALSE)
  }
  variable = index$variables[[id]]
  if (!length(variable$sets)) return(variable$global_start)
  if (length(ref$indices) != length(variable$sets)) {
    stop(sprintf("Variable %s expects %s indices, got %s",
                 ref$name, length(variable$sets), length(ref$indices)),
         call. = FALSE)
  }
  positions = integer(length(variable$sets))
  for (d in seq_along(variable$sets)) {
    expr = ref$indices[[d]]
    value = if (is.name(expr) && !is.null(bindings[[as.character(expr)]])) {
      bindings[[as.character(expr)]]
    } else if (is.character(expr) && length(expr) == 1L) {
      expr
    } else if (!is.language(expr) && length(expr) == 1L) {
      expr
    } else {
      sparse_eval_expr(expr, NULL, bindings, index)
    }
    source_set = if (is.name(expr)) {
      bindings[[paste0(".set:", as.character(expr))]]
    } else NULL
    target_set = variable$sets[[d]]
    if (!is.null(source_set) && !identical(source_set, target_set) &&
        !is.null(index$sets[[source_set]]) &&
        !is.null(index$sets[[target_set]]) &&
        is.numeric(value) && length(value) == 1L && !is.na(value) &&
        value >= 1L && value <= length(index$sets[[source_set]]$values)) {
      value = index$sets[[source_set]]$values[[as.integer(value)]]
    }
    if (is.numeric(value) && length(value) == 1L && !is.na(value)) {
      set = index$sets[[variable$sets[[d]]]]
      if (value >= 1 && value <= length(set$values) &&
          identical(as.numeric(value), as.numeric(as.integer(value)))) {
        positions[[d]] = as.integer(value)
      } else {
        positions[[d]] = sparse_position_for_label(as.character(value),
                                                   variable$sets[[d]], index)
      }
    } else {
      positions[[d]] = sparse_position_for_label(as.character(value),
                                                 variable$sets[[d]], index)
    }
    if (is.na(positions[[d]])) {
      stop(sprintf("Cannot resolve index %s of %s",
                   paste(deparse(expr), collapse = " "), ref$name),
           call. = FALSE)
    }
  }
  stride = 1L
  local = 1L
  for (d in seq_along(positions)) {
    local = local + (positions[[d]] - 1L) * stride
    stride = stride * variable$lengths[[d]]
  }
  as.integer(variable$global_start + local - 1L)
}

sparse_eval_expr = function(expr, state, bindings, index) {
  if (is.null(expr)) return(NA_real_)
  if (is.name(expr)) {
    name = as.character(expr)
    if (!is.null(bindings[[name]])) return(bindings[[name]])
    if (!is.null(state) && !is.null(sparse_state_data(state)[[tolower(name)]])) {
      return(sparse_state_data(state)[[tolower(name)]])
    }
    return(name)
  }
  if (!is.language(expr)) {
    if (is.name(expr)) expr = as.character(expr)
    if (is.character(expr) && length(expr) == 1L &&
        !is.null(bindings[[expr]])) return(bindings[[expr]])
    return(expr)
  }
  if (length(expr) == 0L) return(NA_real_)

  op = as.character(expr[[1]])
  builtin_ops = c(
    "[", "(", "setpos", "sum", "isin", "ifelse", "!",
    "+", "-", "*", "/", "^", "==", "!=", "<", ">",
    "<=", ">=", "&", "|", "exp", "loge", "log", "sqrt", "abs"
  )
  if (!(tolower(op) %in% builtin_ops) && !is.null(state) &&
      !is.null(sparse_state_data(state)[[tolower(op)]])) {
    ref = as.call(c(
      list(as.name("["), as.name(tolower(op))),
      as.list(expr)[-1L]
    ))
    return(sparse_eval_expr(ref, state, bindings, index))
  }
  if (op == "[") {
    ref = sparse_parse_ref(expr)
    array = if (is.null(state)) NULL else {
      if (is.environment(state)) state$data[[ref$name]] else state[[ref$name]]
    }
    if (is.null(array)) {
      stop(sprintf("Data array %s is missing", ref$name), call. = FALSE)
    }
    if (!length(ref$indices)) return(array)
    dims = dim(array)
    if (is.null(dims)) return(as.numeric(array))
    positions = integer(length(ref$indices))
    dim_names = dimnames(array)
    for (d in seq_along(ref$indices)) {
      item = ref$indices[[d]]
      value = if (is.name(item) && !is.null(bindings[[as.character(item)]])) {
        bindings[[as.character(item)]]
      } else if (is.character(item) && length(item) == 1L) {
        item
      } else if (!is.language(item) && length(item) == 1L) {
        item
      } else {
        sparse_eval_expr(item, state, bindings, index)
      }
      set_name = NULL
      if (length(index$sets)) {
        for (candidate in names(index$sets)) {
          if (!is.null(dim_names) && d <= length(dim_names) &&
              !is.null(dim_names[[d]]) &&
              any(as.character(dim_names[[d]]) == as.character(value))) {
            set_name = candidate
            break
          }
        }
      }
      if (is.numeric(value) && length(value) == 1L && !is.na(value) &&
          value == as.integer(value) && value >= 1 && value <= dims[[d]]) {
        positions[[d]] = as.integer(value)
      } else if (!is.null(dim_names) && d <= length(dim_names) &&
                 !is.null(dim_names[[d]])) {
        positions[[d]] = match(as.character(value), dim_names[[d]])
      } else if (!is.null(set_name)) {
        positions[[d]] = sparse_position_for_label(as.character(value),
                                                   set_name, index)
      } else {
        positions[[d]] = suppressWarnings(as.integer(value))
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
    return(as.numeric(array[[linear]]))
  }

  if (op == "setpos" && length(expr) >= 2L) {
    value = sparse_eval_expr(expr[[2]], state, bindings, index)
    source_name = bindings[[paste0(".set:", as.character(expr[[2]]))]]
    label = as.character(value)
    if (is.numeric(value) && length(value) == 1L &&
        !is.null(source_name) && !is.null(index$sets[[source_name]])) {
      source = index$sets[[source_name]]
      if (value >= 1L && value <= length(source$values)) {
        label = source$values[[as.integer(value)]]
      }
    }
    candidates = names(index$sets)
    if (!is.null(source_name)) {
      candidates = c(setdiff(candidates, source_name), source_name)
    }
    for (candidate in candidates) {
      candidate_values = index$sets[[candidate]]$values
      position = match(label, candidate_values)
      if (is.na(position) && grepl("\\.", label)) {
        position = match(sub("^[^.]*\\.", "", label), candidate_values)
      }
      if (!is.na(position)) return(as.numeric(position))
    }
    return(if (is.numeric(value)) as.numeric(value) else NA_real_)
  }
  if (op == "sum" && length(expr) >= 4L) {
    set_name = tolower(as.character(expr[[3]]))
    set = index$sets[[set_name]]
    if (is.null(set)) stop(sprintf("Unknown sum set %s", set_name),
                           call. = FALSE)
    total = 0
    for (position in seq_along(set$values)) {
      next_bindings = bindings
      next_bindings[[as.character(expr[[2]])]] = position
      value = sparse_eval_expr(expr[[4]], state, next_bindings, index)
      if (length(value) != 1L) value = sum(value)
      total = total + value
    }
    return(total)
  }
  if (op == "isin" && length(expr) >= 3L) {
    index_value = sparse_eval_expr(expr[[2]], state, bindings, index)
    set_name = tolower(as.character(expr[[3]]))
    set = index$sets[[set_name]]
    if (is.null(set)) stop(sprintf("Unknown membership set %s", set_name),
                           call. = FALSE)
    source_name = bindings[[paste0(".set:", as.character(expr[[2]]))]]
    if (is.numeric(index_value) && length(index_value) == 1L &&
        !is.null(source_name) && !is.null(index$sets[[source_name]])) {
      source_set = index$sets[[source_name]]
      if (index_value >= 1L && index_value <= length(source_set$values)) {
        index_value = source_set$values[[as.integer(index_value)]]
      }
    }
    return(as.character(index_value) %in% as.character(set$values))
  }

  if (op == "ifelse") {
    condition = sparse_eval_expr(expr[[2]], state, bindings, index)
    yes = sparse_eval_expr(expr[[3]], state, bindings, index)
    no = if (length(expr) >= 4L) sparse_eval_expr(
      expr[[4]], state, bindings, index
    ) else 0
    return(ifelse(condition, yes, no))
  }

  if (op == "!") return(!sparse_eval_expr(expr[[2]], state, bindings, index))

  if (op %in% c("+", "-", "*", "/", "^", "==", "!=", "<", ">",
                "<=", ">=", "&", "|")) {
    args = lapply(as.list(expr)[-1L], sparse_eval_expr,
                  state = state, bindings = bindings, index = index)
    if (op == "-" && length(args) == 1L) return(-args[[1]])
    if (op == "/" && length(args) == 2L) {
      return(ifelse(args[[2]] == 0, 0, args[[1]] / args[[2]]))
    }
    return(do.call(op, args))
  }

  if (op %in% c("exp", "loge", "log", "sqrt", "abs")) {
    value = sparse_eval_expr(expr[[2]], state, bindings, index)
    if (op == "loge") op = "log"
    return(get(op)(value))
  }

  stop(sprintf("Unsupported sparse expression operator: %s", op),
       call. = FALSE)
}

sparse_for_each_domain = function(domains, state, index, bindings = list(),
                                  callback, position = 1L) {
  if (position > length(domains)) {
    callback(bindings)
    return(invisible(NULL))
  }
  domain = domains[[position]]
  set = index$sets[[domain$set]]
  if (is.null(set)) stop(sprintf("Unknown domain set %s", domain$set),
                         call. = FALSE)
  for (value in seq_along(set$values)) {
    next_bindings = bindings
    next_bindings[[domain$index]] = value
    next_bindings[[paste0(".set:", domain$index)]] = domain$set
    valid = TRUE
    if (!is.null(domain$predicate)) {
      valid = isTRUE(as.logical(sparse_eval_expr(
        domain$predicate, state, next_bindings, index
      )))
    }
    if (valid) {
      sparse_for_each_domain(domains, state, index, next_bindings,
                             callback, position + 1L)
    }
  }
  invisible(NULL)
}

sparse_for_each_sum = function(sums, state, index, bindings, callback,
                               position = 1L) {
  if (position > length(sums)) {
    callback(bindings)
    return(invisible(NULL))
  }
  sum_spec = sums[[position]]
  set = index$sets[[sum_spec$set]]
  if (is.null(set)) stop(sprintf("Unknown sum set %s", sum_spec$set),
                         call. = FALSE)
  for (value in seq_along(set$values)) {
    next_bindings = bindings
    next_bindings[[sum_spec$index]] = value
    next_bindings[[paste0(".set:", sum_spec$index)]] = sum_spec$set
    sparse_for_each_sum(sums, state, index, next_bindings, callback,
                        position + 1L)
  }
  invisible(NULL)
}

sparse_build_row_layout = function(spec, index, state) {
  next_row = 1L
  for (id in seq_along(index$equations)) {
sparse_domain_count = function(domains, state, index) {
  if (!length(domains)) return(1L)
  simple = all(vapply(domains, function(domain) {
    is.null(domain$predicate)
  }, logical(1)))
  if (simple) {
    return(as.integer(prod(vapply(domains, function(domain) {
      length(index$sets[[domain$set]]$values)
    }, numeric(1)))))
  }
  count = 0L
  sparse_for_each_domain(
    domains, state, index,
    callback = function(bindings) count <<- count + 1L
  )
  count
}

    equation = index$equations[[id]]
    count = sparse_domain_count(equation$domains, state, index)
    equation$row_start = as.integer(next_row)
    equation$row_end = as.integer(next_row + count - 1L)
    equation$n = as.integer(count)
    index$equations[[id]] = equation
    next_row = next_row + count
  }
  index$equation_count = as.integer(next_row - 1L)
  index$row_layout_ready = TRUE
  index$pattern_cache = NULL
  index$column_order = NULL
  index
}

sparse_array_labels = function(array, base_name) {
  if (length(array) == 1L) return(sprintf("%s[]", base_name))
  dn = dimnames(array)
  if (is.null(dn)) return(sprintf("%s[%s]", base_name, seq_along(array)))
  if (length(dn) == 1L) return(sprintf("%s[%s]", base_name, dn[[1]]))
  combinations = expand.grid(dn, KEEP.OUT.ATTRS = FALSE,
                              stringsAsFactors = FALSE)
  labels = apply(combinations, 1L, function(row) {
    sprintf("%s[%s]", base_name,
            paste(sprintf("\"%s\"", row), collapse = ","))
  })
  as.character(labels)
}

sparse_materialize_labels = function(state, index, equations = TRUE,
                                     variables = TRUE) {
  data = if (is.environment(state)) state$data else state
  if (variables) {
    variable_labels = unlist(lapply(index$variables, function(variable) {
      sparse_array_labels(data[[variable$name]], variable$name)
    }), use.names = FALSE)
    data$variables = variable_labels
    numbers = seq_along(variable_labels)
    names(numbers) = variable_labels
    data$variableNumbers = numbers
  }
  if (equations) {
    equation_labels = unlist(lapply(index$equations, function(equation) {
      if (!length(equation$domains)) return(sprintf("%s[]", equation$name))
      domains = lapply(equation$domains, function(domain) {
        index$sets[[domain$set]]$values
      })
      combinations = expand.grid(domains, KEEP.OUT.ATTRS = FALSE,
                                 stringsAsFactors = FALSE)
      apply(combinations, 1L, function(row) {
        sprintf("%s[%s]", equation$name,
                paste(sprintf("\"%s\"", row), collapse = ","))
      })
    }), use.names = FALSE)
    data$equations = equation_labels
    numbers = seq_along(equation_labels)
    names(numbers) = equation_labels
    data$equationNumbers = numbers
  }
  data
}

sparse_estimate_index_bytes = function(index) {
  variable_bytes = sum(vapply(index$variables, function(v) 8 * v$n,
                              numeric(1)))
  equation_bytes = 8 * index$equation_count
  list(
    variable_storage = variable_bytes,
    equation_storage = equation_bytes,
    metadata = as.numeric(object.size(index))
  )
}

sparse_pattern_key = function(index) {
  paste(
    vapply(index$sets, function(set) paste(set$values, collapse = "\u001f"),
           character(1)),
    paste(index$closure_names, collapse = ","),
    paste(index$equation_count, index$endogenous_count, sep = ":"),
    sep = "|"
  )
}

sparse_invalidate_pattern = function(index) {
  index$pattern_cache = NULL
  index
}
