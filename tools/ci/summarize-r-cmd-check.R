#!/usr/bin/env Rscript

phase04Baseline = function() {
  c(passes = 2364L, failures = 19L, skips = 65L,
    errors = 1L, warnings = 4L, notes = 4L)
}

checkCount = function(value) {
  if (length(value) != 1L || is.na(value)) return("not reported")
  format(as.integer(value), big.mark = ",", scientific = FALSE, trim = TRUE)
}

formatRcmdCheckReport = function(current, baseline = phase04Baseline()) {
  fields = names(phase04Baseline())
  stopifnot(identical(names(baseline), fields),
            identical(names(current$counts), fields),
            length(current$exitStatus) == 1L,
            !is.na(current$exitStatus))
  baselineText = sprintf(
    "%s passes, %s failures, %s skips, %s ERROR, %s WARNINGs, and %s NOTEs",
    checkCount(baseline[["passes"]]), checkCount(baseline[["failures"]]),
    checkCount(baseline[["skips"]]), checkCount(baseline[["errors"]]),
    checkCount(baseline[["warnings"]]), checkCount(baseline[["notes"]])
  )
  c(
    "## Representative R CMD check baseline (informational, non-required)",
    "",
    paste("Observed current check result:", current$result),
    paste("Original R CMD check exit status:", current$exitStatus),
    "",
    "| Count | Observed current check | Inherited Phase 04 baseline only |",
    "| --- | --- | --- |",
    vapply(fields, function(field) {
      sprintf("| %s | %s | %s |", field, checkCount(current$counts[[field]]),
              checkCount(baseline[[field]]))
    }, character(1L)),
    "",
    "Inherited Phase 04 baseline only:",
    baselineText,
    "",
    "These inherited counts describe Phase 04; this report makes no claim that Phase 05 resolves them.",
    "A missing current count is reported as not reported, rather than copied from the baseline.",
    ""
  )
}

selfTestRcmdCheckReport = function() {
  current = list(
    result = "synthetic nonzero check result",
    exitStatus = 11L,
    counts = c(passes = 17L, failures = 2L, skips = 3L,
               errors = 1L, warnings = 2L, notes = 3L)
  )
  report = formatRcmdCheckReport(current)
  stopifnot(
    "Observed current check result: synthetic nonzero check result" %in% report,
    "Original R CMD check exit status: 11" %in% report,
    "| Count | Observed current check | Inherited Phase 04 baseline only |" %in% report,
    "| passes | 17 | 2,364 |" %in% report,
    "| failures | 2 | 19 |" %in% report,
    "| skips | 3 | 65 |" %in% report,
    "| errors | 1 | 1 |" %in% report,
    "| warnings | 2 | 4 |" %in% report,
    "| notes | 3 | 4 |" %in% report,
    "2,364 passes, 19 failures, 65 skips, 1 ERROR, 4 WARNINGs, and 4 NOTEs" %in% report
  )
  current$counts[] = NA_integer_
  current$exitStatus = 0L
  report = formatRcmdCheckReport(current)
  stopifnot("| passes | not reported | 2,364 |" %in% report,
            "Original R CMD check exit status: 0" %in% report)
  observed = parseRcmdCheckCounts(
    "Status: 1 ERROR, 2 WARNINGs, 3 NOTEs",
    "[ FAIL 2 | WARN 0 | SKIP 3 | PASS 17 ]"
  )
  stopifnot(identical(observed$counts, c(passes = 17L, failures = 2L,
                                        skips = 3L, errors = 1L,
                                        warnings = 2L, notes = 3L)))
  cat("PASS: report formatter preserves current labels, original exit status and exact inherited Phase 04 baseline; no package check ran\n")
  invisible(TRUE)
}

