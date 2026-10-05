#!/usr/bin/env Rscript

workflow_identity_abort = function(code, detail = NULL) {
  message = if (is.null(detail) || !length(detail) || !nzchar(detail)) {
    code
  } else {
    paste(code, detail)
  }
  stop(message, call. = FALSE)
}

workflow_identity_script_path = local({
  source_files = vapply(sys.frames(), function(frame) {
    value = frame$ofile
    if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
  }, character(1))
  source_files = source_files[nzchar(source_files)]
  file_argument = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(source_files)) {
    normalizePath(tail(source_files, 1L), mustWork = TRUE)
  } else if (length(file_argument)) {
    normalizePath(sub("^--file=", "", file_argument[[1L]]), mustWork = TRUE)
  } else {
    NA_character_
  }
})

workflow_identity_repository_root = function() {
  working = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  ancestors = working
  while (!identical(tail(ancestors, 1L), dirname(tail(ancestors, 1L)))) {
    ancestors = c(ancestors, dirname(tail(ancestors, 1L)))
  }
  candidates = c(
    if (!is.na(workflow_identity_script_path)) {
      dirname(dirname(workflow_identity_script_path))
    } else {
      character()
    },
    ancestors
  )
  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        file.exists(file.path(
          candidate, "inst", "migration", "predecessor-fingerprints.dcf"
        ))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  workflow_identity_abort("WORKFLOW_IDENTITY_ROOT_NOT_FOUND")
}

workflow_identity_old_token = function(root = workflow_identity_repository_root()) {
  registry = file.path(root, "inst", "migration", "predecessor-fingerprints.dcf")
  if (!isTRUE(file_test("-f", registry))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_REGISTRY_MISSING", registry)
  }
  records = tryCatch(
    read.dcf(registry, fields = "Package-Name"),
    error = function(error) workflow_identity_abort(
      "WORKFLOW_IDENTITY_REGISTRY_INVALID", conditionMessage(error)
    )
  )
  package = unique(as.character(records[, "Package-Name"]))
  if (length(package) != 1L || is.na(package) || !nzchar(package)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_PREDECESSOR_INVALID")
  }
  package
}

workflow_identity_policy_fields = function() {
  c("path", "category", "allowed_line_sha256", "max_count", "owner")
}

workflow_identity_allowed_paths = function() {
  c(
    ".planning/STATE.md",
    ".planning/ROADMAP.md",
    ".planning/phases/03-gemodelr-identity-migration/03-VALIDATION.md",
    ".planning/phases/03-gemodelr-identity-migration/03-REVIEW.md",
    file.path(
      ".planning/phases/03-gemodelr-identity-migration",
      paste0(sprintf("03-%02d", 13:20), "-SUMMARY.md")
    )
  )
}

workflow_identity_summary_paths = function() {
  workflow_identity_allowed_paths()[5:12]
}

workflow_identity_hash_raw = function(value) {
  if (!is.raw(value)) workflow_identity_abort("WORKFLOW_IDENTITY_HASH_INPUT")
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(unclass(as.character(openssl::sha256(value))))
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(value, algo = "sha256", serialize = FALSE))
  }
  workflow_identity_abort("WORKFLOW_IDENTITY_SHA256_UNAVAILABLE")
}

workflow_identity_hash_line = function(line) {
  if (!is.character(line) || length(line) != 1L || is.na(line) ||
      grepl("[\r\n]", line, perl = TRUE)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_LINE_INVALID")
  }
  workflow_identity_hash_raw(charToRaw(enc2utf8(paste0(line, "\n"))))
}

workflow_identity_read_raw = function(path) {
  info = file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) || info$size[[1L]] < 1L ||
      info$size[[1L]] > 50 * 1024^2 || !isTRUE(file_test("-f", path))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_FILE_INVALID", path)
  }
  connection = file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, "raw", n = as.integer(info$size[[1L]]))
}

