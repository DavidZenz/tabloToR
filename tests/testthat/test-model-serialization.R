if (!exists("GEModel", inherits = TRUE)) {
  serialization_source_root = normalizePath(
    testthat::test_path("..", ".."), mustWork = TRUE
  )
  serialization_r_files = sort(list.files(
    file.path(serialization_source_root, "R"),
    pattern = "\\.R$", full.names = TRUE
  ))
  for (serialization_r_file in serialization_r_files) {
    sys.source(serialization_r_file, envir = .GlobalEnv)
  }
}
serializationCompleteReceiverSnapshot = function(model) {
  fields = names(GEModel$fields())
  snapshot = lapply(fields, function(field) {
    value = model[[field]]
    if (identical(field, "sparseState") && is.environment(value)) {
      return(as.list.environment(value, all.names = TRUE))
    }
    value
  })
  names(snapshot) = fields
  snapshot
}

serializationPayloadFields = function() {
  c(
    "schema", "schema_version", "package_lineage", "source",
    "engine", "levels", "closure", "shocks", "accepted",
    "memory_budget", "diagnostics"
  )
}

test_that("saveState writes exact current GEModelR package lineage", {
  registry = .serialization_package_lineage_registry()
  expect_identical(nrow(registry), 1L)
  expect_identical(registry$`Package-Name`, "tabloToR")
  expect_identical(registry$`Package-Version`, "0.1.0")
  expect_identical(registry$`Lineage-Review-State`, "reviewed")
  expect_identical(registry$`Reachability-Review-State`, "approved")
  expect_match(
    registry$`Source-Fingerprint`, "^[0-9a-f]{32}$"
  )

  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  model$saveState(state_file)
  payload = readRDS(state_file)

  expect_identical(names(payload), serializationPayloadFields())
  expect_identical(
    payload$package_lineage,
    list(
      name = "GEModelR",
      version = "0.1.0",
      source_fingerprint = unname(registry$`Source-Fingerprint`)
    )
  )
})

test_that("failed state replacement preserves the previous checkpoint", {
  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  model$saveState(state_file)
  prior_payload = readRDS(state_file)
  prior_bytes = readBin(
    state_file, what = "raw", n = file.info(state_file)$size
  )

  expect_error(
    .serialization_atomic_save_rds(
      list(replacement = TRUE), state_file,
      replace = function(from, to) FALSE
    ),
    "previous state was preserved"
  )

  expect_identical(readRDS(state_file), prior_payload)
  expect_identical(
    readBin(state_file, what = "raw", n = file.info(state_file)$size),
    prior_bytes
  )
  temporary_prefix = paste0(".", basename(state_file), "-")
  directory_files = list.files(dirname(state_file), all.files = TRUE,
                               no.. = TRUE)
  expect_false(any(startsWith(directory_files, temporary_prefix)))

  model$saveState(state_file)
  expect_identical(readRDS(state_file), prior_payload)
})

test_that("unsupported package lineage fails before receiver mutation", {
  model = make_three_region_model("sparse")
  payload = .build_logical_state_payload(model)
  unsupported = list()

  unsupported$missing = payload[names(payload) != "package_lineage"]

  unsupported$malformed = payload
  unsupported$malformed$package_lineage = "tabloToR"

  unsupported$missing_field = payload
  unsupported$missing_field$package_lineage$source_fingerprint = NULL

  unsupported$unknown_field = payload
  unsupported$unknown_field$package_lineage$unexpected = TRUE

  unsupported$non_scalar_name = payload
  unsupported$non_scalar_name$package_lineage$name = c(
    "tabloToR", "tabloToR"
  )

  unsupported$unknown_source = payload
  unsupported$unknown_source$package_lineage$source_fingerprint = paste(
    rep("0", 32L), collapse = ""
  )

  unsupported$unallowlisted_package = payload
  unsupported$unallowlisted_package$package_lineage$name = "unknownPackage"

  unsupported$stale_current = payload
  unsupported$stale_current$package_lineage$version = "0.0.9"

  unsupported$forged_current = payload
  unsupported$forged_current$package_lineage$source_fingerprint = paste(
    rep("f", 32L), collapse = ""
  )

  for (name in names(unsupported)) {
    expectSerializationRejectedWithoutMutation(
      unsupported[[name]], pattern = "package lineage|top-level",
      info = name
    )
  }
})

