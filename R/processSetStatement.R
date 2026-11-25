.tablo_read_set = function(set, file, header, bindings) {
  values = get0(file, envir = bindings, inherits = FALSE)[[header]]
  if (is.null(values)) {
    stop(sprintf('SET %s from file %s header "%s" is missing',
                 set, file, header), call. = FALSE)
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
  # SET FORMULA
  else if (grepl(".* = \\(all,.*,.*\\)", s$command)) {
    command = normalizeTabloExpression(s$command)
    command = sub("=", "==", command, fixed = TRUE)
    preCommand = str2lang(gsub(":", ",", gsub("\\(all,", "all(", command)))

    setName = deparse1(preCommand[[3]][[3]])
    standIn = deparse1(preCommand[[3]][[2]])
    preCommand[[3]][[4]] = str2lang(gsub(
      paste0('\\b', standIn, '\\b'),
      setName ,
      deparse1(preCommand[[3]][[4]])
    ))

    preCommand[[3]][[1]] = as.name('[')
    preCommand[[3]][[2]] = NULL

    preCommand[[3]][[3]] = call(
      ".tablo_condition", removeFunctions(preCommand[[3]][[3]]),
      paste("Set", deparse1(preCommand[[2L]]))
    )

    #toRet[[deparse(preCommand[[2]])]] = eval(preCommand[[3]], toRet)
    toRet = sprintf('%s=%s', deparse1(preCommand[[2]]), deparse1(preCommand[[3]]))
    #eval(str2lang('SLUG[ENDW_COMM]'), toRet)
    #eval(quote(SLUG[ENDW_COMM]),toRet)
  }
  # SET SPECIFIED
  else if (grepl(".*\\(.*\\)", s$command)) {
    from = regexpr('\\(', s$command)
    to = regexpr('\\)', s$command)
    elements = trimws(strsplit(substr(s$command, from + 1, to - 1), ',')[[1]])

    set_name = as.name(trimws(substr(s$command, 1, from - 1)))
    elements = unlist(lapply(elements, .tablo_expand_set_range),
                      use.names = FALSE)
    toRet = call("=", set_name, elements)
  }

  return(toRet)
}
