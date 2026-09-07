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

test_that("serialization entry points and helpers have explicit contract rows", {
  manifest = loadCompatibilityManifest()
  expected = data.frame(
    kind = c("method", "method", rep("internal", 3L)),
    name = c(
      "saveState", "loadState", ".build_logical_state_payload",
      ".validate_logical_state_payload", ".restore_logical_state_payload"
    ),
    tier = c("supported", "supported", rep("internal", 3L)),
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
  path = testthat::test_path(
    "..", "..", "inst", "compatibility", "SERIALIZATION.md"
  )
  expect_true(file.exists(path))
  text = paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_match(text, "gemodel-logical-state", fixed = TRUE)
  expect_match(text, "schema version 1", fixed = TRUE)
  expect_match(text, "same-version compatibility-only", fixed = TRUE)
  expect_match(text, "trusted local", ignore.case = TRUE)
  expect_match(text, "cache", ignore.case = TRUE)
})
