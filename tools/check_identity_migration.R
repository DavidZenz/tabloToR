#!/usr/bin/env Rscript

identity_abort = function(code, detail = NULL) {
  message = if (is.null(detail) || !length(detail) || !nzchar(detail)) {
    code
  } else {
    paste(code, detail)
  }
  stop(message, call. = FALSE)
}

identity_script_path = local({
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

identity_repository_root = function() {
  working = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  ancestors = working
  while (!identical(tail(ancestors, 1L), dirname(tail(ancestors, 1L)))) {
    ancestors = c(ancestors, dirname(tail(ancestors, 1L)))
  }
  candidates = c(
    if (!is.na(identity_script_path)) dirname(dirname(identity_script_path))
    else character(),
    ancestors
  )
  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        file.exists(file.path(
          candidate, "inst", "migration", "benchmark-identity-map.dcf"
        ))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  identity_abort("HISTORICAL_ROOT_NOT_FOUND")
}

identity_historical_registry_path = function(root = identity_repository_root()) {
  file.path(root, "inst", "migration", "historical-evidence.dcf")
}

identity_historical_allowlist_path = function(root = identity_repository_root()) {
  file.path(root, "inst", "migration", "old-identity-allowlist.csv")
}

identity_hash_raw = function(value) {
  if (!is.raw(value)) identity_abort("HISTORICAL_HASH_INPUT_INVALID")
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(unclass(as.character(openssl::sha256(value))))
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(value, algo = "sha256", serialize = FALSE))
  }
  identity_abort("HISTORICAL_SHA256_UNAVAILABLE")
}

identity_read_raw = function(path) {
  info = file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) || info$size[[1L]] < 1 ||
      info$size[[1L]] > 50 * 1024^2 || !isTRUE(file_test("-f", path))) {
    identity_abort("HISTORICAL_FILE_INVALID", path)
  }
  connection = file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, "raw", n = as.integer(info$size[[1L]]))
}

identity_hash_file = function(path) {
  identity_hash_raw(identity_read_raw(path))
}

identity_resolve_path = function(root, relative) {
  if (!is.character(relative) || length(relative) != 1L ||
      is.na(relative) || !nzchar(relative) ||
      !identical(relative, trimws(relative)) ||
      (grepl("[\r\n*?{}]", relative) ||
       grepl("[", relative, fixed = TRUE) ||
       grepl("]", relative, fixed = TRUE))) {
    identity_abort("HISTORICAL_PATH_INVALID", relative)
  }
  relative = gsub("\\\\", "/", relative)
  components = strsplit(relative, "/", fixed = TRUE)[[1L]]
  if (startsWith(relative, "/") || grepl("^[A-Za-z]:", relative) ||
      any(components %in% c("", ".", ".."))) {
    identity_abort("HISTORICAL_PATH_INVALID", relative)
  }
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate = do.call(file.path, as.list(c(root, components)))
  if (!file.exists(candidate) || dir.exists(candidate) ||
      !isTRUE(file_test("-f", candidate))) {
    identity_abort("HISTORICAL_PATH_MISSING", relative)
  }
  resolved = normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (!startsWith(resolved, paste0(root, "/"))) {
    identity_abort("HISTORICAL_PATH_ESCAPE", relative)
  }
  resolved
}

identity_historical_registry_fields = function() {
  c(
    "Schema", "Record-Id", "Category", "Path", "Region",
    "Digest-Algorithm", "Byte-Digest", "Identity-Mode",
    "Predecessor-Identity", "Review-State", "Contract-State", "Rationale"
  )
}

