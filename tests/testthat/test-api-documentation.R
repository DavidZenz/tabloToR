rd_aliases <- function(rd) {
  aliases <- Filter(
    function(node) identical(attr(node, "Rd_tag"), "\\alias"), rd
  )
  vapply(aliases, function(node) as.character(node[[1L]]), character(1))
}

rd_text <- function(rd) {
  paste(unlist(rd, recursive = TRUE, use.names = FALSE), collapse = " ")
}

test_that("generated help covers the deliberate GEModel API", {
  package_path <- testthat::test_path("..", "..", "man", "GEModelR-package.Rd")
  class_path <- testthat::test_path("..", "..", "man", "GEModel.Rd")
  if (file.exists(package_path) && file.exists(class_path)) {
    package_rd <- tools::parse_Rd(package_path)
    class_rd <- tools::parse_Rd(class_path)
  } else {
    installed_help <- tools::Rd_db("GEModelR")
    package_rd <- installed_help[["GEModelR-package.Rd"]]
    class_rd <- installed_help[["GEModel.Rd"]]
  }
  package_aliases <- rd_aliases(package_rd)
  class_aliases <- rd_aliases(class_rd)
  expect_true("GEModelR-package" %in% package_aliases)
  expect_true("GEModel" %in% class_aliases)

  help_text <- paste(rd_text(package_rd), rd_text(class_rd))
  supported_methods <- c(
    "loadTablo", "loadData", "setShocks", "setClosure",
    "setMemoryBudget", "estimateMemory", "solveModel", "retryPostsim",
    "saveState", "loadState"
  )
  backend_ids <- c(
    "Matrix", "SparseM", "SuiteSparse", "StructuredSchur",
    "StructuredSchurFGMRES", "StructuredSchurFGMRESCpp"
  )
  option_defaults <- c(
    "GEModelR.sparse.lu_order", "GEModelR.sparse.suite_sparse_ordering",
    "GEModelR.sparse.structured_residual_tolerance",
    "GEModelR.sparse.elimination_pivot_tolerance",
    "GEModelR.sparse.schur_region_batch_size",
    "GEModelR.sparse.schur_panel_size", "GEModelR.sparse.schur_restart",
    "GEModelR.sparse.schur_max_iterations", "GEModelR.sparse.schur_tolerance",
    "GEModelR.sparse.schur_cpp_threads", "GEModelR.serialization.max_bytes",
    "GEModelR.serialization.max_elements"
  )
  diagnostic_fields <- c(
    "schema_version", "engine", "requested_backend", "implementation",
    "status", "condition_class", "accepted_numerical_state",
    "retryable_postsim", "failure_phase", "failure_reason", "cleanup_status"
  )
  diagnostic_statuses <- c(
    "running", "succeeded", "validation_failed", "capability_failed",
    "numerical_failed", "postsim_failed", "committed_state_failed"
  )
  condition_classes <- c(
    "GEModelR_validation_error", "GEModelR_capability_error",
    "GEModelR_numerical_error", "GEModelR_postsim_error",
    "GEModelR_retryable_postsim_error", "GEModelR_committed_state_error"
  )

  for (contract_item in c(
    supported_methods, backend_ids, option_defaults, diagnostic_fields,
    diagnostic_statuses, condition_classes,
    "memory_budget", "legacy", "sparse", "full", "compact",
    "2e-7", "1e-12", "268435456", "50000000"
  )) {
    expect_true(
      grepl(contract_item, help_text, fixed = TRUE),
      info = sprintf("generated help is missing %s", contract_item)
    )
  }
  expect_match(help_text, "Integer from 0 through 3", fixed = TRUE)
  expect_match(
    help_text,
    "Compact output and variable/dimension selectors are supported",
    fixed = TRUE
  )
  expect_match(help_text, "only by the sparse engine", fixed = TRUE)
  expect_match(
    help_text,
    "the legacy engine accepts full output and no",
    fixed = TRUE
  )
  expect_match(help_text, "selectors", fixed = TRUE)
  for (ordering in c("cholmod", "amd", "metis", "best", "natural", "none", "given")) {
    expect_true(grepl(ordering, help_text, fixed = TRUE))
  }
  expect_match(help_text, "No global solver-memory option", fixed = TRUE)
})
