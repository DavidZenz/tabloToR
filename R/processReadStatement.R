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
  source_names = tolower(names(source_labels)[value_axes])
  expected_names = tolower(names(target_labels)[target_axes])
  shared_names = intersect(source_names, expected_names)
  # A pair of recognized set names out of order distinguishes switched
  # axes even when the sets have identical element labels.
  shared_names = setdiff(shared_names, c("", NA_character_,
    source_names[duplicated(source_names)],
    expected_names[duplicated(expected_names)]))
  if (length(shared_names) > 1L &&
      !identical(source_names[source_names %in% shared_names],
                 expected_names[expected_names %in% shared_names])) {
    stop(sprintf("%s has named dimensions in the wrong order (%s, expected %s)",
                 context, paste(source_names, collapse = ", "),
                 paste(expected_names, collapse = ", ")), call. = FALSE)
  }
  for (axis in seq_len(common_rank)) {
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
                   context, axis), call. = FALSE)
    }
    orders[[value_axes[[axis]]]] = positions
    reorder = reorder || !identical(positions, seq_along(positions))
  }
  if (reorder) return(do.call("[", c(list(values), orders, list(drop = FALSE))))
  values
}

.tablo_read_coefficient = function(target, read, bindings) {
  input = get0(read$file, envir = bindings, inherits = FALSE)
  values = input[[read$header]]
  if (read$optional && is.null(values)) return(target)

  selection = target
  positions = list()
  if (length(read$indices)) {
    dims = dim(target)
    labels = dimnames(target)
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
    selection = do.call("[", c(list(target), positions, list(drop = FALSE)))
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

  values = .tablo_header_values(selection, values, read$target,
                               read$file, read$header)
  if (length(positions)) {
    return(do.call("[<-", c(list(target), positions, list(value = values))))
  }
  target[] = values
  target
}

processReadStatement = function(s) {
  read = .parse_header_read(s)
  if (is.null(read)) return(NULL)
  target = as.name(read$target)
  call("=", target, call(".tablo_read_coefficient", target, read,
                          quote(environment())))
}

.mark_optional_read_defaults = function(statements) {
  formulas = list()
  # A formula before an optional read provides the initial fallback.
  for (id in seq_along(statements)) {
    statement = statements[[id]]
    if (statement$class == "formula" &&
        !any(grepl("^\\(\\s*always\\s*\\)$", statement$parsed$elements))) {
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
