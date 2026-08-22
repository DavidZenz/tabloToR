make_cpp_structured_model <- function() {
  fixture <- tempfile(fileext = ".tab")
  writeLines(c(
    "set comm (c1,c2);",
    "set reg (r1,r2);",
    "variable (all,c,comm)(all,r,reg)(change) x(c,r);",
    "variable (all,r,reg)(change) y(r);",
    "variable (change) z;",
    "variable (all,c,comm)(all,r,reg) a(c,r);",
    "variable (all,r,reg) b(r);",
    "variable d;",
    "equation ex (all,c,comm)(all,r,reg) x(c,r) = a(c,r);",
    "equation ey (all,r,reg) y(r) = b(r);",
    "equation ez z = d;"
  ), fixture)
  model <- GEModel$new()
  model$loadTablo(fixture)
  unlink(fixture)
  model$setClosure(c("a", "b", "d"))
  model$loadData(list(), engine = "sparse")
  model$setShocks(setNames(
    c(1, 2, 3, 4, 5, 6, 7),
    c("a[c1,r1]", "a[c2,r1]", "a[c1,r2]", "a[c2,r2]",
      "b[r1]", "b[r2]", "d[]")
  ))
  model
}

make_cpp_schur_fixture <- function() {
  set.seed(71)
  dense <- matrix(rnorm(121), 11L, 11L)
  diag(dense) <- diag(dense) + 12
  # One local block, two unequal regions, and a two-position global block.
  row_group <- as.integer(c(0, 0, 0, 1, 1, 2, 2, 2, 2, 3, 3))
  column_group <- as.integer(c(0, 0, 0, 1, 1, 2, 2, 2, 2, 3, 3))
  list(
    A = Matrix::Matrix(dense, sparse = TRUE),
    dense = dense,
    rhs = rnorm(11L),
    row_group = row_group,
    column_group = column_group,
    local_count = 1L,
    region_count = 2L,
    global_group = 3L
  )
}

contains_external_pointer <- function(value) {
  if (typeof(value) == "externalptr") return(TRUE)
  if (is.environment(value)) {
    return(any(vapply(as.list.environment(value, all.names = TRUE),
                      contains_external_pointer, logical(1))))
  }
  if (is.list(value)) {
    return(any(vapply(value, contains_external_pointer, logical(1))))
  }
  FALSE
}
