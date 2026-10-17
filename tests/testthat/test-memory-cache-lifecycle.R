test_that("Schur budgets include dense blocks, factors and simultaneous work", {
  partition = list(external = list(row_group = c(0L, rep(1L, 768), 2L),
    commodity_count = 1L, region_count = 1L, global_group = 2L))
  for (backend in c("StructuredSchurFGMRES", "StructuredSchurFGMRESCpp")) {
    bytes = sparse_schur_memory(partition, backend)
    expect_gte(bytes$dense_matrix_bytes, 8 * 768^2)
    expect_gte(bytes$dense_factor_bytes, 8 * 768^2)
    expect_gt(bytes$dense_workspace_bytes, 0)
    expect_gt(bytes$worker_workspace_bytes, 0)
    expect_gt(bytes$sparse_factor_scratch_bytes, 0)
    expect_error(sparse_check_budget(
      list(estimated_peak_bytes = sum(unlist(bytes))), 2 * 1024^2),
      "above the configured")
  }
  # Original commodity groups can contain rows removed by earlier stages.
  # Their bounded native scratch is linear, not a dense factor of that size.
  partition$external$row_group = c(rep(0L, 20000L), 1L, 2L)
  bytes = sparse_schur_memory(partition, "StructuredSchurFGMRESCpp")
  expect_equal(bytes$sparse_factor_scratch_bytes, 280 * 20000)
})

test_that("public Schur memory guards reject known dense storage before assembly", {
  path = tempfile(fileext = ".tab")
  on.exit(unlink(path), add = TRUE)
  writeLines(c("set comm (c1);", "set reg (r1);",
    sprintf("set item (%s);", paste0("i", 1:768, collapse = ",")),
    "variable (all,c,comm)(all,r,reg)(change) x(c,r);",
    "variable (all,i,item)(all,r,reg)(change) y(i,r);",
    "variable (change) z;", "variable (all,c,comm)(all,r,reg) a(c,r);",
    "variable (all,i,item)(all,r,reg) b(i,r);", "variable d;",
    "equation ex (all,c,comm)(all,r,reg) x(c,r) = a(c,r);",
    "equation ey (all,i,item)(all,r,reg) y(i,r) = b(i,r);",
    "equation ez z = d;"), path)
  model = GEModel$new()
  model$loadTablo(path)
  model$setClosure(c("a", "b", "d"))
  model$loadData(list(), engine = "sparse")
  model$setShocks(c("a[c1,r1]" = 1, "b[i1,r1]" = 1, "d[]" = 1))
  partition = function(index, state) list(stages = list(NULL),
    external = sparse_external_block_partition(index, state))
  estimate = NULL
  check = sparse_check_budget
  with_mocked_bindings(
    expect_error(model$solveModel(iter = 1, steps = 1, engine = "sparse",
      postsim = FALSE, backend = "StructuredSchurFGMRESCpp",
      memory_budget = 2 * 1024^2), "above the configured"),
    sparse_gtap_elimination_partition = partition,
    sparse_check_budget = function(value, budget) {
      estimate <<- value
      check(value, budget)
    }, .package = "GEModelR")
  expect_gte(estimate$estimated_peak_bytes, 16 * 768^2)
  expect_false(isTRUE(model$lastDiagnostics$accepted_numerical_state))
})

test_that("assembled matrices are no longer retained during simulation updates", {
  observed = FALSE
  old = options(GEModelR.transaction.fault = function(phase, context) {
    if (phase != "simulation-update") return(invisible(NULL))
    for (frame in sys.frames()) {
      if (!exists("emitted", frame, inherits = FALSE)) next
      if (!exists("coefficient_matrix", frame, inherits = FALSE)) next
      observed <<- TRUE
      expect_null(get("emitted", frame)$A)
      expect_null(get("coefficient_matrix", frame))
    }
  })
  on.exit(options(old), add = TRUE)
  model = make_synthetic_model()
  model$setShocks(c("a[r1]" = 1))
  model$solveModel(iter = 1, steps = 1, engine = "sparse", postsim = FALSE)
  expect_true(observed)
})

test_that("structural cache survives transactions but never retains factors", {
  model = make_cpp_structured_model()
  partition = function(index, state) list(stages = list(NULL),
    external = sparse_external_block_partition(index, state))
  solve = function(model) with_mocked_bindings(
    model$solveModel(iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      backend = "StructuredSchurFGMRESCpp", diagnostics = TRUE, output = "compact"),
    sparse_gtap_elimination_partition = partition, .package = "GEModelR")
  solve(model)
  expect_equal(model$lastDiagnostics$native$structural_cache_misses, 1L)
  fresh = unserialize(serialize(model, NULL))
  solve(model)
  solve(fresh)
  expect_equal(model$lastDiagnostics$native$structural_cache_hits, 1L)
  expect_equal(model$lastDiagnostics$native$numeric_refactorizations, 1L)
  expect_equal(model$solution, fresh$solution, tolerance = 1e-12)
  expect_false(contains_external_pointer(model$sparseState$.solver_cache))
  model$setClosure(model$closure)
  expect_length(model$sparseState$.solver_cache, 0L)
  solve(model)
  expect_equal(model$lastDiagnostics$native$structural_cache_misses, 1L)
})

test_that("requested detailed reference diagnostics retain their solution field", {
  model = make_cpp_structured_model()
  partition = function(index, state) list(stages = list(NULL),
    external = sparse_external_block_partition(index, state))
  with_mocked_bindings(
    model$solveModel(iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      backend = "StructuredSchurFGMRES", diagnostics = TRUE, output = "compact"),
    sparse_gtap_elimination_partition = partition, .package = "GEModelR")
  expect_length(model$lastDiagnostics$solver_diagnostics$solution,
                 length(model$solution))
  expect_true(all(is.finite(model$lastDiagnostics$solver_diagnostics$solution)))
})
