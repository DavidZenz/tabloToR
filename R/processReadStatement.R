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

processReadStatement = function(s) {
  read = .parse_header_read(s)
  if (is.null(read)) return(NULL)

  value = sprintf("%s[[%s]]", read$file, encodeString(read$header, quote = '"'))
  assignment = sprintf("%s[] = %s", read$target, value)
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
