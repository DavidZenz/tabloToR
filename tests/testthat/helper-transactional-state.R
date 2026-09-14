transactionalModelSnapshot = function(model, include_diagnostics = TRUE) {
  fields = list(
    closure = model$closure,
    shocks = model$shocks,
    explicitShocks = model$explicitShocks,
    variableValues = model$variableValues,
    data = model$data,
    solution = model$solution,
    compactOutput = model$compactOutput,
    loadedEngine = model$loadedEngine,
    sparseState = if (is.environment(model$sparseState)) {
      sparse_state_data(model$sparseState)
    } else NULL,
    sparseSolverCache = if (is.environment(model$sparseState) &&
                            !is.null(model$sparseState$.solver_cache)) {
      model$sparseState$.solver_cache
    } else list(),

    sparseIndex = model$sparseIndex,
    postsimRecord = if (".postsimRecord" %in% names(GEModel$fields())) {
      model$.postsimRecord
    } else list()
  )
  if (isTRUE(include_diagnostics)) {
    fields$lastDiagnostics = model$lastDiagnostics
  }
  fields
}

expectTransactionalStateIdentical = function(before, model,
                                              include_diagnostics = FALSE) {
  after = transactionalModelSnapshot(
    model, include_diagnostics = include_diagnostics
  )
  testthat::expect_identical(
    serialize(after, NULL, version = 3L),
    serialize(before, NULL, version = 3L)
  )
}

localTransactionFault = function(callback, env = parent.frame()) {
  old = getOption("tabloToR.transaction.fault")
  options(tabloToR.transaction.fault = callback)
  withr::defer(options(tabloToR.transaction.fault = old), envir = env)
  invisible(callback)
}

failTransactionAt = function(phase, occurrence = 1L, env = parent.frame()) {
  seen = 0L
  localTransactionFault(function(actual, context) {
    if (identical(actual, phase)) {
      seen <<- seen + 1L
      if (seen == occurrence) {
        stop(sprintf("injected %s failure", phase), call. = FALSE)
      }
    }
    invisible(NULL)
  }, env = env)
}

recordTransactionPhases = function(fail_phase = NULL, occurrence = 1L,
                                    env = parent.frame()) {
  phases = character()
  seen = 0L
  localTransactionFault(function(actual, context) {
    phases <<- c(phases, actual)
    if (!is.null(fail_phase) && identical(actual, fail_phase)) {
      seen <<- seen + 1L
      if (seen == occurrence) {
        stop(sprintf("injected %s failure", actual), call. = FALSE)
      }
    }
    invisible(NULL)
  }, env = env)
  function() phases
}

expectedPublicOptionReplacements = function() {
  c(
    "tabloToR.serialization.max_bytes" =
      "GEModelR.serialization.max_bytes",
    "tabloToR.serialization.max_elements" =
      "GEModelR.serialization.max_elements",
    "tabloToR.sparse.lu_order" = "GEModelR.sparse.lu_order",
    "tabloToR.sparse.schur_cpp_threads" =
      "GEModelR.sparse.schur_cpp_threads",
    "tabloToR.sparse.schur_max_iterations" =
      "GEModelR.sparse.schur_max_iterations",
    "tabloToR.sparse.schur_panel_size" =
      "GEModelR.sparse.schur_panel_size",
    "tabloToR.sparse.schur_refinement_iterations" =
      "GEModelR.sparse.schur_refinement_iterations",
    "tabloToR.sparse.schur_region_batch_size" =
      "GEModelR.sparse.schur_region_batch_size",
    "tabloToR.sparse.schur_restart" =
      "GEModelR.sparse.schur_restart",
    "tabloToR.sparse.schur_tolerance" =
      "GEModelR.sparse.schur_tolerance",
    "tabloToR.sparse.structured_residual_tolerance" =
      "GEModelR.sparse.structured_residual_tolerance",
    "tabloToR.sparse.suite_sparse_ordering" =
      "GEModelR.sparse.suite_sparse_ordering"
  )
}

optionReplacementRegistryPath = function() {
  candidates = c(
    system.file(
      "migration", "option-replacements.dcf", package = "GEModelR"
    ),
    testthat::test_path(
      "..", "..", "inst", "migration", "option-replacements.dcf"
    )
  )
  candidates = candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) {
    stop("Missing public option replacement registry", call. = FALSE)
  }
  normalizePath(candidates[[1L]], mustWork = TRUE)
}

expectOldPublicOptionRejected = function(old_key, replacement, operation,
                                          before = NULL,
                                          snapshot = NULL) {
  existing = old_key %in% names(options())
  old_value = getOption(old_key)
  do.call(options, stats::setNames(list(TRUE), old_key))
  on.exit({
    value = if (existing) list(old_value) else list(NULL)
    do.call(options, stats::setNames(value, old_key))
  }, add = TRUE)

  error = tryCatch({
    operation()
    NULL
  }, error = identity)
  testthat::expect_true(inherits(error, "error"), info = old_key)
  if (!inherits(error, "error")) return(invisible(error))
  message = conditionMessage(error)
  testthat::expect_match(message, old_key, fixed = TRUE, info = old_key)
  testthat::expect_match(message, replacement, fixed = TRUE, info = old_key)
  testthat::expect_match(message, "MIGRATION.md", fixed = TRUE,
                         info = old_key)
  if (!is.null(before) && is.function(snapshot)) {
    testthat::expect_identical(
      serialize(snapshot(), NULL, version = 3L),
      serialize(before, NULL, version = 3L),
      info = old_key
    )
  }
  invisible(error)
}
