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
  levels = .serialization_strip_runtime(levels)
  list(
    engine = model$loadedEngine,
    levels = levels,
    closure = model$closure,
    shocks = model$explicitShocks,
    solution = model$solution,
    data = .serialization_strip_runtime(model$data),
    compact_output = model$compactOutput,
    memory_budget = model$memoryBudget,
    diagnostics = model$lastDiagnostics
  )
}

serializationReceiverSnapshot = function(model) {
  list(
    data = model$data,
    solution = model$solution,
    change_variables = model$changeVariables,
    variables = model$variables,
    basic_change_variables = model$basicChangeVariables,
    variable_values = model$variableValues,
    tablo_statements = model$tabloStatements,
    sparse_spec = model$sparseSpec,
    sparse_index = model$sparseIndex,
    sparse_state = if (is.environment(model$sparseState)) {
      sparse_state_data(model$sparseState)
    } else NULL,
    loaded_engine = model$loadedEngine,
    closure = model$closure,
    explicit_shocks = model$explicitShocks,
    source_data = model$sourceData,
    memory_budget = model$memoryBudget,
    diagnostics = model$lastDiagnostics,
    compact_output = model$compactOutput,
    postsim_record = model$.postsimRecord
  )
}

writeSerializationPayload = function(payload, path) {
  saveRDS(payload, path, version = 3L)
  invisible(path)
}

serializationPolicyPath = function() {
  source_path = testthat::test_path(
    "..", "..", "inst", "compatibility", "SERIALIZATION.md"
  )
  if (file.exists(source_path)) return(source_path)
  installed_path = system.file(
    "compatibility", "SERIALIZATION.md", package = "tabloToR"
  )
  if (!nzchar(installed_path)) {
    stop("Installed serialization policy is unavailable", call. = FALSE)
  }
  installed_path
}

expectSerializationRejectedWithoutMutation = function(
    payload, pattern = "Invalid logical state payload", info = NULL) {
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  writeSerializationPayload(payload, state_file)

  receiver = GEModel$new()
  receiver$closure = "receiver-sentinel"
  receiver$memoryBudget = 4096
  before = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )
  testthat::expect_error(receiver$loadState(state_file), pattern, info = info)
  after = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )
  testthat::expect_identical(after, before, info = info)
  invisible(receiver)
}

runSerializationRejectionFreshProcess = function(state_files) {
  package_root = normalizePath(
    testthat::test_path("..", ".."), mustWork = TRUE
  )
  result_file = tempfile(fileext = ".rds")
  script_file = tempfile(fileext = ".R")
  on.exit(unlink(c(result_file, script_file)), add = TRUE)

  script = c(
    "args = commandArgs(trailingOnly = TRUE)",
    "package_root = normalizePath(args[[1L]], mustWork = TRUE)",
    "state_files = args[seq.int(2L, length(args) - 1L)]",
    "result_file = args[[length(args)]]",
    "r_files = sort(list.files(file.path(package_root, 'R'), pattern = '\\\\.R$', full.names = TRUE))",
    "for (path in r_files) sys.source(path, envir = .GlobalEnv)",
    "if (!length(r_files)) {",
    "  library(tabloToR)",
    "  GEModel = get('GEModel', envir = asNamespace('tabloToR'))",
    "}",
    "results = lapply(state_files, function(state_file) {",
    "  model = GEModel$new()",
    "  model$closure = 'fresh-process-sentinel'",
    "  model$memoryBudget = 8192",
    "  before = serialize(list(closure = model$closure, memory_budget = model$memoryBudget, source = model$sourceData, engine = model$loadedEngine), NULL, version = 3L)",
    "  error = tryCatch({ model$loadState(state_file); NULL }, error = function(condition) conditionMessage(condition))",
    "  after = serialize(list(closure = model$closure, memory_budget = model$memoryBudget, source = model$sourceData, engine = model$loadedEngine), NULL, version = 3L)",
    "  list(error = error, unchanged = identical(after, before))",
    "})",
    "saveRDS(results, result_file, version = 3L)"
  )
  writeLines(script, script_file, useBytes = TRUE)
  output = system2(
    file.path(R.home("bin"), "Rscript"),
    c(
      "--vanilla", shQuote(script_file), shQuote(package_root),
      shQuote(state_files), shQuote(result_file)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status = attr(output, "status")
  if (is.null(status)) status = 0L
  if (!identical(as.integer(status), 0L)) {
    stop(paste(c("Fresh-process rejection check failed:", output),
               collapse = "\n"), call. = FALSE)
  }
  readRDS(result_file)
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
    "if (!length(r_files)) {",
    "  library(tabloToR)",
    "  package_namespace = asNamespace('tabloToR')",
    "  GEModel = get('GEModel', envir = package_namespace)",
    "  sparse_state_data = get('sparse_state_data', envir = package_namespace)",
    "  .serialization_strip_runtime = get('.serialization_strip_runtime', envir = package_namespace)",
    "}",
    "serializationModelSnapshot = function(model) {",
    "  levels = if (is.environment(model$sparseState)) sparse_state_data(model$sparseState) else model$data",
    "  levels = .serialization_strip_runtime(levels)",
    "  list(",
    "    engine = model$loadedEngine, levels = levels,",
    "    closure = model$closure, shocks = model$explicitShocks,",
    "    solution = model$solution,",
    "    data = .serialization_strip_runtime(model$data),",
    "    compact_output = model$compactOutput,",
    "    memory_budget = model$memoryBudget,",
    "    diagnostics = model$lastDiagnostics",
    "  )",
    "}",
    "model = GEModel$new()",
    "returned = model$loadState(args[[2L]])",
    "before = serializationModelSnapshot(model)",
    "cache_before = if (is.environment(model$sparseState) && !is.null(model$sparseState$.solver_cache)) length(model$sparseState$.solver_cache) else 0L",
    "model$solveModel(iter = 1, steps = 1, engine = model$loadedEngine, postsim = TRUE, diagnostics = TRUE, output = 'full', backend = 'Matrix', reduction = 'off')",
    "after = serializationModelSnapshot(model)",
    "cache_after = if (is.environment(model$sparseState) && !is.null(model$sparseState$.solver_cache)) length(model$sparseState$.solver_cache) else 0L",
    "saveRDS(list(returned_self = identical(returned, model), before = before, after = after, cache_before = cache_before, cache_after = cache_after), args[[3L]], version = 3L)"
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
