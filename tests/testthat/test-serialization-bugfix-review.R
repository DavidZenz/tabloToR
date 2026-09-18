serializationBugfixToolPath = function() {
  candidates = c(
    file.path("tools", "check_serialization_bugfix.R"),
    testthat::test_path("..", "..", "tools", "check_serialization_bugfix.R")
  )
  hits = candidates[file.exists(candidates)]
  if (!length(hits)) {
    stop("serialization BUGFIX review tool is unavailable", call. = FALSE)
  }
  normalizePath(hits[[1L]], mustWork = TRUE)
}

loadSerializationBugfixTool = function() {
  environment = new.env(parent = globalenv())
  sys.source(serializationBugfixToolPath(), envir = environment)
  environment
}

test_that("proposal gate proves the exact candidate and blocks approval", {
  tool = loadSerializationBugfixTool()
  review_record = tool$serialization_bugfix_validate_record()
  proposal_record_path = NULL
  if (identical(review_record[["Review-State"]], "approved")) {
    proposal_record_path = tempfile(tmpdir = tool$serialization_bugfix_repository_root(), fileext = ".dcf")
    on.exit(unlink(proposal_record_path), add = TRUE)
    record_lines = readLines(
      file.path(tool$serialization_bugfix_repository_root(), "inst", "migration", "serialization-bugfix.dcf"),
      encoding = "bytes"
    )
    record_lines[startsWith(record_lines, "Review-State:")] =
      "Review-State: proposed"
    record_lines[startsWith(record_lines, "Reviewer:")] =
      "Reviewer: pending"
    record_lines[startsWith(record_lines, "Reviewed-UTC:")] =
      "Reviewed-UTC: pending"
    writeLines(record_lines, proposal_record_path, useBytes = TRUE)
  }
  result = tool$serialization_bugfix_verify_delta(
    mode = "proposal", record_path = proposal_record_path
  )

  expect_true(result$clean)
  expect_identical(result$record$`Schema`, "gemodelr-serialization-bugfix-v1")
  expect_identical(result$record$`Finding`, "CR-04")
  expect_identical(result$record$`Change-Kind`, "BUGFIX")
  expect_identical(result$record$`Review-State`, "proposed")
  expect_identical(result$record$`Reviewer`, "pending")
  expect_identical(result$record$`Reviewed-UTC`, "pending")
  expect_match(result$record$`Before-Commit`, "^[0-9a-f]{40}$")
  expect_match(result$record$`Before-SHA256`, "^[0-9a-f]{64}$")
  expect_match(result$record$`After-SHA256`, "^[0-9a-f]{64}$")
  expect_match(result$record$`Patch-SHA256`, "^[0-9a-f]{64}$")
  expect_identical(result$candidate$rejected, TRUE)
  expect_identical(result$candidate$unchanged, TRUE)
  expect_identical(result$candidate$predecessor_loaded, TRUE)
  if (identical(review_record[["Review-State"]], "approved")) {
    expect_identical(review_record[["Reviewer"]], "David Zenz")
    expect_identical(review_record[["Reviewed-UTC"]], "2026-09-18T09:12:51Z")
    expect_identical(review_record[["Before-SHA256"]], "78042d7032a3df97761e252f9d4eca4e3c08ea3bf2c9f905592841d2652d8aee")
    expect_identical(review_record[["After-SHA256"]], "957f15724e76cbd9c43132b224f0e8e4ae9a1e1f68206a8c7af2fadc2d55da1a")
    expect_identical(review_record[["Patch-SHA256"]], "8f1d219330e374ae30746c8732e572f82ae0809bbea57b9d5d259bd30afb305a")
  }
  expect_error(
    tool$serialization_bugfix_verify_delta(mode = "approved"),
    "proposed|approval|approved",
    ignore.case = TRUE
  )
})

test_that("BUGFIX review records reject scope, digest and approval drift", {
  tool = loadSerializationBugfixTool()
  record = tool$serialization_bugfix_validate_record()
  expect_identical(record$`Source-Path`, "R/modelSerialization.R")
  expect_identical(record$`Patch-Path`, "inst/migration/serialization-bugfix.patch")
  expect_identical(
    record$`Allowed-Functions`,
    ".serialization_validate_structure;validate_projection"
  )

  path = tempfile(fileext = ".dcf")
  on.exit(unlink(path), add = TRUE)
  writeLines(c(
    "Schema: gemodelr-serialization-bugfix-v1",
    "Finding: CR-04",
    "Change-Kind: BUGFIX",
    "Source-Path: ../R/modelSerialization.R",
    "Before-Commit: 0000000000000000000000000000000000000000",
    "Before-SHA256: 0000000000000000000000000000000000000000000000000000000000000000",
    "After-SHA256: 0000000000000000000000000000000000000000000000000000000000000000",
    "Patch-Path: inst/migration/serialization-bugfix.patch",
    "Patch-SHA256: 0000000000000000000000000000000000000000000000000000000000000000",
    "Allowed-Functions: .serialization_validate_structure;validate_projection",
    "Review-State: proposed",
    "Reviewer: pending",
    "Reviewed-UTC: pending"
  ), path)
  expect_error(tool$serialization_bugfix_validate_record(path), "path|scope|commit|digest|root")
})
