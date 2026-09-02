test_that("three-region tolerance is selected by fixture conditioning", {
  tolerances = loadNumericalTolerances()
  selected = numericalToleranceFor("three-region", "ordinary")

  expect_false("backend" %in% names(tolerances))
  expect_identical(selected$tier, "strict")
  expect_equal(selected$solution_atol, 1e-10)
  expect_equal(selected$solution_rtol, 1e-8)
  expect_equal(selected$residual_rtol, 1e-10)
  expect_match(selected$rationale, "no conditioning exception", fixed = TRUE)
  expect_true(nzchar(selected$reviewer))
})

test_that("Matrix candidate passes backend-neutral true residual acceptance", {
  prepared = threeRegionMatrixCandidate()
  tolerance = numericalToleranceFor("three-region", "ordinary")

  accepted = .sparse_accept_candidate(
    prepared$candidate,
    expected_structure = describeCompatibilityStructure(numeric(3L)),
    residual_tolerance = tolerance$residual_rtol,
    diagnostics = FALSE
  )

  expect_true(accepted$accepted)
  expect_true(accepted$finite)
  expect_identical(accepted$backend, "Matrix")
  expect_identical(
    accepted$output_structure,
    describeCompatibilityStructure(numeric(3L))
  )
  expect_s4_class(accepted$coefficient_matrix, "sparseMatrix")
  expect_false(is.matrix(accepted$coefficient_matrix))
  expect_equal(accepted$rhs, c(1, 3, -2), tolerance = 1e-12)
  expect_lte(accepted$true_residual$relative_l2, tolerance$residual_rtol)
  expect_null(accepted$retained_diagnostics)
})

test_that("bad finite candidates are rejected before state mutation", {
  for (diagnostics in c(FALSE, TRUE)) {
    prepared = threeRegionMatrixCandidate()
    before = prepared$state$data
    corrupt = function(candidate) {
      candidate$solution = candidate$solution + 1
      candidate
    }

    expect_error(
      .sparse_solve_one_step_reference(
        prepared$state,
        prepared$model,
        prepared$index,
        prepared$shocks,
        backend = "Matrix",
        reduction = "off",
        measure = diagnostics,
        candidate_transform = corrupt
      ),
      "true residual.*solution was not applied"
    )
    expect_identical(prepared$state$data, before)
  }
})

test_that("candidate acceptance stays outside broad alphabetic exports", {
  expect_false(
    ".sparse_accept_candidate" %in% getNamespaceExports("tabloToR")
  )
})