test_that("migration source gate narrows only reviewed serialization source", {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  tool_path = file.path(
    root, "inst", "tools", "refresh_phase02_baselines.R"
  )
  testthat::skip_if_not(file.exists(tool_path), "source-tree gate unavailable")
  tool = new.env(parent = globalenv())
  sys.source(tool_path, envir = tool)
  map = tool$phase02_load_identity_map(root = root)
  protected = tool$phase02_protected_numerical_source_files()
  expect_identical(
    unique(map$`Reviewed-Non-Numerical-Exclusions`),
    "R/modelSerialization.R"
  )
  expect_setequal(
    intersect(tool$phase02_identity_source_files(root), protected),
    protected
  )
  expect_false(
    "R/modelSerialization.R" %in%
      tool$phase02_identity_source_files(root)
  )

  source = tempfile("phase02-serialization-migration-")
  on.exit(unlink(source, recursive = TRUE, force = TRUE), add = TRUE)
  relative = c(
    tool$phase02_identity_source_files(root),
    tool$phase02_identity_reviewed_exclusions()
  )
  for (path in relative) {
    target = file.path(source, path)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    expect_true(file.copy(file.path(root, path), target))
  }
  expect_silent(tool$phase02_validate_identity_source(source, map))

  serialization_path = file.path(source, "R", "modelSerialization.R")
  write(
    "# reviewed non-numerical serialization migration",
    serialization_path, append = TRUE
  )
  expect_silent(tool$phase02_validate_identity_source(source, map))

  protected_path = file.path(source, protected[[1L]])
  write("# forbidden numerical drift", protected_path, append = TRUE)
  expect_error(
    tool$phase02_validate_identity_source(source, map),
    "source fingerprint"
  )
})

test_that("accepted logical state round trips through the versioned payload", {
  model = make_three_region_model("sparse")
  model$setMemoryBudget(128 * 1024^2)
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1,
    steps = 1,
    engine = "sparse",
    postsim = TRUE,
    diagnostics = TRUE,
    output = "full",
    backend = "Matrix",
    reduction = "off"
  )
  expected = serializationModelSnapshot(model)
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)

  returned = model$saveState(state_file)
  expect_identical(returned, model)
  payload = readRDS(state_file)

  expect_identical(names(payload), serializationPayloadFields())
  expect_identical(payload$schema, "gemodel-logical-state")
  expect_identical(payload$schema_version, 1L)
  expect_identical(payload$engine, "sparse")
  expect_identical(payload$levels, expected$levels)
  expect_identical(payload$closure, expected$closure)
  expect_identical(payload$shocks, expected$shocks)
  expect_identical(payload$accepted$solution, expected$solution)
  expect_identical(payload$accepted$data, expected$data)
  expect_identical(payload$accepted$compact_output, expected$compact_output)
  expect_identical(payload$memory_budget, expected$memory_budget)
  expect_identical(payload$diagnostics, expected$diagnostics)
  expect_false(serializationContainsRuntimeState(payload))
  expect_false(any(grepl(
    "pointer|factor|cache|workspace|applied|postsim_record",
    names(payload), ignore.case = TRUE
  )))

  restored = GEModel$new()
  load_return = restored$loadState(state_file)
  expect_identical(load_return, restored)
  expect_identical(serializationModelSnapshot(restored), expected)
  expect_identical(restored$.postsimRecord, list())
  expect_false(serializationContainsRuntimeState(restored$sourceData))

  fresh = runSerializationFreshProcess(state_file)
  expect_true(fresh$returned_self)
  expect_identical(fresh$before, expected)
  expect_identical(fresh$cache_before, 0L)
  expect_identical(fresh$cache_after, 0L)
  expect_identical(fresh$after$engine, "sparse")
  expect_identical(
    describeCompatibilityStructure(fresh$after$solution),
    describeCompatibilityStructure(expected$solution)
  )
  expect_identical(
    lapply(fresh$after$data, describeCompatibilityStructure),
    lapply(expected$data, describeCompatibilityStructure)
  )
  expect_true(all(is.finite(fresh$after$solution)))
})

