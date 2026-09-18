#!/usr/bin/env Rscript

seal_abort = function(code, detail = NULL) {
  message = if (is.null(detail) || !length(detail) || !nzchar(detail)) {
    code
  } else {
    paste(code, detail)
  }
  stop(message, call. = FALSE)
}

seal_script_path = local({
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

seal_environment = environment()

seal_guess_root = function() {
  working = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  ancestors = working
  while (!identical(tail(ancestors, 1L), dirname(tail(ancestors, 1L)))) {
    ancestors = c(ancestors, dirname(tail(ancestors, 1L)))
  }
  candidates = c(
    if (!is.na(seal_script_path)) dirname(dirname(seal_script_path))
    else character(),
    ancestors
  )
  required = c("DESCRIPTION", file.path("tools", "check_identity_migration.R"),
               file.path("tools", "check_workflow_identity_policy.R"))
  hit = candidates[vapply(candidates, function(candidate) {
    all(file.exists(file.path(candidate, required)))
  }, logical(1))]
  if (!length(hit)) seal_abort("IDENTITY_RESEAL_ROOT_NOT_FOUND")
  normalizePath(hit[[1L]], winslash = "/", mustWork = TRUE)
}

seal_load_support = function(target) {
  if (!exists("identity_abort", envir = target, inherits = FALSE)) {
    root = seal_guess_root()
    identity_path = file.path(root, "tools", "check_identity_migration.R")
    policy_path = file.path(root, "tools", "check_workflow_identity_policy.R")
    if (!isTRUE(file_test("-f", identity_path)) ||
        !isTRUE(file_test("-f", policy_path))) {
      seal_abort("IDENTITY_SUPPORT_TOOLS_MISSING", root)
    }
    sys.source(identity_path, envir = target)
    sys.source(policy_path, envir = target)
  }
  invisible(NULL)
}
seal_load_support(seal_environment)

seal_approved_workflow_policy_sha256 =
  "882f3f92a8afe84fdd50b4565ed189af5242afd8cfc2bfd72a22db4553f2ce1e"

seal_repository_root = function(root = NULL) {
  if (is.null(root)) {
    root = seal_guess_root()
  }
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  required = c(
    "DESCRIPTION",
    file.path("tools", "check_identity_migration.R"),
    file.path("tools", "check_workflow_identity_policy.R"),
    file.path("inst", "migration", "workflow-evidence-policy.csv")
  )
  if (any(!file.exists(file.path(root, required)))) {
    seal_abort("IDENTITY_RESEAL_ROOT_INVALID", root)
  }
  root
}

seal_hash_raw = function(value) {
  if (!is.raw(value)) seal_abort("IDENTITY_RESEAL_HASH_INPUT")
  if (exists("identity_hash_raw", inherits = TRUE)) {
    return(identity_hash_raw(value))
  }
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(unclass(as.character(openssl::sha256(value))))
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(value, algo = "sha256", serialize = FALSE))
  }
  seal_abort("IDENTITY_RESEAL_SHA256_UNAVAILABLE")
}

seal_read_raw = function(path) {
  info = file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) ||
      !isTRUE(file_test("-f", path))) {
    seal_abort("IDENTITY_RESEAL_FILE_INVALID", path)
  }
  connection = file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, "raw", n = as.integer(info$size[[1L]]))
}

seal_hash_file = function(path) {
  seal_hash_raw(seal_read_raw(path))
}

seal_git = function() {
  path = if (file.exists("/usr/bin/git")) "/usr/bin/git" else Sys.which("git")
  if (!nzchar(path)) seal_abort("IDENTITY_RESEAL_GIT_MISSING")
  path
}

seal_git_output = function(root, arguments, code) {
  output = suppressWarnings(system2(
    seal_git(), c("-C", root, arguments), stdout = TRUE, stderr = TRUE
  ))
  status = attr(output, "status")
  if (!is.null(status) && status != 0L) {
    seal_abort(code, paste(output, collapse = " "))
  }
  output
}

