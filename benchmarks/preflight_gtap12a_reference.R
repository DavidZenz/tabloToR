preflight_script_file = local({
  script_name = "preflight_gtap12a_reference.R"
  source_files = vapply(sys.frames(), function(frame) {
    for (name in c("ofile", "file")) {
      value = frame[[name]]
      if (is.character(value) && length(value) == 1L && !is.na(value) &&
          identical(basename(value), script_name)) return(value)
    }
    ""
  }, character(1))
  source_files = source_files[nzchar(source_files) & file.exists(source_files)]
  file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(source_files)) {
    normalizePath(tail(source_files, 1L), mustWork = TRUE)
  } else if (length(file_arg)) {
    candidate = sub("^--file=", "", file_arg[[1L]])
    if (identical(basename(candidate), script_name) && file.exists(candidate)) {
      normalizePath(candidate, mustWork = TRUE)
    } else NULL
  } else NULL
})

if (is.null(preflight_script_file)) {
  candidates = c(
    file.path("benchmarks", "preflight_gtap12a_reference.R"),
    file.path("..", "..", "benchmarks", "preflight_gtap12a_reference.R")
  )
  candidates = candidates[file.exists(candidates)]
  if (!length(candidates)) {
    stop("Could not locate the benchmark preflight script", call. = FALSE)
  }
  preflight_script_file = normalizePath(candidates[[1L]], mustWork = TRUE)
}
sys.source(file.path(dirname(preflight_script_file), "benchmark_config.R"),
           envir = environment())

preflight_reference_backend = "StructuredSchurFGMRES"
preflight_candidate_backend = "StructuredSchurFGMRESCpp"
preflight_reference_schema = 3L
preflight_solution_schema = 2L

preflight_reason = function(reasons, code) {
  unique(c(reasons, code))
}

preflight_text = function(value) {
  if (length(value) != 1L || is.na(value)) return(NA_character_)
  value = gsub("[\r\n][[:blank:]]*", " ", as.character(value))
  value = gsub("[[:blank:]]+", " ", value)
  if (!nzchar(trimws(value))) NA_character_ else value
}

preflight_same = function(left, right) {
  length(left) == 1L && length(right) == 1L && !is.na(left) &&
    !is.na(right) && identical(as.character(left), as.character(right))
}

preflight_inside = function(path, repo_root) {
  if (is.null(path) || is.null(repo_root) || !nzchar(path) ||
      !nzchar(repo_root)) return(FALSE)
  path = tolower(gsub("\\\\", "/", path))
  repo_root = tolower(gsub("\\\\", "/", repo_root))
  identical(path, repo_root) || startsWith(path, paste0(repo_root, "/"))
}

preflight_normalize = function(path, kind, repo_root, reasons, label) {
  value = preflight_text(path)
  if (is.na(value)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, paste0("missing_", label)
    )))
  }
  normalized = tryCatch(normalizePath(value, winslash = "/", mustWork = TRUE),
                        error = function(error) NULL)
  if (is.null(normalized)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, paste0("unavailable_", label)
    )))
  }
  if (preflight_inside(normalized, repo_root)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, paste0(label, "_inside_repository")
    )))
  }
  info = suppressWarnings(file.info(normalized))
  if (nrow(info) != 1L || is.na(info$isdir[[1L]]) ||
      (identical(kind, "directory") && !info$isdir[[1L]]) ||
      (identical(kind, "file") && info$isdir[[1L]]) ||
      file.access(normalized, if (identical(kind, "directory")) 5L else 4L) != 0L) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, paste0("unreadable_", label)
    )))
  }
  list(path = normalized, reasons = reasons)
}

preflight_output_path = function(path, repo_root, reasons) {
  value = preflight_text(path)
  if (is.na(value)) return(list(path = NULL, reasons = reasons))
  value = path.expand(value)
  absolute = if (.Platform$OS.type == "windows") {
    grepl("^([[:alpha:]]:[/\\\\]|[/\\\\]{2})", value)
  } else startsWith(value, "/")
  if (!absolute) value = file.path(getwd(), value)
  parent = dirname(value)
  normalized_parent = normalizePath(parent, winslash = "/", mustWork = FALSE)
  if (is.null(normalized_parent)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, "unavailable_preflight_report_path"
    )))
  }
  normalized = file.path(normalized_parent, basename(value))
  if (file.exists(normalized)) {
    resolved = tryCatch(normalizePath(normalized, winslash = "/", mustWork = TRUE),
                       error = function(error) NULL)
    if (is.null(resolved)) {
      return(list(path = NULL, reasons = preflight_reason(
        reasons, "invalid_preflight_report_path"
      )))
    }
    normalized = resolved
  }
  if (preflight_inside(normalized, repo_root)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, "preflight_report_inside_repository"
    )))
  }
  if (dir.exists(normalized)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, "invalid_preflight_report_path"
    )))
  }
  if (!dir.exists(normalized_parent)) {
    suppressWarnings(dir.create(normalized_parent, recursive = TRUE,
                                showWarnings = FALSE))
  }
  normalized_parent = tryCatch(
    normalizePath(normalized_parent, winslash = "/", mustWork = TRUE),
    error = function(error) NULL
  )
  if (is.null(normalized_parent)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, "unavailable_preflight_report_path"
    )))
  }
  normalized = file.path(normalized_parent, basename(value))
  if (preflight_inside(normalized, repo_root)) {
    return(list(path = NULL, reasons = preflight_reason(
      reasons, "preflight_report_inside_repository"
    )))
  }
  list(path = normalized, reasons = reasons)
}

