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

test_that("unshocked exogenous values evaluate as implicit zero", {
  model <- make_synthetic_model()
  data <- sparse_state_data(model$sparseState)
  data$a[] <- NA_real_
  data$a[[2L]] <- 5
  state <- sparse_make_state(data)
  bindings <- list(r = 1:2, ".set:r" = "reg")
  unindexed_a <- as.call(list(as.name("["), as.name("a")))

  expect_equal(
    sparse_eval_expr_vectorized(
      quote(a), state, bindings, model$sparseIndex, 2L
    ),
    c(0, 5)
  )
  expect_equal(
    sparse_eval_expr_vectorized(
      unindexed_a, state, bindings, model$sparseIndex, 2L
    ),
    c(0, 5)
  )

  expect_equal(
    sparse_eval_expr_vectorized(
      quote(a[r]), state, bindings, model$sparseIndex, 2L
    ),
    c(0, 5)
  )
  expect_equal(
    sparse_eval_expr(
      quote(a[r]), state, list(r = 1L, ".set:r" = "reg"),
      model$sparseIndex
    ),
    0
  )
  expect_equal(
    as.numeric(sparse_eval_expr(quote(a), state, list(), model$sparseIndex)),
    c(0, 5)
  )
  expect_equal(
    as.numeric(sparse_eval_expr(unindexed_a, state, list(), model$sparseIndex)),
    c(0, 5)
  )
  expect_true(is.na(sparse_eval_expr(
    quote(x[r]), state, list(r = 1L, ".set:r" = "reg"),
    model$sparseIndex
  )))
})

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

test_that("formula dependencies include every repeated target definition", {
  equations = list(list(
    terms = list(list(coefficient = quote(a)))
  ))
  updates = list(
    list(
      class = "formula", target = list(name = "a"),
      expression = 0
    ),
    list(
      class = "formula", target = list(name = "a"),
      expression = quote(b)
    ),
    list(
      class = "formula", target = list(name = "b"),
      expression = 1
    )
  )

  expect_setequal(
    sparse_required_formula_names(equations, updates),
    c("a", "b")
  )
})