workflow_identity_resolve_path = function(root, relative, allow_missing = FALSE) {
  if (!is.character(relative) || length(relative) != 1L || is.na(relative) ||
      !nzchar(relative) || !identical(relative, trimws(relative)) ||
      grepl("[\r\n*?{}]", relative, perl = TRUE) ||
      grepl("[\\[\\]]", relative, perl = TRUE)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_PATH_INVALID", relative)
  }
  relative = gsub("\\\\", "/", relative)
  components = strsplit(relative, "/", fixed = TRUE)[[1L]]
  if (startsWith(relative, "/") || grepl("^[A-Za-z]:", relative) ||
      any(components %in% c("", ".", ".."))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_PATH_INVALID", relative)
  }
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate = do.call(file.path, as.list(c(root, components)))
  if (!file.exists(candidate) || dir.exists(candidate) ||
      !isTRUE(file_test("-f", candidate))) {
    if (isTRUE(allow_missing)) return(candidate)
    workflow_identity_abort("WORKFLOW_IDENTITY_PATH_MISSING", relative)
  }
  resolved = normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (!identical(resolved, root) &&
      !startsWith(resolved, paste0(root, "/"))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_PATH_ESCAPE", relative)
  }
  resolved
}

workflow_identity_read_policy = function(path) {
  value = tryCatch(
    read.csv(
      path, stringsAsFactors = FALSE, check.names = FALSE,
      colClasses = "character", na.strings = NULL
    ),
    error = function(error) workflow_identity_abort(
      "WORKFLOW_IDENTITY_POLICY_INVALID", conditionMessage(error)
    )
  )
  if (!identical(names(value), workflow_identity_policy_fields())) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_FIELDS")
  }
  value[] = lapply(value, as.character)
  value
}

workflow_identity_review_path = function(root = workflow_identity_repository_root()) {
  file.path(root, "inst", "migration", 
            "workflow-evidence-policy-review.dcf")
}

workflow_identity_policy_path = function(root = workflow_identity_repository_root()) {
  file.path(root, "inst", "migration", "workflow-evidence-policy.csv")
}

workflow_identity_read_review = function(
    path = workflow_identity_review_path()) {
  value = tryCatch(
    read.dcf(path),
    error = function(error) workflow_identity_abort(
      "WORKFLOW_IDENTITY_REVIEW_INVALID", conditionMessage(error)
    )
  )
  fields = c(
    "Schema", "Policy-SHA256", "Review-State", "Reviewer", "Reviewed-UTC",
    "Scope", "Rationale"
  )
  if (!identical(dim(value), c(1L, length(fields))) ||
      !identical(colnames(value), fields)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_REVIEW_FIELDS")
  }
  value = as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
  value[] = lapply(value, as.character)
  value[1L, , drop = FALSE]
}

workflow_identity_expected_owner = function(path) {
  if (path %in% c(".planning/STATE.md", ".planning/ROADMAP.md") ||
      path %in% workflow_identity_summary_paths()) {
    return("orchestrator")
  }
  if (path %in% c(
    ".planning/phases/03-gemodelr-identity-migration/03-VALIDATION.md",
    ".planning/phases/03-gemodelr-identity-migration/03-REVIEW.md"
  )) return("verifier")
  NA_character_
}

workflow_identity_policy_key = function(path, digest) {
  paste(path, digest, sep = "\r")
}