preflight_find_input = function(data_dir, candidates) {
  paths = file.path(data_dir, candidates)
  hit = paths[file.exists(paths) & !dir.exists(paths)]
  if (!length(hit) || file.access(hit[[1L]], 4L) != 0L) return(NULL)
  normalizePath(hit[[1L]], winslash = "/", mustWork = TRUE)
}

preflight_parse_bool = function(value) {
  text = tolower(preflight_text(value))
  if (is.na(text)) return(NA)
  if (text %in% c("true", "1", "yes")) return(TRUE)
  if (text %in% c("false", "0", "no")) return(FALSE)
  NA
}

preflight_parse_integer = function(value, minimum = 1L) {
  text = preflight_text(value)
  if (is.na(text)) return(NA_integer_)
  number = suppressWarnings(as.numeric(text))
  if (!is.finite(number) || number != floor(number) || number < minimum ||
      number > .Machine$integer.max) return(NA_integer_)
  as.integer(number)
}

preflight_parse_steps = function(value) {
  text = preflight_text(value)
  if (is.na(text)) return(integer())
  pieces = strsplit(text, ",", fixed = TRUE)[[1L]]
  result = suppressWarnings(as.integer(pieces))
  if (!length(result) || anyNA(result) || any(result < 1L)) integer() else result
}

preflight_record_read = function(path) {
  record = tryCatch(read.dcf(path, all = FALSE), error = function(error) NULL)
  if (is.null(record) || nrow(record) != 1L) return(NULL)
  values = as.list(as.data.frame(record, stringsAsFactors = FALSE)[1L, , drop = FALSE])
  lapply(values, preflight_text)
}

preflight_required_record_fields = function() {
  c(
    "schema_version", "package_name", "package_version", "source_commit",
    "source_archive_sha256", "installed_package_signature",
    "compiler_identity", "compiler_flags", "r_version", "matrix_version",
    "rcpp_version", "blas", "platform", "cpu", "ram_bytes",
    "model_signature", "pair_signature", "run_signature", "backend",
    "threads", "iter", "steps", "postsim", "panel_size",
    "region_batch_size", "memory_budget"
  )
}

preflight_validate_record = function(record, expected_backend, reasons, label) {
  if (is.null(record)) {
    return(preflight_reason(reasons, paste0("invalid_", label)))
  }
  missing = setdiff(preflight_required_record_fields(), names(record))
  if (length(missing)) {
    reasons = preflight_reason(reasons, paste0(label, "_metadata_missing"))
    return(reasons)
  }
  scalar_fields = preflight_required_record_fields()
  if (any(vapply(record[scalar_fields], function(value) {
    is.na(preflight_text(value))
  }, logical(1)))) {
    reasons = preflight_reason(reasons, paste0(label, "_metadata_missing"))
  }
  if (!preflight_same(record$schema_version, "1") ||
      !preflight_same(record$package_name, "GEModelR") ||
      !preflight_same(record$backend, expected_backend)) {
    reasons = preflight_reason(reasons, paste0(label, "_metadata_mismatch"))
  }
  if (!grepl("^[0-9][[:alnum:].+-]*$",
             preflight_text(record$package_version))) {
    reasons = preflight_reason(reasons, paste0(label, "_package_version_invalid"))
  }
  if (!grepl("^[[:xdigit:]]{40}([[:xdigit:]]{24})?$",
             preflight_text(record$source_commit)) ||
      !grepl("^[[:xdigit:]]{64}$", preflight_text(record$source_archive_sha256)) ||
      !grepl("^[[:xdigit:]]{32}$",
             preflight_text(record$installed_package_signature)) ||
      !grepl("^[[:xdigit:]]{32}$", preflight_text(record$model_signature)) ||
      !grepl("^[[:xdigit:]]{32}$", preflight_text(record$pair_signature)) ||
      !grepl("^[[:xdigit:]]{32}$", preflight_text(record$run_signature))) {
    reasons = preflight_reason(reasons, paste0(label, "_fingerprint_invalid"))
  }
  integer_fields = c("threads", "iter", "panel_size", "region_batch_size")
  if (any(vapply(record[integer_fields], function(value) {
    is.na(preflight_parse_integer(value))
  }, logical(1))) || length(preflight_parse_steps(record$steps)) == 0L ||
      is.na(preflight_parse_bool(record$postsim))) {
    reasons = preflight_reason(reasons, paste0(label, "_run_settings_invalid"))
  }
  budget = tolower(preflight_text(record$memory_budget))
  if (!is.na(budget) && budget != "none") {
    value = suppressWarnings(as.numeric(budget))
    if (!is.finite(value) || value <= 0) {
      reasons = preflight_reason(reasons, paste0(label, "_run_settings_invalid"))
    }
  }
  reasons
}

