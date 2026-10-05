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
    after = lifecycleModelSnapshot(model)
    after$lastDiagnostics = before$lastDiagnostics
    expect_identical(after, before)
    expect_identical(names(model$lastDiagnostics), .gemodelr_diagnostics_fields)
    expect_identical(model$lastDiagnostics$status, "validation_failed")
    expect_identical(model$lastDiagnostics$condition_class,
                     "GEModelR_validation_error")
    expect_identical(model$lastDiagnostics$engine, requested_engine)
    expect_identical(model$lastDiagnostics$requested_backend, "Matrix")

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

test_that("closure changes clear accepted outputs and dependent caches", {
  model = make_three_region_model(engine = "sparse")
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "compact", variables = "stock",
    reduction = "off"
  )
  failTransactionAt("post-update")
  expect_error(model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "compact", variables = "stock",
    reduction = "off"
  ), "injected post-update failure")
  expect_true(length(model$.postsimRecord) > 0L)
  expect_true(length(model$lastDiagnostics) > 0L)

  prior_spec = model$sparseSpec
  prior_source = model$sourceData
  prior_data = sparse_state_data(model$sparseState)
  model$sparseState$.solver_cache = list(
    StructuredSchurFGMRESCpp = list(index_key = "stale closure cache")
  )
  model$sparseIndex$pattern_cache = list(key = "stale closure pattern")
  model$sparseIndex$column_order = 1L

  model$setClosure(character())

  expect_identical(model$solution, numeric())
  expect_identical(model$compactOutput, list())
  expect_identical(model$.postsimRecord, list())
  expect_identical(model$lastDiagnostics, list())
  expect_identical(model$sparseSpec, prior_spec)
  expect_identical(model$sourceData, prior_source)
  expect_identical(sparse_state_data(model$sparseState), prior_data)
  expect_identical(model$closure, character())
  expect_identical(model$sparseIndex$closure_names, character())
  expect_null(model$sparseIndex$pattern_cache)
  expect_null(model$sparseIndex$column_order)
  expect_false(isTRUE(model$sparseIndex$row_layout_ready))
  expect_identical(model$sparseState$.solver_cache, list())
})

test_that("invalid closure names preserve solved state for both engines", {
  for (engine in c("sparse", "legacy")) {
    model = make_three_region_model(engine = engine)
    set_three_region_shocks(model, "preferred", c(1, 2, -1))

    if (identical(engine, "sparse")) {
      fail_retryable_postsim = function() {
        failTransactionAt("post-update", env = environment())
        expect_error(model$solveModel(
          iter = 1, steps = 1, engine = engine, postsim = TRUE,
          diagnostics = TRUE, output = "compact", variables = "stock",
          reduction = "off"
        ), "injected post-update failure")
      }
      model$solveModel(
        iter = 1, steps = 1, engine = engine, postsim = TRUE,
        diagnostics = TRUE, output = "compact", variables = "stock",
        reduction = "off"
      )
      fail_retryable_postsim()
      expect_true(length(model$.postsimRecord) > 0L)
      expect_true(model$lastDiagnostics$retryable_postsim)
      expect_true(length(model$compactOutput) > 0L)
    } else {
      model$solveModel(
        iter = 1, steps = 1, engine = engine, postsim = FALSE,
        diagnostics = TRUE, output = "full", reduction = "off"
      )
      expect_length(model$sparseIndex, 0L)
    }

    expect_true(length(model$solution) > 0L)
    expect_true(length(model$lastDiagnostics) > 0L)
    before = lifecycleModelSnapshot(model)

    expect_error(model$setClosure("not_a_tablo_variable"),
                 "Unknown closure variable")
    expect_identical(lifecycleModelSnapshot(model), before)

    model$setClosure("q")
    expect_identical(model$closure, "q")
    expect_identical(model$solution, numeric())
    expect_identical(model$compactOutput, list())
    expect_identical(model$.postsimRecord, list())
    expect_identical(model$lastDiagnostics, list())
    if (identical(engine, "sparse")) {
      expect_identical(model$sparseIndex$closure_names, "q")
      q_id = model$sparseIndex$variable_by_name$q
      tax_id = model$sparseIndex$variable_by_name$tax
      expect_true(model$sparseIndex$variables[[q_id]]$exogenous)
      expect_false(model$sparseIndex$variables[[tax_id]]$exogenous)
      expect_null(model$sparseIndex$pattern_cache)
    } else {
      expect_length(model$sparseIndex, 0L)
    }
  }
})

test_that("shock changes clear pending solve state but retain logical inputs", {
  model = make_three_region_model(engine = "sparse")
  model$variableValues = list(
    tax = three_region_shock_array(c(1, 2, -1))
  )
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "compact", variables = "stock",
    reduction = "off"
  )
  failTransactionAt("post-update")
  expect_error(model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
    diagnostics = TRUE, output = "compact", variables = "stock",
    reduction = "off"
  ), "injected post-update failure")
  expect_true(length(model$.postsimRecord) > 0L)
  expect_true(length(model$lastDiagnostics) > 0L)

  prior_spec = model$sparseSpec
  prior_source = model$sourceData
  prior_index = model$sparseIndex
  prior_state = sparse_state_data(model$sparseState)
  prior_cache = model$sparseState$.solver_cache
  prior_values = model$variableValues
  prior_solution = model$solution
  prior_output = model$compactOutput

  model$setShocks(setNames(
    c(2, 0, -2),
    c('tax["north"]', 'tax["south"]', 'tax["east"]')
  ))

  expect_identical(model$.postsimRecord, list())
  expect_identical(model$lastDiagnostics, list())
  expect_identical(model$sparseSpec, prior_spec)
  expect_identical(model$sourceData, prior_source)
  expect_identical(model$sparseIndex, prior_index)
  expect_identical(sparse_state_data(model$sparseState), prior_state)
  expect_identical(model$sparseState$.solver_cache, prior_cache)
  expect_identical(model$variableValues, prior_values)
  expect_identical(model$solution, prior_solution)
  expect_identical(model$compactOutput, prior_output)
})
