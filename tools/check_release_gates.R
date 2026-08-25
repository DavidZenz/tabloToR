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
  if (!identical(protocolValues[["Cleanroom-Protocol-Version"]], "1") ||
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
    "reviewer_attestation", "behavior_test", "behavior_test_status",
    "public_standard", "redistributable_fixture",
    "provenance_classification"
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
      identical(values[["behavior_test_status"]], "pass") &&
      startsWith(values[["public_standard"]], "public:") &&
      startsWith(
        values[["redistributable_fixture"]], "redistributable:"
      ) &&
      identical(
        values[["provenance_classification"]], "new-independent"
      )
    if (!evidenceComplete) {
      return(fail("CLEANROOM_EVIDENCE_INCOMPLETE"))
    }
    components[[index]] <- values
  }

  componentIds <- vapply(
    components, `[[`, character(1), "component_id"
  )
  provenanceKeys <- vapply(
    components, `[[`, character(1), "provenance_key"
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
  release_gate_result(
    repository_state = "eligible",
    release_ready = TRUE,
    reason_codes = character(),
    parse_status = c(parsePass, cleanroom = "pass"),
    intentional_blockers = intentionalBlockers
  )
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
    evidenceValues[["Name-Availability-Status"]], "pending-plan-01-04"
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
  if (length(intentionalBlockers)) {
    return(release_gate_result(
      reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
      parse_status = c(
        parsePass, public_domain = "pass", provenance_coverage = "pass"
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
    writeLines(c(
      "Cleanroom-Protocol-Version: 1",
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
      "compatibility_example: x=1 produces y=1",
      "specification_author: self-test-specification-author",
      "specification_attestation: behavior-only-no-inherited-expression",
      "implementer: self-test-independent-implementer",
      "implementer_eligibility: eligible",
      "implementer_source_access: none",
      "implementer_attestation: no-inherited-source-access",
      "reviewer: self-test-independent-reviewer",
      "reviewer_attestation: independent-review-complete",
      "behavior_test: self-test#observable-contract",
      "behavior_test_status: pass",
      "public_standard: public:documented-R-semantics",
      "redistributable_fixture: redistributable:synthetic-example",
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
    "Name-Availability-Status: pending-plan-01-04"
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
  blockedResult <- release_gate_evaluate(blocked)

  cleared <- fixture("cleared")
  release_gate_write_self_fixture(cleared, "cleared", includeScope = TRUE)
  clearedResult <- release_gate_evaluate(cleared)

  publicDomain <- fixture("public-domain")
  release_gate_write_self_public_domain_fixture(publicDomain)
  publicDomainResult <- release_gate_evaluate(publicDomain)

  publicDomainPending <- fixture("public-domain-pending")
  release_gate_write_self_public_domain_fixture(
    publicDomainPending, "pending-audit"
  )
  publicDomainPendingResult <- release_gate_evaluate(publicDomainPending)
  cleanroom <- fixture("cleanroom")
  release_gate_write_self_fixture(
    cleanroom, "clean-room-required", cleanroomReview = "approved"
  )
  cleanroomResult <- release_gate_evaluate(cleanroom)

  malformed <- fixture("malformed")
  release_gate_write_self_fixture(
    malformed, "blocked", duplicateStatus = TRUE
  )
  malformedResult <- release_gate_evaluate(malformed)

  sensitive <- fixture("sensitive")
  release_gate_write_self_fixture(sensitive, "blocked", sensitive = TRUE)
  sensitiveResult <- release_gate_evaluate(sensitive)

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
      identical(
        result$reason_codes,
        "PROVENANCE_COVERAGE_INCOMPLETE"
      ) &&
      identical(
        unname(result$parse_status),
        c("pass", "pass", "pass", "incomplete")
      )
    return(if (validBlocked) 0L else 1L)
  }
  if (isTRUE(result$release_ready)) 0L else 1L
}

if (sys.nframe() == 0L) {
  quit(status = release_gate_main(), save = "no")
}
