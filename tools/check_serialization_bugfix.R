#!/usr/bin/env Rscript

serialization_bugfix_stop = function(message) {
  stop(sprintf("Serialization BUGFIX review failed: %s", message), call. = FALSE)
}

serialization_bugfix_repository_root = function(root = NULL) {
  if (!is.null(root)) {
    if (!is.character(root) || length(root) != 1L || is.na(root) ||
        !nzchar(root) || !dir.exists(root)) {
      serialization_bugfix_stop("repository root is unavailable")
    }
    return(normalizePath(root, winslash = "/", mustWork = TRUE))
  }
  working = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  ancestors = working
  repeat {
    parent = dirname(tail(ancestors, 1L))
    if (identical(parent, tail(ancestors, 1L))) break
    ancestors = c(ancestors, parent)
  }
  candidates = ancestors
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        file.exists(file.path(candidate, "R", "modelSerialization.R")) &&
        dir.exists(file.path(candidate, "tests", "testthat"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  serialization_bugfix_stop("could not locate the package repository root")
}

serialization_bugfix_path_key = function(path) {
  value = normalizePath(path, winslash = "/", mustWork = FALSE)
  value = sub("/+$", "", value)
  if (identical(.Platform$OS.type, "windows")) value = tolower(value)
  value
}

serialization_bugfix_path_contains = function(parent, child) {
  parent = serialization_bugfix_path_key(parent)
  child = serialization_bugfix_path_key(child)
  identical(parent, child) || startsWith(child, paste0(parent, "/"))
}

serialization_bugfix_read_raw = function(path, label = "file") {
  if (!file.exists(path) || dir.exists(path) || nzchar(Sys.readlink(path))) {
    serialization_bugfix_stop(sprintf("%s is missing or is not a regular file", label))
  }
  size = file.info(path)$size
  if (!is.finite(size) || size < 1 || size > 50 * 1024^2) {
    serialization_bugfix_stop(sprintf("%s has an invalid size", label))
  }
  connection = file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, what = "raw", n = as.integer(size))
}

serialization_bugfix_hash_raw = function(value) {
  if (!is.raw(value)) serialization_bugfix_stop("hash input is not raw")
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(unclass(as.character(openssl::sha256(value))))
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(value, algo = "sha256", serialize = FALSE))
  }
  serialization_bugfix_stop("SHA-256 support is unavailable")
}

serialization_bugfix_hash_file = function(path, label = "file") {
  serialization_bugfix_hash_raw(serialization_bugfix_read_raw(path, label))
}

serialization_bugfix_git_executable = function() {
  candidates = c(
    if (file.exists("/usr/bin/git")) "/usr/bin/git" else character(),
    unname(Sys.which("git"))
  )
  candidates = candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) {
    serialization_bugfix_stop("Git executable is unavailable")
  }
  candidates[[1L]]
}

serialization_bugfix_command = function(
    command, arguments, allow_status = 0L, label = command) {
  stdout = tempfile("serialization-bugfix-stdout-")
  stderr = tempfile("serialization-bugfix-stderr-")
  on.exit(unlink(c(stdout, stderr), force = TRUE), add = TRUE)
  result = tryCatch(
    system2(command, arguments, stdout = stdout, stderr = stderr),
    error = function(error) {
      serialization_bugfix_stop(sprintf(
        "%s could not run: %s", label, conditionMessage(error)
      ))
    }
  )
  status = attr(result, "status")
  if (is.null(status)) status = 0L
  if (!as.integer(status) %in% as.integer(allow_status)) {
    error_text = if (file.exists(stderr)) {
      paste(readLines(stderr, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    } else ""
    serialization_bugfix_stop(sprintf(
      "%s exited with status %s%s", label, status,
      if (nzchar(error_text)) paste0(": ", error_text) else ""
    ))
  }
  list(
    status = as.integer(status),
    stdout = if (file.exists(stdout)) {
      readLines(stdout, warn = FALSE, encoding = "UTF-8")
    } else character(),
    stderr = if (file.exists(stderr)) {
      readLines(stderr, warn = FALSE, encoding = "UTF-8")
    } else character()
  )
}

serialization_bugfix_validate_relative_path = function(
    root, value, expected, label) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value) || grepl("[\r\n]", value) ||
      grepl("(^|[/\\\\])\\.\\.?($|[/\\\\])", value) ||
      grepl("^([/\\\\]|[A-Za-z]:)", value)) {
    serialization_bugfix_stop(sprintf("%s is not a safe root-relative path", label))
  }
  if (!identical(value, expected)) {
    serialization_bugfix_stop(sprintf("%s is outside the reviewed scope", label))
  }
  target = file.path(root, value)
  if (!file.exists(target) || dir.exists(target) || nzchar(Sys.readlink(target))) {
    serialization_bugfix_stop(sprintf("%s is missing or is not a regular file", label))
  }
  normalized = normalizePath(target, winslash = "/", mustWork = TRUE)
  if (!serialization_bugfix_path_contains(root, normalized)) {
    serialization_bugfix_stop(sprintf("%s escapes the repository root", label))
  }
  normalized
}

