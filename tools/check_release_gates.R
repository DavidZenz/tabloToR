#!/usr/bin/env Rscript

release_gate_result <- function(repository_state = "invalid",
                                release_ready = FALSE,
                                reason_codes,
                                parse_status = c(
                                  rights = "fail",
                                  release_gates = "not-evaluated"
                                ),
                                intentional_blockers = character()) {
  list(
    repository_state = as.character(repository_state)[[1L]],
    release_ready = isTRUE(release_ready),
    reason_codes = as.character(reason_codes),
    parse_status = parse_status,
    intentional_blockers = as.character(intentional_blockers)
  )
}

release_gate_marker_values <- function(lines, field) {
  pattern <- paste0("^", field, ":[[:space:]]*(.*)$")
  hits <- grep(pattern, lines, value = TRUE)
  sub(pattern, "\\1", hits)
}

release_gate_read_lines <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(error) NULL
  )
}

release_gate_file_hash <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::md5sum(normalizePath(path, mustWork = TRUE))[[1L]])
}

release_gate_single_markers <- function(lines, fields) {
  values <- lapply(fields, function(field) {
    release_gate_marker_values(lines, field)
  })
  names(values) <- fields
  values
}

release_gate_resolve_evidence_path <- function(root, relative_path) {
  if (!is.character(relative_path) || length(relative_path) != 1L ||
      is.na(relative_path) || !nzchar(trimws(relative_path)) ||
      grepl("[\r\n]", relative_path)) {
    return(NULL)
  }
  normalizedRelative <- gsub("\\\\", "/", relative_path)
  components <- strsplit(normalizedRelative, "/", fixed = TRUE)[[1L]]
  if (startsWith(normalizedRelative, "/") ||
      grepl("^[A-Za-z]:", normalizedRelative) ||
      any(components %in% c("", ".", ".."))) {
    return(NULL)
  }
  rootPath <- tryCatch(
    normalizePath(root, winslash = "/", mustWork = TRUE),
    error = function(error) NULL
  )
  candidate <- do.call(file.path, as.list(c(rootPath, components)))
  if (is.null(rootPath) || !file.exists(candidate) || dir.exists(candidate) ||
      !isTRUE(file_test("-f", candidate))) {
    return(NULL)
  }
  info <- file.info(candidate)
  if (is.na(info[["size"]][[1L]]) || info[["size"]][[1L]] <= 0L) {
    return(NULL)
  }
  resolved <- tryCatch(
    normalizePath(candidate, winslash = "/", mustWork = TRUE),
    error = function(error) NULL
  )
  if (is.null(resolved) || !startsWith(resolved, paste0(rootPath, "/"))) {
    return(NULL)
  }
  resolved
}

release_gate_verify_evidence_file <- function(
    root, relative_path, expected_md5) {
  if (!is.character(expected_md5) || length(expected_md5) != 1L ||
      is.na(expected_md5) || !grepl("^[0-9a-f]{32}$", expected_md5)) {
    return(NULL)
  }
  path <- release_gate_resolve_evidence_path(root, relative_path)
  if (is.null(path)) return(NULL)
  actual <- unname(tools::md5sum(path)[[1L]])
  if (!identical(actual, expected_md5)) return(NULL)
  path
}

release_gate_cleanroom_timeout_seconds <- function() {
  30L
}

release_gate_run_cleanroom_test <- function(
    behavior_test, replacement_source, redistributable_fixture) {
  paths <- c(behavior_test, replacement_source, redistributable_fixture)
  if (length(paths) != 3L || any(!file.exists(paths))) return(FALSE)
  log <- tempfile("release-gate-cleanroom-test-")
  on.exit(unlink(log), add = TRUE)
  arguments <- c(
    "--vanilla", shQuote(behavior_test),
    "--source", shQuote(replacement_source),
    "--fixture", shQuote(redistributable_fixture)
  )
  status <- tryCatch(
    suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"), arguments,
      stdout = log, stderr = log,
      timeout = as.integer(release_gate_cleanroom_timeout_seconds())
    )),
    error = function(error) NA_integer_
  )
  identical(as.integer(status), 0L)
}

release_gate_cleanroom_timestamp_valid <- function(value) {
  if (!is.character(value) || length(value) != 1L ||
      !grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
        value
      )) {
    return(FALSE)
  }
  parsed <- as.POSIXct(
    value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  !is.na(parsed) && identical(
    format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), value
  )
}

release_gate_cleanroom_date_valid <- function(value) {
  if (!is.character(value) || length(value) != 1L ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", value)) {
    return(FALSE)
  }
  parsed <- as.Date(value, format = "%Y-%m-%d")
  !is.na(parsed) && identical(format(parsed, "%Y-%m-%d"), value)
}

release_gate_read_cleanroom_result <- function(path) {
  required <- c(
    "Component-ID", "Provenance-Key", "Replacement-Source-MD5",
    "Behavior-Test-MD5", "Fixture-MD5", "Public-Standard-Evidence-MD5",
    "Test-Command-ID", "Exit-Status", "Result-Producer",
    "Produced-At-UTC", "Reviewer", "Review-Date", "Result-Status"
  )
  value <- tryCatch(
    read.dcf(path),
    error = function(error) NULL
  )
  if (is.null(value) || nrow(value) != 1L ||
      !identical(colnames(value), required)) {
    return(NULL)
  }
  result <- unname(value[1L, ])
  names(result) <- required
  if (any(is.na(result)) || any(!nzchar(trimws(result))) ||
      !release_gate_cleanroom_timestamp_valid(result[["Produced-At-UTC"]]) ||
      !release_gate_cleanroom_date_valid(result[["Review-Date"]])) {
    return(NULL)
  }
  result
}

release_gate_cleanroom_result_fresh <- function(result, input_paths) {
  produced <- as.POSIXct(
    result[["Produced-At-UTC"]],
    format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  modified <- file.info(input_paths)[["mtime"]]
  if (is.na(produced) || any(is.na(modified))) return(FALSE)
  producedNumber <- as.numeric(produced)
  newestInput <- max(as.numeric(modified))
  producedNumber + 2 >= newestInput &&
    producedNumber <= as.numeric(Sys.time()) + 60
}

release_gate_cleanroom_failure <- function(reason, parsePass,
                                           intentionalBlockers) {
  release_gate_result(
    repository_state = "blocked",
    reason_codes = reason,
    parse_status = c(parsePass, cleanroom = "fail"),
    intentional_blockers = intentionalBlockers
  )
}

release_gate_evaluate_cleanroom <- function(root, cleanroomLines, parsePass,
                                            intentionalBlockers) {
  fail <- function(reason) {
    release_gate_cleanroom_failure(
      reason, parsePass, intentionalBlockers
    )
  }
  if (is.null(cleanroomLines)) {
    return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
  }
  protocol <- release_gate_single_markers(
    cleanroomLines,
    c(
      "Cleanroom-Protocol-Version", "Cleanroom-Coverage",
      "Cleanroom-Review-Status"
    )
  )
  if (any(vapply(protocol, length, integer(1)) != 1L)) {
    return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
  }
  protocolValues <- vapply(protocol, `[[`, character(1), 1L)
  if (!identical(protocolValues[["Cleanroom-Review-Status"]], "approved")) {
    return(fail("CLEANROOM_REVIEW_INCOMPLETE"))
  }
  if (!identical(protocolValues[["Cleanroom-Protocol-Version"]], "2") ||
      !identical(protocolValues[["Cleanroom-Coverage"]], "complete")) {
    return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
  }

  inheritedKeys <- release_gate_marker_values(
    cleanroomLines, "Inherited-Provenance-Key"
  )
  if (!length(inheritedKeys) || any(!nzchar(trimws(inheritedKeys))) ||
      anyDuplicated(inheritedKeys)) {
    return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
  }
  specificationDir <- file.path(root, "specs", "cleanroom")
  specificationFiles <- if (dir.exists(specificationDir)) {
    sort(list.files(
      specificationDir, pattern = "\\.md$", full.names = TRUE
    ))
  } else {
    character()
  }
  specificationFiles <- specificationFiles[
    basename(specificationFiles) != "README.md"
  ]
  if (!length(specificationFiles)) {
    return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
  }

  requiredFields <- c(
    "component_id", "provenance_key", "inputs", "outputs", "errors",
    "invariants", "compatibility_example", "specification_author",
    "specification_attestation", "implementer", "implementer_eligibility",
    "implementer_source_access", "implementer_attestation", "reviewer",
    "reviewer_attestation", "replacement_source", "replacement_source_md5",
    "behavior_test", "behavior_test_md5", "public_standard_evidence",
    "public_standard_evidence_md5", "redistributable_fixture", "fixture_md5",
    "independent_result", "independent_result_md5",
    "provenance_classification"
  )
  evidenceFields <- c(
    replacement_source = "replacement_source_md5",
    behavior_test = "behavior_test_md5",
    public_standard_evidence = "public_standard_evidence_md5",
    redistributable_fixture = "fixture_md5",
    independent_result = "independent_result_md5"
  )
  components <- vector("list", length(specificationFiles))
  for (index in seq_along(specificationFiles)) {
    lines <- release_gate_read_lines(specificationFiles[[index]])
    fields <- release_gate_single_markers(lines, requiredFields)
    sourceAccess <- fields[["implementer_source_access"]]
    eligibility <- fields[["implementer_eligibility"]]
    if (length(sourceAccess) == 1L && nzchar(trimws(sourceAccess)) &&
        !identical(sourceAccess, "none")) {
      return(fail("CLEANROOM_IMPLEMENTER_INELIGIBLE"))
    }
    if (length(eligibility) == 1L && nzchar(trimws(eligibility)) &&
        !identical(eligibility, "eligible")) {
      return(fail("CLEANROOM_IMPLEMENTER_INELIGIBLE"))
    }
    if (any(vapply(fields, length, integer(1)) != 1L)) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }
    values <- vapply(fields, `[[`, character(1), 1L)
    if (any(!nzchar(trimws(values)))) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }
    roles <- unname(values[c(
      "specification_author", "implementer", "reviewer"
    )])
    evidenceComplete <- length(unique(roles)) == 3L &&
      identical(
        values[["specification_attestation"]],
        "behavior-only-no-inherited-expression"
      ) &&
      identical(
        values[["implementer_attestation"]],
        "no-inherited-source-access"
      ) &&
      identical(
        values[["reviewer_attestation"]],
        "independent-review-complete"
      ) &&
      identical(
        values[["provenance_classification"]], "new-independent"
      )
    if (!evidenceComplete) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }

    resolved <- vapply(names(evidenceFields), function(field) {
      path <- release_gate_verify_evidence_file(
        root, values[[field]], values[[evidenceFields[[field]]]]
      )
      if (is.null(path)) "" else path
    }, character(1))
    if (any(!nzchar(resolved)) || anyDuplicated(resolved)) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }

    result <- release_gate_read_cleanroom_result(
      resolved[["independent_result"]]
    )
    if (is.null(result)) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }
    if (identical(
      result[["Result-Producer"]], values[["implementer"]]
    )) {
      return(fail("CLEANROOM_IMPLEMENTER_INELIGIBLE"))
    }
    resultRoles <- c(
      values[["specification_author"]], values[["implementer"]],
      values[["reviewer"]], result[["Result-Producer"]]
    )
    resultMatches <- length(unique(resultRoles)) == 4L &&
      identical(result[["Component-ID"]], values[["component_id"]]) &&
      identical(result[["Provenance-Key"]], values[["provenance_key"]]) &&
      identical(
        result[["Replacement-Source-MD5"]],
        values[["replacement_source_md5"]]
      ) &&
      identical(
        result[["Behavior-Test-MD5"]], values[["behavior_test_md5"]]
      ) &&
      identical(result[["Fixture-MD5"]], values[["fixture_md5"]]) &&
      identical(
        result[["Public-Standard-Evidence-MD5"]],
        values[["public_standard_evidence_md5"]]
      ) &&
      identical(result[["Test-Command-ID"]], "rscript-cleanroom-v1") &&
      identical(result[["Exit-Status"]], "0") &&
      identical(result[["Reviewer"]], values[["reviewer"]]) &&
      identical(result[["Result-Status"]], "pass")
    inputPaths <- resolved[c(
      "replacement_source", "behavior_test", "public_standard_evidence",
      "redistributable_fixture"
    )]
    if (!resultMatches ||
        !release_gate_cleanroom_result_fresh(result, inputPaths) ||
        !release_gate_run_cleanroom_test(
          resolved[["behavior_test"]],
          resolved[["replacement_source"]],
          resolved[["redistributable_fixture"]]
        )) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }
    components[[index]] <- list(
      values = values, paths = resolved, result = result
    )
  }

  componentIds <- vapply(
    components, function(component) component$values[["component_id"]],
    character(1)
  )
  provenanceKeys <- vapply(
    components, function(component) component$values[["provenance_key"]],
    character(1)
  )
  coverageComplete <- !anyDuplicated(componentIds) &&
    !anyDuplicated(provenanceKeys) &&
    identical(sort(provenanceKeys), sort(inheritedKeys))
  if (!coverageComplete) {
    return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
  }
  if (length(intentionalBlockers)) {
    return(release_gate_result(
      reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
      parse_status = c(parsePass, cleanroom = "pass"),
      intentional_blockers = intentionalBlockers
    ))
  }
  eligible <- release_gate_result(
    repository_state = "eligible",
    release_ready = TRUE,
    reason_codes = character(),
    parse_status = c(parsePass, cleanroom = "pass"),
    intentional_blockers = intentionalBlockers
  )
  eligible$cleanroom_components <- components
  eligible$cleanroom_inherited_keys <- inheritedKeys
  eligible
}

