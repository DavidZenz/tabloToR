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

release_gate_single_markers <- function(lines, fields) {
  values <- lapply(fields, function(field) {
    release_gate_marker_values(lines, field)
  })
  names(values) <- fields
  values
}

release_gate_has_sensitive_evidence <- function(root) {
  evidenceDirs <- file.path(root, "docs", c("provenance", "release"))
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
    "Request-Status", "Request-URL", "Evidence-Hash", "Reviewer",
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

  if (identical(rightsStatus, "blocked")) {
    if (!identical(intentionalBlockers, "RIGHTS_BLOCKED")) {
      return(release_gate_result(
        reason_codes = "INTENTIONAL_BLOCKERS_MISMATCH",
        parse_status = parsePass,
        intentional_blockers = intentionalBlockers
      ))
    }
    return(release_gate_result(
      repository_state = "blocked",
      reason_codes = "RIGHTS_BLOCKED",
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
  cleanroomPass <- FALSE
  if (!is.null(cleanroomLines)) {
    cleanroom <- release_gate_single_markers(
      cleanroomLines,
      c("Cleanroom-Coverage", "Cleanroom-Review-Status")
    )
    if (all(vapply(cleanroom, length, integer(1)) == 1L)) {
      cleanroomValues <- vapply(cleanroom, `[[`, character(1), 1L)
      cleanroomPass <- identical(
        cleanroomValues[["Cleanroom-Coverage"]], "complete"
      ) && identical(
        cleanroomValues[["Cleanroom-Review-Status"]], "approved"
      )
    }
  }
  if (!cleanroomPass) {
    return(release_gate_result(
      reason_codes = "CLEANROOM_REVIEW_INCOMPLETE",
      parse_status = c(parsePass, cleanroom = "fail"),
      intentional_blockers = intentionalBlockers
    ))
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

release_gate_write_self_fixture <- function(root, status,
                                            includeScope = FALSE,
                                            cleanroomReview = NULL,
                                            duplicateStatus = FALSE,
                                            sensitive = FALSE) {
  dir.create(file.path(root, "docs", "provenance"), recursive = TRUE)
  dir.create(file.path(root, "docs", "release"), recursive = TRUE)
  statusLines <- rep(
    paste0("Rights-Status: ", status),
    if (duplicateStatus) 2L else 1L
  )
  rightsLines <- c(
    statusLines,
    "Upstream-Repository: https://example.invalid/upstream",
    "Upstream-Commit: self-test-commit",
    "Request-Status: resolved",
    "Request-URL: https://example.invalid/request",
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
  blockers <- if (identical(status, "blocked")) "RIGHTS_BLOCKED" else "NONE"
  writeLines(c(
    paste0("Rights-Gate-Status: ", status),
    paste0("Intentional-Blockers: ", blockers)
  ), file.path(root, "docs", "release", "RELEASE-GATES.md"))
  if (!is.null(cleanroomReview)) {
    writeLines(c(
      "Cleanroom-Coverage: complete",
      paste0("Cleanroom-Review-Status: ", cleanroomReview)
    ), file.path(root, "docs", "provenance", "CLEANROOM.md"))
  }
  if (sensitive) {
    writeLines(
      "self-test-sensitive-value",
      file.path(root, "docs", "provenance", "credential.txt")
    )
  }
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

  identical(blockedResult$reason_codes, "RIGHTS_BLOCKED") &&
    identical(blockedResult$repository_state, "blocked") &&
    isTRUE(clearedResult$release_ready) &&
    identical(clearedResult$repository_state, "eligible") &&
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
      identical(result$reason_codes, "RIGHTS_BLOCKED") &&
      identical(unname(result$parse_status), c("pass", "pass")) &&
      identical(result$intentional_blockers, "RIGHTS_BLOCKED")
    return(if (validBlocked) 0L else 1L)
  }
  if (isTRUE(result$release_ready)) 0L else 1L
}

if (sys.nframe() == 0L) {
  quit(status = release_gate_main(), save = "no")
}
