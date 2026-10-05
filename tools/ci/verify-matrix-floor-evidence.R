#!/usr/bin/env Rscript

# This validator consumes hosted CSV outcomes, never the installed Matrix.
matrixEvidenceColumns = c("setup_r_alias", "resolved_r_version", "os",
  "build_mode", "candidate_label", "matrix_version", "source_install_result",
  "solver_test_result", "run_id")
matrixEvidencePairs = c("Linux/serial", "macOS/serial", "Windows/serial",
  "Linux/openmp", "Windows/openmp")

readMatrixEvidence = function(path) {
  rows = read.csv(path, colClasses = "character", check.names = FALSE,
                  stringsAsFactors = FALSE)
  if (!identical(names(rows), matrixEvidenceColumns) || !nrow(rows) ||
      anyNA(rows) || any(!nzchar(as.matrix(rows)))) {
    stop("Missing rows or exact evidence columns", call. = FALSE)
  }
  if (any(!rows$setup_r_alias %in% c("release", "oldrel-1", "devel")) ||
      any(!paste(rows$os, rows$build_mode, sep = "/") %in% matrixEvidencePairs) ||
      any(!grepl("^[0-9]+[.][0-9]+[.][0-9]+$", rows$resolved_r_version)) ||
      any(!grepl("^[0-9]+[.][0-9]+[-.][0-9]+$", rows$matrix_version)) ||
      any(!grepl("^[1-9][0-9]+$", rows$run_id)) ||
      any(!rows$source_install_result %in% c("success", "failure", "cancelled", "not_run")) ||
      any(!rows$solver_test_result %in% c("success", "failure", "cancelled", "not_run"))) {
    stop("Invalid exact version, platform, run ID or outcome", call. = FALSE)
  }
  keys = matrixEvidenceKeys(rows, includeRun = TRUE)
  if (anyDuplicated(keys)) stop("Duplicate evidence tuple", call. = FALSE)
  for (alias in unique(rows$setup_r_alias)) {
    if (length(unique(rows$resolved_r_version[rows$setup_r_alias == alias])) != 1L) {
      stop("Inconsistent resolved R version for alias", call. = FALSE)
    }
  }
  rows
}

matrixEvidenceKeys = function(rows, includeRun = FALSE) {
  fields = c("setup_r_alias", "os", "build_mode", "candidate_label", "matrix_version")
  if (includeRun) fields = c(fields, "run_id")
  do.call(paste, c(rows[fields], sep = "/"))
}

matrixEvidencePass = function(rows) {
  rows$source_install_result == "success" & rows$solver_test_result == "success"
}

matrixEvidenceDcf = function(path, fields) {
  value = read.dcf(path)
  if (nrow(value) != 1L || !identical(colnames(value), fields) ||
      anyNA(value) || any(!nzchar(value))) {
    stop("Invalid checked provenance metadata", call. = FALSE)
  }
  setNames(as.list(value[1L, ]), fields)
}

matrixEvidenceFile = function(directory, relative) {
  if (!nzchar(relative) || grepl("^/|^[A-Za-z]:|\\\\|(^|/)[.][.](/|$)", relative)) {
    stop("Invalid retained provenance path", call. = FALSE)
  }
  path = file.path(directory, relative)
  if (!file.exists(path) || dir.exists(path) ||
      !startsWith(normalizePath(path), paste0(normalizePath(directory), "/"))) {
    stop("Missing retained provenance payload", call. = FALSE)
  }
  path
}

matrixEvidenceDigest = function(path, expected) {
  if (!grepl("^[0-9a-f]{32}$", expected) ||
      !identical(unname(tools::md5sum(path)), expected)) {
    stop("Retained provenance digest mismatch", call. = FALSE)
  }
}

