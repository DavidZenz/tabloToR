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
      post_block[[length(post_block) + 1L]] = bquote(.check_tablo_assertions(
        list(.(assertion)), as.list(environment(), all.names = TRUE),
        phase = "postsim"
      ))
    } else if (isTRUE(s$postsim)) {
      post_block[[length(post_block) + 1L]] =
        str2lang(processFormulaStatement(s))
    } else if (!.tablo_formula_is_initial(s)) {
      formula_block[[length(formula_block) + 1L]] =
        str2lang(processFormulaStatement(s))
    }
  }

  function(data, phase = "all") {
    if (phase %in% c("all", "formula") && length(formula_block) > 1L) {
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
      data = eval(call("within", quote(data), post_block))
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

.tablo_add_euler_coefficients = function(accumulator, current, original, weight) {
  for (name in names(current)) {
    value = current[[name]]
    reference = original[[name]]
    # Extrapolate changes to keep unchanged coefficients exact.
    missing = !is.finite(reference)
    if (any(missing)) {
      value[missing & !is.finite(value)] = NA_real_
      reference[missing] = 0
    }
    weighted = (value - reference) * weight
    previous = accumulator[[name]]
    accumulator[[name]] = if (is.null(previous)) weighted else previous + weighted
  }
  accumulator
}

.tablo_finish_euler_coefficients = function(result, original) {
  for (name in names(result)) {
    value = result[[name]]
    reference = original[[name]]
    missing = !is.finite(reference)
    value[!missing] = value[!missing] + reference[!missing]
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
