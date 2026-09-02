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

test_that("WF-DEFAULT-OMITTED and WF-DEFAULT-EXPLICIT are equivalent", {
  legacy_omitted = GEModel$new()
  legacy_omitted$loadTablo(three_region_fixture_path())
  legacy_omitted$setClosure("tax")
  legacy_omitted$loadData(three_region_input_data())
  set_three_region_shocks(legacy_omitted, "preferred")

  legacy_explicit = make_three_region_model(engine = "legacy")
  set_three_region_shocks(legacy_explicit, "preferred")

  omitted_visible = withVisible(
    legacy_omitted$solveModel(iter = 1, steps = 1)
  )
  explicit_visible = withVisible(legacy_explicit$solveModel(
    iter = 1, steps = 1, engine = "legacy", backend = "Matrix"
  ))

  expect_identical(legacy_omitted$loadedEngine, "legacy")
  expect_false(omitted_visible$visible)
  expect_false(explicit_visible$visible)
  expect_equal(legacy_omitted$solution, legacy_explicit$solution,
               tolerance = 1e-12)
  expect_identical(
    describeCompatibilityStructure(legacy_omitted$solution),
    describeCompatibilityStructure(legacy_explicit$solution)
  )

  sparse_omitted = make_three_region_model()
  sparse_explicit = make_three_region_model()
  set_three_region_shocks(sparse_omitted, "preferred")
  set_three_region_shocks(sparse_explicit, "preferred")
  sparse_omitted$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    diagnostics = TRUE, reduction = "off"
  )
  sparse_explicit$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    diagnostics = TRUE, backend = "Matrix", reduction = "off",
    variables = NULL, dimensions = NULL
  )

  expect_identical(sparse_omitted$lastDiagnostics$solver_backend, "Matrix")
  expect_identical(sparse_explicit$lastDiagnostics$solver_backend, "Matrix")
  expect_equal(sparse_omitted$solution, sparse_explicit$solution,
               tolerance = 1e-12)
  expect_identical(sparse_omitted$data, sparse_explicit$data)
  expect_identical(sparse_omitted$compactOutput, list())
  expect_identical(sparse_explicit$compactOutput, list())
})

test_that("WF-FULL-OUTPUT freezes full and selected structures", {
  full = make_three_region_model()
  set_three_region_shocks(full, "preferred", c(1, 2, -1))
  returned = withVisible(full$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    postsim = TRUE, diagnostics = TRUE, output = "full",
    backend = "Matrix", reduction = "off"
  ))

  expect_false(returned$visible)
  expect_identical(returned$value, full)
  expect_identical(
    describeCompatibilityStructure(full$solution),
    list(
      class = "numeric",
      type = "double",
      length = 3L,
      names = c('q["north"]', 'q["south"]', 'q["east"]'),
      dim = NULL,
      dimnames = NULL,
      missing = c(FALSE, FALSE, FALSE),
      encoding = character()
    )
  )
  expect_identical(full$compactOutput, list())
  expect_identical(
    names(full$data),
    c("basedata", "reported", "stock", "weight", "reg", "/", "tax", "q",
      "variables", "variableNumbers", "equations", "equationNumbers")
  )
  expect_identical(full$lastDiagnostics$post_simulation_retained, TRUE)

  selected = make_three_region_model()
  set_three_region_shocks(selected, "preferred", c(1, 2, -1))
  selected$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    postsim = TRUE, output = "full", variables = "stock",
    dimensions = list(reg = "south"), reduction = "off"
  )

  expect_identical(names(selected$compactOutput), "stock")
  expect_identical(
    describeCompatibilityStructure(selected$compactOutput$stock),
    list(
      class = "array",
      type = "double",
      length = 1L,
      names = "south",
      dim = 1L,
      dimnames = list(reg = "south"),
      missing = FALSE,
      encoding = character()
    )
  )
  expect_identical(names(selected$solution),
                   c('q["north"]', 'q["south"]', 'q["east"]'))

  empty = make_three_region_model()
  set_three_region_shocks(empty, "preferred")
  empty$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    variables = character(), dimensions = list(), reduction = "off"
  )
  expect_identical(empty$compactOutput, list())
})

