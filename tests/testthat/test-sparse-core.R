make_statement <- function(class, equation, elements = character()) {
  list(
    class = class,
    parsed = list(
      equation = equation,
      elements = elements,
      equationName = equation
    )
  )
}

make_synthetic_spec <- function() {
  statements <- list(
    make_statement("variable", "x(r)", c("(all,r,reg)", "(change)")),
    make_statement("variable", "a(r)", "(all,r,reg)"),
    make_statement("variable", "b(r)", "(all,r,reg)"),
    make_statement(
      "equation",
      "x(r) = IF(r in foo, a(r)) + sum(s,reg,b(s))",
      "(all,r,reg)"
    )
  )
  sparse_compile_spec(statements)
}

make_synthetic_data <- function() {
  list(
    reg = c("r1", "r2"),
    foo = "r1",
    x = array(NA_real_, 2L, dimnames = list(c("r1", "r2"))),
    a = array(0, 2L, dimnames = list(c("r1", "r2"))),
    b = array(0, 2L, dimnames = list(c("r1", "r2")))
  )
}

make_synthetic_model <- function() {
  spec <- make_synthetic_spec()
  data <- make_synthetic_data()
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

test_that("compiler preserves conditional and summation structure", {
  spec <- make_synthetic_spec()

  expect_length(spec$variables, 3L)
  expect_length(spec$equations, 1L)
  expect_length(spec$equations[[1]]$terms, 3L)
  expect_true(any(vapply(
    spec$equations[[1]]$terms,
    function(term) length(term$sums) == 1L,
    logical(1)
  )))
  expect_true(any(vapply(
    spec$equations[[1]]$terms,
    function(term) length(term$guards) == 1L,
    logical(1)
  )))
  expect_length(spec$compile_errors, 0L)
})

test_that("zero shocks stay implicit and nonzero shocks build a sparse RHS", {
  spec <- make_synthetic_spec()
  data <- make_synthetic_data()
  state <- sparse_make_state(data)
  index <- sparse_build_row_layout(
    spec,
    sparse_rebuild_columns(sparse_build_index(spec, data), c("a", "b")),
    state
  )

  zero <- sparse_resolve_shocks(
    list(
      explicitShocks = sparse_normalize_shocks(setNames(0, "a[r1]")),
      variableValues = list()
    ),
    state,
    index
  )
  expect_length(zero$positions, 0L)

  shocks <- setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]"))
  resolved <- sparse_resolve_shocks(
    list(
      explicitShocks = sparse_normalize_shocks(shocks),
      variableValues = list()
    ),
    state,
    index
  )
  emitted <- sparse_emit_system(state, index, resolved)

  expect_s4_class(emitted$A, "sparseMatrix")
  expect_false(is.matrix(emitted$A))
  expect_equal(emitted$rhs, c(8, 3), tolerance = 1e-12)
  expect_equal(
    solve_sparse_system(emitted$A, emitted$rhs, reduction = "off"),
    c(8, 3),
    tolerance = 1e-12
  )
})

test_that("GEModel exposes sparse closure, shocks, memory, and compact output", {
  model <- make_synthetic_model()
  model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))

  model$solveModel(
    iter = 1,
    steps = 1,
    engine = "sparse",
    diagnostics = TRUE,
    output = "full",
    reduction = "auto"
  )

  expect_equal(as.numeric(model$solution), c(8, 3), tolerance = 1e-7)
  expect_equal(as.numeric(model$data$x), c(8, 3), tolerance = 1e-7)
  expect_false(model$lastDiagnostics$estimated_memory$dense_fallback)
  expect_equal(model$lastDiagnostics$engine, "sparse")

  estimate <- model$estimateMemory(engine = "sparse")
  expect_gt(estimate$estimated_peak_bytes, 0)
  expect_false(estimate$dense_fallback)

  compact <- make_synthetic_model()
  compact$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
  compact$solveModel(
    iter = 1,
    steps = 1,
    engine = "sparse",
    output = "compact",
    variables = "x",
    postsim = FALSE,
    reduction = "off"
  )
  expect_true(is.list(compact$compactOutput))
  expect_equal(as.numeric(compact$compactOutput$x), c(8, 3))
  expect_length(compact$data, 0L)
})

test_that("closure changes rebuild endogenous columns and invalidate patterns", {
  model <- make_synthetic_model()
  expect_equal(model$sparseIndex$endogenous_count, 2L)

  model$setClosure("a")
  expect_equal(model$sparseIndex$endogenous_count, 4L)
  expect_null(model$sparseIndex$pattern_cache)
})

