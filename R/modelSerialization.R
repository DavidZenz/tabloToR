# Versioned portable logical-state serialization for GEModel.

.serialization_schema = "gemodel-logical-state"
.serialization_schema_version = 1L

.serialization_max_bytes = function() {
  value = getOption("tabloToR.serialization.max_bytes", 256 * 1024^2)
  value = suppressWarnings(as.numeric(value)[1L])
  if (!is.finite(value) || value <= 0) 256 * 1024^2 else value
}

.serialization_max_elements = function() {
  value = getOption("tabloToR.serialization.max_elements", 50000000)
  value = suppressWarnings(as.numeric(value)[1L])
  if (!is.finite(value) || value <= 0) 50000000 else value
}

.serialization_stop = function(message) {
  stop(sprintf("Invalid logical state payload: %s", message), call. = FALSE)
}

.serialization_object_fingerprint = function(value) {
  bytes = serialize(value, NULL, version = 3L)
  path = tempfile("tabloToR-fingerprint-")
  connection = file(path, open = "wb")
  writeBin(bytes, connection)
  close(connection)
  fingerprint = unname(tools::md5sum(path))
  unlink(path)
  fingerprint
}

.serialization_capture_tablo = function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path) || !file.exists(path)) {
    stop("TABLO source must be one existing file", call. = FALSE)
  }
  normalized = normalizePath(path, mustWork = TRUE)
  size = file.info(normalized)$size
  if (is.na(size) || size < 1 || size > .serialization_max_bytes()) {
    stop("TABLO source is empty or exceeds the serialization size limit",
         call. = FALSE)
  }
  connection = file(normalized, open = "rb")
  source = readBin(connection, what = "raw", n = as.integer(size))
  close(connection)
  list(
    name = basename(normalized),
    tablo_source = source,
    tablo_fingerprint = .serialization_object_fingerprint(source)
  )
}

.serialization_validate_names = function(value, expected, context) {
  actual = names(value)
  if (is.null(actual) || anyDuplicated(actual) ||
      !setequal(actual, expected) || length(actual) != length(expected)) {
    missing = setdiff(expected, actual)
    unknown = setdiff(actual, expected)
    detail = c(
      if (length(missing)) sprintf("missing: %s", paste(missing, collapse = ", ")),
      if (length(unknown)) sprintf("unknown: %s", paste(unknown, collapse = ", "))
    )
    if (!length(detail)) detail = "duplicate or unnamed fields"
    .serialization_stop(sprintf(
      "%s fields are not allowlisted (%s)", context,
      paste(detail, collapse = "; ")
    ))
  }
  invisible(TRUE)
}

.serialization_validate_portable = function(value, path = "payload",
                                               depth = 0L) {
  if (depth > 64L) {
    .serialization_stop(sprintf("%s exceeds the nesting limit", path))
  }
  if (is.null(value)) return(invisible(TRUE))
  if (is.environment(value) || is.function(value) ||
      typeof(value) == "externalptr" || is.factor(value) || is.object(value)) {
    allowed_array = is.array(value) &&
      all(class(value) %in% c("matrix", "array"))
    if (!allowed_array) {
      .serialization_stop(sprintf(
        "%s contains a non-portable class or runtime object", path
      ))
    }
  }
  if (is.pairlist(value) || is.language(value) || is.symbol(value) ||
      is.expression(value) || inherits(value, "connection")) {
    .serialization_stop(sprintf("%s contains executable runtime state", path))
  }
  if (is.list(value)) {
    if (length(value) > .serialization_max_elements()) {
      .serialization_stop(sprintf("%s exceeds the element limit", path))
    }
    value_names = names(value)
    for (index in seq_along(value)) {
      label = if (!is.null(value_names) && nzchar(value_names[[index]])) {
        value_names[[index]]
      } else as.character(index)
      .serialization_validate_portable(
        value[[index]], paste(path, label, sep = "$"), depth + 1L
      )
    }
    return(invisible(TRUE))
  }
  if (!is.null(value) &&
      !typeof(value) %in% c("logical", "integer", "double", "character", "raw")) {
    .serialization_stop(sprintf("%s has unsupported type %s", path,
                                typeof(value)))
  }
  if (length(value) > .serialization_max_elements()) {
    .serialization_stop(sprintf("%s exceeds the element limit", path))
  }
  dimensions = dim(value)
  if (!is.null(dimensions)) {
    if (!is.numeric(dimensions) || anyNA(dimensions) ||
        any(dimensions < 0) || prod(as.double(dimensions)) != length(value)) {
      .serialization_stop(sprintf("%s has invalid dimensions", path))
    }
  }
  if (is.numeric(value) && any(is.infinite(value))) {
    .serialization_stop(sprintf("%s contains non-finite numeric values", path))
  }
  invisible(TRUE)
}

