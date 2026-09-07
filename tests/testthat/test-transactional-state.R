test_that("sparse second-substep failure is transactionally invisible", {
  model = make_three_region_model()
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  before = transactionalModelSnapshot(model, include_diagnostics = FALSE)
  failTransactionAt("after-substep", occurrence = 2L)

  expect_error(
    model$solveModel(
      iter = 1, steps = 3, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, reduction = "off"
    ),
    "injected after-substep failure"
  )

  expectTransactionalStateIdentical(before, model)
  expect_identical(model$lastDiagnostics$status, "failed")
  expect_identical(model$lastDiagnostics$failure_phase, "after-substep")
  expect_false(model$lastDiagnostics$accepted_numerical_state)
  expect_false(model$lastDiagnostics$retryable_postsim)
})

test_that("sparse simulation-update failure does not publish working state", {
  model = make_three_region_model()
  set_three_region_shocks(model, "variableValues", c(2, 0, 0))
  before = transactionalModelSnapshot(model, include_diagnostics = FALSE)
  failTransactionAt("simulation-update")

  expect_error(
    model$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
      diagnostics = TRUE, reduction = "off"
    ),
    "injected simulation-update failure"
  )

  expectTransactionalStateIdentical(before, model)
  expect_identical(model$lastDiagnostics$failure_phase, "simulation-update")
})

test_that("accepted sparse solve commits exactly once", {
  model = make_three_region_model()
  set_three_region_shocks(model, "preferred", c(1, 2, -1))
  commits = 0L
  localTransactionFault(function(phase, context) {
    if (identical(phase, "commit-accepted-state")) {
      commits <<- commits + 1L
    }
    invisible(NULL)
  })

  model$solveModel(
    iter = 1, steps = 3, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", reduction = "off"
  )

  expect_identical(commits, 1L)
  expect_equal(unname(model$solution), c(1, 3, -2), tolerance = 3e-2)
  expect_identical(model$lastDiagnostics$status, "complete")
  expect_true(model$lastDiagnostics$accepted_numerical_state)
  expect_false(model$lastDiagnostics$retryable_postsim)
})

test_that("transaction commit seam remains internal", {
  exported = getNamespaceExports("tabloToR")
  expect_true(exists(".commit_accepted_state", mode = "function"))
  expect_false(".commit_accepted_state" %in% exported)

  manifest = loadCompatibilityManifest()
  row = manifest[
    manifest$kind == "internal" &
      manifest$name == ".commit_accepted_state",
    , drop = FALSE
  ]
  expect_equal(nrow(row), 1L)
  expect_identical(row$tier, "internal")
})

test_that("sparse numerical rejection matrix preserves committed state", {
  phases = c(
    "compilation", "factorization", "convergence", "finiteness",
    "residual", "simulation-update"
  )
  for (phase in phases) {
    model = make_three_region_model()
    set_three_region_shocks(model, "preferred", c(1, 2, -1))
    before = transactionalModelSnapshot(model, include_diagnostics = FALSE)
    failTransactionAt(phase)

    expect_error(
      model$solveModel(
        iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
        diagnostics = TRUE, reduction = "off"
      ),
      paste("injected", phase, "failure"),
      info = phase
    )
    expectTransactionalStateIdentical(before, model)
    expect_identical(model$lastDiagnostics$status, "failed", info = phase)
    expect_identical(model$lastDiagnostics$failure_phase, phase, info = phase)
    expect_false(model$lastDiagnostics$accepted_numerical_state, info = phase)
  }
})

test_that("legacy rejection matrix runs on an isolated copy", {
  phases = c(
    "compilation", "factorization", "convergence", "finiteness",
    "residual", "simulation-update"
  )
  for (phase in phases) {
    model = make_three_region_model(engine = "legacy")
    set_three_region_shocks(model, "preferred", c(1, 2, -1))
    before = transactionalModelSnapshot(model, include_diagnostics = FALSE)
    failTransactionAt(phase)

    expect_error(
      model$solveModel(iter = 1, steps = 1, engine = "legacy"),
      paste("injected", phase, "failure"),
      info = phase
    )
    expectTransactionalStateIdentical(before, model)
    expect_identical(model$lastDiagnostics$status, "failed", info = phase)
    expect_identical(model$lastDiagnostics$engine, "legacy", info = phase)
    expect_identical(model$lastDiagnostics$failure_phase, phase, info = phase)
  }
})