release_gate_public_domain_failure <- function(reason, parsePass,
                                               intentionalBlockers) {
  release_gate_result(
    reason_codes = reason,
    parse_status = c(parsePass, public_domain = "fail"),
    intentional_blockers = intentionalBlockers
  )
}

release_gate_evaluate_public_domain <- function(
    root, rightsLines, rightsValues, parsePass, intentionalBlockers) {
  fail <- function(reason) {
    release_gate_public_domain_failure(
      reason, parsePass, intentionalBlockers
    )
  }
  requiredRightsEvidence <- c(
    "Rights-Basis", "Covered-Upstream-Commit", "Covered-Components",
    "Excluded-Components", "Provenance-Coverage-Status",
    "Evidence-Document", "Response-URL", "Response-Date-UTC",
    "Response-Author-GitHub", "Response-Author-Association",
    "Response-Review-Status", "Successor-Name-Basis",
    "Name-Availability-Status"
  )
  rightsEvidence <- release_gate_single_markers(
    rightsLines, requiredRightsEvidence
  )
  if (any(vapply(rightsEvidence, length, integer(1)) != 1L)) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }
  evidenceValues <- vapply(rightsEvidence, `[[`, character(1), 1L)
  if (any(!nzchar(trimws(evidenceValues)))) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }
  evidenceDocument <- evidenceValues[["Evidence-Document"]]
  if (!identical(evidenceDocument, "docs/provenance/UPSTREAM-RESPONSE.md")) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }
  evidencePath <- file.path(root, evidenceDocument)
  evidenceLines <- release_gate_read_lines(evidencePath)
  if (is.null(evidenceLines)) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }
  if (!identical(
    release_gate_file_hash(evidencePath), rightsValues[["Evidence-Hash"]]
  )) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_HASH_MISMATCH"))
  }

  responseFields <- c(
    "Response-Document-Version", "Upstream-Repository", "Upstream-Commit",
    "Response-URL", "Response-Date-UTC", "Response-Author-GitHub",
    "Response-Author-Association", "Response-Statement", "CC0-Reference",
    "US-Government-Works-Reference"
  )
  response <- release_gate_single_markers(evidenceLines, responseFields)
  if (any(vapply(response, length, integer(1)) != 1L)) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }
  responseValues <- vapply(response, `[[`, character(1), 1L)
  expectedStatement <- paste(
    "It is in the public domain (CC0)--I created it as part of my duties",
    "as an employee of the US federal government, and so I do not retain",
    "any copyright."
  )
  metadataMatches <- identical(
    responseValues[["Response-Document-Version"]], "1"
  ) && identical(
    responseValues[["Upstream-Repository"]],
    rightsValues[["Upstream-Repository"]]
  ) && identical(
    responseValues[["Upstream-Commit"]],
    rightsValues[["Upstream-Commit"]]
  ) && identical(
    responseValues[["Response-URL"]],
    evidenceValues[["Response-URL"]]
  ) && identical(
    responseValues[["Response-Date-UTC"]],
    evidenceValues[["Response-Date-UTC"]]
  ) && identical(
    responseValues[["Response-Author-GitHub"]],
    evidenceValues[["Response-Author-GitHub"]]
  ) && identical(
    responseValues[["Response-Author-Association"]],
    evidenceValues[["Response-Author-Association"]]
  ) && identical(
    responseValues[["Response-Statement"]], expectedStatement
  ) && identical(
    responseValues[["CC0-Reference"]],
    "https://creativecommons.org/publicdomain/zero/1.0/"
  ) && startsWith(
    responseValues[["US-Government-Works-Reference"]],
    "https://uscode.house.gov/"
  )
  if (!metadataMatches) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }

  scopeComplete <- identical(
    evidenceValues[["Rights-Basis"]], "public-domain-cc0"
  ) && identical(
    evidenceValues[["Covered-Upstream-Commit"]],
    rightsValues[["Upstream-Commit"]]
  ) && identical(
    evidenceValues[["Covered-Components"]],
    "upstream-authored-inherited-source"
  ) && identical(
    evidenceValues[["Excluded-Components"]],
    "unrelated-third-party-components"
  )
  if (!scopeComplete) {
    return(fail("RIGHTS_SCOPE_INCOMPLETE"))
  }
  reviewComplete <- identical(
    rightsValues[["Rights-Status"]], "cleared"
  ) && identical(
    evidenceValues[["Response-Review-Status"]],
    "accepted-public-domain-cc0"
  ) && !grepl(
    "^pending", rightsValues[["Reviewer"]], ignore.case = TRUE
  ) && grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
    rightsValues[["Review-Date-UTC"]]
  ) && identical(
    evidenceValues[["Successor-Name-Basis"]], "independently-selected"
  ) && identical(
    evidenceValues[["Name-Availability-Status"]], "approved-initial-report"
  )
  if (!reviewComplete) {
    return(fail("PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE"))
  }

  coverageStatus <- evidenceValues[["Provenance-Coverage-Status"]]
  if (!identical(coverageStatus, "complete")) {
    blocker <- "PROVENANCE_COVERAGE_INCOMPLETE"
    if (!identical(intentionalBlockers, blocker)) {
      return(release_gate_result(
        reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
        parse_status = c(
          parsePass, public_domain = "pass",
          provenance_coverage = "incomplete"
        ),
        intentional_blockers = intentionalBlockers
      ))
    }
    return(release_gate_result(
      repository_state = "blocked",
      reason_codes = blocker,
      parse_status = c(
        parsePass, public_domain = "pass",
        provenance_coverage = "incomplete"
      ),
      intentional_blockers = intentionalBlockers
    ))
  }
  release_gate_result(
    repository_state = "eligible",
    release_ready = TRUE,
    reason_codes = character(),
    parse_status = c(
      parsePass, public_domain = "pass", provenance_coverage = "pass"
    ),
    intentional_blockers = intentionalBlockers
  )
}

release_gate_has_sensitive_evidence <- function(root) {
  evidenceDirs <- c(
    file.path(root, "docs", c("provenance", "release")),
    file.path(root, "specs", "cleanroom")
  )
  evidenceDirs <- evidenceDirs[dir.exists(evidenceDirs)]
  if (!length(evidenceDirs)) return(FALSE)
  files <- unlist(lapply(evidenceDirs, function(path) {
    list.files(
      path, recursive = TRUE, full.names = TRUE,
      all.files = TRUE, no.. = TRUE
    )
  }), use.names = FALSE)
  if (!length(files)) return(FALSE)
  info <- file.info(files)
  files <- files[!is.na(info[["isdir"]]) & !info[["isdir"]]]
  info <- info[files, , drop = FALSE]
  namesLower <- tolower(basename(files))
  nameIndicator <- grepl(
    "credential|private[-_]?correspondence|proprietary|giant[-_]?result",
    namesLower
  ) | grepl("\\.(har|tab|rds|rdata)$", namesLower)
  sizeIndicator <- !is.na(info[["size"]]) & info[["size"]] > 5 * 1024^2
  classIndicator <- vapply(files, function(path) {
    lines <- release_gate_read_lines(path)
    if (is.null(lines)) return(FALSE)
    any(grepl(
      "^Evidence-Class:[[:space:]]*(credential|private-correspondence|proprietary-model|giant-result)[[:space:]]*$",
      lines,
      ignore.case = TRUE
    ))
  }, logical(1))
  any(nameIndicator | sizeIndicator | classIndicator)
}

