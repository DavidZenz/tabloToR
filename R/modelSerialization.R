# Versioned portable logical-state serialization for GEModel.

.serialization_schema = "gemodel-logical-state"
.serialization_schema_version = 1L
.serialization_lineage_registry_fields = function() {
  c(
    "Schema", "Record-Id", "Package-Name", "Package-Version",
    "Source-Scope", "Source-File-Count", "Source-Fingerprint",
    "Source-Locator-Type", "Source-Locator", "Source-Immutable-Id",
    "Fixture-Path", "Fixture-Digest-Algorithm", "Fixture-Digest",
    "Tablo-Path", "Tablo-Digest-Algorithm", "Tablo-Digest",
    "Data-Fingerprint", "Install-Command", "Conversion-Command",
    "Lineage-Review-State", "Reachability-Review-State", "Rationale"
  )
}
.serialization_source_path = function(relative) {
  if (!is.character(relative) || length(relative) != 1L ||
      is.na(relative) || !nzchar(relative)) {
    return(character())
  }
  current = normalizePath(getwd(), mustWork = TRUE)
  roots = character()
  repeat {
    roots = c(roots, current)
    parent = dirname(current)
    if (identical(parent, current)) break
    current = parent
  }
  candidates = file.path(roots, relative)
  matches = candidates[
    file.exists(candidates) & !dir.exists(candidates)
  ]
  if (!length(matches)) return(character())
  normalizePath(matches[[1L]], mustWork = TRUE)
}


.serialization_current_package_metadata = function() {
  package_environment = environment(.serialization_current_package_metadata)
  package_name = tryCatch(
    getNamespaceName(package_environment),
    error = function(error) character()
  )
  package_version = if (length(package_name) == 1L &&
                        !is.na(package_name) && nzchar(package_name)) {
    tryCatch(
      as.character(getNamespaceVersion(package_name)),
      error = function(error) character()
    )
  } else character()

  if (length(package_name) != 1L || is.na(package_name) ||
      !nzchar(package_name) || length(package_version) != 1L ||
      is.na(package_version) || !nzchar(package_version)) {
    description_candidates = .serialization_source_path("DESCRIPTION")
    if (!length(description_candidates)) {
      .serialization_stop("current package metadata is unavailable")
    }
    description = tryCatch(
      read.dcf(description_candidates[[1L]], fields = c(
        "Package", "Version"
      )),
      error = function(error) {
        .serialization_stop(sprintf(
          "current package metadata is invalid: %s",
          conditionMessage(error)
        ))
      }
    )
    package_name = unname(description[1L, "Package"])
    package_version = unname(description[1L, "Version"])
  }

  values = c(name = package_name, version = package_version)
  if (!is.character(values) || length(values) != 2L ||
      anyNA(values) || any(!nzchar(values)) ||
      any(values != trimws(values))) {
    .serialization_stop("current package metadata must be exact scalars")
  }
  as.list(values)
}

.serialization_lineage_registry_path = function(package_name = NULL) {
  installed_path = character()
  if (is.character(package_name) && length(package_name) == 1L &&
      !is.na(package_name) && nzchar(package_name)) {
    installed_path = system.file(
      "migration", "predecessor-fingerprints.dcf",
      package = package_name
    )
  }
  source_path = .serialization_source_path(file.path(
    "inst", "migration", "predecessor-fingerprints.dcf"
  ))
  candidates = c(installed_path, source_path)
  candidates = candidates[
    nzchar(candidates) & file.exists(candidates) & !dir.exists(candidates)
  ]
  if (!length(candidates)) {
    .serialization_stop("package lineage registry is unavailable")
  }
  normalizePath(candidates[[1L]], mustWork = TRUE)
}

