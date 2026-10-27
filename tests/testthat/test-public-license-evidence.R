loadPublicLicenseTool = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  path = file.path(root, "tools", "ci", "check-license-decision.R")
  testthat::skip_if_not(file.exists(path), "public CI tools require source checkout")
  tool = new.env(parent = globalenv())
  sys.source(path, envir = tool)
  list(root = root, tool = tool)
}

publicLicenseFixture = function(source, private = FALSE) {
  root = tempfile("public-license-")
  dir.create(root)
  paths = c("DESCRIPTION", "GOVERNANCE.md", "inst/CITATION",
             "inst/compatibility/release-license.dcf",
             "inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md")
  if (private) paths = c(paths, "docs/release/LICENSE-DECISION.md")
  for (path in paths) {
    dir.create(dirname(file.path(root, path)), recursive = TRUE, showWarnings = FALSE)
    input = file.path(source, path)
    # Public checkouts deliberately omit the private decision. Recreate that
    # branch only inside this synthetic fixture from the same public markers.
    if (private && identical(path, "docs/release/LICENSE-DECISION.md") && !file.exists(input)) {
      input = file.path(source, "inst/compatibility/release-license.dcf")
    }
    stopifnot(file.copy(input, file.path(root, path)))
  }
  root
}

test_that("license CI validates public evidence without private release records", {
  loaded = loadPublicLicenseTool()
  for (private in c(FALSE, TRUE)) {
    root = publicLicenseFixture(loaded$root, private)
    expect_true(loaded$tool$runLicenseDecisionCheck(root, inspectInstalled = FALSE))
    unlink(root, recursive = TRUE)
  }
  public = publicLicenseFixture(loaded$root)
  privateFixture = publicLicenseFixture(public, private = TRUE)
  on.exit(unlink(c(public, privateFixture), recursive = TRUE), add = TRUE)
  expect_true(loaded$tool$runLicenseDecisionCheck(privateFixture, inspectInstalled = FALSE))
})

test_that("license CI rejects stale public summaries and missing or changed audits", {
  loaded = loadPublicLicenseTool()
  for (mutation in c("mismatch", "missing", "changed", "blocked", "dependency")) {
    root = publicLicenseFixture(loaded$root, private = TRUE)
    public = file.path(root, "inst/compatibility/release-license.dcf")
    audit = file.path(root, "inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md")
    if (mutation == "mismatch") {
      writeLines(sub("Reviewer:.*", "Reviewer: other", readLines(public)), public)
    } else if (mutation == "missing") {
      unlink(audit)
    } else if (mutation == "changed") {
      cat("unreviewed change", file = audit, append = TRUE)
    } else if (mutation == "blocked") {
      decision = file.path(root, "docs/release/LICENSE-DECISION.md")
      writeLines(sub("Outstanding-Blockers: NONE", "Outstanding-Blockers: UNREVIEWED", readLines(decision)), decision)
    } else {
      path = file.path(root, "DESCRIPTION")
      writeLines(sub("    SparseM,", "    SparseM, unreviewedDependency,", readLines(path), fixed = TRUE), path)
    }
    expect_error(loaded$tool$runLicenseDecisionCheck(root, inspectInstalled = FALSE), info = mutation)
    unlink(root, recursive = TRUE)
  }
})

test_that("license evidence cannot escape through paths or symbolic links", {
  loaded = loadPublicLicenseTool()
  root = publicLicenseFixture(loaded$root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_error(loaded$tool$licenseEvidencePath(root, "../outside"), "Invalid")
  path = file.path(root, "inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md")
  outside = tempfile("outside-audit-")
  on.exit(unlink(outside), add = TRUE)
  stopifnot(file.copy(path, outside))
  unlink(path)
  testthat::skip_if_not(file.symlink(outside, path), "symlinks unavailable")
  expect_error(loaded$tool$runLicenseDecisionCheck(root, inspectInstalled = FALSE), "Linked")
})

test_that("dependency compatibility never follows from FOSS metadata alone", {
  tool = loadPublicLicenseTool()$tool
  expect_true(tool$licenseDependencyCompatible("Rcpp", "GPL (>= 2)"))
  expect_true(tool$licenseDependencyCompatible("Matrix", "GPL (>= 2) | file LICENCE"))
  expect_false(tool$licenseDependencyCompatible("Rcpp", "GPL-2"))
  expect_false(tool$licenseDependencyCompatible("Rcpp", "file LICENSE"))
  expect_false(tool$licenseDependencyCompatible("unknown", "GPL (>= 2) | file LICENCE"))
})
