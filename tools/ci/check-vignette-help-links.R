#!/usr/bin/env Rscript

local({
vignette_help_script_arg = grep(
  "^--file=", commandArgs(trailingOnly = FALSE), value = TRUE
)
if (length(vignette_help_script_arg) != 1L) {
  stop("Unable to identify the checker script path", call. = FALSE)
}
vignette_help_script = normalizePath(
  sub("^--file=", "", vignette_help_script_arg),
  winslash = "/", mustWork = TRUE
)
vignette_help_source_root = normalizePath(
  file.path(dirname(vignette_help_script), "..", ".."),
  winslash = "/", mustWork = TRUE
)

vignette_help_process = function(command, arguments, directory, environment) {
  previous = setwd(directory)
  on.exit(setwd(previous), add = TRUE)
  output = suppressWarnings(system2(
    command, arguments, stdout = TRUE, stderr = TRUE, env = environment
  ))
  status = attr(output, "status")
  if (is.null(status)) status = 0L
  if (!identical(as.integer(status), 0L)) {
    stop(paste(c(
      paste0("Command failed with exit status ", status, ": ", command),
      output
    ), collapse = "\n"), call. = FALSE)
  }
  invisible(as.character(output))
}

vignette_help_target = function(page, expected_target, output_name) {
  html = paste(readLines(page, warn = FALSE, encoding = "UTF-8"),
               collapse = "\n")
  anchors = regmatches(
    html,
    gregexpr(
      "<a\\b[^>]*>[\\s\\S]*?</a>",
      html, perl = TRUE, ignore.case = TRUE
    )
  )[[1L]]
  all_anchors = anchors
  anchor_text = gsub("<[^>]*>", " ", anchors, perl = TRUE)
  anchors = anchors[grepl(
    "GEModelR[[:space:]]+package[[:space:]]+help",
    anchor_text, ignore.case = TRUE, perl = TRUE
  )]
  if (length(anchors) != 1L) {
    link_candidates = paste(
      all_anchors[grepl("GEModelR", anchor_text, ignore.case = TRUE)],
      collapse = " | "
    )
    stop(sprintf(
      "%s must contain exactly one GEModelR package help link: %s; candidates: %s",
      output_name, page, link_candidates
    ), call. = FALSE)
  }
  href_match = regexec("href=[\"']([^\"']+)[\"']", anchors[[1L]], perl = TRUE)
  href_parts = regmatches(anchors[[1L]], href_match)[[1L]]
  if (length(href_parts) != 2L) {
    stop(sprintf("Unable to read the help link in %s", page), call. = FALSE)
  }
  href = sub("[?#].*$", "", href_parts[[2L]])
  if (grepl("^[A-Za-z][A-Za-z0-9+.-]*:", href) || startsWith(href, "/")) {
    stop(sprintf("Expected a local help link in %s, found %s", page, href),
         call. = FALSE)
  }
  actual_target = normalizePath(
    file.path(dirname(page), utils::URLdecode(href)),
    winslash = "/", mustWork = FALSE
  )
  expected_target = normalizePath(
    expected_target, winslash = "/", mustWork = TRUE
  )
  if (!file.exists(actual_target) || !identical(actual_target, expected_target)) {
    stop(sprintf(
      "%s help link does not resolve to its package manual page (href=%s)",
      output_name, href
    ), call. = FALSE)
  }
  cat(sprintf("PASS %s: %s -> %s\n", output_name, href,
              basename(actual_target)))
  invisible(href)
}

vignette_help_temp_root = tempfile("gemodelr-vignette-help-links-")
dir.create(vignette_help_temp_root, recursive = TRUE)
on.exit(unlink(vignette_help_temp_root, recursive = TRUE, force = TRUE),
        add = TRUE)

build_root = file.path(vignette_help_temp_root, "build")
library_root = file.path(vignette_help_temp_root, "library")
unpack_root = file.path(vignette_help_temp_root, "unpack")
dir.create(build_root)
dir.create(library_root)
dir.create(unpack_root)

ambient_libraries = normalizePath(.libPaths(), winslash = "/", mustWork = TRUE)
environment = c(
  paste0("R_LIBS_USER=", normalizePath(library_root, winslash = "/",
                                          mustWork = TRUE)),
  paste0("R_LIBS_SITE=", paste(ambient_libraries,
                                collapse = .Platform$path.sep)),
  "R_ENVIRON_USER=/dev/null",
  "R_PROFILE_USER=/dev/null"
)
r_command = file.path(R.home("bin"), "R")

vignette_help_process(
  r_command,
  c("CMD", "build", "--no-manual", shQuote(vignette_help_source_root)),
  build_root,
  environment
)
archives = list.files(
  build_root, pattern = "^GEModelR_[^/]+[.]tar[.]gz$", full.names = TRUE
)
if (length(archives) != 1L) {
  stop("Expected exactly one GEModelR source archive", call. = FALSE)
}

vignette_help_process(
  r_command,
  c("CMD", "INSTALL", "--html",
    paste0("--library=", shQuote(library_root)),
    shQuote(archives[[1L]])),
  build_root,
  environment
)
installed_package = file.path(library_root, "GEModelR")
installed_doc = file.path(installed_package, "doc")
installed_html = file.path(installed_package, "html", "GEModelR-package.html")
if (!file.exists(installed_html)) {
  stop("Installed GEModelR package manual page is missing", call. = FALSE)
}
for (article in c("backend-selection", "diagnostics-memory-budgeting")) {
  page = file.path(installed_doc, paste0(article, ".html"))
  if (!file.exists(page)) {
    stop(sprintf("Installed vignette HTML is missing: %s", page),
         call. = FALSE)
  }
  vignette_help_target(page, installed_html, paste0("installed ", article))
}

utils::untar(archives[[1L]], exdir = unpack_root)
package_directories = list.dirs(unpack_root, recursive = FALSE, full.names = TRUE)
package_directories = package_directories[file.exists(
  file.path(package_directories, "DESCRIPTION")
)]
if (length(package_directories) != 1L) {
  stop("Expected one unpacked GEModelR source tree", call. = FALSE)
}
unpacked_source = normalizePath(
  package_directories[[1L]], winslash = "/", mustWork = TRUE
)
pkgdown::build_site(
  pkg = unpacked_source,
  examples = FALSE,
  run_dont_run = FALSE,
  preview = FALSE,
  devel = FALSE,
  new_process = FALSE,
  install = TRUE,
  quiet = TRUE,
  override = list(destination = ".pkgdown-link-check")
)
site_root = file.path(unpacked_source, ".pkgdown-link-check")
site_reference = file.path(site_root, "reference", "GEModelR-package.html")
if (!file.exists(site_reference)) {
  stop("Pkgdown GEModelR package reference page is missing", call. = FALSE)
}
for (article in c("backend-selection", "diagnostics-memory-budgeting")) {
  page = file.path(site_root, "articles", paste0(article, ".html"))
  if (!file.exists(page)) {
    stop(sprintf("Pkgdown article HTML is missing: %s", page),
         call. = FALSE)
  }
  vignette_help_target(page, site_reference, paste0("pkgdown ", article))
}

cat("PASS installed-vignette and pkgdown package-help links\n")
})