matrixValidateRunProvenance = function(actual, directory, run) {
  stem = paste0("hosted-provenance-", run, "-1")
  metadata = matrixEvidenceDcf(file.path(directory, paste0(stem, ".dcf")),
    c("RunID", "RunAttempt", "HeadSHA", "RunURL", "ManifestMD5",
      "RowsFile", "RowsMD5", "Normalization"))
  if (metadata$RunID != run || metadata$RunAttempt != "1" ||
      !grepl("^[0-9a-f]{40}$", metadata$HeadSHA) ||
      metadata$RunURL != paste0("https://github.com/DavidZenz/tabloToR/actions/runs/", run) ||
      metadata$RowsFile != paste0(stem, ".csv") ||
      metadata$Normalization != "strict-json-and-artifact-sha256-v1") {
    stop("Invalid hosted run/attempt provenance", call. = FALSE)
  }
  # This DCF is a trusted normalization of strictly parsed original JSON and
  # SHA256-checked artifacts. Runtime checks need only offline base R MD5.
  matrixEvidenceDigest(file.path(directory, paste0("hosted-run-", run, "-1.json")),
                       metadata$ManifestMD5)
  path = matrixEvidenceFile(directory, metadata$RowsFile)
  matrixEvidenceDigest(path, metadata$RowsMD5)
  provenance = read.csv(path, colClasses = "character", check.names = FALSE,
                         stringsAsFactors = FALSE)
  extra = c("run_attempt", "job_id", "job_name", "job_conclusion", "source_step",
    "solver_step", "artifact_id", "artifact_name", "artifact_digest", "payload_file",
    "payload_md5", "payload_sha256", "failure_log_file", "failure_log_md5",
    "failure_log_sha256", "failure_reason")
  if (!identical(names(provenance), c(matrixEvidenceColumns, extra)) ||
      !nrow(provenance) || anyNA(provenance) || any(!nzchar(as.matrix(provenance))) ||
      anyDuplicated(matrixEvidenceKeys(provenance, TRUE)) ||
      anyDuplicated(provenance$job_id) || anyDuplicated(provenance$artifact_id) ||
      any(provenance$run_id != run) || any(provenance$run_attempt != metadata$RunAttempt)) {
    stop("Invalid hosted row provenance", call. = FALSE)
  }
  for (i in seq_len(nrow(provenance))) {
    row = provenance[i, , drop = FALSE]
    if (!grepl("^[1-9][0-9]+$", row$job_id) ||
        !grepl("^[1-9][0-9]+$", row$artifact_id) ||
        !grepl("^sha256:[0-9a-f]{64}$", row$artifact_digest) ||
        !grepl("^[0-9a-f]{64}$", row$payload_sha256)) {
      stop("Invalid hosted job/artifact identifiers or digests", call. = FALSE)
    }
    jobNames = c(paste(row$os, "/ R", row$setup_r_alias, "/ Matrix",
                      paste0(row$matrix_version, " (", row$candidate_label, ")"), "/", row$build_mode),
                 paste(row$os, "/ R", row$setup_r_alias, "/ Matrix", row$candidate_label, "/", row$build_mode))
    artifact = paste("matrix-candidate", run, metadata$RunAttempt, row$setup_r_alias,
                     row$candidate_label, row$os, row$build_mode, sep = "-")
    solver = if (row$solver_step == "skipped") "not_run" else row$solver_step
    if (!row$job_name %in% jobNames || row$artifact_name != artifact ||
        row$source_step != row$source_install_result || solver != row$solver_test_result ||
        !row$source_step %in% c("success", "failure", "cancelled") ||
        !row$solver_step %in% c("success", "failure", "cancelled", "skipped") ||
        (matrixEvidencePass(row) && row$job_conclusion != "success") ||
        ((row$source_step == "failure" || row$solver_step == "failure") &&
           row$job_conclusion != "failure") ||
        row$payload_file != paste0("payloads-", run, "-1/", row$job_id, ".csv")) {
      stop("Hosted tuple or step outcomes disagree with payload", call. = FALSE)
    }
    payloadPath = matrixEvidenceFile(directory, row$payload_file)
    matrixEvidenceDigest(payloadPath, row$payload_md5)
    payload = readMatrixEvidence(payloadPath)
    claim = row[matrixEvidenceColumns]
    rownames(claim) = rownames(payload) = NULL
    if (nrow(payload) != 1L || !identical(claim, payload)) {
      stop("Hosted provenance disagrees with retained artifact row", call. = FALSE)
    }
    if (row$source_step == "failure") {
      if (row$failure_log_file != paste0("payloads-", run, "-1/", row$job_id, ".log")) {
        stop("Failed-source artifact identity mismatch", call. = FALSE)
      }
      logPath = matrixEvidenceFile(directory, row$failure_log_file)
      matrixEvidenceDigest(logPath, row$failure_log_md5)
      if (!grepl("^[0-9a-f]{64}$", row$failure_log_sha256)) {
        stop("Missing failed-source artifact digest", call. = FALSE)
      }
      errors = trimws(grep("error:", readLines(logPath, warn = FALSE),
                           value = TRUE, ignore.case = TRUE))
      if (!length(errors) || row$failure_reason != errors[[1L]]) {
        stop("Exclusion reason disagrees with retained source artifact", call. = FALSE)
      }
    } else if (any(unlist(row[c("failure_log_file", "failure_log_md5",
                                "failure_log_sha256", "failure_reason")]) != "none")) {
      stop("Unexpected failed-source provenance", call. = FALSE)
    }
  }
  matched = provenance[match(matrixEvidenceKeys(actual, TRUE),
                            matrixEvidenceKeys(provenance, TRUE)), , drop = FALSE]
  claim = matched[matrixEvidenceColumns]
  rownames(actual) = rownames(claim) = NULL
  if (!identical(actual, claim)) stop("Evidence differs from checked hosted provenance", call. = FALSE)
  matched
}

