test_that("retained regional transfers replace only mathematically equivalent solves", {
  fixture = make_cpp_schur_fixture()
  runtime = .sparse_schur_cpp_runtime
  old = runtime$active
  runtime$active = TRUE
  runtime$state = sparse_make_state(list())
  runtime$index_key = "regional-reuse"
  on.exit({
    .sparse_cpp_release_live_factors()
    runtime$active = old
    runtime$state = NULL
    runtime$index_key = NULL
  }, add = TRUE)
  build = function(A) .sparse_exact_schur_build_cpp(A,
    fixture$row_group, fixture$column_group, fixture$local_count,
    fixture$region_count, fixture$global_group, rhs = fixture$rhs)
  system = build(fixture$A)
  oracle = system
  oracle$regional_transfers = NULL
  set.seed(171020)
  for (case in seq_len(30)) {
    value = rnorm(length(system$external_columns))
    expect_equal(sparse_exact_schur_apply_preconditioner(system, value),
                  sparse_exact_schur_apply_preconditioner(oracle, value),
                  tolerance = 1e-12)
  }
  calls = 0L
  solve = sparse_exact_schur_solve_factor
  with_mocked_bindings({
    sparse_exact_schur_apply_preconditioner(system, value)
    expect_equal(calls, system$region_count + 1L)
  }, sparse_exact_schur_solve_factor = function(...) {
    calls <<- calls + 1L
    solve(...)
  }, .package = "GEModelR")
  updated = fixture$A
  updated@x = updated@x * 1.01
  changed = build(updated)
  expect_equal(changed$diagnostics$structural_cache_hits, 1L)
  expect_equal(changed$diagnostics$numeric_refactorizations, 1L)
  # A fresh owner rebuilds metadata and all factors for the updated values.
  runtime$state = sparse_make_state(list())
  fresh = build(updated)
  expect_equal(sparse_exact_schur_apply_preconditioner(changed, value),
                sparse_exact_schur_apply_preconditioner(fresh, value),
                tolerance = 1e-12)
  expect_error(sparse_exact_schur_apply_preconditioner(system, rep(Inf, 8)),
               "invalid")
})

test_that("structural cache keys cover batching while numerical factors stay fresh", {
  fixture = make_cpp_schur_fixture()
  runtime = .sparse_schur_cpp_runtime
  old = runtime$active
  runtime$active = TRUE
  runtime$state = sparse_make_state(list())
  runtime$index_key = "option-reuse"
  options_before = options(GEModelR.sparse.lu_order =
                             getOption("GEModelR.sparse.lu_order", 3L))
  on.exit(options(options_before), add = TRUE)
  on.exit({
    .sparse_cpp_release_live_factors()
    runtime$active = old
    runtime$state = NULL
    runtime$index_key = NULL
  }, add = TRUE)
  for (order in 0:3) {
    options(GEModelR.sparse.lu_order = order)
    args = list(A = fixture$A * (1 + order / 100), row_group = fixture$row_group,
      column_group = fixture$column_group, local_count = fixture$local_count,
      region_count = fixture$region_count, global_group = fixture$global_group,
      lu_order = order, panel_size = 2L + order, region_batch_size = 1L)
    first = do.call(.sparse_exact_schur_build_cpp, args)
    expect_equal(first$diagnostics$structural_cache_misses, 1L)
    if (order > 0L) {
      expect_true("panel_size" %in% first$diagnostics$structural_cache_rebuild_reasons)
    }
    second = do.call(.sparse_exact_schur_build_cpp, args)
    expect_equal(second$diagnostics$structural_cache_hits, 1L)
    value = fixture$rhs[first$external_rows]
    expect_equal(sparse_exact_schur_apply(first, value),
                  sparse_exact_schur_apply(second, value), tolerance = 1e-12)
    expect_equal(sparse_exact_schur_apply_preconditioner(first, value),
                  sparse_exact_schur_apply_preconditioner(second, value),
                  tolerance = 1e-12)
    .sparse_cpp_release_live_factors()
  }
})
