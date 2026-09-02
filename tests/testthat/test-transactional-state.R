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
  expect_equal(unname(model$solution), c(1, 3, -2), tolerance = 1e-12)
  expect_identical(model$lastDiagnostics$status, "complete")
  expect_true(model$lastDiagnostics$accepted_numerical_state)
  expect_false(model$lastDiagnostics$retryable_postsim)
})

test_that("transaction commit seam remains internal", {
  exported = getNamespaceExports("tabloToR")
  expect_true(exists(".commit_accepted_state", mode = "function"))
  expect_false(".commit_accepted_state" %in% exported)

  manifest = readCompatibilityManifest()
  row = manifest[
    manifest$kind == "internal" &
      manifest$name == ".commit_accepted_state",
    , drop = FALSE
  ]
  expect_equal(nrow(row), 1L)
  expect_identical(row$tier, "internal")
})