parseRcmdCheckCounts = function(checkLines, testLines) {
  counts = setNames(rep(NA_integer_, length(phase04Baseline())),
                    names(phase04Baseline()))
  status = grep("^Status:", checkLines, value = TRUE)
  result = if (length(status)) tail(status, 1L) else "Status summary not reported"
  if (length(status)) {
    labels = c(errors = "ERROR", warnings = "WARNING", notes = "NOTE")
    for (key in names(labels)) {
      match = regmatches(result, regexec(paste0("([0-9]+) ", labels[[key]]), result))[[1L]]
      counts[[key]] = if (length(match)) as.integer(match[[2L]]) else 0L
    }
  }
  summaries = grep("\\[.*FAIL[[:space:]]+[0-9,]+.*PASS[[:space:]]+[0-9,]+.*\\]",
                   testLines, value = TRUE)
  if (length(summaries)) {
    latest = tail(summaries, 1L)
    for (key in c("passes", "failures", "skips")) {
      label = c(passes = "PASS", failures = "FAIL", skips = "SKIP")[[key]]
      match = regmatches(latest, regexec(
        paste0(label, "[[:space:]]+([0-9,]+)"), latest))[[1L]]
      if (length(match)) counts[[key]] = as.integer(gsub(",", "", match[[2L]]))
    }
  }
  list(result = result, counts = counts)
}

copyCheckSource = function(source, destination) {
  # Prefer the tracked manifest: private inputs and unrelated untracked output
  # must not enter a source archive or its downloadable check directory.
  files = suppressWarnings(system2("git", c("-C", shQuote(source), "ls-files"),
                                   stdout = TRUE, stderr = FALSE))
  if (!length(files) || !is.null(attr(files, "status"))) {
    stop("R CMD check requires a Git source checkout", call. = FALSE)
  }
  files = files[!grepl("^(\\.git|\\.planning|\\.gsd|\\.codex|\\.agents|\\.aws)(/|$)", files)]
  files = files[!grepl("(^|/)([^/]+\\.(o|so|dll|a)|[^/]+\\.Rcheck)(/|$)", files)]
  files = files[!grepl("(^|/)(\\.RData|\\.Rhistory|\\.Renviron|\\.Rproj.user)(/|$)", files)]
  dir.create(destination, recursive = TRUE)
  for (file in files) {
    from = file.path(source, file)
    to = file.path(destination, file)
    if (!file.exists(from) || dir.exists(from)) next
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(from, to, overwrite = FALSE, copy.mode = TRUE)) {
      stop(paste("Could not copy tracked source:", file), call. = FALSE)
    }
  }
  stopifnot(file.exists(file.path(destination, "DESCRIPTION")))
}

