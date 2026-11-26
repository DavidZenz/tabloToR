.parse_header_read = function(statement) {
  pattern = paste0(
    "^([a-z][a-z0-9_.]*)(\\s*\\([^)]*\\))?\\s+from\\s+file\\s+",
    "([a-z][a-z0-9_.]*)\\s+header\\s+\"([^\"]+)\""
  )
  command = trimws(statement$parsed$equation)
  parts = regmatches(command, regexec(pattern, command, perl = TRUE))[[1L]]
  if (!length(parts)) return(NULL)
  qualifiers = trimws(unlist(statement$parsed$elements, use.names = FALSE))
  optional = grepl("^\\(\\s*ifheaderexists\\s*\\)$", qualifiers)
  domains = lapply(qualifiers[!optional], sparse_parse_qualifier)
  indices = if (nzchar(parts[[3L]])) {
    as.list(str2lang(paste0(parts[[2L]], parts[[3L]])))[-1L]
  } else list()
  list(optional = any(optional), target = parts[[2L]], file = parts[[4L]],
       header = parts[[5L]], indices = indices, domains = domains)
}

.tablo_shared_axis_names = function(source, target) {
  setdiff(intersect(source, target), c("", NA_character_,
    source[duplicated(source)], target[duplicated(target)]))
}

.tablo_header_values = function(target, values, coefficient, file, header) {
  context = sprintf('READ %s from file %s header "%s"', coefficient, file, header)
  if (is.null(values)) {
    stop(sprintf("%s is missing", context), call. = FALSE)
  }
  if (length(values) != length(target)) {
    stop(sprintf("%s has %s values, expected %s",
                 context, length(values), length(target)), call. = FALSE)
  }

  target_dims = dim(target)
  value_dims = dim(values)
  if (is.null(value_dims) && length(target_dims) == 1L &&
      !is.null(names(values))) {
    source_names = names(values)
    value_dims = target_dims
    dim(values) = value_dims
    dimnames(values) = list(source_names)
  }
  if (is.null(value_dims)) return(values)

  rank = max(length(target_dims), length(value_dims))
  pad = function(dims) c(dims, rep.int(1L, rank - length(dims)))
  aligned = identical(pad(target_dims), pad(value_dims))
  target_axes = seq_along(target_dims)
  value_axes = seq_along(value_dims)
  if (!aligned) {
    target_axes = which(target_dims != 1L)
    value_axes = which(value_dims != 1L)
  }
  if (!identical(as.integer(target_dims[target_axes]),
                 as.integer(value_dims[value_axes])) &&
      !aligned) {
    stop(sprintf("%s has dimensions %s, expected %s", context,
                 paste(value_dims, collapse = " x "),
                 paste(target_dims, collapse = " x ")), call. = FALSE)
  }

  orders = lapply(value_dims, seq_len)
  source_labels = dimnames(values)
  target_labels = dimnames(target)
  reorder = FALSE
  common_rank = min(length(target_axes), length(value_axes))
  common_axes = seq_len(common_rank)
  value_axes = value_axes[common_axes]
  target_axes = target_axes[common_axes]
  all_source_names = tolower(names(source_labels))
  all_expected_names = tolower(names(target_labels))
  source_names = all_source_names[value_axes]
  expected_names = all_expected_names[target_axes]
  # Each unambiguous set name identifies its axis, even when some other
  # names are absent or differ from the TABLO declarations.
  shared_names = .tablo_shared_axis_names(source_names, expected_names)
  if (any(match(shared_names, source_names) !=
          match(shared_names, expected_names))) {
    stop(sprintf("%s has named dimensions in the wrong order (%s, expected %s)",
                 context, paste(source_names, collapse = ", "),
                 paste(expected_names, collapse = ", ")), call. = FALSE)
  }
  # Singleton axes may move or be omitted when matching shapes. Named axes
  # present in both arrays still provide an element label to check.
  shared = .tablo_shared_axis_names(all_source_names, all_expected_names)
  source_singletons = match(shared, all_source_names)
  target_singletons = match(shared, all_expected_names)
  paired_targets = target_axes[match(source_singletons, value_axes)]
  keep = value_dims[source_singletons] == 1L &
    target_dims[target_singletons] == 1L &
    (is.na(paired_targets) | paired_targets != target_singletons)
  value_axes = c(value_axes, source_singletons[keep])
  target_axes = c(target_axes, target_singletons[keep])
  for (axis in seq_along(value_axes)) {
    if (is.null(source_labels) || is.null(target_labels)) break
    source = source_labels[[value_axes[[axis]]]]
    expected = target_labels[[target_axes[[axis]]]]
    if (is.null(source) || is.null(expected)) next
    source = tolower(source)
    expected = tolower(expected)
    positions = match(expected, source)
    if (anyNA(source) || anyNA(positions) || anyDuplicated(source) ||
        anyDuplicated(positions)) {
      stop(sprintf("%s has incompatible labels on dimension %s",
                   context, target_axes[[axis]]), call. = FALSE)
    }
    orders[[value_axes[[axis]]]] = positions
    reorder = reorder || !identical(positions, seq_along(positions))
  }
  if (reorder) return(do.call("[", c(list(values), orders, list(drop = FALSE))))
  values
}