serialization_bugfix_git_source = function(root, commit, relative) {
  if (!is.character(commit) || length(commit) != 1L || is.na(commit) ||
      !grepl("^[0-9a-f]{40}$", commit)) {
    serialization_bugfix_stop("Before-Commit is not one exact commit id")
  }
  serialization_bugfix_command(
    serialization_bugfix_git_executable(), c("-C", root, "cat-file", "-e", paste0(commit, "^{commit}")),
    label = "git commit validation"
  )
  output = tempfile("serialization-bugfix-before-source-", fileext = ".R")
  error = tempfile("serialization-bugfix-before-source-error-")
  on.exit(unlink(c(output, error), force = TRUE), add = TRUE)
  result = tryCatch(
    system2(
      serialization_bugfix_git_executable(), c("-C", root, "show", paste0(commit, ":", relative)),
      stdout = output, stderr = error
    ),
    error = function(condition) {
      serialization_bugfix_stop(sprintf(
        "git source extraction failed: %s", conditionMessage(condition)
      ))
    }
  )
  status = attr(result, "status")
  if (is.null(status)) status = 0L
  if (!identical(as.integer(status), 0L)) {
    error_text = paste(readLines(error, warn = FALSE), collapse = "\n")
    serialization_bugfix_stop(sprintf(
      "git source extraction failed%s",
      if (nzchar(error_text)) paste0(": ", error_text) else ""
    ))
  }
  serialization_bugfix_read_raw(output, "immutable before source")
}

serialization_bugfix_read_record = function(path) {
  value = tryCatch(
    as.data.frame(
      read.dcf(path), stringsAsFactors = FALSE, check.names = FALSE
    ),
    error = function(error) {
      serialization_bugfix_stop(sprintf(
        "review record is invalid: %s", conditionMessage(error)
      ))
    }
  )
  fields = c(
    "Schema", "Finding", "Change-Kind", "Source-Path", "Before-Commit",
    "Before-SHA256", "After-SHA256", "Patch-Path", "Patch-SHA256",
    "Allowed-Functions", "Review-State", "Reviewer", "Reviewed-UTC"
  )
  if (nrow(value) != 1L || !identical(names(value), fields)) {
    serialization_bugfix_stop(
      "review record must contain exactly one record with the strict schema"
    )
  }
  value[] = lapply(value, as.character)
  if (anyNA(value) || any(!nzchar(as.matrix(value))) ||
      any(as.matrix(value) != trimws(as.matrix(value)))) {
    serialization_bugfix_stop("review record contains empty or untrimmed fields")
  }
  as.list(value[1L, ])
}

