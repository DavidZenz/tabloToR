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
  result = tool$serialization_bugfix_verify_delta(mode = "proposal")

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
  expect_error(tool$serialization_bugfix_validate_record(path), "path|scope|commit|digest")
})