release_gate_evaluate <- function(root = ".") {
  root <- normalizePath(root, mustWork = TRUE)
  if (release_gate_has_sensitive_evidence(root)) {
    return(release_gate_result(reason_codes = "SENSITIVE_EVIDENCE_CLASS"))
  }
  rightsPath <- file.path(root, "docs", "provenance", "RIGHTS.md")
  releasePath <- file.path(root, "docs", "release", "RELEASE-GATES.md")
  rightsLines <- release_gate_read_lines(rightsPath)
  if (is.null(rightsLines)) {
    return(release_gate_result(reason_codes = "RIGHTS_DOCUMENT_MISSING"))
  }

  requiredRights <- c(
    "Rights-Status", "Upstream-Repository", "Upstream-Commit",
    "Request-Status", "Request-URL", "Request-Date-UTC",
    "Request-Content-Hash", "Evidence-Hash", "Reviewer",
    "Review-Date-UTC"
  )
  rights <- release_gate_single_markers(rightsLines, requiredRights)
  if (length(rights[["Rights-Status"]]) != 1L) {
    return(release_gate_result(reason_codes = "RIGHTS_STATUS_CARDINALITY"))
  }
  otherCardinality <- vapply(
    rights[setdiff(requiredRights, "Rights-Status")],
    length,
    integer(1)
  )
  if (any(otherCardinality != 1L)) {
    return(release_gate_result(reason_codes = "RIGHTS_FIELD_CARDINALITY"))
  }
  rightsValues <- vapply(rights, `[[`, character(1), 1L)
  if (any(!nzchar(trimws(rightsValues)))) {
    return(release_gate_result(reason_codes = "RIGHTS_FIELD_EMPTY"))
  }
  rightsStatus <- rightsValues[["Rights-Status"]]
  if (!rightsStatus %in% c("blocked", "cleared", "clean-room-required")) {
    return(release_gate_result(reason_codes = "RIGHTS_STATUS_INVALID"))
  }

  releaseLines <- release_gate_read_lines(releasePath)
  if (is.null(releaseLines)) {
    return(release_gate_result(
      reason_codes = "RELEASE_GATES_DOCUMENT_MISSING",
      parse_status = c(rights = "pass", release_gates = "fail")
    ))
  }
  release <- release_gate_single_markers(
    releaseLines,
    c("Rights-Gate-Status", "Intentional-Blockers")
  )
  if (any(vapply(release, length, integer(1)) != 1L)) {
    return(release_gate_result(
      reason_codes = "RELEASE_GATE_MARKER_CARDINALITY",
      parse_status = c(rights = "pass", release_gates = "fail")
    ))
  }
  releaseValues <- vapply(release, `[[`, character(1), 1L)
  intentionalBlockers <- trimws(strsplit(
    releaseValues[["Intentional-Blockers"]], ",", fixed = TRUE
  )[[1L]])
  intentionalBlockers <- intentionalBlockers[nzchar(intentionalBlockers)]
  if (length(intentionalBlockers) == 1L &&
      identical(toupper(intentionalBlockers), "NONE")) {
    intentionalBlockers <- character()
  }
  parsePass <- c(rights = "pass", release_gates = "pass")

  if (!identical(releaseValues[["Rights-Gate-Status"]], rightsStatus)) {
    return(release_gate_result(
      reason_codes = "RIGHTS_RELEASE_STATUS_MISMATCH",
      parse_status = parsePass,
      intentional_blockers = intentionalBlockers
    ))
  }

  requestStatus <- rightsValues[["Request-Status"]]
  if (identical(requestStatus, "superseded-by-public-response")) {
    return(release_gate_evaluate_public_domain(
      root, rightsLines, rightsValues, parsePass, intentionalBlockers
    ))
  }
  requestPath <- file.path(
    root, "docs", "provenance", "UPSTREAM-REQUEST.md"
  )
  requestLines <- release_gate_read_lines(requestPath)
  requestParseFail <- c(parsePass, request = "fail")
  if (is.null(requestLines)) {
    return(release_gate_result(
      reason_codes = "REQUEST_SCOPE_INCOMPLETE",
      parse_status = requestParseFail,
      intentional_blockers = intentionalBlockers
    ))
  }
  requestMetadata <- release_gate_single_markers(
    requestLines,
    c("Request-Document-Version", "Upstream-Repository", "Upstream-Commit")
  )
  expectedAsks <- c(
    "explicit-open-source-license",
    "modification-and-public-redistribution",
    "attributed-GEModelR-name"
  )
  requestAsks <- release_gate_marker_values(requestLines, "Request-Ask")
  metadataComplete <- all(vapply(
    requestMetadata, length, integer(1)
  ) == 1L)
  if (metadataComplete) {
    requestMetadataValues <- vapply(
      requestMetadata, `[[`, character(1), 1L
    )
    metadataComplete <- identical(
      requestMetadataValues[["Request-Document-Version"]], "1"
    ) && identical(
      requestMetadataValues[["Upstream-Repository"]],
      rightsValues[["Upstream-Repository"]]
    ) && identical(
      requestMetadataValues[["Upstream-Commit"]],
      rightsValues[["Upstream-Commit"]]
    )
  }
  scopeComplete <- metadataComplete &&
    length(requestAsks) == length(expectedAsks) &&
    identical(sort(requestAsks), sort(expectedAsks))
  if (!scopeComplete) {
    return(release_gate_result(
      reason_codes = "REQUEST_SCOPE_INCOMPLETE",
      parse_status = requestParseFail,
      intentional_blockers = intentionalBlockers
    ))
  }
  actualRequestHash <- release_gate_file_hash(requestPath)
  if (is.na(actualRequestHash) || !identical(
    actualRequestHash, rightsValues[["Request-Content-Hash"]]
  )) {
    return(release_gate_result(
      reason_codes = "REQUEST_HASH_MISMATCH",
      parse_status = requestParseFail,
      intentional_blockers = intentionalBlockers
    ))
  }
  requestStatus <- rightsValues[["Request-Status"]]
  allowedRequestStatuses <- c(
    "draft", "reviewed-unposted", "posted-pending",
    "response-received-review-pending", "resolved"
  )
  if (!requestStatus %in% allowedRequestStatuses) {
    return(release_gate_result(
      reason_codes = "REQUEST_STATUS_INVALID",
      parse_status = requestParseFail,
      intentional_blockers = intentionalBlockers
    ))
  }
  unpostedRequest <- requestStatus %in% c(
    "draft", "reviewed-unposted"
  )
  if (unpostedRequest) {
    postingEvidenceComplete <- identical(
      rightsValues[["Request-URL"]], "not-posted"
    ) && identical(
      rightsValues[["Request-Date-UTC"]], "not-posted"
    )
    requestBlocker <- "REQUEST_NOT_POSTED"
  } else {
    postingEvidenceComplete <- grepl(
      "^https://", rightsValues[["Request-URL"]]
    ) && grepl(
      "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
      rightsValues[["Request-Date-UTC"]]
    )
    requestBlocker <- if (identical(requestStatus, "resolved")) {
      character()
    } else {
      "REQUEST_NOT_A_GRANT"
    }
  }
  if (!postingEvidenceComplete) {
    return(release_gate_result(
      reason_codes = "REQUEST_NOT_POSTED",
      parse_status = requestParseFail,
      intentional_blockers = intentionalBlockers
    ))
  }
  parsePass <- c(parsePass, request = "pass")

  if (identical(rightsStatus, "blocked")) {
    if (!length(requestBlocker)) requestBlocker <- "REQUEST_NOT_A_GRANT"
    blockedReasons <- c("RIGHTS_BLOCKED", requestBlocker)
    if (!identical(intentionalBlockers, blockedReasons)) {
      return(release_gate_result(
        reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
        parse_status = parsePass,
        intentional_blockers = intentionalBlockers
      ))
    }
    return(release_gate_result(
      repository_state = "blocked",
      reason_codes = blockedReasons,
      parse_status = parsePass,
      intentional_blockers = intentionalBlockers
    ))
  }

  if (length(requestBlocker)) {
    return(release_gate_result(
      reason_codes = requestBlocker,
      parse_status = parsePass,
      intentional_blockers = intentionalBlockers
    ))
  }

  if (identical(rightsStatus, "cleared")) {
    coveredCommit <- release_gate_marker_values(
      rightsLines, "Covered-Upstream-Commit"
    )
    coveredComponents <- release_gate_marker_values(
      rightsLines, "Covered-Components"
    )
    scopeComplete <- length(coveredCommit) == 1L &&
      identical(coveredCommit[[1L]], rightsValues[["Upstream-Commit"]]) &&
      length(coveredComponents) == 1L &&
      "inherited-source" %in% trimws(strsplit(
        coveredComponents[[1L]], ",", fixed = TRUE
      )[[1L]])
    if (!scopeComplete) {
      return(release_gate_result(
        reason_codes = "RIGHTS_SCOPE_INCOMPLETE",
        parse_status = parsePass,
        intentional_blockers = intentionalBlockers
      ))
    }
    clearanceComplete <- identical(
      rightsValues[["Request-Status"]], "resolved"
    ) && grepl("^https://", rightsValues[["Request-URL"]]) &&
      grepl("^[0-9a-f]{32,64}$", rightsValues[["Evidence-Hash"]]) &&
      identical(
        grepl("^pending", rightsValues[["Reviewer"]], ignore.case = TRUE),
        FALSE
      ) && grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
        rightsValues[["Review-Date-UTC"]]
      )
    if (!clearanceComplete) {
      return(release_gate_result(
        reason_codes = "RIGHTS_EVIDENCE_INCOMPLETE",
        parse_status = parsePass,
        intentional_blockers = intentionalBlockers
      ))
    }
    if (length(intentionalBlockers)) {
      return(release_gate_result(
        reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
        parse_status = parsePass,
        intentional_blockers = intentionalBlockers
      ))
    }
    return(release_gate_result(
      repository_state = "eligible",
      release_ready = TRUE,
      reason_codes = character(),
      parse_status = parsePass,
      intentional_blockers = intentionalBlockers
    ))
  }

  cleanroomPath <- file.path(root, "docs", "provenance", "CLEANROOM.md")
  cleanroomLines <- release_gate_read_lines(cleanroomPath)
  release_gate_evaluate_cleanroom(
    root, cleanroomLines, parsePass, intentionalBlockers
  )
}



