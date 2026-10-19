parseDecisionRecord = function(path) {
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  markerLines = grep("^[A-Za-z][A-Za-z0-9-]*:", lines, value = TRUE)
  keys = sub(":.*$", "", markerLines)
  values = sub("^[^:]+:[[:space:]]*", "", markerLines)
  if (anyDuplicated(keys)) {
    stop("License decision contains duplicate metadata fields", call. = FALSE)
  }
  stats::setNames(values, keys)
}

requireField = function(fields, name, expected) {
  actual = fields[[name]]
  if (length(actual) != 1L || is.na(actual) || !identical(actual, expected)) {
    stop(paste0("License decision field mismatch: ", name), call. = FALSE)
  }
  invisible(actual)
}

runLicenseDecisionCheck = function(root) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  decisionPath = file.path(root, "docs", "release", "LICENSE-DECISION.md")
  descriptionPath = file.path(root, "DESCRIPTION")
  if (!file.exists(decisionPath) || !file.exists(descriptionPath)) {
    stop("License decision or DESCRIPTION is missing", call. = FALSE)
  }

  decision = parseDecisionRecord(decisionPath)
  required = c(
    "Decision-Record-Version", "Decision-Status", "SPDX-License-Identifier",
    "Description-License", "Decision-Authority", "Reviewer",
    "Review-Date-UTC", "Referenced-License-Files", "Citation-File",
    "Outstanding-Blockers"
  )
  missing = setdiff(required, names(decision))
  if (length(missing)) {
    stop(
      paste("License decision is missing fields:", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }

  requireField(decision, "Decision-Record-Version", "1")
  requireField(decision, "Decision-Status", "reviewed")
  requireField(decision, "SPDX-License-Identifier", "GPL-3.0-or-later")
  requireField(decision, "Description-License", "GPL (>= 3)")
  requireField(decision, "Decision-Authority", "GOVERNANCE.md")
  requireField(decision, "Reviewer", "David Zenz")
  requireField(decision, "Review-Date-UTC", "2026-10-19")
  requireField(decision, "Referenced-License-Files", "none")
  requireField(decision, "Citation-File", "inst/CITATION")
  requireField(
    decision, "Outstanding-Blockers",
    "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED"
  )

  description = tryCatch(
    read.dcf(descriptionPath),
    error = function(error) stop("DESCRIPTION cannot be parsed", call. = FALSE)
  )
  if (nrow(description) != 1L ||
      !identical(unname(description[1L, "Package"]), "GEModelR") ||
      !identical(unname(description[1L, "License"]), decision[["Description-License"]])) {
    stop("DESCRIPTION package identity or License field disagrees with the decision", call. = FALSE)
  }

  authorityPath = file.path(root, decision[["Decision-Authority"]])
  citationPath = file.path(root, decision[["Citation-File"]])
  if (!file.exists(authorityPath) || !file.exists(citationPath)) {
    stop("A referenced authority or citation file is missing", call. = FALSE)
  }
  authority = readLines(authorityPath, warn = FALSE, encoding = "UTF-8")
  if (!any(authority == "Maintainer: David Zenz") ||
      !any(authority == "Release-Authority: David Zenz") ||
      !any(authority == "Identity-Approval: approved")) {
    stop("The named decision authority does not match approved governance", call. = FALSE)
  }

  analyzeLicense = get0("analyze_license", envir = asNamespace("tools"), inherits = FALSE)
  if (!is.function(analyzeLicense)) {
    stop("This R version cannot validate standard license expressions", call. = FALSE)
  }
  licenseAnalysis = tryCatch(
    analyzeLicense(decision[["Description-License"]]),
    error = function(error) stop("R rejected the DESCRIPTION License expression", call. = FALSE)
  )
  if (!isTRUE(licenseAnalysis$is_canonical) ||
      !isTRUE(licenseAnalysis$is_FOSS) ||
      length(licenseAnalysis$bad_components) != 0L ||
      !identical(licenseAnalysis$standardization, decision[["Description-License"]])) {
    stop("R does not recognize the selected expression as a canonical free/open-source license", call. = FALSE)
  }

  message("License decision verified: GPL-3.0-or-later (GPL (>= 3)).")
  invisible(TRUE)
}

arguments = commandArgs(trailingOnly = TRUE)
if (length(arguments) == 0L) {
  packageRoot = getwd()
} else if (length(arguments) == 2L && identical(arguments[[1L]], "--root")) {
  packageRoot = arguments[[2L]]
} else {
  stop("Usage: Rscript --vanilla tools/ci/check-license-decision.R [--root PATH]", call. = FALSE)
}

runLicenseDecisionCheck(packageRoot)
