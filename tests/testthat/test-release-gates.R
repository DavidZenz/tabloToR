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

expectReleaseGateFailure <- function(command, reason) {
  expect_identical(command$status, 1L)
  expect_true(any(command$output == paste0("reason_codes=", reason)))
  expect_false(any(grepl(
    "mivanic|fixture-reviewer|upstream-fixture",
    command$output,
    ignore.case = TRUE
  )))
}

writeReleaseGateFixture <- function(root, rightsStatus = "blocked",
                                    releaseStatus = rightsStatus,
                                    includeStatus = TRUE,
                                    duplicateStatus = FALSE,
                                    includeScope = FALSE,
                                    intentionalBlockers = if (
                                      identical(rightsStatus, "blocked")
                                    ) "RIGHTS_BLOCKED" else "NONE") {
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
    paste0("Intentional-Blockers: ", intentionalBlockers)
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
    expectReleaseGateFailure(
      runReleaseGate(c("--root", root, "--offline")),
      "RIGHTS_STATUS_CARDINALITY"
    )
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
  expectReleaseGateFailure(
    runReleaseGate(c("--root", root, "--offline")),
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
  expectReleaseGateFailure(
    runReleaseGate(c("--root", root, "--offline")),
    "RIGHTS_SCOPE_INCOMPLETE"
  )
})

writeCleanroomFixture <- function(root, reviewStatus = "approved") {
  writeReleaseGateFixture(root, rightsStatus = "clean-room-required")
  writeLines(c(
    "# Clean-room Fixture",
    "Cleanroom-Coverage: complete",
    paste0("Cleanroom-Review-Status: ", reviewStatus)
  ), file.path(root, "docs", "provenance", "CLEANROOM.md"))
}

test_that("offline readiness stays distinct from an intentional block", {
  root <- releaseGateProjectRoot()
  offline <- runReleaseGate(c("--root", root, "--offline"))
  expectReleaseGateFailure(offline, "RIGHTS_BLOCKED")

  malformed <- tempfile("release-gate-unrelated-error-")
  on.exit(unlink(malformed, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(malformed)
  rightsPath <- file.path(malformed, "docs", "provenance", "RIGHTS.md")
  write("Evidence-Hash: duplicate", rightsPath, append = TRUE)

  asserted <- runReleaseGate(c("--root", malformed, "--assert-blocked"))
  expectReleaseGateFailure(asserted, "RIGHTS_FIELD_CARDINALITY")
})

test_that("complete written grant evidence proves synthetic readiness", {
  root <- tempfile("release-gate-cleared-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(
    root,
    rightsStatus = "cleared",
    includeScope = TRUE
  )

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)

  command <- runReleaseGate(c("--root", root, "--offline"))
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "repository_state=eligible"))
  expect_true(any(command$output == "release_ready=true"))
  expect_true(any(command$output == "reason_codes=NONE"))
})

test_that("complete reviewed clean-room evidence proves synthetic readiness", {
  root <- tempfile("release-gate-cleanroom-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(root)

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)
  expect_identical(
    runReleaseGate(c("--root", root, "--offline"))$status,
    0L
  )

  incomplete <- tempfile("release-gate-cleanroom-review-")
  on.exit(unlink(incomplete, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(incomplete, reviewStatus = "pending")
  expectReleaseGateFailure(
    runReleaseGate(c("--root", incomplete, "--offline")),
    "CLEANROOM_REVIEW_INCOMPLETE"
  )
})

test_that("sensitive evidence classes fail without disclosing matches", {
  indicators <- c(
    "credential.txt", "private-correspondence.txt", "fixture.har",
    "giant-result.rds"
  )
  for (indicator in indicators) {
    root <- tempfile("release-gate-sensitive-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeReleaseGateFixture(root)
    sentinel <- paste0("do-not-disclose-", basename(indicator))
    writeLines(
      sentinel,
      file.path(root, "docs", "provenance", indicator)
    )

    command <- runReleaseGate(c("--root", root, "--offline"))
    expectReleaseGateFailure(command, "SENSITIVE_EVIDENCE_CLASS")
    expect_false(any(grepl(sentinel, command$output, fixed = TRUE)))
    expect_false(any(grepl(indicator, command$output, fixed = TRUE)))
  }
})

test_that("the built-in isolated self-test proves both result directions", {
  command <- runReleaseGate("--self-test")
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "self_test=pass"))
})