seal_git_head = function(root) {
  output = seal_git_output(root, c("rev-parse", "HEAD"),
                           "IDENTITY_RESEAL_GIT_HEAD")
  head = trimws(paste(output, collapse = ""))
  if (!grepl("^[0-9a-f]{40}$", head)) {
    seal_abort("IDENTITY_RESEAL_HEAD_INVALID", head)
  }
  head
}

seal_git_status = function(root) {
  output = seal_git_output(
    root,
    c("status", "--porcelain=v1", "--untracked-files=all"),
    "IDENTITY_RESEAL_GIT_STATUS"
  )
  if (length(output) && !all(is.na(output))) {
    as.character(output)
  } else {
    character()
  }
}

seal_git_tracked_paths = function(root) {
  paths = identity_git_tracked_paths(root)
  if (!length(paths)) seal_abort("IDENTITY_RESEAL_NO_TRACKED_FILES")
  paths
}

seal_is_symlink = function(path) {
  value = tryCatch(Sys.readlink(path), error = function(error) "")
  is.character(value) && length(value) == 1L && nzchar(value)
}

seal_tracked_tree_digest = function(root) {
  root = seal_repository_root(root)
  paths = seal_git_tracked_paths(root)
  records = lapply(paths, function(relative) {
    path = file.path(root, relative)
    if (seal_is_symlink(path)) {
      seal_abort("IDENTITY_RESEAL_TRACKED_SYMLINK", relative)
    }
    if (!file.exists(path) || dir.exists(path) ||
        !isTRUE(file_test("-f", path))) {
      seal_abort("IDENTITY_RESEAL_TRACKED_INPUT_MISSING", relative)
    }
    c(
      charToRaw(enc2utf8(paste0(relative, intToUtf8(0L)))),
      seal_read_raw(path),
      charToRaw(intToUtf8(0L))
    )
  })
  seal_hash_raw(do.call(c, records))
}

seal_path_outside_root = function(path, root, code) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path)) {
    seal_abort(code, "empty path")
  }
  path = normalizePath(path, winslash = "/", mustWork = FALSE)
  root = seal_repository_root(root)
  if (identical(path, root) || startsWith(path, paste0(root, "/"))) {
    seal_abort(code, path)
  }
  path
}

seal_workflow_policy_paths = function(root) {
  result = identity_validate_approved_workflow_policy(root)
  result$policy_paths
}

seal_validate_approved_workflow_policy = function(
    root = seal_repository_root(),
    policy_path = file.path(
      root, "inst", "migration", "workflow-evidence-policy.csv"
    ),
    review_path = file.path(
      root, "inst", "migration", "workflow-evidence-policy-review.dcf"
    )) {
  root = seal_repository_root(root)
  result = identity_validate_approved_workflow_policy(
    root, policy_path = policy_path, review_path = review_path
  )
  if (!identical(result$policy$PolicySHA256,
                seal_approved_workflow_policy_sha256)) {
    seal_abort(
      "IDENTITY_RESEAL_POLICY_DIGEST",
      result$policy$PolicySHA256
    )
  }
  result
}

seal_read_reseal_review = function(path) {
  value = tryCatch(
    read.dcf(path),
    error = function(error) seal_abort(
      "IDENTITY_RESEAL_REVIEW_INVALID", conditionMessage(error)
    )
  )
  fields = c(
    "Schema", "Before-Allowlist-SHA256", "Approved-Allowlist-SHA256",
    "Policy-SHA256", "Scope", "Reviewer", "Reviewed-UTC", "Review-State"
  )
  if (!identical(dim(value), c(1L, length(fields))) ||
      !identical(colnames(value), fields)) {
    seal_abort("IDENTITY_RESEAL_REVIEW_FIELDS")
  }
  value = as.data.frame(value, stringsAsFactors = FALSE,
                        check.names = FALSE)
  value[] = lapply(value, as.character)
  value[1L, , drop = FALSE]
}

