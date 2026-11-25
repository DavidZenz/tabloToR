getVarCoef = function(expr,
                      sets = list(),
                      coefficient = 1,
                      guards = list()) {
  toRet = list()
  if (length(expr) == 1) {
    if (is.numeric(expr) && isTRUE(expr == 0)) return(toRet)
    toRet[[length(toRet) + 1]] = list(variable = expr,
                                      sets = sets,
                                      coefficient = coefficient,
                                      guards = guards)
  }
  # If the top operator is sum: add to set/index
  else if (expr[[1]] == 'sum') {
    sets[[length(sets) + 1]] = list(index = expr[[2]], set = expr[[3]])

    toRet[[length(toRet) + 1]] = getVarCoef(expr[[4]], sets, coefficient, guards)

  } else if (expr[[1]] == '[') {
    toRet[[length(toRet) + 1]] = list(variable = expr,
                                      sets = sets,
                                      coefficient = coefficient,
                                      guards = guards)
  } else if (expr[[1]] == "ifelse") {
    toRet[[1L]] = getVarCoef(expr[[3L]], sets, coefficient,
                             c(guards, list(expr[[2L]])))
    if (length(expr) >= 4L) {
      toRet[[2L]] = getVarCoef(expr[[4L]], sets, coefficient,
                               c(guards, list(call("!", expr[[2L]]))))
    }
  } else if (expr[[1]] == '(') {
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[2]], sets, coefficient, guards)
  } else if (expr[[1]] == '+') {
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[2]], sets, coefficient, guards)
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[3]], sets, coefficient, guards)
  } else if (expr[[1]] == '-' & length(expr)==3) {
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[2]], sets, coefficient, guards)
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[3]], sets, call('-',coefficient), guards)
  } else if (expr[[1]] == '-' & length(expr)==2) {
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[2]], sets, call('-',coefficient), guards)
  } else if (expr[[1]] == '*') {
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[3]], sets, call('*', coefficient, expr[[2]]), guards)
  } else if (expr[[1]] == "/") {
    toRet[[1L]] = getVarCoef(expr[[2L]], sets,
                             call("/", coefficient, expr[[3L]]), guards)
  } else if (expr[[1]] == '=') {
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[2]], sets, coefficient, guards)
    toRet[[length(toRet) + 1]] = getVarCoef(expr[[3]], sets, call('*', coefficient,-1), guards)

  }
  return(toRet)
}


unlistVarCoef = function(obj) {
  toRet = list()
  for (e in obj) {
    if (!is.null(e$variable)) {
      toRet[[length(toRet) + 1]] = e
    } else{
      getResults = unlistVarCoef(e)
      for (ge in getResults) {
        toRet[[length(toRet) + 1]] = ge
      }
    }
  }
  return(toRet)
}

generateEquationCoefficients = function(equationStatements) {
  #toRet = list('equationMatrixList=list()')
  toRet = list()
  for (s in equationStatements) {
    # Get the formula for each variable
    frm = correctFormula(s$parsed$equation)

    variables = unlistVarCoef(getVarCoef(frm))

    for (v in seq_along(variables)) {
      if (length(variables[[v]]$variable) == 1) {
        variables[[v]]$indices = list()
        variables[[v]]$varname = variables[[v]]$variable
      } else{
        variables[[v]]$indices =  as.list(variables[[v]]$variable[3:length(variables[[v]]$variable)])
        variables[[v]]$varname = variables[[v]]$variable[[2]]
      }
      variables[[v]]$qualifiers = Map(function(f)
        sprintf('all(%s,%s)', deparse(f$index), deparse1(f$set)),
        variables[[v]]$sets)
    }

    dimensions = s$parsed$elements[grep('\\(all,', s$parsed$elements)]
    qualifiers = gsub('<>', '!=', gsub(':', ",", gsub(
      '=', '==', gsub('\\(all,', 'all(', dimensions)
    )))


    equationName = s$parsed$equationName
    equationIndices=Map(function(f)str2lang(f)[[2]],qualifiers)

    #Loop throuch each variable mentioned in this equation
    for (v in variables) {
      loops = lapply(c(qualifiers, v$qualifiers), str2lang)
      index_sets = setNames(
        lapply(loops, function(q) q[[3L]]),
        vapply(loops, function(q) as.character(q[[2L]]), "")
      )
      #Loop through the qualifiers (zeroth is the initial equation)
      expr = sprintf(
        "list(list(equation=%s,variable = %s, expression= %s))",

        ifelse(length(equationIndices)>0,sprintf(
          "sprintf('%s[%s]',%s)",
          equationName,
          paste(rep('\"%s\"', length(equationIndices)), collapse = ','),
          paste(unlist(equationIndices), collapse = ',')
        ),sprintf(
          '"%s[%s]"',
          equationName,
          paste(rep('\"%s\"', length(equationIndices)), collapse = ',')
        )),

        ifelse(
          length(v$indices) > 0,
          sprintf(
            "sprintf('%s[%s]',%s)",
            deparse1(v$varname),
            paste(rep('\"%s\"', length(v$indices)), collapse = ','),
            paste(unlist(v$indices), collapse = ',')
          ),
          sprintf(
            '"%s[%s]"',
            deparse1(v$varname),
            paste(rep('\"%s\"', length(v$indices)), collapse = ',')
          )
        ),
        deparse1(sumToMap(.tablo_with_division(v$coefficient), index_sets))
      )
      for (guard in rev(v$guards)) {
        context = encodeString(paste("Equation", equationName), quote = '"')
        expr = sprintf("if (.tablo_condition(%s, %s)) %s else list()",
                       deparse1(sumToMap(.tablo_with_division(guard), index_sets)), context, expr)
      }
      for (q in loops) {
        expr = sprintf(
          'unlist(Map(function(%s)%s,%s),recursive=F,use.names=F)',
          deparse1(q[[2]]),
          expr,
          deparse1(q[[3]])
        )
      }
      toRet[[length(toRet) + 1]] = sprintf('%s',expr)
    }


  }

  combinedExpression = sprintf("equationMatrixList=unlist(list(%s),recursive=FALSE)", paste(toRet,collapse=","))


  f = str2lang('function(data)return(data)')
  w = str2lang('within(data,{})')
  # for (tr in toRet) {
  #   w[[3]][[length(w[[3]]) + 1]] = str2lang(tr)
  # }

  w[[3]][[length(w[[3]]) + 1]] = parse(text=combinedExpression)[[1]]

  f[[3]][[2]] = w

  return(eval(f))
}
