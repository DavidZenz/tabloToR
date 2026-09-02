test_that("WF-PREFERRED-SPARSE runs the public three-region workflow", {
  workflow = run_three_region_workflow()
  model = workflow$model

  expect_identical(
    names(workflow$states),
    c("fresh", "tablo_loaded", "closure_set", "data_loaded",
      "shocks_set", "solved")
  )
  expect_identical(workflow$states$fresh$loaded_engine, character())
  expect_identical(workflow$states$tablo_loaded$compile_errors, character())
  expect_identical(workflow$states$closure_set$closure, "tax")
  expect_identical(workflow$states$data_loaded$loaded_engine, "sparse")
  expect_identical(workflow$states$data_loaded$variable_values, list())
  expect_identical(
    workflow$states$shocks_set$labels,
    c('tax["north"]', 'tax["south"]', 'tax["east"]')
  )
  expect_equal(unname(workflow$states$shocks_set$values), c(1, 2, -1))
  expect_identical(workflow$states$solved$loaded_engine, "sparse")

  expected_solution_structure = list(
    class = "numeric",
    type = "double",
    length = 3L,
    names = c('q["north"]', 'q["south"]', 'q["east"]'),
    dim = NULL,
    dimnames = NULL,
    missing = c(FALSE, FALSE, FALSE),
    encoding = character()
  )
  expect_identical(
    describeCompatibilityStructure(model$solution),
    expected_solution_structure
  )
  expect_equal(unname(model$solution), c(1, 3, -2), tolerance = 1e-12)
  expect_equal(as.numeric(model$data$stock), c(101, 203, 298),
               tolerance = 1e-12)
  expect_equal(as.numeric(model$data$reported), c(101, 203, 298),
               tolerance = 1e-12)
  expect_identical(model$lastDiagnostics$solver_backend, "Matrix")
  expect_false(model$lastDiagnostics$dense_fallback)
})

test_that("the public three-region fixture is small and redistributable", {
  fixture = three_region_fixture_path()
  provenance = three_region_provenance_path()
  fixture_text = readLines(fixture, warn = FALSE)
  provenance_text = paste(readLines(provenance, warn = FALSE), collapse = "\n")

  expect_lt(file.info(fixture)$size, 4096)
  expect_false(any(grepl("GTAP|SmallAg|private|proprietary",
                         fixture_text, ignore.case = TRUE)))
  expect_match(provenance_text, "newly authored", ignore.case = TRUE)
  expect_match(provenance_text, "CC0-1.0", fixed = TRUE)
  expect_match(provenance_text, "three-region.tab", fixed = TRUE)
  expect_match(provenance_text, unname(tools::md5sum(fixture)), fixed = TRUE)
  expect_match(provenance_text, "no copied.*GTAP.*SmallAg",
               ignore.case = TRUE)
})

test_that("WF-PREFERRED-SPARSE is mapped to executable public calls", {
  workflows = paste(
    readLines(three_region_workflows_path(), warn = FALSE),
    collapse = "\n"
  )

  expect_match(workflows, "WF-PREFERRED-SPARSE", fixed = TRUE)
  expect_match(
    workflows,
    "GEModel$new() -> loadTablo() -> setClosure() -> loadData() -> setShocks() -> solveModel()",
    fixed = TRUE
  )
  expect_match(workflows, "Matrix", fixed = TRUE)
})

test_that("D-03 shock APIs share normalized indexed application semantics", {
  preferred = make_three_region_model()
  preferred$setShocks(setNames(
    c(0, NA, 1, 2, -3, 4),
    c("", "tax[east]", 'tax["north"]', "tax[ north ]",
      "tax[north]", 'tax["south"]')
  ))
  direct = make_three_region_model()
  direct$variableValues = list(
    tax = three_region_shock_array(c(0, 4, NA))
  )
  legacy = make_three_region_model(engine = "legacy")
  legacy$setShocks(setNames(
    c(0, NA, 1, 2, -3, 4),
    c("", "tax[east]", 'tax["north"]', "tax[ north ]",
      "tax[north]", 'tax["south"]')
  ))

  preferred_resolved = sparse_resolve_shocks(
    preferred, preferred$sparseState, preferred$sparseIndex
  )
  direct_resolved = sparse_resolve_shocks(
    direct, direct$sparseState, direct$sparseIndex
  )

  expect_identical(preferred_resolved$positions, direct_resolved$positions)
  expect_equal(preferred_resolved$values, direct_resolved$values)
  expect_identical(preferred_resolved$labels, 'tax["south"]')
  expect_equal(preferred_resolved$values, 4)

  solve_three_region_once(preferred)
  solve_three_region_once(direct)
  solve_three_region_once(legacy, engine = "legacy")
  expect_equal(preferred$solution, direct$solution, tolerance = 1e-12)
  expect_equal(unname(preferred$solution), c(0, 6, 0), tolerance = 1e-12)
  expect_equal(unname(legacy$solution), c(0, 6, 0), tolerance = 1e-12)
})

test_that("shock normalization preserves scalar and multi-index labels", {
  normalized = sparse_normalize_shocks(setNames(
    c(2, 3),
    c("scalar[]", 'matrix["north","east"]')
  ))
  scalar = sparse_parse_label(normalized$labels[[1L]])
  multi = sparse_parse_label(normalized$labels[[2L]])

  expect_identical(unname(normalized$values), c(2, 3))
  expect_identical(scalar, list(name = "scalar", indices = character()))
  expect_identical(
    multi,
    list(name = "matrix", indices = c("north", "east"))
  )
})

test_that("missing-element subassignment is partial positional input", {
  model = make_three_region_model()
  model$variableValues$tax[2L] = 2
  resolved = sparse_resolve_shocks(
    model, model$sparseState, model$sparseIndex
  )

  expect_identical(model$variableValues$tax, c(NA_real_, 2))
  expect_identical(resolved$labels, 'tax["south"]')
  expect_equal(resolved$values, 2)
})

test_that("WF-REPEATED-SOLVE retains then clears shocks for both APIs", {
  for (engine in c("sparse", "legacy")) {
    for (api in c("preferred", "variableValues")) {
      model = make_three_region_model(engine = engine)
      set_three_region_shocks(model, api)

      solve_three_region_once(model, engine = engine)
      first = model$solution
      solve_three_region_once(model, engine = engine)
      retained = model$solution

      clear_three_region_shocks(model, api)
      solve_three_region_once(model, engine = engine)
      cleared = model$solution

      label = paste(engine, api)
      expect_equal(unname(first), c(1, 0, 0), tolerance = 1e-12,
                   info = label)
      expect_equal(retained, first, tolerance = 1e-12, info = label)
      expect_equal(unname(cleared), c(0, 0, 0), tolerance = 1e-12,
                   info = label)
    }
  }
})
