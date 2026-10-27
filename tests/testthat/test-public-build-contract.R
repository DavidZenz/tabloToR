publicBuildSource = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  testthat::skip_if_not(file.exists(file.path(root, "tools", "ci", "check-public-build-contract.R")),
                         "public build tooling requires source checkout")
  tool = new.env(parent = globalenv())
  sys.source(file.path(root, "tools", "ci", "check-public-build-contract.R"), tool)
  list(root = root, tool = tool)
}

publicBuildFixture = function(source) {
  root = tempfile("public-build-")
  dir.create(root)
  paths = c("DESCRIPTION", "README.md", "tools/ci/verify-matrix-floor-evidence.R",
             "tools/ci/check-license-decision.R", "inst/compatibility/matrix-support.dcf",
             "inst/compatibility/matrix-supported.csv")
  for (path in paths) {
    dir.create(dirname(file.path(root, path)), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(source, path), file.path(root, path)))
  }
  root
}

test_that("public Matrix checks execute without private planning evidence", {
  loaded = publicBuildSource()
  root = publicBuildFixture(loaded$root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_false(dir.exists(file.path(root, ".planning")))
  expect_true(loaded$tool$checkPublicBuildContract(root))
})

test_that("public Matrix checks retain coverage and metadata boundaries", {
  loaded = publicBuildSource()
  for (mutation in c("digest", "missing_tuple", "readme", "minimum")) {
    root = publicBuildFixture(loaded$root)
    csv = file.path(root, "inst/compatibility/matrix-supported.csv")
    if (mutation == "digest") {
      cat("changed", file = csv, append = TRUE)
    } else if (mutation == "missing_tuple") {
      lines = readLines(csv)
      writeLines(lines[-length(lines)], csv)
      dcf = file.path(root, "inst/compatibility/matrix-support.dcf")
      writeLines(sub("^Evidence-MD5:.*", paste0("Evidence-MD5: ", unname(tools::md5sum(csv))), readLines(dcf)), dcf)
    } else if (mutation == "readme") {
      file = file.path(root, "README.md")
      writeLines(gsub("Matrix support: 1.6-5", "Matrix support: 1.5-0", readLines(file), fixed = TRUE), file)
    } else {
      file = file.path(root, "DESCRIPTION")
      writeLines(gsub("Matrix (>= 1.6-5)", "Matrix (>= 1.5-0)", readLines(file), fixed = TRUE), file)
    }
    expect_error(loaded$tool$checkPublicBuildContract(root), info = mutation)
    unlink(root, recursive = TRUE)
  }
})
