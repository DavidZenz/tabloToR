test_that("current sparse state preserves exact double leaves", {
  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)

  model$saveState(state_file)
  payload = readRDS(state_file)
  expect_true(is.double(payload$levels$basedata$stock))

  restored = GEModel$new()
  returned = restored$loadState(state_file)

  expect_identical(returned, restored)
  expect_identical(restored$loadedEngine, "sparse")
  restored_levels = sparse_state_data(restored$sparseState)
  expect_true(is.double(restored_levels$basedata$stock))
  expect_identical(
    dimnames(restored_levels$basedata$stock),
    dimnames(payload$levels$basedata$stock)
  )
})

test_that("logical-for-double sparse state is rejected before receiver mutation", {
  model = make_three_region_model("sparse")
  state_file = tempfile(fileext = ".rds")
  bad_file = tempfile(fileext = ".rds")
  on.exit(unlink(c(state_file, bad_file)), add = TRUE)

  model$saveState(state_file)
  payload = readRDS(state_file)
  stock = payload$levels$basedata$stock
  expect_true(is.double(stock))
  payload$levels$basedata$stock = array(
    as.logical(stock), dim = dim(stock), dimnames = dimnames(stock)
  )
  writeSerializationPayload(payload, bad_file)

  receiver = GEModel$new()
  receiver$closure = "receiver-sentinel"
  receiver$memoryBudget = 4096
  before = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )

  expect_error(
    receiver$loadState(bad_file),
    "levels\\$basedata\\$stock type does not match"
  )
  after = serialize(
    serializationReceiverSnapshot(receiver), NULL, version = 3L
  )
  expect_identical(after, before)
})

serializationLeafStructure = function(value) {
  list(
    typeof = typeof(value),
    class = class(value),
    names = names(value),
    dim = dim(value),
    dimnames = dimnames(value)
  )
}

serializationLeafPayloadFieldNames = c(
  "schema", "schema_version", "package_lineage", "source",
  "engine", "levels", "closure", "shocks", "accepted",
  "memory_budget", "diagnostics"
)

serializationReplaceLeafValues = function(value, type) {
  replacement = switch(
    type,
    logical = as.logical(value),
    integer = as.integer(value),
    matrix = as.numeric(value),
    nonfinite = as.numeric(value)
  )
  attributes(replacement) = attributes(value)
  if (identical(type, "matrix")) attr(replacement, "class") = "matrix"
  if (identical(type, "nonfinite")) replacement[[1L]] = Inf
  replacement
}

serializationBuildCurrentPayload = function(
    engine = "sparse", output = "unsolved") {
  model = make_three_region_model(engine)
  if (identical(output, "unsolved")) {
    return(.build_logical_state_payload(model))
  }
  if (!identical(engine, "legacy")) {
    set_three_region_shocks(model, "preferred", c(1, 2, -1))
  }
  if (identical(output, "compact")) {
    suppressMessages(model$solveModel(
      iter = 1, steps = 1, engine = engine, postsim = FALSE,
      diagnostics = TRUE, output = "compact", variables = "stock",
      dimensions = list(reg = "south"), backend = "Matrix", reduction = "off"
    ))
  } else if (identical(engine, "legacy")) {
    suppressMessages(model$solveModel(
      iter = 1, steps = 1, engine = "legacy"
    ))
  } else {
    suppressMessages(model$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, output = "full", backend = "Matrix", reduction = "off"
    ))
  }
  .build_logical_state_payload(model)
}

serializationResavePayload = function(payload) {
  state_file = tempfile(fileext = ".rds")
  normalized_file = tempfile(fileext = ".rds")
  on.exit(unlink(c(state_file, normalized_file)), add = TRUE)
  writeSerializationPayload(payload, state_file)
  receiver = GEModel$new()
  returned = receiver$loadState(state_file)
  receiver$saveState(normalized_file)
  list(
    returned = returned,
    receiver = receiver,
    normalized = readRDS(normalized_file)
  )
}

serializationPopulatedReceiver = function() {
  receiver = make_three_region_model("sparse")
  set_three_region_shocks(receiver, "preferred", c(1, 2, -1))
  suppressMessages(receiver$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "full", backend = "Matrix", reduction = "off"
  ))
  receiver$sparseState$.solver_cache = list(
    task_03_16 = list(backend = "Matrix", marker = "preserve")
  )
  receiver$.postsimRecord = list(
    task_03_16 = list(output = "full", marker = "preserve")
  )
  receiver
}

serializationCompleteReceiverBytes = function(model) {
  snapshot = serializationReceiverSnapshot(model)
  snapshot$shocks = model$shocks
  snapshot$sparse_solver_cache = if (
    is.environment(model$sparseState) &&
    !is.null(model$sparseState$.solver_cache)
  ) model$sparseState$.solver_cache else list()
  serialize(snapshot, NULL, version = 3L)
}

