.tablo_finite_update = function(value, name) {
  if (!is.numeric(value) || any(!is.finite(value))) {
    stop(sprintf("TABLO UPDATE of %s produced a non-finite or non-numeric value",
                 name), call. = FALSE)
  }
  value
}

generateUpdates = function(statements) {
  formula_block = quote({})
  post_block = quote({})
  post_fields = character()
  update_block = quote({})
  targets = character()
  for (s in statements) {
    if (s$class == "update") {
      formula = correctFormula(s$parsed$equation)
      name = sparse_parse_ref(formula[[2L]])$name
      targets = union(targets, name)
      target = call("$", as.name(".tablo_pending"), as.name(name))
      update_block[[length(update_block) + 1L]] =
        str2lang(processUpdateStatement(s, target))
    } else if (s$class == "assertion") {
      assertion = .compile_tablo_assertion(s)
      if (assertion$postsim) {
        post_block[[length(post_block) + 1L]] = bquote(
          if (.tablo_check_post_assertions) .check_tablo_assertions(
            list(.(assertion)), as.list(environment(), all.names = TRUE),
            phase = "postsim"
          )
        )
      } else if (!assertion$initial) {
        formula_block[[length(formula_block) + 1L]] = bquote(
          .check_tablo_assertions(
            list(.(assertion)), as.list(environment(), all.names = TRUE)
          )
        )
      }
    } else if (isTRUE(s$postsim)) {
      if (s$class == "formula") {
        expression = str2lang(processFormulaStatement(s))
        target = sparse_parse_ref(correctFormula(s$parsed$equation)[[2L]])$name
      } else {
        expression = .tablo_postsim_structure(s)
        if (is.null(expression)) next
        target = as.character(expression[[2L]])
      }
      post_fields = union(post_fields, target)
      post_block[[length(post_block) + 1L]] = expression
    } else if (isTRUE(s$step_reload)) {
      previous = quote(.tablo_previous_levels)
      formula_block[[length(formula_block) + 1L]] = if (s$class == "read") {
        processReadStatement(s, previous)
      } else {
        str2lang(processFormulaStatement(s, previous))
      }
    } else if (!.tablo_formula_is_initial(s)) {
      formula_block[[length(formula_block) + 1L]] =
        str2lang(processFormulaStatement(s))
    }
  }

  function(data, phase = "all", check_assertions = TRUE) {
    if (phase %in% c("all", "formula") && length(formula_block) > 1L) {
      .tablo_previous_levels = data
      data = eval(call("within", quote(data), formula_block))
    }
    if (phase %in% c("all", "update") && length(targets)) {
      # The generated assignments write into .tablo_pending and read the
      # original coefficient bindings throughout the update pass.
      bindings = list2env(data, parent = environment(generateUpdates))
      bindings$.tablo_pending = data[targets]
      eval(update_block, bindings)
      data[targets] = bindings$.tablo_pending
    }
    if (phase == "postsim" && length(post_block) > 1L) {
      .tablo_check_post_assertions = check_assertions
      result = eval(call("within", quote(data), post_block))
      fields = intersect(post_fields, names(result))
      data[fields] = result[fields]
    }
    data
  }
}

.tablo_updated_coefficients = function(spec) {
  unique(vapply(spec$coefficient_updates, function(update) {
    update$target$name
  }, ""))
}

.tablo_euler_weights = function(steps) {
  steps = as.numeric(steps)
  # Lagrange interpolation at step size zero, with step sizes 1 / steps.
  vapply(seq_along(steps), function(i) {
    prod(steps[[i]] / (steps[[i]] - steps[-i]))
  }, numeric(1))
}

.tablo_add_euler_coefficients = function(accumulator, current, weight) {
  if (is.null(accumulator)) return(list(anchor = current, differences = list()))
  for (name in names(current)) {
    # Center on a completed trajectory. Subtracting the original level can
    # erase small final levels when all trajectories move far from it.
    anchor = accumulator$anchor[[name]]
    weighted = (current[[name]] - anchor) * weight
    previous = accumulator$differences[[name]]
    accumulator$differences[[name]] =
      if (is.null(previous)) weighted else previous + weighted
  }
  accumulator
}

.tablo_finish_euler_coefficients = function(accumulator, original) {
  result = accumulator$anchor
  for (name in names(result)) {
    value = result[[name]] + accumulator$differences[[name]]
    reference = original[[name]]
    missing = !is.finite(reference)
    if (any(is.infinite(value)) || any(is.na(value) & !missing)) {
      stop(sprintf("TABLO extrapolation produced a non-finite value for %s",
                   name), call. = FALSE)
    }
    retain = is.na(value) & missing
    value[retain] = reference[retain]
    result[[name]] = value
  }
  result
}