preflight_record_run_config = function(record) {
  budget_text = tolower(preflight_text(record$memory_budget))
  budget = if (is.na(budget_text) || budget_text == "none") NULL else
    suppressWarnings(as.numeric(budget_text))
  list(
    backend = preflight_text(record$backend),
    threads = preflight_parse_integer(record$threads),
    iter = preflight_parse_integer(record$iter),
    steps = preflight_parse_steps(record$steps),
    postsim = preflight_parse_bool(record$postsim),
    panel_size = preflight_parse_integer(record$panel_size),
    region_batch_size = preflight_parse_integer(record$region_batch_size),
    memory_budget = budget
  )
}

preflight_model_config = function(data_dir, tablo_path, closure_file,
                                  shocks_file = NULL, iter, steps, postsim) {
  sets_path = preflight_find_input(c(data_dir), c("sets.har", "gsdgset.har"))
  data_path = preflight_find_input(c(data_dir), c("basedata.har", "gsdgdat.har"))
  parameters_path = preflight_find_input(
    c(data_dir), c("default.prm", "gsdgpar.har")
  )
  if (any(vapply(list(sets_path, data_path, parameters_path), is.null, logical(1)))) {
    return(NULL)
  }
  closure = tryCatch(readRDS(closure_file), error = function(error) NULL)
  if (is.null(closure) || is.environment(closure) || is.function(closure)) {
    return(NULL)
  }
  shocks = NULL
  if (!is.null(shocks_file)) {
    shocks = tryCatch(readRDS(shocks_file), error = function(error) NULL)
    if (is.null(shocks)) return(NULL)
  }
  package_root = system.file(package = "GEModelR")
  package_available = nzchar(package_root) && dir.exists(package_root) &&
    requireNamespace("GEModelR", quietly = TRUE) &&
    requireNamespace("Matrix", quietly = TRUE) &&
    requireNamespace("Rcpp", quietly = TRUE)
  if (!package_available) return(NULL)
  package_signature = tryCatch(benchmark_hash_tree(package_root),
                               error = function(error) NA_character_)
  if (is.na(package_signature) || !nzchar(package_signature)) return(NULL)
  list(
    tablo = benchmark_hash_file(tablo_path),
    sets = benchmark_hash_file(sets_path),
    data = benchmark_hash_file(data_path),
    parameters = benchmark_hash_file(parameters_path),
    closure_file = benchmark_hash_file(closure_file),
    closure = benchmark_hash_object(sort(as.character(closure))),
    shocks_file = benchmark_hash_file(shocks_file),
    shocks = benchmark_hash_object(shocks),
    package_name = "GEModelR",
    package_version = as.character(utils::packageVersion("GEModelR")),
    installed_package_signature = package_signature,
    option_prefix = "GEModelR.",
    native_routine_prefix = ".GEModelR_",
    r_version = R.version.string,
    matrix_version = as.character(utils::packageVersion("Matrix")),
    rcpp_version = as.character(utils::packageVersion("Rcpp")),
    iter = as.integer(iter),
    steps = as.integer(steps),
    postsim = isTRUE(postsim),
    platform = R.version$platform,
    cpu = benchmark_cpu(),
    ram = benchmark_physical_ram(),
    blas = benchmark_blas()
  )
}

preflight_collect_reference_csv = function(reference_dir, reasons) {
  paths = list.files(reference_dir, pattern = "[.]csv$", full.names = TRUE,
                     recursive = FALSE, all.files = FALSE)
  records = list()
  count = 0L
  required_columns = c(
    "schema_version", "run_id", "repetition", "warmup", "run_signature",
    "pair_signature", "model_signature", "git_commit", "package_name",
    "package_version", "installed_package_signature", "option_prefix",
    "native_routine_prefix", "r_version", "matrix_version", "platform",
    "backend", "threads", "iter", "steps", "postsim", "status",
    "metric", "value"
  )
  for (path in paths) {
    frame = tryCatch(read.csv(path, stringsAsFactors = FALSE,
                              check.names = FALSE),
                     error = function(error) NULL)
    if (is.null(frame) || !"backend" %in% names(frame)) next
    if (!any(as.character(frame$backend) == preflight_reference_backend,
             na.rm = TRUE)) next
    count = count + 1L
    if (length(setdiff(required_columns, names(frame)))) {
      reasons = preflight_reason(reasons, "reference_csv_metadata_missing")
      next
    }
    frame = frame[as.character(frame$backend) == preflight_reference_backend,
                  , drop = FALSE]
    records[[length(records) + 1L]] = frame
  }
  if (!count) reasons = preflight_reason(reasons, "reference_csv_missing")
  if (!length(records)) {
    return(list(records = list(), count = count, reasons = reasons))
  }
  list(records = records, count = count, reasons = reasons)
}

preflight_row_text = function(frame, column) {
  if (!column %in% names(frame)) return(character())
  as.character(frame[[column]])
}