test_that("small versioned solve envelope round trips without extra state", {
  model = make_three_region_model("sparse")
  model$setMemoryBudget(128 * 1024^2)
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "full", backend = "Matrix",
    reduction = "off"
  )
  detailed = model$lastDiagnostics
  envelope = .gemodelr_diagnostics_envelope(
    engine = detailed$engine,
    requested_backend = detailed$requested_backend,
    implementation = detailed$implementation,
    status = detailed$status,
    condition_class = detailed$condition_class,
    accepted_numerical_state = detailed$accepted_numerical_state,
    retryable_postsim = detailed$retryable_postsim,
    failure_phase = detailed$failure_phase,
    failure_reason = detailed$failure_reason,
    cleanup_status = detailed$cleanup_status
  )
  model$lastDiagnostics = envelope
  expect_identical(names(envelope), .gemodelr_diagnostics_fields)
  expect_identical(envelope$schema_version, 1L)

  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  model$saveState(state_file)
  payload = readRDS(state_file)
  expect_identical(names(payload), serializationPayloadFields())
  expect_identical(payload$schema, "gemodel-logical-state")
  expect_identical(payload$schema_version, 1L)
  expect_identical(payload$diagnostics, envelope)

  restored = GEModel$new()
  restored$loadState(state_file)
  expect_identical(restored$lastDiagnostics, envelope)
  expect_identical(names(restored$lastDiagnostics), .gemodelr_diagnostics_fields)
})

test_that("case-insensitive shock labels round trip through logical state", {
  model = make_three_region_model("sparse")
  shocks = setNames(
    c(1, 2, -1),
    c("TAX[north]", " tax[ 'south' ] ", "Tax[\"east\"]")
  )
  model$setShocks(shocks)
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", backend = "Matrix",
    reduction = "off"
  )
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  model$saveState(state_file)

  restored = GEModel$new()
  restored$loadState(state_file)

  expect_identical(restored$explicitShocks$labels, names(shocks))
  expect_identical(unname(restored$explicitShocks$values), unname(shocks))
  expect_identical(restored$solution, model$solution)
})

test_that("serialization entry points and helpers have explicit contract rows", {
  manifest = loadCompatibilityManifest()
  expected = data.frame(
    kind = c("method", "method", rep("internal", 4L)),
    name = c(
      "saveState", "loadState", ".build_logical_state_payload",
      ".validate_logical_state_payload", ".validate_reconstructed_logical_state",
      ".restore_logical_state_payload"
    ),
    tier = c("supported", "supported", rep("internal", 4L)),
    stringsAsFactors = FALSE
  )
  actual = manifest[
    manifest$name %in% expected$name,
    c("kind", "name", "tier"),
    drop = FALSE
  ]
  actual = actual[match(expected$name, actual$name), , drop = FALSE]
  rownames(actual) = NULL

  expect_identical(actual, expected)
  expect_false(any(expected$name[expected$kind == "internal"] %in%
                     getNamespaceExports("GEModelR")))
})

test_that("serialization policy documents portable and compatibility-only forms", {
  path = serializationPolicyPath()
  expect_true(file.exists(path))
  text = paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "gemodel-logical-state", fixed = TRUE)
  expect_match(text, "schema version 1", fixed = TRUE)
  expect_match(text, "same-version compatibility-only", fixed = TRUE)
  expect_match(text, "trusted local", ignore.case = TRUE)
  expect_match(text, "cache", ignore.case = TRUE)
})