seal_validate_reseal_review = function(
    root = seal_repository_root(),
    allowlist_path = file.path(
      root, "inst", "migration", "old-identity-allowlist.csv"
    ),
    review_path = file.path(
      root, "inst", "migration", "identity-reseal-review.dcf"
    )) {
  root = seal_repository_root(root)
  review = seal_read_reseal_review(review_path)
  policy = seal_validate_approved_workflow_policy(root)
  digests = review[1L, c(
    "Before-Allowlist-SHA256", "Approved-Allowlist-SHA256",
    "Policy-SHA256"
  )]
  if (!identical(review[["Schema"]], "gemodelr-identity-reseal-review-v1") ||
      !identical(review[["Review-State"]], "approved") ||
      !nzchar(review[["Scope"]]) || !nzchar(review[["Reviewer"]]) ||
      identical(review[["Reviewer"]], "pending") ||
      !grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
        review[["Reviewed-UTC"]]
      )) {
    seal_abort("IDENTITY_RESEAL_REVIEW_APPROVAL_REQUIRED")
  }
  if (any(!grepl("^[0-9a-f]{64}$", as.character(digests)))) {
    seal_abort("IDENTITY_RESEAL_REVIEW_DIGEST")
  }
  if (!identical(review[["Policy-SHA256"]],
                 policy$policy$PolicySHA256)) {
    seal_abort("IDENTITY_RESEAL_REVIEW_POLICY_DIGEST")
  }
  observed = seal_hash_file(allowlist_path)
  if (!identical(observed, review[["Approved-Allowlist-SHA256"]])) {
    seal_abort("IDENTITY_RESEAL_ALLOWLIST_APPROVAL_DIGEST", observed)
  }
  list(clean = TRUE, review = review, policy = policy,
       allowlist_sha256 = observed)
}

seal_row_key = function(value) {
  if (!is.data.frame(value) || !nrow(value)) return(character())
  paste(value$path, value$category, sep = "\r")
}

seal_row_description = function(row, prefix) {
  paste(
    prefix, row$path, row$category,
    paste0("count=", row$expected_count),
    paste0("occurrence=", row$literal_or_line_digest),
    if (nzchar(row$file_digest)) paste0("file=", row$file_digest) else "",
    "purpose=", row$rationale,
    sep = " | "
  )
}

seal_print_row_diff = function(before, candidate) {
  before_key = seal_row_key(before)
  candidate_key = seal_row_key(candidate)
  before_map = if (length(before_key)) {
    setNames(seq_along(before_key), before_key)
  } else {
    integer()
  }
  candidate_map = if (length(candidate_key)) {
    setNames(seq_along(candidate_key), candidate_key)
  } else {
    integer()
  }
  changed = intersect(names(before_map), names(candidate_map))
  changed = changed[
    !vapply(changed, function(key) identical(
      before[before_map[[key]], , drop = FALSE],
      candidate[candidate_map[[key]], , drop = FALSE]
    ), logical(1))
  ]
  for (key in setdiff(candidate_key, before_key)) {
    cat(seal_row_description(
      candidate[candidate_map[[key]], , drop = FALSE], "ADDED"
    ), "\n")
  }
  for (key in changed) {
    cat(seal_row_description(
      candidate[candidate_map[[key]], , drop = FALSE], "CHANGED"
    ), "\n")
  }
  for (key in setdiff(before_key, candidate_key)) {
    cat(seal_row_description(
      before[before_map[[key]], , drop = FALSE], "REMOVED"
    ), "\n")
  }
  if (!length(setdiff(candidate_key, before_key)) &&
      !length(changed) && !length(setdiff(before_key, candidate_key))) {
    cat("No exact-row changes.\n")
  }
}