preflight_validate_reference_rows = function(frames, reference_record,
                                             candidate_record, reasons) {
  if (!length(frames)) {
    return(list(records = list(), measured = 0L, warmups = 0L,
                reasons = reasons))
  }
  frame = do.call(rbind, frames)
  row_scalar_fields = c(
    "schema_version", "run_id", "repetition", "warmup", "run_signature",
    "pair_signature", "model_signature", "git_commit", "package_name",
    "package_version", "installed_package_signature", "option_prefix",
    "native_routine_prefix", "r_version", "matrix_version", "platform",
    "backend", "threads", "iter", "steps", "postsim", "status"
  )
  if (any(!row_scalar_fields %in% names(frame))) {
    return(list(records = list(), measured = 0L, warmups = 0L,
                reasons = preflight_reason(reasons,
                                           "reference_csv_metadata_missing")))
  }
  if (anyNA(frame$run_id) || any(!nzchar(as.character(frame$run_id))) ||
      anyNA(frame$metric) || any(!nzchar(as.character(frame$metric)))) {
    reasons = preflight_reason(reasons, "reference_csv_metadata_invalid")
  }
  run_key = paste(as.character(frame$backend), as.character(frame$run_id),
                  sep = "\r")
  groups = split(seq_len(nrow(frame)), run_key)
  records = list()
  for (key in names(groups)) {
    indexes = groups[[key]]
    rows = frame[indexes, , drop = FALSE]
    for (field in row_scalar_fields) {
      values = unique(as.character(rows[[field]]))
      if (length(values) != 1L || anyNA(values) || !nzchar(values[[1L]])) {
        reasons = preflight_reason(reasons, "reference_csv_metadata_inconsistent")
      }
    }
    metric_names = as.character(rows$metric)
    if (anyDuplicated(metric_names)) {
      reasons = preflight_reason(reasons, "reference_csv_metrics_inconsistent")
    }
    required_metrics = c(
      "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
      "solution_finite", "selected_outputs_finite",
      "dense_full_system_operations"
    )
    if (length(setdiff(required_metrics, metric_names))) {
      reasons = preflight_reason(reasons, "reference_metrics_missing")
    }
    metric_values = stats::setNames(as.character(rows$value), metric_names)
    for (metric in intersect(required_metrics[1:3], names(metric_values))) {
      value = suppressWarnings(as.numeric(metric_values[[metric]]))
      if (length(value) != 1L || !is.finite(value) || value < 0) {
        reasons = preflight_reason(reasons, "reference_metrics_invalid")
      }
    }
    for (metric in intersect(required_metrics[4:6], names(metric_values))) {
      value = preflight_parse_bool(metric_values[[metric]])
      if (is.na(value)) {
        reasons = preflight_reason(reasons, "reference_metrics_invalid")
      }
      if (identical(metric, "solution_finite") && !is.na(value) && !value) {
        reasons = preflight_reason(reasons, "reference_solution_nonfinite")
      }
      if (identical(metric, "selected_outputs_finite") && !is.na(value) &&
          !value) {
        reasons = preflight_reason(reasons, "reference_selected_outputs_nonfinite")
      }
      if (identical(metric, "dense_full_system_operations") &&
          !is.na(value) && value) {
        reasons = preflight_reason(reasons, "reference_dense_fallback")
      }
    }
    row = rows[1L, , drop = FALSE]
    record = lapply(row_scalar_fields, function(field) as.character(row[[field]][[1L]]))
    names(record) = row_scalar_fields
    if (!grepl("^[[:alnum:]][[:alnum:]._-]*$", record$run_id) ||
        record$run_id %in% c(".", "..")) {
      reasons = preflight_reason(reasons, "reference_run_id_invalid")
    }
    if (!preflight_same(record$schema_version,
                        as.character(preflight_reference_schema))) {
      reasons = preflight_reason(reasons, "reference_schema_mismatch")
    }
    if (!preflight_same(record$status, "completed")) {
      reasons = preflight_reason(reasons, "reference_run_incomplete")
    }
    record$metrics = metric_values
    records[[key]] = record
  }
  run_ids = vapply(records, function(record) record$run_id, character(1))
  if (anyDuplicated(run_ids)) {
    reasons = preflight_reason(reasons, "reference_run_id_duplicate")
  }
  warmup = vapply(records, function(record) {
    preflight_parse_bool(record$warmup)
  }, logical(1))
  repetitions = vapply(records, function(record) {
    preflight_parse_integer(record$repetition)
  }, integer(1))
  if (anyNA(warmup) || anyNA(repetitions) || any(repetitions < 1L)) {
    reasons = preflight_reason(reasons, "reference_repetition_metadata_invalid")
  }
  measured_count = sum(!warmup, na.rm = TRUE)
  warmup_count = sum(warmup, na.rm = TRUE)
  if (measured_count < 3L) {
    reasons = preflight_reason(reasons, "reference_repetitions_insufficient")
  }
  if (warmup_count < 1L) {
    reasons = preflight_reason(reasons, "reference_warmup_missing")
  }
  if (length(unique(repetitions[!warmup])) != measured_count) {
    reasons = preflight_reason(reasons, "reference_repetition_metadata_invalid")
  }
  if (length(unique(repetitions[warmup])) != warmup_count) {
    reasons = preflight_reason(reasons, "reference_repetition_metadata_invalid")
  }
  get_record = function(field) unique(vapply(records, function(record) {
    as.character(record[[field]])
  }, character(1)))
  for (field in c("model_signature", "pair_signature", "run_signature",
                  "git_commit", "package_name", "package_version",
                  "installed_package_signature", "option_prefix",
                  "native_routine_prefix", "r_version", "matrix_version",
                  "platform", "threads", "iter", "steps")) {
    if (length(get_record(field)) != 1L) {
      reasons = preflight_reason(
        reasons, paste0("reference_metadata_mismatch_", field)
      )
    }
  }
  if (length(records) && length(unique(vapply(records, function(item) {
    as.character(preflight_parse_bool(item$postsim))
  }, character(1)))) != 1L) {
    reasons = preflight_reason(reasons, "reference_metadata_mismatch_postsim")
  }
  record = if (length(records)) records[[1L]] else list()
  candidate_settings = if (is.null(candidate_record)) list() else
    preflight_record_run_config(candidate_record)
  reference_settings = if (is.null(reference_record)) list() else
    preflight_record_run_config(reference_record)
  if (length(records) &&
      (is.null(reference_record) || is.null(candidate_record) ||
       !preflight_same(record$model_signature, reference_record$model_signature) ||
       !preflight_same(record$pair_signature, reference_record$pair_signature) ||
       !preflight_same(record$run_signature, reference_record$run_signature) ||
       !preflight_same(record$git_commit, reference_record$source_commit) ||
       !preflight_same(record$package_name, reference_record$package_name) ||
       !preflight_same(record$package_version, reference_record$package_version) ||
       !preflight_same(record$installed_package_signature,
                       reference_record$installed_package_signature) ||
       !preflight_same(record$option_prefix, "GEModelR.") ||
       !preflight_same(record$native_routine_prefix, ".GEModelR_") ||
       !preflight_same(record$backend, preflight_reference_backend) ||
       !preflight_same(record$r_version, R.version$major) ||
       !preflight_same(record$matrix_version, reference_record$matrix_version) ||
       !preflight_same(record$platform, reference_record$platform) ||
       !preflight_same(record$threads, reference_record$threads) ||
       !preflight_same(record$iter, reference_record$iter) ||
       !preflight_same(record$steps, reference_record$steps) ||
       !identical(preflight_parse_bool(record$postsim),
                  preflight_parse_bool(reference_record$postsim)))) {
    reasons = preflight_reason(reasons, "reference_metadata_mismatch")
  }
  if (length(records) && !is.null(reference_record)) {
    for (field in c("r_version", "matrix_version", "platform")) {
      expected = if (identical(field, "r_version")) R.version$major else
        reference_record[[field]]
      if (!preflight_same(record[[field]], expected)) {
        reasons = preflight_reason(
          reasons, paste0("reference_metadata_mismatch_", field)
        )
      }
    }
  }
  if (length(records) && !is.null(reference_record) &&
      !is.null(candidate_record) &&
      (!preflight_same(candidate_record$model_signature,
                       reference_record$model_signature) ||
       !preflight_same(candidate_record$pair_signature,
                       reference_record$pair_signature) ||
       !identical(candidate_settings$iter, reference_settings$iter) ||
       !identical(candidate_settings$steps, reference_settings$steps) ||
       !identical(candidate_settings$postsim, reference_settings$postsim) ||
       !identical(candidate_settings$panel_size, reference_settings$panel_size) ||
       !identical(candidate_settings$region_batch_size,
                  reference_settings$region_batch_size) ||
       !identical(candidate_settings$memory_budget,
                  reference_settings$memory_budget))) {
    reasons = preflight_reason(reasons, "candidate_run_configuration_mismatch")
  }
  list(records = records, measured = measured_count, warmups = warmup_count,
       reasons = reasons)
}