identity_expected_registry_metadata = function() {
  data.frame(
    `Record-Id` = c(
      "phase02-expectations", "phase02-tolerances",
      "phase02-fingerprints", "phase02-acceptance",
      "gtap12a-cpp-results", "protected-gemodel",
      "protected-sparse-elimination", "protected-sparse-solver",
      "protected-sparse-schur-complement", "gemodel-warning-region"
    ),
    Category = c(
      rep("immutable-phase02-evidence", 4L),
      "immutable-benchmark-evidence",
      rep("protected-numerical-source", 4L),
      "protected-source-region"
    ),
    Path = c(
      file.path("tests", "testthat", "baselines", "phase02",
                "expectations.csv"),
      file.path("tests", "testthat", "baselines", "phase02",
                "tolerances.csv"),
      file.path("tests", "testthat", "baselines", "phase02",
                "fingerprints.dcf"),
      file.path("tests", "testthat", "baselines", "phase02",
                "ACCEPTANCE.md"),
      file.path("benchmarks", "GTAP12A_CPP_RESULTS.md"),
      file.path("R", "GEModel.R"),
      file.path("R", "sparseElimination.R"),
      file.path("R", "sparseSolver.R"),
      file.path("R", "sparseSchurComplement.R"),
      file.path("R", "GEModel.R")
    ),
    Region = c(
      rep("whole-file", 5L),
      rep("identity-normalized-whole-file", 4L),
      "lines-228-228"
    ),
    `Identity-Mode` = c(rep("raw", 5L), rep("exact-map-v1", 4L), "raw"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

identity_read_historical_registry = function(path) {
  value = tryCatch(
    read.dcf(path),
    error = function(error) identity_abort(
      "HISTORICAL_REGISTRY_INVALID", conditionMessage(error)
    )
  )
  value = as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(names(value), identity_historical_registry_fields())) {
    identity_abort("HISTORICAL_REGISTRY_FIELDS")
  }
  value[] = lapply(value, as.character)
  value
}

identity_load_map_tool = function(root) {
  environment = new.env(parent = globalenv())
  sys.source(
    file.path(root, "inst", "tools", "refresh_phase02_baselines.R"),
    envir = environment
  )
  environment
}

identity_region_payload = function(path, region) {
  match = regexec("^lines-([0-9]+)-([0-9]+)$", region)
  values = regmatches(region, match)[[1L]]
  if (length(values) != 3L) {
    identity_abort("HISTORICAL_REGION_INVALID", region)
  }
  first = as.integer(values[[2L]])
  last = as.integer(values[[3L]])
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  if (is.na(first) || is.na(last) || first < 1L || last < first ||
      last > length(lines)) {
    identity_abort("HISTORICAL_REGION_INVALID", region)
  }
  charToRaw(paste0(
    seq.int(first, last), ":", lines[seq.int(first, last)], "\n",
    collapse = ""
  ))
}

identity_registry_digest = function(record, root, map_tool, map) {
  path = identity_resolve_path(root, record$Path[[1L]])
  mode = record$`Identity-Mode`[[1L]]
  if (identical(record$Region[[1L]], "whole-file") &&
      identical(mode, "raw")) {
    return(identity_hash_file(path))
  }
  if (identical(record$Region[[1L]], "identity-normalized-whole-file") &&
      identical(mode, "exact-map-v1")) {
    text = rawToChar(identity_read_raw(path))
    normalized = map_tool$phase02_canonicalize_identity_text(text, map)
    return(identity_hash_raw(charToRaw(normalized)))
  }
  if (startsWith(record$Region[[1L]], "lines-") &&
      identical(mode, "raw")) {
    return(identity_hash_raw(identity_region_payload(
      path, record$Region[[1L]]
    )))
  }
  identity_abort("HISTORICAL_REGISTRY_MODE", record$`Record-Id`[[1L]])
}

identity_load_historical_registry = function(
    path = identity_historical_registry_path(root), root = identity_repository_root()) {
  value = identity_read_historical_registry(path)
  expected = identity_expected_registry_metadata()
  invalid = !nrow(value) || anyNA(value) ||
    any(!nzchar(as.matrix(value))) ||
    any(as.matrix(value) != trimws(as.matrix(value)))
  if (invalid) identity_abort("HISTORICAL_REGISTRY_INCOMPLETE")
  if (!all(value$Schema == "gemodelr-historical-evidence-v1")) {
    identity_abort("HISTORICAL_REGISTRY_SCHEMA")
  }
  if (anyDuplicated(value$`Record-Id`) ||
      !identical(value$`Record-Id`, expected$`Record-Id`)) {
    identity_abort("HISTORICAL_REGISTRY_RECORDS")
  }
  metadata = c("Record-Id", "Category", "Path", "Region", "Identity-Mode")
  if (!identical(value[metadata], expected[metadata])) {
    identity_abort("HISTORICAL_REGISTRY_METADATA")
  }
  if (!all(value$`Digest-Algorithm` == "sha256") ||
      any(!grepl("^[0-9a-f]{64}$", value$`Byte-Digest`))) {
    identity_abort("HISTORICAL_REGISTRY_DIGEST")
  }
  if (!all(value$`Predecessor-Identity` == "tabloToR")) {
    identity_abort("HISTORICAL_REGISTRY_PREDECESSOR")
  }
  if (!all(value$`Review-State` == "reviewed")) {
    identity_abort("HISTORICAL_REGISTRY_REVIEW")
  }
  if (!all(value$`Contract-State` == "locked")) {
    identity_abort("HISTORICAL_REGISTRY_CONTRACT")
  }
  if (any(!nzchar(value$Rationale))) {
    identity_abort("HISTORICAL_REGISTRY_RATIONALE")
  }

  map_tool = identity_load_map_tool(root)
  map = map_tool$phase02_load_identity_map(root = root, validate_source = TRUE)
  observed = vapply(seq_len(nrow(value)), function(index) {
    identity_registry_digest(value[index, , drop = FALSE], root, map_tool, map)
  }, character(1))
  drift = value$`Record-Id`[observed != value$`Byte-Digest`]
  if (length(drift)) {
    identity_abort(
      "HISTORICAL_REGISTRY_DIGEST_DRIFT", paste(drift, collapse = ",")
    )
  }
  value
}

identity_historical_allowlist_fields = function() {
  c(
    "path", "category", "expected_count", "literal_or_line_digest",
    "file_digest", "rationale"
  )
}

identity_read_historical_allowlist = function(path) {
  value = tryCatch(
    read.csv(
      path, stringsAsFactors = FALSE, check.names = FALSE,
      colClasses = "character", na.strings = NULL
    ),
    error = function(error) identity_abort(
      "HISTORICAL_ALLOWLIST_INVALID", conditionMessage(error)
    )
  )
  if (!identical(names(value), identity_historical_allowlist_fields())) {
    identity_abort("HISTORICAL_ALLOWLIST_FIELDS")
  }
  value[] = lapply(value, as.character)
  value
}

identity_historical_line_state = function(path) {
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  counts = vapply(lines, function(line) {
    matches = gregexpr("tabloToR", line, ignore.case = TRUE, perl = TRUE)[[1L]]
    if (length(matches) == 1L && matches[[1L]] == -1L) 0L else length(matches)
  }, integer(1))
  hit = which(counts > 0L)
  payload = paste0(hit, ":", lines[hit], "\n", collapse = "")
  list(
    count = as.integer(sum(counts)),
    line_digest = identity_hash_raw(charToRaw(payload)),
    file_digest = identity_hash_file(path)
  )
}

identity_validate_historical_allowlist = function(value, root, registry) {
  if (!is.data.frame(value) ||
      !identical(names(value), identity_historical_allowlist_fields())) {
    identity_abort("HISTORICAL_ALLOWLIST_FIELDS")
  }
  value[] = lapply(value, as.character)
  if (anyNA(value) || any(!nzchar(as.matrix(value))) ||
      any(as.matrix(value) != trimws(as.matrix(value)))) {
    identity_abort("HISTORICAL_ALLOWLIST_INCOMPLETE")
  }
  if (anyDuplicated(value$path)) {
    identity_abort("HISTORICAL_ALLOWLIST_DUPLICATE")
  }
  if (nrow(value) != 1L ||
      !identical(
        value$path,
        "tests/testthat/baselines/phase02/fingerprints.dcf"
      )) {
    identity_abort("HISTORICAL_ALLOWLIST_RECORDS")
  }
  if (!all(value$category == "immutable-historical-evidence")) {
    identity_abort("HISTORICAL_ALLOWLIST_CATEGORY")
  }
  count = suppressWarnings(as.integer(value$expected_count))
  if (anyNA(count) || !identical(as.character(count), value$expected_count) ||
      any(count < 1L)) {
    identity_abort("HISTORICAL_ALLOWLIST_COUNT")
  }
  digests = c(value$literal_or_line_digest, value$file_digest)
  if (any(!grepl("^[0-9a-f]{64}$", digests))) {
    identity_abort("HISTORICAL_ALLOWLIST_DIGEST")
  }
  immutable_paths = registry$Path[startsWith(registry$Category, "immutable-")]
  if (any(!value$path %in% immutable_paths)) {
    identity_abort("HISTORICAL_ALLOWLIST_STALE")
  }

  states = lapply(value$path, function(relative) {
    identity_historical_line_state(identity_resolve_path(root, relative))
  })
  observed_count = vapply(states, `[[`, integer(1), "count")
  observed_line = vapply(states, `[[`, character(1), "line_digest")
  observed_file = vapply(states, `[[`, character(1), "file_digest")
  if (!identical(observed_count, count)) {
    identity_abort("HISTORICAL_ALLOWLIST_COUNT_DRIFT")
  }
  if (!identical(observed_line, value$literal_or_line_digest)) {
    identity_abort("HISTORICAL_ALLOWLIST_LINE_DRIFT")
  }
  if (!identical(observed_file, value$file_digest)) {
    identity_abort("HISTORICAL_ALLOWLIST_FILE_DRIFT")
  }
  invisible(TRUE)
}

identity_validate_numerical_contracts = function(
    root = identity_repository_root()) {
  map_tool = identity_load_map_tool(root)
  map = map_tool$phase02_load_identity_map(root = root, validate_source = TRUE)
  read_normalized = function(relative) {
    text = rawToChar(identity_read_raw(identity_resolve_path(root, relative)))
    map_tool$phase02_canonicalize_identity_text(text, map)
  }
  files = list(
    gemodel = read_normalized("R/GEModel.R"),
    elimination = read_normalized("R/sparseElimination.R"),
    solver = read_normalized("R/sparseSolver.R"),
    schur = read_normalized("R/sparseSchurComplement.R")
  )
  required = list(
    c("gemodel", "solveModel = function(iter = 3, steps = c(1,3),"),
    c("gemodel", 'engine = c("legacy", "sparse"),'),
    c("gemodel", 'backend = "Matrix",'),
    c("solver", "order_value = order(i, j)"),
    c("solver", "relative_l2 = residual_norm / max(1, rhs_norm)"),
    c("solver", "residual_tolerance = 2e-7"),
    c("solver", 'getOption("<<PACKAGE-IDENTITY-MIXED>>.sparse.lu_order", 3L)'),
    c("solver", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.elimination_pivot_tolerance", 1e-12'),
    c("elimination", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.schur_region_batch_size", 8L'),
    c("elimination", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.schur_panel_size", 64L'),
    c("elimination", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.schur_restart", 80L'),
    c("elimination", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.schur_max_iterations", 500L'),
    c("elimination", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.schur_tolerance", 2e-7'),
    c("elimination", '"<<PACKAGE-IDENTITY-MIXED>>.sparse.schur_true_residual_frequency", 1L'),
    c("schur", "region_batch_size = 8L, panel_size = 64L, restart = 80L,"),
    c("schur", "max_iterations = 500L, tolerance = 2e-7,"),
    c("schur", "true_residual_frequency = 1L")
  )
  missing = vapply(required, function(contract) {
    !grepl(contract[[2L]], files[[contract[[1L]]]], fixed = TRUE)
  }, logical(1))
  if (any(missing)) {
    identity_abort(
      "HISTORICAL_NUMERICAL_CONTRACT_DRIFT",
      paste(vapply(required[missing], `[[`, character(1), 2L),
            collapse = " | ")
    )
  }

  tolerance_path = identity_resolve_path(
    root, "tests/testthat/baselines/phase02/tolerances.csv"
  )
  tolerance = read.csv(
    tolerance_path, stringsAsFactors = FALSE, check.names = FALSE
  )
  expected = data.frame(
    fixture = c("three-region", "full-gtap-external", "tiny-structured"),
    tier = c("strict", "external", "strict"),
    solution_atol = c(1e-10, 1e-10, 1e-10),
    solution_rtol = c(1e-8, 2e-7, 1e-8),
    residual_rtol = c(1e-10, 2e-7, 1e-10),
    stringsAsFactors = FALSE
  )
  actual = tolerance[c(
    "fixture", "tier", "solution_atol", "solution_rtol", "residual_rtol"
  )]
  if (!identical(actual, expected)) {
    identity_abort("HISTORICAL_TOLERANCE_CONTRACT_DRIFT")
  }
  invisible(TRUE)
}

identity_check_historical = function(
    root = identity_repository_root(),
    registry_path = identity_historical_registry_path(root),
    allowlist_path = identity_historical_allowlist_path(root)) {
  registry = identity_load_historical_registry(registry_path, root)
  allowlist = identity_read_historical_allowlist(allowlist_path)
  identity_validate_historical_allowlist(allowlist, root, registry)
  identity_validate_numerical_contracts(root)
  list(
    clean = TRUE,
    immutable_records = as.integer(sum(startsWith(
      registry$Category, "immutable-"
    ))),
    protected_source_records = as.integer(sum(
      registry$Category == "protected-numerical-source"
    )),
    protected_region_records = as.integer(sum(
      registry$Category == "protected-source-region"
    )),
    historical_occurrences = as.integer(sum(
      as.integer(allowlist$expected_count)
    )),
    registry = registry
  )
}

identity_usage = function() {
  paste(
    "Usage:",
    "  rtk Rscript --vanilla tools/check_identity_migration.R --historical-only",
    sep = "\n"
  )
}

identity_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  if (identical(arguments, "--help")) {
    cat(identity_usage(), "\n")
    return(invisible(0L))
  }
  if (!identical(arguments, "--historical-only")) {
    identity_abort("HISTORICAL_ARGUMENT_INVALID")
  }
  result = identity_check_historical()
  cat("Historical identity audit: PASS\n")
  cat(sprintf("Immutable-records: %s\n", result$immutable_records))
  cat(sprintf(
    "Protected-source-records: %s\n", result$protected_source_records
  ))
  cat(sprintf(
    "Protected-region-records: %s\n", result$protected_region_records
  ))
  cat(sprintf(
    "Historical-predecessor-occurrences: %s\n",
    result$historical_occurrences
  ))
  invisible(0L)
}

if (sys.nframe() == 0L) identity_main()