selectMatrixFloor = function(rows, history = NULL) {
  candidates = unique(rows$matrix_version[rows$candidate_label != "current"])
  candidates = candidates[order(package_version(candidates))]
  if (!length(candidates) || !identical(candidates[[1L]], "1.6-5")) {
    stop("Missing provisional candidate and earlier rejection history", call. = FALSE)
  }
  if (length(candidates) > 1L) {
    if (is.null(history) || !identical(names(history),
        c("matrix_version", "source_url", "requires_r", "eligible", "release_order")) ||
        anyNA(history) || anyDuplicated(history$matrix_version) ||
        !identical(history$matrix_version, candidates) ||
        any(history$eligible != "true") ||
        !identical(as.integer(history$release_order), seq_along(candidates)) ||
        any(!grepl("^[0-9]+[.][0-9]+([.][0-9]+)?$", history$requires_r)) ||
        any(package_version(history$requires_r) >
            package_version(unique(rows$resolved_r_version[rows$setup_r_alias == "oldrel-1"])))) {
      stop("Missing ordered eligible CRAN fallback history", call. = FALSE)
    }
    urls = paste0("https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_",
                  candidates, ".tar.gz")
    if (!identical(history$source_url, urls)) stop("Invalid fallback source URL", call. = FALSE)
  }
  attempts = character()
  for (candidate in candidates) {
    floorRows = rows[rows$setup_r_alias == "oldrel-1" &
                      rows$matrix_version == candidate & rows$candidate_label != "current", ]
    pairs = paste(floorRows$os, floorRows$build_mode, sep = "/")
    if (nrow(floorRows) != 5L || !setequal(pairs, matrixEvidencePairs)) {
      stop("Missing five oldrel-1 candidate pairings", call. = FALSE)
    }
    if (all(matrixEvidencePass(floorRows))) {
      return(list(version = candidate, rows = floorRows, rejected = attempts))
    }
    attempts = c(attempts, candidate)
  }
  stop("No candidate has five passing oldrel-1 rows", call. = FALSE)
}