workflow_identity_validate_policy = function(
    value = workflow_identity_read_policy(workflow_identity_policy_path()),
    root = workflow_identity_repository_root()) {
  fields = workflow_identity_policy_fields()
  if (!is.data.frame(value) || !identical(names(value), fields)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_FIELDS")
  }
  value[] = lapply(value, as.character)
  if (!nrow(value)) workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_EMPTY")
  if (anyNA(value) || any(!nzchar(as.matrix(value))) ||
      any(as.matrix(value) != trimws(as.matrix(value)))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_INCOMPLETE")
  }
  if (any(value$category != "migration-instruction")) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_CATEGORY")
  }
  if (any(!value$owner %in% c("orchestrator", "verifier"))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_OWNER")
  }
  allowed = workflow_identity_allowed_paths()
  if (any(!value$path %in% allowed)) {
    workflow_identity_abort(
      "WORKFLOW_IDENTITY_POLICY_PATH_SCOPE",
      paste(unique(value$path[!value$path %in% allowed]), collapse = ",")
    )
  }
  if (any(value$owner != vapply(value$path, workflow_identity_expected_owner,
                                character(1)))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_OWNER_SCOPE")
  }
  key = workflow_identity_policy_key(value$path, value$allowed_line_sha256)
  if (anyDuplicated(key)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_DUPLICATE")
  }
  if (any(!grepl("^[0-9a-f]{64}$", value$allowed_line_sha256))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_DIGEST")
  }
  count = suppressWarnings(as.integer(value$max_count))
  if (anyNA(count) || any(count < 1L) ||
      !identical(as.character(count), value$max_count)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_COUNT")
  }
  summary = value$path %in% workflow_identity_summary_paths()
  if (any(count[summary] != 1L)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_SUMMARY_COUNT")
  }
  if (any(value$allowed_line_sha256[summary] !=
          workflow_identity_hash_line(paste0(
            "Predecessor-package: ", workflow_identity_old_token(root)
          )))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_SUMMARY_LINE")
  }
  if (!setequal(unique(value$path), intersect(unique(value$path), allowed))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_POLICY_PATH_SCOPE")
  }
  invisible(value)
}

workflow_identity_file_lines = function(path) {
  raw = workflow_identity_read_raw(path)
  if (!identical(raw[[length(raw)]], as.raw(10L))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_LINE_TERMINATOR", path)
  }
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  data.frame(
    line = lines,
    digest = vapply(lines, workflow_identity_hash_line, character(1)),
    fenced = {
      state = FALSE
      value = logical(length(lines))
      for (index in seq_along(lines)) {
        marker = grepl("^[[:space:]]*(```|~~~)", lines[[index]])
        value[[index]] = state || marker
        if (marker) state = !state
      }
      value
    },
    stringsAsFactors = FALSE
  )
}

workflow_identity_check_lines = function(
    root = workflow_identity_repository_root(),
    policy_path = workflow_identity_policy_path(),
    review_path = workflow_identity_review_path()) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  policy = workflow_identity_read_policy(policy_path)
  workflow_identity_validate_policy(policy, root)
  predecessor = workflow_identity_old_token(root)
  expected_hash = workflow_identity_hash_line(
    paste0("Predecessor-package: ", predecessor)
  )
  observed = list()

  for (path in unique(policy$path)) {
    optional = path %in% workflow_identity_summary_paths()
    resolved = workflow_identity_resolve_path(root, path, allow_missing = optional)
    if (!file.exists(resolved)) next
    lines = workflow_identity_file_lines(resolved)
    matches = grepl(predecessor, lines$line, fixed = TRUE)
    if (any(lines$fenced[matches])) {
      workflow_identity_abort("WORKFLOW_IDENTITY_CODE_FENCE", path)
    }
    allowed = policy[policy$path == path, , drop = FALSE]
    observed_hashes = lines$digest[matches]
    unknown = setdiff(unique(observed_hashes), allowed$allowed_line_sha256)
    if (length(unknown)) {
      workflow_identity_abort(
        "WORKFLOW_IDENTITY_UNKNOWN_LINE", paste(path, unknown, collapse = ",")
      )
    }
    for (index in seq_len(nrow(allowed))) {
      digest = allowed$allowed_line_sha256[[index]]
      count = sum(observed_hashes == digest)
      if (count > as.integer(allowed$max_count[[index]])) {
        workflow_identity_abort(
          "WORKFLOW_IDENTITY_LINE_COUNT",
          paste(path, digest, count, allowed$max_count[[index]], sep = ":")
        )
      }
      if (path %in% workflow_identity_summary_paths() &&
          digest != expected_hash) {
        workflow_identity_abort("WORKFLOW_IDENTITY_SUMMARY_LINE", path)
      }
    }
    observed[[path]] = data.frame(
      path = path,
      observed_count = length(observed_hashes),
      stringsAsFactors = FALSE
    )
  }

  review = workflow_identity_read_review(review_path)
  list(
    clean = TRUE,
    policy = list(
      PolicySHA256 = workflow_identity_hash_file(policy_path),
      ReviewState = review$`Review-State`,
      Reviewer = review$Reviewer,
      ReviewedUTC = review$`Reviewed-UTC`,
      PathCount = length(unique(policy$path)),
      PredecessorPackage = predecessor
    ),
    rows = if (length(observed)) do.call(rbind, observed) else data.frame(),
    policy_rows = policy
  )
}

