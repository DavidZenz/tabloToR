#!/usr/bin/env Rscript

output_rel <- file.path(
  ".planning", "phases", "06-documentation-and-release-qualification",
  "06-15-provenance-reconciliation"
)
report_name <- "PROVENANCE-RECONCILIATION.md"
delta_name <- "candidate-review-delta.csv"
manifest_name <- "SHA256SUMS"
auxiliary_inputs <- c(
  "docs/provenance/EXPECTED-KEYS.csv",
  "docs/provenance/PROVENANCE.csv",
  "tools/provenance_inventory.R"
)

abort <- function(message) stop(message, call. = FALSE)

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) abort("cannot determine generator path")
script_path <- normalizePath(
  sub("^--file=", "", script_argument), winslash = "/", mustWork = TRUE
)

option_value <- function(args, name, default = NULL) {
  exact <- which(args == name)
  if (length(exact)) {
    id <- exact[[1L]]
    if (id == length(args)) abort(paste("missing value for", name))
    return(args[[id + 1L]])
  }
  prefix <- paste0(name, "=")
  inline <- args[startsWith(args, prefix)]
  if (length(inline)) return(sub(prefix, "", inline[[1L]], fixed = TRUE))
  default
}

git_executable <- function() {
  candidates <- unique(c("/usr/bin/git", unname(Sys.which("git"))))
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  for (candidate in candidates) {
    status <- suppressWarnings(system2(
      candidate, "--version", stdout = FALSE, stderr = FALSE
    ))
    if (identical(as.integer(status), 0L)) return(candidate)
  }
  abort("git is unavailable or cannot run with the installed system libraries")
}