.serialization_package_lineage_registry = function(path = NULL) {
  metadata = .serialization_current_package_metadata()
  if (is.null(path)) {
    path = .serialization_lineage_registry_path(metadata$name)
  }
  value = tryCatch(
    read.dcf(path),
    error = function(error) {
      .serialization_stop(sprintf(
        "package lineage registry is invalid: %s",
        conditionMessage(error)
      ))
    }
  )
  value = as.data.frame(
    value, stringsAsFactors = FALSE, check.names = FALSE
  )
  expected = .serialization_lineage_registry_fields()
  if (!identical(names(value), expected) || nrow(value) != 1L) {
    .serialization_stop(
      "package lineage registry does not match the strict schema"
    )
  }
  value[] = lapply(value, as.character)
  if (anyNA(value) || any(!nzchar(as.matrix(value))) ||
      any(as.matrix(value) != trimws(as.matrix(value)))) {
    .serialization_stop(
      "package lineage registry must contain exact non-empty values"
    )
  }
  if (!identical(
    unname(value[["Schema"]]), "gemodelr-predecessor-lineage-v1"
  )) {
    .serialization_stop("package lineage registry schema is unsupported")
  }
  if (anyDuplicated(value[["Record-Id"]]) ||
      anyDuplicated(paste(
        value[["Package-Name"]], value[["Package-Version"]],
        value[["Source-Fingerprint"]], sep = "\r"
      ))) {
    .serialization_stop("package lineage registry contains duplicates")
  }
  source_counts = suppressWarnings(as.integer(
    value[["Source-File-Count"]]
  ))
  if (anyNA(source_counts) || any(source_counts < 1L) ||
      any(as.character(source_counts) !=
          value[["Source-File-Count"]])) {
    .serialization_stop("package lineage source count is malformed")
  }
  if (any(!grepl(
    "^[0-9a-f]{32}$", value[["Source-Fingerprint"]]
  ))) {
    .serialization_stop("package lineage source fingerprint is malformed")
  }
  if (any(value[["Lineage-Review-State"]] != "reviewed")) {
    .serialization_stop("package lineage is not reviewed")
  }
  if (any(value[["Reachability-Review-State"]] != "approved")) {
    .serialization_stop("package lineage reachability is not approved")
  }
  value
}

.serialization_current_package_lineage = function() {
  metadata = .serialization_current_package_metadata()
  registry = .serialization_package_lineage_registry()
  list(
    name = metadata$name,
    version = metadata$version,
    source_fingerprint = unname(registry[["Source-Fingerprint"]])
  )
}

.serialization_validate_package_lineage = function(lineage) {
  if (!is.list(lineage) || is.object(lineage)) {
    .serialization_stop("package lineage must be an unclassed list")
  }
  fields = c("name", "version", "source_fingerprint")
  .serialization_validate_names(lineage, fields, "package lineage")
  values = lineage[fields]
  valid_scalars = vapply(values, function(value) {
    is.character(value) && length(value) == 1L &&
      !is.na(value) && nzchar(value) && identical(value, trimws(value))
  }, logical(1))
  if (!all(valid_scalars)) {
    .serialization_stop(
      "package lineage fields must be exact non-empty character scalars"
    )
  }
  if (!grepl("^[0-9a-f]{32}$", lineage$source_fingerprint)) {
    .serialization_stop("package lineage source fingerprint is malformed")
  }

  current = .serialization_current_package_lineage()
  if (identical(lineage, current)) {
    return(invisible("current"))
  }

  registry = .serialization_package_lineage_registry()
  matches = registry[["Package-Name"]] == lineage$name &
    registry[["Package-Version"]] == lineage$version &
    registry[["Source-Fingerprint"]] == lineage$source_fingerprint
  if (sum(matches) != 1L) {
    .serialization_stop("package lineage is not allowlisted")
  }
  invisible("predecessor")
}

.serialization_guard_old_options = function() {
  current = c(
    "GEModelR.serialization.max_bytes",
    "GEModelR.serialization.max_elements"
  )
  old = names(.identity_public_option_replacements)[
    .identity_public_option_replacements %in% current
  ]
  .identity_guard_old_options(old)
}


.serialization_max_bytes = function() {
  value = getOption("GEModelR.serialization.max_bytes", 256 * 1024^2)
  value = suppressWarnings(as.numeric(value)[1L])
  if (!is.finite(value) || value <= 0) 256 * 1024^2 else value
}