seal_propose_exact_rows = function(
    root = seal_repository_root(),
    output_path) {
  root = seal_repository_root(root)
  output_path = seal_path_outside_root(output_path, root,
                                       "IDENTITY_RESEAL_OUTPUT_INSIDE_ROOT")
  if (file.exists(output_path) || dir.exists(output_path)) {
    seal_abort("IDENTITY_RESEAL_OUTPUT_EXISTS", output_path)
  }
  parent = dirname(output_path)
  if (!dir.exists(parent)) {
    seal_abort("IDENTITY_RESEAL_OUTPUT_PARENT_MISSING", parent)
  }
  before_head = seal_git_head(root)
  before_status = seal_git_status(root)
  before_tree = seal_tracked_tree_digest(root)
  policy = seal_validate_approved_workflow_policy(root)
  candidate = identity_build_occurrence_allowlist(root)
  current_path = file.path(
    root, "inst", "migration", "old-identity-allowlist.csv"
  )
  before = tryCatch(
    identity_read_historical_allowlist(current_path),
    error = function(error) NULL
  )
  utils::write.csv(
    candidate, output_path, row.names = FALSE, quote = TRUE, na = "",
    fileEncoding = "UTF-8"
  )
  seal_print_row_diff(before, candidate)
  after_head = seal_git_head(root)
  after_status = seal_git_status(root)
  after_tree = seal_tracked_tree_digest(root)
  if (!identical(before_head, after_head) ||
      !identical(before_status, after_status) ||
      !identical(before_tree, after_tree)) {
    seal_abort("IDENTITY_RESEAL_PROPOSAL_MUTATED")
  }
  cat("Phase 03 exact-row proposal: PASS\n")
  cat(sprintf("Before-Allowlist-SHA256: %s\n",
              if (is.null(before)) "unreadable" else
                seal_hash_file(current_path)))
  cat(sprintf("Candidate-Allowlist-SHA256: %s\n",
              seal_hash_file(output_path)))
  cat(sprintf("Policy-SHA256: %s\n", policy$policy$PolicySHA256))
  cat("Approval-State: proposal-only\n")
  invisible(list(
    clean = TRUE,
    candidate = candidate,
    candidate_path = output_path,
    candidate_sha256 = seal_hash_file(output_path),
    policy_sha256 = policy$policy$PolicySHA256
  ))
}

seal_qualification_stages = function() {
  c(
    "clean-state", "git-export", "extract", "source-identity", "build",
    "archive-identity", "check", "install", "install-identity",
    "fresh-workflow", "full-suite", "predecessor-digests",
    "historical-evidence", "phase02-original", "serialization-bugfix",
    "phase02-migration", "release-blockers", "repository-readonly"
  )
}

seal_qualification_parents = function() {
  c(
    "clean-state" = "ROOT",
    "git-export" = "clean-state",
    "extract" = "git-export",
    "source-identity" = "extract",
    "build" = "extract",
    "archive-identity" = "build",
    "check" = "build",
    "install" = "build",
    "install-identity" = "install",
    "fresh-workflow" = "install-identity",
    "full-suite" = "install-identity",
    "predecessor-digests" = "source-identity",
    "historical-evidence" = "source-identity",
    "phase02-original" = "source-identity",
    "serialization-bugfix" = "source-identity",
    "phase02-migration" = "source-identity",
    "release-blockers" = "source-identity",
    "repository-readonly" = "clean-state"
  )
}

