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
  cat("PASS: report formatter preserves current labels, original exit status and exact inherited Phase 04 baseline; no package check ran\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  arguments = commandArgs(trailingOnly = TRUE)
  if (identical(arguments, "--self-test")) {
    selfTestRcmdCheckReport()
  } else {
    stop("Usage: summarize-r-cmd-check.R --self-test", call. = FALSE)
  }
}
