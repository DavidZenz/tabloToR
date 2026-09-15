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

identity_expected_historical_allowlist = function() {
  data.frame(
    path = c(
      "tests/testthat/baselines/phase02/fingerprints.dcf",
      "inst/migration/predecessor-fingerprints.dcf",
      "tests/testthat/fixtures/serialization/tabloToR-schema1-lineage.rds",
      "tests/testthat/test-identity-migration.R",
      "tests/testthat/test-model-serialization.R",
      "tools/check_predecessor_bridge.R"
    ),
    category = c(
      "immutable-historical-evidence",
      "predecessor-lineage-registry",
      "predecessor-logical-state-fixture",
      "migration-regression-test",
      "migration-regression-test",
      "migration-verification-tool"
    ),
    stringsAsFactors = FALSE
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

identity_rds_occurrence_records = function(value, path = "payload") {
  records = character()
  visit = function(item, location) {
    if (is.list(item)) {
      labels = names(item)
      for (index in seq_along(item)) {
        label = if (!is.null(labels) && nzchar(labels[[index]])) {
          paste0(location, "$", labels[[index]])
        } else {
          paste0(location, "[[", index, "]]")
        }
        visit(item[[index]], label)
      }
      return(invisible(NULL))
    }
    if (!is.character(item)) return(invisible(NULL))
    for (index in seq_along(item)) {
      matches = gregexpr(
        "tabloToR", item[[index]], ignore.case = TRUE, perl = TRUE
      )[[1L]]
      count = if (length(matches) == 1L && matches[[1L]] == -1L) {
        0L
      } else {
        length(matches)
      }
      if (count) {
        record = paste0(
          location, "[[", index, "]]:", item[[index]], "\n"
        )
        records <<- c(records, rep(record, count))
      }
    }
    invisible(NULL)
  }
  visit(value, path)
  records
}

identity_historical_line_state = function(path) {
  if (identical(tolower(tools::file_ext(path)), "rds")) {
    value = tryCatch(
      readRDS(path),
      error = function(error) identity_abort(
        "HISTORICAL_ALLOWLIST_RDS_INVALID", conditionMessage(error)
      )
    )
    records = identity_rds_occurrence_records(value)
    return(list(
      count = as.integer(length(records)),
      line_digest = identity_hash_raw(charToRaw(paste0(
        records, collapse = ""
      ))),
      file_digest = identity_hash_file(path)
    ))
  }
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
  expected = identity_expected_historical_allowlist()
  if (!identical(
    value[c("path", "category")], expected
  )) {
    identity_abort("HISTORICAL_ALLOWLIST_RECORDS")
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
  immutable_rows =
    value$category == "immutable-historical-evidence"
  if (any(!value$path[immutable_rows] %in% immutable_paths)) {
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
      as.integer(
        allowlist$expected_count[
          allowlist$category == "immutable-historical-evidence"
        ]
      )
    )),
    registry = registry
  )
}

identity_old_token = function() paste0("tablo", "ToR")

identity_occurrence_categories = function() {
  c(
    "upstream-attribution",
    "migration-instruction",
    "immutable-historical-evidence",
    "old-option-replacement",
    "reviewed-serialization-fingerprint"
  )
}

identity_category_rationale = function(category) {
  unname(c(
    "upstream-attribution" =
      "Reviewed predecessor attribution, rights, or upstream source reference",
    "migration-instruction" =
      "Explicit predecessor-to-GEModelR migration instruction or audit contract",
    "immutable-historical-evidence" =
      "Immutable predecessor-era planning, benchmark, or accepted baseline evidence",
    "old-option-replacement" =
      "Exact predecessor option key retained only to reject it and name its replacement",
    "reviewed-serialization-fingerprint" =
      "Reviewed predecessor lineage, fixture, locator, or serialization fingerprint"
  )[[category]])
}

identity_read_historical_allowlist = function(path) {
  value = tryCatch(
    read.csv(
      path, stringsAsFactors = FALSE, check.names = FALSE,
      colClasses = "character", na.strings = NULL
    ),
    error = function(error) identity_abort(
      "UNEXPECTED_OLD_IDENTITY_ALLOWLIST_INVALID", conditionMessage(error)
    )
  )
  if (!identical(names(value), identity_historical_allowlist_fields())) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_FIELDS")
  }
  value[] = lapply(value, as.character)
  value
}

identity_match_positions = function(value) {
  matches = gregexpr(
    identity_old_token(), value, ignore.case = TRUE, perl = TRUE
  )[[1L]]
  if (length(matches) == 1L && matches[[1L]] == -1L) {
    integer()
  } else {
    as.integer(matches)
  }
}