preflight_validate_solutions = function(reference_dir, records, reasons) {
  measured = records[!vapply(records, function(record) {
    isTRUE(preflight_parse_bool(record$warmup))
  }, logical(1))]
  count = 0L
  for (record in measured) {
    if (!grepl("^[[:alnum:]][[:alnum:]._-]*$", record$run_id) ||
        record$run_id %in% c(".", "..")) {
      reasons = preflight_reason(reasons, "reference_run_id_invalid")
      next
    }
    path = file.path(reference_dir, paste0(record$run_id, ".rds"))
    if (!file.exists(path) || dir.exists(path)) {
      reasons = preflight_reason(reasons, "reference_solution_missing")
      next
    }
    value = tryCatch(readRDS(path), error = function(error) NULL)
    required = c(
      "schema_version", "run_id", "pair_signature", "run_signature",
      "model_signature", "backend", "threads", "repetition", "warmup",
      "solution", "selected_outputs"
    )
    if (!is.list(value) || is.null(names(value)) || anyDuplicated(names(value)) ||
        length(setdiff(required, names(value)))) {
      reasons = preflight_reason(reasons, "reference_solution_invalid")
      next
    }
    solution = value$solution
    if (is.null(solution) || !is.atomic(solution) ||
        typeof(solution) != "double" || is.object(solution) ||
        !length(solution) || any(!is.finite(solution))) {
      reasons = preflight_reason(reasons, "reference_solution_invalid")
      next
    }
    validate_output_tree = function(outputs) {
      valid_names = is.list(outputs) && !is.object(outputs) &&
        length(outputs) > 0L && !is.null(names(outputs)) &&
        length(names(outputs)) == length(outputs) && !anyNA(names(outputs)) &&
        all(nzchar(names(outputs))) && !anyDuplicated(names(outputs))
      if (!valid_names) return(FALSE)
      all(vapply(outputs, function(item) {
        if (is.list(item)) return(validate_output_tree(item))
        !is.null(item) && is.atomic(item) && typeof(item) == "double" &&
          !is.object(item) && length(item) > 0L && all(is.finite(item))
      }, logical(1)))
    }
    outputs_valid = validate_output_tree(value$selected_outputs)
    if (!outputs_valid) {
      reasons = preflight_reason(reasons, "reference_solution_invalid")
      next
    }
    if (!preflight_same(value$schema_version, as.character(preflight_solution_schema)) ||
        !preflight_same(value$run_id, record$run_id) ||
        !preflight_same(value$pair_signature, record$pair_signature) ||
        !preflight_same(value$run_signature, record$run_signature) ||
        !preflight_same(value$model_signature, record$model_signature) ||
        !preflight_same(value$backend, record$backend) ||
        !preflight_same(value$threads, record$threads) ||
        !preflight_same(value$repetition, record$repetition) ||
        !identical(preflight_parse_bool(value$warmup), FALSE)) {
      reasons = preflight_reason(reasons, "reference_solution_metadata_mismatch")
      next
    }
    count = count + 1L
    rm(value)
  }
  list(count = count, reasons = reasons)
}