.serialization_strip_runtime = function(value) {
  if (!is.list(value)) return(value)
  value_names = names(value)
  keep = !vapply(value, function(item) {
    is.environment(item) || is.function(item) ||
      typeof(item) == "externalptr"
  }, logical(1))
  value = value[keep]
  if (!is.null(value_names)) names(value) = value_names[keep]
  for (index in seq_along(value)) {
    value[[index]] = .serialization_strip_runtime(value[[index]])
  }
  value
}

.serialization_model_shocks = function(model) {
  explicit = model$explicitShocks
  if (is.list(explicit) && length(explicit$labels)) {
    return(sparse_normalize_shocks(explicit))
  }
  if (identical(model$loadedEngine, "sparse") &&
      is.environment(model$sparseState) && length(model$sparseIndex)) {
    resolved = sparse_resolve_shocks(
      model, model$sparseState, model$sparseIndex
    )
    return(list(
      labels = as.character(resolved$labels),
      values = as.numeric(resolved$values)
    ))
  }
  sparse_normalize_shocks(model$shocks)
}

.build_logical_state_payload = function(model) {
  if (!inherits(model, "GEModel")) {
    stop("model must be a GEModel reference object", call. = FALSE)
  }
  source = model$sourceData
  source_fields = c(
    "name", "tablo_source", "tablo_fingerprint", "loaded_data",
    "data_fingerprint"
  )
  if (!is.list(source) || !setequal(names(source), source_fields)) {
    stop(
      paste(
        "Portable source identity is unavailable; reload the TABLO source",
        "and data before calling saveState()"
      ),
      call. = FALSE
    )
  }
  levels = if (identical(model$loadedEngine, "sparse") &&
               is.environment(model$sparseState)) {
    sparse_state_data(model$sparseState)
  } else {
    model$data
  }
  levels = .serialization_strip_runtime(levels)
  payload = list(
    schema = .serialization_schema,
    schema_version = .serialization_schema_version,
    source = source[source_fields],
    engine = model$loadedEngine,
    levels = levels,
    closure = model$closure,
    shocks = .serialization_model_shocks(model),
    accepted = list(
      solution = model$solution,
      data = .serialization_strip_runtime(model$data),
      compact_output = model$compactOutput
    ),
    memory_budget = model$memoryBudget,
    diagnostics = model$lastDiagnostics
  )
  .validate_logical_state_payload(payload)
  payload
}