serialization_bugfix_validate_record = function(
    record_path = NULL, root = serialization_bugfix_repository_root()) {
  root = serialization_bugfix_repository_root(root)
  if (is.null(record_path)) {
    record_path = file.path(root, "inst", "migration",
                            "serialization-bugfix.dcf")
  }
  if (!is.character(record_path) || length(record_path) != 1L ||
      is.na(record_path) || !file.exists(record_path) || dir.exists(record_path)) {
    serialization_bugfix_stop("review record is missing")
  }
  record_path = normalizePath(record_path, winslash = "/", mustWork = TRUE)
  if (!serialization_bugfix_path_contains(root, record_path)) {
    serialization_bugfix_stop("review record escapes the repository root")
  }
  record = serialization_bugfix_read_record(record_path)
  if (!identical(record[["Schema"]], "gemodelr-serialization-bugfix-v1") ||
      !identical(record[["Finding"]], "CR-04") ||
      !identical(record[["Change-Kind"]], "BUGFIX")) {
    serialization_bugfix_stop("review record has an unsupported finding or change kind")
  }
  source_path = serialization_bugfix_validate_relative_path(
    root, record[["Source-Path"]], "R/modelSerialization.R", "Source-Path"
  )
  patch_path = serialization_bugfix_validate_relative_path(
    root, record[["Patch-Path"]],
    "inst/migration/serialization-bugfix.patch", "Patch-Path"
  )
  for (field in c("Before-SHA256", "After-SHA256", "Patch-SHA256")) {
    if (!grepl("^[0-9a-f]{64}$", record[[field]])) {
      serialization_bugfix_stop(sprintf("%s is not a SHA-256 digest", field))
    }
  }
  if (!identical(
    record[["Allowed-Functions"]],
    ".serialization_promote_reconstructed_fields;.serialization_validate_structure;.validate_reconstructed_logical_state;validate_projection"
  )) {
    serialization_bugfix_stop("Allowed-Functions is not the exact revised function scope")
  }
  if (!record[["Review-State"]] %in% c("proposed", "approved")) {
    serialization_bugfix_stop("Review-State is unsupported")
  }
  if (identical(record[["Review-State"]], "proposed")) {
    if (!identical(record[["Reviewer"]], "pending") ||
        !identical(record[["Reviewed-UTC"]], "pending")) {
      serialization_bugfix_stop(
        "proposed review records must remain pending"
      )
    }
  } else if (identical(record[["Reviewer"]], "pending") ||
             !grepl(
               "^[^\r\n[:space:]][^\r\n]*[^\r\n[:space:]]$",
               record[["Reviewer"]]
             ) ||
             !grepl(
               "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
               record[["Reviewed-UTC"]]
             )) {
    serialization_bugfix_stop(
      "approved review records require a reviewer and UTC timestamp"
    )
  }
  before = serialization_bugfix_git_source(
    root, record[["Before-Commit"]], record[["Source-Path"]]
  )
  if (!identical(
    serialization_bugfix_hash_raw(before), record[["Before-SHA256"]]
  )) {
    serialization_bugfix_stop("Before-SHA256 does not match the immutable source")
  }
  if (!identical(
    serialization_bugfix_hash_file(source_path, "current serialization source"),
    record[["Before-SHA256"]]
  ) && identical(record[["Review-State"]], "proposed")) {
    serialization_bugfix_stop(
      "current serialization source no longer matches the proposed before bytes"
    )
  }
  if (!identical(
    serialization_bugfix_hash_file(patch_path, "serialization BUGFIX patch"),
    record[["Patch-SHA256"]]
  )) {
    serialization_bugfix_stop("Patch-SHA256 does not match the patch bytes")
  }
  record
}