identity_rds_occurrence_records = function(value, path = "payload") {
  records = character()
  visit = function(item, location) {
    if (is.list(item)) {
      labels = names(item)
      for (index in seq_along(item)) {
        label = if (!is.null(labels) && nzchar(labels[[index]])) {
          paste0(location, "$", labels[[index]])
        } else {
          paste0(location, "[[", index, "]]")
        }
        visit(item[[index]], label)
      }
      return(invisible(NULL))
    }
    if (!is.character(item)) return(invisible(NULL))
    for (index in seq_along(item)) {
      positions = identity_match_positions(item[[index]])
      if (length(positions)) {
        records <<- c(records, vapply(
          seq_along(positions),
          function(ordinal) paste0(
            "rds:", location, "[[", index, "]]:", ordinal, ":",
            item[[index]], "\n"
          ),
          character(1)
        ))
      }
    }
    invisible(NULL)
  }
  visit(value, path)
  records
}

identity_active_owner = function(path, line, position) {
  plan11 = c(
    ".gitignore", "CONTRIBUTORS.md", "NEWS.md",
    "docs/release/RELEASE-GATES.md",
    "inst/cpp/sparse-elimination.cpp",
    "rcpp-solver-acceleration-plan.md",
    "src/tablo-sparse-lu.h"
  )
  if (path %in% plan11) return("03-11")

  if (path == "docs/provenance/EXPECTED-KEYS.csv") return("03-10-task-2")
  if (path %in% c(
    "tools/check_release_gates.R", "tools/provenance_inventory.R",
    "tests/testthat/test-provenance-inventory.R"
  )) {
    return("03-10-task-2")
  }

  token_end = position + nchar(identity_old_token()) - 1L
  before = if (position > 1L) substr(line, position - 1L, position - 1L) else ""
  after = if (token_end < nchar(line)) {
    substr(line, token_end + 1L, token_end + 1L)
  } else {
    ""
  }
  if (path == "docs/provenance/PROVENANCE.csv" &&
      (identical(before, ".") || identical(after, "_"))) {
    return("03-10-task-2")
  }
  if (path == "tests/testthat/test-attribution-contract.R" &&
      grepl("description.*Package", line)) {
    return("03-10-task-2")
  }
  if (path == "tests/testthat/test-release-gates.R" &&
      (identical(after, "_") || grepl("Package: ", line, fixed = TRUE))) {
    return("03-10-task-2")
  }
  if (path == "tests/testthat/test-baseline-artifacts.R" &&
      grepl("system.file", line, fixed = TRUE)) {
    return("03-11")
  }
  NA_character_
}

identity_occurrence_category = function(path, line, position) {
  if (grepl("^\\.planning/", path)) return("migration-instruction")
  if (grepl("^benchmarks/\\.", path) ||
      path == "benchmarks/GTAP12A_CPP_RESULTS.md" ||
      grepl("^tests/testthat/baselines/phase02/", path) ||
      path %in% c(
        "inst/migration/benchmark-identity-map.dcf",
        "inst/migration/historical-evidence.dcf",
        "inst/tools/refresh_phase02_baselines.R"
      )) {
    return("immutable-historical-evidence")
  }
  if (path %in% c(
    "inst/migration/predecessor-fingerprints.dcf",
    "tests/testthat/fixtures/serialization/tabloToR-schema1-lineage.rds",
    "R/modelSerialization.R",
    "tests/testthat/test-model-serialization.R",
    "tools/check_predecessor_bridge.R"
  )) {
    return("reviewed-serialization-fingerprint")
  }
  token_end = position + nchar(identity_old_token()) - 1L
  after = if (token_end < nchar(line)) {
    substr(line, token_end + 1L, token_end + 1L)
  } else {
    ""
  }
  if (identical(after, ".") ||
      path %in% c(
        "inst/migration/option-replacements.dcf",
        "R/identityMigration.R", "R/sparseElimination.R",
        "R/sparseSchurComplement.R", "R/sparseSolver.R",
        "R/sparseSuiteSparse.R", "R/zzzSparseSchurCpp.R",
        "tests/testthat/helper-transactional-state.R",
        "tests/testthat/test-transactional-state.R"
      )) {
    return("old-option-replacement")
  }
  if (path %in% c(
    "MIGRATION.md", "README.md",
    "tests/testthat/test-identity-migration.R",
    "tests/testthat/test-baseline-artifacts.R",
    "tests/testthat/test-benchmark-harness.R",
    "tools/check_identity_migration.R"
  )) {
    return("migration-instruction")
  }
  if (grepl("^docs/provenance/", path) ||
      path %in% c(
        "DESCRIPTION", "inst/CITATION",
        "tests/testthat/test-attribution-contract.R",
        "tests/testthat/test-release-gates.R"
      )) {
    return("upstream-attribution")
  }
  NA_character_
}