preflight_compare_records = function(reference, candidate, current, reasons) {
  environment_fields = c(
    "package_name", "package_version", "source_commit", "source_archive_sha256",
    "installed_package_signature", "compiler_identity", "compiler_flags",
    "r_version", "matrix_version", "rcpp_version", "blas", "platform",
    "cpu", "ram_bytes"
  )
  if (!is.null(reference) && !is.null(candidate)) {
    for (field in environment_fields) {
      if (!preflight_same(reference[[field]], candidate[[field]])) {
        reasons = preflight_reason(
          reasons, paste0("build_record_identity_mismatch_", field)
        )
      }
    }
    if (!is.null(current)) {
      current_identity = list(
        package_name = "GEModelR",
        package_version = as.character(utils::packageVersion("GEModelR")),
        installed_package_signature = current$installed_package_signature,
        r_version = R.version.string,
        matrix_version = as.character(utils::packageVersion("Matrix")),
        rcpp_version = as.character(utils::packageVersion("Rcpp")),
        blas = benchmark_blas(), platform = R.version$platform,
        cpu = benchmark_cpu(), ram_bytes = format(
          benchmark_physical_ram(), scientific = FALSE
        )
      )
      for (field in names(current_identity)) {
        if (!preflight_same(candidate[[field]], current_identity[[field]])) {
          reasons = preflight_reason(
            reasons, paste0("candidate_package_environment_mismatch_", field)
          )
        }
      }
    }
  }
  reasons
}

preflight_validate_script_parity = function(repo_root, reasons) {
  names = c("benchmark_config.R", "benchmark_gtap12a_run.R",
            "check_benchmark_gate.R")
  for (name in names) {
    source = file.path(repo_root, "benchmarks", name)
    installed = system.file("benchmarks", name, package = "GEModelR")
    if (!file.exists(source) || !nzchar(installed) || !file.exists(installed)) {
      reasons = preflight_reason(reasons, "benchmark_driver_identity_unavailable")
      next
    }
    source_bytes = tryCatch(readBin(source, "raw", n = file.info(source)$size),
                            error = function(error) raw())
    installed_bytes = tryCatch(
      readBin(installed, "raw", n = file.info(installed)$size),
      error = function(error) raw()
    )
    if (!length(source_bytes) || !identical(source_bytes, installed_bytes)) {
      reasons = preflight_reason(reasons, "benchmark_driver_identity_mismatch")
    }
  }
  reasons
}

preflight_safe_identifier = function(value) {
  value = preflight_text(value)
  if (is.na(value)) return("not_available")
  if (!grepl("^[[:alnum:]][[:alnum:] ._+()-]*$", value)) return("redacted")
  value
}

