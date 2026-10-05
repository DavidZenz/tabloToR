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
      .sparse_solve_one_step_impl(
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
    any(c(".sparse_accept_candidate", ".sparse_solve_one_step_impl") %in%
          getNamespaceExports("GEModelR"))
  )
  expect_false(
    "candidate_transform" %in% names(formals(sparse_solve_one_step))
  )
})

test_that("backend declarations encode layered numerical authority", {
  declarations = numericalBackendDeclarations()

  expect_identical(
    declarations$authority[declarations$backend == "Matrix"],
    "Matrix"
  )
  expect_identical(
    declarations$authority[
      declarations$backend == "StructuredSchurFGMRESCpp"
    ],
    "StructuredSchurFGMRES"
  )
  expect_identical(
    declarations$role[declarations$backend == "legacy"],
    "compatibility-smoke"
  )
  expect_true(all(declarations$required[
    declarations$backend %in%
      c("Matrix", "SparseM", "StructuredSchurFGMRES", "legacy")
  ]))
  expect_false(any(declarations$required[
    declarations$backend %in%
      c("SuiteSparse", "StructuredSchurFGMRESCpp", "OpenMP")
  ]))
})

test_that("conditioning tiers are explicit and never backend-specific", {
  tolerances = loadNumericalTolerances()
  ordinary = tolerances[tolerances$conditioning == "ordinary", , drop = FALSE]
  exception = numericalToleranceFor(
    "full-gtap-external", "ill-conditioned"
  )

  expect_false("backend" %in% names(tolerances))
  expect_true(all(ordinary$residual_rtol == 1e-10))
  expect_equal(exception$residual_rtol, 2e-7)
  expect_match(exception$rationale, "external only", fixed = TRUE)
  expect_match(
    exception$rationale, "never a backend-specific exception", fixed = TRUE
  )
})

test_that("compact expectation rows freeze transparent canonical outputs", {
  expectations = loadNumericalExpectations()
  authority = runThreeRegionBackend("Matrix")
  selected = expectations[
    expectations$fixture == "three-region", , drop = FALSE
  ]

  expect_equal(nrow(selected), 6L)
  expect_identical(
    paste(names(authority$output), collapse = "|"),
    selected$value[selected$key == "solution.names"]
  )
  values = selected[selected$kind == "value", , drop = FALSE]
  expect_equal(
    unname(authority$output),
    as.numeric(values$value),
    tolerance = 1e-12
  )
  expect_lt(file.info(numericalBaselinePath("expectations.csv"))$size, 4096)
})

test_that("required generic backends execute against Matrix authority", {
  tolerance = numericalToleranceFor("three-region", "ordinary")
  authority = runThreeRegionBackend("Matrix")

  for (backend in c("Matrix", "SparseM")) {
    capability = numericalBackendCapability(backend)
    skipOptionalCapability(capability)
    candidate = runThreeRegionBackend(backend)
    expectNumericalEquivalent(
      authority$output, candidate$output, tolerance,
      authority$system, candidate$system, info = backend
    )
    expect_identical(candidate$model$lastDiagnostics$solver_backend, backend)
  }
})

test_that("optional SuiteSparse has explicit availability behavior", {
  capability = numericalBackendCapability("SuiteSparse")
  skipOptionalCapability(capability)
  tolerance = numericalToleranceFor("three-region", "ordinary")
  authority = runThreeRegionBackend("Matrix")
  candidate = runThreeRegionBackend("SuiteSparse")

  expectNumericalEquivalent(
    authority$output, candidate$output, tolerance,
    authority$system, candidate$system, info = "SuiteSparse"
  )
})

test_that("required structured R authority executes with full residual", {
  capability = numericalBackendCapability("StructuredSchurFGMRES")
  skipOptionalCapability(capability)
  tolerance = numericalToleranceFor("tiny-structured", "ordinary")
  authority = runStructuredBackend("StructuredSchurFGMRES")

  expect_equal(unname(authority$output), 1:7, tolerance = 1e-10)
  expectNumericalEquivalent(
    authority$output, authority$output, tolerance,
    authority$system, authority$system,
    info = "StructuredSchurFGMRES authority"
  )
  expect_identical(
    authority$model$lastDiagnostics$solver_backend,
    "StructuredSchurFGMRES"
  )
})

test_that("optional structured C++ is accepted against structured R", {
  capability = numericalBackendCapability("StructuredSchurFGMRESCpp")
  skipOptionalCapability(capability)
  tolerance = numericalToleranceFor("tiny-structured", "ordinary")
  authority = runStructuredBackend("StructuredSchurFGMRES")
  candidate = runStructuredBackend("StructuredSchurFGMRESCpp")

  expectNumericalEquivalent(
    authority$output, candidate$output, tolerance,
    authority$system, candidate$system,
    info = "StructuredSchurFGMRESCpp"
  )
  expect_identical(
    candidate$model$lastDiagnostics$candidate_acceptance$backend,
    "StructuredSchurFGMRESCpp"
  )
  expect_true(candidate$model$lastDiagnostics$candidate_acceptance$finite)
  expect_lte(
    candidate$model$lastDiagnostics$candidate_acceptance$
      true_residual$relative_l2,
    tolerance$residual_rtol
  )
})

test_that("optional OpenMP path matches serial native accumulation", {
  capability = numericalBackendCapability("OpenMP")
  skipOptionalCapability(capability)
  fixture = make_cpp_schur_fixture()
  local = which(fixture$row_group == 0L)
  regions = list(
    which(fixture$row_group == 1L),
    which(fixture$row_group == 2L)
  )
  global = which(fixture$row_group == 3L)
  external = unlist(c(regions, list(global)), use.names = FALSE)
  B = fixture$A[local, local, drop = FALSE]
  L = fixture$A[external, local, drop = FALSE]
  R = fixture$A[local, external, drop = FALSE]
  D = fixture$A[external, external, drop = FALSE]
  factor = Matrix::lu(B, order = 1L)
  external_regions = list(
    seq_along(regions[[1L]]),
    length(regions[[1L]]) + seq_along(regions[[2L]])
  )
  external_global = sum(vapply(regions, length, integer(1))) +
    seq_along(global)

  serial = .GEModelR_schur_accumulate_batch_serial(
    list(factor), list(L), list(R), D, external_regions,
    external_global, 1:2, 2L, 1L
  )
  parallel = .GEModelR_schur_accumulate_batch(
    list(factor), list(L), list(R), D, external_regions,
    external_global, 1:2, 2L, 2L
  )

  expect_equal(parallel$regional, serial$regional, tolerance = 1e-10)
  expect_equal(parallel$global_region, serial$global_region,
               tolerance = 1e-10)
  expect_identical(parallel$diagnostics$threads_effective, 2L)
})

test_that("mocked optional unavailability emits the exact skip reason", {
  capability = numericalBackendCapability(
    "StructuredSchurFGMRESCpp",
    available = FALSE,
    reason = "mocked native symbol absence"
  )
  condition = tryCatch(
    skipOptionalCapability(capability),
    skip = function(condition) condition
  )

  expect_s3_class(condition, "skip")
  expect_identical(
    conditionMessage(condition),
    paste0(
      "Reason: optional capability StructuredSchurFGMRESCpp unavailable: ",
      "mocked native symbol absence"
    )
  )
})