git_run <- function(root, args, allow_failure = FALSE) {
  output <- suppressWarnings(system2(
    git_executable(), c("-C", shQuote(root), args),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (!identical(as.integer(status), 0L) && !isTRUE(allow_failure)) {
    abort(paste("git command failed:", paste(args, collapse = " "),
                paste(output, collapse = "\n")))
  }
  list(output = output, status = as.integer(status))
}

sha256_files <- function(paths) {
  if (!length(paths) || any(!file.exists(paths))) abort("SHA-256 input is missing")
  rtk <- Sys.which("rtk")
  if (!nzchar(rtk)) abort("rtk is required to calculate SHA-256 digests")
  output <- suppressWarnings(system2(
    rtk,
    c("proxy", "sha256sum", "--binary", vapply(paths, shQuote, character(1))),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) {
    abort(paste("sha256sum failed:", paste(output, collapse = "\n")))
  }
  hashes <- vapply(output, function(line) {
    match <- regexec("^([[:xdigit:]]{64})[[:space:]]+", line, perl = TRUE)
    value <- regmatches(line, match)[[1L]]
    if (length(value) != 2L) abort(paste("cannot parse sha256sum output:", line))
    tolower(value[[2L]])
  }, character(1))
  if (length(hashes) != length(paths)) abort("unexpected sha256sum output count")
  names(hashes) <- paths
  hashes
}

sha256_file <- function(path) unname(sha256_files(path)[[1L]])

sha256_text <- function(value) {
  path <- tempfile("06-15-provenance-fingerprint-")
  on.exit(unlink(path), add = TRUE)
  connection <- file(path, open = "wb")
  tryCatch(
    writeBin(charToRaw(enc2utf8(value)), connection),
    finally = close(connection)
  )
  sha256_file(path)
}

read_report_field <- function(path, field) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  match <- grep(paste0("^", field, "="), lines, value = TRUE)
  if (length(match) != 1L) abort(paste("missing or duplicate report field:", field))
  sub("^[^=]*=", "", match[[1L]])
}

relative_paths <- function(paths, root) {
  vapply(paths, function(path) {
    canonical <- normalizePath(path, winslash = "/", mustWork = TRUE)
    prefix <- if (endsWith(root, "/")) root else paste0(root, "/")
    if (!startsWith(canonical, prefix)) abort("input path escaped the repository root")
    substring(canonical, nchar(prefix) + 1L)
  }, character(1))
}

source_input_paths <- function(root) {
  source_files <- provenance_source_files(root)
  source_rel <- vapply(source_files, provenance_relative_path, character(1), root = root)
  paths <- unname(sort(unique(c(source_rel, auxiliary_inputs)), method = "radix"))
  missing <- paths[!file.exists(file.path(root, paths))]
  if (length(missing)) abort(paste("inventoried input is missing:", paste(missing, collapse = ", ")))
  paths
}

tree_input_paths <- function(root, commit) {
  tracked <- git_run(root, c(
    "ls-tree", "-r", "--name-only", commit, "--",
    "R", "src", "inst/cpp", auxiliary_inputs
  ))$output
  source <- tracked[
    grepl("^R/.+\\.R$", tracked, ignore.case = TRUE) |
      grepl("^(src|inst/cpp)/.+\\.(c|cc|cpp|cxx|h|hpp)$", tracked,
            ignore.case = TRUE)
  ]
  paths <- unname(sort(unique(c(source, auxiliary_inputs)), method = "radix"))
  missing <- setdiff(auxiliary_inputs, tracked)
  if (length(missing)) abort(paste("required input is absent from commit tree:",
                                   paste(missing, collapse = ", ")))
  paths
}

git_blob_id <- function(root, commit, relative) {
  result <- git_run(root, c("rev-parse", "--verify", paste0(commit, ":", relative)),
                    allow_failure = TRUE)
  if (result$status != 0L || length(result$output) != 1L) {
    abort(paste("input path is absent from recorded commit:", relative))
  }
  result$output[[1L]]
}

working_blob_id <- function(root, relative) {
  result <- git_run(root, c("hash-object", "--no-filters", "--", relative))
  if (length(result$output) != 1L) abort(paste("cannot hash input path:", relative))
  result$output[[1L]]
}

input_fingerprint <- function(root, paths) {
  digests <- sha256_files(file.path(root, paths))
  sizes <- file.info(file.path(root, paths))$size
  records <- paste(
    nchar(paths, type = "bytes"), paths, format(sizes, scientific = FALSE),
    unname(digests), sep = "\t"
  )
  sha256_text(paste0(paste(records, collapse = "\n"), "\n"))
}

compare_input_tree <- function(root, commit, paths) {
  tracked_paths <- tree_input_paths(root, commit)
  if (!identical(unname(sort(paths, method = "radix")), tracked_paths)) {
    missing <- setdiff(tracked_paths, paths)
    additional <- setdiff(paths, tracked_paths)
    abort(paste(
      "current inventoried input paths differ from the recorded tree;",
      paste0("missing=[", paste(missing, collapse = ","), "]"),
      paste0("additional=[", paste(additional, collapse = ","), "]")
    ))
  }
  changed <- paths[vapply(paths, function(path) {
    !identical(working_blob_id(root, path), git_blob_id(root, commit, path))
  }, logical(1))]
  if (length(changed)) {
    abort(paste("inventoried input bytes differ from", commit, ":",
                paste(changed, collapse = ", ")))
  }
  invisible(TRUE)
}

validate_clean_detached_snapshot <- function(root) {
  commit <- git_run(root, c("rev-parse", "HEAD"))$output[[1L]]
  branch <- git_run(root, c("rev-parse", "--abbrev-ref", "HEAD"))$output[[1L]]
  if (!identical(branch, "HEAD")) abort("snapshot worktree is not detached")
  status <- git_run(root, c("status", "--porcelain", "--untracked-files=all"))$output
  if (length(status)) abort(paste("source snapshot is dirty:", paste(status, collapse = " | ")))
  commit
}

read_csv <- function(path, columns = NULL) {
  value <- tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                    colClasses = "character", na.strings = NULL),
    error = function(error) abort(paste("invalid CSV:", path, conditionMessage(error)))
  )
  value[] <- lapply(value, as.character)
  if (!is.null(columns) && !identical(names(value), columns)) {
    abort(paste("unexpected CSV columns:", path))
  }
  value
}

write_csv <- function(value, path) {
  utils::write.csv(value, path, row.names = FALSE, na = "")
}