preflight_gtap12a_reference = function(options, repo_root = getwd()) {
  reasons = character()
  repo_root = tryCatch(normalizePath(repo_root, winslash = "/", mustWork = TRUE),
                       error = function(error) getwd())
  fields = list(
    reference_dir = "directory",
    data_dir = "directory",
    tablo = "file",
    closure_file = "file",
    reference_build_record = "file",
    candidate_build_record = "file"
  )
  paths = list()
  for (name in names(fields)) {
    result = preflight_normalize(options[[name]], fields[[name]], repo_root,
                                 reasons, name)
    paths[[name]] = result$path
    reasons = result$reasons
  }
  shocks_path = NULL
  if (!is.null(options$shocks_file) && nzchar(options$shocks_file)) {
    result = preflight_normalize(options$shocks_file, "file", repo_root,
                                 reasons, "shocks_file")
    shocks_path = result$path
    reasons = result$reasons
  }
  output = preflight_output_path(options$output, repo_root, reasons)
  reasons = output$reasons
  output_path = output$path
  if (isTRUE(options$require_report) && is.null(output_path)) {
    reasons = preflight_reason(reasons, "missing_preflight_report_path")
  }

  csv_inventory = list(records = list(), count = 0L, reasons = reasons)
  if (!is.null(paths$reference_dir)) {
    csv_inventory = preflight_collect_reference_csv(paths$reference_dir, reasons)
    reasons = csv_inventory$reasons
  }
  reference_record = if (!is.null(paths$reference_build_record)) {
    preflight_record_read(paths$reference_build_record)
  } else NULL
  candidate_record = if (!is.null(paths$candidate_build_record)) {
    preflight_record_read(paths$candidate_build_record)
  } else NULL
  if (!is.null(paths$reference_build_record)) {
    reasons = preflight_validate_record(reference_record,
                                        preflight_reference_backend, reasons,
                                        "reference_build_record")
  }
  if (!is.null(paths$candidate_build_record)) {
    reasons = preflight_validate_record(candidate_record,
                                        preflight_candidate_backend, reasons,
                                        "candidate_build_record")
  }

  reference_validation = preflight_validate_reference_rows(
    csv_inventory$records, reference_record, candidate_record, reasons
  )
  reasons = reference_validation$reasons
  solution_validation = if (!is.null(paths$reference_dir)) {
    preflight_validate_solutions(paths$reference_dir,
                                 reference_validation$records, reasons)
  } else {
    list(count = 0L, reasons = reasons)
  }
  reasons = solution_validation$reasons

  current_config = NULL
  if (!is.null(paths$data_dir) && !is.null(paths$tablo) &&
      !is.null(paths$closure_file) && !is.null(reference_record) &&
      !is.null(candidate_record)) {
    candidate_settings = preflight_record_run_config(candidate_record)
    current_config = tryCatch(preflight_model_config(
      data_dir = paths$data_dir,
      tablo_path = paths$tablo,
      closure_file = paths$closure_file,
      shocks_file = shocks_path,
      iter = candidate_settings$iter,
      steps = candidate_settings$steps,
      postsim = candidate_settings$postsim
    ), error = function(error) NULL)
  }
  if (is.null(current_config)) {
    reasons = preflight_reason(reasons, "input_configuration_unavailable")
  } else {
    expected_model_signature = benchmark_signature(current_config)
    if (!preflight_same(reference_record$model_signature,
                        expected_model_signature) ||
        !preflight_same(candidate_record$model_signature,
                        expected_model_signature)) {
      reasons = preflight_reason(reasons, "input_model_signature_mismatch")
    }
    reference_settings = preflight_record_run_config(reference_record)
    candidate_settings = preflight_record_run_config(candidate_record)
    expected_pair_reference = benchmark_signature(c(
      current_config,
      list(
        panel_size = reference_settings$panel_size,
        region_batch_size = reference_settings$region_batch_size,
        memory_budget = reference_settings$memory_budget
      )
    ))
    expected_pair_candidate = benchmark_signature(c(
      current_config,
      list(
        panel_size = candidate_settings$panel_size,
        region_batch_size = candidate_settings$region_batch_size,
        memory_budget = candidate_settings$memory_budget
      )
    ))
    if (!preflight_same(reference_record$pair_signature,
                        expected_pair_reference) ||
        !preflight_same(candidate_record$pair_signature,
                        expected_pair_candidate)) {
      reasons = preflight_reason(reasons, "pair_signature_mismatch")
    }
    expected_reference_run = benchmark_signature(c(
      current_config,
      list(
        panel_size = reference_settings$panel_size,
        region_batch_size = reference_settings$region_batch_size,
        memory_budget = reference_settings$memory_budget,
        backend = preflight_reference_backend,
        threads = reference_settings$threads
      )
    ))
    expected_candidate_run = benchmark_signature(c(
      current_config,
      list(
        panel_size = candidate_settings$panel_size,
        region_batch_size = candidate_settings$region_batch_size,
        memory_budget = candidate_settings$memory_budget,
        backend = preflight_candidate_backend,
        threads = candidate_settings$threads
      )
    ))
    if (!preflight_same(reference_record$run_signature,
                        expected_reference_run) ||
        !preflight_same(candidate_record$run_signature,
                        expected_candidate_run)) {
      reasons = preflight_reason(reasons, "run_signature_mismatch")
    }
    records = reference_validation$records
    if (length(records) && any(!vapply(records, function(record) {
      preflight_same(record$model_signature, expected_model_signature) &&
        preflight_same(record$pair_signature, expected_pair_reference) &&
        preflight_same(record$run_signature, expected_reference_run)
    }, logical(1)))) {
      reasons = preflight_reason(reasons, "reference_signature_mismatch")
    }
  }
  reasons = preflight_compare_records(reference_record, candidate_record,
                                     current_config, reasons)
  reasons = preflight_validate_script_parity(repo_root, reasons)
  if (!is.null(reference_record) && length(reference_validation$records)) {
    # The CSV run settings must match the retained reference build record.
    record_settings = preflight_record_run_config(reference_record)
    if (any(!vapply(reference_validation$records, function(record) {
      preflight_same(record$threads, record_settings$threads) &&
        preflight_same(record$iter, record_settings$iter) &&
        identical(preflight_parse_steps(record$steps), record_settings$steps) &&
        identical(preflight_parse_bool(record$postsim), record_settings$postsim)
    }, logical(1)))) {
      reasons = preflight_reason(reasons, "reference_run_settings_mismatch")
    }
  }
  reasons = sort(unique(reasons), method = "radix")
  status = if (!length(reasons)) "eligible" else "blocked"
  result = list(
    reference_preflight_status = status,
    reference_csv_count = as.integer(csv_inventory$count),
    reference_solution_count = as.integer(solution_validation$count),
    measured_repetitions = as.integer(reference_validation$measured),
    warmup_count = as.integer(reference_validation$warmups),
    reason_codes = reasons,
    reference_package_name = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$package_name),
    reference_package_version = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$package_version),
    reference_source_commit = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$source_commit),
    reference_source_archive_sha256 = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$source_archive_sha256),
    reference_installed_package_signature = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$installed_package_signature),
    reference_compiler_identity = if (is.null(reference_record)) "not_available" else
      preflight_safe_identifier(reference_record$compiler_identity),
    candidate_package_version = if (is.null(candidate_record)) "not_available" else
      preflight_text(candidate_record$package_version),
    candidate_source_commit = if (is.null(candidate_record)) "not_available" else
      preflight_text(candidate_record$source_commit),
    candidate_source_archive_sha256 = if (is.null(candidate_record)) "not_available" else
      preflight_text(candidate_record$source_archive_sha256),
    candidate_installed_package_signature = if (is.null(candidate_record)) "not_available" else
      preflight_text(candidate_record$installed_package_signature),
    candidate_compiler_identity = if (is.null(candidate_record)) "not_available" else
      preflight_safe_identifier(candidate_record$compiler_identity),
    reference_model_signature = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$model_signature),
    reference_pair_signature = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$pair_signature),
    reference_run_signature = if (is.null(reference_record)) "not_available" else
      preflight_text(reference_record$run_signature),
    candidate_run_signature = if (is.null(candidate_record)) "not_available" else
      preflight_text(candidate_record$run_signature)
  )
  if (!is.null(output_path)) {
    tryCatch({
      dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
      report = as.data.frame(as.list(c(
        result[setdiff(names(result), "reason_codes")],
        list(reason_codes = if (length(reasons)) paste(reasons, collapse = ",") else "none")
      )), stringsAsFactors = FALSE)
      report[] = lapply(report, function(column) {
        column[is.na(column)] = "not_available"
        column
      })
      suppressWarnings(write.dcf(report, file = output_path))
      if (!file.exists(output_path)) stop("write failed")
    }, error = function(error) {
      result$reference_preflight_status <<- "blocked"
      result$reason_codes <<- sort(unique(c(
        result$reason_codes, "preflight_report_write_failed"
      )), method = "radix")
    })
  }
  result$reference_preflight_status = if (length(result$reason_codes)) "blocked" else
    result$reference_preflight_status
  result
}