serialization_bugfix_validate_protection = function(root) {
  refresh_path = file.path(root, "inst", "tools",
                           "refresh_phase02_baselines.R")
  if (!file.exists(refresh_path)) {
    serialization_bugfix_stop("Phase 02 source-scope verifier is unavailable")
  }
  refresh = new.env(parent = globalenv())
  sys.source(refresh_path, envir = refresh)
  map_path = file.path(root, "inst", "migration",
                       "benchmark-identity-map.dcf")
  map = tryCatch(
    refresh$phase02_load_identity_map(
      path = map_path, root = root, validate_source = TRUE
    ),
    error = function(error) {
      serialization_bugfix_stop(sprintf(
        "identity source contract is invalid: %s", conditionMessage(error)
      ))
    }
  )
  if (!identical(
    unname(map[["Reviewed-Non-Numerical-Exclusions"]]),
    rep("R/modelSerialization.R", 2L)
  ) || !identical(
    unname(map[["Normalized-Source-Fingerprint"]]),
    rep("aee225f16707f20978a4f4318bffb4fe", 2L)
  )) {
    serialization_bugfix_stop(
      "identity map does not retain the exact reviewed serialization exclusion"
    )
  }
  protected = refresh$phase02_protected_numerical_source_files()
  identity_files = refresh$phase02_identity_source_files(root)
  if ("R/modelSerialization.R" %in% identity_files ||
      !all(protected %in% identity_files)) {
    serialization_bugfix_stop(
      "identity source scope does not retain the exact protected files"
    )
  }
  canonical_dir = file.path(root, "tests", "testthat", "baselines", "phase02")
  original = tryCatch(
    refresh$phase02_check_original_artifacts(
      root = root, canonical_dir = canonical_dir
    ),
    error = function(error) {
      serialization_bugfix_stop(sprintf(
        "immutable Phase 02 evidence is invalid: %s", conditionMessage(error)
      ))
    }
  )
  if (!identical(
    original$accepted_canonical_hash,
    "f6f2297a6ab257c9737a64354c82d7f1"
  )) {
    serialization_bugfix_stop("accepted canonical Phase 02 hash drifted")
  }
  list(
    map = map,
    protected = protected,
    identity_files = identity_files,
    original = original
  )
}

serialization_bugfix_apply_candidate = function(
    root, before, patch_path, source_path, record) {
  workspace = tempfile("serialization-bugfix-candidate-")
  if (!dir.create(workspace, recursive = TRUE, showWarnings = FALSE)) {
    serialization_bugfix_stop("candidate workspace could not be created")
  }
  on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)
  candidate = file.path(workspace, source_path)
  dir.create(dirname(candidate), recursive = TRUE, showWarnings = FALSE)
  before_path = file.path(workspace, "before.R")
  writeBin(before, before_path)
  writeBin(before, candidate)
  result = local({
    old = getwd()
    setwd(workspace)
    on.exit(setwd(old), add = TRUE)
    serialization_bugfix_command(
      "patch",
      c("--batch", "--forward", "--fuzz=0", "-p1", "-i", patch_path),
      label = "candidate patch application"
    )
  })
  if (!file.exists(candidate)) {
    serialization_bugfix_stop("candidate patch did not produce the source file")
  }
  after = serialization_bugfix_read_raw(candidate, "candidate after source")
  if (!identical(serialization_bugfix_hash_raw(after), record[["After-SHA256"]])) {
    serialization_bugfix_stop("After-SHA256 does not match the patched candidate")
  }
  patch_lines = readLines(patch_path, warn = FALSE, encoding = "bytes")
  hunks = patch_lines[startsWith(patch_lines, "@@ ")]
  if (!identical(hunks, c(
    "@@ -414,6 +414,21 @@",
    "@@ -660,19 +675,23 @@",
    "@@ -692,6 +711,34 @@",
    "@@ -714,7 +761,7 @@",
    "@@ -822,10 +869,18 @@"
  )) || any(grepl(
    "^(diff --git|index |old mode|new mode|rename )", patch_lines
  ))) {
    serialization_bugfix_stop(
      "patch is not exactly the reviewed validation hunks"
    )
  }
  expected_patch = tempfile("serialization-bugfix-expected-patch-")
  before_for_diff = tempfile("serialization-bugfix-diff-before-")
  after_for_diff = tempfile("serialization-bugfix-diff-after-")
  on.exit(unlink(c(expected_patch, before_for_diff, after_for_diff), force = TRUE),
          add = TRUE)
  writeBin(before, before_for_diff)
  writeBin(after, after_for_diff)
  diff_result = serialization_bugfix_command(
    "diff",
    c(
      "-u", "--label", paste0("a/", source_path),
      "--label", paste0("b/", source_path), before_for_diff, after_for_diff
    ),
    allow_status = c(0L, 1L), label = "candidate patch reproduction"
  )
  writeLines(diff_result$stdout, expected_patch, useBytes = TRUE)
  expected = serialization_bugfix_read_raw(expected_patch, "reproduced patch")
  actual = serialization_bugfix_read_raw(patch_path, "reviewed patch")
  if (!identical(actual, expected) ||
      !identical(serialization_bugfix_hash_raw(actual), record[["Patch-SHA256"]])) {
    serialization_bugfix_stop(
      "reviewed patch bytes do not reproduce the exact candidate delta"
    )
  }
  list(
    workspace = workspace,
    candidate_source = candidate,
    before = before,
    after = after,
    patch = actual,
    patch_command_status = result$status
  )
}

