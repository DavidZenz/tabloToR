three_region_fixture_path = function() {
  normalizePath(
    testthat::test_path("fixtures", "three-region.tab"),
    mustWork = TRUE
  )
}

three_region_provenance_path = function() {
  normalizePath(
    testthat::test_path("fixtures", "PROVENANCE.md"),
    mustWork = TRUE
  )
}

three_region_workflows_path = function() {
  installed = system.file(
    "compatibility", "WORKFLOWS.md",
    package = "tabloToR"
  )
  source = testthat::test_path(
    "..", "..", "inst", "compatibility", "WORKFLOWS.md"
  )
  candidates = c(installed, source)
  candidates = candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) {
    stop("Compatibility workflow matrix is missing", call. = FALSE)
  }
  normalizePath(candidates[[1]], mustWork = TRUE)
}

three_region_input_data = function() {
  regions = c("north", "south", "east")
  list(
    basedata = list(
      weight = array(
        c(1, 1.5, 2),
        dim = 3L,
        dimnames = list(reg = regions)
      ),
      stock = array(
        c(100, 200, 300),
        dim = 3L,
        dimnames = list(reg = regions)
      )
    )
  )
}

phase02_workflow_snapshot = function(model) {
  explicit = model$explicitShocks
  list(
    loaded_engine = model$loadedEngine,
    closure = model$closure,
    variable_values = model$variableValues,
    compile_errors = if (is.null(model$sparseSpec$compile_errors)) {
      character()
    } else {
      as.character(model$sparseSpec$compile_errors)
    },
    labels = if (is.null(explicit$labels)) character() else explicit$labels,
    values = if (is.null(explicit$values)) numeric() else explicit$values,
    solution = describeCompatibilityStructure(model$solution)
  )
}

make_three_region_model = function(engine = "sparse") {
  model = GEModel$new()
  model$loadTablo(three_region_fixture_path())
  model$setClosure("tax")
  model$loadData(three_region_input_data(), engine = engine)
  model
}

three_region_shock_array = function(values = c(1, 0, 0)) {
  array(
    as.numeric(values),
    dim = 3L,
    dimnames = list(reg = c("north", "south", "east"))
  )
}

set_three_region_shocks = function(model, api, values = c(1, 0, 0)) {
  api = match.arg(api, c("preferred", "variableValues"))
  if (api == "preferred") {
    model$setShocks(setNames(
      as.numeric(values),
      c('tax["north"]', 'tax["south"]', 'tax["east"]')
    ))
  } else {
    model$variableValues = list(tax = three_region_shock_array(values))
  }
  invisible(model)
}

clear_three_region_shocks = function(model, api) {
  api = match.arg(api, c("preferred", "variableValues"))
  if (api == "preferred") {
    model$setShocks(setNames(0, 'tax["north"]'))
  } else {
    model$variableValues = list()
  }
  invisible(model)
}

solve_three_region_once = function(model, engine = "sparse") {
  model$solveModel(
    iter = 1,
    steps = 1,
    engine = engine,
    postsim = FALSE,
    diagnostics = TRUE,
    output = "full",
    backend = "Matrix",
    reduction = "off"
  )
  invisible(model)
}

run_three_region_workflow = function() {
  model = GEModel$new()
  states = list(fresh = phase02_workflow_snapshot(model))

  model$loadTablo(three_region_fixture_path())
  states$tablo_loaded = phase02_workflow_snapshot(model)

  model$setClosure("tax")
  states$closure_set = phase02_workflow_snapshot(model)

  model$loadData(three_region_input_data(), engine = "sparse")
  states$data_loaded = phase02_workflow_snapshot(model)

  model$setShocks(setNames(
    c(1, 2, -1),
    c('tax["north"]', 'tax["south"]', 'tax["east"]')
  ))
  states$shocks_set = phase02_workflow_snapshot(model)

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
  states$solved = phase02_workflow_snapshot(model)

  list(model = model, states = states)
}
