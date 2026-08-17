processSetStatement = function(s) {
  # SET READ
  if (grepl(".* maximum size .* read elements from file .* header \"*\"",
            s$command)) {
    words = strsplit(s$command, " ")[[1]]
    #toRet[[words[1]]] = files[[words[9]]][[gsub("\"", "", words[11])]]
    toRet = sprintf('%s=%s$%s', words[[1]], words[[9]], gsub("\"", "", words[11]))
  }
  else if (grepl(".* read elements from file .* header \"*\"",
            s$command)) {
    words = strsplit(s$command, " ")[[1]]
    #toRet[[words[1]]] = files[[words[9]]][[gsub("\"", "", words[11])]]
    toRet = sprintf('%s=%s$%s', words[[1]], words[[6]], gsub("\"", "", words[8]))
  }
  # SET DIFFERENCE
  else if (grepl(".* = .* - .*", s$command)) {
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

    preCommand[[3]][[3]] = removeFunctions(preCommand[[3]][[3]])

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

    #toRet[[trimws(substr(s$command, 1, from - 1))]] = elements
    toRet = sprintf('%s=c(%s)',
                    trimws(substr(s$command, 1, from - 1)),
                    paste('"', elements, '"', sep = '', collapse = ','))
  }

  return(toRet)
}