serialization_bugfix_candidate_script = function() {
  c(
    "args = commandArgs(trailingOnly = TRUE)",
    "candidate_root = normalizePath(args[[1L]], mustWork = TRUE)",
    "fixture = normalizePath(args[[2L]], mustWork = TRUE)",
    "predecessor = normalizePath(args[[3L]], mustWork = TRUE)",
    "result_file = args[[4L]]",
    "old_wd = getwd()",
    "setwd(candidate_root)",
    "on.exit(setwd(old_wd), add = TRUE)",
    "r_files = sort(list.files(file.path(candidate_root, 'R'), pattern = '\\\\.R$', full.names = TRUE))",
    "for (path in r_files) sys.source(path, envir = .GlobalEnv)",
    "three_region_input_data = function() {",
    "  regions = c('north', 'south', 'east')",
    "  list(basedata = list(weight = array(c(1, 1.5, 2), dim = 3L, dimnames = list(reg = regions)), stock = array(c(100, 200, 300), dim = 3L, dimnames = list(reg = regions))))",
    "}",
    "build_model = function() {",
    "  model = GEModel$new()",
    "  model$loadTablo(fixture)",
    "  model$setClosure('tax')",
    "  model$loadData(three_region_input_data(), engine = 'sparse')",
    "  model",
    "}",
    "receiver_snapshot = function(model) {",
    "  list(data = model$data, solution = model$solution, change_variables = model$changeVariables, variables = model$variables, basic_change_variables = model$basicChangeVariables, variable_values = model$variableValues, tablo_statements = model$tabloStatements, sparse_spec = model$sparseSpec, sparse_index = model$sparseIndex, sparse_state = if (is.environment(model$sparseState)) sparse_state_data(model$sparseState) else NULL, loaded_engine = model$loadedEngine, closure = model$closure, explicit_shocks = model$explicitShocks, source_data = model$sourceData, memory_budget = model$memoryBudget, diagnostics = model$lastDiagnostics, compact_output = model$compactOutput, postsim_record = model$.postsimRecord)",
    "}",
    "model = build_model()",
    "payload = .build_logical_state_payload(model)",
    "stock = payload$levels$basedata$stock",
    "stopifnot(is.double(stock), length(stock) == 3L)",
    "stock = array(as.logical(stock), dim = dim(stock), dimnames = dimnames(stock))",
    "payload$levels$basedata$stock = stock",
    "bad_file = tempfile(fileext = '.rds')",
    "saveRDS(payload, bad_file, version = 3L)",
    "receiver = GEModel$new()",
    "receiver$closure = 'receiver-sentinel'",
    "receiver$memoryBudget = 8192",
    "before = serialize(receiver_snapshot(receiver), NULL, version = 3L)",
    "error = tryCatch({ receiver$loadState(bad_file); NULL }, error = function(condition) conditionMessage(condition))",
    "after = serialize(receiver_snapshot(receiver), NULL, version = 3L)",
    "predecessor_receiver = GEModel$new()",
    "predecessor_error = tryCatch({ predecessor_receiver$loadState(predecessor); NULL }, error = function(condition) conditionMessage(condition))",
    "saveRDS(list(rejected = is.character(error) && grepl('type does not match', error, fixed = TRUE), unchanged = identical(before, after), error = error, predecessor_loaded = is.null(predecessor_error), predecessor_error = predecessor_error, predecessor_lineage = if (is.null(predecessor_error)) .serialization_current_package_lineage() else NULL), result_file, version = 3L)",
    "unlink(bad_file)",
    ""
  )
}

