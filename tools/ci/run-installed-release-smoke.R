#!/usr/bin/env Rscript

releaseSmokeStop = function(code) {
  stop(structure(list(message = code, call = NULL),
    class = c("GEModelRReleaseSmokeError", "error", "condition")))
}

releaseSmokeEnvironment = function(name) {
  value = Sys.getenv(name, unset = "")
  if (!nzchar(value)) releaseSmokeStop(paste0("MISSING_", name))
  value
}

runInstalledReleaseSmoke = function() {
  libraryPath = releaseSmokeEnvironment("GEModelR_TEST_LIBRARY")
  expectedVersion = releaseSmokeEnvironment("GEModelR_EXPECTED_VERSION")
  channel = releaseSmokeEnvironment("GEModelR_DISTRIBUTION_CHANNEL")
  sourceCommit = releaseSmokeEnvironment("GEModelR_EXPECTED_SOURCE_COMMIT")
  if (!channel %in% c("local", "github", "runiverse")) releaseSmokeStop("INVALID_DISTRIBUTION_CHANNEL")
  if (!grepl("^[0-9a-f]{40}([0-9a-f]{24})?$", sourceCommit)) releaseSmokeStop("INVALID_SOURCE_COMMIT")
  if (!grepl("^[0-9]+([.-][0-9]+)+$", expectedVersion)) releaseSmokeStop("INVALID_EXPECTED_VERSION")
  if (!dir.exists(libraryPath)) releaseSmokeStop("MISSING_SELECTED_LIBRARY")
  libraryPath = normalizePath(libraryPath, winslash = "/", mustWork = TRUE)
  packagePath = file.path(libraryPath, "GEModelR")
  if (!dir.exists(packagePath)) releaseSmokeStop("MISSING_SELECTED_PACKAGE")
  packagePath = normalizePath(packagePath, winslash = "/", mustWork = TRUE)
  if (!identical(dirname(packagePath), libraryPath)) releaseSmokeStop("PACKAGE_LIBRARY_MISMATCH")
  metadata = tryCatch(read.dcf(file.path(packagePath, "DESCRIPTION")),
    error = function(error) releaseSmokeStop("INVALID_PACKAGE_METADATA"))
  if (nrow(metadata) != 1L ||
      !all(c("Package", "Version", "Imports") %in% colnames(metadata))) {
    releaseSmokeStop("INVALID_PACKAGE_METADATA")
  }
  if (!identical(unname(metadata[1L, "Package"]), "GEModelR") ||
      !identical(unname(metadata[1L, "Version"]), expectedVersion)) releaseSmokeStop("PACKAGE_VERSION_MISMATCH")
  .libPaths(c(libraryPath, .libPaths()))
  matrixPath = find.package("Matrix", quiet = TRUE)
  if (!nzchar(matrixPath)) releaseSmokeStop("MISSING_MATRIX")
  declarations = trimws(strsplit(metadata[1L, "Imports"], ",", fixed = TRUE)[[1L]])
  declaration = declarations[grepl("^Matrix($|[[:space:](])", declarations)]
  if (length(declaration) != 1L) releaseSmokeStop("INVALID_MATRIX_DECLARATION")
  declaredFloor = package_version("1.6-5")
  if (!identical(declaration, "Matrix")) {
    fields = regmatches(declaration, regexec(
      "^Matrix[[:space:]]*\\([[:space:]]*>=[[:space:]]*([0-9]+([.-][0-9]+)+)[[:space:]]*\\)$",
      declaration
    ))[[1L]]
    if (!length(fields)) releaseSmokeStop("INVALID_MATRIX_DECLARATION")
    declaredFloor = package_version(fields[[2L]])
  }
  matrixVersion = packageVersion("Matrix")
  if (matrixVersion < package_version("1.6-5") ||
      matrixVersion < declaredFloor) releaseSmokeStop("MATRIX_BELOW_FLOOR")
  if ("GEModelR" %in% loadedNamespaces()) releaseSmokeStop("PACKAGE_ALREADY_LOADED")
  if ("Matrix" %in% loadedNamespaces()) releaseSmokeStop("MATRIX_ALREADY_LOADED")
  if (identical(channel, "runiverse") &&
      (!"RemoteSha" %in% colnames(metadata) ||
       !identical(unname(metadata[1L, "RemoteSha"]), sourceCommit))) releaseSmokeStop("RUNIVERSE_SOURCE_MISMATCH")
  tryCatch(library(GEModelR, lib.loc = libraryPath),
    error = function(error) releaseSmokeStop("PACKAGE_LOAD_FAILED"))
  loadedPath = normalizePath(getNamespaceInfo(asNamespace("GEModelR"), "path"),
    winslash = "/", mustWork = TRUE)
  if (!identical(loadedPath, packagePath)) releaseSmokeStop("LOADED_NAMESPACE_MISMATCH")
  loadedMatrixPath = normalizePath(getNamespaceInfo(asNamespace("Matrix"), "path"),
    winslash = "/", mustWork = TRUE)
  if (!identical(loadedMatrixPath, normalizePath(matrixPath, winslash = "/", mustWork = TRUE))) {
    releaseSmokeStop("LOADED_MATRIX_MISMATCH")
  }
  originalDirectory = getwd()
  workdir = tempfile("GEModelR-release-smoke-")
  dir.create(workdir)
  on.exit({
    setwd(originalDirectory)
    unlink(workdir, recursive = TRUE)
  }, add = TRUE)
  setwd(workdir)
  tabloPath = file.path(workdir, "three-region.tab")
  writeLines(c(
    "set reg (north,south,east);",
    "coefficient (all,r,reg) weight(r);",
    "read weight from file basedata header \"WEIGHT\";",
    "coefficient (all,r,reg) stock(r);",
    "read stock from file basedata header \"STOCK\";",
    "coefficient (all,r,reg) reported(r);",
    "formula (all,r,reg) reported(r) = stock(r);",
    "variable (all,r,reg)(change) q(r);",
    "variable (all,r,reg) tax(r);",
    "equation market (all,r,reg) q(r) = weight(r) * tax(r);",
    "update (all,r,reg)(change) stock(r) = q(r);"
  ), tabloPath, useBytes = TRUE)
  regions = c("north", "south", "east")
  inputData = list(basedata = list(
    weight = array(c(1, 1.5, 2), dim = 3L, dimnames = list(reg = regions)),
    stock = array(c(100, 200, 300), dim = 3L, dimnames = list(reg = regions))
  ))
  model = GEModelR::GEModel$new()
  model$loadTablo(tabloPath)
  model$setClosure("tax")
  model$loadData(inputData, engine = "sparse")
  model$setShocks(setNames(4, 'tax["south"]'))
  model$solveModel(iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", backend = "Matrix", reduction = "off")
  solution = unname(model$solution)
  if (!is.numeric(solution) || length(solution) != 3L || any(!is.finite(solution)) ||
      max(abs(solution - c(0, 6, 0))) > 1e-12) releaseSmokeStop("NUMERICAL_SMOKE_MISMATCH")
  cat("PASS installed-release-smoke\n")
  cat("package=GEModelR\nversion=", expectedVersion, "\nchannel=", channel,
    "\nsource_commit=", sourceCommit, "\n", sep = "")
  cat("source_identity_basis=", if (channel == "runiverse") "installed_RemoteSha" else
    "caller_attested_source", "\n", sep = "")
  cat("library_ownership=verified\nmatrix_version=", as.character(packageVersion("Matrix")), "\n", sep = "")
  invisible(solution)
}

tryCatch(runInstalledReleaseSmoke(), error = function(error) {
  code = if (inherits(error, "GEModelRReleaseSmokeError")) conditionMessage(error) else
    "SMOKE_EXECUTION_FAILED"
  cat("FAIL ", code, "\n", sep = "", file = stderr())
  quit(save = "no", status = 1L, runLast = FALSE)
})
