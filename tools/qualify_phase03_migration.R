#!/usr/bin/env Rscript

qualification_abort = function(code, detail = NULL) {
  message = if (is.null(detail) || !length(detail) || !nzchar(detail)) {
    code
  } else {
    paste(code, detail)
  }
  stop(message, call. = FALSE)
}

qualification_script_path = local({
  source_files = vapply(sys.frames(), function(frame) {
    value = frame$ofile
    if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
  }, character(1))
  source_files = source_files[nzchar(source_files)]
  file_argument = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(source_files)) {
    normalizePath(tail(source_files, 1L), winslash = "/", mustWork = TRUE)
  } else if (length(file_argument)) {
    normalizePath(
      sub("^--file=", "", file_argument[[1L]]),
      winslash = "/", mustWork = TRUE
    )
  } else {
    NA_character_
  }
})

qualification_repository_root = function() {
  candidates = c(
    if (!is.na(qualification_script_path)) {
      dirname(dirname(qualification_script_path))
    } else character(),
    getwd()
  )
  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        file.exists(file.path(candidate, "NAMESPACE")) &&
        dir.exists(file.path(candidate, ".git"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  qualification_abort("QUALIFICATION_REPOSITORY_ROOT_NOT_FOUND")
}

qualification_hash_raw = function(value) {
  if (!is.raw(value)) qualification_abort("QUALIFICATION_HASH_INPUT_INVALID")
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(unclass(as.character(openssl::sha256(value))))
  }
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(value, algo = "sha256", serialize = FALSE))
  }
  qualification_abort("QUALIFICATION_SHA256_UNAVAILABLE")
}

qualification_read_raw = function(path, maximum = 1024^3) {
  info = file.info(path)
  if (!nrow(info) || is.na(info$size[[1L]]) || info$size[[1L]] < 0 ||
      info$size[[1L]] > maximum || !isTRUE(file_test("-f", path))) {
    qualification_abort("QUALIFICATION_FILE_INVALID", path)
  }
  connection = file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  readBin(connection, "raw", n = as.integer(info$size[[1L]]))
}

qualification_hash_file = function(path) {
  qualification_hash_raw(qualification_read_raw(path))
}

qualification_hash_tree = function(root) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  relative = list.files(
    root, recursive = TRUE, all.files = TRUE, full.names = FALSE,
    include.dirs = FALSE, no.. = TRUE
  )
  relative = relative[!grepl("^\\.git(/|$)", relative)]
  relative = sort(unique(relative), method = "radix")
  records = lapply(relative, function(path) {
    absolute = file.path(root, path)
    link = Sys.readlink(absolute)
    payload = if (nzchar(link)) {
      paste0("link:", link)
    } else {
      paste0("file:", qualification_hash_file(absolute))
    }
    mode = sprintf("%04o", as.integer(file.info(absolute)$mode))
    c(
      charToRaw(path), as.raw(0L), charToRaw(mode), as.raw(0L),
      charToRaw(payload), charToRaw("\n")
    )
  })
  qualification_hash_raw(do.call(c, records))
}

qualification_require_digest = function(observed, expected, label) {
  valid = function(value) {
    is.character(value) && length(value) == 1L && !is.na(value) &&
      grepl("^[0-9a-f]{64}$", value)
  }
  if (!valid(observed) || !valid(expected) || !identical(observed, expected)) {
    qualification_abort("QUALIFICATION_DIGEST_MISMATCH", label)
  }
  invisible(TRUE)
}

qualification_git = function() {
  candidates = c("/usr/bin/git", Sys.which("git"))
  candidates = candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) qualification_abort("QUALIFICATION_GIT_UNAVAILABLE")
  normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
}

