.tablo_set_position = function(member, labels, set_name) {
  positions = match(tolower(as.character(member)), tolower(as.character(labels)))
  if (anyNA(positions)) {
    stop(sprintf("$POS cannot resolve a member of SET %s", set_name),
         call. = FALSE)
  }
  positions
}

sumToMap = function(expr, index_sets = list()) {
  if (!is.call(expr)) return(expr)
  op = expr[[1L]]

  if (identical(op, as.name("setpos"))) {
    set = if (length(expr) == 3L) expr[[3L]] else if (
      length(expr) == 2L && is.name(expr[[2L]])
    ) index_sets[[as.character(expr[[2L]])]]
    if (!is.name(set)) stop("$POS requires a known index set", call. = FALSE)
    return(call(".tablo_set_position", sumToMap(expr[[2L]], index_sets),
                set, as.character(set)))
  }
  if (identical(op, as.name("for"))) {
    index_sets[[as.character(expr[[2L]])]] = expr[[3L]]
    expr[[4L]] = sumToMap(expr[[4L]], index_sets)
    return(expr)
  }
  if (identical(op, as.name("sum")) && length(expr) == 4L) {
    index = expr[[2L]]
    set = expr[[3L]]
    index_sets[[as.character(index)]] = set
    expression = sumToMap(expr[[4L]], index_sets)
    mapped = str2lang(sprintf("Map(function(%s)%s, %s)",
                              deparse1(index), deparse1(expression),
                              deparse1(set)))
    return(call("sum", call("unlist", mapped)))
  }
  for (i in seq_along(expr)[-1L]) {
    if (!identical(expr[[i]], quote(expr = ))) {
      expr[i] = list(sumToMap(expr[[i]], index_sets))
    }
  }
  expr
}

generateFormulas = function(formulaStatements) {
  toRet = list()
  for (s in formulaStatements) {
        toRet[[length(toRet) + 1]] = processFormulaStatement(s)
  }

  f = str2lang('function(data)return(data)')
  w = str2lang('within(data,{})')
  for (tr in toRet) {
    w[[3]][[length(w[[3]]) + 1]] = sumToMap(str2lang(tr))
  }

  f[[3]][[2]] = w

  return(eval(f))
}

#
# toRet[[55]]
#
# sum(r, REG, VST[l, r])
#
#
# x = str2lang('sum(r,REG,POP[r])')
# y = str2lang(
#   sprintf(
#     '%s(unlist(Map(function(%s)%s,%s)))',
#     deparse(x[[1]]),
#     deparse(x[[2]]),
#     deparse(x[[4]]),
#     deparse(x[[3]])
#   )
# )
#
# REG = c('A', 'B')
# PROD = c('P','R','S')
#
# VPA = array(c(1, 2, 3, 4), dim = c(3,2), dimnames = list(PROD,REG))
# VGA = array(c(1, 2, 3, 4), dim = c(2), dimnames = list(REG))
#
# eval(sumToMap(str2lang('sum(r,REG,VGA[r]+sum(j,PROD,VPA[j,r]))')))
#
#
# POP = array(c(1, 2, 3, 4), dim = c(4), dimnames = list(REG))
# eval(y)
#
# sumToMap(str2lang('sum(r,REG,VGA[r]+sum(j,PROD,VPA[j,r]))'))
#
#
# sum(VST[l, REG])
#
# sum(Map(function(r)
#   , VXWD[i, r, s]))
#
# sum(r, REG, sum(s, REG, VXWD[i, r, s])) / (sum(k,
#                                                TRAD_COMM, sum(r, REG, sum(s, REG, VXWD[k, r, s]))) +
#                                              sum(l, MARG_COMM, sum(r, REG, VST[l, r])))
