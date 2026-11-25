removeFunctions = function(exp) {
  return(str2lang(gsub('\\)', ']', gsub(
    '\\(', '[', deparse1(exp)
  ))))
}
correctFormula = function(formulaText, preserve_assignment = TRUE) {

  #formulaText = str2lang(gsub('\\]', ')', gsub('\\[', '(', deparse(gsub(":", "%:%", gsub("\\(all,", "all(", gsub('>==','>=',gsub('<==','<=',gsub('=','==',formulaText)))))))))
  formulaText = normalizeTabloExpression(if (is.character(formulaText)) paste(formulaText, collapse = " ") else deparse1(formulaText))
  assignment_match = regexec("^\\s*([^=]+?)\\s*=\\s*(.*)$", formulaText,
                             perl = TRUE)
  assignment_match = regmatches(formulaText, assignment_match)[[1]]
  if (isTRUE(preserve_assignment) && length(assignment_match)) {
    rhs = gsub("(?<![<>=!])=(?!=)", "==", assignment_match[[3]],
               perl = TRUE)
    formulaText = paste0(assignment_match[[2]], " = ", rhs)
  } else {
    formulaText = gsub("(?<![<>=!])=(?!=)", "==", formulaText,
                       perl = TRUE)
  }
  formulaText = gsub("\\]", ")", gsub("\\[", "(", formulaText))
  exp = normalizeIfCalls(.normalize_tablo_filtered_sums(str2lang(formulaText)))
  return(functionToData(exp))
}

.tablo_sum_filter = function(domain) {
  if (!is.call(domain) || length(domain) < 2L) return(NULL)
  if (identical(domain[[1L]], as.name(":")) && is.name(domain[[2L]])) {
    return(list(set = domain[[2L]], condition = domain[[3L]]))
  }
  # R binds the colon more tightly than a comparison. Retain the remaining
  # operators when the set/condition separator is on their left operand.
  filter = .tablo_sum_filter(domain[[2L]])
  if (is.null(filter)) return(NULL)
  domain[[2L]] = filter$condition
  filter$condition = domain
  filter
}

.normalize_tablo_filtered_sums = function(expression) {
  if (!is.call(expression)) return(expression)
  if (identical(expression[[1L]], as.name("sum")) && length(expression) == 4L) {
    filter = .tablo_sum_filter(expression[[3L]])
    if (!is.null(filter)) {
      expression[[3L]] = filter$set
      expression[[4L]] = call("ifelse", filter$condition, expression[[4L]], 0)
    }
  }
  for (i in seq_along(expression)[-1L]) {
    expression[[i]] = .normalize_tablo_filtered_sums(expression[[i]])
  }
  expression
}

functionToData = function(exp) {
  dataNames = c('sum',
                'exp',
                'loge',
                'log',
                'sqrt',
                'abs',
                '=',
                '-',
                '+',
                '/',
                '*',
                '(',
                '==',
                '!=',
                '<',
                '>',
                '<=',
                '>=',
                '&',
                '|',
                '!',
                '^',
                'ifelse',
                'isin',
                'setpos')
  if (length(exp) == 1) {
    return(exp)
  } else    if (!(as.character(exp[[1]]) %in% dataNames)) {
    dataName = exp[[1]]
    exp[[1]] = as.name('[')

    for (c2 in length(exp):2) {
      exp[[c2 + 1]] = exp[[c2]]
    }

    exp[[2]] = dataName
    return(exp)
  }

  else{
    for (c1 in 1:length(exp)) {
      exp[[c1]] = functionToData(exp[[c1]])
    }
    return(exp)
  }
}
normalizeIfCalls = function(exp) {
  if (!is.language(exp) || is.name(exp) || length(exp) == 0L) return(exp)
  for (i in seq_along(exp)) {
    exp[[i]] = normalizeIfCalls(exp[[i]])
  }
  operator = tolower(as.character(exp[[1]]))
  if (operator %in% c("if", "ifelse")) {
    exp[[1]] = as.name("ifelse")
    if (length(exp) == 3L) exp[[4]] = 0
  }
  exp
}


generateSets = function(statements) {
  toRet = list()
  for (s in statements) {
    toRet[[length(toRet) + 1]] = processSetStatement(s)

  }

  f = str2lang('function(data)return(data)')
  w = str2lang('within(data,{})')
  for (tr in toRet) {
    w[[3]][[length(w[[3]]) + 1]] = if (is.call(tr)) tr else str2lang(tr)
  }

  f[[3]][[2]] = w

  return(eval(f))
}