make_delta <- function(inventory, expected, ledger, input_commit,
                       source_snapshot_sha256) {
  source_keys <- provenance_key_frame(inventory)
  expected_keys <- provenance_key_frame(expected)
  ledger_keys <- provenance_key_frame(ledger)
  if (anyDuplicated(source_keys) || anyDuplicated(expected_keys) ||
      anyDuplicated(ledger_keys)) abort("duplicate source or canonical provenance key")

  columns <- c(
    "change", "input_commit", "source_snapshot_sha256", "path", "symbol",
    "source_present", "expected_present", "ledger_present",
    "line_start", "line_end", "before_expression_hash_md5",
    "after_expression_hash_md5", "prior_classification",
    "first_local_commit_audit_only", "git_contributors_audit_only",
    "identity_evidence_status", "author", "copyright_holder", "license_basis",
    "reviewer", "review_date"
  )
  rows <- list()
  add_row <- function(change, key, source_id = NA_integer_,
                      expected_id = NA_integer_, ledger_id = NA_integer_) {
    path_symbol <- strsplit(key, "::", fixed = TRUE)[[1L]]
    if (length(path_symbol) < 2L) abort("invalid path/symbol provenance key")
    source_present <- !is.na(source_id)
    expected_present <- !is.na(expected_id)
    ledger_present <- !is.na(ledger_id)
    rows[[length(rows) + 1L]] <<- data.frame(
      change = change,
      input_commit = input_commit,
      source_snapshot_sha256 = source_snapshot_sha256,
      path = path_symbol[[1L]],
      symbol = paste(path_symbol[-1L], collapse = "::"),
      source_present = as.character(source_present),
      expected_present = as.character(expected_present),
      ledger_present = as.character(ledger_present),
      line_start = if (source_present) inventory$line_start[[source_id]] else "",
      line_end = if (source_present) inventory$line_end[[source_id]] else "",
      before_expression_hash_md5 = if (ledger_present) ledger$expression_hash[[ledger_id]] else "",
      after_expression_hash_md5 = if (source_present) inventory$expression_hash[[source_id]] else "",
      prior_classification = if (ledger_present) ledger$classification[[ledger_id]] else "",
      first_local_commit_audit_only = if (source_present) inventory$first_local_commit[[source_id]] else "",
      git_contributors_audit_only = if (source_present) inventory$contributors[[source_id]] else "",
      identity_evidence_status = "unreviewed",
      author = "", copyright_holder = "", license_basis = "",
      reviewer = "", review_date = "",
      stringsAsFactors = FALSE
    )
  }

  missing <- setdiff(expected_keys, source_keys)
  for (key in missing) {
    expected_id <- match(key, expected_keys)
    add_row("missing-key", key, expected_id = expected_id,
            ledger_id = match(key, ledger_keys))
  }
  extra <- setdiff(source_keys, expected_keys)
  for (key in extra) {
    source_id <- match(key, source_keys)
    add_row("extra-key", key, source_id = source_id,
            ledger_id = match(key, ledger_keys))
  }
  common <- intersect(source_keys, expected_keys)
  for (key in common) {
    source_id <- match(key, source_keys)
    expected_id <- match(key, expected_keys)
    ledger_id <- match(key, ledger_keys)
    if (is.na(ledger_id)) {
      add_row("canonical-ledger-missing-key", key, source_id,
              expected_id = expected_id)
    } else if (!identical(inventory$expression_hash[[source_id]],
                          ledger$expression_hash[[ledger_id]])) {
      add_row("changed-hash", key, source_id, expected_id, ledger_id)
    }
  }
  ledger_extra <- setdiff(ledger_keys, expected_keys)
  for (key in ledger_extra) {
    add_row("canonical-ledger-extra-key", key,
            source_id = match(key, source_keys), ledger_id = match(key, ledger_keys))
  }
  if (!length(rows)) {
    delta <- as.data.frame(setNames(replicate(length(columns), character(), simplify = FALSE), columns),
                           stringsAsFactors = FALSE)
  } else {
    delta <- do.call(rbind, rows)
  }
  delta <- delta[, columns, drop = FALSE]
  delta <- delta[order(delta$change, delta$path, delta$symbol, method = "radix"), , drop = FALSE]
  rownames(delta) <- NULL
  list(
    delta = delta,
    counts = c(
      missing_key_count = length(missing),
      extra_key_count = length(extra),
      changed_hash_count = sum(delta$change == "changed-hash"),
      canonical_ledger_missing_key_count = sum(delta$change == "canonical-ledger-missing-key"),
      canonical_ledger_extra_key_count = length(ledger_extra),
      review_delta_row_count = nrow(delta)
    )
  )
}

