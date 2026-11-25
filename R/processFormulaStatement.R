.tablo_formula_qualifiers = function(statement) {
  elements = unlist(statement$parsed$elements, use.names = FALSE)
  elements = elements[!grepl("^\\(\\s*all\\s*,", elements)]
  elements = gsub('"[^"]*"', '""', elements)
  trimws(unlist(strsplit(sub("\\)$", "", sub("^\\(", "", elements)),
                         ",", fixed = TRUE), use.names = FALSE))
}

.tablo_formula_is_initial = function(statement) {
  qualifiers = .tablo_formula_qualifiers(statement)
  isTRUE(statement$read_default) || "initial" %in% qualifiers ||
    (!("always" %in% qualifiers) && isTRUE(statement$formula_initial_default))
}

processFormulaStatement = function(s){
  frm = correctFormula(s$parsed$equation)
  frm[[3L]] = .tablo_with_division(frm[[3L]], s$division)
  #frm = correctFormula(gsub(":","%:%",gsub('>==','>=',gsub('<==','<=',gsub('=','=',s$parsed$equation)))))

  dimensions = s$parsed$elements[grep('\\(all,', s$parsed$elements)]
  qualifiers = gsub('<>', '!=', gsub(':', ",", gsub(
    '=', '==', gsub('\\(all,', 'all(', dimensions)
  )))

  if (length(qualifiers) > 0) {
    condition = list()
    for (l in 1:length(qualifiers)) {
      q = str2lang(qualifiers[[l]])
      if (length(q) == 4) {
        condition[[length(condition) + 1]] = deparse1(.tablo_with_division(correctFormula(
          deparse1(q[[4]]), preserve_assignment = FALSE
        ), s$division))
      }
    }

    for (l in 1:length(qualifiers)) {
      q = str2lang(qualifiers[[l]])
      if (l == 1) {
        expr = sprintf(
          'for(%s in %s){%s}',
          paste0(deparse1(q[[2]]),collapse=' '),
          paste0(deparse1(q[[3]]),collapse=' '),
          ifelse(
            length(condition) == 0,
            paste0(deparse1(frm),collapse=' '),
            sprintf(
              'if(%s){%s}',
              paste(condition, collapse = '&'),
              paste0(deparse1(frm), collapse=' ')
            )
          )
        )
      } else {
        expr = sprintf(
          'for(%s in %s){%s}',
          paste0(deparse1(q[[2]]),collapse=' '),
                 paste0(deparse1(q[[3]]),collapse=' '),
          expr
        )
      }
    }
  } else{
    expr = paste0(deparse1(frm),collapse=' ')
  }
  return(paste0(deparse1(sumToMap(str2lang(expr))),collapse=' '))
}
