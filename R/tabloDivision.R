.tablo_mark_division = function(statements) {
  normal = post = list(zero = 0, nonzero = NULL)
  postsim = FALSE
  for (id in seq_along(statements)) {
    statement = statements[[id]]
    if (statement$class == "postsim") {
      postsim = grepl("^\\(\\s*begin\\s*\\)", statement$command)
    } else if (statement$class == "zerodivide") {
      qualifiers = trimws(gsub("[()]", "", unlist(statement$parsed$elements)))
      kind = if (!length(qualifiers) || identical(qualifiers, "zero_by_zero")) {
        "zero"
      } else if (identical(qualifiers, "nonzero_by_zero")) {
        "nonzero"
      } else {
        stop(sprintf("Invalid ZERODIVIDE qualifier in %s", statement$command),
             call. = FALSE)
      }
      command = trimws(statement$parsed$equation)
      replacement = NULL
      if (grepl("^default\\s+", command)) {
        value = trimws(sub("^default\\s+", "", command))
        number = suppressWarnings(as.numeric(value))
        if (is.finite(number)) {
          replacement = number
        } else if (grepl("^[a-z][a-z0-9_.]*$", value)) {
          replacement = as.name(value)
        } else {
          stop(sprintf("Invalid ZERODIVIDE default %s", value), call. = FALSE)
        }
      } else if (command != "off") {
        stop(sprintf("Invalid ZERODIVIDE directive %s", command), call. = FALSE)
      }
      if (postsim) {
        post[kind] = list(replacement)
      } else {
        normal[kind] = list(replacement)
      }
    } else if (statement$class == "formula") {
      statements[[id]]$division = if (postsim) post else normal
      statements[[id]]$postsim = postsim
    }
  }
  statements
}

.tablo_with_division = function(expr, policy = list(zero = NULL, nonzero = NULL)) {
  if (!is.call(expr)) return(expr)
  for (argument in seq_along(expr)[-1L]) {
    if (!identical(expr[[argument]], quote(expr = ))) {
      expr[argument] = list(.tablo_with_division(expr[[argument]], policy))
    }
  }
  if (identical(expr[[1L]], as.name("/"))) {
    expr = call(".tablo_divide", expr[[2L]], expr[[3L]],
                policy$zero, policy$nonzero)
  }
  expr
}

.tablo_divide = function(numerator, denominator, zero = NULL, nonzero = NULL) {
  value = numerator / denominator
  denominator = rep_len(denominator, length(value))
  missing_divisor = which(denominator == 0)
  if (!length(missing_divisor)) return(value)

  numerator = rep_len(numerator, length(value))[missing_divisor]
  from_zero = missing_divisor[which(numerator == 0)]
  from_nonzero = missing_divisor[which(numerator != 0)]
  if (length(from_zero)) {
    if (is.null(zero)) stop("TABLO division by zero (0/0)", call. = FALSE)
    value[from_zero] = zero
  }
  if (length(from_nonzero)) {
    if (is.null(nonzero)) stop("TABLO division by zero", call. = FALSE)
    value[from_nonzero] = nonzero
  }
  value
}