manifest_entries <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(trimws(lines)) & !startsWith(trimws(lines), "#")]
  values <- lapply(lines, function(line) {
    match <- regexec("^([[:xdigit:]]{64})[[:space:]]+\\*?(.+)$", line, perl = TRUE)
    parts <- regmatches(line, match)[[1L]]
    if (length(parts) != 3L) abort(paste("invalid SHA256SUMS line:", line))
    c(hash = tolower(parts[[2L]]), path = parts[[3L]])
  })
  if (!length(values)) abort("SHA256SUMS is empty")
  do.call(rbind, values)
}

check_outputs <- function(root, out_dir) {
  report <- file.path(out_dir, report_name)
  delta_path <- file.path(out_dir, delta_name)
  manifest <- file.path(out_dir, manifest_name)
  for (path in c(report, delta_path, manifest, script_path)) {
    if (!file.exists(path)) abort(paste("proposal output is missing:", path))
  }
  entries <- manifest_entries(manifest)
  script_rel <- relative_paths(script_path, root)
  report_rel <- relative_paths(report, root)
  delta_rel <- relative_paths(delta_path, root)
  expected_paths <- unname(c(script_rel, report_rel, delta_rel))
  if (anyDuplicated(entries[, "path"]) ||
      !identical(sort(entries[, "path"], method = "radix"),
                 sort(expected_paths, method = "radix"))) {
    abort("SHA256SUMS does not bind exactly the generator, report, and delta")
  }
  ordered_entries <- entries[match(expected_paths, entries[, "path"]), , drop = FALSE]
  actual <- sha256_files(file.path(root, ordered_entries[, "path"]))
  if (!identical(unname(actual), unname(ordered_entries[, "hash"]))) {
    abort("SHA256SUMS digest mismatch")
  }
  if (!identical(read_report_field(report, "generator_sha256"),
                 unname(sha256_files(script_path)[[1L]]))) {
    abort("report generator digest mismatch")
  }
  if (!identical(read_report_field(report, "candidate_delta_sha256"),
                 unname(sha256_files(delta_path)[[1L]]))) {
    abort("report delta digest mismatch")
  }
  delta <- read_csv(delta_path)
  counts <- table(factor(delta$change, levels = c(
    "missing-key", "extra-key", "changed-hash",
    "canonical-ledger-missing-key", "canonical-ledger-extra-key"
  )))
  count_fields <- c(
    "missing_key_count", "extra_key_count", "changed_hash_count",
    "canonical_ledger_missing_key_count", "canonical_ledger_extra_key_count",
    "review_delta_row_count"
  )
  expected_counts <- c(as.integer(counts), nrow(delta))
  actual_counts <- vapply(count_fields, function(field) {
    value <- read_report_field(report, field)
    if (!grepl("^[0-9]+$", value)) abort(paste("invalid report count:", field))
    as.integer(value)
  }, integer(1))
  if (!identical(unname(actual_counts), unname(expected_counts))) {
    abort("report counts do not match candidate delta")
  }
  invisible(list(report = report, delta = delta_path, manifest = manifest))
}

