#!/usr/bin/env Rscript

phase02_accept_script_path = local({
  file_argument = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_argument)) {
    normalizePath(sub("^--file=", "", file_argument[[1L]]), mustWork = TRUE)
  } else {
    source_file = tryCatch(sys.frame(1L)$ofile, error = function(error) NULL)
    if (is.null(source_file)) NA_character_ else
      normalizePath(source_file, mustWork = TRUE)
  }
})

phase02_accept_root = function() {
  if (!is.na(phase02_accept_script_path)) {
    candidate = dirname(dirname(phase02_accept_script_path))
    if (file.exists(file.path(candidate, "DESCRIPTION"))) return(candidate)
  }
  working = normalizePath(getwd(), mustWork = TRUE)
  while (TRUE) {
    if (file.exists(file.path(working, "DESCRIPTION")) &&
        file.exists(file.path(working, "tools",
                              "refresh_phase02_baselines.R"))) {
      return(working)
    }
    parent = dirname(working)
    if (identical(parent, working)) break
    working = parent
  }
  stop("Could not locate the package repository root", call. = FALSE)
}

sys.source(
  file.path(phase02_accept_root(), "tools", "refresh_phase02_baselines.R"),
  envir = environment()
)

phase02_accept_text = function(value, name, maximum) {
  if (is.null(value) || length(value) != 1L || is.na(value) ||
      !nzchar(trimws(value))) {
    stop(sprintf("A non-empty %s is required", name), call. = FALSE)
  }
  value = trimws(value)
  if (nchar(value, type = "bytes") > maximum || grepl("[\r\n]", value)) {
    stop(sprintf("The %s is invalid or too long", name), call. = FALSE)
  }
  value
}

phase02_validate_proposal = function(proposal, canonical_dir) {
  if (is.null(proposal) || length(proposal) != 1L || is.na(proposal) ||
      !dir.exists(proposal)) {
    stop("The proposal directory does not exist", call. = FALSE)
  }
  proposal = normalizePath(proposal, mustWork = TRUE)
  canonical_dir = normalizePath(canonical_dir, mustWork = TRUE)
  if (phase02_path_contains(canonical_dir, proposal) ||
      phase02_path_contains(proposal, canonical_dir)) {
    stop("The proposal directory overlaps the canonical baseline",
         call. = FALSE)
  }
  required = c(
    phase02_stable_artifact_names(), "run-metadata.dcf", "proposal.dcf",
    "DIFF.md"
  )
  paths = file.path(proposal, required)
  if (any(!file.exists(paths)) || any(dir.exists(paths))) {
    stop("The proposal is missing a required regular artifact",
         call. = FALSE)
  }
  if (any(nzchar(Sys.readlink(paths)))) {
    stop("The proposal contains a symbolic-link artifact", call. = FALSE)
  }
  sizes = file.info(paths)$size
  if (any(!is.finite(sizes)) || any(sizes > phase02_max_artifact_bytes()) ||
      sum(sizes) > 1024^2) {
    stop("The proposal exceeds the accepted size bounds", call. = FALSE)
  }
  manifest = tryCatch(
    read.dcf(file.path(proposal, "proposal.dcf")),
    error = function(error) stop("The proposal manifest is corrupt",
                                 call. = FALSE)
  )
  if (nrow(manifest) != 1L || !all(c("Schema", "Proposal-Hash") %in%
                                    colnames(manifest)) ||
      !identical(unname(manifest[1L, "Schema"]),
                 "phase02-baseline-proposal-v1")) {
    stop("The proposal manifest has an unsupported schema", call. = FALSE)
  }
  declared = unname(manifest[1L, "Proposal-Hash"])
  actual = phase02_artifact_hash(proposal)
  if (!identical(declared, actual)) {
    stop("The proposal hash does not match its stable artifacts",
         call. = FALSE)
  }
  comparison = phase02_diff_frame(canonical_dir, proposal)
  expected_diff = phase02_render_diff(comparison)
  actual_diff = readLines(file.path(proposal, "DIFF.md"), warn = FALSE)
  if (!identical(actual_diff, expected_diff)) {
    stop("The proposal diff is stale relative to the canonical baseline",
         call. = FALSE)
  }
  list(path = proposal, hash = actual, comparison = comparison)
}