workflow_identity_hash_file = function(path) {
  workflow_identity_hash_raw(workflow_identity_read_raw(path))
}

workflow_identity_validate_review = function(
    mode = c("proposal", "approved"),
    root = workflow_identity_repository_root(),
    policy_path = workflow_identity_policy_path(),
    review_path = workflow_identity_review_path()) {
  mode = match.arg(mode)
  policy = workflow_identity_read_policy(policy_path)
  workflow_identity_validate_policy(policy, root)
  review = workflow_identity_read_review(review_path)
  if (!identical(review$Schema, "gemodelr-workflow-identity-policy-review-v1")) {
    workflow_identity_abort("WORKFLOW_IDENTITY_REVIEW_SCHEMA")
  }
  digest = workflow_identity_hash_file(policy_path)
  if (!identical(review$`Policy-SHA256`, digest)) {
    workflow_identity_abort("WORKFLOW_IDENTITY_REVIEW_POLICY_DIGEST")
  }
  states = c("proposed", "approved")
  if (!review$`Review-State` %in% states) {
    workflow_identity_abort("WORKFLOW_IDENTITY_REVIEW_STATE")
  }
  if (identical(mode, "approved") &&
      !identical(review$`Review-State`, "approved")) {
    workflow_identity_abort("WORKFLOW_IDENTITY_APPROVAL_REQUIRED")
  }
  if (identical(review$`Review-State`, "proposed") &&
      (!identical(review$Reviewer, "pending") ||
       !identical(review$`Reviewed-UTC`, "pending"))) {
    workflow_identity_abort("WORKFLOW_IDENTITY_PROPOSAL_REVIEW_FIELDS")
  }
  if (identical(review$`Review-State`, "approved")) {
    if (!nzchar(review$Reviewer) || identical(review$Reviewer, "pending") ||
        !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
               review$`Reviewed-UTC`)) {
      workflow_identity_abort("WORKFLOW_IDENTITY_APPROVAL_FIELDS")
    }
  }
  review
}

workflow_identity_main = function(
    arguments = commandArgs(trailingOnly = TRUE)) {
  if (identical(arguments, "--help")) {
    cat(paste(
      "Usage:",
      "  Rscript --vanilla tools/check_workflow_identity_policy.R --proposal",
      "  Rscript --vanilla tools/check_workflow_identity_policy.R --verify-approved",
      sep = "\n"
    ), "\n")
    return(invisible(0L))
  }
  if (!identical(arguments, "--proposal") &&
      !identical(arguments, "--verify-approved")) {
    workflow_identity_abort("WORKFLOW_IDENTITY_ARGUMENT_INVALID")
  }
  root = workflow_identity_repository_root()
  mode = if (identical(arguments, "--proposal")) "proposal" else "approved"
  workflow_identity_validate_review(mode, root = root)
  result = workflow_identity_check_lines(root = root)
  cat("Workflow identity policy: PASS\n")
  cat(sprintf("Review-state: %s\n", result$policy$ReviewState))
  cat(sprintf("Policy-SHA256: %s\n", result$policy$PolicySHA256))
  cat(sprintf("Enumerated-paths: %s\n", result$policy$PathCount))
  cat(sprintf("Predecessor-package: %s\n", result$policy$PredecessorPackage))
  invisible(0L)
}

if (sys.nframe() == 0L) workflow_identity_main()
