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

# Site configuration and the curated landing page belong to the checkout,
# while R source archives deliberately exclude those repository-only files.
for (input in c("_pkgdown.yml", file.path("pkgdown", "index.md"))) {
  link = Sys.readlink(input)
  if (!isTRUE(file_test("-f", input)) || (!is.na(link) && nzchar(link))) {
    stop("Documentation input is missing or linked: ", input, call. = FALSE)
  }
  target = file.path(packageRoot, input)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (!isTRUE(file.copy(input, target, overwrite = TRUE))) {
    stop("Unable to stage documentation input: ", input, call. = FALSE)
  }
}

pkgdown::build_site(pkg = packageRoot)

siteRoot = file.path(packageRoot, ".pkgdown-site")
if (!file.exists(file.path(siteRoot, "index.html")) ||
    !file.exists(file.path(siteRoot, "articles", "first-simulation.html"))) {
  stop("pkgdown output is incomplete: ", siteRoot, call. = FALSE)
}

# pkgdown renders package citation, NEWS, and repository governance/contributor
# files by default. Those records remain in their authoritative locations but
# are not part of this public documentation artifact.
repositoryOnlyPages = c(
  file.path(siteRoot, "authors.html"),
  file.path(siteRoot, "CONTRIBUTORS.html"),
  file.path(siteRoot, "GOVERNANCE.html"),
  file.path(siteRoot, "news")
)
for (page in repositoryOnlyPages) {
  if (file.exists(page)) {
    removed = unlink(page, recursive = TRUE, force = TRUE)
    if (!identical(removed, 0L)) {
      stop("Unable to remove repository-only pkgdown output: ", page, call. = FALSE)
    }
  }
}

sitemap = file.path(siteRoot, "sitemap.xml")
if (file.exists(sitemap)) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("xml2 is required to prune removed pages from sitemap.xml", call. = FALSE)
  }
  sitemapXml = xml2::read_xml(sitemap)
  locations = xml2::xml_find_all(sitemapXml, ".//*[local-name()='loc']")
  hiddenPage = grepl("/(authors\\.html|CONTRIBUTORS\\.html|news/)", xml2::xml_text(locations))
  if (any(hiddenPage)) {
    xml2::xml_remove(locations[hiddenPage])
    xml2::write_xml(sitemapXml, sitemap)
  }
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