test_that("memory budgets fail during preflight", {
  model <- make_synthetic_model()
  model$setMemoryBudget(1)
  expect_error(
    model$solveModel(
      iter = 1,
      steps = 1,
      engine = "sparse",
      postsim = FALSE,
      reduction = "off"
    ),
    "above the configured"
  )
})

test_that("sparse and legacy engines agree on the fixture", {
  fixture <- test_path("fixtures", "synthetic.tab")

  legacy <- GEModel$new()
  legacy$loadTablo(fixture)
  legacy$setClosure("a")
  legacy$loadData(list(), engine = "legacy")
  legacy$setShocks(setNames(5, 'a["r1"]'))
  legacy$solveModel(iter = 1, steps = 1)

  sparse <- GEModel$new()
  sparse$loadTablo(fixture)
  sparse$setClosure("a")
  sparse$loadData(list(), engine = "sparse")
  sparse$setShocks(setNames(5, "a[r1]"))
  sparse$solveModel(
    iter = 1, steps = 1, engine = "sparse", reduction = "off"
  )

  expect_equal(
    as.numeric(sparse$solution),
    as.numeric(legacy$solution),
    tolerance = 1e-7
  )
})

test_that("sparse Euler steps stream without dense substep matrices", {
  model <- make_synthetic_model()
  model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
  model$solveModel(
    iter = 3,
    steps = c(1, 3),
    engine = "sparse",
    postsim = FALSE,
    output = "compact",
    variables = "x",
    diagnostics = TRUE,
    reduction = "auto"
  )

  expect_length(model$compactOutput$x, 2L)
  expect_true(all(is.finite(model$compactOutput$x)))
  expect_equal(model$lastDiagnostics$steps, c(1, 3))
  expect_false(model$lastDiagnostics$estimated_memory$dense_fallback)
})

test_that("SparseM remains a compatible sparse backend", {
  skip_if_not_installed("SparseM")
  model <- make_synthetic_model()
  model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
  model$solveModel(
    iter = 1,
    steps = 1,
    engine = "sparse",
    backend = "SparseM",
    postsim = FALSE,
    reduction = "off"
  )

  expect_equal(as.numeric(model$solution), c(8, 3), tolerance = 1e-7)
})
test_that("vectorized and scalar emitters agree", {
  model <- make_synthetic_model()
  model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
  shocks <- sparse_resolve_shocks(
    model, model$sparseState, model$sparseIndex
  )
  vectorized <- sparse_emit_system(
    model$sparseState, model$sparseIndex, shocks
  )
  previous <- getOption("tabloToR.sparse.vectorized")
  options(tabloToR.sparse.vectorized = FALSE)
  on.exit(options(tabloToR.sparse.vectorized = previous), add = TRUE)
  scalar <- sparse_emit_system(
    model$sparseState, model$sparseIndex, shocks
  )

  expect_equal(vectorized$rhs, scalar$rhs, tolerance = 1e-12)
  expect_equal(
    Matrix::summary(vectorized$A),
    Matrix::summary(scalar$A),
    tolerance = 1e-12
  )
})

test_that("cross-set indexed references resolve by label", {
  statements <- list(
    make_statement(
      "variable", "x(c,r)",
      c("(all,c,comm)", "(all,r,reg)")
    ),
    make_statement(
      "variable", "qst(m,r)",
      c("(all,m,marg)", "(all,r,reg)")
    ),
    make_statement(
      "equation", "x(c,r) = IF(c in marg, qst(c,r))",
      c("(all,c,comm)", "(all,r,reg)")
    )
  )
  spec <- sparse_compile_spec(statements)
  data <- list(
    comm = c("c1", "m1", "c2"),
    marg = "m1",
    reg = c("r1", "r2"),
    x = array(
      NA_real_, dim = c(3, 2),
      dimnames = list(comm = c("c1", "m1", "c2"), reg = c("r1", "r2"))
    ),
    qst = array(
      0, dim = c(1, 2),
      dimnames = list(marg = "m1", reg = c("r1", "r2"))
    )
  )
  state <- sparse_make_state(data)
  index <- sparse_build_row_layout(
    spec,
    sparse_rebuild_columns(
      sparse_build_index(spec, data), "qst"
    ),
    state
  )
  shocks <- sparse_resolve_shocks(
    list(
      explicitShocks = sparse_normalize_shocks(
        setNames(c(5, 7), c("qst[m1,r1]", "qst[m1,r2]"))
      ),
      variableValues = list()
    ),
    state,
    index
  )
  emitted <- sparse_emit_system(state, index, shocks)

  expect_equal(dim(emitted$A), c(6, 6))
  expect_equal(emitted$nnz, 6L)
  expect_equal(emitted$rhs, c(0, 0, 5, 7, 0, 0), tolerance = 1e-12)
})