qualification_r = function(name = c("R", "Rscript")) {
  name = match.arg(name)
  path = file.path(R.home("bin"), name)
  if (!file.exists(path)) qualification_abort("QUALIFICATION_R_UNAVAILABLE", name)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

qualification_temporary_parent = function() {
  candidates = unique(c(Sys.getenv("TMPDIR", unset = ""), "/tmp"))
  candidates = candidates[nzchar(candidates) & dir.exists(candidates)]
  writable = candidates[file.access(candidates, mode = 2L) == 0L]
  if (!length(writable)) {
    qualification_abort("QUALIFICATION_TEMP_PARENT_UNAVAILABLE")
  }
  normalizePath(writable[[1L]], winslash = "/", mustWork = TRUE)
}

qualification_latest_root = function(paths) {
  paths = as.character(paths)
  paths = paths[dir.exists(paths)]
  if (!length(paths)) return(character())
  modified = file.info(paths)$mtime
  if (all(is.na(modified))) {
    qualification_abort("QUALIFICATION_TEMP_ROOT_TIME_UNAVAILABLE")
  }
  paths[[which.max(modified)]]
}

qualification_status_path = function(line) {
  value = if (nchar(line) >= 4L) substr(line, 4L, nchar(line)) else ""
  if (grepl(" -> ", value, fixed = TRUE)) {
    value = tail(strsplit(value, " -> ", fixed = TRUE)[[1L]], 1L)
  }
  gsub("\\\\", "/", value)
}

qualification_ignored_workspace_path = function(path) {
  path %in% c(
    ".planning/WINDOWS.md",
    ".planning/config.json",
    ".planning/milestone.lock"
  ) || grepl("^\\.gsd(/|$)", path) ||
    grepl("^\\.planning/research/\\.cache(/|$)", path) ||
    grepl(
      "^\\.planning/phases/02-compatibility-and-numerical-baseline/(02-06-baseline-proposal|02-review-fix-baseline-proposal)(/|$)",
      path
    ) || grepl("^src/[^/]+[.](o|so)$", path)
}

qualification_validate_clean_status = function(lines) {
  lines = as.character(lines)
  lines = lines[nzchar(lines)]
  paths = vapply(lines, qualification_status_path, character(1))
  relevant = lines[!vapply(paths, qualification_ignored_workspace_path,
                            logical(1))]
  if (length(relevant)) {
    qualification_abort(
      "QUALIFICATION_RELEVANT_STATE_DIRTY",
      paste(relevant, collapse = " | ")
    )
  }
  invisible(TRUE)
}

qualification_run_command = function(
    stage, command, arguments = character(), directory = NULL,
    environment = character(), log_directory) {
  if (!dir.exists(log_directory)) {
    dir.create(log_directory, recursive = TRUE, showWarnings = FALSE)
  }
  label = gsub("[^A-Za-z0-9_.-]", "-", stage)
  log = file.path(log_directory, paste0(label, ".log"))
  old = NULL
  if (!is.null(directory)) {
    old = setwd(directory)
    on.exit(setwd(old), add = TRUE)
  }
  status = suppressWarnings(system2(
    command, arguments, stdout = log, stderr = log, env = environment
  ))
  if (is.null(status)) status = 0L
  output = if (file.exists(log)) {
    readLines(log, warn = FALSE, encoding = "UTF-8")
  } else {
    character()
  }
  result = list(
    command = paste(c(shQuote(command), arguments), collapse = " "),
    status = as.integer(status),
    log = normalizePath(log, winslash = "/", mustWork = TRUE),
    log_digest = qualification_hash_file(log),
    output = output
  )
  if (!identical(result$status, 0L)) {
    qualification_abort(
      "QUALIFICATION_COMMAND_FAILED",
      paste0(stage, " status=", result$status, " log=", result$log)
    )
  }
  result
}

qualification_internal_result = function(stage, lines, log_directory) {
  if (!dir.exists(log_directory)) {
    dir.create(log_directory, recursive = TRUE, showWarnings = FALSE)
  }
  log = file.path(log_directory, paste0(stage, ".log"))
  writeLines(as.character(lines), log, useBytes = TRUE)
  list(
    command = paste0("internal:", stage), status = 0L,
    log = normalizePath(log, winslash = "/", mustWork = TRUE),
    log_digest = qualification_hash_file(log), output = as.character(lines)
  )
}

qualification_native_contract = function() {
  c(
    "_GEModelR_GEModelR_dense_lu_factor" = 1L,
    "_GEModelR_GEModelR_dense_lu_solve" = 2L,
    "_GEModelR_GEModelR_dense_lu_release" = 1L,
    "_GEModelR_GEModelR_eliminate_blocks" = 6L,
    "_GEModelR_GEModelR_reconstruct_blocks" = 7L,
    "_GEModelR_GEModelR_schur_cpp_capabilities" = 0L,
    "_GEModelR_GEModelR_sparse_lu_solve" = 2L,
    "_GEModelR_GEModelR_sparse_pattern_hash" = 1L,
    "_GEModelR_GEModelR_schur_accumulate_batch_parallel" = 9L,
    "_GEModelR_GEModelR_schur_accumulate_global" = 7L,
    "_GEModelR_GEModelR_schur_accumulate_batch" = 9L
  )
}

qualification_required_stages = function() {
  c(
    "clean-state", "git-export", "extract", "source-identity", "build",
    "archive-identity", "check", "install", "install-identity",
    "fresh-workflow", "full-suite", "predecessor-digests",
    "historical-evidence", "phase02-original", "serialization-bugfix",
    "phase02-migration", "release-blockers", "repository-readonly"
  )
}

qualification_stage_parents = function() {
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

qualification_example_stages = function() {
  names = qualification_required_stages()
  parents = qualification_stage_parents()
  output = vapply(names, function(stage) {
    qualification_hash_raw(charToRaw(paste0("output:", stage)))
  }, character(1))
  root_digest = qualification_hash_raw(charToRaw("ROOT"))
  parent_digest = vapply(names, function(stage) {
    parent = unname(parents[[stage]])
    if (identical(parent, "ROOT")) root_digest else unname(output[[parent]])
  }, character(1))
  data.frame(
    stage = names,
    parent_stage = unname(parents[names]),
    parent_digest = parent_digest,
    input_digest = parent_digest,
    output_digest = unname(output[names]),
    stringsAsFactors = FALSE
  )
}

qualification_validate_stage_chain = function(stages) {
  required_columns = c(
    "stage", "parent_stage", "parent_digest", "input_digest",
    "output_digest"
  )
  if (!is.data.frame(stages) || !all(required_columns %in% names(stages)) ||
      !identical(stages$stage, qualification_required_stages())) {
    qualification_abort("QUALIFICATION_STAGE_SET_MISMATCH")
  }
  if (anyDuplicated(stages$stage) || anyNA(stages[required_columns]) ||
      any(!grepl("^[0-9a-f]{64}$", unlist(
        stages[c("parent_digest", "input_digest", "output_digest")],
        use.names = FALSE
      )))) {
    qualification_abort("QUALIFICATION_STAGE_RECORD_INVALID")
  }
  expected_parents = unname(qualification_stage_parents()[stages$stage])
  if (!identical(stages$parent_stage, expected_parents)) {
    qualification_abort("QUALIFICATION_STAGE_PARENT_MISMATCH")
  }
  for (index in seq_len(nrow(stages))) {
    if (!identical(
      stages$input_digest[[index]], stages$parent_digest[[index]]
    )) {
      qualification_abort(
        "QUALIFICATION_STAGE_INPUT_MISMATCH", stages$stage[[index]]
      )
    }
    parent = stages$parent_stage[[index]]
    if (!identical(parent, "ROOT")) {
      parent_index = match(parent, stages$stage)
      if (is.na(parent_index) || parent_index >= index || !identical(
        stages$parent_digest[[index]], stages$output_digest[[parent_index]]
      )) {
        qualification_abort(
          "QUALIFICATION_STAGE_PARENT_MISMATCH", stages$stage[[index]]
        )
      }
    }
  }
  invisible(TRUE)
}

qualification_reviewed_note_allowlist = function() {
  c("* checking DESCRIPTION meta-information ... NOTE\nNicht-Standard Lizenzspezifikation:\n  What license is it under?\nZu standardisieren: FALSE", "* checking installed package size ... NOTE\n  installed size is  8.9Mb\n  sub-directories of 1Mb or more:\n    libs   7.9Mb")
}

qualification_validate_notes = function(
    observed, allowlist = qualification_reviewed_note_allowlist()) {
  observed = sort(unique(as.character(observed)), method = "radix")
  allowlist = sort(unique(as.character(allowlist)), method = "radix")
  if (!identical(observed, allowlist)) {
    detail = paste(c(
      paste0("missing=", paste(setdiff(allowlist, observed), collapse = " || ")),
      paste0("unexpected=", paste(setdiff(observed, allowlist), collapse = " || "))
    ), collapse = " ")
    qualification_abort("QUALIFICATION_CHECK_NOTE_DRIFT", detail)
  }
  invisible(TRUE)
}

qualification_normalize_check_line = function(line, temporary_root) {
  value = gsub("[[:space:]]+$", "", line)
  root = normalizePath(temporary_root, winslash = "/", mustWork = TRUE)
  value = gsub(root, "<QUALIFICATION_ROOT>", value, fixed = TRUE)
  value = gsub("/tmp/Rtmp[^/[:space:]]+", "<R-TEMP>", value)
  value
}

qualification_extract_check_findings = function(lines, temporary_root) {
  starts = grep("^\\* checking .* \\.\\.\\. (ERROR|WARNING|NOTE)$", lines)
  if (!length(starts)) {
    return(list(errors = character(), warnings = character(), notes = character()))
  }
  kinds = sub("^.* \\.\\.\\. ", "", lines[starts])
  blocks = lapply(seq_along(starts), function(index) {
    first = starts[[index]]
    next_checks = which(seq_along(lines) > first & grepl("^\\* checking ", lines))
    last = if (length(next_checks)) next_checks[[1L]] - 1L else length(lines)
    value = vapply(
      lines[seq.int(first, last)], qualification_normalize_check_line,
      character(1), temporary_root = temporary_root
    )
    while (length(value) && !nzchar(tail(value, 1L))) {
      value = head(value, -1L)
    }
    paste(value, collapse = "\n")
  })
  list(
    errors = unlist(blocks[kinds == "ERROR"], use.names = FALSE),
    warnings = unlist(blocks[kinds == "WARNING"], use.names = FALSE),
    notes = unlist(blocks[kinds == "NOTE"], use.names = FALSE)
  )
}

qualification_validate_package_path = function(package_path, library) {
  library = normalizePath(library, winslash = "/", mustWork = TRUE)
  package_path = normalizePath(package_path, winslash = "/", mustWork = TRUE)
  expected = normalizePath(
    file.path(library, "GEModelR"), winslash = "/", mustWork = TRUE
  )
  if (!identical(package_path, expected)) {
    qualification_abort("QUALIFICATION_AMBIENT_LIBRARY", package_path)
  }
  invisible(TRUE)
}

qualification_validate_static_identity = function(root) {
  description = read.dcf(file.path(root, "DESCRIPTION"))[1L, ]
  namespace = readLines(file.path(root, "NAMESPACE"), warn = FALSE)
  exports = readLines(file.path(root, "src", "RcppExports.cpp"), warn = FALSE)
  if (!identical(unname(description[["Package"]]), "GEModelR") ||
      !any(grepl("useDynLib(GEModelR, .registration=TRUE)", namespace,
                 fixed = TRUE)) ||
      sum(grepl("R_init_GEModelR", exports, fixed = TRUE)) != 1L ||
      !any(grepl("R_useDynamicSymbols(dll, FALSE)", exports, fixed = TRUE))) {
    qualification_abort("QUALIFICATION_STATIC_IDENTITY_MISMATCH")
  }
  contract = qualification_native_contract()
  quote = intToUtf8(34L)
  for (name in names(contract)) {
    prefix = paste0("{", quote, name, quote)
    suffix = paste0(", ", unname(contract[[name]]), "}")
    matches = grepl(prefix, exports, fixed = TRUE) &
      grepl(suffix, exports, fixed = TRUE)
    if (sum(matches) != 1L) {
      qualification_abort("QUALIFICATION_NATIVE_CONTRACT_MISMATCH", name)
    }
  }
  if (sum(grepl(paste0("{", quote, "_GEModelR_"), exports, fixed = TRUE)) !=
      length(contract)) {
    qualification_abort("QUALIFICATION_NATIVE_ROUTINE_COUNT_MISMATCH")
  }
  invisible(TRUE)
}

qualification_stage_row = function(
    stage, parent_stage, parent_digest, output_digest, command_result,
    input_path, result) {
  data.frame(
    stage = stage,
    parent_stage = parent_stage,
    parent_digest = parent_digest,
    input_digest = parent_digest,
    output_digest = output_digest,
    command = command_result$command,
    status = as.character(command_result$status),
    input_path = input_path,
    log_sha256 = command_result$log_digest,
    result = paste(result, collapse = "; "),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

qualification_append_stage = function(
    stages, stage, output_digest, command_result, input_path, result,
    root_digest) {
  parent = unname(qualification_stage_parents()[[stage]])
  parent_digest = if (identical(parent, "ROOT")) {
    root_digest
  } else {
    index = match(parent, stages$stage)
    if (is.na(index)) {
      qualification_abort("QUALIFICATION_STAGE_PARENT_MISSING", stage)
    }
    stages$output_digest[[index]]
  }
  rbind(stages, qualification_stage_row(
    stage, parent, parent_digest, output_digest, command_result,
    input_path, result
  ))
}

qualification_empty_stages = function() {
  data.frame(
    stage = character(), parent_stage = character(),
    parent_digest = character(), input_digest = character(),
    output_digest = character(), command = character(), status = character(),
    input_path = character(), log_sha256 = character(), result = character(),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

qualification_shell = function(parts) {
  paste(vapply(parts, shQuote, character(1)), collapse = " ")
}

qualification_extract_shell = function(export, source, verification) {
  paste(
    qualification_shell(c(
      "/usr/bin/tar", "-xf", export, "-C", source, "--same-permissions"
    )),
    "&&",
    qualification_shell(c(
      "/usr/bin/tar", "-xf", export, "-C", verification,
      "--same-permissions"
    ))
  )
}

qualification_isolated_environment = function(
    library, gap_test_library = library) {
  library = normalizePath(library, winslash = "/", mustWork = TRUE)
  gap_test_library = normalizePath(
    gap_test_library, winslash = "/", mustWork = TRUE
  )
  ambient = normalizePath(.libPaths(), winslash = "/", mustWork = TRUE)
  ambient = ambient[!vapply(ambient, function(path) {
    dir.exists(file.path(path, "GEModelR"))
  }, logical(1))]
  c(
    paste0("R_LIBS_USER=", library),
    paste0("R_LIBS_SITE=", paste(ambient, collapse = .Platform$path.sep)),
    paste0("GEModelR_GAP_TEST_LIBRARY=", gap_test_library),
    "R_ENVIRON_USER=/dev/null",
    "R_PROFILE_USER=/dev/null"
  )
}

qualification_write_fresh_script = function(path) {
  contract = qualification_native_contract()
  names_text = paste(encodeString(names(contract), quote = "\""), collapse = ", ")
  arities_text = paste(sprintf("%dL", unname(contract)), collapse = ", ")
  lines = c(
    "args = commandArgs(trailingOnly = TRUE)",
    "isolated = normalizePath(args[[1L]], winslash = '/', mustWork = TRUE)",
    "source = normalizePath(args[[2L]], winslash = '/', mustWork = TRUE)",
    "result_path = args[[3L]]",
    "library(GEModelR, lib.loc = isolated, character.only = FALSE)",
    "package_path = normalizePath(find.package('GEModelR'), winslash = '/', mustWork = TRUE)",
    "stopifnot(identical(package_path, file.path(isolated, 'GEModelR')))",
    "other = setdiff(.libPaths(), isolated)",
    "stopifnot(!any(dir.exists(file.path(other, 'GEModelR'))))",
    "stopifnot(identical(unname(getNamespaceName(asNamespace('GEModelR'))), 'GEModelR'))",
    "dll = getLoadedDLLs()[['GEModelR']]",
    "stopifnot(!is.null(dll))",
    "dll_path = normalizePath(dll[['path']], winslash = '/', mustWork = TRUE)",
    "stopifnot(identical(tools::file_path_sans_ext(basename(dll_path)), 'GEModelR'))",
    "stopifnot(identical(dll[['dynamicLookup']], FALSE))",
    paste0("expected_names = c(", names_text, ")"),
    paste0("expected_arities = c(", arities_text, ")"),
    "names(expected_arities) = expected_names",
    "registered = getDLLRegisteredRoutines(dll)[['.Call']]",
    "observed_arities = vapply(registered, function(value) as.integer(value[['numParameters']]), integer(1))",
    "stopifnot(identical(observed_arities, expected_arities))",
    "nm = Sys.which('nm')",
    "stopifnot(nzchar(nm))",
    "symbols = system2(nm, c('-D', shQuote(dll_path)), stdout = TRUE, stderr = TRUE)",
    "stopifnot(any(grepl(' R_init_GEModelR$', symbols)))",
    "regions = c('north', 'south', 'east')",
    "input = list(basedata = list(weight = array(c(1, 1.5, 2), dim = 3L, dimnames = list(reg = regions)), stock = array(c(100, 200, 300), dim = 3L, dimnames = list(reg = regions))))",
    "model = GEModel$new()",
    "model$loadTablo(file.path(source, 'tests', 'testthat', 'fixtures', 'three-region.tab'))",
    "model$setClosure('tax')",
    "model$loadData(input, engine = 'sparse')",
    "model$setShocks(setNames(c(1, 2, -1), c('tax[\"north\"]', 'tax[\"south\"]', 'tax[\"east\"]')))",
    "model$solveModel(iter = 1, steps = 1, engine = 'sparse', postsim = TRUE, diagnostics = TRUE, output = 'full', backend = 'Matrix', reduction = 'off')",
    "stopifnot(length(model$solution) > 0L, all(is.finite(model$solution)))",
    "current = tempfile(fileext = '.rds')",
    "current_resaved = tempfile(fileext = '.rds')",
    "predecessor_resaved = tempfile(fileext = '.rds')",
    "model$saveState(current)",
    "current_model = GEModel$new()",
    "current_model$loadState(current)",
    "current_model$saveState(current_resaved)",
    "current_payload = readRDS(current_resaved)",
    "stopifnot(identical(current_payload$package_lineage$name, 'GEModelR'))",
    "predecessor = file.path(source, 'tests', 'testthat', 'fixtures', 'serialization', 'tabloToR-schema1-lineage.rds')",
    "predecessor_model = GEModel$new()",
    "predecessor_model$loadState(predecessor)",
    "predecessor_model$saveState(predecessor_resaved)",
    "predecessor_payload = readRDS(predecessor_resaved)",
    "stopifnot(identical(predecessor_payload$package_lineage$name, 'GEModelR'))",
    "digest = function(path) unname(tools::md5sum(path))",
    "saveRDS(list(package_path = package_path, dll_path = dll_path, dynamic_lookup = dll[['dynamicLookup']], initializer = 'R_init_GEModelR', routines = observed_arities, solution_md5 = digest(current), current_resave_md5 = digest(current_resaved), predecessor_resave_md5 = digest(predecessor_resaved), current_lineage = current_payload$package_lineage, predecessor_lineage = predecessor_payload$package_lineage), result_path, version = 3L)",
    "cat('Fresh installed public/native/serialization workflow: PASS\\n')"
  )
  writeLines(lines, path, useBytes = TRUE)
  invisible(path)
}

qualification_r_string = function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    qualification_abort("QUALIFICATION_R_STRING_INVALID")
  }
  encodeString(value, quote = "\"", justify = "none")
}

qualification_suite_expression = function(library, test_directory) {
  library = qualification_r_string(library)
  tests = qualification_r_string(test_directory)
  paste0(
    "library(testthat); library(GEModelR, lib.loc=", library,
    "); result = testthat::test_dir(", tests,
    ", reporter='summary', stop_on_failure=TRUE, stop_on_warning=FALSE, ",
    "package='GEModelR', load_package='installed'); ",
    "stopifnot(!any(vapply(result, function(x) length(x$results) && ",
    "any(vapply(x$results, inherits, logical(1), 'expectation_failure')), ",
    "logical(1))))"
  )
}

qualification_required_full_suite_tests = function() {
  file.path(
    "tests", "testthat",
    c(
      "test-installed-benchmark-execution.R",
      "test-benchmark-correctness-gate.R",
      "test-serialization-leaf-types.R"
    )
  )
}

qualification_assert_output = function(output, patterns, stage) {
  text = paste(output, collapse = "\n")
  missing = patterns[!vapply(patterns, grepl, logical(1), x = text,
                             fixed = TRUE)]
  if (length(missing)) {
    qualification_abort(
      "QUALIFICATION_STAGE_OUTPUT_MISMATCH",
      paste(stage, paste(missing, collapse = " | "))
    )
  }
  invisible(TRUE)
}

qualification_phase02_migration_arguments = function(source) {
  c(
    "--vanilla", file.path(source, "tools", "refresh_phase02_baselines.R"),
    "--check-migration-source"
  )
}


qualification_phase02_original_arguments = function(source) {
  c(
    "--vanilla", file.path(source, "tools", "refresh_phase02_baselines.R"),
    "--check-original-artifacts"
  )
}

qualification_manifest_frame = function(
    stages, head, export_digest, extracted_digest, archive_digest,
    installation_digest, root, cleanup) {
  frame = data.frame(
    Schema = rep("gemodelr-phase03-qualification-v1", nrow(stages)),
    Stage = stages$stage,
    Parent.Stage = stages$parent_stage,
    Parent.Digest = stages$parent_digest,
    Input.Digest = stages$input_digest,
    Output.Digest = stages$output_digest,
    Command = stages$command,
    Status = stages$status,
    Input.Path = stages$input_path,
    Log.SHA256 = stages$log_sha256,
    Result = stages$result,
    HEAD = rep(head, nrow(stages)),
    Export.SHA256 = rep(export_digest, nrow(stages)),
    Extracted.Tree.SHA256 = rep(extracted_digest, nrow(stages)),
    Package.Archive.SHA256 = rep(archive_digest, nrow(stages)),
    Installation.Tree.SHA256 = rep(installation_digest, nrow(stages)),
    Temporary.Root = rep(root, nrow(stages)),
    Cleanup = rep(cleanup, nrow(stages)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  names(frame) = gsub("[.]", "-", names(frame))
  frame
}

qualification_execute = function(root = qualification_repository_root()) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  git = qualification_git()
  status_before = system2(
    git, c("-C", shQuote(root), "status", "--porcelain=v1",
           "--untracked-files=all"), stdout = TRUE, stderr = TRUE
  )
  status_code = attr(status_before, "status")
  if (!is.null(status_code) && status_code != 0L) {
    qualification_abort("QUALIFICATION_GIT_STATUS_FAILED")
  }
  qualification_validate_clean_status(status_before)
  head = system2(
    git, c("-C", shQuote(root), "rev-parse", "HEAD"),
    stdout = TRUE, stderr = TRUE
  )
  if (length(head) != 1L || !grepl("^[0-9a-f]{40}$", head)) {
    qualification_abort("QUALIFICATION_HEAD_INVALID")
  }
  head = head[[1L]]
  root_digest = qualification_hash_raw(charToRaw(head))

  temporary_root = tempfile(
    "GEModelR-phase03-qualification-",
    tmpdir = qualification_temporary_parent()
  )
  if (!dir.create(temporary_root, recursive = TRUE, showWarnings = FALSE)) {
    qualification_abort("QUALIFICATION_TEMP_ROOT_FAILED")
  }
  temporary_root = normalizePath(
    temporary_root, winslash = "/", mustWork = TRUE
  )
  success = FALSE
  on.exit({
    if (isTRUE(success)) {
      unlink(temporary_root, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)
  logs = file.path(temporary_root, "logs")
  source = file.path(temporary_root, "source")
  check = file.path(temporary_root, "check")
  library = file.path(temporary_root, "library")
  archive_audit = file.path(temporary_root, "archive-audit")
  extraction_verification = file.path(
    temporary_root, "extraction-verification"
  )
  dir.create(logs, recursive = TRUE)
  dir.create(source)
  dir.create(check)
  dir.create(library)
  dir.create(archive_audit)
  dir.create(extraction_verification)
  export = file.path(temporary_root, "git-export.tar")
  stages = qualification_empty_stages()

  clean_result = qualification_internal_result(
    "clean-state",
    c(paste0("HEAD=", head), status_before, "Relevant tracked state: CLEAN"),
    logs
  )
  clean_digest = qualification_hash_raw(charToRaw(paste(
    c(head, status_before), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "clean-state", clean_digest, clean_result, root,
    "recorded HEAD; relevant tracked state clean", root_digest
  )

  export_shell = paste(
    qualification_shell(c(
      git, "-C", root, "archive", "--format=tar",
      paste0("--output=", export), head
    )),
    "&&",
    paste0(qualification_shell(c(git, "get-tar-commit-id")),
           " < ", shQuote(export))
  )
  export_result = qualification_run_command(
    "git-export", "/bin/sh", c("-c", shQuote(export_shell)),
    log_directory = logs
  )
  qualification_assert_output(export_result$output, head, "git-export")
  export_digest = qualification_hash_file(export)
  stages = qualification_append_stage(
    stages, "git-export", export_digest, export_result, root,
    paste0("git archive HEAD sha256=", export_digest), root_digest
  )

  extract_shell = qualification_extract_shell(
    export, source, extraction_verification
  )
  extract_result = qualification_run_command(
    "extract", "/bin/sh", c("-c", shQuote(extract_shell)),
    log_directory = logs
  )
  extracted_digest = qualification_hash_tree(source)
  verification_digest = qualification_hash_tree(extraction_verification)
  qualification_require_digest(
    extracted_digest, verification_digest, "extracted-tree"
  )
  unlink(extraction_verification, recursive = TRUE, force = TRUE)
  stages = qualification_append_stage(
    stages, "extract", extracted_digest, extract_result, export,
    paste0("exact export extracted tree sha256=", extracted_digest),
    root_digest
  )

  source_shell = paste(
    qualification_shell(c(git, "-C", source, "init", "--quiet")), "&&",
    qualification_shell(c(git, "-C", source, "add", "--all", "--force")),
    "&&", qualification_shell(c(
      qualification_r("Rscript"), "--vanilla",
      file.path(source, "tools", "check_identity_migration.R"),
      "--tracked-source"
    )), "&&", qualification_shell(c(
      qualification_r("Rscript"), "--vanilla",
      file.path(source, "tools", "provenance_inventory.R"),
      "--check", paste0("--root=", source)
    ))
  )
  source_result = qualification_run_command(
    "source-identity", "/bin/sh", c("-c", shQuote(source_shell)),
    log_directory = logs
  )
  qualification_assert_output(
    source_result$output,
    c(
      "Tracked source identity audit: PASS",
      "Allowlisted-predecessor-occurrences: 706",
      "Active-owner-occurrences: 0",
      "provenance_status=reviewed rows=290 expected_keys=290"
    ),
    "source-identity"
  )
  qualification_validate_static_identity(source)
  qualification_require_digest(
    qualification_hash_tree(source), extracted_digest, "source-after-identity"
  )
  source_identity_digest = qualification_hash_raw(charToRaw(paste(
    c(extracted_digest, source_result$log_digest), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "source-identity", source_identity_digest, source_result, source,
    "706 retained predecessor occurrences; 0 active; provenance 290/290",
    root_digest
  )

  build_result = qualification_run_command(
    "build", qualification_r("R"),
    c("CMD", "build", "--no-manual", shQuote(source)),
    directory = temporary_root, log_directory = logs
  )
  archives = list.files(
    temporary_root, pattern = "^GEModelR_[^/]+[.]tar[.]gz$",
    full.names = TRUE
  )
  if (length(archives) != 1L) {
    qualification_abort("QUALIFICATION_ARCHIVE_CARDINALITY", length(archives))
  }
  package_archive = normalizePath(
    archives[[1L]], winslash = "/", mustWork = TRUE
  )
  archive_digest = qualification_hash_file(package_archive)
  stages = qualification_append_stage(
    stages, "build", archive_digest, build_result, source,
    paste0("one GEModelR source archive sha256=", archive_digest), root_digest
  )

  utils::untar(package_archive, exdir = archive_audit)
  archive_roots = list.dirs(archive_audit, recursive = FALSE, full.names = TRUE)
  if (length(archive_roots) != 1L) {
    qualification_abort("QUALIFICATION_ARCHIVE_ROOT_CARDINALITY")
  }
  qualification_validate_static_identity(archive_roots[[1L]])
  archive_identity_result = qualification_internal_result(
    "archive-identity",
    c(
      "Archive package identity: GEModelR",
      "Archive DLL initializer: R_init_GEModelR",
      "Archive registered routines: 11",
      paste0("Archive-SHA256=", archive_digest)
    ),
    logs
  )
  archive_identity_digest = qualification_hash_raw(charToRaw(paste(
    c(archive_digest, archive_identity_result$log_digest), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "archive-identity", archive_identity_digest,
    archive_identity_result, package_archive,
    "GEModelR metadata, initializer, dynamic policy, names and arities exact",
    root_digest
  )

  check_result = qualification_run_command(
    "check", qualification_r("R"),
    c("CMD", "check", "--no-manual", shQuote(package_archive)),
    directory = check, log_directory = logs
  )
  qualification_require_digest(
    qualification_hash_file(package_archive), archive_digest,
    "archive-after-check"
  )
  check_logs = list.files(
    check, pattern = "00check[.]log$", recursive = TRUE, full.names = TRUE
  )
  if (length(check_logs) != 1L) {
    qualification_abort("QUALIFICATION_CHECK_LOG_CARDINALITY")
  }
  check_root = dirname(check_logs[[1L]])
  check_tests = file.path(check_root, "tests", "testthat")
  if (!dir.exists(check_tests)) {
    qualification_abort("QUALIFICATION_CHECK_TESTS_MISSING")
  }
  required_suite_tests = file.path(
    check_root, qualification_required_full_suite_tests()
  )
  missing_suite_tests = required_suite_tests[!file.exists(required_suite_tests)]
  if (length(missing_suite_tests)) {
    qualification_abort(
      "QUALIFICATION_GAP_TESTS_MISSING",
      paste(missing_suite_tests, collapse = ",")
    )
  }
  check_lines = readLines(check_logs[[1L]], warn = FALSE, encoding = "UTF-8")
  findings = qualification_extract_check_findings(check_lines, temporary_root)
  if (length(findings$errors)) {
    qualification_abort(
      "QUALIFICATION_CHECK_ERRORS", paste(findings$errors, collapse = " || ")
    )
  }
  if (length(findings$warnings)) {
    qualification_abort(
      "QUALIFICATION_CHECK_WARNINGS",
      paste(findings$warnings, collapse = " || ")
    )
  }
  qualification_validate_notes(findings$notes)
  check_digest = qualification_hash_raw(charToRaw(paste(
    c(archive_digest, check_result$log_digest,
      vapply(findings$notes, function(note) {
        qualification_hash_raw(charToRaw(note))
      }, character(1))),
    collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "check", check_digest, check_result, package_archive,
    paste0(
      "R CMD check: 0 ERROR, 0 WARNING, ", length(findings$notes),
      " exact reviewed NOTE"
    ), root_digest
  )

  install_result = qualification_run_command(
    "install", qualification_r("R"),
    c("CMD", "INSTALL", paste0("--library=", shQuote(library)),
      shQuote(package_archive)),
    log_directory = logs
  )
  qualification_require_digest(
    qualification_hash_file(package_archive), archive_digest,
    "archive-after-install"
  )
  installed = file.path(library, "GEModelR")
  if (!dir.exists(installed)) {
    qualification_abort("QUALIFICATION_INSTALLATION_MISSING")
  }
  installation_digest = qualification_hash_tree(installed)
  stages = qualification_append_stage(
    stages, "install", installation_digest, install_result, package_archive,
    paste0("isolated installation sha256=", installation_digest), root_digest
  )

  qualification_validate_package_path(installed, library)
  installed_description = read.dcf(file.path(installed, "DESCRIPTION"))[1L, ]
  installed_dll = list.files(
    file.path(installed, "libs"), pattern = "^GEModelR[.](so|dll|dylib)$",
    recursive = TRUE, full.names = TRUE
  )
  if (!identical(unname(installed_description[["Package"]]), "GEModelR") ||
      length(installed_dll) != 1L) {
    qualification_abort("QUALIFICATION_INSTALLED_IDENTITY_MISMATCH")
  }
  install_identity_result = qualification_internal_result(
    "install-identity",
    c(
      paste0("Installed-Package-Path=", installed),
      paste0("Installed-DLL=", installed_dll[[1L]]),
      paste0("Installation-Tree-SHA256=", installation_digest)
    ),
    logs
  )
  install_identity_digest = qualification_hash_raw(charToRaw(paste(
    c(installation_digest, install_identity_result$log_digest),
    collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "install-identity", install_identity_digest,
    install_identity_result, installed,
    "isolated GEModelR package and GEModelR shared library exact", root_digest
  )

  fresh_script = file.path(temporary_root, "fresh-workflow.R")
  fresh_result_path = file.path(temporary_root, "fresh-workflow-result.rds")
  qualification_write_fresh_script(fresh_script)
  fresh_result = qualification_run_command(
    "fresh-workflow", qualification_r("Rscript"),
    c("--vanilla", shQuote(fresh_script), shQuote(library), shQuote(source),
      shQuote(fresh_result_path)),
    environment = qualification_isolated_environment(
      library, gap_test_library = library
    ),
    log_directory = logs
  )
  fresh = readRDS(fresh_result_path)
  qualification_validate_package_path(fresh$package_path, library)
  if (!identical(fresh$dynamic_lookup, FALSE) ||
      !identical(fresh$initializer, "R_init_GEModelR") ||
      !identical(fresh$routines, qualification_native_contract()) ||
      !identical(fresh$current_lineage$name, "GEModelR") ||
      !identical(fresh$predecessor_lineage$name, "GEModelR")) {
    qualification_abort("QUALIFICATION_FRESH_WORKFLOW_MISMATCH")
  }
  fresh_digest = qualification_hash_raw(serialize(fresh, NULL, version = 3L))
  stages = qualification_append_stage(
    stages, "fresh-workflow", fresh_digest, fresh_result, installed,
    c(
      "public solve finite", "current state restore/resave GEModelR",
      "approved predecessor restore/resave GEModelR", "R_init_GEModelR",
      "dynamicLookup FALSE", "11 exact registered routines"
    ), root_digest
  )

  suite_expression = qualification_suite_expression(library, check_tests)
  suite_result = qualification_run_command(
    "full-suite", qualification_r("R"),
    c("--vanilla", "-q", "-e", shQuote(suite_expression)),
    directory = check_root,
    environment = qualification_isolated_environment(
      library, gap_test_library = library
    ),
    log_directory = logs
  )
  suite_digest = qualification_hash_raw(charToRaw(paste(
    c(installation_digest, suite_result$log_digest), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "full-suite", suite_digest, suite_result, check_tests,
    "full R CMD check test copy against isolated installed GEModelR passed",
    root_digest
  )

  predecessor_result = qualification_run_command(
    "predecessor-digests", qualification_r("Rscript"),
    c("--vanilla", file.path(source, "tools", "check_predecessor_bridge.R"),
      "--verify-approved-digests"),
    directory = source, log_directory = logs
  )
  qualification_assert_output(
    predecessor_result$output,
    c("Approved predecessor evidence digests: PASS", "Registry-SHA256:",
      "Fixture-SHA256:"),
    "predecessor-digests"
  )
  predecessor_digest = qualification_hash_raw(charToRaw(paste(
    c(source_identity_digest, predecessor_result$log_digest), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "predecessor-digests", predecessor_digest,
    predecessor_result, source,
    "approved predecessor registry and fixture whole-file digests exact",
    root_digest
  )

  historical_result = qualification_run_command(
    "historical-evidence", qualification_r("Rscript"),
    c("--vanilla", file.path(source, "tools", "check_identity_migration.R"),
      "--historical-only"),
    directory = source, log_directory = logs
  )
  qualification_assert_output(
    historical_result$output,
    c("Historical identity audit: PASS", "Immutable-records: 5",
      "Protected-source-records: 4", "Protected-region-records: 1"),
    "historical-evidence"
  )
  historical_digest = qualification_hash_raw(charToRaw(paste(
    c(source_identity_digest, historical_result$log_digest), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "historical-evidence", historical_digest, historical_result,
    source,
    "immutable Phase 2/benchmark bytes and protected numerical source exact",
    root_digest
  )

  phase02_original_result = qualification_run_command(
    "phase02-original", qualification_r("Rscript"),
    qualification_phase02_original_arguments(source),
    directory = source, log_directory = logs
  )
  qualification_assert_output(
    phase02_original_result$output,
    c(
      "Phase 02 original artifact gate: PASS",
      "Accepted-canonical-hash: f6f2297a6ab257c9737a64354c82d7f1",
      "Original-artifacts-verified: 4",
      "Original-acceptance-verified: true"
    ),
    "phase02-original"
  )
  phase02_original_digest = qualification_hash_raw(charToRaw(paste(
    c(
      source_identity_digest, phase02_original_result$command,
      phase02_original_result$log_digest
    ),
    collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "phase02-original", phase02_original_digest,
    phase02_original_result, source,
    "immutable original Phase 2 artifacts and accepted hash exact",
    root_digest
  )

  serialization_bugfix_result = qualification_run_command(
    "serialization-bugfix", qualification_r("Rscript"),
    c(
      "--vanilla",
      file.path(source, "tools", "check_serialization_bugfix.R"),
      "--verify-approved"
    ),
    directory = source, log_directory = logs
  )
  qualification_assert_output(
    serialization_bugfix_result$output,
    c(
      "Serialization BUGFIX gate: PASS",
      "Change-Kind: BUGFIX",
      "Before-SHA256:",
      "After-SHA256:"
    ),
    "serialization-bugfix"
  )
  serialization_bugfix_digest = qualification_hash_raw(charToRaw(paste(
    c(
      source_identity_digest, serialization_bugfix_result$command,
      serialization_bugfix_result$log_digest
    ),
    collapse = intToUtf8(10L)
  )))
  stages = qualification_append_stage(
    stages, "serialization-bugfix", serialization_bugfix_digest,
    serialization_bugfix_result, source,
    "approved serialization BUGFIX before/after digest pair verified",
    root_digest
  )

  phase02_migration_result = qualification_run_command(
    "phase02-migration", qualification_r("Rscript"),
    qualification_phase02_migration_arguments(source),
    directory = source, log_directory = logs
  )
  qualification_assert_output(
    phase02_migration_result$output,
    c("Phase 02 migration source gate: PASS",
      "Identity-normalized-source-fingerprint:",
      "Accepted-canonical-hash:"),
    "phase02-migration"
  )

  phase02_migration_digest = qualification_hash_raw(charToRaw(paste(
    c(
      source_identity_digest, phase02_migration_result$command,
      phase02_migration_result$log_digest
    ),
    collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "phase02-migration", phase02_migration_digest,
    phase02_migration_result, source,
    "identity-normalized Phase 2 migration source gate passed", root_digest
  )

  release_result = qualification_run_command(
    "release-blockers", qualification_r("Rscript"),
    c("--vanilla", file.path(source, "tools", "check_release_gates.R"),
      paste0("--root=", source), "--offline", "--assert-blocked"),
    directory = source, log_directory = logs
  )
  qualification_assert_output(
    release_result$output,
    c(
      "repository_state=blocked", "release_ready=false",
      "reason_codes=DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED"
    ),
    "release-blockers"
  )
  release_digest = qualification_hash_raw(charToRaw(paste(
    c(source_identity_digest, release_result$log_digest), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "release-blockers", release_digest, release_result, source,
    "exact two reviewed release blockers remain active", root_digest
  )

  status_after = system2(
    git, c("-C", shQuote(root), "status", "--porcelain=v1",
           "--untracked-files=all"), stdout = TRUE, stderr = TRUE
  )
  head_after = system2(
    git, c("-C", shQuote(root), "rev-parse", "HEAD"),
    stdout = TRUE, stderr = TRUE
  )
  if (!identical(status_after, status_before) ||
      !identical(head_after, head)) {
    qualification_abort("QUALIFICATION_REPOSITORY_MUTATED")
  }
  readonly_result = qualification_internal_result(
    "repository-readonly",
    c(paste0("HEAD=", head_after), status_after,
      "Repository status remained byte-identical"),
    logs
  )
  readonly_digest = qualification_hash_raw(charToRaw(paste(
    c(head_after, status_after), collapse = "\n"
  )))
  stages = qualification_append_stage(
    stages, "repository-readonly", readonly_digest, readonly_result, root,
    "HEAD and complete porcelain status unchanged during qualification",
    root_digest
  )

  qualification_validate_stage_chain(stages)
  if (any(stages$status != "0")) {
    qualification_abort("QUALIFICATION_STAGE_STATUS_FAILED")
  }
  manifest = qualification_manifest_frame(
    stages, head, export_digest, extracted_digest, archive_digest,
    installation_digest, temporary_root, "removed-after-emission"
  )
  manifest_path = file.path(temporary_root, "qualification-manifest.dcf")
  write.dcf(
    manifest, manifest_path, keep.white = names(manifest), useBytes = TRUE
  )
  manifest_digest = qualification_hash_file(manifest_path)
  manifest_text = readLines(manifest_path, warn = FALSE, encoding = "UTF-8")
  success = TRUE
  cat("QUALIFICATION_MANIFEST_BEGIN\n")
  cat(paste0(manifest_text, collapse = "\n"), "\n")
  cat("QUALIFICATION_MANIFEST_END\n")
  cat(sprintf("Qualification-Manifest-SHA256: %s\n", manifest_digest))
  cat(sprintf("Qualification-HEAD: %s\n", head))
  cat(sprintf("Qualification-Export-SHA256: %s\n", export_digest))
  cat(sprintf("Qualification-Extracted-Tree-SHA256: %s\n", extracted_digest))
  cat(sprintf("Qualification-Archive-SHA256: %s\n", archive_digest))
  cat(sprintf("Qualification-Installation-SHA256: %s\n", installation_digest))
  cat("Qualification-Cleanup: removed-after-emission\n")
  invisible(list(
    manifest = manifest, manifest_digest = manifest_digest,
    temporary_root = temporary_root
  ))
}

qualification_expect_failure = function(expression, pattern) {
  error = tryCatch({
    force(expression)
    NULL
  }, error = identity)
  if (is.null(error) || !grepl(pattern, conditionMessage(error), fixed = TRUE)) {
    qualification_abort("QUALIFICATION_SELF_TEST_DID_NOT_FAIL", pattern)
  }
  invisible(TRUE)
}

qualification_self_test = function() {
  stages = qualification_example_stages()
  stopifnot(length(qualification_required_stages()) == 18L)
  broken = stages
  broken$parent_digest[[4L]] = paste(rep("0", 64L), collapse = "")
  broken$input_digest[[4L]] = broken$parent_digest[[4L]]
  qualification_expect_failure(
    qualification_validate_stage_chain(broken),
    "QUALIFICATION_STAGE_PARENT_MISMATCH"
  )
  cat("Self-test stage-link mismatch: PASS\n")

  qualification_expect_failure(
    qualification_validate_clean_status(" M R/GEModel.R"),
    "QUALIFICATION_RELEVANT_STATE_DIRTY"
  )
  cat("Self-test dirty relevant state: PASS\n")

  command_root = tempfile("qualification-self-command-")
  dir.create(command_root)
  on.exit(unlink(command_root, recursive = TRUE, force = TRUE), add = TRUE)
  qualification_expect_failure(
    qualification_run_command(
      "command-failure", "/bin/sh", c("-c", shQuote("exit 7")),
      log_directory = command_root
    ),
    "QUALIFICATION_COMMAND_FAILED"
  )
  cat("Self-test command failure: PASS\n")

  qualification_expect_failure(
    qualification_validate_notes("unreviewed NOTE", character()),
    "QUALIFICATION_CHECK_NOTE_DRIFT"
  )
  cat("Self-test NOTE drift: PASS\n")

  library_root = tempfile("qualification-self-library-")
  isolated = file.path(library_root, "library")
  wrong = file.path(library_root, "ambient", "GEModelR")
  dir.create(file.path(isolated, "GEModelR"), recursive = TRUE)
  dir.create(wrong, recursive = TRUE)
  on.exit(unlink(library_root, recursive = TRUE, force = TRUE), add = TRUE)
  qualification_expect_failure(
    qualification_validate_package_path(wrong, isolated),
    "QUALIFICATION_AMBIENT_LIBRARY"
  )
  cat("Self-test wrong library: PASS\n")

  digest = qualification_hash_raw(charToRaw("expected"))
  qualification_expect_failure(
    qualification_require_digest(
      digest, paste(rep("f", 64L), collapse = ""), "self-test"
    ),
    "QUALIFICATION_DIGEST_MISMATCH"
  )
  cat("Self-test digest mismatch: PASS\n")
  cat("Phase 03 qualification self-test: PASS\n")
  invisible(TRUE)
}

qualification_usage = function() {
  paste(
    "Usage:",
    "  rtk Rscript --vanilla tools/qualify_phase03_migration.R --self-test",
    "  rtk Rscript --vanilla tools/qualify_phase03_migration.R --execute",
    sep = "\n"
  )
}

qualification_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  if (identical(arguments, "--self-test")) {
    qualification_self_test()
    return(invisible(0L))
  }
  if (identical(arguments, "--execute")) {
    result = tryCatch(
      qualification_execute(),
      error = function(error) {
        message(conditionMessage(error))
        roots = list.files(
          qualification_temporary_parent(),
          pattern = "^GEModelR-phase03-qualification-",
          full.names = TRUE
        )
        roots = qualification_latest_root(roots)
        if (length(roots)) {
          message("Qualification root retained: ", tail(roots, 1L))
        }
        return(1L)
      }
    )
    if (identical(result, 1L)) return(1L)
    return(invisible(0L))
  }
  if (identical(arguments, "--help")) {
    cat(qualification_usage(), "\n")
    return(invisible(0L))
  }
  qualification_abort("QUALIFICATION_ARGUMENT_INVALID")
}

if (sys.nframe() == 0L) {
  status = qualification_main()
  if (is.numeric(status) && identical(as.integer(status), 1L)) {
    quit(save = "no", status = 1L, runLast = FALSE)
  }
}