phase02_acceptance_record = function(reviewer, reason, proposal_hash,
                                      old_hash, new_hash,
                                      fingerprints, tolerances) {
  ordinary = tolerances[
    tolerances$fixture == "three-region" &
      tolerances$conditioning == "ordinary", , drop = FALSE
  ]
  c(
    "# Phase 02 Baseline Acceptance", "",
    paste0("- **Reviewer:** ", reviewer),
    paste0("- **Reason:** ", reason),
    paste0("- **Accepted-UTC:** ",
           format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste0("- **Proposal-Hash:** `", proposal_hash, "`"),
    paste0("- **Old-Canonical-Hash:** `", old_hash, "`"),
    paste0("- **New-Canonical-Hash:** `", new_hash, "`"),
    paste0("- **Fixture-MD5:** `", fingerprints[["Fixture-MD5"]], "`"),
    paste0("- **Source-Fingerprint:** `",
           fingerprints[["Source-Fingerprint"]], "`"),
    paste0("- **Tolerance-Tier:** ", ordinary$tier[[1L]],
           " (solution atol ", ordinary$solution_atol[[1L]],
           ", rtol ", ordinary$solution_rtol[[1L]],
           "; residual rtol ", ordinary$residual_rtol[[1L]], ")"),
    "",
    paste(
      "Only the compact stable artifacts listed in `proposal.dcf` were",
      "accepted. Volatile run metadata remains review evidence and external",
      "GTAP inputs and full solutions remain outside the repository."
    )
  )
}

phase02_accept_proposal = function(
    proposal, reviewer, reason, canonical_dir = phase02_canonical_dir(),
    dry_run = FALSE) {
  reviewer = phase02_accept_text(reviewer, "reviewer", 200L)
  reason = phase02_accept_text(reason, "reason", 2000L)
  if (!is.logical(dry_run) || length(dry_run) != 1L || is.na(dry_run)) {
    stop("dry_run must be TRUE or FALSE", call. = FALSE)
  }
  canonical_dir = normalizePath(canonical_dir, mustWork = TRUE)
  validated = phase02_validate_proposal(proposal, canonical_dir)
  old_hash = phase02_artifact_hash(canonical_dir)
  staging = tempfile("phase02-accept-staging-", tmpdir = dirname(canonical_dir))
  if (!dir.create(staging)) {
    stop("Could not create the canonical acceptance staging directory",
         call. = FALSE)
  }
  on.exit(unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)
  stable = phase02_stable_artifact_names()
  if (!all(file.copy(file.path(validated$path, stable),
                     file.path(staging, stable)))) {
    stop("Could not stage all proposal artifacts", call. = FALSE)
  }
  new_hash = phase02_artifact_hash(staging)
  if (!identical(new_hash, validated$hash)) {
    stop("The staged canonical hash does not match the proposal hash",
         call. = FALSE)
  }
  fingerprints = as.list(read.dcf(
    file.path(staging, "fingerprints.dcf")
  )[1L, ])
  tolerances = read.csv(
    file.path(staging, "tolerances.csv"), stringsAsFactors = FALSE,
    check.names = FALSE
  )
  record = phase02_acceptance_record(
    reviewer, reason, validated$hash, old_hash, new_hash,
    fingerprints, tolerances
  )
  if (isTRUE(dry_run)) {
    return(invisible(list(
      dry_run = TRUE, proposal_hash = validated$hash,
      old_canonical_hash = old_hash, new_canonical_hash = new_hash,
      record = record
    )))
  }

  backup = tempfile("phase02-accept-backup-", tmpdir = dirname(canonical_dir))
  dir.create(backup)
  on.exit(unlink(backup, recursive = TRUE, force = TRUE), add = TRUE)
  existing = c(stable, "ACCEPTANCE.md")
  existing = existing[file.exists(file.path(canonical_dir, existing))]
  if (length(existing) && !all(file.copy(
    file.path(canonical_dir, existing), file.path(backup, existing)
  ))) {
    stop("Could not back up the canonical baseline", call. = FALSE)
  }
  committed = FALSE
  on.exit({
    if (!committed) {
      for (name in stable) unlink(file.path(canonical_dir, name))
      if (file.exists(file.path(canonical_dir, "ACCEPTANCE.md"))) {
        unlink(file.path(canonical_dir, "ACCEPTANCE.md"))
      }
      if (length(existing)) file.copy(
        file.path(backup, existing), file.path(canonical_dir, existing),
        overwrite = TRUE
      )
    }
  }, add = TRUE)
  if (!all(file.copy(file.path(staging, stable),
                     file.path(canonical_dir, stable), overwrite = TRUE))) {
    stop("Could not replace all canonical baseline artifacts", call. = FALSE)
  }
  acceptance_temp = tempfile("phase02-acceptance-", tmpdir = canonical_dir)
  writeLines(record, acceptance_temp, useBytes = TRUE)
  if (!file.rename(acceptance_temp,
                   file.path(canonical_dir, "ACCEPTANCE.md"))) {
    unlink(acceptance_temp)
    stop("Could not publish ACCEPTANCE.md", call. = FALSE)
  }
  if (!identical(phase02_artifact_hash(canonical_dir), new_hash)) {
    stop("Canonical verification failed after acceptance", call. = FALSE)
  }
  committed = TRUE
  invisible(list(
    dry_run = FALSE, proposal_hash = validated$hash,
    old_canonical_hash = old_hash, new_canonical_hash = new_hash,
    acceptance = file.path(canonical_dir, "ACCEPTANCE.md")
  ))
}

phase02_accept_usage = function() {
  paste(
    "Usage:",
    paste0(
      "  rtk Rscript --vanilla tools/accept_phase02_baselines.R ",
      "--proposal=<proposal-dir> --reviewer=<name> --reason=<text>"
    ),
    "  Add --dry-run to validate and preview without changing canonical files.",
    sep = "\n"
  )
}

phase02_accept_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  if ("--help" %in% arguments) {
    cat(phase02_accept_usage(), "\n")
    return(invisible(0L))
  }
  allowed = startsWith(arguments, "--proposal=") |
    startsWith(arguments, "--reviewer=") |
    startsWith(arguments, "--reason=") | arguments == "--dry-run"
  if (any(!allowed)) stop("Unknown acceptance argument", call. = FALSE)
  result = phase02_accept_proposal(
    proposal = phase02_cli_value(arguments, "--proposal"),
    reviewer = phase02_cli_value(arguments, "--reviewer"),
    reason = phase02_cli_value(arguments, "--reason"),
    dry_run = "--dry-run" %in% arguments
  )
  cat(sprintf("Proposal-Hash: %s\n", result$proposal_hash))
  cat(sprintf("Old-Canonical-Hash: %s\n", result$old_canonical_hash))
  cat(sprintf("New-Canonical-Hash: %s\n", result$new_canonical_hash))
  cat(if (result$dry_run) "Dry run: canonical files unchanged\n" else
    sprintf("Accepted: %s\n", result$acceptance))
  invisible(0L)
}

if (sys.nframe() == 0L) phase02_accept_main()