release_gate_evaluate_rights = release_gate_evaluate

release_gate_markdown_table = function(lines, heading) {
  start = which(trimws(lines) == heading)
  if (length(start) != 1L) return(NULL)
  following = seq.int(start + 1L, length(lines))
  nextHeading = following[grepl("^##[[:space:]]", lines[following])]
  end = if (length(nextHeading)) nextHeading[[1L]] - 1L else length(lines)
  tableLines = lines[seq.int(start + 1L, end)]
  tableLines = tableLines[grepl("^\\|", trimws(tableLines))]
  if (length(tableLines) < 2L) return(NULL)
  cells = lapply(tableLines, function(line) {
    trimws(strsplit(sub("\\|$", "", sub("^\\|", "", trimws(line))),
                    "\\|")[[1L]])
  })
  header = cells[[1L]]
  body = cells[-c(1L, 2L)]
  if (!length(body)) {
    result = as.data.frame(setNames(
      replicate(length(header), character(), simplify = FALSE),
      header
    ), stringsAsFactors = FALSE)
    return(result)
  }
  if (any(lengths(body) != length(header))) return(NULL)
  result = as.data.frame(do.call(rbind, body), stringsAsFactors = FALSE)
  names(result) = header
  result
}

release_gate_integrated_failure = function(reason, parseStatus, stream) {
  parseStatus[[stream]] = "fail"
  release_gate_result(reason_codes = reason, parse_status = parseStatus)
}

release_gate_validate_provenance = function(root, parseStatus) {
  expectedPath = file.path(root, "docs", "provenance", "EXPECTED-KEYS.csv")
  inventoryPath = file.path(root, "docs", "provenance", "PROVENANCE.csv")
  if (!file.exists(expectedPath) || !file.exists(inventoryPath)) {
    return(list(error = release_gate_integrated_failure(
      "PROVENANCE_EVIDENCE_MISSING", parseStatus, "provenance"
    )))
  }
  expectedRows = tryCatch(read.csv(expectedPath, stringsAsFactors = FALSE), error = function(error) NULL)
  expected = if (is.null(expectedRows) || !identical(names(expectedRows), c("path", "symbol"))) character() else paste(expectedRows$path, expectedRows$symbol, sep = "::")
  if (!length(expected) || anyDuplicated(expected)) {
    return(list(error = release_gate_integrated_failure(
      "PROVENANCE_KEY_MISMATCH", parseStatus, "provenance"
    )))
  }
  inventory = tryCatch(
    read.csv(inventoryPath, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(error) NULL
  )
  columns = c(
    "path", "symbol", "language", "classification",
    "upstream_repository", "upstream_commit", "upstream_path",
    "first_local_commit", "expression_hash", "contributors",
    "copyright_holder", "license_basis", "evidence", "reviewer",
    "review_date", "status", "notes"
  )
  if (is.null(inventory) || !identical(names(inventory), columns)) {
    return(list(error = release_gate_integrated_failure(
      "PROVENANCE_COLUMNS_MISSING", parseStatus, "provenance"
    )))
  }
  artifactKeys = paste(inventory$path, inventory$symbol, sep = "::")
  if (anyDuplicated(artifactKeys)) {
    return(list(error = release_gate_integrated_failure(
      "PROVENANCE_DUPLICATE_KEY", parseStatus, "provenance"
    )))
  }
  if (!identical(sort(artifactKeys), sort(expected))) {
    return(list(error = release_gate_integrated_failure(
      "PROVENANCE_KEY_MISMATCH", parseStatus, "provenance"
    )))
  }
  blocking = !grepl("^reviewed", inventory$status) |
    !inventory$classification %in% c(
      "inherited-identical", "inherited-modified", "new-independent",
      "generated"
    ) |
    !nzchar(inventory$license_basis) |
    !nzchar(inventory$reviewer) |
    !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", inventory$review_date)
  if (any(blocking)) {
    return(list(error = release_gate_integrated_failure(
      "PROVENANCE_ROW_BLOCKING", parseStatus, "provenance"
    )))
  }
  parseStatus[["provenance"]] = "pass"
  list(
    parse_status = parseStatus,
    inventory = inventory,
    inventory_path = inventoryPath,
    artifact_keys = artifactKeys
  )
}


release_gate_load_tool = function(path, symbol_names) {
  if (!file.exists(path)) {
    stop("PROVENANCE_TOOL_MISSING", call. = FALSE)
  }
  environment = new.env(parent = baseenv())
  loaded = tryCatch(
    {
      sys.source(path, envir = environment)
      TRUE
    },
    error = function(error) FALSE
  )
  if (!loaded ||
      any(!vapply(symbol_names, exists, logical(1),
                  envir = environment, inherits = FALSE))) {
    stop("PROVENANCE_TOOL_LOAD_FAILED", call. = FALSE)
  }
  result = lapply(symbol_names, get, envir = environment, inherits = FALSE)
  names(result) = symbol_names
  result
}

release_gate_provenance_reason = function(error) {
  code = strsplit(conditionMessage(error), "[[:space:]]+")[[1L]][[1L]]
  mapped = c(
    PROVENANCE_SOURCE_EMPTY = "PROVENANCE_SOURCE_MISSING",
    PROVENANCE_R_PARSE_FAILED = "PROVENANCE_SOURCE_EXTRACTION_FAILED",
    PROVENANCE_GIT_UNAVAILABLE = "PROVENANCE_GIT_EVIDENCE_MISSING",
    PROVENANCE_FILE_MISSING = "PROVENANCE_EVIDENCE_MISSING"
  )
  if (code %in% names(mapped)) return(unname(mapped[[code]]))
  allowed = c(
    "PROVENANCE_TOOL_MISSING", "PROVENANCE_TOOL_LOAD_FAILED",
    "PROVENANCE_EVIDENCE_MISSING", "PROVENANCE_CSV_INVALID",
    "PROVENANCE_COLUMNS_MISSING", "PROVENANCE_DUPLICATE_KEY",
    "PROVENANCE_KEY_MISMATCH", "PROVENANCE_ROW_BLOCKING"
  )
  if (code %in% allowed) code else "PROVENANCE_SOURCE_VALIDATION_FAILED"
}

release_gate_validate_current_source = function(root, parseStatus) {
  fail = function(reason) {
    list(error = release_gate_integrated_failure(
      reason, parseStatus, "provenance"
    ))
  }
  toolPath = file.path(root, "tools", "provenance_inventory.R")
  symbols = c(
    "provenance_columns", "provenance_collect_sources",
    "provenance_read_csv", "provenance_validate_ledger",
    "provenance_key_frame"
  )
  tool = tryCatch(
    release_gate_load_tool(toolPath, symbols),
    error = function(error) error
  )
  if (inherits(tool, "error")) {
    return(fail(release_gate_provenance_reason(tool)))
  }

  expectedPath = file.path(root, "docs", "provenance", "EXPECTED-KEYS.csv")
  ledgerPath = file.path(root, "docs", "provenance", "PROVENANCE.csv")
  validated = tryCatch(
    {
      expected = tool$provenance_read_csv(
        expectedPath, c("path", "symbol")
      )
      ledger = tool$provenance_read_csv(
        ledgerPath, tool$provenance_columns
      )
      inventory = tool$provenance_collect_sources(
        root, include_git = TRUE
      )
      tool$provenance_validate_ledger(ledger, expected, inventory)
      list(expected = expected, ledger = ledger, inventory = inventory)
    },
    error = function(error) error
  )
  if (inherits(validated, "error")) {
    return(fail(release_gate_provenance_reason(validated)))
  }

  parseStatus[["provenance"]] = "pass"
  list(
    parse_status = parseStatus,
    inventory = validated$ledger,
    current_inventory = validated$inventory,
    inventory_path = ledgerPath,
    artifact_keys = tool$provenance_key_frame(validated$ledger)
  )
}

release_gate_validate_cleanroom_provenance = function(
    base, provenance, parseStatus) {
  components = base$cleanroom_components
  if (is.null(components) || !length(components)) {
    return(list(parse_status = parseStatus))
  }
  fail = function() {
    list(error = release_gate_integrated_failure(
      "CLEANROOM_EVIDENCE_INCOMPLETE", parseStatus, "cleanroom"
    ))
  }
  componentKeys = vapply(
    components, function(component) component$values[["provenance_key"]],
    character(1)
  )
  componentPaths = vapply(
    components, function(component) {
      gsub("\\", "/", component$values[["replacement_source"]], fixed = TRUE)
    },
    character(1)
  )
  ledger = provenance$inventory
  ledgerKeys = paste(ledger$path, ledger$symbol, sep = "::")
  inherited = ledger$classification %in%
    c("inherited-identical", "inherited-modified")
  matched = match(componentKeys, ledgerKeys)
  valid = identical(
    sort(componentKeys), sort(base$cleanroom_inherited_keys)
  ) &&
    !anyDuplicated(componentKeys) &&
    !any(is.na(matched)) &&
    !any(inherited) &&
    all(ledger$classification[matched] == "new-independent") &&
    identical(unname(ledger$path[matched]), unname(componentPaths))
  if (!valid) return(fail())
  parseStatus[["cleanroom"]] = "pass"
  list(parse_status = parseStatus)
}

release_gate_review_date_valid = function(values) {
  vapply(values, function(value) {
    if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", value)) {
      return(FALSE)
    }
    parsed = as.Date(value, format = "%Y-%m-%d")
    !is.na(parsed) && identical(
      format(parsed, "%Y-%m-%d"), value
    )
  }, logical(1))
}

