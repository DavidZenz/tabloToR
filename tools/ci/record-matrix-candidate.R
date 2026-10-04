#!/usr/bin/env Rscript

# Record observed outcomes without treating skipped work as passing evidence.
recordMatrixCandidate = function() {
  required = function(name) {
    value = Sys.getenv(name, unset = "")
    if (!nzchar(value)) stop(paste("Missing candidate evidence field:", name),
                             call. = FALSE)
    value
  }
  outcome = function(name) {
    value = Sys.getenv(name, unset = "")
    if (!nzchar(value) || identical(value, "skipped")) value = "not_run"
    stopifnot(value %in% c("success", "failure", "cancelled", "not_run"))
    value
  }
  row = data.frame(
    setup_r_alias = required("GEModelR_SETUP_R_ALIAS"),
    resolved_r_version = as.character(getRversion()),
    os = required("GEModelR_PLATFORM"),
    build_mode = required("GEModelR_BUILD_MODE"),
    candidate_label = required("GEModelR_CANDIDATE_LABEL"),
    matrix_version = required("GEModelR_EXPECT_MATRIX_VERSION"),
    source_install_result = outcome("GEModelR_SOURCE_INSTALL_RESULT"),
    solver_test_result = outcome("GEModelR_SOLVER_TEST_RESULT"),
    run_id = required("GITHUB_RUN_ID"),
    stringsAsFactors = FALSE
  )
  directory = required("GEModelR_EVIDENCE_DIR")
  if (!dir.exists(directory)) dir.create(directory, recursive = TRUE)
  path = file.path(directory, "matrix-candidate-evidence.csv")
  utils::write.csv(row, path, row.names = FALSE, na = "")
  summary = c(
    "## Provisional Matrix candidate evidence",
    "",
    paste("|", paste(names(row), collapse = " | "), "|"),
    paste("|", paste(rep("---", ncol(row)), collapse = " | "), "|"),
    paste("|", paste(unlist(row, use.names = FALSE), collapse = " | "), "|"),
    "",
    "Candidate evidence only; no final Matrix floor is selected.",
    ""
  )
  writeLines(summary, file.path(directory, "job-summary.md"))
  cat(paste(summary, collapse = "\n"), "\n")
  githubSummary = Sys.getenv("GITHUB_STEP_SUMMARY")
  if (nzchar(githubSummary)) {
    cat(paste(summary, collapse = "\n"), "\n", file = githubSummary, append = TRUE)
  }
  invisible(row)
}

recordMatrixCandidate()
