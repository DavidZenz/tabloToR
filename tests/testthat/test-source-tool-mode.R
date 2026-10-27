sourceModeTool = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  path = file.path(root, "tools/ci/run-source-tool-tests.R")
  testthat::skip_if_not(file.exists(path), "source-only runner requires a source checkout")
  tool = new.env(parent = globalenv())
  sys.source(path, envir = tool)
  tool
}

test_that("public source checks cannot bypass private evidence or history", {
  tool = sourceModeTool()
  root = tempfile("source-mode-")
  lib = tempfile("source-mode-library-")
  dir.create(root)
  dir.create(lib)
  on.exit(unlink(c(root, lib), recursive = TRUE), add = TRUE)
  for (private in c(".planning", "docs/provenance", "docs/release")) {
    dir.create(file.path(root, private), recursive = TRUE)
    expect_error(tool$runSourceToolTests(c(root, lib, "--public-source")),
      "cannot bypass development evidence")
    unlink(file.path(root, private), recursive = TRUE)
  }
  git = Sys.which("git")
  testthat::skip_if_not(nzchar(git), "Git is unavailable")
  run = function(args) {
    result = suppressWarnings(system2(git, c("-C", shQuote(root), args), stdout = TRUE, stderr = TRUE))
    stopifnot(is.null(attr(result, "status")))
    invisible(result)
  }
  run(c("init", "--quiet"))
  run(c("config", "user.name", "Fixture"))
  run(c("config", "user.email", "fixture@example.invalid"))
  dir.create(file.path(root, ".planning"))
  writeLines("private fixture", file.path(root, ".planning/private.txt"))
  run(c("add", ".planning/private.txt"))
  run(c("commit", "--quiet", "-m", "fixture"))
  unlink(file.path(root, ".planning"), recursive = TRUE)
  expect_error(tool$runSourceToolTests(c(root, lib, "--public-source")),
    "history without private development paths")
})

test_that("source runner requires explicit modes and complete source groups", {
  tool = sourceModeTool()
  root = tempfile("source-mode-incomplete-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_error(tool$runSourceToolTests(c(root, root, "--unknown")), "Usage")
  expect_error(tool$runSourceToolTests(c(root, root)), "Incomplete source-tool checkout")
})
