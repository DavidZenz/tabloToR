#!/usr/bin/env Rscript

metadata = read.dcf("DESCRIPTION")
package = metadata[1L, "Package"]
version = metadata[1L, "Version"]
archive = paste0(package, "_", version, ".tar.gz")
if (!file.exists(archive)) {
  stop("Source archive is missing: ", archive, call. = FALSE)
}

status = system2(
  "node",
  args = shQuote(c("tools/ci/check-public-content.cjs", "--archive", archive)),
  # R can set LD_LIBRARY_PATH to its own libraries. Do not pass that to Node,
  # whose native dependencies must resolve from the system runtime instead.
  env = "LD_LIBRARY_PATH="
)
if (!identical(status, 0L)) {
  stop("Source archive content gate failed", call. = FALSE)
}

runnerTemp = Sys.getenv("RUNNER_TEMP", unset = tempdir())
sourceRoot = file.path(runnerTemp, "pkgdown-source")
unlink(sourceRoot, recursive = TRUE, force = TRUE)
dir.create(sourceRoot, recursive = TRUE)
utils::untar(archive, exdir = sourceRoot)

packageRoot = file.path(sourceRoot, package)
if (!dir.exists(packageRoot)) {
  stop("Extracted package directory is missing: ", packageRoot, call. = FALSE)
}

pkgdown::build_site(pkg = packageRoot)

siteRoot = file.path(packageRoot, ".pkgdown-site")
if (!file.exists(file.path(siteRoot, "index.html")) ||
    !file.exists(file.path(siteRoot, "articles", "first-simulation.html"))) {
  stop("pkgdown output is incomplete: ", siteRoot, call. = FALSE)
}

artifactRoot = file.path(runnerTemp, "pkgdown-site")
unlink(artifactRoot, recursive = TRUE, force = TRUE)
dir.create(artifactRoot, recursive = TRUE)
siteFiles = list.files(
  siteRoot,
  all.files = TRUE,
  full.names = TRUE,
  no.. = TRUE
)
copied = file.copy(siteFiles, artifactRoot, recursive = TRUE)
if (length(copied) == 0L || !all(copied)) {
  stop("Unable to stage the complete pkgdown site artifact", call. = FALSE)
}