expectSerializationLeafRejected = function(payload, pattern, info) {
  state_file = tempfile(fileext = ".rds")
  on.exit(unlink(state_file), add = TRUE)
  writeSerializationPayload(payload, state_file)
  receiver = serializationPopulatedReceiver()
  before = serializationCompleteReceiverBytes(receiver)
  error = tryCatch({
    receiver$loadState(state_file)
    NULL
  }, error = identity)
  expect_true(inherits(error, "error"), info = info)
  if (inherits(error, "error")) {
    expect_match(conditionMessage(error), pattern, info = info)
  }
  after = serializationCompleteReceiverBytes(receiver)
  expect_identical(after, before, info = info)
  invisible(receiver)
}

serializationAssertCurrentLineage = function(payload) {
  expect_identical(names(payload), serializationLeafPayloadFieldNames)
  expect_identical(payload$schema, "gemodel-logical-state")
  expect_identical(payload$schema_version, 1L)
  expect_identical(payload$package_lineage, .serialization_current_package_lineage())
}

test_that("current and predecessor round trips preserve exact leaf metadata", {
  regions = c("north", "south", "east")
  expected_sparse = list(
    typeof = "double",
    class = "array",
    names = regions,
    dim = 3L,
    dimnames = list(reg = regions)
  )
  expected_legacy = list(
    typeof = "double",
    class = "numeric",
    names = regions,
    dim = NULL,
    dimnames = NULL
  )
  expected_compact = list(
    typeof = "double",
    class = "array",
    names = "south",
    dim = 1L,
    dimnames = list(reg = "south")
  )

  unsolved = serializationBuildCurrentPayload("sparse", "unsolved")
  serializationAssertCurrentLineage(unsolved)
  expect_identical(
    serializationLeafStructure(unsolved$levels$basedata$stock),
    expected_sparse
  )
  unsolved_roundtrip = serializationResavePayload(unsolved)
  expect_identical(unsolved_roundtrip$returned, unsolved_roundtrip$receiver)
  serializationAssertCurrentLineage(unsolved_roundtrip$normalized)
  expect_identical(
    serializationLeafStructure(
      sparse_state_data(unsolved_roundtrip$receiver$sparseState)$basedata$stock
    ),
    expected_sparse
  )
  expect_identical(
    serializationLeafStructure(
      unsolved_roundtrip$normalized$levels$basedata$stock
    ),
    expected_sparse
  )

  full = serializationBuildCurrentPayload("sparse", "full")
  serializationAssertCurrentLineage(full)
  expect_identical(
    serializationLeafStructure(full$levels$basedata$stock),
    expected_sparse
  )
  expect_identical(
    serializationLeafStructure(full$accepted$solution),
    list(
      typeof = "double", class = "numeric", names = c(
        "q[\"north\"]", "q[\"south\"]", "q[\"east\"]"
      ), dim = NULL, dimnames = NULL
    )
  )
  full_roundtrip = serializationResavePayload(full)
  serializationAssertCurrentLineage(full_roundtrip$normalized)
  expect_identical(
    serializationLeafStructure(full_roundtrip$normalized$levels$basedata$stock),
    expected_sparse
  )

  compact = serializationBuildCurrentPayload("sparse", "compact")
  serializationAssertCurrentLineage(compact)
  expect_identical(
    names(compact$accepted$compact_output), c("stock", "solution")
  )
  expect_identical(
    serializationLeafStructure(compact$accepted$compact_output$stock),
    expected_compact
  )
  compact_roundtrip = serializationResavePayload(compact)
  serializationAssertCurrentLineage(compact_roundtrip$normalized)
  expect_identical(
    serializationLeafStructure(compact_roundtrip$receiver$compactOutput$stock),
    expected_compact
  )
  expect_identical(
    serializationLeafStructure(compact_roundtrip$normalized$accepted$compact_output$stock),
    expected_compact
  )

  legacy = serializationBuildCurrentPayload("legacy", "full")
  serializationAssertCurrentLineage(legacy)
  expect_identical(
    serializationLeafStructure(legacy$levels$stock), expected_legacy
  )
  expect_identical(
    serializationLeafStructure(legacy$accepted$data$stock), expected_legacy
  )
  legacy_roundtrip = serializationResavePayload(legacy)
  serializationAssertCurrentLineage(legacy_roundtrip$normalized)
  expect_identical(legacy_roundtrip$receiver$loadedEngine, "legacy")
  expect_identical(
    serializationLeafStructure(legacy_roundtrip$receiver$data$stock),
    expected_legacy
  )
  expect_identical(
    serializationLeafStructure(legacy_roundtrip$normalized$levels$stock),
    expected_legacy
  )

  fixture = testthat::test_path(
    "fixtures", "serialization", "tabloToR-schema1-lineage.rds"
  )
  predecessor = readRDS(fixture)
  predecessor_roundtrip = serializationResavePayload(predecessor)
  expect_identical(
    predecessor_roundtrip$returned, predecessor_roundtrip$receiver
  )
  expect_identical(predecessor_roundtrip$normalized$schema_version, 1L)
  expect_identical(
    predecessor_roundtrip$normalized$package_lineage,
    .serialization_current_package_lineage()
  )
  expect_identical(
    serializationLeafStructure(
      sparse_state_data(predecessor_roundtrip$receiver$sparseState)$basedata$stock
    ),
    expected_sparse
  )
  expect_identical(
    serializationLeafStructure(
      predecessor_roundtrip$normalized$levels$basedata$stock
    ),
    expected_sparse
  )
})

