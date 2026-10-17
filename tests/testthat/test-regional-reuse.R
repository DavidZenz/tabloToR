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