validateMatrixEvidence = function(input, supported, history = NULL) {
  selected = selectMatrixFloor(input, history)
  if (any(!input$candidate_label %in% c("minimum", "current", "fallback")) ||
      any(!supported$candidate_label %in% c("minimum", "current"))) {
    stop("Invalid candidate label", call. = FALSE)
  }
  current = unique(supported$matrix_version[supported$candidate_label == "current"])
  if (length(current) != 1L || package_version(current) < package_version(selected$version) ||
      any(supported$matrix_version[supported$candidate_label == "minimum"] != selected$version) ||
      any(!matrixEvidencePass(supported)) || length(unique(supported$run_id)) != 1L) {
    stop("Failed or inconsistent exact supported endpoints", call. = FALSE)
  }
  expected = expand.grid(setup_r_alias = c("release", "oldrel-1", "devel"),
                          pair = matrixEvidencePairs,
                          candidate_label = c("minimum", "current"),
                          stringsAsFactors = FALSE)
  expectedKeys = paste(expected$setup_r_alias, expected$pair,
    expected$candidate_label,
    ifelse(expected$candidate_label == "minimum", selected$version, current), sep = "/")
  selectedInput = input[input$matrix_version %in% c(selected$version, current), , drop = FALSE]
  selectedInput$candidate_label[selectedInput$candidate_label == "fallback"] = "minimum"
  if (!setequal(matrixEvidenceKeys(selectedInput), expectedKeys)) {
    stop("Missing full candidate matrix evidence", call. = FALSE)
  }
  supportedKeys = matrixEvidenceKeys(supported)
  if (anyDuplicated(supportedKeys) || any(!supportedKeys %in% expectedKeys)) {
    stop("Unexpected supported tuple", call. = FALSE)
  }
  excludedKeys = setdiff(expectedKeys, supportedKeys)
  excluded = selectedInput[match(excludedKeys, matrixEvidenceKeys(selectedInput)), , drop = FALSE]
  if (anyNA(excluded) || any(excluded$setup_r_alias == "oldrel-1") ||
      any(excluded$candidate_label != "minimum") ||
      any(excluded$source_install_result != "failure") ||
      any(excluded$solver_test_result != "not_run")) {
    stop("Missing exact failed-source exclusion evidence", call. = FALSE)
  }
  for (alias in unique(supported$setup_r_alias)) {
    if (!identical(unique(supported$resolved_r_version[supported$setup_r_alias == alias]),
                   unique(input$resolved_r_version[input$setup_r_alias == alias]))) {
      stop("Supported run resolved R disagrees with candidate run", call. = FALSE)
    }
  }
  list(selected = selected, current = current, excluded = excluded,
       supported = supported)
}

matrixEvidenceTable = function(rows) {
  c(paste("|", paste(names(rows), collapse = " | "), "|"),
    paste("|", paste(rep("---", ncol(rows)), collapse = " | "), "|"),
    apply(rows, 1L, function(row) paste("|", paste(row, collapse = " | "), "|")))
}

matrixFloorRecord = function(inputPath, supportedPath, historyPath = NULL) {
  input = readMatrixEvidence(inputPath)
  supported = readMatrixEvidence(supportedPath)
  history = if (is.null(historyPath)) NULL else read.csv(historyPath,
    colClasses = "character", stringsAsFactors = FALSE)
  # Compare against retained immutable run merges, not mutable local claims.
  directory = file.path(dirname(inputPath), "hosted-evidence")
  checked = list()
  for (rows in list(input, supported)) {
    for (run in unique(rows$run_id)) {
      retainedPath = file.path(directory, paste0("matrix-candidate-evidence-", run, "-1.csv"))
      manifestPath = file.path(directory, paste0("hosted-run-", run, "-1.json"))
      if (!file.exists(retainedPath) || !file.exists(manifestPath)) {
        stop("Missing retained hosted run merge or artifact manifest", call. = FALSE)
      }
      retained = readMatrixEvidence(retainedPath)
      actual = rows[rows$run_id == run, , drop = FALSE]
      matched = retained[match(matrixEvidenceKeys(actual, TRUE),
                              matrixEvidenceKeys(retained, TRUE)), , drop = FALSE]
      rownames(actual) = rownames(matched) = NULL
      if (!identical(actual, matched)) stop("Evidence differs from retained hosted rows", call. = FALSE)
      checked[[length(checked) + 1L]] = matrixValidateRunProvenance(actual, directory, run)
    }
  }
  result = validateMatrixEvidence(input, supported, history)
  provenance = do.call(rbind, checked)
  reasons = provenance$failure_reason[match(matrixEvidenceKeys(result$excluded, TRUE),
                                            matrixEvidenceKeys(provenance, TRUE))]
  if (anyNA(reasons) || any(reasons == "none")) stop("Missing checked exclusion reason", call. = FALSE)
  result$excluded$failure_reason = gsub("|", "/", reasons, fixed = TRUE)
  floor = result$selected$version
  relative = function(path) {
    root = normalizePath(dirname(inputPath))
    full = normalizePath(path)
    if (!startsWith(full, paste0(root, "/"))) return(full)
    substring(full, nchar(root) + 2L)
  }
  unname(c("# Matrix floor evidence", "",
    paste0("Selected floor: ", floor),
    paste0("Current endpoint: ", result$current),
    paste0("Resolved oldrel-1 R: ", unique(result$selected$rows$resolved_r_version)),
    paste0("Selected archive: https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_", floor, ".tar.gz"),
    paste0("Current source: https://cran.r-project.org/src/contrib/Matrix_", result$current, ".tar.gz"),
    paste0("Input CSV: ", basename(inputPath)),
    paste0("Supported CSV: ", relative(supportedPath)),
    paste0("History CSV: ", if (is.null(historyPath)) "none" else relative(historyPath)),
    paste0("Input MD5: ", unname(tools::md5sum(inputPath))),
    paste0("Supported MD5: ", unname(tools::md5sum(supportedPath))),
    paste0("Full supported run: ", unique(supported$run_id), " (attempt 1)"), "",
    "## Five required oldrel-1 results", "", matrixEvidenceTable(result$selected$rows), "",
    "## Fallback history", "",
    if (!length(result$selected$rejected)) {
      "None: provisional 1.6-5 passed all five required pairings; no successor was tested or substituted."
    } else paste("Rejected in eligible ascending order:", paste(result$selected$rejected, collapse = ", ")),
    "", "## Full supported matrix", "", matrixEvidenceTable(supported), "",
    "## Individually evidenced exclusions", "", matrixEvidenceTable(result$excluded), "",
    "The excluded tuples failed exact Matrix source installation for the individually checked reasons above; solver tests did not run.",
    "Original JSON manifests, checked normalized job/artifact provenance, exact CSV payloads and failed-source logs are retained in hosted-evidence/.",
    "See HOSTED-COMPATIBILITY.md for the exact compiler errors, prior attempts and independent informational full-check findings.",
    "This evidence establishes endpoint compatibility on valid tuples; it does not claim every R/Matrix/platform cross-product installs.", ""))
}

