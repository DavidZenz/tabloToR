.tablo_read_set = function(set, file, header, bindings) {
  values = get0(file, envir = bindings, inherits = FALSE)[[header]]
  if (is.null(values)) {
    stop(sprintf('SET %s from file %s header "%s" is missing',
                 set, file, header), call. = FALSE)
  }
  .tablo_unique_set_members(values, set)
}

.tablo_unique_set_members = function(values, set) {
  labels = tolower(as.character(values))
  duplicates = unique(labels[duplicated(labels)])
  if (length(duplicates)) {
    stop(sprintf("SET %s has duplicate members: %s", set,
                 paste(duplicates, collapse = ", ")), call. = FALSE)
  }
  values
}

.tablo_expand_set_range = function(element) {
  quoted = grepl('^"[^"]*"$', element)
  if (quoted) return(substr(element, 2L, nchar(element) - 1L))
  pattern = "^([a-z0-9_.]*?)([0-9]+)\\s*-\\s*([a-z0-9_.]*?)([0-9]+)$"
  range = regmatches(element, regexec(pattern, element, perl = TRUE))[[1L]]
  if (!length(range) || range[[2L]] != range[[4L]]) return(element)
  first = suppressWarnings(as.integer(range[[3L]]))
  last = suppressWarnings(as.integer(range[[5L]]))
  if (is.na(first) || is.na(last) || first > last) {
    stop(sprintf("Invalid TABLO set range %s", element), call. = FALSE)
  }
  paste0(range[[2L]], sprintf("%0*d", nchar(range[[3L]]), seq.int(first, last)))
}

processSetStatement = function(s) {
  pattern = paste0(
    "^([a-z][a-z0-9_.]*)\\s+(?:maximum\\s+size\\s+[0-9]+\\s+)?",
    "read\\s+elements\\s+from\\s+file\\s+([a-z][a-z0-9_.]*)\\s+",
    "header\\s+\"([^\"]+)\""
  )
  read = regmatches(s$command, regexec(pattern, s$command, perl = TRUE))[[1L]]
  if (length(read)) {
    target = as.name(read[[2L]])
    return(call("=", target, call(".tablo_read_set", read[[2L]], read[[3L]],
                                 read[[4L]], quote(environment()))))
  }
  conditional = regexec("^([a-z][a-z0-9_.]*)\\s*=\\s*(\\(\\s*all\\s*,.*\\))$",
                        s$command, perl = TRUE)
  conditional = regmatches(s$command, conditional)[[1L]]
  if (length(conditional)) {
    name = conditional[[2L]]
    domain = sparse_parse_qualifier(conditional[[3L]])
    label = as.name(domain$index)
    set = as.name(domain$set)
    predicate = correctFormula(domain$predicate, preserve_assignment = FALSE)
    predicate = sumToMap(predicate, setNames(list(set), domain$index))
    predicate = call(".tablo_condition", predicate, paste("Set", name))
    select = as.call(list(as.name("function"), as.pairlist(setNames(
      list(quote(expr = )), as.character(label)
    )), predicate))
    return(call("=", as.name(name), call("[", set, call("vapply", set, select, FALSE))))
  }
  # SET DIFFERENCE
  if (grepl(".* = .* - .*", s$command)) {
    command = str2lang(s$command)
    command[[3]][[1]] = as.name('setdiff')
    #toRet[[deparse(command[[2]])]] = eval(command[[3]], toRet)
    toRet = sprintf('%s=%s', deparse1(command[[2]]), deparse1(command[[3]]))
  }
  # SET UNION
  else if (grepl(".* = .* union .*", s$command)) {
    command = str2lang(gsub('union', '+', s$command))
    command[[3]][[1]] = as.name('union')
    #toRet[[deparse(command[[2]])]] = eval(command[[3]], toRet)
    toRet = sprintf('%s=%s', deparse1(command[[2]]), deparse1(command[[3]]))
  }
  else if (grepl(".* = .* \\+ .*", s$command)) {
    lhs = trimws(sub("=.*$", "", s$command))
    rhs = trimws(sub("^[^=]*=", "", s$command))
    parts = trimws(strsplit(rhs, "\\+")[[1]])
    expression = parts[[1]]
    if (length(parts) > 1L) {
      for (part in parts[-1L]) {
        expression = sprintf("union(%s,%s)", expression, part)
      }
    }
    toRet = sprintf("%s=%s", lhs, expression)
  }
  else if (grepl(".* = .* [xX] .*", s$command)) {
    rhs = sub("^[^=]*=\\s*", "", s$command)
    parts = strsplit(rhs, "\\s+[xX]\\s+")[[1]]
    toRet = sprintf("%s=as.vector(outer(%s,%s,paste,sep='.'))",
                    trimws(sub("=.*$", "", s$command)),
                    trimws(parts[[1]]), trimws(parts[[2]]))
  }
  # SET INTERSECTION
  else if (grepl(".* = .* intersect .*", s$command)) {
    command = str2lang(gsub('intersect', '+', s$command))
    command[[3]][[1]] = as.name('intersect')
    #toRet[[deparse(command[[2]])]] = eval(command[[3]], toRet)
    toRet = sprintf('%s=%s', deparse1(command[[2]]), deparse1(command[[3]]))
  }
  # SET SPECIFIED
  else if (grepl(".*\\(.*\\)", s$command)) {
    from = regexpr('\\(', s$command)
    to = regexpr('\\)', s$command)
    elements = trimws(strsplit(substr(s$command, from + 1, to - 1), ',')[[1]])

    set_name = as.name(trimws(substr(s$command, 1, from - 1)))
    elements = unlist(lapply(elements, .tablo_expand_set_range),
                      use.names = FALSE)
    toRet = call("=", set_name,
                 call(".tablo_unique_set_members", elements, as.character(set_name)))
  }

  return(toRet)
}