preflight_cli_options = function(args) {
  values = list()
  for (argument in args) {
    match = regexec("^--([[:alnum:]-]+)=(.*)$", argument)
    pieces = regmatches(argument, match)[[1L]]
    if (!length(pieces)) next
    name = gsub("-", "_", pieces[[2L]], fixed = TRUE)
    if (name %in% names(values)) values[[name]] = "" else
      values[[name]] = pieces[[3L]]
  }
  environment_value = function(name, default = "") {
    value = Sys.getenv(name, unset = default)
    if (!nzchar(value)) NULL else value
  }
  list(
    reference_dir = values$reference_dir %||%
      environment_value("GEMODELR_GTAP12A_REFERENCE_DIR") %||%
      environment_value("GEMODELR_GTAP12A_OUTPUT_DIR"),
    data_dir = values$data_dir %||% environment_value("GEMODELR_GTAP12A_DATA_DIR"),
    tablo = values$tablo %||% environment_value("GEMODELR_GTAP12A_TABLO"),
    closure_file = values$closure_file %||%
      environment_value("GEMODELR_GTAP12A_CLOSURE_FILE"),
    reference_build_record = values$reference_build_record %||%
      environment_value("GEMODELR_GTAP12A_REFERENCE_BUILD_RECORD"),
    candidate_build_record = values$candidate_build_record %||%
      environment_value("GEMODELR_GTAP12A_CANDIDATE_BUILD_RECORD"),
    shocks_file = values$shocks_file %||%
      environment_value("GEMODELR_GTAP12A_SHOCKS_FILE"),
    output = values$output %||% environment_value("GEMODELR_GTAP12A_PREFLIGHT_REPORT"),
    require_report = TRUE
  )
}

`%||%` = function(value, fallback) {
  if (is.null(value) || !length(value) || is.na(value) || !nzchar(value)) {
    fallback
  } else {
    value
  }
}

preflight_print_summary = function(result) {
  summary = c(
    reference_preflight_status = result$reference_preflight_status,
    reference_csv_count = result$reference_csv_count,
    reference_solution_count = result$reference_solution_count,
    measured_repetitions = result$measured_repetitions,
    warmup_count = result$warmup_count,
    reason_codes = if (length(result$reason_codes)) {
      paste(result$reason_codes, collapse = ",")
    } else "none"
  )
  for (name in names(summary)) cat(name, "=", as.character(summary[[name]]), "\n", sep = "")
  invisible(result)
}

if (identical(preflight_script_file,
              tryCatch(normalizePath(sub("^--file=", "", grep(
                "^--file=", commandArgs(FALSE), value = TRUE
              )[[1L]]), winslash = "/", mustWork = TRUE),
              error = function(error) ""))) {
  result = preflight_gtap12a_reference(preflight_cli_options(
    commandArgs(trailingOnly = TRUE)
  ))
  preflight_print_summary(result)
  quit(save = "no", status = if (identical(
    result$reference_preflight_status, "eligible"
  )) 0L else 1L)
}
