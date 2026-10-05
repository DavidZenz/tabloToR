#!/usr/bin/env Rscript

phase02_accept_script_path = local({
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
  } else NA_character_
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

phase02_accept_root_path = phase02_accept_root()
phase02_refresh_candidates = c(
  file.path(phase02_accept_root_path, "inst", "tools",
            "refresh_phase02_baselines.R"),
  file.path(phase02_accept_root_path, "tools", "refresh_phase02_baselines.R")
)
phase02_refresh_candidates = phase02_refresh_candidates[
  file.exists(phase02_refresh_candidates)
]
if (!length(phase02_refresh_candidates)) {
  stop("Could not locate the Phase 02 refresh implementation", call. = FALSE)
}
sys.source(phase02_refresh_candidates[[1L]], envir = environment())

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
  stable_columns = paste0(
    "Artifact-", gsub("[^A-Za-z0-9]", "-", phase02_stable_artifact_names()),
    "-MD5"
  )
  required_manifest = c(
    "Schema", "Proposal-Hash", "Run-Metadata-MD5", stable_columns
  )
  if (nrow(manifest) != 1L ||
      !setequal(colnames(manifest), required_manifest) ||
      !identical(unname(manifest[1L, "Schema"]),
                 "phase02-baseline-proposal-v2")) {
    stop("The proposal manifest has an unsupported schema", call. = FALSE)
  }
  declared = unname(manifest[1L, "Proposal-Hash"])
  actual = phase02_artifact_hash(proposal)
  if (!identical(declared, actual)) {
    stop("The proposal hash does not match its stable artifacts",
         call. = FALSE)
  }
  stable = phase02_stable_artifact_names()
  stable_hashes = vapply(
    stable, function(name) phase02_hash_file(file.path(proposal, name)),
    character(1)
  )
  declared_stable = unname(manifest[1L, stable_columns])
  if (!identical(declared_stable, unname(stable_hashes))) {
    stop("The proposal manifest does not match its artifact hashes",
         call. = FALSE)
  }
  run_metadata_hash = phase02_hash_file(
    file.path(proposal, "run-metadata.dcf")
  )
  if (!identical(
    unname(manifest[1L, "Run-Metadata-MD5"]), run_metadata_hash
  )) {
    stop("The proposal run-metadata evidence hash does not match",
         call. = FALSE)
  }
  artifacts = tryCatch({
    expectations = read.csv(
      file.path(proposal, "expectations.csv"), stringsAsFactors = FALSE,
      check.names = FALSE
    )
    tolerances = read.csv(
      file.path(proposal, "tolerances.csv"), stringsAsFactors = FALSE,
      check.names = FALSE
    )
    fingerprints = read.dcf(file.path(proposal, "fingerprints.dcf"))
    metadata = read.dcf(file.path(proposal, "run-metadata.dcf"))
    if (!identical(names(expectations), c(
      "fixture", "authority", "kind", "key", "value", "rationale"
    )) || !nrow(expectations) ||
        anyDuplicated(expectations[c("fixture", "authority", "kind", "key")])) {
      stop("expectations.csv schema is invalid")
    }
    if (!identical(names(tolerances), c(
      "fixture", "conditioning", "tier", "solution_atol", "solution_rtol",
      "residual_rtol", "rationale", "reviewer"
    )) || !nrow(tolerances) ||
        anyDuplicated(tolerances[c("fixture", "conditioning")]) ||
        any(!is.finite(as.matrix(tolerances[c(
          "solution_atol", "solution_rtol", "residual_rtol"
        )]))) ||
        any(as.matrix(tolerances[c(
          "solution_atol", "solution_rtol", "residual_rtol"
        )]) < 0)) {
      stop("tolerances.csv schema is invalid")
    }
    identity_fields = c(
      "Schema", "Fixture-Path", "Fixture-MD5",
      "Fixture-Input-Signature", "Source-Fingerprint",
      "Package-Signature", "Model-Signature"
    )
    if (nrow(fingerprints) != 1L ||
        !all(identity_fields %in% colnames(fingerprints)) ||
        !identical(unname(fingerprints[1L, "Schema"]),
                   "phase02-baseline-fingerprints-v1")) {
      stop("fingerprints.dcf schema is invalid")
    }
    if (nrow(metadata) != 1L ||
        !all(c("Schema", "Generated-UTC", "Solver-Backend") %in%
             colnames(metadata)) ||
        !identical(unname(metadata[1L, "Schema"]),
                   "phase02-baseline-run-metadata-v1")) {
      stop("run-metadata.dcf schema is invalid")
    }
    list(
      expectations = expectations, tolerances = tolerances,
      fingerprints = as.list(fingerprints[1L, ]),
      identity_fields = identity_fields
    )
  }, error = function(error) {
    stop(sprintf("The proposal artifact schema is invalid: %s",
                 conditionMessage(error)), call. = FALSE)
  })
  comparison = phase02_diff_frame(canonical_dir, proposal)
  expected_diff = phase02_render_diff(comparison)
  actual_diff = readLines(file.path(proposal, "DIFF.md"), warn = FALSE)
  if (!identical(actual_diff, expected_diff)) {
    stop("The proposal diff is stale relative to the canonical baseline",
         call. = FALSE)
  }
  list(
    path = proposal, hash = actual, comparison = comparison,
    run_metadata_hash = run_metadata_hash,
    fingerprints = artifacts$fingerprints,
    tolerances = artifacts$tolerances,
    identity_fields = artifacts$identity_fields
  )
}