serialization_bugfix_run_candidate = function(root, after, predecessor) {
  candidate_root = tempfile("serialization-bugfix-source-")
  if (!dir.create(candidate_root, recursive = TRUE, showWarnings = FALSE)) {
    serialization_bugfix_stop("plain-source candidate root could not be created")
  }
  on.exit(unlink(candidate_root, recursive = TRUE, force = TRUE), add = TRUE)
  r_destination = file.path(candidate_root, "R")
  if (!dir.create(r_destination, recursive = TRUE, showWarnings = FALSE)) {
    serialization_bugfix_stop("plain-source candidate R directory could not be created")
  }
  r_files = list.files(file.path(root, "R"), pattern = "\\.R$",
                       recursive = TRUE, full.names = TRUE)
  if (!length(r_files) || any(!file.copy(
    r_files, file.path(r_destination, basename(r_files)), overwrite = TRUE
  ))) {
    serialization_bugfix_stop("plain-source candidate R files could not be copied")
  }
  if (!file.copy(file.path(root, "DESCRIPTION"), candidate_root,
                 overwrite = TRUE)) {
    serialization_bugfix_stop("plain-source candidate DESCRIPTION could not be copied")
  }
  registry_destination = file.path(
    candidate_root, "inst", "migration", "predecessor-fingerprints.dcf"
  )
  dir.create(dirname(registry_destination), recursive = TRUE,
             showWarnings = FALSE)
  if (!file.copy(
    file.path(root, "inst", "migration", "predecessor-fingerprints.dcf"),
    registry_destination, overwrite = TRUE
  )) {
    serialization_bugfix_stop("plain-source candidate lineage registry could not be copied")
  }
  candidate_serialization = file.path(candidate_root, "R", "modelSerialization.R")
  writeBin(after, candidate_serialization)
  script = tempfile("serialization-bugfix-candidate-script-", fileext = ".R")
  result_file = tempfile("serialization-bugfix-candidate-result-", fileext = ".rds")
  on.exit(unlink(c(script, result_file), force = TRUE), add = TRUE)
  writeLines(serialization_bugfix_candidate_script(), script, useBytes = TRUE)
  rscript = file.path(R.home("bin"), "Rscript")
  result = serialization_bugfix_command(
    rscript,
    c("--vanilla", script, candidate_root, file.path(
      root, "tests", "testthat", "fixtures", "three-region.tab"
    ), predecessor, result_file),
    label = "plain-source serialization candidate"
  )
  if (!file.exists(result_file)) {
    serialization_bugfix_stop("plain-source candidate did not write its result")
  }
  value = tryCatch(
    readRDS(result_file),
    error = function(error) {
      serialization_bugfix_stop(sprintf(
        "plain-source candidate result is invalid: %s", conditionMessage(error)
      ))
    }
  )
  required = c(
    "rejected", "unchanged", "error", "predecessor_loaded",
    "predecessor_error", "predecessor_lineage"
  )
  if (!is.list(value) || !identical(names(value), required) ||
      !isTRUE(value$rejected) || !isTRUE(value$unchanged) ||
      !isTRUE(value$predecessor_loaded)) {
    serialization_bugfix_stop(
      "plain-source candidate did not prove rejection, nonmutation, and predecessor success"
    )
  }
  value
}

