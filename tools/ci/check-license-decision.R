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

licenseEvidencePath = function(root, relative) {
  if (length(relative) != 1L || is.na(relative) || !nzchar(relative) ||
      grepl("^/|^[A-Za-z]:|\\\\|(^|/)[.][.]?(/|$)", relative)) {
    stop("Invalid license evidence path", call. = FALSE)
  }
  current = root
  for (part in strsplit(relative, "/", fixed = TRUE)[[1L]]) {
    current = file.path(current, part)
    link = Sys.readlink(current)
    if (!is.na(link) && nzchar(link)) stop("Linked license evidence is forbidden", call. = FALSE)
  }
  if (!isTRUE(file_test("-f", current)) ||
      !startsWith(normalizePath(current, winslash = "/"), paste0(root, "/"))) {
    stop("License evidence is missing or outside root", call. = FALSE)
  }
  current
}

licensePackageNames = function(value) {
  if (is.na(value) || !nzchar(value)) return(character())
  sort(trimws(sub("[[:space:]]*\\(.*$", "", strsplit(value, ",", fixed = TRUE)[[1L]])))
}

licenseDependencyCompatible = function(package, expression) {
  expression = gsub("[[:space:]]", "", expression)
  expression %in% c("GPL(>=2)", "GPL(>=3)", "GPL-3", "GPL-2|GPL-3") ||
    (identical(package, "Matrix") && identical(expression, "GPL(>=2)|fileLICENCE")) ||
    (identical(package, "methods") && grepl("^PartofR[0-9]+[.][0-9]+[.][0-9]+$", expression))
}

runLicenseDecisionCheck = function(root, inspectInstalled = TRUE) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  relative = if (file.exists(file.path(root, "docs", "release", "LICENSE-DECISION.md"))) {
    "docs/release/LICENSE-DECISION.md"
  } else "inst/compatibility/release-license.dcf"
  decisionPath = licenseEvidencePath(root, relative)
  descriptionPath = licenseEvidencePath(root, "DESCRIPTION")

  decision = parseDecisionRecord(decisionPath)
  required = c(
    "Decision-Record-Version", "Decision-Status", "SPDX-License-Identifier",
    "Description-License", "Decision-Authority", "Reviewer",
    "Review-Date-UTC", "Referenced-License-Files", "Citation-File",
    "Outstanding-Blockers", "Dependency-Audit-Artifact", "Dependency-Audit-MD5",
    "License-Selection-Authority", "License-Selection-Date"
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
  requireField(decision, "License-Selection-Authority", "David Zenz")
  requireField(decision, "License-Selection-Date", "2026-10-19")
  date = suppressWarnings(as.Date(decision[["Review-Date-UTC"]], format = "%Y-%m-%d"))
  if (!nzchar(decision[["Reviewer"]]) || decision[["Reviewer"]] == "pending" ||
      is.na(date) || format(date, "%Y-%m-%d") != decision[["Review-Date-UTC"]]) {
    stop("License technical review is incomplete", call. = FALSE)
  }
  requireField(decision, "Referenced-License-Files", "none")
  requireField(decision, "Citation-File", "inst/CITATION")
  requireField(
    decision, "Outstanding-Blockers",
    "NONE"
  )
  publicPath = file.path(root, "inst", "compatibility", "release-license.dcf")
  if (file.exists(publicPath)) {
    public = parseDecisionRecord(licenseEvidencePath(root, "inst/compatibility/release-license.dcf"))
    if (!identical(decision[required], public[required])) {
      stop("Public license summary disagrees with decision", call. = FALSE)
    }
  }
  requireField(decision, "Dependency-Audit-Artifact", "inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md")
  auditPath = licenseEvidencePath(root, decision[["Dependency-Audit-Artifact"]])
  digest = decision[["Dependency-Audit-MD5"]]
  if (!grepl("^[a-f0-9]{32}$", digest) || !identical(unname(tools::md5sum(auditPath)), digest)) {
    stop("Dependency audit digest mismatch", call. = FALSE)
  }
  audit = parseDecisionRecord(auditPath)
  requireField(audit, "Audit-Version", "1")
  requireField(audit, "Audit-Result", "compatible")
  requireField(audit, "Package-License", "GPL-3.0-or-later")

  description = tryCatch(
    read.dcf(descriptionPath),
    error = function(error) stop("DESCRIPTION cannot be parsed", call. = FALSE)
  )
  if (nrow(description) != 1L ||
      !identical(unname(description[1L, "Package"]), "GEModelR") ||
      !identical(unname(description[1L, "License"]), decision[["Description-License"]])) {
    stop("DESCRIPTION package identity or License field disagrees with the decision", call. = FALSE)
  }

  authorityPath = licenseEvidencePath(root, decision[["Decision-Authority"]])
  citationPath = licenseEvidencePath(root, decision[["Citation-File"]])
  if (!file.exists(authorityPath) || !file.exists(citationPath)) {
    stop("A referenced authority or citation file is missing", call. = FALSE)
  }
  authority = readLines(authorityPath, warn = FALSE, encoding = "UTF-8")
  if (!any(authority == "Maintainer: David Zenz") ||
      !any(authority == "Release-Authority: David Zenz") ||
      !any(authority == "Identity-Approval: approved")) {
    stop("The named decision authority does not match approved governance", call. = FALSE)
  }
  if (!identical(licensePackageNames(description[1L, "Imports"]), sort(c("Matrix", "Rcpp", "SparseM", "methods"))) ||
      !identical(licensePackageNames(description[1L, "LinkingTo"]), "Rcpp")) {
    stop("Dependency declarations changed beyond the reviewed audit", call. = FALSE)
  }
  if (isTRUE(inspectInstalled)) {
    for (package in c("Matrix", "Rcpp", "SparseM", "methods")) {
      value = utils::packageDescription(package)
      if (!is.list(value) || length(value$License) != 1L ||
          !licenseDependencyCompatible(package, value$License)) {
        stop(paste("Dependency license needs review:", package), call. = FALSE)
      }
    }
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

  message("License decision and dependency audit verified: GPL-3.0-or-later.")
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
arguments = commandArgs(trailingOnly = TRUE)
if (length(arguments) == 0L) {
  packageRoot = getwd()
} else if (length(arguments) == 2L && identical(arguments[[1L]], "--root")) {
  packageRoot = arguments[[2L]]
} else {
  stop("Usage: Rscript --vanilla tools/ci/check-license-decision.R [--root PATH]", call. = FALSE)
}

runLicenseDecisionCheck(packageRoot)
}