.validate_logical_state_payload = function(
    payload, max_bytes = .serialization_max_bytes()) {
  if (!is.list(payload) || is.object(payload)) {
    .serialization_stop("top level must be an unclassed list")
  }
  expected = c(
    "schema", "schema_version", "source", "engine", "levels",
    "closure", "shocks", "accepted", "memory_budget", "diagnostics"
  )
  .serialization_validate_names(payload, expected, "top-level")
  if (!is.character(payload$schema) || length(payload$schema) != 1L ||
      !identical(payload$schema, .serialization_schema)) {
    .serialization_stop("schema identifier is unsupported")
  }
  if (!is.integer(payload$schema_version) ||
      !identical(payload$schema_version, .serialization_schema_version)) {
    .serialization_stop("schema version is unsupported")
  }
  if (!is.character(payload$engine) || length(payload$engine) != 1L ||
      is.na(payload$engine) ||
      !payload$engine %in% c("legacy", "sparse")) {
    .serialization_stop("engine must be exactly legacy or sparse")
  }
  if (!is.character(payload$closure) || anyNA(payload$closure)) {
    .serialization_stop("closure must be a non-missing character vector")
  }
  if (!is.list(payload$source) || is.object(payload$source)) {
    .serialization_stop("source must be an unclassed list")
  }
  source_fields = c(
    "name", "tablo_source", "tablo_fingerprint", "loaded_data",
    "data_fingerprint"
  )
  .serialization_validate_names(payload$source, source_fields, "source")
  source = payload$source
  if (!is.character(source$name) || length(source$name) != 1L ||
      is.na(source$name) || !nzchar(source$name)) {
    .serialization_stop("source name must be one non-empty string")
  }
  if (!is.raw(source$tablo_source) || !length(source$tablo_source)) {
    .serialization_stop("TABLO source must be non-empty raw content")
  }
  fingerprint_pattern = "^[[:xdigit:]]{32}$"
  fingerprints = c(source$tablo_fingerprint, source$data_fingerprint)
  if (!is.character(fingerprints) || length(fingerprints) != 2L ||
      anyNA(fingerprints) || any(!grepl(fingerprint_pattern, fingerprints))) {
    .serialization_stop("source fingerprints must be 32 hexadecimal characters")
  }
  if (!identical(
    source$tablo_fingerprint,
    .serialization_object_fingerprint(source$tablo_source)
  )) {
    .serialization_stop("TABLO source fingerprint mismatch")
  }
  if (!is.list(source$loaded_data) || is.object(source$loaded_data)) {
    .serialization_stop("loaded source data must be an unclassed list")
  }
  if (!identical(
    source$data_fingerprint,
    .serialization_object_fingerprint(source$loaded_data)
  )) {
    .serialization_stop("loaded source data fingerprint mismatch")
  }
  if (!is.list(payload$levels) || is.object(payload$levels)) {
    .serialization_stop("levels must be an unclassed list")
  }
  if (!is.list(payload$shocks) || is.object(payload$shocks)) {
    .serialization_stop("shocks must be an unclassed list")
  }
  .serialization_validate_names(
    payload$shocks, c("labels", "values"), "shocks"
  )
  if (!is.character(payload$shocks$labels) ||
      !is.double(payload$shocks$values) ||
      length(payload$shocks$labels) != length(payload$shocks$values) ||
      anyNA(payload$shocks$labels) || any(!nzchar(payload$shocks$labels)) ||
      anyDuplicated(payload$shocks$labels) ||
      any(!is.finite(payload$shocks$values)) ||
      any(payload$shocks$values == 0)) {
    .serialization_stop("shocks must contain unique labels and finite nonzero values")
  }
  if (!is.list(payload$accepted) || is.object(payload$accepted)) {
    .serialization_stop("accepted state must be an unclassed list")
  }
  .serialization_validate_names(
    payload$accepted, c("solution", "data", "compact_output"),
    "accepted state"
  )
  if (!is.numeric(payload$accepted$solution) ||
      any(!is.finite(payload$accepted$solution))) {
    .serialization_stop("accepted solution must be finite numeric data")
  }
  if (!is.list(payload$accepted$data) ||
      !is.list(payload$accepted$compact_output)) {
    .serialization_stop("accepted outputs must be lists")
  }
  budget = payload$memory_budget
  if (!is.numeric(budget) || length(budget) > 1L ||
      (length(budget) && (!is.finite(budget) || budget <= 0))) {
    .serialization_stop("memory budget must be empty or one positive number")
  }
  if (!is.list(payload$diagnostics) || is.object(payload$diagnostics)) {
    .serialization_stop("diagnostics must be an unclassed list")
  }
  .serialization_validate_portable(payload)
  serialized_size = length(serialize(payload, NULL, version = 3L))
  if (serialized_size > max_bytes || as.numeric(object.size(payload)) > max_bytes) {
    .serialization_stop("payload exceeds the configured size limit")
  }
  invisible(payload)
}

.restore_logical_state_payload = function(payload) {
  .validate_logical_state_payload(payload)
  suffix = tools::file_ext(payload$source$name)
  if (!nzchar(suffix)) suffix = "tab"
  path = tempfile("tabloToR-restore-", fileext = paste0(".", suffix))
  connection = file(path, open = "wb")
  writeBin(payload$source$tablo_source, connection)
  close(connection)
  on.exit(unlink(path), add = TRUE)

  restored = GEModel$new()
  restored$loadTablo(path)
  restored$setClosure(payload$closure)
  restored$loadData(payload$source$loaded_data, engine = payload$engine)
  restored$sourceData = payload$source
  if (identical(payload$engine, "sparse")) {
    rebuilt_levels = sparse_state_data(restored$sparseState)
    for (name in names(payload$levels)) {
      rebuilt_levels[[name]] = payload$levels[[name]]
    }
    restored$sparseState = sparse_make_state(rebuilt_levels)
  }
  restored$data = payload$accepted$data
  restored$solution = payload$accepted$solution
  restored$compactOutput = payload$accepted$compact_output
  restored$explicitShocks = payload$shocks
  restored$shocks = setNames(
    payload$shocks$values, payload$shocks$labels
  )
  restored$variableValues = list()
  restored$memoryBudget = payload$memory_budget
  restored$lastDiagnostics = payload$diagnostics
  restored$loadedEngine = payload$engine
  restored$.postsimRecord = list()
  restored
}

.install_restored_logical_state = function(model, restored) {
  fields = names(GEModel$fields())
  values = lapply(fields, function(field) restored[[field]])
  names(values) = fields
  for (field in fields) model[[field]] = values[[field]]
  invisible(model)
}
