make_shared_synthetic_spec <- function() {
  statements <- list(
    make_statement("variable", "x(r)", c("(all,r,reg)", "(change)")),
    make_statement("variable", "a(r)", "(all,r,reg)"),
    make_statement("variable", "b(r)", "(all,r,reg)"),
    make_statement(
      "equation", "x(r) = IF(r in foo, a(r)) + sum(s,reg,b(s))",
      "(all,r,reg)"
    )
  )
  sparse_compile_spec(statements)
}

make_shared_synthetic_data <- function() {
  list(
    reg = c("r1", "r2"), foo = "r1",
    x = array(NA_real_, 2L, dimnames = list(c("r1", "r2"))),
    a = array(0, 2L, dimnames = list(c("r1", "r2"))),
    b = array(0, 2L, dimnames = list(c("r1", "r2")))
  )
}

make_synthetic_model <- function() {
  model <- GEModel$new()
  fixture <- tempfile(fileext = ".tab")
  writeLines(c(
    "set reg (r1,r2);",
    "variable (all,r,reg)(change) x(r);",
    "variable (all,r,reg) a(r);",
    "variable (all,r,reg) b(r);",
    "equation eq (all,r,reg) x(r) = a(r) + sum(s,reg,b(s));"
  ), fixture)
  on.exit(unlink(fixture), add = TRUE)
  model$loadTablo(fixture)
  model$setClosure(c("a", "b"))
  model$loadData(make_shared_synthetic_data(), engine = "sparse")
  model
}