release_gate_validate_attribution = function(
    root, rightsValues, provenance, parseStatus) {
  path = file.path(root, "docs", "provenance", "ATTRIBUTION.md")
  lines = release_gate_read_lines(path)
  if (is.null(lines)) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_EVIDENCE_MISSING", parseStatus, "attribution"
    )))
  }
  fields = c(
    "Attribution-Schema-Version", "Inventory-Path", "Inventory-Row-Count",
    "Inventory-Snapshot-MD5", "Upstream-Repository", "Upstream-Commit",
    "Reviewer", "Review-Date"
  )
  markers = release_gate_single_markers(lines, fields)
  if (any(vapply(markers, length, integer(1)) != 1L)) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_EVIDENCE_MISSING", parseStatus, "attribution"
    )))
  }
  values = vapply(markers, `[[`, character(1), 1L)
  metadataMatches = identical(
    values[["Attribution-Schema-Version"]], "1"
  ) && identical(
    values[["Inventory-Path"]], "docs/provenance/PROVENANCE.csv"
  ) && identical(
    suppressWarnings(as.integer(values[["Inventory-Row-Count"]])),
    nrow(provenance$inventory)
  ) && identical(
    values[["Inventory-Snapshot-MD5"]],
    unname(tools::md5sum(provenance$inventory_path)[[1L]])
  ) && identical(
    values[["Upstream-Repository"]],
    rightsValues[["Upstream-Repository"]]
  ) && identical(
    values[["Upstream-Commit"]], rightsValues[["Upstream-Commit"]]
  ) && identical(values[["Reviewer"]], "David Zenz") &&
    release_gate_review_date_valid(values[["Review-Date"]])
  if (!metadataMatches) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_DESTINATION_MISMATCH", parseStatus, "attribution"
    )))
  }
  roles = release_gate_markdown_table(lines, "## Reviewed role assignments")
  blockers = release_gate_markdown_table(lines, "## Blocking facts")
  roleColumns = c(
    "person/entity", "role", "evidence_keys", "rights_basis", "destination",
    "reviewer", "review_date", "status"
  )
  blockerColumns = c(
    "fact", "evidence_key", "destination", "reason", "reviewer",
    "review_date", "status"
  )
  if (is.null(roles) || is.null(blockers) ||
      !identical(names(roles), roleColumns) ||
      !identical(names(blockers), blockerColumns) ||
      !nrow(roles) ||
      any(!nzchar(as.matrix(roles))) ||
      any(!nzchar(as.matrix(blockers))) ||
      any(!roles$role %in% c("aut", "ctb", "cph", "cre")) ||
      any(roles$status != "reviewed") ||
      any(roles$reviewer != "David Zenz") ||
      any(!release_gate_review_date_valid(roles$review_date)) ||
      any(blockers$status != "blocking") ||
      any(blockers$reviewer != "David Zenz") ||
      any(!release_gate_review_date_valid(blockers$review_date)) ||
      !all(c("David Zenz", "Maros Ivanic") %in% roles[["person/entity"]])) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_ROLE_UNREVIEWED", parseStatus, "attribution"
    )))
  }
  evidenceKeys = unique(trimws(unlist(strsplit(
    roles$evidence_keys, ";", fixed = TRUE
  ))))
  if (!all(evidenceKeys %in% provenance$artifact_keys)) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_EVIDENCE_MISSING", parseStatus, "attribution"
    )))
  }
  if (any(!blockers$evidence_key %in% provenance$artifact_keys)) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_EVIDENCE_MISSING", parseStatus, "attribution"
    )))
  }
  blockingRows = blockers$status == "blocking"
  blockingReasons = blockers$reason[blockingRows]
  if (any(!nzchar(blockingReasons)) || anyDuplicated(blockingReasons)) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_BLOCKER_INVALID", parseStatus, "attribution"
    )))
  }
  parseStatus[["attribution"]] = "pass"
  list(
    parse_status = parseStatus, blockers = blockingReasons, roles = roles
  )
}

release_gate_attribution_destination_paths = function(root) {
  c(
    DESCRIPTION = file.path(root, "DESCRIPTION"),
    README = file.path(root, "README.md"),
    CITATION = file.path(root, "inst", "CITATION"),
    CONTRIBUTORS = file.path(root, "CONTRIBUTORS.md"),
    PROVENANCE = file.path(
      root, "docs", "provenance", "PROVENANCE.csv"
    ),
    NEWS = file.path(root, "NEWS.md")
  )
}

release_gate_validate_attribution_destination_presence = function(
    root, parseStatus) {
  paths = release_gate_attribution_destination_paths(root)
  if (!all(file.exists(paths))) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_DESTINATION_MISSING",
      parseStatus, "attribution_destinations"
    )))
  }
  list(parse_status = parseStatus, paths = paths)
}

release_gate_attribution_role_markers = function(lines) {
  values = release_gate_marker_values(lines, "Attribution-Role")
  if (!length(values)) return(NULL)
  parts = strsplit(values, "|", fixed = TRUE)
  if (any(lengths(parts) != 2L)) return(NULL)
  people = vapply(parts, `[[`, character(1), 1L)
  roles = lapply(parts, function(value) {
    sort(unique(trimws(strsplit(value[[2L]], ",", fixed = TRUE)[[1L]])))
  })
  if (any(!nzchar(people)) || anyDuplicated(people) ||
      any(!lengths(roles))) {
    return(NULL)
  }
  names(roles) = people
  roles
}

release_gate_validate_attribution_destinations = function(
    root, attribution, provenance, parseStatus) {
  presence = release_gate_validate_attribution_destination_presence(
    root, parseStatus
  )
  if (!is.null(presence$error)) return(presence)
  paths = presence$paths
  lines = lapply(paths, release_gate_read_lines)
  if (any(vapply(lines, is.null, logical(1)))) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_DESTINATION_MISSING",
      parseStatus, "attribution_destinations"
    )))
  }

  evidence = unique(trimws(unlist(strsplit(
    attribution$roles$evidence_keys, ";", fixed = TRUE
  ))))
  people = unique(attribution$roles[["person/entity"]])
  content = vapply(lines, paste, collapse = "\n", character(1))
  content[["PROVENANCE"]] = paste(
    paste(
      provenance$inventory$path, provenance$inventory$symbol, sep = "::"
    ),
    provenance$inventory$contributors,
    provenance$inventory$copyright_holder,
    provenance$inventory$license_basis,
    collapse = "\n"
  )
  complete = vapply(content, function(value) {
    all(vapply(evidence, grepl, logical(1), x = value, fixed = TRUE)) &&
      all(vapply(people, grepl, logical(1), x = value, fixed = TRUE))
  }, logical(1))
  if (!all(complete)) {
    return(list(error = release_gate_integrated_failure(
      "ATTRIBUTION_DESTINATION_MISMATCH",
      parseStatus, "attribution_destinations"
    )))
  }

  ledgerKeys = paste(
    provenance$inventory$path, provenance$inventory$symbol, sep = "::"
  )
  for (index in seq_len(nrow(attribution$roles))) {
    roleKeys = trimws(strsplit(
      attribution$roles$evidence_keys[[index]], ";", fixed = TRUE
    )[[1L]])
    person = attribution$roles[["person/entity"]][[index]]
    role = attribution$roles$role[[index]]
    rows = match(roleKeys, ledgerKeys)
    credited = vapply(rows, function(row) {
      field = if (identical(role, "cph")) {
        "copyright_holder"
      } else {
        "contributors"
      }
      grepl(person, provenance$inventory[[field]][[row]], fixed = TRUE)
    }, logical(1))
    if (anyNA(rows) || !all(credited)) {
      return(list(error = release_gate_integrated_failure(
        "ATTRIBUTION_DESTINATION_MISMATCH",
        parseStatus, "attribution_destinations"
      )))
    }
  }

  expectedRoles = split(
    attribution$roles$role, attribution$roles[["person/entity"]]
  )
  expectedRoles = lapply(expectedRoles, function(value) {
    sort(unique(value))
  })
  for (destination in c("CONTRIBUTORS", "NEWS")) {
    actualRoles = release_gate_attribution_role_markers(
      lines[[destination]]
    )
    if (is.null(actualRoles) ||
        !identical(actualRoles[sort(names(actualRoles))],
                   expectedRoles[sort(names(expectedRoles))])) {
      return(list(error = release_gate_integrated_failure(
        "ATTRIBUTION_DESTINATION_MISMATCH",
        parseStatus, "attribution_destinations"
      )))
    }
  }
  parseStatus[["attribution_destinations"]] = "pass"
  list(parse_status = parseStatus)
}


release_gate_validate_name = function(root, parseStatus) {
  path = file.path(root, "docs", "release", "NAME-CHECK.md")
  toolPath = file.path(root, "tools", "check_name_availability.R")
  tool = tryCatch(
    release_gate_load_tool(toolPath, "name_check_verify_report"),
    error = function(error) error
  )
  if (inherits(tool, "error")) {
    return(list(error = release_gate_integrated_failure(
      "NAME_TOOL_LOAD_FAILED", parseStatus, "name"
    )))
  }
  verified = tryCatch(
    {
      tool$name_check_verify_report(path, require_review = TRUE)
      TRUE
    },
    error = function(error) FALSE
  )
  if (!verified) {
    return(list(error = release_gate_integrated_failure(
      "NAME_REPORT_INVALID", parseStatus, "name"
    )))
  }

  lines = release_gate_read_lines(path)
  fields = c(
    "Name", "Check-Kind", "Checked-At-UTC", "Overall-Result",
    "Reviewer", "Review-Date-UTC"
  )
  markers = release_gate_single_markers(lines, fields)
  values = vapply(markers, `[[`, character(1), 1L)
  approved = identical(values[["Name"]], "GEModelR") &&
    values[["Check-Kind"]] %in% c("initial", "reservation", "release") &&
    identical(
      values[["Overall-Result"]], "NAME_AVAILABLE_NO_EXACT_COLLISION"
    ) &&
    identical(values[["Reviewer"]], "David Zenz")
  if (!approved) {
    return(list(error = release_gate_integrated_failure(
      "NAME_REPORT_INVALID", parseStatus, "name"
    )))
  }
  parseStatus[["name"]] = "pass"
  list(
    parse_status = parseStatus,
    check_kind = values[["Check-Kind"]],
    checked_at = values[["Checked-At-UTC"]]
  )
}

