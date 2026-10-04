#!/usr/bin/env Rscript

requiredEnvironment = function(name) {
  value = Sys.getenv(name, unset = "")
  if (!nzchar(value)) stop(paste(name, "must be explicitly set"), call. = FALSE)
  value
}

runInstalledCoreTests = function() {
  openmp = requiredEnvironment("GEModelR_EXPECT_OPENMP")
  if (!openmp %in% c("required", "forbidden")) {
    stop("GEModelR_EXPECT_OPENMP must be required or forbidden", call. = FALSE)
  }
  matrix = requiredEnvironment("GEModelR_EXPECT_MATRIX_VERSION")
  if (!identical(matrix, "installed") &&
      !grepl("^[0-9]+([.-][0-9]+)+$", matrix)) {
    stop("GEModelR_EXPECT_MATRIX_VERSION must be installed or an exact numeric version",
         call. = FALSE)
  }
  lib = normalizePath(requiredEnvironment("GEModelR_TEST_LIBRARY"),
                      winslash = "/", mustWork = TRUE)
  packagePath = normalizePath(file.path(lib, "GEModelR"),
                              winslash = "/", mustWork = TRUE)
  .libPaths(c(lib, .libPaths()))
  library(GEModelR, lib.loc = lib)
  library(Matrix)
  loadedPath = normalizePath(getNamespaceInfo(asNamespace("GEModelR"), "path"),
                             winslash = "/", mustWork = TRUE)
  stopifnot(identical(loadedPath, packagePath))
  stopifnot(identical(normalizePath(find.package("GEModelR"), winslash = "/"),
                      packagePath))

  matrixVersion = packageVersion("Matrix")
  if (!identical(matrix, "installed") &&
      matrixVersion != package_version(matrix)) {
    stop(sprintf("Requested Matrix %s but loaded %s", matrix, matrixVersion),
         call. = FALSE)
  }
  imports = packageDescription("GEModelR", lib.loc = lib, fields = "Imports")
  declarations = trimws(strsplit(imports, ",", fixed = TRUE)[[1L]])
  declaration = declarations[grepl("^Matrix($|[[:space:](])", declarations)]
  if (length(declaration) != 1L) {
    stop("Expected one installed GEModelR Matrix Imports declaration", call. = FALSE)
  }
  if (!identical(declaration, "Matrix")) {
    fields = regmatches(declaration, regexec(
      "^Matrix[[:space:]]*\\([[:space:]]*>=[[:space:]]*([0-9]+([.-][0-9]+)+)[[:space:]]*\\)$",
      declaration
    ))[[1L]]
    if (!length(fields)) stop("Invalid Matrix minimum declaration", call. = FALSE)
    if (matrixVersion < package_version(fields[[2L]])) {
      stop(paste("Loaded Matrix is below the declared minimum", fields[[2L]]),
           call. = FALSE)
    }
  }

  capabilities = GEModelR:::.GEModelR_schur_cpp_capabilities()
  if (identical(openmp, "forbidden")) {
    stopifnot(identical(capabilities$openmp, FALSE))
    stopifnot(identical(capabilities$max_threads, 1L))
  } else {
    stopifnot(identical(capabilities$openmp, TRUE))
    stopifnot(capabilities$max_threads >= 2L)
  }
  cat(sprintf("Installed GEModelR %s: %s\nMatrix %s (expectation: %s)\nOpenMP expectation: %s\n",
              packageVersion("GEModelR", lib.loc = lib), packagePath,
              matrixVersion, matrix, openmp))
  print(capabilities)

  groups = c("native-portability", "suite-sparse-unsupported",
             "sparse-schur-openmp", "public-cpp-backend",
             "public-solver-contract", "matrix-compatibility")
  files = paste0("test-", groups, ".R")
  testPath = system.file("tests", "testthat", package = "GEModelR", lib.loc = lib)
  missing = files[!file.exists(file.path(testPath, files))]
  if (!nzchar(testPath) || length(missing)) {
    stop(paste("Missing installed core test groups:", paste(missing, collapse = ", ")),
         call. = FALSE)
  }

  # Execute from an unrelated directory and load only the installed namespace.
  originalWorkdir = getwd()
  workdir = tempfile("GEModelR-installed-core-")
  dir.create(workdir)
  on.exit({
    setwd(originalWorkdir)
    unlink(workdir, recursive = TRUE)
  }, add = TRUE)
  setwd(workdir)
  results = testthat::test_package(
    "GEModelR", filter = paste0("^(", paste(groups, collapse = "|"), ")$"),
    reporter = "summary", stop_on_failure = TRUE
  )
  report = as.data.frame(results)
  missing = setdiff(files, report$file)
  if (!nrow(report) || length(missing)) {
    stop(paste("Installed core test groups did not execute:",
               paste(missing, collapse = ", ")), call. = FALSE)
  }
  allowedSkip = identical(openmp, "forbidden") &
    report$file == "test-sparse-schur-openmp.R" &
    report$test == "bounded OpenMP Schur batches match serial execution"
  if (any(report$skipped & !allowedSkip)) {
    stop("Unexpected skip in installed core contracts", call. = FALSE)
  }
  if (any(report$failed > 0L | report$error)) {
    stop("Installed core contracts failed", call. = FALSE)
  }
  for (file in files) {
    if (!any(report$passed[report$file == file] > 0L)) {
      stop(paste("Installed core group has no passing assertions:", file),
           call. = FALSE)
    }
  }
  cat(sprintf("PASS: all %d installed core groups; %d tests, %d assertions, %d explicit serial skips\n",
              length(groups), nrow(report), sum(report$passed), sum(report$skipped)))
  invisible(results)
}

runInstalledCoreTests()