test_that("current and predecessor malformed leaves reject transactionally", {
  current_unsolved = serializationBuildCurrentPayload("sparse", "unsolved")
  current_compact = serializationBuildCurrentPayload("sparse", "compact")
  current_legacy = serializationBuildCurrentPayload("legacy", "full")
  predecessor = readRDS(testthat::test_path(
    "fixtures", "serialization", "tabloToR-schema1-lineage.rds"
  ))
  regions = c("north", "south", "east")
  rejections = list()
  patterns = list()

  rejections$current_levels_logical = current_unsolved
  rejections$current_levels_logical$levels$basedata$stock =
    serializationReplaceLeafValues(
      current_unsolved$levels$basedata$stock, "logical"
    )
  patterns$current_levels_logical = "type does not match"

  rejections$current_levels_integer = current_unsolved
  rejections$current_levels_integer$levels$basedata$stock =
    serializationReplaceLeafValues(
      current_unsolved$levels$basedata$stock, "integer"
    )
  patterns$current_levels_integer = "type does not match"

  rejections$current_levels_wrong_class = current_unsolved
  rejections$current_levels_wrong_class$levels$basedata$stock =
    serializationReplaceLeafValues(
      current_unsolved$levels$basedata$stock, "matrix"
    )
  patterns$current_levels_wrong_class = "type does not match|unsupported attribute\\(s\\): class"

  rejections$current_accepted_data_integer = current_legacy
  rejections$current_accepted_data_integer$accepted$data$stock =
    serializationReplaceLeafValues(
      current_legacy$accepted$data$stock, "integer"
    )
  patterns$current_accepted_data_integer = "type does not match"

  rejections$current_compact_logical = current_compact
  rejections$current_compact_logical$accepted$compact_output$stock =
    serializationReplaceLeafValues(
      current_compact$accepted$compact_output$stock, "logical"
    )
  patterns$current_compact_logical = "type does not match"

  rejections$current_compact_integer = current_compact
  rejections$current_compact_integer$accepted$compact_output$stock =
    serializationReplaceLeafValues(
      current_compact$accepted$compact_output$stock, "integer"
    )
  patterns$current_compact_integer = "type does not match"

  rejections$current_compact_wrong_class = current_compact
  rejections$current_compact_wrong_class$accepted$compact_output$stock =
    serializationReplaceLeafValues(
      current_compact$accepted$compact_output$stock, "matrix"
    )
  patterns$current_compact_wrong_class = "type does not match|unsupported attribute\\(s\\): class"

  rejections$current_bad_dimensions = current_unsolved
  rejections$current_bad_dimensions$levels$basedata$stock = array(
    as.numeric(current_unsolved$levels$basedata$stock),
    dim = 3L,
    dimnames = list(reg = paste0("bad-", regions))
  )
  patterns$current_bad_dimensions = "dimensions do not match"

  rejections$current_nonfinite = current_unsolved
  rejections$current_nonfinite$levels$basedata$stock[[1L]] = Inf
  patterns$current_nonfinite = "non-finite"

  rejections$predecessor_levels_logical = predecessor
  rejections$predecessor_levels_logical$levels$basedata$stock =
    serializationReplaceLeafValues(
      predecessor$levels$basedata$stock, "logical"
    )
  patterns$predecessor_levels_logical = "type does not match"

  rejections$predecessor_accepted_data_integer = predecessor
  rejections$predecessor_accepted_data_integer$accepted$data$basedata$stock =
    serializationReplaceLeafValues(
      predecessor$accepted$data$basedata$stock, "integer"
    )
  patterns$predecessor_accepted_data_integer = "type does not match"

  rejections$predecessor_levels_wrong_class = predecessor
  rejections$predecessor_levels_wrong_class$levels$basedata$stock =
    serializationReplaceLeafValues(
      predecessor$levels$basedata$stock, "matrix"
    )
  patterns$predecessor_levels_wrong_class = "type does not match|unsupported attribute\\(s\\): class"

  rejections$predecessor_lineage_stale = predecessor
  rejections$predecessor_lineage_stale$package_lineage$version = "0.0.9"
  patterns$predecessor_lineage_stale = "package lineage|fingerprint mismatch"

  expect_identical(names(rejections), names(patterns))
  for (name in names(rejections)) {
    expectSerializationLeafRejected(
      rejections[[name]], patterns[[name]], info = name
    )
  }
})