seal_example_qualification_manifest = function() {
  stages = seal_qualification_stages()
  parents = seal_qualification_parents()
  outputs = vapply(
    stages,
    function(stage) seal_hash_raw(charToRaw(paste0("output:", stage))),
    character(1)
  )
  root_digest = seal_hash_raw(charToRaw("ROOT"))
  parent_digest = vapply(stages, function(stage) {
    parent = unname(parents[[stage]])
    if (identical(parent, "ROOT")) root_digest else
      unname(outputs[[parent]])
  }, character(1))
  result = vapply(stages, function(stage) {
    if (identical(stage, "phase02-original")) {
      "immutable original Phase 2 artifacts and accepted hash exact"
    } else if (identical(stage, "serialization-bugfix")) {
      "approved serialization BUGFIX before/after digest pair verified"
    } else if (identical(stage, "phase02-migration")) {
      "identity-normalized Phase 2 migration source gate passed"
    } else {
      paste0("stage ", stage, " passed with linked evidence")
    }
  }, character(1))
  command = paste0("stage:", stages)
  command[stages == "phase02-original"] =
    "Rscript --check-original-artifacts"
  command[stages == "serialization-bugfix"] =
    "Rscript --verify-approved"
  command[stages == "phase02-migration"] =
    "Rscript --check-migration-source"
  output = data.frame(
    Schema = rep("gemodelr-phase03-qualification-v1", length(stages)),
    Stage = stages,
    ParentStage = unname(parents[stages]),
    ParentDigest = parent_digest,
    InputDigest = parent_digest,
    OutputDigest = unname(outputs[stages]),
    Command = command,
    Status = rep("0", length(stages)),
    InputPath = paste0("input/", stages),
    LogSHA256 = vapply(
      stages,
      function(stage) seal_hash_raw(charToRaw(paste0("log:", stage))),
      character(1)
    ),
    Result = result,
    HEAD = rep(paste(rep("0", 40L), collapse = ""), length(stages)),
    ExportSHA256 = rep(seal_hash_raw(charToRaw("export")), length(stages)),
    ExtractedTreeSHA256 = rep(seal_hash_raw(charToRaw("extract")), length(stages)),
    PackageArchiveSHA256 = rep(seal_hash_raw(charToRaw("archive")), length(stages)),
    InstallationTreeSHA256 = rep(seal_hash_raw(charToRaw("install")), length(stages)),
    TemporaryRoot = rep("/tmp/qualification-root", length(stages)),
    Cleanup = rep("removed-after-emission", length(stages)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(output) = c(
    "Schema", "Stage", "Parent-Stage", "Parent-Digest", "Input-Digest",
    "Output-Digest", "Command", "Status", "Input-Path", "Log-SHA256",
    "Result", "HEAD", "Export-SHA256", "Extracted-Tree-SHA256",
    "Package-Archive-SHA256", "Installation-Tree-SHA256",
    "Temporary-Root", "Cleanup"
  )
  output
}

seal_manifest_frame_for_test = function(stages) {
  stages
}

seal_manifest_from_lines = function(lines) {
  begins = which(lines == "QUALIFICATION_MANIFEST_BEGIN")
  ends = which(lines == "QUALIFICATION_MANIFEST_END")
  if (length(begins) != 1L || length(ends) != 1L ||
      begins >= ends || ends - begins < 2L) {
    seal_abort("QUALIFICATION_TRANSCRIPT_MANIFEST_BOUNDS")
  }
  payload = lines[seq.int(begins + 1L, ends - 1L)]
  value = tryCatch(
    read.dcf(textConnection(paste0(payload, collapse = "\n"))),
    error = function(error) seal_abort(
      "QUALIFICATION_TRANSCRIPT_MANIFEST_INVALID", conditionMessage(error)
    )
  )
  value = as.data.frame(value, stringsAsFactors = FALSE,
                        check.names = FALSE)
  value[] = lapply(value, as.character)
  value
}

seal_validate_manifest = function(manifest) {
  required = c(
    "Schema", "Stage", "Parent-Stage", "Parent-Digest", "Input-Digest",
    "Output-Digest", "Command", "Status", "Input-Path", "Log-SHA256",
    "Result", "HEAD", "Export-SHA256", "Extracted-Tree-SHA256",
    "Package-Archive-SHA256", "Installation-Tree-SHA256",
    "Temporary-Root", "Cleanup"
  )
  if (!is.data.frame(manifest) || !identical(names(manifest), required)) {
    seal_abort("QUALIFICATION_TRANSCRIPT_MANIFEST_FIELDS")
  }
  manifest[] = lapply(manifest, as.character)
  stages = seal_qualification_stages()
  if (!identical(manifest$Stage, stages) ||
      anyDuplicated(manifest$Stage) ||
      anyNA(manifest) || any(!nzchar(as.matrix(manifest)))) {
    seal_abort("QUALIFICATION_TRANSCRIPT_STAGE_RECORD_INVALID")
  }
  if (!all(manifest$Schema == "gemodelr-phase03-qualification-v1") ||
      !all(manifest$Status == "0") ||
      !all(manifest$Cleanup == "removed-after-emission")) {
    seal_abort("QUALIFICATION_TRANSCRIPT_STAGE_STATUS")
  }
  if (any(!grepl("^[0-9a-f]{64}$", unlist(manifest[c(
    "Parent-Digest", "Input-Digest", "Output-Digest", "Log-SHA256",
    "Export-SHA256", "Extracted-Tree-SHA256",
    "Package-Archive-SHA256", "Installation-Tree-SHA256"
  )], use.names = FALSE))) ||
      any(!grepl("^[0-9a-f]{40}$", manifest$HEAD))) {
    seal_abort("QUALIFICATION_TRANSCRIPT_DIGEST")
  }
  parents = seal_qualification_parents()
  for (index in seq_along(stages)) {
    parent = unname(parents[[stages[[index]]]])
    expected = if (identical(parent, "ROOT")) {
      seal_hash_raw(charToRaw("ROOT"))
    } else {
      manifest[["Output-Digest"]][[match(parent, stages)]]
    }
    if (!identical(manifest[["Parent-Stage"]][[index]], parent) ||
        !identical(manifest[["Input-Digest"]][[index]],
                   manifest[["Parent-Digest"]][[index]]) ||
        !identical(manifest[["Parent-Digest"]][[index]], expected)) {
      seal_abort("QUALIFICATION_TRANSCRIPT_LINK")
    }
  }
  original = manifest[manifest$Stage == "phase02-original", , drop = FALSE]
  migration = manifest[manifest$Stage == "phase02-migration", , drop = FALSE]
  bugfix = manifest[manifest$Stage == "serialization-bugfix", , drop = FALSE]
  if (!grepl("--check-original-artifacts", original$Command) ||
      !grepl("--check-migration-source", migration$Command) ||
      identical(original$Command, migration$Command) ||
      !grepl("immutable original", original$Result, fixed = TRUE) ||
      !grepl("migration source gate", migration$Result, fixed = TRUE) ||
      !grepl("--verify-approved", bugfix$Command) ||
      !grepl("BUGFIX", bugfix$Result, fixed = TRUE)) {
    seal_abort("QUALIFICATION_TRANSCRIPT_STAGE_BINDING")
  }
  invisible(TRUE)
}

seal_verify_qualification_transcript = function(
    transcript_path,
    root = seal_repository_root()) {
  root = seal_repository_root(root)
  transcript_path = seal_path_outside_root(
    transcript_path, root, "QUALIFICATION_TRANSCRIPT_INSIDE_ROOT"
  )
  if (!file.exists(transcript_path) || dir.exists(transcript_path)) {
    seal_abort("QUALIFICATION_TRANSCRIPT_MISSING", transcript_path)
  }
  before_head = seal_git_head(root)
  before_status = seal_git_status(root)
  before_tree = seal_tracked_tree_digest(root)
  lines = readLines(transcript_path, warn = FALSE, encoding = "UTF-8")
  manifest = seal_manifest_from_lines(lines)
  seal_validate_manifest(manifest)
  digest_line = grep("^Qualification-Manifest-SHA256: [0-9a-f]{64}$",
                     lines, value = TRUE)
  head_line = grep("^Qualification-HEAD: [0-9a-f]{40}$",
                   lines, value = TRUE)
  if (length(digest_line) != 1L || length(head_line) != 1L) {
    seal_abort("QUALIFICATION_TRANSCRIPT_SUMMARY")
  }
  manifest_path = tempfile("qualification-transcript-manifest-",
                           fileext = ".dcf")
  on.exit(unlink(manifest_path, force = TRUE), add = TRUE)
  write.dcf(
    manifest, manifest_path, keep.white = names(manifest), useBytes = TRUE
  )
  observed_digest = seal_hash_file(manifest_path)
  emitted_digest = sub(
    "^Qualification-Manifest-SHA256: ", "", digest_line
  )
  if (!identical(observed_digest, emitted_digest) ||
      !identical(manifest$HEAD[[1L]],
                 sub("^Qualification-HEAD: ", "", head_line))) {
    seal_abort("QUALIFICATION_TRANSCRIPT_MANIFEST_DIGEST")
  }
  after_head = seal_git_head(root)
  after_status = seal_git_status(root)
  after_tree = seal_tracked_tree_digest(root)
  if (!identical(before_head, after_head) ||
      !identical(before_status, after_status) ||
      !identical(before_tree, after_tree)) {
    seal_abort("QUALIFICATION_TRANSCRIPT_REPOSITORY_MUTATED")
  }
  cat("Phase 03 qualification transcript gate: PASS\n")
  cat(sprintf("Qualification-HEAD: %s\n", manifest$HEAD[[1L]]))
  cat(sprintf("Qualification-Manifest-SHA256: %s\n", observed_digest))
  invisible(list(clean = TRUE, head = manifest$HEAD[[1L]],
                 manifest = manifest, manifest_digest = observed_digest))
}

seal_run_gate = function(root, relative, arguments, code, patterns) {
  script = file.path(root, relative)
  if (!file.exists(script)) seal_abort(code, script)
  rscript = file.path(R.home("bin"), "Rscript")
  output = suppressWarnings(system2(
    rscript, c("--vanilla", script, arguments),
    stdout = TRUE, stderr = TRUE
  ))
  status = attr(output, "status")
  if (!is.null(status) && status != 0L) {
    seal_abort(code, paste(output, collapse = " "))
  }
  text = paste(output, collapse = "\n")
  missing = patterns[!vapply(
    patterns, grepl, logical(1), x = text, fixed = TRUE
  )]
  if (length(missing)) seal_abort(code, paste(missing, collapse = " | "))
  invisible(output)
}

seal_check_final_tree = function(root = seal_repository_root()) {
  root = seal_repository_root(root)
  before_head = seal_git_head(root)
  before_status = seal_git_status(root)
  before_tree = seal_tracked_tree_digest(root)
  policy = seal_validate_approved_workflow_policy(root)
  review = seal_validate_reseal_review(root)
  identity = identity_check_occurrences(
    "tracked-source", root = root,
    allowlist_path = file.path(
      root, "inst", "migration", "old-identity-allowlist.csv"
    )
  )
  historical = identity_check_historical(root)
  seal_run_gate(
    root, file.path("tools", "check_predecessor_bridge.R"),
    "--verify-approved-digests", "IDENTITY_RESEAL_PREDECESSOR_GATE",
    "Approved predecessor evidence digests: PASS"
  )
  seal_run_gate(
    root, file.path("inst", "tools", "refresh_phase02_baselines.R"),
    "--check-original-artifacts", "IDENTITY_RESEAL_ORIGINAL_GATE",
    "Phase 02 original artifact gate: PASS"
  )
  seal_run_gate(
    root, file.path("tools", "check_serialization_bugfix.R"),
    "--verify-approved", "IDENTITY_RESEAL_BUGFIX_GATE",
    c("Serialization BUGFIX gate: PASS", "Change-Kind: BUGFIX")
  )
  after_head = seal_git_head(root)
  after_status = seal_git_status(root)
  after_tree = seal_tracked_tree_digest(root)
  if (!identical(before_head, after_head) ||
      !identical(before_status, after_status) ||
      !identical(before_tree, after_tree)) {
    seal_abort("IDENTITY_RESEAL_FINAL_TREE_MUTATED")
  }
  result = list(
    clean = TRUE,
    head = after_head,
    tracked_tree_sha256 = after_tree,
    workflow_policy_sha256 = policy$policy$PolicySHA256,
    unexpected_occurrences = 0L,
    stale_records = 0L,
    active_occurrences = identity$active_occurrences,
    workflow_occurrences = identity$workflow_occurrences,
    historical = historical,
    review = review
  )
  cat("Phase 03 final tracked-tree audit: PASS\n")
  cat(sprintf("HEAD: %s\n", result$head))
  cat(sprintf("Tracked-tree-SHA256: %s\n", result$tracked_tree_sha256))
  cat(sprintf("Workflow-policy-SHA256: %s\n",
              result$workflow_policy_sha256))
  cat(sprintf("Unexpected-occurrences: %s\n",
              result$unexpected_occurrences))
  cat(sprintf("Stale-records: %s\n", result$stale_records))
  invisible(result)
}

seal_verify_source_candidate = function(root, relative, candidate_text) {
  root = seal_repository_root(root)
  if (!is.character(relative) || length(relative) != 1L ||
      !relative %in% identity_git_tracked_paths(root)) {
    seal_abort("IDENTITY_RESEAL_SOURCE_PATH_INVALID", relative)
  }
  if (grepl(tolower(identity_old_token()), tolower(candidate_text),
            fixed = TRUE)) {
    seal_abort("IDENTITY_RESEAL_UNAPPROVED_SOURCE_LITERAL", relative)
  }
  invisible(TRUE)
}

seal_usage = function() {
  paste(
    "Usage:",
    "  rtk Rscript --vanilla tools/seal_phase03_identity.R",
    "--propose-exact-rows --output=/outside/candidate.csv",
    "  rtk Rscript --vanilla tools/seal_phase03_identity.R",
    "--check-final-tree",
    "  rtk Rscript --vanilla tools/seal_phase03_identity.R",
    "--verify-qualification-transcript=/outside/qualification.log",
    sep = "\n"
  )
}

seal_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  root_values = grep("^--root=", arguments, value = TRUE)
  if (length(root_values) > 1L) {
    seal_abort("IDENTITY_RESEAL_ROOT_ARGUMENT")
  }
  root = if (length(root_values)) {
    sub("^--root=", "", root_values[[1L]])
  } else {
    NULL
  }
  arguments = arguments[!startsWith(arguments, "--root=")]
  if (identical(arguments, "--check-final-tree")) {
    seal_check_final_tree(seal_repository_root(root))
    return(invisible(0L))
  }
  transcript = grep("^--verify-qualification-transcript=", arguments,
                    value = TRUE)
  if (length(transcript) == 1L && length(arguments) == 1L) {
    seal_verify_qualification_transcript(
      sub("^--verify-qualification-transcript=", "", transcript[[1L]]),
      root = seal_repository_root(root)
    )
    return(invisible(0L))
  }
  if ("--propose-exact-rows" %in% arguments) {
    output = grep("^--output=", arguments, value = TRUE)
    if (length(output) != 1L ||
        length(arguments) != 2L ||
        identical(arguments[[1L]], "--output")) {
      seal_abort("IDENTITY_RESEAL_PROPOSAL_ARGUMENT")
    }
    seal_propose_exact_rows(
      root = seal_repository_root(root),
      output_path = sub("^--output=", "", output[[1L]])
    )
    return(invisible(0L))
  }
  if (identical(arguments, "--help")) {
    cat(seal_usage(), "\n")
    return(invisible(0L))
  }
  seal_abort("IDENTITY_RESEAL_ARGUMENT_INVALID")
}

if (sys.nframe() == 0L) {
  status = tryCatch(
    seal_main(),
    error = function(error) {
      message(conditionMessage(error))
      1L
    }
  )
  if (is.numeric(status) && identical(as.integer(status), 1L)) {
    quit(save = "no", status = 1L, runLast = FALSE)
  }
}