test_that("nested sums are vectorized across inner domains", {
  values = array(
    seq_len(24), dim = c(2, 3, 2, 2),
    dimnames = list(
      marg = c("m1", "m2"), comm = c("c1", "c2", "c3"),
      reg = c("r1", "r2"), reg = c("r1", "r2")
    )
  )
  state = sparse_make_state(list(vtmfsd = values))
  index = list(sets = list(
    marg = list(values = c("m1", "m2")),
    comm = list(values = c("c1", "c2", "c3")),
    reg = list(values = c("r1", "r2"))
  ))
  total = quote(sum(m, marg, sum(c, comm,
    sum(s, reg, sum(d, reg, vtmfsd[m, c, s, d])))))
  by_margin = quote(sum(c, comm,
    sum(s, reg, sum(d, reg, vtmfsd[m, c, s, d]))))

  expect_equal(
    sparse_eval_expr_vectorized(total, state, list(), index, 1L),
    sum(values)
  )
  expect_equal(
    sparse_eval_expr_vectorized(
      by_margin, state,
      list(m = 1:2, ".set:m" = "marg"), index, 2L
    ),
    as.numeric(apply(values, 1L, sum))
  )

  data = state$data
  data$vtuse = NA_real_
  state$data = data
  update = list(
    target = list(name = "vtuse", indices = list()),
    expression = total,
    domains = list()
  )
  expect_true(sparse_apply_update_vectorized(update, state, index))
  expect_equal(state$data$vtuse, sum(values))
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

test_that("column singleton reduction reconstructs coupled variables", {
  A <- Matrix::sparseMatrix(
    i = c(1, 1, 2),
    j = c(1, 2, 2),
    x = c(2, 1, 2),
    dims = c(2, 2)
  )
  rhs <- c(5, 4)

  reduced <- solve_sparse_system(A, rhs, reduction = "auto")
  direct <- solve_sparse_system(A, rhs, reduction = "off")

  expect_equal(reduced, c(1.5, 2), tolerance = 1e-12)
  expect_equal(reduced, direct, tolerance = 1e-12)
})

test_that("row singleton reduction reconstructs coupled variables", {
  A <- Matrix::sparseMatrix(
    i = c(1, 2, 2),
    j = c(1, 1, 2),
    x = c(2, 1, 3),
    dims = c(2, 2)
  )
  rhs <- c(4, 11)

  reduced <- solve_sparse_system(A, rhs, reduction = "auto")
  direct <- solve_sparse_system(A, rhs, reduction = "off")

  expect_equal(reduced, c(2, 3), tolerance = 1e-12)
  expect_equal(reduced, direct, tolerance = 1e-12)
})

test_that("SuiteSparse backend uses sparse LU without densifying", {
  skip_if_not(sparse_suite_sparse_available())
  A <- Matrix::sparseMatrix(
    i = c(1, 1, 2),
    j = c(1, 2, 2),
    x = c(2, 1, 2),
    dims = c(2, 2)
  )

  solution <- solve_sparse_system(
    A, c(5, 4), backend = "SuiteSparse", reduction = "off"
  )

  expect_equal(solution, c(1.5, 2), tolerance = 1e-12)
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

test_that("postsim keeps reporting equations outside the numerical solve", {
  fixture <- tempfile(fileext = ".tab")
  writeLines(c(
    "variable (change) x;",
    "variable y;",
    "variable z;",
    "variable a;",
    "equation ex x = a;",
    "equation ey y = x;",
    "equation ez z = y;"
  ), fixture)
  on.exit(unlink(fixture), add = TRUE)

  model <- GEModel$new()
  model$loadTablo(fixture)
  model$setClosure("a")
  model$loadData(list(), engine = "sparse")
  full <- sparse_rebuild_columns(model$sparseIndex, model$closure)
  simulation <- sparse_select_simulation_index(
    full, model$sparseSpec, model$sparseState, postsim = FALSE
  )
  with_postsim <- sparse_select_simulation_index(
    full, model$sparseSpec, model$sparseState, postsim = TRUE
  )

  expect_lt(simulation$equation_count, full$equation_count)
  expect_equal(with_postsim$equation_count, simulation$equation_count)
  expect_equal(with_postsim$endogenous_count, simulation$endogenous_count)
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

test_that("sparse updates match legacy across iterations and post-simulation", {
  fixture <- test_path("fixtures", "update.tab")
  configurations <- list(
    list(iter = 1, steps = 1),
    list(iter = 3, steps = 1),
    list(iter = 3, steps = c(1, 3))
  )

  for (configuration in configurations) {
    legacy <- GEModel$new()
    legacy$loadTablo(fixture)
    legacy$setClosure("a")
    legacy$loadData(list(), engine = "legacy")
    legacy$setShocks(setNames(10, "a[]"))
    legacy$solveModel(
      iter = configuration$iter,
      steps = configuration$steps
    )

    for (postsim_value in c(FALSE, TRUE)) {
      sparse <- GEModel$new()
      sparse$loadTablo(fixture)
      sparse$setClosure("a")
      sparse$loadData(list(), engine = "sparse")
      sparse$setShocks(setNames(10, "a[]"))
      sparse$solveModel(
        iter = configuration$iter,
        steps = configuration$steps,
        engine = "sparse",
        postsim = postsim_value,
        reduction = "off"
      )

      sparse_data <- sparse_state_data(sparse$sparseState)
      expect_equal(
        as.numeric(sparse$solution),
        as.numeric(legacy$solution),
        tolerance = 1e-7
      )
      expect_equal(
        as.numeric(sparse_data$v),
        as.numeric(legacy$data$v),
        tolerance = 1e-7
      )
      if (configuration$iter == 1 && identical(configuration$steps, 1)) {
        expect_equal(as.numeric(sparse_data$v), 110, tolerance = 1e-7)
      }
      if (postsim_value) {
        expect_equal(
          as.numeric(sparse_data$reported),
          as.numeric(sparse_data$v),
          tolerance = 1e-7
        )
      }
    }
  }
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

test_that("BTF solve preserves a sparse block-triangular solution", {
  A <- Matrix::sparseMatrix(
    i = c(1L, 1L, 2L, 2L, 3L, 3L, 4L, 4L),
    j = c(1L, 2L, 2L, 3L, 3L, 4L, 4L, 4L),
    x = c(2, 1, 3, 4, 5, 6, 7, 8),
    dims = c(4L, 4L)
  )
  expected <- c(1, 2, 3, 4)

  expect_equal(
    sparse_btf_solve(A, as.numeric(A %*% expected)),
    expected,
    tolerance = 1e-12
  )
})

test_that("structured elimination reconstructs eliminated variables", {
  skip_if_not_installed("Rcpp")
  A <- Matrix::sparseMatrix(
    i = c(1L, 1L, 2L, 2L, 3L, 3L, 4L, 4L, 1L, 2L, 3L, 4L,
           5L, 5L, 5L),
    j = c(1L, 2L, 1L, 2L, 3L, 4L, 3L, 4L, 5L, 5L, 5L, 5L,
           1L, 3L, 5L),
    x = c(4, 1, 2, 3, 5, 1, 2, 4, 0.2, 0.3, 0.4, 0.1,
           0.5, 0.2, 2),
    dims = c(5L, 5L)
  )
  expected <- c(1, -2, 0.5, 3, 4)
  partition <- list(
    row_group = as.integer(c(0L, 0L, 1L, 1L, -1L)),
    column_group = as.integer(c(0L, 0L, 1L, 1L, -1L)),
    n_groups = 2L
  )
  result <- sparse_exact_structured_solve(
    A, as.numeric(A %*% expected), partition
  )

  expect_equal(result$reduced_dimension, 1L)
  expect_equal(result$solution, expected, tolerance = 1e-10)
  expect_lt(
    sparse_true_residual(A, result$solution, as.numeric(A %*% expected))$relative_l2,
    1e-10
  )
})

test_that("structured elimination composes exact reduction stages", {
  skip_if_not_installed("Rcpp")
  A <- Matrix::sparseMatrix(
    i = c(1L, 1L, 2L, 2L, 3L),
    j = c(1L, 2L, 2L, 3L, 3L),
    x = c(2, 1, 3, 1, 4),
    dims = c(3L, 3L)
  )
  expected <- c(1, 2, 3)
  partition <- list(
    stages = list(
      first = list(
        row_group = as.integer(c(0L, -1L, -1L)),
        column_group = as.integer(c(0L, -1L, -1L)),
        n_groups = 1L
      ),
      second = list(
        row_group = as.integer(c(-1L, 0L, -1L)),
        column_group = as.integer(c(-1L, 0L, -1L)),
        n_groups = 1L
      )
    )
  )
  result <- sparse_exact_structured_solve(
    A, as.numeric(A %*% expected), partition
  )

  expect_equal(result$solution, expected, tolerance = 1e-10)
  expect_equal(result$reduced_dimension, 1L)
  expect_equal(result$stage_count, 2L)
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

test_that("exact Schur rejects coupled local blocks", {
  A = Matrix::sparseMatrix(
    i = c(1L, 2L, 3L, 4L, 1L),
    j = c(1L, 2L, 3L, 4L, 2L),
    x = c(2, 2, 2, 2, 0.5),
    dims = c(4L, 4L)
  )
  groups = as.integer(0:3)

  expect_error(
    sparse_exact_schur_validate_partition(
      A, groups, groups,
      local_count = 2L, region_count = 1L, global_group = 3L
    ),
    "local blocks 0 and 1 are coupled"
  )
})

test_that("external Schur groups commodity-region positions by commodity", {
  domains = list(
    list(index = "c", set = "comm", predicate = NULL),
    list(index = "r", set = "reg", predicate = NULL)
  )
  index = list(
    sets = list(
      comm = list(values = c("c1", "c2")),
      reg = list(values = c("r1", "r2"))
    ),
    equations = list(list(
      name = "e_x", domains = domains, n = 4L,
      row_start = 1L, row_end = 4L
    )),
    variables = list(list(
      name = "x", domains = domains, n = 4L,
      endo_start = 1L, exogenous = FALSE
    )),
    equation_count = 4L,
    endogenous_count = 4L,
    column_order = 1:4
  )

  partition = sparse_external_block_partition(index, NULL)

  expect_false(any(partition$row_group < 0L))
  expect_false(any(partition$column_group < 0L))
  expect_equal(sort(tabulate(partition$row_group + 1L)), c(2L, 2L))
  expect_equal(sort(tabulate(partition$column_group + 1L)), c(2L, 2L))
})

test_that("external Schur promotes cross-commodity equations by region", {
  domains = list(
    list(index = "c", set = "comm", predicate = NULL),
    list(index = "r", set = "reg", predicate = NULL)
  )
  ref = function(name, first) list(
    name = name, indices = list(as.name(first), as.name("r"))
  )
  qpa_term = list(ref = ref("qpa", "c"), sums = list())
  ppa_term = list(
    ref = ref("ppa", "k"),
    sums = list(list(index = "k", set = "comm"))
  )
  index = list(
    sets = list(
      comm = list(values = c("c1", "c2")),
      reg = list(values = c("r1", "r2"))
    ),
    equations = list(
      list(
        name = "e_qpa", domains = domains, n = 4L,
        row_start = 1L, row_end = 4L,
        terms = list(qpa_term, ppa_term), lhs_terms = list(qpa_term)
      ),
      list(
        name = "e_ppa", domains = domains, n = 4L,
        row_start = 5L, row_end = 8L,
        terms = list(), lhs_terms = list()
      )
    ),
    variables = list(
      list(
        name = "qpa", sets = c("comm", "reg"), domains = domains,
        n = 4L, endo_start = 1L, exogenous = FALSE
      ),
      list(
        name = "ppa", sets = c("comm", "reg"), domains = domains,
        n = 4L, endo_start = 5L, exogenous = FALSE
      )
    ),
    variable_by_name = list(qpa = 1L, ppa = 2L),
    equation_count = 8L,
    endogenous_count = 8L,
    column_order = 1:8
  )

  partition = sparse_external_block_partition(index, NULL)

  expect_equal(partition$regional_equations, "e_qpa")
  expect_equal(partition$regional_variables, "qpa")
  expect_equal(partition$row_group[1:4], c(2L, 3L, 2L, 3L))
  expect_equal(partition$column_group[1:4], c(2L, 2L, 3L, 3L))
  expect_equal(tabulate(partition$row_group + 1L, nbins = 5L),
               c(2L, 2L, 2L, 2L, 0L))
  expect_equal(tabulate(partition$column_group + 1L, nbins = 5L),
               c(2L, 2L, 2L, 2L, 0L))
})

test_that("exact Schur FGMRES preserves a multi-region sparse system", {
  skip_if_not_installed("Matrix")
  set.seed(7)
  dense = matrix(rnorm(81), 9L, 9L)
  diag(dense) = diag(dense) + 10
  A = Matrix::Matrix(dense, sparse = TRUE)
  row_groups = as.integer(c(0L, 0L, 1L, 1L, 2L, 2L, 1L, 1L, 3L))
  column_groups = as.integer(c(1L, 0L, 2L, 1L, 0L, 2L, 1L, 1L, 3L))
  rhs = rnorm(9L)

  result = sparse_exact_schur_solve(
    A, rhs, row_groups, column_groups, local_count = 1L, region_count = 2L,
    global_group = 3L, panel_size = 2L, restart = 8L, max_iterations = 30L,
    tolerance = 1e-10, true_residual_frequency = 1L
  )

  expect_true(result$converged)
  expect_equal(result$solution, as.numeric(solve(dense, rhs)),
               tolerance = 1e-8)
  expect_lt(result$diagnostics$true_relative_residual, 1e-10)
  expect_false(result$diagnostics$dense_full_system_operations)
})