identity_git_tracked_paths = function(root) {
  git = if (file.exists("/usr/bin/git")) "/usr/bin/git" else "git"
  output = suppressWarnings(system2(
    git, c("-C", shQuote(root), "ls-files"),
    stdout = TRUE, stderr = TRUE
  ))
  status = attr(output, "status")
  if (!is.null(status) && status != 0L) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_GIT", paste(output, collapse = " "))
  }
  sort(unique(output[nzchar(output)]), method = "radix")
}

identity_occurrences_for_path = function(root, relative) {
  path = identity_resolve_path(root, relative)
  rows = list()
  add = function(record, line, position, kind) {
    owner = identity_active_owner(relative, line, position)
    category = if (is.na(owner)) {
      identity_occurrence_category(relative, line, position)
    } else {
      NA_character_
    }
    rows[[length(rows) + 1L]] <<- data.frame(
      path = relative,
      category = category,
      active_owner = owner,
      record = record,
      kind = kind,
      stringsAsFactors = FALSE
    )
  }

  path_positions = identity_match_positions(relative)
  if (length(path_positions)) {
    for (ordinal in seq_along(path_positions)) {
      add(
        paste0("path:", ordinal, ":", relative, "\n"),
        relative, path_positions[[ordinal]], "path"
      )
    }
  }

  if (identical(relative, "inst/migration/old-identity-allowlist.csv")) {
    return(if (length(rows)) do.call(rbind, rows) else NULL)
  }

  if (identical(tolower(tools::file_ext(relative)), "rds")) {
    value = tryCatch(
      readRDS(path),
      error = function(error) identity_abort(
        "UNEXPECTED_OLD_IDENTITY_RDS_INVALID", relative
      )
    )
    records = identity_rds_occurrence_records(value)
    for (record in records) add(record, record, 1L, "rds")
    return(if (length(rows)) do.call(rbind, rows) else NULL)
  }

  info = file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) || info$size[[1L]] == 0L) {
    return(if (length(rows)) do.call(rbind, rows) else NULL)
  }
  raw = identity_read_raw(path)
  if (any(raw == as.raw(0L))) {
    return(if (length(rows)) do.call(rbind, rows) else NULL)
  }
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  for (line_number in seq_along(lines)) {
    positions = identity_match_positions(lines[[line_number]])
    for (ordinal in seq_along(positions)) {
      add(
        paste0(
          "content:", line_number, ":", ordinal, ":", lines[[line_number]],
          "\n"
        ),
        lines[[line_number]], positions[[ordinal]], "content"
      )
    }
  }
  if (length(rows)) do.call(rbind, rows) else NULL
}

