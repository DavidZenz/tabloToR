.tablo_sum_product_factors = function(expression) {
  if (is.call(expression) && identical(expression[[1L]], as.name("("))) {
    return(.tablo_sum_product_factors(expression[[2L]]))
  }
  if (is.call(expression) && identical(expression[[1L]], as.name("*"))) {
    return(call("+", .tablo_sum_product_factors(expression[[2L]]),
                .tablo_sum_product_factors(expression[[3L]])))
  }
  expression
}

.tablo_update_expression = function(target, expression, qualifiers) {
  if (any(grepl("^\\(\\s*explicit\\s*\\)$", qualifiers, ignore.case = TRUE))) {
    return(expression)
  }
  if (any(grepl("^\\(\\s*change\\s*\\)$", qualifiers, ignore.case = TRUE))) {
    return(call("+", target, expression))
  }
  if (any(grepl("^\\(\\s*percent_change\\s*\\)$", qualifiers,
                ignore.case = TRUE))) {
    return(call("*", target, call("+", 1, call("/", expression, 100))))
  }
  change = .tablo_sum_product_factors(expression)
  call("*", target, call("+", 1, call("/", change, 100)))
}

processUpdateStatement = function(s, target = NULL) {
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
  frm[[3L]] = .tablo_with_division(frm[[3L]])
  if (s$class == "update") {
    name = sparse_parse_ref(frm[[2L]])$name
    frm[[3L]] = call(".tablo_finite_update", frm[[3L]], name)
  }
  if (!is.null(target)) {
    if (is.name(frm[[2L]])) {
      frm[[2L]] = target
    } else {
      frm[[2L]][[2L]] = target
    }
  }

  if (length(qualifiers) > 0) {
    condition = list()
    for (l in 1:length(qualifiers)) {
      q = str2lang(qualifiers[[l]])
      if (length(q) == 4) {
        condition[[length(condition) + 1]] = deparse1(.tablo_with_division(correctFormula(
          deparse1(q[[4]]), preserve_assignment = FALSE
        )))
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
