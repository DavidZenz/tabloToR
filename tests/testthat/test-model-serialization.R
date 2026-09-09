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
                     getNamespaceExports("tabloToR")))
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

  for (name in names(malformed)) {
    expectSerializationRejectedWithoutMutation(
      malformed[[name]], info = name
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

  receiver = GEModel$new()
  receiver$closure = "receiver-sentinel"
  before = serializationReceiverSnapshot(receiver)
  withr::local_options(
    tabloToR.serialization.max_bytes = file.info(state_file)$size - 1
  )
  expect_error(receiver$loadState(state_file), "size limit")
  expect_identical(serializationReceiverSnapshot(receiver), before)

  withr::local_options(tabloToR.serialization.max_elements = 2)
  expect_error(
    .validate_logical_state_payload(payload),
    "element limit"
  )
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