serialization_bugfix_verify_delta = function(
    mode = c("proposal", "approved"),
    record_path = NULL, root = serialization_bugfix_repository_root()) {
  mode = match.arg(mode)
  root = serialization_bugfix_repository_root(root)
  record = serialization_bugfix_validate_record(record_path, root)
  protection = serialization_bugfix_validate_protection(root)
  source_path = file.path(root, record[["Source-Path"]])
  patch_path = file.path(root, record[["Patch-Path"]])
  before = serialization_bugfix_git_source(
    root, record[["Before-Commit"]], record[["Source-Path"]]
  )
  current = serialization_bugfix_read_raw(source_path, "current serialization source")
  if (identical(mode, "proposal")) {
    if (!record[["Review-State"]] %in% c("proposed", "approved")) {
      serialization_bugfix_stop(
        "proposal mode requires a proposed or approved review record"
      )
    }
    if (!identical(current, before)) {
      serialization_bugfix_stop(
        "proposal mode requires the live source to remain at the before bytes"
      )
    }
  } else {
    if (!identical(record[["Review-State"]], "approved")) {
      serialization_bugfix_stop(
        "approved mode requires explicit human approval of these exact bytes"
      )
    }
    if (!identical(
      serialization_bugfix_hash_raw(current), record[["After-SHA256"]]
    )) {
      serialization_bugfix_stop(
        "approved mode requires the live source to equal After-SHA256"
      )
    }
  }
  candidate = serialization_bugfix_apply_candidate(
    root, before, patch_path, record[["Source-Path"]], record
  )
  if (!identical(
    serialization_bugfix_hash_raw(candidate$after), record[["After-SHA256"]]
  )) {
    serialization_bugfix_stop("candidate after source is not hash-bound")
  }
  predecessor = file.path(
    root, "tests", "testthat", "fixtures", "serialization",
    "tabloToR-schema1-lineage.rds"
  )
  if (!file.exists(predecessor) || dir.exists(predecessor) ||
      !identical(
        serialization_bugfix_hash_file(predecessor, "predecessor fixture"),
        "578f4b1a90e21097e401c22f20d0ef118ab71ce27b5301c0fd90aa776174274b"
      )) {
    serialization_bugfix_stop("genuine predecessor fixture is missing or drifted")
  }
  workspace = tempfile("serialization-bugfix-candidate-source-root-")
  if (!dir.create(workspace, recursive = TRUE, showWarnings = FALSE)) {
    serialization_bugfix_stop("candidate source root could not be prepared")
  }
  on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)
  candidate_result = serialization_bugfix_run_candidate(root, candidate$after,
                                                        predecessor)
  list(
    clean = TRUE,
    mode = mode,
    record = record,
    protection = protection,
    candidate = candidate_result,
    before_sha256 = serialization_bugfix_hash_raw(before),
    after_sha256 = serialization_bugfix_hash_raw(candidate$after),
    patch_sha256 = serialization_bugfix_hash_raw(candidate$patch)
  )
}

serialization_bugfix_main = function(
    arguments = commandArgs(trailingOnly = TRUE)) {
  if (identical(arguments, "--help")) {
    cat(
      "Usage: rtk Rscript --vanilla tools/check_serialization_bugfix.R",
      "--proposal | --verify-approved\n"
    )
    return(invisible(0L))
  }
  if (length(arguments) != 1L ||
      !arguments[[1L]] %in% c("--proposal", "--verify-approved")) {
    serialization_bugfix_stop(
      "choose exactly one of --proposal or --verify-approved"
    )
  }
  mode = if (identical(arguments[[1L]], "--proposal")) "proposal" else "approved"
  result = serialization_bugfix_verify_delta(mode = mode)
  if (identical(mode, "proposal")) {
    cat("Serialization BUGFIX proposal: PASS\n")
  } else {
    cat("Serialization BUGFIX gate: PASS\n")
    cat("Change-Kind: BUGFIX\n")
  }
  cat(sprintf("Before-SHA256: %s\n", result$before_sha256))
  cat(sprintf("After-SHA256: %s\n", result$after_sha256))
  cat(sprintf("Patch-SHA256: %s\n", result$patch_sha256))
  invisible(0L)
}

if (sys.nframe() == 0L) serialization_bugfix_main()
