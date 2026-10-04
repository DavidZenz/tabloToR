#!/usr/bin/env Rscript

matrixSourceInputs = function(arguments) {
  dryRun = length(arguments) > 0L && identical(arguments[[1L]], "--dry-run")
  if (dryRun) arguments = arguments[-1L]
  if (length(arguments) != 3L || any(!nzchar(arguments))) {
    stop(paste(
      "Usage: install-matrix-source.R [--dry-run]",
      "<CRAN-source-archive-URL> <Matrix-version> <empty-library>"
    ), call. = FALSE)
  }
  url = arguments[[1L]]
  version = arguments[[2L]]
  if (!grepl("^[0-9]+([.-][0-9]+)+$", version)) {
    stop("Matrix version must be an explicit numeric version", call. = FALSE)
  }
  match = regexec(paste0(
    "^https://cran[.]r-project[.]org/src/contrib/",
    "(Archive/Matrix/)?Matrix_([0-9]+([.-][0-9]+)+)[.]tar[.]gz$"
  ), url)
  fields = regmatches(url, match)[[1L]]
  if (!length(fields)) {
    stop("URL must name an exact HTTPS CRAN Matrix source archive", call. = FALSE)
  }
  if (!identical(fields[[3L]], version)) {
    stop("Matrix archive URL and requested version do not match", call. = FALSE)
  }
  library = path.expand(arguments[[3L]])
  if (!grepl("^(/|[A-Za-z]:[/\\\\])", library)) {
    library = file.path(getwd(), library)
  }
  matrixSourceCleanLibrary(library)
  library = normalizePath(library, winslash = "/", mustWork = FALSE)
  matrixSourceCleanLibrary(library)
  list(url = url, version = version, library = library, dryRun = dryRun)
}

matrixSourceCleanLibrary = function(library) {
  link = Sys.readlink(library)
  if (!is.na(link) && nzchar(link)) {
    stop("Target library must not be a symbolic link", call. = FALSE)
  }
  if (file.exists(library) && !dir.exists(library)) {
    stop("Target library is not a directory", call. = FALSE)
  }
  if (dir.exists(library) &&
      length(list.files(library, all.files = TRUE, no.. = TRUE))) {
    stop("Target library must be empty, including hidden files", call. = FALSE)
  }
}

matrixSourceArchive = function(archive, version, directory) {
  entries = utils::untar(archive, list = TRUE)
  if (!length(entries) || any(!grepl("^Matrix(/|$)", entries)) ||
      any(grepl("(^|/)\\.\\.(/|$)|\\\\", entries))) {
    stop("Archive must contain only relative Matrix source paths", call. = FALSE)
  }
  if (!"Matrix/DESCRIPTION" %in% entries ||
      !any(grepl("^Matrix/src/.*[.](c|cpp|f|f90)$", entries)) ||
      any(grepl("^Matrix/(Meta|libs)(/|$)", entries))) {
    stop("Archive must be a Matrix source package, never a binary", call. = FALSE)
  }
  utils::untar(archive, files = "Matrix/DESCRIPTION", exdir = directory)
  description = read.dcf(file.path(directory, "Matrix", "DESCRIPTION"))
  if (!all(c("Package", "Version") %in% colnames(description)) ||
      nrow(description) != 1L || description[1L, "Package"] != "Matrix" ||
      as.character(package_version(description[1L, "Version"])) !=
        as.character(package_version(version))) {
    stop("Downloaded source metadata does not match requested Matrix version",
         call. = FALSE)
  }
}

matrixSourceVerify = function(library, version) {
  namespace = loadNamespace("Matrix", lib.loc = library)
  loadedPath = normalizePath(getNamespaceInfo(namespace, "path"),
                             winslash = "/", mustWork = TRUE)
  expectedPath = normalizePath(file.path(library, "Matrix"),
                               winslash = "/", mustWork = TRUE)
  if (!identical(loadedPath, expectedPath)) {
    stop("Matrix did not load from the isolated target library", call. = FALSE)
  }
  installed = as.character(utils::packageVersion("Matrix", lib.loc = library))
  expected = as.character(package_version(version))
  if (!identical(installed, expected)) {
    stop(sprintf("Installed Matrix %s does not match requested %s",
                 installed, version), call. = FALSE)
  }
  cat("Verified Matrix version:", installed, "\n")
  cat("Verified Matrix library:", library, "\n")
  invisible(installed)
}

matrixSourceDownload = function(url, version, archive,
                                download = utils::download.file) {
  warnings = character()
  status = tryCatch(withCallingHandlers(
    download(url, archive, mode = "wb", quiet = FALSE),
    warning = function(condition) {
      warnings <<- c(warnings, conditionMessage(condition))
      invokeRestart("muffleWarning")
    }
  ), error = identity)
  if (!identical(status, 0L)) {
    detail = c(warnings, if (inherits(status, "error")) conditionMessage(status))
    current = paste0("https://cran.r-project.org/src/contrib/Matrix_",
                     version, ".tar.gz")
    missing = any(grepl("HTTP[^\n]*404|404[^\n]*Not Found", detail,
                       ignore.case = TRUE))
    if (!identical(url, current) || !missing) {
      stop(paste(c("Matrix source download failed", detail), collapse = ": "),
           call. = FALSE)
    }
    url = paste0("https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_",
                 version, ".tar.gz")
    cat("Current source returned HTTP 404; retrying exact version:", url, "\n")
    unlink(archive)
    status = download(url, archive, mode = "wb", quiet = FALSE)
    if (!identical(status, 0L)) stop("Matrix source download failed", call. = FALSE)
  }
  cat("Downloaded Matrix source archive:", url, "\n")
  invisible(url)
}

matrixSourceInstall = function(inputs) {
  cat("Matrix source archive:", inputs$url, "\n")
  cat("Requested Matrix version:", inputs$version, "\n")
  cat("Target library:", inputs$library, "\n")
  if (inputs$dryRun) {
    cat("Dry run: validated inputs; no download or installation\n")
    return(invisible(NULL))
  }
  if ("Matrix" %in% loadedNamespaces()) {
    stop("Matrix must not be loaded before the isolated source install", call. = FALSE)
  }
  scratch = tempfile("Matrix-source-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  archive = file.path(scratch, basename(inputs$url))
  matrixSourceDownload(inputs$url, inputs$version, archive)
  matrixSourceArchive(archive, inputs$version, scratch)
  # Check again after downloading before allowing R to write to the target.
  matrixSourceCleanLibrary(inputs$library)
  if (!dir.exists(inputs$library) &&
      !dir.create(inputs$library, recursive = TRUE)) {
    stop("Could not create target library", call. = FALSE)
  }
  library = normalizePath(inputs$library, winslash = "/", mustWork = TRUE)
  arguments = c("CMD", "INSTALL", "--preclean",
                paste0("--library=", shQuote(library)), shQuote(archive))
  cat("Source install with active R:", R.version.string, "\n")
  status = system2(file.path(R.home("bin"), "R"), arguments)
  if (!identical(status, 0L)) stop("Matrix source installation failed", call. = FALSE)
  matrixSourceVerify(library, inputs$version)
}

if (sys.nframe() == 0L) {
  tryCatch(
    matrixSourceInstall(matrixSourceInputs(commandArgs(trailingOnly = TRUE))),
    error = function(error) {
      message("Matrix source installer: ", conditionMessage(error))
      quit(status = 1L)
    }
  )
}