release_gate_validate_governance = function(root, parseStatus) {
  path = file.path(root, "GOVERNANCE.md")
  lines = release_gate_read_lines(path)
  fields = c(
    "Maintainer", "Approved-Contact", "Release-Authority",
    "Security-Route", "Identity-Approval", "Reviewer", "Review-Date-UTC"
  )
  if (is.null(lines)) {
    return(list(error = release_gate_integrated_failure(
      "GOVERNANCE_IDENTITY_UNAPPROVED", parseStatus, "governance"
    )))
  }
  markers = release_gate_single_markers(lines, fields)
  if (any(vapply(markers, length, integer(1)) != 1L)) {
    return(list(error = release_gate_integrated_failure(
      "GOVERNANCE_IDENTITY_UNAPPROVED", parseStatus, "governance"
    )))
  }
  values = vapply(markers, `[[`, character(1), 1L)
  identity = identical(values[["Maintainer"]], "David Zenz") &&
    identical(values[["Approved-Contact"]], "zenz@wiiw.ac.at") &&
    identical(values[["Release-Authority"]], "David Zenz") &&
    identical(values[["Identity-Approval"]], "approved") &&
    identical(values[["Reviewer"]], "David Zenz") &&
    grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
          values[["Review-Date-UTC"]])
  if (!identity) {
    return(list(error = release_gate_integrated_failure(
      "GOVERNANCE_IDENTITY_UNAPPROVED", parseStatus, "governance"
    )))
  }
  if (!identical(
    values[["Security-Route"]], "mailto:zenz@wiiw.ac.at"
  )) {
    return(list(error = release_gate_integrated_failure(
      "GOVERNANCE_SECURITY_ROUTE_MISSING", parseStatus, "governance"
    )))
  }
  parseStatus[["governance"]] = "pass"
  list(parse_status = parseStatus, values = values)
}


release_gate_validate_repository = function(
    root, governance, parseStatus) {
  path = file.path(root, "docs", "release", "REPOSITORY.md")
  lines = release_gate_read_lines(path)
  fields = c(
    "Owner-Slug", "Repository-Name", "Canonical-URL", "Issue-Tracker",
    "Visibility-Boundary", "Identity-Approval", "Reviewer",
    "Review-Date-UTC", "Reservation-Authorization",
    "Visibility-Detachment-Authorization", "Branch-Settings-Authorization",
    "Release-Authorization"
  )
  if (is.null(lines)) {
    return(list(error = release_gate_integrated_failure(
      "REPOSITORY_URL_MISMATCH", parseStatus, "repository"
    )))
  }
  markers = release_gate_single_markers(lines, fields)
  if (any(vapply(markers, length, integer(1)) != 1L)) {
    return(list(error = release_gate_integrated_failure(
      "REPOSITORY_URL_MISMATCH", parseStatus, "repository"
    )))
  }
  values = vapply(markers, `[[`, character(1), 1L)
  if (!identical(values[["Owner-Slug"]], "DavidZenz") ||
      !identical(values[["Repository-Name"]], "GEModelR") ||
      !identical(
        values[["Canonical-URL"]], "https://github.com/DavidZenz/GEModelR"
      )) {
    return(list(error = release_gate_integrated_failure(
      "REPOSITORY_URL_MISMATCH", parseStatus, "repository"
    )))
  }
  if (!identical(
    values[["Issue-Tracker"]],
    "https://github.com/DavidZenz/GEModelR/issues"
  )) {
    return(list(error = release_gate_integrated_failure(
      "REPOSITORY_ISSUES_MISMATCH", parseStatus, "repository"
    )))
  }
  boundaryFields = c(
    "Reservation-Authorization", "Visibility-Detachment-Authorization",
    "Branch-Settings-Authorization", "Release-Authorization"
  )
  boundary = identical(
    values[["Visibility-Boundary"]], "private-development"
  ) && identical(values[["Identity-Approval"]], "approved") &&
    identical(values[["Reviewer"]], governance[["Reviewer"]]) &&
    identical(
      values[["Review-Date-UTC"]], governance[["Review-Date-UTC"]]
    ) && all(values[boundaryFields] == "not-authorized")
  if (!boundary) {
    return(list(error = release_gate_integrated_failure(
      "REPOSITORY_BOUNDARY_INVALID", parseStatus, "repository"
    )))
  }
  parseStatus[["repository"]] = "pass"
  list(parse_status = parseStatus, values = values)
}

release_gate_release_check_fresh = function(nameEvidence) {
  if (!identical(nameEvidence$check_kind, "release")) return(FALSE)
  checked = as.POSIXct(
    nameEvidence$checked_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  age = difftime(Sys.time(), checked, units = "hours")
  !is.na(checked) && age <= 24 && age >= 0
}


release_gate_evaluate = function(root = ".") {
  root = normalizePath(root, mustWork = TRUE)
  rightsPath = file.path(root, "docs", "provenance", "RIGHTS.md")
  rightsLines = release_gate_read_lines(rightsPath)
  integratedVersion = if (is.null(rightsLines)) character() else
    release_gate_marker_values(rightsLines, "Integrated-Evidence-Version")
  if (length(integratedVersion) != 1L ||
      !identical(integratedVersion[[1L]], "1")) {
    return(release_gate_result(
      reason_codes = "INTEGRATED_EVIDENCE_VERSION_INVALID",
      parse_status = c(integrated = "fail")
    ))
  }
  base = release_gate_evaluate_rights(root)
  if (!identical(base$repository_state, "eligible")) return(base)

  requiredRights = c(
    "Rights-Status", "Upstream-Repository", "Upstream-Commit",
    "Request-Status", "Request-URL", "Request-Date-UTC",
    "Request-Content-Hash", "Evidence-Hash", "Reviewer",
    "Review-Date-UTC"
  )
  rights = release_gate_single_markers(rightsLines, requiredRights)
  rightsValues = vapply(rights, `[[`, character(1), 1L)
  parseStatus = c(
    base$parse_status[names(base$parse_status) != "provenance_coverage"],
    integrated = "pass"
  )

  destinationPresence =
    release_gate_validate_attribution_destination_presence(
      root, parseStatus
    )
  if (!is.null(destinationPresence$error)) {
    return(destinationPresence$error)
  }
  provenance = release_gate_validate_current_source(
    root, destinationPresence$parse_status
  )
  if (!is.null(provenance$error)) return(provenance$error)
  cleanroomProvenance = release_gate_validate_cleanroom_provenance(
    base, provenance, provenance$parse_status
  )
  if (!is.null(cleanroomProvenance$error)) {
    return(cleanroomProvenance$error)
  }
  provenance$parse_status = cleanroomProvenance$parse_status
  attribution = release_gate_validate_attribution(
    root, rightsValues, provenance, provenance$parse_status
  )
  if (!is.null(attribution$error)) return(attribution$error)
  destinations = release_gate_validate_attribution_destinations(
    root, attribution, provenance, attribution$parse_status
  )
  if (!is.null(destinations$error)) return(destinations$error)
  nameEvidence = release_gate_validate_name(root, destinations$parse_status)
  if (!is.null(nameEvidence$error)) return(nameEvidence$error)
  governance = release_gate_validate_governance(
    root, nameEvidence$parse_status
  )
  if (!is.null(governance$error)) return(governance$error)
  repository = release_gate_validate_repository(
    root, governance$values, governance$parse_status
  )
  if (!is.null(repository$error)) return(repository$error)
  description = release_gate_validate_description(
    root, governance$values, repository$values, attribution$blockers,
    repository$parse_status
  )
  if (!is.null(description$error)) return(description$error)
  license = release_gate_validate_license_decision(
    root, attribution$blockers, description$parse_status
  )
  if (!is.null(license$error)) return(license$error)

  rightsBlockers = release_gate_marker_values(
    rightsLines, "Unresolved-Release-Blocker"
  )
  rightsBlockers = rightsBlockers[rightsBlockers != "NONE"]
  blockers = attribution$blockers
  if (!identical(base$intentional_blockers, blockers) ||
      !identical(rightsBlockers, blockers)) {
    return(release_gate_result(
      reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
      parse_status = license$parse_status,
      intentional_blockers = base$intentional_blockers
    ))
  }
  if (length(blockers)) {
    return(release_gate_result(
      repository_state = "blocked",
      release_ready = FALSE,
      reason_codes = blockers,
      parse_status = license$parse_status,
      intentional_blockers = base$intentional_blockers
    ))
  }
  if (!release_gate_release_check_fresh(nameEvidence)) {
    return(release_gate_result(
      reason_codes = "NAME_REPORT_STALE",
      parse_status = license$parse_status,
      intentional_blockers = base$intentional_blockers
    ))
  }
  release_gate_result(
    repository_state = "eligible",
    release_ready = TRUE,
    reason_codes = character(),
    parse_status = license$parse_status,
    intentional_blockers = character()
  )
}


release_gate_validate_description = function(
    root, governance, repository, blockers, parseStatus) {
  path = file.path(root, "DESCRIPTION")
  description = tryCatch(
    read.dcf(path),
    error = function(error) NULL
  )
  required = c(
    "Package", "Authors@R", "Maintainer", "License", "URL", "BugReports"
  )
  if (is.null(description) ||
      !all(required %in% colnames(description))) {
    return(list(error = release_gate_integrated_failure(
      "DESCRIPTION_IDENTITY_MISMATCH", parseStatus, "description"
    )))
  }
  value = function(field) unname(description[[1L, field]])
  expectedMaintainer = paste0(
    governance[["Maintainer"]], " <", governance[["Approved-Contact"]], ">"
  )
  authors = value("Authors@R")
  identity = identical(value("Package"), "tabloToR") &&
    identical(value("Maintainer"), expectedMaintainer) &&
    grepl("person(\"David\", \"Zenz\"", authors, fixed = TRUE) &&
    grepl("email = \"zenz@wiiw.ac.at\"", authors, fixed = TRUE) &&
    grepl("role = c(\"aut\", \"cre\", \"cph\")", authors, fixed = TRUE)
  if (!identity) {
    return(list(error = release_gate_integrated_failure(
      "DESCRIPTION_IDENTITY_MISMATCH", parseStatus, "description"
    )))
  }
  if (!identical(value("URL"), repository[["Canonical-URL"]])) {
    return(list(error = release_gate_integrated_failure(
      "DESCRIPTION_URL_MISMATCH", parseStatus, "description"
    )))
  }
  if (!identical(value("BugReports"), repository[["Issue-Tracker"]])) {
    return(list(error = release_gate_integrated_failure(
      "DESCRIPTION_ISSUES_MISMATCH", parseStatus, "description"
    )))
  }
  parseStatus[["description"]] = "pass"
  list(parse_status = parseStatus)
}

release_gate_validate_license_expression = function(expression, root) {
  if (!is.character(expression) || length(expression) != 1L ||
      !nzchar(trimws(expression)) || grepl("[\r\n]", expression)) {
    return(FALSE)
  }
  checker = tryCatch(
    getFromNamespace(".check_package_license", "tools"),
    error = function(error) NULL
  )
  if (!is.function(checker)) return(FALSE)
  dcf = tempfile("release-gate-license-", fileext = ".dcf")
  on.exit(unlink(dcf), add = TRUE)
  values = matrix(
    c("releasegatefixture", expression), nrow = 1L,
    dimnames = list(NULL, c("Package", "License"))
  )
  checked = tryCatch(
    {
      write.dcf(values, dcf)
      checker(dcf, dir = root)
    },
    error = function(error) NULL
  )
  !is.null(checked) && length(checked) == 0L
}

release_gate_license_review_date_valid = function(value) {
  if (!grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
    value
  )) {
    return(FALSE)
  }
  parsed = as.POSIXct(
    value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  !is.na(parsed) && identical(
    format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), value
  )
}