phase02_acceptance_record = function(reviewer, reason, proposal_hash,
                                      run_metadata_hash, old_hash, new_hash,
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
    paste0("- **Run-Metadata-MD5:** `", run_metadata_hash, "`"),
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

phase02_acceptance_fault = function(phase) {
  hook = getOption("GEModelR.phase02.acceptance.fault")
  if (is.function(hook)) hook(phase)
  invisible(NULL)
}

phase02_accept_proposal = function(
    proposal, reviewer, reason, canonical_dir = phase02_canonical_dir(),
    dry_run = FALSE) {
  reviewer = phase02_accept_text(reviewer, "reviewer", 200L)
  reason = phase02_accept_text(reason, "reason", 2000L)
  if (!is.logical(dry_run) || length(dry_run) != 1L || is.na(dry_run)) {
    stop("dry_run must be TRUE or FALSE", call. = FALSE)
  }
  canonical_dir = normalizePath(
    canonical_dir, winslash = "/", mustWork = TRUE
  )
  lock = paste0(canonical_dir, ".accept-lock")
  backup = paste0(canonical_dir, ".accept-backup")
  if (!dir.create(lock, showWarnings = FALSE)) {
    stop("Canonical baseline acceptance is locked by another process",
         call. = FALSE)
  }
  on.exit(unlink(lock, recursive = TRUE, force = TRUE), add = TRUE)
  if (file.exists(backup) || dir.exists(backup)) {
    stop(
      "A recoverable canonical backup exists; inspect it before acceptance",
      call. = FALSE
    )
  }
  validated = phase02_validate_proposal(proposal, canonical_dir)
  current_dir = tempfile(
    "phase02-current-source-", tmpdir = dirname(canonical_dir)
  )
  on.exit(unlink(current_dir, recursive = TRUE, force = TRUE), add = TRUE)
  regenerated = phase02_generate_proposal(
    current_dir, canonical_dir = canonical_dir
  )
  current = phase02_validate_proposal(current_dir, canonical_dir)
  if (!identical(regenerated$proposal_hash, validated$hash) ||
      !identical(
        unname(validated$fingerprints[validated$identity_fields]),
        unname(current$fingerprints[current$identity_fields])
      )) {
    stop(
      "The reviewed proposal no longer matches the current source and model",
      call. = FALSE
    )
  }
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
  fingerprints = validated$fingerprints
  tolerances = validated$tolerances
  record = phase02_acceptance_record(
    reviewer, reason, validated$hash, validated$run_metadata_hash,
    old_hash, new_hash, fingerprints, tolerances
  )
  phase02_write_lines(record, file.path(staging, "ACCEPTANCE.md"), staging)
  if (isTRUE(dry_run)) {
    return(invisible(list(
      dry_run = TRUE, proposal_hash = validated$hash,
      old_canonical_hash = old_hash, new_canonical_hash = new_hash,
      record = record
    )))
  }

  committed = FALSE
  canonical_moved = FALSE
  on.exit({
    if (!committed && canonical_moved) {
      if (dir.exists(canonical_dir) &&
          !file.rename(canonical_dir, staging)) {
        warning("Could not move the failed canonical publication aside",
                call. = FALSE)
      }
      if (!dir.exists(canonical_dir) && dir.exists(backup) &&
          !file.rename(backup, canonical_dir)) {
        warning("Could not restore the recoverable canonical backup",
                call. = FALSE)
      }
    }
  }, add = TRUE)
  if (!file.rename(canonical_dir, backup)) {
    stop("Could not create the recoverable canonical backup", call. = FALSE)
  }
  canonical_moved = TRUE
  phase02_acceptance_fault("after-canonical-backup")
  if (!file.rename(staging, canonical_dir)) {
    stop("Could not publish the staged canonical baseline", call. = FALSE)
  }
  phase02_acceptance_fault("after-canonical-publication")
  if (!identical(phase02_artifact_hash(canonical_dir), new_hash) ||
      !file.exists(file.path(canonical_dir, "ACCEPTANCE.md"))) {
    stop("Canonical verification failed after acceptance", call. = FALSE)
  }
  committed = TRUE
  if (unlink(backup, recursive = TRUE, force = TRUE) != 0L) {
    warning("Accepted baseline but could not remove its recovery backup",
            call. = FALSE)
  }
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