generate_candidate <- function(root, snapshot_root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  snapshot_root <- normalizePath(snapshot_root, winslash = "/", mustWork = TRUE)
  out_dir <- file.path(root, output_rel)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  report_path <- file.path(out_dir, report_name)
  delta_path <- file.path(out_dir, delta_name)
  manifest_path <- file.path(out_dir, manifest_name)
  if (any(file.exists(c(report_path, delta_path, manifest_path)))) {
    abort("candidate outputs already exist; preserve them and inspect before regenerating")
  }
  source(file.path(snapshot_root, "tools", "provenance_inventory.R"), local = .GlobalEnv)
  snapshot_commit <- validate_clean_detached_snapshot(snapshot_root)
  snapshot_paths <- source_input_paths(snapshot_root)
  compare_input_tree(snapshot_root, snapshot_commit, snapshot_paths)
  source_snapshot_sha256 <- input_fingerprint(snapshot_root, snapshot_paths)

  inventory <- provenance_collect_sources(snapshot_root, include_git = TRUE)
  expected <- read_csv(file.path(snapshot_root, auxiliary_inputs[[1L]]), c("path", "symbol"))
  ledger <- read_csv(file.path(snapshot_root, auxiliary_inputs[[2L]]), provenance_columns)
  candidate <- make_delta(inventory, expected, ledger, snapshot_commit,
                          source_snapshot_sha256)

  stage <- tempfile(".06-15-provenance-stage-", tmpdir = dirname(out_dir))
  if (!dir.create(stage)) abort("cannot create proposal staging directory")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  staged_delta <- file.path(stage, delta_name)
  staged_report <- file.path(stage, report_name)
  staged_manifest <- file.path(stage, manifest_name)
  write_csv(candidate$delta, staged_delta)
  delta_sha256 <- sha256_file(staged_delta)
  generator_sha256 <- sha256_file(script_path)
  counts <- candidate$counts
  report_lines <- c(
    "# Phase 06-15 provenance reconciliation proposal",
    "",
    paste0("input_commit=", snapshot_commit),
    paste0("source_snapshot_sha256=", source_snapshot_sha256),
    paste0("source_snapshot_input_file_count=", length(snapshot_paths)),
    paste0("generator_sha256=", generator_sha256),
    paste0("candidate_delta_sha256=", delta_sha256),
    paste0("missing_key_count=", counts[["missing_key_count"]]),
    paste0("extra_key_count=", counts[["extra_key_count"]]),
    paste0("changed_hash_count=", counts[["changed_hash_count"]]),
    paste0("canonical_ledger_missing_key_count=", counts[["canonical_ledger_missing_key_count"]]),
    paste0("canonical_ledger_extra_key_count=", counts[["canonical_ledger_extra_key_count"]]),
    paste0("review_delta_row_count=", counts[["review_delta_row_count"]]),
    "",
    "## Comparison scope",
    "",
    paste0("The detached, clean input tree at `", snapshot_commit,
           "` was inventoried with its tracked R/C/C++ source files under `R/`, `src/`, and `inst/cpp/`."),
    "The SHA-256 source snapshot fingerprint binds the raw bytes and relative paths of those files,",
    "`tools/provenance_inventory.R`, and the canonical `EXPECTED-KEYS.csv` and `PROVENANCE.csv` inputs.",
    "The input fingerprint excludes proposal outputs and other metadata outside this inventoried input set.",
    "",
    "The review delta compares the clean source inventory with the canonical expected keys and ledger from the same input commit.",
    "`before_expression_hash_md5` and `after_expression_hash_md5` are exact expression digests from the existing inventory convention;",
    "the SHA-256 snapshot and proposal digests bind the corresponding input and output bytes.",
    "",
    "## Exact delta counts",
    "",
    paste0("- Missing source keys present in the canonical expected-key list: ", counts[["missing_key_count"]]),
    paste0("- Source keys absent from the canonical expected-key list: ", counts[["extra_key_count"]]),
    paste0("- Matching source keys with a changed ledger expression hash: ", counts[["changed_hash_count"]]),
    paste0("- Expected keys with no canonical ledger row: ", counts[["canonical_ledger_missing_key_count"]]),
    paste0("- Canonical ledger keys absent from the expected-key list: ", counts[["canonical_ledger_extra_key_count"]]),
    paste0("- Total review-delta rows: ", counts[["review_delta_row_count"]]),
    "",
    "The CSV gives each row's path, symbol, source line range where present, input commit, source snapshot digest,",
    "and exact before/after expression digests. Source lines and Git history are investigative leads only.",
    "Git-derived first-commit and contributor fields are marked audit-only and do not establish identity, authorship,",
    "copyright, license rights, or attribution. The proposed author, copyright, license-basis, reviewer, and review-date fields are blank.",
    "No canonical provenance, attribution, or release-blocker record was changed.",
    "",
    "## Preserved documentation and release decisions",
    "",
    "- D-01: retain the pkgdown GitHub Pages site alongside package vignettes.",
    "- D-02: keep user guides, API reference, migration, architecture, and contributor guidance in the site; keep detailed release/provenance evidence repository-only.",
    "- D-03: retain the five focused vignette topics.",
    "- D-04: keep normal builds on small redistributable fixtures; document but do not run the external full-scale benchmark.",
    "- D-05: retain the adopted pre-1.0 and post-1.0 lifecycle/deprecation policy and identify 0.1.0 as development-only.",
    "",
    "## Review boundary",
    "",
    "This is an unapproved proposal. Review every delta row against evidence that independently establishes the relevant source identity and rights.",
    "A Git author name or commit message alone is insufficient. Do not populate attribution facts by inference.",
    "Canonical files remain unchanged until the exact input commit and delta digest are approved in the separate review step.",
    "The generator and immutable report/delta output digests are listed in `SHA256SUMS`; the report's own digest is also in that manifest."
  )
  writeLines(report_lines, staged_report, useBytes = TRUE)

  script_rel <- relative_paths(script_path, root)
  report_rel <- file.path(output_rel, report_name)
  delta_rel <- file.path(output_rel, delta_name)
  staged_hashes <- c(
    sha256_file(script_path), sha256_file(staged_report), sha256_file(staged_delta)
  )
  manifest_lines <- paste0(staged_hashes, "  ", c(script_rel, report_rel, delta_rel))
  writeLines(manifest_lines, staged_manifest, useBytes = TRUE)
  if (!identical(delta_sha256, sha256_file(staged_delta)) ||
      !identical(read_report_field(staged_report, "candidate_delta_sha256"), delta_sha256) ||
      !identical(read_report_field(staged_report, "generator_sha256"), generator_sha256)) {
    abort("candidate delta or generator changed between report creation and manifest binding")
  }

  staged_paths <- c(staged_report, staged_delta, staged_manifest)
  final_paths <- c(report_path, delta_path, manifest_path)
  created <- character()
  for (id in seq_along(staged_paths)) {
    if (!file.rename(staged_paths[[id]], final_paths[[id]])) {
      unlink(created)
      abort("could not publish the complete proposal output set")
    }
    created <- c(created, final_paths[[id]])
  }
  check_outputs(root, out_dir)
  message(sprintf(
    "proposal_status=generated input_commit=%s source_snapshot_sha256=%s missing=%d extra=%d changed_hash=%d delta_rows=%d delta_sha256=%s",
    snapshot_commit, source_snapshot_sha256,
    counts[["missing_key_count"]], counts[["extra_key_count"]],
    counts[["changed_hash_count"]], counts[["review_delta_row_count"]], delta_sha256
  ))
  invisible(candidate)
}

