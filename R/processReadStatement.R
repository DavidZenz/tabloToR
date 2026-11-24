.parse_header_read = function(statement) {
  pattern = paste0(
    "^\\s*(\\(\\s*ifheaderexists\\s*\\)\\s*)?",
    "([a-z][a-z0-9_.]*)\\s+from\\s+file\\s+([a-z][a-z0-9_.]*)",
    "\\s+header\\s+\"([^\"]+)\""
  )
  parts = regmatches(statement$command,
                     regexec(pattern, statement$command, perl = TRUE))[[1L]]
  if (!length(parts)) return(NULL)
  list(optional = nzchar(parts[[2L]]), target = parts[[3L]],
       file = parts[[4L]], header = parts[[5L]])
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
  if (!identical(pad(target_dims), pad(value_dims))) {
    stop(sprintf("%s has dimensions %s, expected %s", context,
                 paste(value_dims, collapse = " x "),
                 paste(target_dims, collapse = " x ")), call. = FALSE)
  }

  orders = lapply(value_dims, seq_len)
  source_labels = dimnames(values)
  target_labels = dimnames(target)
  reorder = FALSE
  for (axis in seq_len(min(length(source_labels), length(target_labels)))) {
    source = source_labels[[axis]]
    expected = target_labels[[axis]]
    if (is.null(source) || is.null(expected)) next
    source = tolower(source)
    expected = tolower(expected)
    positions = match(expected, source)
    if (anyNA(source) || anyNA(positions) || anyDuplicated(source) ||
        anyDuplicated(positions)) {
      stop(sprintf("%s has incompatible labels on dimension %s",
                   context, axis), call. = FALSE)
    }
    orders[[axis]] = positions
    reorder = reorder || !identical(positions, seq_along(positions))
  }
  if (reorder) return(do.call("[", c(list(values), orders, list(drop = FALSE))))
  values
}

processReadStatement = function(s) {
  read = .parse_header_read(s)
  if (is.null(read)) return(NULL)

  value = sprintf("%s[[%s]]", read$file, encodeString(read$header, quote = '"'))
  assignment = sprintf(
    "%s[] = .tablo_header_values(%s, %s, %s, %s, %s)",
    read$target, read$target, value,
    encodeString(read$target, quote = '"'), encodeString(read$file, quote = '"'),
    encodeString(read$header, quote = '"')
  )
  if (read$optional) {
    return(sprintf(
      'if (exists("%s", inherits = FALSE) && !is.null(%s)) %s',
      read$file, value, assignment
    ))
  }
  assignment
}

.mark_optional_read_defaults = function(statements) {
  formulas = list()
  # A formula before an optional read provides the initial fallback. Run
  # reads of that coefficient in the same order as its initialization formulas.
  replay_targets = character()
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
        replay_targets = union(replay_targets, read$target)
      }
    }
  }

  if (!length(replay_targets)) return(statements)
  for (id in seq_along(statements)) {
    if (statements[[id]]$class != "read") next
    read = .parse_header_read(statements[[id]])
    if (!is.null(read) && read$target %in% replay_targets) {
      statements[[id]]$initialize_read = TRUE
    }
  }
  statements
}
