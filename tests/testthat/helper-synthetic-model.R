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
  spec <- make_shared_synthetic_spec()
  data <- make_shared_synthetic_data()
  model <- GEModel$new()
  model$sparseSpec <- spec
  model$data <- data
  model$sourceData <- data
  model$sparseState <- sparse_make_state(data)
  model$sparseIndex <- sparse_build_index(spec, data)
  model$setClosure(c("a", "b"))
  model$sparseIndex <- sparse_build_row_layout(
    spec, model$sparseIndex, model$sparseState
  )
  model$variableValues <- data[c("x", "a", "b")]
  model
}