verifyMatrixFinalMetadata = function(evidence, description = "DESCRIPTION", readme = "README.md") {
  lines = readLines(evidence, warn = FALSE)
  field = function(name) {
    values = sub(paste0("^", name, ": "), "", lines[startsWith(lines, paste0(name, ": "))])
    if (length(values) != 1L || !nzchar(values)) stop("Invalid floor record field", call. = FALSE)
    values
  }
  resolve = function(path) if (grepl("^/|^[A-Za-z]:", path)) path else file.path(dirname(evidence), path)
  history = field("History CSV")
  regenerated = matrixFloorRecord(resolve(field("Input CSV")), resolve(field("Supported CSV")),
    if (history == "none") NULL else resolve(history))
  if (!identical(lines, regenerated)) stop("Floor record disagrees with hosted evidence", call. = FALSE)
  floor = field("Selected floor")
  current = field("Current endpoint")
  imports = trimws(strsplit(read.dcf(description)[1L, "Imports"], ",", fixed = TRUE)[[1L]])
  matrix = imports[grepl("^Matrix($|[[:space:](])", imports)]
  if (!identical(matrix, paste0("Matrix (>= ", floor, ")"))) {
    stop("DESCRIPTION Matrix minimum disagrees with evidence", call. = FALSE)
  }
  text = paste(readLines(readme, warn = FALSE), collapse = "\n")
  if (!grepl(paste0("Matrix support: ", floor, " through ", current), text, fixed = TRUE)) {
    stop("README Matrix interval disagrees with evidence", call. = FALSE)
  }
  cat("Final metadata matches hosted floor", floor, "and current", current, "\n")
  invisible(TRUE)
}

matrixFloorMain = function(args = commandArgs(trailingOnly = TRUE)) {
  value = function(flag, default = NULL) {
    indices = which(args == flag)
    if (!length(indices)) return(default)
    if (length(indices) != 1L || indices == length(args)) stop("Invalid arguments", call. = FALSE)
    args[[indices + 1L]]
  }
  if ("--verify-final-metadata" %in% args) {
    verifyMatrixFinalMetadata(value("--evidence"))
  } else {
    input = value("--input")
    supported = value("--supported", file.path(dirname(input),
      "hosted-evidence/matrix-candidate-evidence-37274723569-1.csv"))
    output = value("--output")
    record = matrixFloorRecord(input, supported, value("--candidate-history"))
    writeLines(record, output)
    cat("Validated five oldrel-1 pairings and full supported matrix:", output, "\n")
  }
}

if (sys.nframe() == 0L) matrixFloorMain()