test_that("WF-COMPACT-OUTPUT and WF-POSTSIM-OFF freeze compact structures", {
  compact = make_three_region_model()
  set_three_region_shocks(compact, "preferred", c(1, 2, -1))
  returned = withVisible(compact$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    postsim = TRUE, diagnostics = TRUE, output = "compact",
    variables = "stock", dimensions = list(reg = "south"),
    backend = "Matrix", reduction = "off"
  ))

  expect_false(returned$visible)
  expect_identical(returned$value, compact)
  expect_identical(names(compact$solution), NULL)
  expect_identical(names(compact$compactOutput), c("stock", "solution"))
  expect_identical(dim(compact$compactOutput$stock), 1L)
  expect_identical(dimnames(compact$compactOutput$stock),
                   list(reg = "south"))
  expect_identical(names(compact$compactOutput$solution), NULL)
  expect_identical(length(compact$compactOutput$solution), 3L)
  expect_true(length(compact$data) > 0L)
  expect_identical(compact$lastDiagnostics$post_simulation_retained, TRUE)

  no_postsim = make_three_region_model()
  set_three_region_shocks(no_postsim, "preferred", c(1, 2, -1))
  no_postsim$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    postsim = FALSE, diagnostics = TRUE, output = "compact",
    variables = character(), reduction = "off"
  )
  expect_identical(names(no_postsim$compactOutput), "solution")
  expect_identical(no_postsim$data, list())
  expect_identical(no_postsim$lastDiagnostics$post_simulation_retained, FALSE)
})

test_that("full output clears stale compact and selected projections", {
  model = make_three_region_model()
  set_three_region_shocks(model, "preferred")
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    output = "compact", variables = "stock", reduction = "off"
  )
  expect_identical(names(model$compactOutput), c("stock", "solution"))

  model$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    output = "full", variables = NULL, dimensions = NULL,
    reduction = "off"
  )
  expect_identical(model$compactOutput, list())
  expect_identical(names(model$solution),
                   c('q["north"]', 'q["south"]', 'q["east"]'))
})

test_that("missing and zero conventions remain distinct", {
  model = make_three_region_model()
  state = model$sparseState
  bindings = list(r = 1L, ".set:r" = "reg")

  expect_identical(
    sparse_eval_expr(
      quote(tax[r]), state, bindings, model$sparseIndex
    ),
    0
  )
  expect_true(is.na(sparse_eval_expr(
    quote(q[r]), state, bindings, model$sparseIndex
  )))

  model$setShocks(setNames(c(0, NA), c("tax[north]", "")))
  resolved = sparse_resolve_shocks(model, state, model$sparseIndex)
  expect_identical(resolved$positions, integer())
  expect_identical(resolved$values, numeric())
  expect_identical(resolved$labels, character())

  model$solveModel(
    iter = 1, steps = 1, engine = "sparse",
    postsim = FALSE, output = "full", reduction = "off"
  )
  expect_equal(unname(model$solution), c(0, 0, 0), tolerance = 1e-12)
})

test_that("WF-PREFERRED-LEGACY-SMOKE exercises only public compatibility", {
  model = make_three_region_model(engine = "legacy")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  returned = withVisible(model$solveModel(iter = 1, steps = 1))

  expect_false(returned$visible)
  expect_identical(returned$value, NULL)
  expect_identical(model$loadedEngine, "legacy")
  expect_identical(model$lastDiagnostics, list())
  expect_identical(
    describeCompatibilityStructure(model$solution),
    list(
      class = "numeric",
      type = "double",
      length = 3L,
      names = c('q["north"]', 'q["south"]', 'q["east"]'),
      dim = NULL,
      dimnames = NULL,
      missing = c(FALSE, FALSE, FALSE),
      encoding = character()
    )
  )
  expect_true(all(is.finite(model$solution)))
  expect_identical(length(model$data$q), 3L)
})

test_that("every workflow row is executable or visibly flagged", {
  lines = readLines(three_region_workflows_path(), warn = FALSE)
  required = c(
    "WF-PREFERRED-SPARSE",
    "WF-VARIABLEVALUES-SPARSE",
    "WF-PREFERRED-LEGACY-SMOKE",
    "WF-DEFAULT-OMITTED",
    "WF-DEFAULT-EXPLICIT",
    "WF-REPEATED-SOLVE",
    "WF-FULL-OUTPUT",
    "WF-COMPACT-OUTPUT",
    "WF-POSTSIM-OFF"
  )

  for (id in required) {
    row = lines[grepl(paste0("`", id, "`"), lines, fixed = TRUE)]
    expect_length(row, 1L)
    expect_match(row, "VERIFIED", fixed = TRUE, info = id)
    expect_match(row, "test-documented-workflow.R", fixed = TRUE, info = id)
  }
  unclassified = lines[grepl("`WF-UNCLASSIFIED`", lines, fixed = TRUE)]
  expect_length(unclassified, 1L)
  expect_match(unclassified, "FLAGGED-UNVERIFIED", fixed = TRUE)
})