verify_input_snapshot <- function(root, out_dir) {
  checked <- check_outputs(root, out_dir)
  report <- checked$report
  commit <- read_report_field(report, "input_commit")
  expected_sha <- read_report_field(report, "source_snapshot_sha256")
  source(file.path(root, "tools", "provenance_inventory.R"), local = .GlobalEnv)
  paths <- source_input_paths(root)
  compare_input_tree(root, commit, paths)
  actual_sha <- input_fingerprint(root, paths)
  if (!identical(actual_sha, expected_sha)) abort("source snapshot fingerprint differs from approved proposal")
  message(sprintf("input_snapshot_status=verified input_commit=%s source_snapshot_sha256=%s files=%d",
                  commit, actual_sha, length(paths)))
  invisible(TRUE)
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  modes <- args[args %in% c("--generate", "--check", "--verify-input-snapshot")]
  if (length(modes) != 1L) {
    abort("choose exactly one mode: --generate, --check, or --verify-input-snapshot")
  }
  root <- normalizePath(option_value(args, "--root", "."), winslash = "/", mustWork = TRUE)
  out_dir <- file.path(root, output_rel)
  if (identical(modes[[1L]], "--generate")) {
    snapshot_root <- option_value(args, "--snapshot-root", NULL)
    if (is.null(snapshot_root)) abort("--generate requires --snapshot-root")
    generate_candidate(root, snapshot_root)
  } else if (identical(modes[[1L]], "--check")) {
    check_outputs(root, out_dir)
    message("proposal_status=integrity_check_pass")
  } else {
    verify_input_snapshot(root, out_dir)
  }
}

tryCatch(
  main(),
  error = function(error) {
    message(conditionMessage(error))
    quit(save = "no", status = 1L, runLast = FALSE)
  }
)
