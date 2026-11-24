.tablo_product_multiplier = function(expression) {
  if (is.call(expression) && identical(expression[[1L]], as.name("("))) {
    return(.tablo_product_multiplier(expression[[2L]]))
  }
  if (is.call(expression) && identical(expression[[1L]], as.name("*"))) {
    return(call("*", .tablo_product_multiplier(expression[[2L]]),
                .tablo_product_multiplier(expression[[3L]])))
  }
  call("+", 1, call("/", expression, 100))
}

.tablo_update_expression = function(target, expression, qualifiers) {
  if (any(grepl("^\\(\\s*change\\s*\\)$", qualifiers, ignore.case = TRUE))) {
    return(call("+", target, expression))
  }
  if (any(grepl("^\\(\\s*percent_change\\s*\\)$", qualifiers,
                ignore.case = TRUE))) {
    return(call("*", target, call("+", 1, call("/", expression, 100))))
  }
  call("*", target, .tablo_product_multiplier(expression))
}

processUpdateStatement = function(s) {
  dimensions = s$parsed$elements[grep('\\(all,', s$parsed$elements)]
  qualifiers = gsub('<>', '!=', gsub(':', ",", gsub(
    '=', '==', gsub('\\(all,', 'all(', dimensions)
  )))



  frm = correctFormula(s$parsed$equation)

  if (s$class == "update") {
    frm[[3L]] = .tablo_update_expression(
      frm[[2L]], frm[[3L]], s$parsed$elements
    )
  }



  if (length(qualifiers) > 0) {
    condition = list()
    for (l in 1:length(qualifiers)) {
      q = str2lang(qualifiers[[l]])
      if (length(q) == 4) {
        condition[[length(condition) + 1]] = deparse1(correctFormula(deparse(q[[4]]), preserve_assignment = FALSE))
      }
    }

    for (l in 1:length(qualifiers)) {
      q = str2lang(qualifiers[[l]])
      if (l == 1) {
        expr = sprintf(
          'for(%s in %s){%s}',
          deparse1(q[[2]]),
          deparse1(q[[3]]),
          ifelse(
            length(condition) == 0,
            deparse1(frm),
            sprintf(
              'if(%s){%s}',
              paste(condition, collapse = '&'),
              deparse1(frm)
            )
          )
        )
      } else {
        expr = sprintf(
          'for(%s in %s){%s}',
          deparse1(q[[2]]),
          deparse1(q[[3]]),
          expr
        )
      }
    }
  } else{
    expr = deparse1(frm)
  }
  return(deparse1(sumToMap(str2lang(expr))))
}
