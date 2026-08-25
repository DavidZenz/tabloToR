releaseGateProjectRoot <- function() {
  candidates <- c(".", "../..", "../../..")
  hit <- candidates[file.exists(file.path(
    candidates, "tools", "check_release_gates.R"
  ))]
  if (length(hit)) return(normalizePath(hit[[1L]], mustWork = TRUE))
  normalizePath(".", mustWork = TRUE)
}

releaseGateScript <- file.path(
  releaseGateProjectRoot(), "tools", "check_release_gates.R"
)
releaseGateEnvironment <- new.env(parent = globalenv())
if (file.exists(releaseGateScript)) {
  sys.source(releaseGateScript, envir = releaseGateEnvironment)
}

evaluateReleaseGate <- function(root) {
  if (!exists("release_gate_evaluate", envir = releaseGateEnvironment,
              inherits = FALSE)) {
    stop("release gate checker is not implemented", call. = FALSE)
  }
  releaseGateEnvironment$release_gate_evaluate(root)
}

runReleaseGate <- function(args) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    shQuote(c("--vanilla", releaseGateScript, args)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  list(
    status = if (is.null(status)) 0L else as.integer(status),
    output = output
  )
}

writeReleaseGateFixture <- function(root, rightsStatus = "blocked",
                                    releaseStatus = rightsStatus,
                                    includeStatus = TRUE,
                                    duplicateStatus = FALSE,
                                    includeScope = FALSE) {
  dir.create(file.path(root, "docs", "provenance"), recursive = TRUE)
  dir.create(file.path(root, "docs", "release"), recursive = TRUE)
  statusLines <- if (includeStatus) {
    rep(paste0("Rights-Status: ", rightsStatus),
        if (duplicateStatus) 2L else 1L)
  } else {
    character()
  }
  rightsLines <- c(
    "# Rights Fixture",
    statusLines,
    "Upstream-Repository: https://github.com/mivanic/tabloToR",
    "Upstream-Commit: upstream-fixture-commit",
    "Request-Status: resolved",
    "Request-URL: https://example.invalid/public-request",
    "Evidence-Hash: 0123456789abcdef0123456789abcdef",
    "Reviewer: fixture-reviewer",
    "Review-Date-UTC: 2026-08-25"
  )
  if (includeScope) {
    rightsLines <- c(
      rightsLines,
      "Covered-Upstream-Commit: upstream-fixture-commit",
      "Covered-Components: inherited-source"
    )
  }
  writeLines(rightsLines, file.path(root, "docs", "provenance", "RIGHTS.md"))
  writeLines(c(
    "# Release Gate Fixture",
    paste0("Rights-Gate-Status: ", releaseStatus),
    "Intentional-Blockers: RIGHTS_BLOCKED"
  ), file.path(root, "docs", "release", "RELEASE-GATES.md"))
}

test_that("the checked-in repository is positively recognized as blocked", {
  root <- releaseGateProjectRoot()
  result <- evaluateReleaseGate(root)

  expect_identical(result$repository_state, "blocked")
  expect_false(result$release_ready)
  expect_identical(result$reason_codes, "RIGHTS_BLOCKED")
  expect_identical(unname(result$parse_status), c("pass", "pass"))

  command <- runReleaseGate(c("--root", root, "--assert-blocked"))
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "repository_state=blocked"))
  expect_true(any(command$output == "release_ready=false"))
  expect_true(any(command$output == "reason_codes=RIGHTS_BLOCKED"))
})

test_that("missing or duplicate rights status has an exact parser reason", {
  for (duplicate in c(FALSE, TRUE)) {
    root <- tempfile("release-gate-status-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeReleaseGateFixture(
      root,
      includeStatus = duplicate,
      duplicateStatus = duplicate
    )

    result <- evaluateReleaseGate(root)
    expect_identical(result$repository_state, "invalid")
    expect_false(result$release_ready)
    expect_identical(result$reason_codes, "RIGHTS_STATUS_CARDINALITY")
  }
})

test_that("rights and release policy status must agree", {
  root <- tempfile("release-gate-mismatch-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(root, releaseStatus = "cleared")

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "RIGHTS_RELEASE_STATUS_MISMATCH"
  )
})

test_that("written clearance must cover the inherited commit and components", {
  root <- tempfile("release-gate-scope-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(root, rightsStatus = "cleared")

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(result$reason_codes, "RIGHTS_SCOPE_INCOMPLETE")
})
