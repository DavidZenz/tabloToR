#!/usr/bin/env Rscript

# Source-only administrative assertions run in a fresh process against one
# installed namespace. Never load_all() or reload native code between groups.
runSourceToolTests = function() {
  args = commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) {
    stop("Usage: run-source-tool-tests.R SOURCE_ROOT INSTALLED_LIBRARY",
         call. = FALSE)
  }
  root = normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
  lib = normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
  groups = c("baseline-artifacts", "gtap12a-reference-preflight")
  files = paste0("test-", groups, ".R")
  required = c("DESCRIPTION", "R/GEModel.R", "src/RcppExports.cpp",
    "inst/tools/refresh_phase02_baselines.R",
    "inst/tools/accept_phase02_baselines.R",
    "benchmarks/preflight_gtap12a_reference.R",
    "tests/testthat/helper-baseline-artifacts.R",
    "tests/testthat/helper-gtap12a-reference-preflight.R",
    file.path("tests", "testthat", files))
  missing = required[!file.exists(file.path(root, required))]
  if (length(missing)) {
    stop(paste("Incomplete source-tool checkout:", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  if ("GEModelR" %in% loadedNamespaces()) {
    stop("Source-tool checks require a fresh R process", call. = FALSE)
  }
  packagePath = normalizePath(file.path(lib, "GEModelR"),
                              winslash = "/", mustWork = TRUE)
  .libPaths(c(lib, .libPaths()))
  library(GEModelR, lib.loc = lib)
  library(testthat)
  loadedPath = normalizePath(getNamespaceInfo(asNamespace("GEModelR"), "path"),
                             winslash = "/", mustWork = TRUE)
  stopifnot(identical(loadedPath, packagePath))
  sourceVersion = read.dcf(file.path(root, "DESCRIPTION"))[1L, "Version"]
  stopifnot(packageVersion("GEModelR", lib.loc = lib) ==
              package_version(sourceVersion))
  cat(sprintf("Source-tool tests: %s\nInstalled namespace: %s\nMatrix: %s\n",
              root, loadedPath, packageVersion("Matrix")))
  results = testthat::test_dir(
    file.path(root, "tests", "testthat"),
    filter = paste0("^(", paste(groups, collapse = "|"), ")$"),
    reporter = "summary", env = new.env(parent = asNamespace("GEModelR")),
    package = "GEModelR", load_package = "none", stop_on_failure = TRUE
  )
  report = as.data.frame(results)
  if (!nrow(report) || length(setdiff(files, report$file)) ||
      any(report$failed > 0L | report$error | report$skipped)) {
    stop("Source-tool assertions failed, skipped, or did not execute", call. = FALSE)
  }
  for (file in files) {
    if (!any(report$passed[report$file == file] > 0L)) {
      stop(paste("Source-tool group has no passing assertions:", file),
           call. = FALSE)
    }
  }
  stopifnot(identical(normalizePath(
    getNamespaceInfo(asNamespace("GEModelR"), "path"), winslash = "/"
  ), loadedPath))
  cat(sprintf("PASS source-tool-tests: %d groups, %d tests, %d assertions, zero skips\n",
              length(groups), nrow(report), sum(report$passed)))
  invisible(results)
}

runSourceToolTests()