.tablo_read_coefficient = function(target, read, bindings, previous = NULL) {
  input = get0(read$file, envir = bindings, inherits = FALSE)
  values = input[[read$header]]
  if (read$optional && is.null(values)) return(target)

  selection = target
  if (is.null(dim(selection)) && !is.null(names(selection))) {
    # Legacy one-dimensional assignments can leave a named vector.
    selection = array(as.vector(selection), length(selection),
                      list(names(selection)))
  }
  positions = list()
  if (length(read$indices)) {
    dims = dim(selection)
    labels = dimnames(selection)
    domain_names = vapply(read$domains, function(domain) domain$index, "")
    indices = vapply(read$indices, function(index) {
      if (is.name(index)) as.character(index) else ""
    }, "")
    domain_ids = match(indices, domain_names)
    if (length(indices) != length(dims) ||
        !setequal(domain_ids[!is.na(domain_ids)], seq_along(read$domains)) ||
        anyDuplicated(domain_ids[!is.na(domain_ids)])) {
      stop(sprintf("READ %s has invalid slice indices", read$target),
           call. = FALSE)
    }
    slice_axes = which(!is.na(domain_ids))
    slice_sets = character(length(slice_axes))
    for (axis in seq_along(indices)) {
      item = read$indices[[axis]]
      domain_id = domain_ids[[axis]]
      if (!is.na(domain_id)) {
        domain = read$domains[[domain_id]]
        set = get0(domain$set, envir = bindings, inherits = FALSE)
        if (is.null(set) || !is.null(domain$predicate)) {
          stop(sprintf("READ %s has an invalid quantifier for %s",
                       read$target, domain$index), call. = FALSE)
        }
        slice_sets[match(axis, slice_axes)] = domain$set
        positions[[axis]] = match(as.character(set), labels[[axis]])
      } else if (is.character(item) && length(item) == 1L) {
        positions[[axis]] = match(item, labels[[axis]])
      } else if (is.numeric(item) && length(item) == 1L &&
                 item %in% seq_len(dims[[axis]])) {
        positions[[axis]] = as.integer(item)
      } else {
        positions[[axis]] = NA_integer_
      }
      if (anyNA(positions[[axis]])) {
        stop(sprintf("READ %s cannot resolve slice index on dimension %s",
                     read$target, axis), call. = FALSE)
      }
    }
    selection = do.call("[", c(list(selection), positions, list(drop = FALSE)))
    if (length(slice_axes)) {
      dimnames(selection) = NULL
      dim(selection) = lengths(positions)[slice_axes]
      dimnames(selection) = setNames(
        lapply(slice_axes, function(axis) labels[[axis]][positions[[axis]]]),
        slice_sets
      )
    } else {
      selection = as.vector(selection)
    }
  } else if (length(read$domains)) {
    stop(sprintf("READ %s has quantifiers without slice indices", read$target),
         call. = FALSE)
  }

  if (is.null(previous)) {
    values = .tablo_header_values(selection, values, read$target,
                                 read$file, read$header)
  } else if (length(positions)) {
    values = do.call("[", c(list(previous), positions, list(drop = FALSE)))
  } else {
    values = previous
  }
  if (length(positions)) {
    return(do.call("[<-", c(list(target), positions, list(value = values))))
  }
  target[] = values
  target
}

processReadStatement = function(s, previous_levels = NULL) {
  read = .parse_header_read(s)
  if (is.null(read)) return(NULL)
  target = as.name(read$target)
  expression = call(".tablo_read_coefficient", target, read, quote(environment()))
  if (!is.null(previous_levels)) {
    expression[[5L]] = call("[[", previous_levels, read$target)
  }
  call("=", target, expression)
}

.tablo_mark_step_reloads = function(statements) {
  formula_targets = character()
  for (id in seq_along(statements)) {
    statement = statements[[id]]
    if (isTRUE(statement$postsim) ||
        !statement$class %in% c("formula", "read")) next
    if (statement$class == "formula") {
      target = sub("^([a-z][a-z0-9_.]*).*$", "\\1", statement$parsed$equation)
      if (!.tablo_formula_is_initial(statement)) {
        formula_targets = union(formula_targets, target)
        next
      }
    } else {
      target = .parse_header_read(statement)$target
    }
    statements[[id]]$step_reload = length(target) && target %in% formula_targets
  }
  statements
}

.mark_optional_read_defaults = function(statements) {
  formulas = list()
  # A preceding formula can provide the fallback during data loading.
  for (id in seq_along(statements)) {
    statement = statements[[id]]
    if (isTRUE(statement$postsim)) next
    if (statement$class == "formula" &&
        !("always" %in% .tablo_qualifiers(statement))) {
      expression = trimws(statement$parsed$equation)
      target = regmatches(expression, regexpr("^[a-z][a-z0-9_.]*", expression))
      if (length(target)) formulas[[target]] = c(formulas[[target]], id)
    }
    if (statement$class == "read") {
      read = .parse_header_read(statement)
      if (isTRUE(read$optional) && length(formulas[[read$target]])) {
        for (formula_id in formulas[[read$target]]) {
          statements[[formula_id]]$read_default = TRUE
        }
      }
    }
  }

  statements
}