release_gate_validate_license_decision = function(
    root, blockers, parseStatus) {
  fail = function(reason) {
    list(error = release_gate_integrated_failure(
      reason, parseStatus, "license"
    ))
  }
  path = file.path(root, "docs", "provenance", "LICENSE-DECISION.md")
  lines = release_gate_read_lines(path)
  if (is.null(lines)) return(fail("LICENSE_DECISION_MISSING"))
  fields = c(
    "License-Decision-Version", "Decision-Status",
    "Description-License", "Dependency-Audit-Artifact",
    "Dependency-Audit-MD5", "Reviewer", "Review-Date-UTC"
  )
  markers = release_gate_single_markers(lines, fields)
  if (any(vapply(markers, length, integer(1)) != 1L)) {
    return(fail("LICENSE_DECISION_INVALID"))
  }
  values = vapply(markers, `[[`, character(1), 1L)
  if (any(!nzchar(trimws(values))) ||
      !identical(values[["License-Decision-Version"]], "1")) {
    return(fail("LICENSE_DECISION_INVALID"))
  }

  description = tryCatch(
    read.dcf(file.path(root, "DESCRIPTION")),
    error = function(error) NULL
  )
  if (is.null(description) ||
      !"License" %in% colnames(description)) {
    return(fail("DESCRIPTION_LICENSE_MISMATCH"))
  }
  descriptionLicense = unname(description[[1L, "License"]])
  dependencyBlocked =
    "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING" %in% blockers

  if (identical(values[["Decision-Status"]], "pending")) {
    pending = c(
      "License-Decision-Version" = "1",
      "Decision-Status" = "pending",
      "Description-License" = "What license is it under?",
      "Dependency-Audit-Artifact" = "pending",
      "Dependency-Audit-MD5" = "pending",
      "Reviewer" = "pending",
      "Review-Date-UTC" = "pending"
    )
    if (!identical(values, pending) ||
        !identical(descriptionLicense, pending[["Description-License"]])) {
      return(fail("LICENSE_DECISION_INVALID"))
    }
    if (!dependencyBlocked) return(fail("LICENSE_DECISION_PENDING"))
    parseStatus[["license"]] = "pass"
    return(list(parse_status = parseStatus, values = values))
  }
  if (!identical(values[["Decision-Status"]], "reviewed")) {
    return(fail("LICENSE_DECISION_INVALID"))
  }
  if (dependencyBlocked) return(fail("LICENSE_BLOCKER_MISMATCH"))
  if (identical(values[["Reviewer"]], "pending") ||
      !nzchar(trimws(values[["Reviewer"]])) ||
      !release_gate_license_review_date_valid(
        values[["Review-Date-UTC"]]
      )) {
    return(fail("LICENSE_DECISION_UNREVIEWED"))
  }
  if (!identical(
    descriptionLicense, values[["Description-License"]]
  )) {
    return(fail("DESCRIPTION_LICENSE_MISMATCH"))
  }

  artifact = values[["Dependency-Audit-Artifact"]]
  normalizedArtifact = gsub("\\\\", "/", artifact)
  components = strsplit(normalizedArtifact, "/", fixed = TRUE)[[1L]]
  if (startsWith(normalizedArtifact, "/") ||
      grepl("^[A-Za-z]:", normalizedArtifact) ||
      any(components %in% c("", ".", ".."))) {
    return(fail("LICENSE_DEPENDENCY_AUDIT_PATH_INVALID"))
  }
  artifactPath = file.path(root, normalizedArtifact)
  if (!file.exists(artifactPath)) {
    return(fail("LICENSE_DEPENDENCY_AUDIT_MISSING"))
  }
  rootPath = normalizePath(root, mustWork = TRUE)
  resolvedArtifact = normalizePath(artifactPath, mustWork = TRUE)
  if (!startsWith(
    resolvedArtifact, paste0(rootPath, .Platform$file.sep)
  )) {
    return(fail("LICENSE_DEPENDENCY_AUDIT_PATH_INVALID"))
  }
  expectedHash = values[["Dependency-Audit-MD5"]]
  if (!grepl("^[0-9a-f]{32}$", expectedHash) ||
      !identical(release_gate_file_hash(resolvedArtifact), expectedHash)) {
    return(fail("LICENSE_DEPENDENCY_AUDIT_HASH_MISMATCH"))
  }
  if (!release_gate_validate_license_expression(
    descriptionLicense, rootPath
  )) {
    return(fail("LICENSE_EXPRESSION_INVALID"))
  }
  parseStatus[["license"]] = "pass"
  list(parse_status = parseStatus, values = values)
}

release_gate_write_self_fixture <- function(root, status,
                                            includeScope = FALSE,
                                            cleanroomReview = NULL,
                                            duplicateStatus = FALSE,
                                            sensitive = FALSE) {
  dir.create(file.path(root, "docs", "provenance"), recursive = TRUE)
  dir.create(file.path(root, "docs", "release"), recursive = TRUE)
  requestStatus <- if (identical(status, "blocked")) "draft" else "resolved"
  requestUrl <- if (identical(requestStatus, "draft")) {
    "not-posted"
  } else {
    "https://example.invalid/request"
  }
  requestDate <- if (identical(requestStatus, "draft")) {
    "not-posted"
  } else {
    "2026-08-25T00:00:00Z"
  }
  requestPath <- file.path(
    root, "docs", "provenance", "UPSTREAM-REQUEST.md"
  )
  writeLines(c(
    "Request-Document-Version: 1",
    "Upstream-Repository: https://example.invalid/upstream",
    "Upstream-Commit: self-test-commit",
    "Request-Ask: explicit-open-source-license",
    "Request-Ask: modification-and-public-redistribution",
    "Request-Ask: attributed-GEModelR-name"
  ), requestPath, useBytes = TRUE)
  requestHash <- release_gate_file_hash(requestPath)
  statusLines <- rep(
    paste0("Rights-Status: ", status),
    if (duplicateStatus) 2L else 1L
  )
  rightsLines <- c(
    statusLines,
    "Upstream-Repository: https://example.invalid/upstream",
    "Upstream-Commit: self-test-commit",
    paste0("Request-Status: ", requestStatus),
    paste0("Request-URL: ", requestUrl),
    paste0("Request-Date-UTC: ", requestDate),
    paste0("Request-Content-Hash: ", requestHash),
    "Evidence-Hash: 0123456789abcdef0123456789abcdef",
    "Reviewer: self-test-reviewer",
    "Review-Date-UTC: 2026-08-25"
  )
  if (includeScope) {
    rightsLines <- c(
      rightsLines,
      "Covered-Upstream-Commit: self-test-commit",
      "Covered-Components: inherited-source"
    )
  }
  writeLines(rightsLines, file.path(root, "docs", "provenance", "RIGHTS.md"))
  blockers <- if (identical(status, "blocked")) {
    "RIGHTS_BLOCKED,REQUEST_NOT_POSTED"
  } else {
    "NONE"
  }
  writeLines(c(
    paste0("Rights-Gate-Status: ", status),
    paste0("Intentional-Blockers: ", blockers)
  ), file.path(root, "docs", "release", "RELEASE-GATES.md"))
  if (!is.null(cleanroomReview)) {
    dir.create(file.path(root, "specs", "cleanroom"), recursive = TRUE)
    relative <- c(
      replacement_source = "cleanroom/self/source.R",
      behavior_test = "cleanroom/self/test.R",
      public_standard_evidence = "cleanroom/self/standard.md",
      redistributable_fixture = "cleanroom/self/fixture.dcf",
      independent_result = "cleanroom/self/result.dcf"
    )
    absolute <- setNames(file.path(root, unname(relative)), names(relative))
    invisible(lapply(
      dirname(absolute), dir.create, recursive = TRUE, showWarnings = FALSE
    ))
    writeLines(c(
      "cleanroom_self = function(value) {",
      "  value * 2",
      "}"
    ), absolute[["replacement_source"]], useBytes = TRUE)
    writeLines(c(
      "args = commandArgs(trailingOnly = TRUE)",
      "if (!identical(args[c(1L, 3L)], c(\"--source\", \"--fixture\"))) stop(\"arguments\")",
      "environment = new.env(parent = baseenv())",
      "sys.source(args[[2L]], envir = environment)",
      "fixture = read.dcf(args[[4L]])",
      "stopifnot(identical(environment$cleanroom_self(as.numeric(fixture[1L, \"Input\"])), as.numeric(fixture[1L, \"Expected\"])))"
    ), absolute[["behavior_test"]], useBytes = TRUE)
    writeLines(c("Input: 2", "Expected: 4", "License: CC0-1.0"),
               absolute[["redistributable_fixture"]], useBytes = TRUE)
    writeLines("Public arithmetic behavior evidence.",
               absolute[["public_standard_evidence"]], useBytes = TRUE)
    hashes <- unname(tools::md5sum(absolute[c(
      "replacement_source", "behavior_test", "public_standard_evidence",
      "redistributable_fixture"
    )]))
    names(hashes) <- c(
      "replacement_source_md5", "behavior_test_md5",
      "public_standard_evidence_md5", "fixture_md5"
    )
    write.dcf(matrix(c(
      "example-component", "R/example.R::example",
      hashes[["replacement_source_md5"]], hashes[["behavior_test_md5"]],
      hashes[["fixture_md5"]], hashes[["public_standard_evidence_md5"]],
      "rscript-cleanroom-v1", "0", "self-test-result-producer",
      format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      "self-test-independent-reviewer",
      format(Sys.Date(), "%Y-%m-%d"), "pass"
    ), nrow = 1L, dimnames = list(NULL, c(
      "Component-ID", "Provenance-Key", "Replacement-Source-MD5",
      "Behavior-Test-MD5", "Fixture-MD5", "Public-Standard-Evidence-MD5",
      "Test-Command-ID", "Exit-Status", "Result-Producer",
      "Produced-At-UTC", "Reviewer", "Review-Date", "Result-Status"
    ))), absolute[["independent_result"]])
    resultHash <- release_gate_file_hash(absolute[["independent_result"]])

    writeLines(c(
      "Cleanroom-Protocol-Version: 2",
      "Cleanroom-Coverage: complete",
      paste0("Cleanroom-Review-Status: ", cleanroomReview),
      "Inherited-Provenance-Key: R/example.R::example"
    ), file.path(root, "docs", "provenance", "CLEANROOM.md"))
    writeLines(c(
      "component_id: example-component",
      "provenance_key: R/example.R::example",
      "inputs: numeric scalar x",
      "outputs: numeric scalar y",
      "errors: non-numeric input is rejected",
      "invariants: output length equals input length",
      "compatibility_example: x=2 produces y=4",
      "specification_author: self-test-specification-author",
      "specification_attestation: behavior-only-no-inherited-expression",
      "implementer: self-test-independent-implementer",
      "implementer_eligibility: eligible",
      "implementer_source_access: none",
      "implementer_attestation: no-inherited-source-access",
      "reviewer: self-test-independent-reviewer",
      "reviewer_attestation: independent-review-complete",
      paste0("replacement_source: ", relative[["replacement_source"]]),
      paste0("replacement_source_md5: ", hashes[["replacement_source_md5"]]),
      paste0("behavior_test: ", relative[["behavior_test"]]),
      paste0("behavior_test_md5: ", hashes[["behavior_test_md5"]]),
      paste0("public_standard_evidence: ", relative[["public_standard_evidence"]]),
      paste0("public_standard_evidence_md5: ", hashes[["public_standard_evidence_md5"]]),
      paste0("redistributable_fixture: ", relative[["redistributable_fixture"]]),
      paste0("fixture_md5: ", hashes[["fixture_md5"]]),
      paste0("independent_result: ", relative[["independent_result"]]),
      paste0("independent_result_md5: ", resultHash),
      "provenance_classification: new-independent"
    ), file.path(root, "specs", "cleanroom", "example-component.md"))
  }
  if (sensitive) {
    writeLines(
      "self-test-sensitive-value",
      file.path(root, "docs", "provenance", "credential.txt")
    )
  }
}