identity_scan_occurrences = function(
    root = identity_repository_root(), mode = "tracked-source") {
  if (!identical(mode, "tracked-source")) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_MODE", mode)
  }
  paths = identity_git_tracked_paths(root)
  paths = paths[vapply(paths, function(relative) {
    candidate = file.path(root, relative)
    file.exists(candidate) && !dir.exists(candidate) &&
      isTRUE(file_test("-f", candidate))
  }, logical(1))]
  rows = lapply(paths, function(relative) {
    identity_occurrences_for_path(root, relative)
  })
  rows = rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(data.frame(
      path = character(), category = character(),
      active_owner = character(), record = character(), kind = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

identity_build_occurrence_allowlist = function(
    root = identity_repository_root(), mode = "tracked-source") {
  occurrences = identity_scan_occurrences(root, mode)
  retained = occurrences[is.na(occurrences$active_owner), , drop = FALSE]
  if (anyNA(retained$category)) {
    missing = unique(retained$path[is.na(retained$category)])
    identity_abort(
      "UNEXPECTED_OLD_IDENTITY_UNCLASSIFIED", paste(missing, collapse = ",")
    )
  }
  if (!nrow(retained)) {
    return(as.data.frame(setNames(
      replicate(
        length(identity_historical_allowlist_fields()),
        character(), simplify = FALSE
      ),
      identity_historical_allowlist_fields()
    ), stringsAsFactors = FALSE))
  }
  key = paste(retained$path, retained$category, sep = "\r")
  keys = sort(unique(key), method = "radix")
  rows = lapply(keys, function(item) {
    selected = retained[key == item, , drop = FALSE]
    category = selected$category[[1L]]
    path = selected$path[[1L]]
    data.frame(
      path = path,
      category = category,
      expected_count = as.character(nrow(selected)),
      literal_or_line_digest = identity_hash_raw(charToRaw(paste0(
        selected$record, collapse = ""
      ))),
      file_digest = if (identical(
        category, "immutable-historical-evidence"
      )) {
        identity_hash_file(identity_resolve_path(root, path))
      } else {
        ""
      },
      rationale = identity_category_rationale(category),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  value = do.call(rbind, rows)
  value[order(value$path, value$category, method = "radix"), , drop = FALSE]
}

identity_validate_occurrence_allowlist = function(
    value, root = identity_repository_root(), mode = "tracked-source") {
  if (!is.data.frame(value) ||
      !identical(names(value), identity_historical_allowlist_fields())) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_FIELDS")
  }
  value[] = lapply(value, as.character)
  required = c(
    "path", "category", "expected_count", "literal_or_line_digest", "rationale"
  )
  if (anyNA(value) || any(!nzchar(as.matrix(value[required]))) ||
      any(as.matrix(value) != trimws(as.matrix(value)))) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_INCOMPLETE")
  }
  key = paste(value$path, value$category, sep = "\r")
  if (anyDuplicated(key)) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_DUPLICATE")
  }
  if (any(!value$category %in% identity_occurrence_categories())) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_CATEGORY")
  }
  invisible(lapply(value$path, function(relative) {
    tryCatch(
      identity_resolve_path(root, relative),
      error = function(error) identity_abort(
        "UNEXPECTED_OLD_IDENTITY_PATH", relative
      )
    )
  }))
  count = suppressWarnings(as.integer(value$expected_count))
  if (anyNA(count) || any(count < 1L) ||
      !identical(as.character(count), value$expected_count)) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_COUNT")
  }
  if (any(!grepl("^[0-9a-f]{64}$", value$literal_or_line_digest))) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_DIGEST")
  }
  immutable = value$category == "immutable-historical-evidence"
  if (any(!grepl("^[0-9a-f]{64}$", value$file_digest[immutable])) ||
      any(nzchar(value$file_digest[!immutable]))) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_FILE_DIGEST")
  }

  observed = identity_build_occurrence_allowlist(root, mode)
  observed_key = paste(observed$path, observed$category, sep = "\r")
  missing = setdiff(observed_key, key)
  extra = setdiff(key, observed_key)
  if (length(missing)) {
    identity_abort(
      "UNEXPECTED_OLD_IDENTITY_MISSING", paste(missing, collapse = ",")
    )
  }
  if (length(extra)) {
    identity_abort(
      "UNEXPECTED_OLD_IDENTITY_STALE", paste(extra, collapse = ",")
    )
  }
  value = value[match(observed_key, key), , drop = FALSE]
  comparable = c(
    "path", "category", "expected_count", "literal_or_line_digest",
    "file_digest", "rationale"
  )
  if (!identical(value[comparable], observed[comparable])) {
    identity_abort("UNEXPECTED_OLD_IDENTITY_DRIFT")
  }
  invisible(TRUE)
}

identity_expected_historical_allowlist = function(
    root = identity_repository_root()) {
  identity_build_occurrence_allowlist(root, "tracked-source")
}

identity_validate_historical_allowlist = function(value, root, registry) {
  identity_validate_occurrence_allowlist(
    value, root = root, mode = "tracked-source"
  )
}

identity_check_occurrences = function(
    mode = "tracked-source", root = identity_repository_root(),
    allowlist_path = identity_historical_allowlist_path(root)) {
  occurrences = identity_scan_occurrences(root, mode)
  allowlist = identity_read_historical_allowlist(allowlist_path)
  identity_validate_occurrence_allowlist(
    allowlist, root = root, mode = mode
  )
  active = occurrences[!is.na(occurrences$active_owner), , drop = FALSE]
  list(
    clean = TRUE,
    mode = mode,
    unexpected_occurrences = 0L,
    allowlisted_occurrences = as.integer(sum(
      as.integer(allowlist$expected_count)
    )),
    active_occurrences = as.integer(nrow(active)),
    active_owners = sort(unique(active$active_owner), method = "radix"),
    allowlist = allowlist
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

identity_usage = function() {
  paste(
    "Usage:",
    "  rtk Rscript --vanilla tools/check_identity_migration.R --historical-only",
    "  rtk Rscript --vanilla tools/check_identity_migration.R --tracked-source",
    sep = "\n"
  )
}

identity_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  if (identical(arguments, "--help")) {
    cat(identity_usage(), "\n")
    return(invisible(0L))
  }
  if (identical(arguments, "--historical-only")) {
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
    return(invisible(0L))
  }
  if (identical(arguments, "--tracked-source")) {
    result = identity_check_occurrences("tracked-source")
    cat("Tracked source identity audit: PASS\n")
    cat(sprintf(
      "Allowlisted-predecessor-occurrences: %s\n",
      result$allowlisted_occurrences
    ))
    cat(sprintf(
      "Active-owner-occurrences: %s\n", result$active_occurrences
    ))
    if (length(result$active_owners)) {
      cat(sprintf(
        "Active-owners: %s\n", paste(result$active_owners, collapse = ",")
      ))
    }
    return(invisible(0L))
  }
  identity_abort("UNEXPECTED_OLD_IDENTITY_ARGUMENT")
}

if (sys.nframe() == 0L) identity_main()
