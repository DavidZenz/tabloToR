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
  expect_equal(workflow$states$shocks_set$values, c(1, 2, -1))
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
