#!/usr/bin/env Rscript

# Resolve once per hosted run, then pass the same exact source to every job.
resolveMatrixCurrent = function() {
  connection = gzcon(url("https://cran.r-project.org/src/contrib/PACKAGES.gz"))
  on.exit(close(connection))
  packages = read.dcf(connection)
  matrix = packages[packages[, "Package"] == "Matrix", , drop = FALSE]
  # The index can also list a devel Recommended/ copy. The current endpoint
  # is the root src/contrib source, whose Path is absent, not that copy.
  if ("Path" %in% colnames(matrix)) {
    path = matrix[, "Path"]
    matrix = matrix[is.na(path) | !nzchar(path), , drop = FALSE]
  }
  if (nrow(matrix) != 1L || !grepl("^[0-9]+[.][0-9]+[-.][0-9]+$", matrix[1L, "Version"])) {
    stop("CRAN did not return one exact Matrix source version", call. = FALSE)
  }
  version = matrix[1L, "Version"]
  source = paste0("https://cran.r-project.org/src/contrib/Matrix_", version, ".tar.gz")
  record = c(paste0("version=", version), paste0("source=", source))
  output = Sys.getenv("GITHUB_OUTPUT")
  if (nzchar(output)) cat(paste(record, collapse = "\n"), "\n", sep = "",
                          file = output, append = TRUE)
  writeLines(c(record, paste0("resolved_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
               paste0("requires=", matrix[1L, "Depends"])), "matrix-current-endpoint.txt")
  cat(paste(record, collapse = "\n"), "\n", sep = "")
}

if (sys.nframe() == 0L) resolveMatrixCurrent()