test_that("malformed logical payloads fail closed before receiver mutation", {
  model = make_three_region_model("sparse")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "full", backend = "Matrix",
    reduction = "off"
  )
  payload = .build_logical_state_payload(model)

  malformed = list()

  malformed$unknown_top_level = payload
  malformed$unknown_top_level$unexpected = TRUE

  malformed$unknown_schema_version = payload
  malformed$unknown_schema_version$schema_version = 2L

  malformed$invalid_engine_type = payload
  malformed$invalid_engine_type$engine = 1L

  malformed$invalid_source_fingerprint = payload
  malformed$invalid_source_fingerprint$source$tablo_fingerprint =
    paste(rep("0", 32L), collapse = "")

  malformed$unknown_level = payload
  malformed$unknown_level$levels$unexpected = 1

  malformed$invalid_level_dimensions = payload
  malformed$invalid_level_dimensions$levels$stock =
    as.numeric(malformed$invalid_level_dimensions$levels$stock)

  malformed$invalid_solution_dimensions = payload
  malformed$invalid_solution_dimensions$accepted$solution =
    malformed$invalid_solution_dimensions$accepted$solution[1L]

  malformed$invalid_accepted_data = payload
  malformed$invalid_accepted_data$accepted$data$stock = "CORRUPTED"

  malformed$invalid_compact_projection = payload
  malformed$invalid_compact_projection$accepted$compact_output =
    list(stock = "CORRUPTED")

  malformed$compact_solution_mismatch = payload
  malformed$compact_solution_mismatch$accepted$compact_output =
    list(solution = payload$accepted$solution + 1)

  malformed$runtime_attribute = payload
  malformed$runtime_attribute$diagnostics$unsafe = structure(
    1, runtime = new.env(parent = emptyenv())
  )

  malformed$invalid_nested_name = payload
  names(malformed$invalid_nested_name$diagnostics)[1L] = NA_character_

  receiver = make_three_region_model("sparse")
  set_three_region_shocks(receiver, "preferred", c(1, 2, -1))
  receiver$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "compact", variables = "stock",
    reduction = "off"
  )
  before = serializationCompleteReceiverSnapshot(receiver)
  state_files = stats::setNames(vapply(names(malformed), function(name) {
    path = tempfile(fileext = ".rds")
    writeSerializationPayload(malformed[[name]], path)
    path
  }, character(1)), names(malformed))
  on.exit(unlink(state_files), add = TRUE)

  for (name in names(malformed)) {
    expect_error(receiver$loadState(state_files[[name]]), info = name)
    expect_identical(
      serializationCompleteReceiverSnapshot(receiver), before, info = name
    )
  }
})

test_that("fresh R processes reject incompatible payloads without mutation", {
  model = make_three_region_model("sparse")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "full", backend = "Matrix",
    reduction = "off"
  )
  payload = .build_logical_state_payload(model)
  malformed = list(
    unknown_schema = (function(value) {
      value$schema_version = 99L
      value
    })(payload),
    source_mismatch = (function(value) {
      value$source$tablo_fingerprint =
        paste(rep("f", 32L), collapse = "")
      value
    })(payload),
    dimension_mismatch = (function(value) {
      value$levels$stock = as.numeric(value$levels$stock)
      value
    })(payload)
  )
  state_files = vapply(malformed, function(value) {
    path = tempfile(fileext = ".rds")
    writeSerializationPayload(value, path)
    path
  }, character(1))
  on.exit(unlink(state_files), add = TRUE)

  results = runSerializationRejectionFreshProcess(state_files)
  expect_true(all(vapply(results, function(value) {
    is.character(value$error) &&
      grepl("Invalid logical state payload", value$error, fixed = TRUE)
  }, logical(1))))
  expect_true(all(vapply(results, `[[`, logical(1), "unchanged")))
})

test_that("serialization limits reject oversized artifacts and values", {
  model = make_three_region_model("sparse")
  payload = .build_logical_state_payload(model)
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  writeSerializationPayload(payload, state_file)

  receiver = make_three_region_model("sparse")
  set_three_region_shocks(receiver, "preferred", c(1, 2, -1))
  receiver$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "full", reduction = "off"
  )
  before = serializationCompleteReceiverSnapshot(receiver)
  withr::local_options(
    GEModelR.serialization.max_bytes = file.info(state_file)$size - 1
  )
  expect_error(receiver$loadState(state_file), "size limit")
  expect_identical(serializationCompleteReceiverSnapshot(receiver), before)

  withr::local_options(GEModelR.serialization.max_elements = 2)
  expect_error(
    .validate_logical_state_payload(payload),
    "element limit"
  )
})

test_that("compressed RDS expansion is rejected after trusted-local decode", {
  model = make_three_region_model("sparse")
  payload = .build_logical_state_payload(model)
  payload$diagnostics$compressible_padding = paste(
    rep("A", 1024^2), collapse = ""
  )
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  writeSerializationPayload(payload, state_file)

  compressed_size = as.numeric(file.info(state_file)$size)
  logical_size = length(serialize(payload, NULL, version = 3L))
  limit = floor((compressed_size + logical_size) / 2)
  expect_lt(compressed_size, limit)
  expect_gt(logical_size, limit)

  receiver = make_three_region_model("sparse")
  set_three_region_shocks(receiver, "preferred", c(1, 2, -1))
  receiver$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "full", reduction = "off"
  )
  before = serializationCompleteReceiverSnapshot(receiver)
  withr::local_options(GEModelR.serialization.max_bytes = limit)
  expect_error(receiver$loadState(state_file), "payload exceeds.*size limit")
  expect_identical(serializationCompleteReceiverSnapshot(receiver), before)
})

