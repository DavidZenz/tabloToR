lifecycleModelSnapshot = function(model) {
  fields = c(
    "shocks", "skeletonGenerator", "sparseSkeletonGenerator",
    "equationCoefficientMatrixGenerator", "equationCoefficientGenerator",
    "generateVariables", "generateUpdates", "data", "solution",
    "changeVariables", "variables", "basicChangeVariables",
    "variableValues", "tabloStatements", "sparseSpec", "sparseIndex",
    "sparseState", "loadedEngine", "closure", "explicitShocks",
    "sourceData", "memoryBudget", "lastDiagnostics", "compactOutput",
    ".postsimRecord"
  )
  snapshot = lapply(fields, function(name) {
    value = model[[name]]
    if (identical(name, "sparseState") && is.environment(value)) {
      return(as.list.environment(value, all.names = TRUE))
    }
    value
  })
  names(snapshot) = fields
  snapshot
}

captureLifecycleCondition = function(expression) {
  tryCatch(force(expression), error = function(error) error)
}

expectLifecycleValidation = function(error, next_method,
                                     failure_phase = "validation") {
  expect_true(inherits(error, "GEModelR_validation_error"))
  expect_identical(class(error)[[1L]], "GEModelR_validation_error")
  expect_identical(error$failure_phase, failure_phase)
  expect_identical(error$remediation$next_method, next_method)
  expect_true(is.character(error$remediation$action))
  expect_length(error$remediation$action, 1L)
  expect_true(nzchar(error$remediation$action))
}

test_that("lifecycle guards identify the next required public method", {
  model = GEModel$new()

  expectLifecycleValidation(
    captureLifecycleCondition(model$loadData(
      three_region_input_data(), engine = "sparse"
    )),
    "loadTablo"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$solveModel(engine = "legacy")),
    "loadTablo"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$estimateMemory(engine = "legacy")),
    "loadTablo"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$retryPostsim()),
    "loadTablo"
  )

  model$loadTablo(three_region_fixture_path())
  expectLifecycleValidation(
    captureLifecycleCondition(model$solveModel(engine = "legacy")),
    "loadData"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$estimateMemory(engine = "legacy")),
    "loadData"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$retryPostsim()),
    "loadData"
  )
})

test_that("lifecycle and selector argument failures use the stable class", {
  model = GEModel$new()
  expectLifecycleValidation(
    captureLifecycleCondition(model$loadTablo(NA_character_)),
    "loadTablo"
  )

  model$loadTablo(three_region_fixture_path())
  expectLifecycleValidation(
    captureLifecycleCondition(model$loadData(
      three_region_input_data(), engine = "unknown"
    )),
    "loadData"
  )
  model$loadData(three_region_input_data(), engine = "sparse")

  expectLifecycleValidation(
    captureLifecycleCondition(model$solveModel(engine = "unknown")),
    "solveModel"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$estimateMemory(engine = "unknown")),
    "estimateMemory"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$estimateMemory(
      engine = "sparse", postsim = 1
    )),
    "estimateMemory"
  )
  expectLifecycleValidation(
    captureLifecycleCondition(model$retryPostsim(diagnostics = 1)),
    "retryPostsim"
  )
})

test_that("solve engine must match the loaded runtime until data is reloaded", {
  for (loaded_engine in c("legacy", "sparse")) {
    model = make_three_region_model(engine = loaded_engine)
    requested_engine = if (identical(loaded_engine, "legacy")) {
      "sparse"
    } else {
      "legacy"
    }
    before = lifecycleModelSnapshot(model)
    error = captureLifecycleCondition(model$solveModel(
      iter = 1, steps = 1, engine = requested_engine, postsim = FALSE
    ))

    expectLifecycleValidation(error, "loadData")
    expect_identical(error$requested_engine, requested_engine)
    expect_identical(error$loaded_engine, loaded_engine)
    expect_identical(lifecycleModelSnapshot(model), before)

    model$loadData(three_region_input_data(), engine = requested_engine)
    expect_identical(model$loadedEngine, requested_engine)
    model$solveModel(
      iter = 1, steps = 1, engine = requested_engine, postsim = FALSE,
      reduction = "off"
    )
    expect_identical(model$loadedEngine, requested_engine)
  }
})

test_that("failed TABLO and data setup preserve every prior model field", {
  model = make_three_region_model(engine = "sparse")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", reduction = "off"
  )

  old_fault = getOption("GEModelR.transaction.fault")
  on.exit(options(GEModelR.transaction.fault = old_fault), add = TRUE)
  options(GEModelR.transaction.fault = function(phase, context) {
    if (identical(phase, "post-update")) {
      stop("injected lifecycle postsimulation failure", call. = FALSE)
    }
    invisible(NULL)
  })
  expect_error(model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "compact", variables = "stock",
    reduction = "off"
  ), "injected lifecycle postsimulation failure")
  expect_true(length(model$.postsimRecord) > 0L)

  before_tablo = lifecycleModelSnapshot(model)
  error = captureLifecycleCondition(model$loadTablo(tempfile(fileext = ".tab")))
  expectLifecycleValidation(error, "loadTablo")
  expect_identical(lifecycleModelSnapshot(model), before_tablo)

  failed_data_model = make_three_region_model(engine = "sparse")
  failed_data_model$sparseSkeletonGenerator = function(input_data) {
    stop("injected data setup failure", call. = FALSE)
  }
  before_data = lifecycleModelSnapshot(failed_data_model)
  error = captureLifecycleCondition(failed_data_model$loadData(
    three_region_input_data(), engine = "sparse"
  ))
  expectLifecycleValidation(error, "loadData", failure_phase = "loadData")
  expect_identical(error$requested_engine, "sparse")
  expect_identical(lifecycleModelSnapshot(failed_data_model), before_data)
})
