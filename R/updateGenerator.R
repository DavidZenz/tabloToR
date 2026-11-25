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