test_that("portable edge values retain structure equality and encoding", {
  utf8 = "\u00e9"
  Encoding(utf8) = "UTF-8"
  latin1 = iconv(utf8, from = "UTF-8", to = "latin1")
  Encoding(latin1) = "latin1"
  edges = list(
    empty = numeric(),
    singleton = array(
      7,
      dim = 1L,
      dimnames = list(region = "north")
    ),
    nullable = NULL,
    missing = c(NA_real_, 1),
    encoded = c(utf8 = utf8, latin1 = latin1)
  )
  model = make_three_region_model("sparse")
  model$lastDiagnostics = list(portable_edges = edges)
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)

  model$saveState(state_file)
  payload = readRDS(state_file)
  restored = GEModel$new()
  restored$loadState(state_file)

  expect_identical(payload$diagnostics$portable_edges, edges)
  expect_identical(restored$lastDiagnostics$portable_edges, edges)
  expect_identical(
    lapply(restored$lastDiagnostics$portable_edges,
           describeCompatibilityStructure),
    lapply(edges, describeCompatibilityStructure)
  )
  expect_true(compatibilityValuesEqual(
    restored$lastDiagnostics$portable_edges$encoded,
    edges$encoded,
    check_encoding = TRUE
  ))
})

test_that("restored runtime cache starts empty and can rebuild independently", {
  capability = numericalBackendCapability("StructuredSchurFGMRESCpp")
  skipOptionalCapability(capability)
  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  model$saveState(state_file)
  restored = GEModel$new()
  restored$loadState(state_file)

  expect_identical(restored$sparseState$.solver_cache, list())
  fixture = make_cpp_schur_fixture()
  runtime = .sparse_schur_cpp_runtime
  old = list(
    active = runtime$active,
    state = runtime$state,
    index_key = runtime$index_key
  )
  on.exit({
    runtime$active = old$active
    runtime$state = old$state
    runtime$index_key = old$index_key
    .sparse_cpp_release_live_factors()
  }, add = TRUE)
  runtime$active = TRUE
  runtime$state = restored$sparseState
  runtime$index_key = "serialization-rebuild"
  .sparse_exact_schur_build_cpp(
    fixture$A, fixture$row_group, fixture$column_group,
    fixture$local_count, fixture$region_count, fixture$global_group,
    rhs = fixture$rhs, panel_size = 2L
  )
  .sparse_cpp_release_live_factors()

  expect_identical(
    names(restored$sparseState$.solver_cache),
    "StructuredSchurFGMRESCpp"
  )
  expect_false(serializationContainsRuntimeState(
    restored$sparseState$.solver_cache
  ))
})

test_that("raw reference serialization remains same-version compatibility-only", {
  model = make_three_region_model("sparse")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  solve_three_region_once(model)
  raw_file = tempfile(fileext = ".rds")
  on.exit(unlink(raw_file), add = TRUE)

  saveRDS(model, raw_file, version = 3L)
  restored = readRDS(raw_file)
  expect_true(inherits(restored, "GEModel"))
  expect_silent(suppressMessages(solve_three_region_once(restored)))
  expect_true(all(is.finite(restored$solution)))

  manifest = loadCompatibilityManifest()
  raw_row = manifest[
    manifest$kind == "serialization" &
      manifest$name == "raw-saveRDS-model",
    , drop = FALSE
  ]
  expect_identical(nrow(raw_row), 1L)
  expect_identical(raw_row$tier, "compatibility-only")
  expect_identical(raw_row$serialization, "same-version-best-effort")

  policy = paste(readLines(serializationPolicyPath(), warn = FALSE),
                 collapse = "\n")
  expect_match(policy, "not a stable portable or cross-version contract",
               fixed = TRUE)
  expect_match(policy, "Do not load payloads from untrusted parties",
               fixed = TRUE)
})

test_that("logical state rebuilds the declared legacy runtime", {
  model = make_three_region_model("legacy")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  suppressMessages(model$solveModel(
    iter = 1, steps = 1, engine = "legacy"
  ))
  expected = serializationModelSnapshot(model)
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)

  model$saveState(state_file)
  restored = GEModel$new()
  restored$loadState(state_file)

  expect_identical(restored$loadedEngine, "legacy")
  expect_identical(serializationModelSnapshot(restored), expected)
  expect_true(is.function(restored$data[["/"]]))
  expect_silent(suppressMessages(restored$solveModel(
    iter = 1, steps = 1, engine = "legacy"
  )))
  expect_true(all(is.finite(restored$solution)))
})

