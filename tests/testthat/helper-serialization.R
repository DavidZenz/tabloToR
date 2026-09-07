serializationPayloadFields = function() {
  c(
    "schema", "schema_version", "source", "engine", "levels",
    "closure", "shocks", "accepted", "memory_budget", "diagnostics"
  )
}

serializationContainsRuntimeState = function(value) {
  if (is.environment(value) || is.function(value) ||
      typeof(value) == "externalptr" || is.factor(value)) {
    return(TRUE)
  }
  if (!is.list(value)) return(FALSE)
  any(vapply(value, serializationContainsRuntimeState, logical(1)))
}

serializationModelSnapshot = function(model) {
  levels = if (is.environment(model$sparseState)) {
    sparse_state_data(model$sparseState)
  } else {
    model$data
  }
  list(
    engine = model$loadedEngine,
    levels = levels,
    closure = model$closure,
    shocks = model$explicitShocks,
    solution = model$solution,
    data = model$data,
    compact_output = model$compactOutput,
    memory_budget = model$memoryBudget,
    diagnostics = model$lastDiagnostics
  )
}

runSerializationFreshProcess = function(state_file) {
  package_root = normalizePath(
    testthat::test_path("..", ".."), mustWork = TRUE
  )
  result_file = tempfile(fileext = ".rds")
  script_file = tempfile(fileext = ".R")
  on.exit(unlink(c(result_file, script_file)), add = TRUE)

  script = c(
    "args = commandArgs(trailingOnly = TRUE)",
    "package_root = normalizePath(args[[1L]], mustWork = TRUE)",
    "r_files = sort(list.files(file.path(package_root, 'R'), pattern = '\\\\.R$', full.names = TRUE))",
    "for (path in r_files) sys.source(path, envir = .GlobalEnv)",
    "sys.source(file.path(package_root, 'tests', 'testthat', 'helper-serialization.R'), envir = .GlobalEnv)",
    "model = GEModel$new()",
    "returned = model$loadState(args[[2L]])",
    "before = serializationModelSnapshot(model)",
    "cache_before = if (is.environment(model$sparseState) && !is.null(model$sparseState$.solver_cache)) length(model$sparseState$.solver_cache) else 0L",
    "model$solveModel(iter = 1, steps = 1, engine = model$loadedEngine, postsim = TRUE, diagnostics = TRUE, output = 'full', backend = 'Matrix', reduction = 'off')",
    "after = serializationModelSnapshot(model)",
    "saveRDS(list(returned_self = identical(returned, model), before = before, after = after, cache_before = cache_before), args[[3L]], version = 3L)"
  )
  writeLines(script, script_file, useBytes = TRUE)
  output = system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      "--vanilla", shQuote(script_file), shQuote(package_root),
      shQuote(state_file), shQuote(result_file)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status = attr(output, "status")
  if (is.null(status)) status = 0L
  if (!identical(as.integer(status), 0L)) {
    stop(paste(c("Fresh-process restore failed:", output), collapse = "\n"),
         call. = FALSE)
  }
  readRDS(result_file)
}