.serialization_max_elements = function() {
  value = getOption("GEModelR.serialization.max_elements", 50000000)
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
  invalid_names = is.null(actual) || !is.character(actual) ||
    length(actual) != length(expected) || anyNA(actual) ||
    any(!nzchar(actual)) || anyDuplicated(actual)
  if (invalid_names || !setequal(actual, expected)) {
    missing = if (is.null(actual)) expected else setdiff(expected, actual)
    unknown = if (is.null(actual)) character() else setdiff(actual, expected)
    detail = c(
      if (length(missing)) sprintf("missing: %s", paste(missing, collapse = ", ")),
      if (length(unknown)) sprintf("unknown: %s", paste(unknown, collapse = ", "))
    )
    if (!length(detail)) detail = "duplicate, missing, or unnamed fields"
    .serialization_stop(sprintf(
      "%s fields are not allowlisted (%s)", context,
      paste(detail, collapse = "; ")
    ))
  }
  invisible(TRUE)
}

.serialization_validate_attributes = function(value, path) {
  value_attributes = attributes(value)
  if (is.null(value_attributes)) return(invisible(TRUE))
  allowed = c("names", if (is.array(value)) c("dim", "dimnames"))
  unknown = setdiff(names(value_attributes), allowed)
  if (length(unknown)) {
    .serialization_stop(sprintf(
      "%s has unsupported attribute(s): %s",
      path, paste(unknown, collapse = ", ")
    ))
  }
  value_names = names(value)
  if (!is.null(value_names) &&
      (!is.character(value_names) || length(value_names) != length(value) ||
       anyNA(value_names))) {
    .serialization_stop(sprintf("%s has invalid names", path))
  }
  dimensions = dim(value)
  if (!is.null(dimensions)) {
    if (!is.integer(dimensions) || anyNA(dimensions) ||
        any(dimensions < 0L) ||
        prod(as.double(dimensions)) != length(value)) {
      .serialization_stop(sprintf("%s has invalid dimensions", path))
    }
    dimension_names = dimnames(value)
    if (!is.null(dimension_names)) {
      if (!is.list(dimension_names) ||
          length(dimension_names) != length(dimensions)) {
        .serialization_stop(sprintf("%s has invalid dimnames", path))
      }
      for (index in seq_along(dimension_names)) {
        labels = dimension_names[[index]]
        if (!is.null(labels) &&
            (!is.character(labels) ||
             length(labels) != dimensions[[index]] || anyNA(labels))) {
          .serialization_stop(sprintf("%s has invalid dimnames", path))
        }
      }
      dimension_labels = names(dimension_names)
      if (!is.null(dimension_labels) &&
          (!is.character(dimension_labels) ||
           length(dimension_labels) != length(dimensions) ||
           anyNA(dimension_labels))) {
        .serialization_stop(sprintf("%s has invalid dimension names", path))
      }
    }
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
  .serialization_validate_attributes(value, path)
  if (is.list(value)) {
    if (length(value) > .serialization_max_elements()) {
      .serialization_stop(sprintf("%s exceeds the element limit", path))
    }
    value_names = names(value)
    if (!is.null(value_names)) {
      named = nzchar(value_names)
      if (anyDuplicated(value_names[named])) {
        .serialization_stop(sprintf("%s has duplicate named fields", path))
      }
    }
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
  if (!typeof(value) %in% c(
    "logical", "integer", "double", "character", "raw"
  )) {
    .serialization_stop(sprintf("%s has unsupported type %s", path,
                                typeof(value)))
  }
  if (length(value) > .serialization_max_elements()) {
    .serialization_stop(sprintf("%s exceeds the element limit", path))
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

.serialization_promote_reconstructed_fields = function(value, fields) {
  if (!is.list(value) || !length(fields)) return(value)
  fields = intersect(fields, names(value))
  for (field in fields) {
    leaf = value[[field]]
    if (is.logical(leaf) || is.integer(leaf)) {
      leaf_attributes = attributes(leaf)
      leaf = as.double(leaf)
      attributes(leaf) = leaf_attributes
      value[[field]] = leaf
    }
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

.serialization_atomic_save_rds = function(object, file,
                                         replace = file.rename) {
  destination = path.expand(file)
  directory = dirname(destination)
  if (!dir.exists(directory)) {
    stop("The state-file destination directory does not exist", call. = FALSE)
  }
  temporary = tempfile(
    pattern = paste0(".", basename(destination), "-"),
    tmpdir = directory
  )
  on.exit(unlink(temporary), add = TRUE)
  saveRDS(object, temporary, version = 3L)
  if (!isTRUE(replace(temporary, destination))) {
    stop(
      "Unable to atomically replace the saved state file; the previous state was preserved",
      call. = FALSE
    )
  }
  invisible(NULL)
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
    package_lineage = .serialization_current_package_lineage(),
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
  if (!is.numeric(max_bytes) || length(max_bytes) != 1L ||
      is.na(max_bytes) || !is.finite(max_bytes) || max_bytes <= 0) {
    .serialization_stop("maximum byte limit must be one positive number")
  }
  if (!is.list(payload) || is.object(payload)) {
    .serialization_stop("top level must be an unclassed list")
  }
  expected = c(
    "schema", "schema_version", "package_lineage", "source",
    "engine", "levels",
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
  .serialization_validate_package_lineage(payload$package_lineage)
  if (!is.character(payload$engine) || length(payload$engine) != 1L ||
      is.na(payload$engine) ||
      !payload$engine %in% c("legacy", "sparse")) {
    .serialization_stop("engine must be exactly legacy or sparse")
  }
  if (!is.character(payload$closure) || anyNA(payload$closure) ||
      any(!nzchar(payload$closure)) ||
      anyDuplicated(payload$closure)) {
    .serialization_stop(
      "closure must contain unique non-missing non-empty names"
    )
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
  if (!identical(basename(source$name), source$name) ||
      grepl("[/\\\\]", source$name)) {
    .serialization_stop(
      "source name must be a basename without path separators"
    )
  }
  if (!is.raw(source$tablo_source) || !length(source$tablo_source)) {
    .serialization_stop("TABLO source must be non-empty raw content")
  }
  if (!is.list(source$loaded_data) || is.object(source$loaded_data)) {
    .serialization_stop("loaded source data must be an unclassed list")
  }
  fingerprint_pattern = "^[[:xdigit:]]{32}$"
  fingerprints = c(source$tablo_fingerprint, source$data_fingerprint)
  if (!is.character(fingerprints) || length(fingerprints) != 2L ||
      anyNA(fingerprints) || any(!grepl(fingerprint_pattern, fingerprints))) {
    .serialization_stop(
      "source fingerprints must be 32 hexadecimal characters"
    )
  }
  if (!identical(
    source$tablo_fingerprint,
    .serialization_object_fingerprint(source$tablo_source)
  )) {
    .serialization_stop("TABLO source fingerprint mismatch")
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
  level_names = names(payload$levels)
  if (is.null(level_names) || anyNA(level_names) ||
      any(!nzchar(level_names)) || anyDuplicated(level_names)) {
    .serialization_stop("levels must have unique non-empty names")
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
    .serialization_stop(
      "shocks must contain unique labels and finite nonzero values"
    )
  }
  if (!is.list(payload$accepted) || is.object(payload$accepted)) {
    .serialization_stop("accepted state must be an unclassed list")
  }
  .serialization_validate_names(
    payload$accepted, c("solution", "data", "compact_output"),
    "accepted state"
  )
  if (!is.double(payload$accepted$solution) ||
      any(!is.finite(payload$accepted$solution))) {
    .serialization_stop("accepted solution must be finite double data")
  }
  if (!is.list(payload$accepted$data) ||
      !is.list(payload$accepted$compact_output) ||
      is.object(payload$accepted$data) ||
      is.object(payload$accepted$compact_output)) {
    .serialization_stop("accepted outputs must be unclassed lists")
  }
  for (field in c("data", "compact_output")) {
    output_names = names(payload$accepted[[field]])
    if (length(payload$accepted[[field]]) &&
        (is.null(output_names) || anyNA(output_names) ||
         any(!nzchar(output_names)) || anyDuplicated(output_names))) {
      .serialization_stop(sprintf(
        "accepted %s must have unique non-empty names", field
      ))
    }
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
  if (serialized_size > max_bytes ||
      as.numeric(object.size(payload)) > max_bytes) {
    .serialization_stop("payload exceeds the configured size limit")
  }
  invisible(payload)
}

.serialization_validate_structure = function(
    value, template, path, allow_dimension_drop = FALSE) {
  if (is.null(template)) {
    if (!is.null(value)) {
      .serialization_stop(sprintf("%s must be NULL", path))
    }
    return(invisible(TRUE))
  }
  if (is.list(template)) {
    if (!is.list(value) || is.object(value) ||
        !identical(names(value), names(template))) {
      .serialization_stop(sprintf(
        "%s fields do not match the reconstructed model", path
      ))
    }
    if (!identical(dim(value), dim(template)) ||
        !identical(dimnames(value), dimnames(template))) {
      .serialization_stop(sprintf(
        "%s dimensions do not match the reconstructed model", path
      ))
    }
    for (index in seq_along(template)) {
      label = names(template)[[index]]
      if (is.null(label) || !nzchar(label)) label = as.character(index)
      .serialization_validate_structure(
        value[[index]], template[[index]],
        paste(path, label, sep = "$"),
        allow_dimension_drop = allow_dimension_drop
      )
    }
    return(invisible(TRUE))
  }
  expected_template = template
  if (isTRUE(allow_dimension_drop) &&
      is.null(dim(value)) && !is.null(dim(template))) {
    expected_template = as.vector(template)
    names(expected_template) = names(template)
  }
  if (!identical(typeof(value), typeof(expected_template)) ||
      !identical(class(value), class(expected_template))) {
    .serialization_stop(sprintf(
      "%s type does not match the reconstructed model", path
    ))
  }
  dimensions_match = identical(dim(value), dim(expected_template)) &&
    identical(dimnames(value), dimnames(expected_template))
  if (!identical(length(value), length(expected_template)) ||
      !identical(names(value), names(expected_template)) ||
      !dimensions_match) {
    .serialization_stop(sprintf(
      "%s dimensions do not match the reconstructed model", path
    ))
  }
  invisible(TRUE)
}

.validate_reconstructed_logical_state = function(payload, restored) {
  rebuilt_levels = if (identical(payload$engine, "sparse")) {
    sparse_state_data(restored$sparseState)
  } else {
    restored$data
  }
  rebuilt_levels = .serialization_strip_runtime(rebuilt_levels)
  available_variables = unique(vapply(
    restored$sparseSpec$variables,
    function(variable) as.character(variable$name)[1L],
    character(1)
  ))
  reconstructed_updates = c(
    restored[["sparseSpec"]][["updates"]],
    restored[["sparseSpec"]][["simulation_updates"]],
    restored[["sparseSpec"]][["formula_initialization_updates"]],
    restored[["sparseSpec"]][["post_updates"]]
  )
  reconstructed_update_fields = if (length(reconstructed_updates)) {
    vapply(
      reconstructed_updates,
      function(update) as.character(
        update[["target"]][["name"]]
      )[1L],
      character(1)
    )
  } else character()
  reconstructed_numeric_fields = if (
    length(payload[["accepted"]][["solution"]])
  ) {
    fields = available_variables
    post_simulation_retained = isTRUE(
      payload[["diagnostics"]][["post_simulation_retained"]]
    )
    if (identical(payload[["engine"]], "legacy") ||
        post_simulation_retained) {
      fields = c(fields, reconstructed_update_fields)
    } else {
      numeric_update_fields = reconstructed_update_fields[vapply(
        reconstructed_update_fields,
        function(field) {
          field %in% names(payload[["levels"]]) &&
            is.double(payload[["levels"]][[field]])
        },
        logical(1)
      )]
      fields = c(fields, numeric_update_fields)
    }
    unique(fields)
  } else character()
  rebuilt_levels = .serialization_promote_reconstructed_fields(
    rebuilt_levels, reconstructed_numeric_fields
  )
  if (identical(payload$engine, "sparse")) {
    .serialization_validate_structure(
      payload$levels, rebuilt_levels, "levels"
    )
  } else {
    if (!identical(names(payload$levels), names(rebuilt_levels))) {
      .serialization_stop(
        "levels fields do not match the reconstructed model"
      )
    }
    updates = c(
      restored$sparseSpec$simulation_updates,
      restored$sparseSpec$formula_initialization_updates
    )
    update_fields = if (length(updates)) {
      vapply(
        updates,
        function(update) as.character(update$target$name)[1L],
        character(1)
      )
    } else character()
    dimension_dropping_fields = unique(c(
      available_variables, reconstructed_update_fields
    ))
    for (field in names(rebuilt_levels)) {
      .serialization_validate_structure(
        payload$levels[[field]], rebuilt_levels[[field]],
        paste0("levels$", field),
        allow_dimension_drop = field %in% dimension_dropping_fields
      )
    }
  }
  if (any(!payload$closure %in% available_variables)) {
    .serialization_stop(
      "closure contains variables absent from the reconstructed model"
    )
  }
  shock_variables = vapply(
    payload$shocks$labels,
    function(label) {
      tryCatch(
        sparse_parse_label(label)$name,
        error = function(error) {
          .serialization_stop(sprintf(
            "shock label is invalid: %s", conditionMessage(error)
          ))
        }
      )
    },
    character(1)
  )
  if (length(shock_variables) &&
      any(!shock_variables %in% payload$closure)) {
    .serialization_stop(
      "shock labels are outside the reconstructed model closure"
    )
  }

  expected_solution_length = if (identical(payload$engine, "sparse")) {
    as.integer(restored$sparseIndex$endogenous_count)
  } else {
    length(restored$data$equations)
  }
  solution = payload$accepted$solution
  if (length(solution) &&
      length(solution) != expected_solution_length) {
    .serialization_stop(
      "accepted solution size does not match the reconstructed model"
    )
  }
  solution_names = names(solution)
  if (!is.null(solution_names) &&
      (anyNA(solution_names) || any(!nzchar(solution_names)) ||
       anyDuplicated(solution_names))) {
    .serialization_stop(
      "accepted solution names must be unique and non-missing"
    )
  }

  level_fields = names(payload$levels)
  accepted_data_template = if (identical(payload$engine, "sparse")) {
    sparse_materialize_labels(
      sparse_make_state(payload$levels), restored$sparseIndex,
      equations = TRUE, variables = TRUE
    )
  } else {
    template = .serialization_strip_runtime(restored$data)
    for (field in level_fields) template[[field]] = payload$levels[[field]]
    template
  }
  unknown_data = setdiff(
    names(payload$accepted$data), names(accepted_data_template)
  )
  if (length(unknown_data)) {
    .serialization_stop(sprintf(
      "accepted data contains unknown field(s): %s",
      paste(unknown_data, collapse = ", ")
    ))
  }
  for (field in names(payload$accepted$data)) {
    .serialization_validate_structure(
      payload$accepted$data[[field]], accepted_data_template[[field]],
      paste0("accepted data$", field),
      allow_dimension_drop = !identical(payload$engine, "sparse") &&
        field %in% dimension_dropping_fields
    )
  }

  compact_output = payload$accepted$compact_output
  unknown_compact = setdiff(names(compact_output), c(level_fields, "solution"))
  if (length(unknown_compact)) {
    .serialization_stop(sprintf(
      "compact output contains unknown field(s): %s",
      paste(unknown_compact, collapse = ", ")
    ))
  }
  validate_projection = function(value, template, path) {
    if (is.list(template) || is.null(dim(template))) {
      .serialization_validate_structure(value, template, path)
      return(invisible(TRUE))
    }
    expected_template = template
    if (!identical(typeof(value), typeof(expected_template)) ||
        !identical(class(value), class(expected_template))) {
      .serialization_stop(sprintf(
        "%s type does not match the reconstructed model", path
      ))
    }
    value_dimensions = dim(value)
    template_dimensions = dim(template)
    names_match = if (is.null(names(template))) {
      is.null(names(value))
    } else {
      !is.null(names(value)) &&
        length(names(value)) == length(value) &&
        !anyDuplicated(names(value)) &&
        all(names(value) %in% names(template))
    }
    if (is.null(value_dimensions) ||
        length(value_dimensions) != length(template_dimensions) ||
        any(value_dimensions > template_dimensions) ||
        !names_match) {
      .serialization_stop(sprintf(
        "%s dimensions do not match the reconstructed model", path
      ))
    }
    value_dimnames = dimnames(value)
    template_dimnames = dimnames(template)
    if (is.null(value_dimnames) != is.null(template_dimnames) ||
        (!is.null(value_dimnames) &&
         !identical(names(value_dimnames), names(template_dimnames)))) {
      .serialization_stop(sprintf(
        "%s dimensions do not match the reconstructed model", path
      ))
    }
    if (!is.null(value_dimnames)) {
      for (index in seq_along(value_dimnames)) {
        labels = value_dimnames[[index]]
        template_labels = template_dimnames[[index]]
        if (is.null(labels) != is.null(template_labels) ||
            (!is.null(labels) && any(!labels %in% template_labels))) {
          .serialization_stop(sprintf(
            "%s dimensions do not match the reconstructed model", path
          ))
        }
      }
    }
    invisible(TRUE)
  }
  for (field in setdiff(names(compact_output), "solution")) {
    validate_projection(
      compact_output[[field]], payload$levels[[field]],
      paste0("compact output$", field)
    )
  }
  if ("solution" %in% names(compact_output) &&
      !identical(compact_output$solution, solution)) {
    .serialization_stop(
      "compact solution is not identical to the accepted solution"
    )
  }
  invisible(payload)
}

.restore_logical_state_payload = function(payload) {
  .validate_logical_state_payload(payload)
  lineage = .serialization_validate_package_lineage(
    payload$package_lineage
  )
  if (identical(lineage, "predecessor")) {
    payload$package_lineage = .serialization_current_package_lineage()
  }
  suffix = tools::file_ext(payload$source$name)
  if (!nzchar(suffix)) suffix = "tab"
  path = tempfile("tabloToR-restore-", fileext = paste0(".", suffix))
  connection = file(path, open = "wb")
  writeBin(payload$source$tablo_source, connection)
  close(connection)
  on.exit(unlink(path), add = TRUE)

  restored = tryCatch({
    candidate = GEModel$new()
    candidate$loadTablo(path)
    candidate$setClosure(payload$closure)
    candidate$loadData(
      payload$source$loaded_data, engine = payload$engine
    )
    candidate
  }, error = function(error) {
    .serialization_stop(sprintf(
      "source reconstruction failed: %s", conditionMessage(error)
    ))
  })
  .validate_reconstructed_logical_state(payload, restored)

  restored$sourceData = payload$source
  if (identical(payload$engine, "sparse")) {
    restored$sparseState = sparse_make_state(payload$levels)
    restored$data = payload$accepted$data
  } else {
    rebuilt_data = restored$data
    for (field in names(payload$levels)) {
      rebuilt_data[[field]] = payload$levels[[field]]
    }
    restored$data = rebuilt_data
  }
  restored$solution = payload$accepted$solution
  restored$compactOutput = payload$accepted$compact_output
  restored$explicitShocks = payload$shocks
  restored$shocks = setNames(
    payload$shocks$values, payload$shocks$labels
  )
  if (identical(payload$engine, "sparse")) {
    restored$variableValues = list()
  }
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