test_that("genuine predecessor fixture enforces lineage and content integrity", {
  fixture = testthat::test_path(
    "fixtures", "serialization", "tabloToR-schema1-lineage.rds"
  )
  expect_true(file.exists(fixture))
  if (!file.exists(fixture)) return(invisible())

  registry = .serialization_package_lineage_registry()
  payload = readRDS(fixture)
  expect_identical(names(payload), serializationPayloadFields())
  expect_identical(
    payload$package_lineage,
    list(
      name = "tabloToR",
      version = "0.1.0",
      source_fingerprint = unname(registry$`Source-Fingerprint`)
    )
  )
  expect_identical(
    payload$source$data_fingerprint,
    unname(registry$`Data-Fingerprint`)
  )

  receiver = GEModel$new()
  returned = receiver$loadState(fixture)
  expect_identical(returned, receiver)
  expect_identical(receiver$loadedEngine, "sparse")
  expect_identical(receiver$sourceData, payload$source)

  normalized_file = tempfile(fileext = ".rds")
  on.exit(unlink(normalized_file), add = TRUE)
  receiver$saveState(normalized_file)
  normalized = readRDS(normalized_file)
  expect_identical(
    normalized$package_lineage,
    .serialization_current_package_lineage()
  )
  expect_identical(normalized$package_lineage$name, "GEModelR")

  rejected = list()
  rejected$duplicate = payload
  names(rejected$duplicate$package_lineage)[[3L]] = "name"

  rejected$non_scalar = payload
  rejected$non_scalar$package_lineage$version = c("0.1.0", "0.1.0")

  rejected$stale = payload
  rejected$stale$package_lineage$version = "0.0.9"

  rejected$unknown = payload
  rejected$unknown$package_lineage$source_fingerprint = paste(
    rep("f", 32L), collapse = ""
  )

  rejected$content_altered = payload
  rejected$content_altered$source$loaded_data$basedata$stock[[1L]] =
    rejected$content_altered$source$loaded_data$basedata$stock[[1L]] + 1

  for (name in names(rejected)) {
    expectSerializationRejectedWithoutMutation(
      rejected[[name]],
      pattern = "package lineage|fingerprint mismatch",
      info = name
    )
  }
})

test_that("serialization predecessor options fail at save and load boundaries", {
  model = make_three_region_model("sparse")
  input_file = tempfile(fileext = ".rds")
  output_file = tempfile(fileext = ".rds")
  on.exit(unlink(c(input_file, output_file)), add = TRUE)
  model$saveState(input_file)
  writeBin(charToRaw("save-sentinel"), output_file)
  output_before = readBin(
    output_file, "raw", n = as.integer(file.info(output_file)$size)
  )

  receiver = GEModel$new()
  receiver$closure = "receiver-sentinel"
  receiver_before = serializationReceiverSnapshot(receiver)
  current = c(
    "GEModelR.serialization.max_bytes",
    "GEModelR.serialization.max_elements"
  )
  replacements = .identity_public_option_replacements[
    .identity_public_option_replacements %in% current
  ]
  for (old_key in names(replacements)) {
    expectOldPublicOptionRejected(
      old_key, replacements[[old_key]],
      function() model$saveState(output_file)
    )
    expect_identical(
      readBin(output_file, "raw", n = length(output_before)),
      output_before,
      info = old_key
    )
    expectOldPublicOptionRejected(
      old_key, replacements[[old_key]],
      function() receiver$loadState(input_file),
      before = receiver_before,
      snapshot = function() serializationReceiverSnapshot(receiver)
    )
  }
})

test_that("raw ReferenceClass RDS is rejected without receiver mutation", {
  raw_file = tempfile(fileext = ".rds")
  on.exit(unlink(raw_file), add = TRUE)
  saveRDS(make_three_region_model("sparse"), raw_file, version = 3L)

  receiver = GEModel$new()
  receiver$closure = "receiver-sentinel"
  before = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )
  expect_error(receiver$loadState(raw_file), "top level")
  after = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )
  expect_identical(after, before)
})

test_that("approved serialization evidence remains byte-identical", {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  testthat::skip_if_not(
    file.exists(file.path(root, "tools", "check_predecessor_bridge.R")),
    "predecessor digest audit requires the source tree"
  )
  expectApprovedSerializationEvidence()
})
