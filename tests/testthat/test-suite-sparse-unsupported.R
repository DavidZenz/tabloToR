test_that("SuiteSparse remains recognized but its installed preflight is unavailable", {
  expect_true("SuiteSparse" %in% ls(.sparse_backend_registry))
  expect_false(sparse_suite_sparse_available())
  # Host probes or a stale availability override cannot enable this backend.
  testthat::local_mocked_bindings(
    sparse_suite_sparse_available = function() TRUE,
    .package = "GEModelR"
  )
  error = tryCatch(.sparse_backend_preflight("SuiteSparse"), error = identity)
  expect_s3_class(error, "GEModelR_capability_error")
  expect_identical(error$requested_backend, "SuiteSparse")
  expect_identical(error$failure_phase, "capability-preflight")
  expect_match(conditionMessage(error), "SuiteSparse.*unavailable")
  expect_match(conditionMessage(error), 'backend="Matrix"', fixed = TRUE)
  expect_match(error$remediation$action, 'backend="Matrix"', fixed = TRUE)
})

test_that("SuiteSparse rejects predecessor ordering options before capability checks", {
  replacements = expectedPublicOptionReplacements()
  old_key = names(replacements)[endsWith(names(replacements), ".suite_sparse_ordering")]
  expect_length(old_key, 1L)
  replacement = replacements[[old_key]]
  withr::local_options(stats::setNames(list("amd"), old_key))
  unavailable_calls = 0L
  testthat::local_mocked_bindings(
    .sparse_backend_unavailable = function(...) {
      unavailable_calls <<- unavailable_calls + 1L
      stop("unexpected capability rejection before migration validation")
    },
    .package = "GEModelR"
  )
  operations = list(
    function() .sparse_backend_preflight("SuiteSparse"),
    function() sparse_suite_sparse_solver(stop("unexpected matrix access"),
                                          stop("unexpected RHS access")),
    function() sparse_suite_sparse_ordering()
  )
  for (operation in operations) {
    error = tryCatch(operation(), error = identity)
    expect_s3_class(error, "error")
    expect_match(conditionMessage(error), old_key, fixed = TRUE)
    expect_match(conditionMessage(error), replacement, fixed = TRUE)
    expect_match(conditionMessage(error), "MIGRATION.md", fixed = TRUE)
  }
  expect_identical(unavailable_calls, 0L)
})

test_that("public SuiteSparse requests fail before emission, compilation or state commit", {
  for (diagnostics in c(FALSE, TRUE)) {
    model = make_synthetic_model()
    model$setShocks(setNames(c(5, 1, 2), c("a[r1]", "b[r1]", "b[r2]")))
    before = transactionalModelSnapshot(model, include_diagnostics = FALSE)
    emission_calls = 0L
    compiler_calls = 0L
    commits = 0L
    testthat::local_mocked_bindings(
      sparse_emit_system = function(...) {
        emission_calls <<- emission_calls + 1L
        stop("unexpected matrix emission")
      },
      .package = "GEModelR"
    )
    testthat::local_mocked_bindings(
      sourceCpp = function(...) {
        compiler_calls <<- compiler_calls + 1L
        stop("unexpected runtime compilation")
      },
      .package = "Rcpp"
    )
    localTransactionFault(function(phase, context) {
      if (identical(phase, "commit-accepted-state")) commits <<- commits + 1L
      invisible(NULL)
    })
    error = tryCatch(model$solveModel(
      iter = 1, steps = 1, engine = "sparse", backend = "SuiteSparse",
      postsim = FALSE, diagnostics = diagnostics, reduction = "off"
    ), error = identity)
    expect_s3_class(error, "GEModelR_capability_error")
    expect_identical(error$requested_engine, "sparse")
    expect_identical(error$requested_backend, "SuiteSparse")
    expect_identical(error$failure_phase, "capability-preflight")
    expect_false(error$accepted_numerical_state)
    expect_false(error$retryable_postsim)
    expect_match(conditionMessage(error), "SuiteSparse.*unavailable")
    expect_match(conditionMessage(error), 'backend="Matrix"', fixed = TRUE)
    expect_match(error$remediation$action, 'backend="Matrix"', fixed = TRUE)
    expect_identical(emission_calls, 0L)
    expect_identical(compiler_calls, 0L)
    expect_identical(commits, 0L)
    expectTransactionalStateIdentical(before, model)
    # Failure diagnostics are published separately from numerical/model state.
    expect_identical(model$lastDiagnostics$status, "capability_failed")
    expect_identical(model$lastDiagnostics$requested_backend, "SuiteSparse")
    expect_false(model$lastDiagnostics$accepted_numerical_state)
  }
})
