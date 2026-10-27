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

serializationBugfixSourceTreeAvailable = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  required = c(
    "DESCRIPTION",
    "R/modelSerialization.R",
    "tools/check_serialization_bugfix.R",
    "inst/migration/serialization-bugfix.dcf",
    "inst/migration/serialization-bugfix.patch"
  )
  all(file.exists(file.path(root, required)))
}

skipUnlessSerializationBugfixSourceTree = function() {
  testthat::skip_if_not(
    serializationBugfixSourceTreeAvailable(),
    "serialization BUGFIX review tests require the package source tree"
  )
}

loadSerializationBugfixTool = function() {
  environment = new.env(parent = globalenv())
  sys.source(serializationBugfixToolPath(), envir = environment)
  environment
}

test_that("current verification preserves original approval and verifies both candidates", {
  skipUnlessSerializationBugfixSourceTree()
  tool = loadSerializationBugfixTool()
  result = tool$serialization_bugfix_verify_current()
  expect_true(result$clean)
  expect_identical(result$mode, "current")
  expect_identical(result$record$`Review-State`, "approved")
  expect_identical(result$record$Reviewer, "David Zenz")
  expect_identical(result$record$`Reviewed-UTC`, "2026-09-18T12:26:01Z")
  expect_identical(result$historical_after_sha256,
    "c62a9223ab857b5ed871b856cf8feda0f3c4dd8386fe5d12e0888ffa1416ad3e")
  expect_identical(result$after_sha256,
    "dc2d3f3ba4fbaae6fc4b20ec7403fc19cf70f9db8c309c93566142e775dee874")
  expect_identical(result$current_review$`Review-State`, "technically-verified")
  expect_match(result$current_review$Reviewer, "automated technical review", fixed = TRUE)
  for (candidate in list(result$candidate, result$historical_candidate)) {
    expect_true(candidate$rejected)
    expect_true(candidate$unchanged)
    expect_true(candidate$predecessor_loaded)
  }
  expect_error(tool$serialization_bugfix_verify_delta(mode = "approved"),
    "approval|approved", ignore.case = TRUE)
})

test_that("current technical review rejects altered bindings and scope", {
  skipUnlessSerializationBugfixSourceTree()
  tool = loadSerializationBugfixTool()
  root = tool$serialization_bugfix_repository_root()
  record = read.dcf(file.path(root, "inst/migration/serialization-current-review.dcf"))
  path = tempfile("serialization-review-", tmpdir = root, fileext = ".dcf")
  on.exit(unlink(path), add = TRUE)
  mutations = list(`Historical-Record-SHA256` = paste(rep("0", 64), collapse = ""),
    `Current-Source-SHA256` = paste(rep("0", 64), collapse = ""),
    `Current-Patch-SHA256` = paste(rep("0", 64), collapse = ""),
    `Source-Path` = "../outside.R", `Current-Patch-Path` = "../outside.patch",
    `Added-Functions` = "unreviewed", `Changed-Functions` = "unreviewed",
    `Review-State` = "approved", `Reviewer` = "David Zenz")
  for (field in names(mutations)) {
    changed = record
    changed[1L, field] = mutations[[field]]
    write.dcf(changed, path, keep.white = colnames(changed))
    expect_error(tool$serialization_bugfix_verify_current(review_path = path),
      "hash binding|path|root|scope|delta|technical review", info = field)
  }
})

test_that("BUGFIX review records reject scope, digest and approval drift", {
  skipUnlessSerializationBugfixSourceTree()
  tool = loadSerializationBugfixTool()
  record = tool$serialization_bugfix_validate_record()
  expect_identical(record$`Source-Path`, "R/modelSerialization.R")
  expect_identical(record$`Patch-Path`, "inst/migration/serialization-bugfix.patch")
  expect_identical(
    record$`Allowed-Functions`,
    ".serialization_promote_reconstructed_fields;.serialization_validate_structure;.validate_reconstructed_logical_state;validate_projection"
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
    "Allowed-Functions: .serialization_promote_reconstructed_fields;.serialization_validate_structure;.validate_reconstructed_logical_state;validate_projection",
    "Review-State: proposed",
    "Reviewer: pending",
    "Reviewed-UTC: pending"
  ), path)
  expect_error(tool$serialization_bugfix_validate_record(path), "path|scope|commit|digest|root")
})