runRcmdCheckReport = function() {
  source = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  temporaryRoot = Sys.getenv("RUNNER_TEMP", unset = dirname(tempdir()))
  temporaryRoot = normalizePath(temporaryRoot, winslash = "/", mustWork = TRUE)
  artifacts = Sys.getenv("GEModelR_CHECK_ARTIFACT_DIR", unset = "")
  if (!nzchar(artifacts)) artifacts = tempfile("GEModelR-check-", tmpdir = temporaryRoot)
  dir.create(artifacts, recursive = TRUE, showWarnings = FALSE)
  artifacts = normalizePath(artifacts, winslash = "/", mustWork = TRUE)
  inside = function(path, directory) {
    identical(path, directory) || startsWith(path, paste0(directory, "/"))
  }
  if (inside(artifacts, source) || !inside(artifacts, temporaryRoot)) {
    stop("Check artifacts must be in a temporary directory outside the source checkout",
         call. = FALSE)
  }
  library = Sys.getenv("GEModelR_TEST_LIBRARY", unset = file.path(artifacts, "library"))
  dir.create(library, recursive = TRUE, showWarnings = FALSE)
  library = normalizePath(library, winslash = "/", mustWork = TRUE)
  if (!inside(library, temporaryRoot) || inside(library, source)) {
    stop("R CMD check library must be an explicit temporary library", call. = FALSE)
  }
  matrixVersion = as.character(packageVersion("Matrix", lib.loc = unique(c(library, .libPaths()))))
  expectedMatrix = Sys.getenv("GEModelR_EXPECT_MATRIX_VERSION", unset = "")
  if (nzchar(expectedMatrix) && !identical(expectedMatrix, "installed") &&
      package_version(matrixVersion) != package_version(expectedMatrix)) {
    stop("Representative check Matrix does not match its exact endpoint", call. = FALSE)
  }
  sourceCopy = file.path(artifacts, "source")
  if (file.exists(sourceCopy)) stop("Check source copy must be new", call. = FALSE)
  copyCheckSource(source, sourceCopy)
  description = read.dcf(file.path(sourceCopy, "DESCRIPTION"))
  archive = paste0(description[1L, "Package"], "_", description[1L, "Version"], ".tar.gz")
  buildLog = file.path(artifacts, "R-CMD-build.log")
  rawLog = file.path(artifacts, "R-CMD-check.log")
  makevars = file.path(artifacts, "Makevars-serial")
  writeLines("SHLIB_OPENMP_CXXFLAGS =", makevars)
  oldDirectory = getwd()
  oldEnvironment = Sys.getenv(c("R_LIBS", "R_MAKEVARS_USER", "GEModelR_EXPECT_OPENMP"),
                              unset = NA_character_)
  on.exit({
    setwd(oldDirectory)
    for (name in names(oldEnvironment)) {
      if (is.na(oldEnvironment[[name]])) Sys.unsetenv(name) else {
        do.call(Sys.setenv, setNames(list(oldEnvironment[[name]]), name))
      }
    }
  }, add = TRUE)
  Sys.setenv(R_LIBS = paste(unique(c(library, .libPaths())), collapse = .Platform$path.sep),
             R_MAKEVARS_USER = makevars, GEModelR_EXPECT_OPENMP = "forbidden")
  setwd(artifacts)
  r = file.path(R.home("bin"), "R")
  cat("Full package check: disposable source", sourceCopy, "\n")
  cat("Explicit check library:", library, "\n")
  buildStatus = system2(r, c("CMD", "build", shQuote(sourceCopy)),
                        stdout = buildLog, stderr = buildLog)
  writeLines(as.character(buildStatus), file.path(artifacts, "build-exit-status.txt"))
  if (identical(buildStatus, 0L)) {
    checkStatus = system2(r, c("CMD", "check", paste0("--library=", shQuote(library)),
                              paste0("--output=", shQuote(artifacts)), shQuote(archive)),
                          stdout = rawLog, stderr = rawLog)
    writeLines(as.character(checkStatus), file.path(artifacts, "check-exit-status.txt"))
    checkDirectories = list.dirs(artifacts, recursive = FALSE, full.names = TRUE)
    checkDirectories = checkDirectories[grepl("\\.Rcheck$", checkDirectories)]
    checkLogs = file.path(checkDirectories, "00check.log")
    checkLogs = checkLogs[file.exists(checkLogs)]
    readLogs = function(paths) {
      unlist(lapply(paths, readLines, warn = FALSE), use.names = FALSE)
    }
    checkLines = c(readLines(rawLog, warn = FALSE), readLogs(checkLogs))
    testLogs = unlist(lapply(checkDirectories, list.files, recursive = TRUE,
                            full.names = TRUE, pattern = "\\.Rout(\\.fail)?$"),
                     use.names = FALSE)
    observed = parseRcmdCheckCounts(checkLines, readLogs(testLogs))
    current = c(observed, list(exitStatus = checkStatus))
    returnStatus = checkStatus
  } else {
    writeLines("R CMD check did not run because source build failed.", rawLog)
    writeLines("not run", file.path(artifacts, "check-exit-status.txt"))
    current = list(result = paste("R CMD build failed with exit status", buildStatus),
                   exitStatus = "not run (source build failed)",
                   counts = setNames(rep(NA_integer_, 6L), names(phase04Baseline())))
    returnStatus = buildStatus
  }
  summary = c(formatRcmdCheckReport(current),
              paste("Observed R version:", as.character(getRversion())),
              paste("Observed Matrix version:", matrixVersion),
              paste("Raw full-check log:", rawLog),
              paste("Complete check directory and source archive:", artifacts), "")
  summaryPath = file.path(artifacts, "job-summary.md")
  writeLines(summary, summaryPath)
  githubSummary = Sys.getenv("GITHUB_STEP_SUMMARY")
  if (nzchar(githubSummary)) {
    cat(paste(summary, collapse = "\n"), "\n", file = githubSummary, append = TRUE)
  }
  cat(paste(summary, collapse = "\n"), "\n")
  cat("Preserved check artifacts:", artifacts, "\n")
  invisible(returnStatus)
}

if (sys.nframe() == 0L) {
  arguments = commandArgs(trailingOnly = TRUE)
  if (identical(arguments, "--self-test")) {
    selfTestRcmdCheckReport()
  } else if (identical(arguments, "--run")) {
    quit(status = runRcmdCheckReport())
  } else {
    stop("Usage: summarize-r-cmd-check.R --self-test | --run", call. = FALSE)
  }
}
