#!/usr/bin/env Rscript

# Deterministic source-location regression checks; no network or installation.
arguments = commandArgs(trailingOnly = TRUE)
installer = if (length(arguments)) arguments[[1L]] else
  "tools/ci/install-matrix-source.R"
source(installer)
version = "1.7-6"
current = paste0("https://cran.r-project.org/src/contrib/Matrix_", version, ".tar.gz")
archiveUrl = paste0("https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_",
                    version, ".tar.gz")
destination = tempfile("Matrix-download-regression-")
calls = character()
success = function(url, destfile, ...) {
  calls <<- c(calls, url)
  writeBin(charToRaw("exact source fixture"), destfile)
  0L
}
output = capture.output(actual <- matrixSourceDownload(
  current, version, destination, success
))
stopifnot(identical(actual, current), identical(calls, current),
          any(grepl(paste0("Downloaded Matrix source archive: ", current),
                    output, fixed = TRUE)))
calls = character()
moved = function(url, destfile, ...) {
  if (identical(url, current)) {
    calls <<- c(calls, url)
    writeBin(charToRaw("partial download"), destfile)
    warning("cannot open URL: HTTP status was '404 Not Found'")
    stop("cannot open URL")
  }
  stopifnot(!file.exists(destfile))
  success(url, destfile, ...)
}
output = capture.output(actual <- matrixSourceDownload(
  current, version, destination, moved
))
stopifnot(identical(actual, archiveUrl), identical(calls, c(current, archiveUrl)),
          identical(rawToChar(readBin(destination, "raw", n = 100L)),
                    "exact source fixture"),
          any(grepl(paste0("Downloaded Matrix source archive: ", archiveUrl),
                    output, fixed = TRUE)))
for (failure in c("HTTP status was '403 Forbidden'", "HTTP status was '500 Internal Server Error'",
                  "SSL certificate problem", "connection timed out")) {
  calls = character()
  fail = function(url, ...) {
    calls <<- c(calls, url)
    stop(failure)
  }
  error = tryCatch(matrixSourceDownload(current, version, destination, fail),
                   error = identity)
  stopifnot(inherits(error, "error"), identical(calls, current))
}
for (url in c(archiveUrl, "https://example.org/Matrix_1.7-6.tar.gz")) {
  calls = character()
  missing = function(url, ...) {
    calls <<- c(calls, url)
    stop("HTTP status was '404 Not Found'")
  }
  error = tryCatch(matrixSourceDownload(url, version, destination, missing),
                   error = identity)
  stopifnot(inherits(error, "error"), identical(calls, url))
}
calls = character()
bothMissing = function(url, ...) {
  calls <<- c(calls, url)
  stop("HTTP status was '404 Not Found'")
}
error = tryCatch(matrixSourceDownload(current, version, destination, bothMissing),
                 error = identity)
stopifnot(inherits(error, "error"), identical(calls, c(current, archiveUrl)))
calls = character()
statusMissing = function(url, destfile, ...) {
  if (identical(url, current)) {
    calls <<- c(calls, url)
    warning("HTTP status was '404 Not Found'")
    return(1L)
  }
  success(url, destfile, ...)
}
actual = matrixSourceDownload(current, version, destination, statusMissing)
stopifnot(identical(actual, archiveUrl), identical(calls, c(current, archiveUrl)))

# A recovered download must still pass the installer's source metadata gate.
fixtureDirectory = tempfile("Matrix-source-metadata-")
dir.create(file.path(fixtureDirectory, "Matrix", "src"), recursive = TRUE)
writeLines(c("Package: Matrix", "Version: 1.7-5"),
           file.path(fixtureDirectory, "Matrix", "DESCRIPTION"))
writeLines("/* source fixture */", file.path(fixtureDirectory, "Matrix", "src", "a.c"))
fixtureArchive = file.path(fixtureDirectory, "Matrix_1.7-6.tar.gz")
oldDirectory = getwd()
setwd(fixtureDirectory)
utils::tar(fixtureArchive, files = "Matrix", compression = "gzip", tar = "internal")
setwd(oldDirectory)
installerEnvironment = new.env(parent = globalenv())
sys.source(installer, installerEnvironment)
installerEnvironment$matrixSourceDownload = function(url, version, archive) {
  matrixSourceDownload(url, version, archive, download = function(url, destfile, ...) {
    if (identical(url, current)) stop("HTTP status was '404 Not Found'")
    stopifnot(identical(url, archiveUrl), file.copy(fixtureArchive, destfile))
    0L
  })
}
targetLibrary = file.path(fixtureDirectory, "library")
error = tryCatch(installerEnvironment$matrixSourceInstall(list(
  url = current, version = version, library = targetLibrary, dryRun = FALSE
)), error = identity)
stopifnot(inherits(error, "error"),
          grepl("source metadata does not match", conditionMessage(error)),
          !dir.exists(targetLibrary))
unlink(fixtureDirectory, recursive = TRUE)
unlink(destination)
cat("Matrix source download regression: 11 scenarios passed\n")