test_that("failed legacy solves do not consume either public shock source", {
  for (api in c("preferred", "variableValues")) {
    model = make_three_region_model(engine = "legacy")
    set_three_region_shocks(model, api, c(1, 0, 0))
    source_before = list(
      explicitShocks = model$explicitShocks,
      variableValues = model$variableValues
    )
    failTransactionAt("factorization")

    expect_error(
      model$solveModel(iter = 1, steps = 1, engine = "legacy"),
      "injected factorization failure",
      info = api
    )
    expect_identical(model$explicitShocks, source_before$explicitShocks)
    expect_identical(model$variableValues, source_before$variableValues)

    localTransactionFault(NULL)
    model$solveModel(iter = 1, steps = 1, engine = "legacy")
    expect_equal(unname(model$solution), c(1, 0, 0), tolerance = 1e-12)
    model$solveModel(iter = 1, steps = 1, engine = "legacy")
    expect_equal(unname(model$solution), c(1, 0, 0), tolerance = 1e-12)
  }
})

test_that("post failures preserve accepted solve and prior complete output", {
  for (phase in c("post-update", "output-projection")) {
    model = make_three_region_model()
    set_three_region_shocks(model, "preferred", c(1, 0, 0))
    model$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
      diagnostics = TRUE, output = "compact", variables = "stock",
      reduction = "off"
    )
    prior_data = model$data
    prior_output = model$compactOutput

    set_three_region_shocks(model, "preferred", c(2, 0, 0))
    recordTransactionPhases(fail_phase = phase)
    expect_error(
      model$solveModel(
        iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
        diagnostics = TRUE, output = "compact", variables = "stock",
        reduction = "off"
      ),
      paste("injected", phase, "failure"),
      info = phase
    )

    expect_equal(unname(model$solution), c(2, 0, 0), tolerance = 1e-12)
    expect_identical(model$data, prior_data)
    expect_identical(model$compactOutput, prior_output)
    expect_identical(model$lastDiagnostics$status, "postsim-incomplete")
    expect_true(model$lastDiagnostics$accepted_numerical_state)
    expect_true(model$lastDiagnostics$retryable_postsim)
    expect_identical(model$lastDiagnostics$failure_phase, phase)
    expect_true(length(model$.postsimRecord) > 0L)

    localTransactionFault(NULL)
    expected = make_three_region_model()
    set_three_region_shocks(expected, "preferred", c(2, 0, 0))
    expected$solveModel(
      iter = 1, steps = 1, engine = "sparse", postsim = TRUE,
      diagnostics = TRUE, output = "compact", variables = "stock",
      reduction = "off"
    )

    retry_phases = recordTransactionPhases()
    returned = withVisible(model$retryPostsim(diagnostics = TRUE))
    numerical = c(
      "compilation", "factorization", "convergence", "finiteness",
      "residual", "simulation-update", "after-substep",
      "commit-accepted-state"
    )
    expect_false(any(retry_phases() %in% numerical), info = phase)
    expect_false(returned$visible)
    expect_identical(returned$value, model)
    expect_identical(model$data, expected$data)
    expect_identical(model$compactOutput, expected$compactOutput)
    expect_identical(model$lastDiagnostics$status, "complete")
    expect_false(model$lastDiagnostics$retryable_postsim)
    expect_identical(model$.postsimRecord, list())
  }
})

test_that("retryPostsim without an accepted record never enters the solver", {
  model = make_three_region_model()
  recorder = recordTransactionPhases()

  expect_error(
    model$retryPostsim(),
    "No retryable post-simulation record"
  )
  expect_identical(recorder(), character())
})

test_that("post retry API and internal helper are tiered explicitly", {
  exported = getNamespaceExports("tabloToR")
  expect_true("retryPostsim" %in% GEModel$methods())
  expect_identical(
    names(formals(GEModel$methods("retryPostsim"))),
    "diagnostics"
  )
  expect_identical(
    paste(deparse(formals(GEModel$methods("retryPostsim"))$diagnostics),
          collapse = ""),
    "FALSE"
  )
  expect_true(exists(".retry_postsim_from_record", mode = "function"))
  expect_false(any(c(
    ".commit_accepted_state", ".retry_postsim_from_record"
  ) %in% exported))

  manifest = loadCompatibilityManifest()
  retry_method = manifest[
    manifest$kind == "method" & manifest$name == "retryPostsim",
    , drop = FALSE
  ]
  retry_helper = manifest[
    manifest$kind == "internal" &
      manifest$name == ".retry_postsim_from_record",
    , drop = FALSE
  ]
  expect_equal(nrow(retry_method), 1L)
  expect_identical(retry_method$tier, "supported")
  expect_equal(nrow(retry_helper), 1L)
  expect_identical(retry_helper$tier, "internal")
})