release_gate_write_self_public_domain_fixture <- function(
    root, coverageStatus = "complete") {
  release_gate_write_self_fixture(root, "cleared")
  responsePath <- file.path(
    root, "docs", "provenance", "UPSTREAM-RESPONSE.md"
  )
  responseUrl <- "https://example.invalid/public-domain-response"
  writeLines(c(
    "Response-Document-Version: 1",
    "Upstream-Repository: https://example.invalid/upstream",
    "Upstream-Commit: self-test-commit",
    paste0("Response-URL: ", responseUrl),
    "Response-Date-UTC: 2026-08-25T00:00:00Z",
    "Response-Author-GitHub: self-test-owner",
    "Response-Author-Association: OWNER",
    paste0(
      "Response-Statement: ",
      "It is in the public domain (CC0)--I created it as part of my duties ",
      "as an employee of the US federal government, and so I do not retain ",
      "any copyright."
    ),
    "CC0-Reference: https://creativecommons.org/publicdomain/zero/1.0/",
    paste0(
      "US-Government-Works-Reference: ",
      "https://uscode.house.gov/view.xhtml?section105"
    )
  ), responsePath, useBytes = TRUE)
  rightsPath <- file.path(root, "docs", "provenance", "RIGHTS.md")
  rightsLines <- release_gate_read_lines(rightsPath)
  rightsLines[grepl("^Request-Status:", rightsLines)] <-
    "Request-Status: superseded-by-public-response"
  rightsLines[grepl("^Evidence-Hash:", rightsLines)] <- paste0(
    "Evidence-Hash: ", release_gate_file_hash(responsePath)
  )
  rightsLines <- c(
    rightsLines,
    "Rights-Basis: public-domain-cc0",
    "Covered-Upstream-Commit: self-test-commit",
    "Covered-Components: upstream-authored-inherited-source",
    "Excluded-Components: unrelated-third-party-components",
    paste0("Provenance-Coverage-Status: ", coverageStatus),
    "Evidence-Document: docs/provenance/UPSTREAM-RESPONSE.md",
    paste0("Response-URL: ", responseUrl),
    "Response-Date-UTC: 2026-08-25T00:00:00Z",
    "Response-Author-GitHub: self-test-owner",
    "Response-Author-Association: OWNER",
    "Response-Review-Status: accepted-public-domain-cc0",
    "Successor-Name-Basis: independently-selected",
    "Name-Availability-Status: approved-initial-report"
  )
  writeLines(rightsLines, rightsPath)
  blockers <- if (identical(coverageStatus, "complete")) {
    "NONE"
  } else {
    "PROVENANCE_COVERAGE_INCOMPLETE"
  }
  writeLines(c(
    "Rights-Gate-Status: cleared",
    paste0("Intentional-Blockers: ", blockers)
  ), file.path(root, "docs", "release", "RELEASE-GATES.md"))
}
release_gate_self_test <- function() {
  root <- tempfile("release-gate-self-test-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- function(name) file.path(root, name)

  blocked <- fixture("blocked")
  release_gate_write_self_fixture(blocked, "blocked")
  blockedResult <- release_gate_evaluate_rights(blocked)

  cleared <- fixture("cleared")
  release_gate_write_self_fixture(cleared, "cleared", includeScope = TRUE)
  clearedResult <- release_gate_evaluate_rights(cleared)

  publicDomain <- fixture("public-domain")
  release_gate_write_self_public_domain_fixture(publicDomain)
  publicDomainResult <- release_gate_evaluate_rights(publicDomain)

  publicDomainPending <- fixture("public-domain-pending")
  release_gate_write_self_public_domain_fixture(
    publicDomainPending, "pending-audit"
  )
  publicDomainPendingResult <- release_gate_evaluate_rights(publicDomainPending)
  cleanroom <- fixture("cleanroom")
  release_gate_write_self_fixture(
    cleanroom, "clean-room-required", cleanroomReview = "approved"
  )
  cleanroomResult <- release_gate_evaluate_rights(cleanroom)

  malformed <- fixture("malformed")
  release_gate_write_self_fixture(
    malformed, "blocked", duplicateStatus = TRUE
  )
  malformedResult <- release_gate_evaluate_rights(malformed)

  sensitive <- fixture("sensitive")
  release_gate_write_self_fixture(sensitive, "blocked", sensitive = TRUE)
  sensitiveResult <- release_gate_evaluate_rights(sensitive)

  identical(blockedResult$reason_codes, c("RIGHTS_BLOCKED", "REQUEST_NOT_POSTED")) &&
    identical(blockedResult$repository_state, "blocked") &&
    isTRUE(clearedResult$release_ready) &&
    identical(clearedResult$repository_state, "eligible") &&
    isTRUE(publicDomainResult$release_ready) &&
    identical(publicDomainResult$repository_state, "eligible") &&
    identical(
      publicDomainPendingResult$reason_codes,
      "PROVENANCE_COVERAGE_INCOMPLETE"
    ) &&
    isTRUE(cleanroomResult$release_ready) &&
    identical(cleanroomResult$repository_state, "eligible") &&
    identical(malformedResult$reason_codes, "RIGHTS_STATUS_CARDINALITY") &&
    identical(sensitiveResult$reason_codes, "SENSITIVE_EVIDENCE_CLASS")
}

release_gate_parse_args <- function(args) {
  root <- "."
  index <- 1L
  while (index <= length(args)) {
    argument <- args[[index]]
    if (identical(argument, "--root")) {
      if (index == length(args)) stop("--root requires a path", call. = FALSE)
      root <- args[[index + 1L]]
      index <- index + 2L
      next
    }
    if (startsWith(argument, "--root=")) {
      root <- sub("^--root=", "", argument)
      index <- index + 1L
      next
    }
    if (!argument %in% c("--offline", "--assert-blocked", "--self-test")) {
      stop("Unknown release-gate argument", call. = FALSE)
    }
    index <- index + 1L
  }
  list(
    root = root,
    offline = "--offline" %in% args,
    assert_blocked = "--assert-blocked" %in% args,
    self_test = "--self-test" %in% args
  )
}

release_gate_print_result <- function(result) {
  reasons <- if (length(result$reason_codes)) {
    paste(result$reason_codes, collapse = ",")
  } else {
    "NONE"
  }
  cat(paste0("repository_state=", result$repository_state, "\n"))
  cat(paste0(
    "release_ready=", tolower(as.character(result$release_ready)), "\n"
  ))
  cat(paste0("reason_codes=", reasons, "\n"))
  for (name in names(result$parse_status)) {
    cat(paste0(
      "parse_status.", name, "=", result$parse_status[[name]], "\n"
    ))
  }
}

release_gate_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- tryCatch(
    release_gate_parse_args(args),
    error = function(error) NULL
  )
  if (is.null(options)) {
    cat("repository_state=invalid\n")
    cat("release_ready=false\n")
    cat("reason_codes=CLI_ARGUMENT_INVALID\n")
    return(2L)
  }
  if (isTRUE(options$self_test)) {
    passed <- tryCatch(
      isTRUE(release_gate_self_test()),
      error = function(error) FALSE
    )
    cat(paste0("self_test=", if (passed) "pass" else "fail", "\n"))
    return(if (passed) 0L else 1L)
  }
  result <- tryCatch(
    release_gate_evaluate(options$root),
    error = function(error) release_gate_result(
      reason_codes = "RELEASE_GATE_INTERNAL_ERROR"
    )
  )
  release_gate_print_result(result)
  if (isTRUE(options$assert_blocked)) {
    validBlocked <- identical(result$repository_state, "blocked") &&
      identical(result$release_ready, FALSE) &&
      identical(result$reason_codes, result$intentional_blockers) &&
      length(result$reason_codes) > 0L &&
      all(unname(result$parse_status) == "pass")
    return(if (validBlocked) 0L else 1L)
  }
  if (isTRUE(result$release_ready)) 0L else 1L
}

if (sys.nframe() == 0L) {
  quit(status = release_gate_main(), save = "no")
}
