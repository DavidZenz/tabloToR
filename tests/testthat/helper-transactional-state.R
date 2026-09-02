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
    sparseIndex = model$sparseIndex
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
