#!/usr/bin/env Rscript

benchmark_gate_fail = function(message) {
  stop(message, call. = FALSE)
}

benchmark_gate_script_dir = function() {
  file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg)) {
    return(dirname(normalizePath(
      sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE
    )))
  }
  ofile = tryCatch(sys.frame(1L)$ofile, error = function(error) NULL)
  if (length(ofile) == 1L && !is.null(ofile) && nzchar(ofile) &&
      file.exists(ofile)) {
    return(dirname(normalizePath(ofile, mustWork = TRUE)))
  }
  for (candidate in c("benchmarks", "inst/benchmarks", ".")) {
    if (file.exists(file.path(candidate, "benchmark_config.R"))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  normalizePath(".", mustWork = TRUE)
}

benchmark_gate_scalar_text = function(value, label, allow_empty = FALSE) {
  if (length(value) != 1L || is.na(value)) {
    benchmark_gate_fail(sprintf("%s must be one non-missing scalar", label))
  }
  value = as.character(value)
  if (!allow_empty && !nzchar(value)) {
    benchmark_gate_fail(sprintf("%s must be non-empty", label))
  }
  value
}

benchmark_gate_scalar_integer = function(value, label, minimum = 1L,
                                         expected = NULL) {
  text = benchmark_gate_scalar_text(value, label)
  number = suppressWarnings(as.numeric(text))
  if (!is.finite(number) || number != floor(number) ||
      number < minimum || number > .Machine$integer.max) {
    benchmark_gate_fail(sprintf("%s must be an integer of at least %s",
                                label, minimum))
  }
  result = as.integer(number)
  if (!is.null(expected) && !identical(result, as.integer(expected))) {
    benchmark_gate_fail(sprintf("%s must equal %s", label, expected))
  }
  result
}

benchmark_gate_scalar_flag = function(value, label) {
  text = tolower(benchmark_gate_scalar_text(value, label))
  if (!text %in% c("true", "false")) {
    benchmark_gate_fail(sprintf("%s must be TRUE or FALSE", label))
  }
  identical(text, "true")
}

benchmark_gate_required_metrics = function() {
  c(
    "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
    "solution_finite", "selected_outputs_finite",
    "dense_full_system_operations"
  )
}

benchmark_gate_metric_numeric = function(record, metric, minimum = NULL) {
  raw = record$metrics[[metric]]
  text = benchmark_gate_scalar_text(
    raw, sprintf("metric %s for %s", metric, record$run_id)
  )
  value = suppressWarnings(as.numeric(text))
  if (!is.finite(value) || (!is.null(minimum) && value < minimum)) {
    benchmark_gate_fail(sprintf("Metric %s for %s is not valid",
                               metric, record$run_id))
  }
  value
}

benchmark_gate_metric_flag = function(record, metric) {
  benchmark_gate_scalar_flag(
    record$metrics[[metric]], sprintf("metric %s for %s", metric, record$run_id)
  )
}

benchmark_gate_require_repeated = function(values, label) {
  values = as.character(values)
  if (!length(values) || anyNA(values) || length(unique(values)) != 1L) {
    benchmark_gate_fail(sprintf("Repeated %s metadata disagrees", label))
  }
  values[[1L]]
}

benchmark_gate_read_csv_records = function(files, reference_name,
                                           candidate_name) {
  if (!length(files)) benchmark_gate_fail("No benchmark CSV files found")
  frames = lapply(files, function(path) {
    tryCatch(
      read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
      error = function(error) benchmark_gate_fail(
        sprintf("Could not read benchmark CSV %s: %s", path,
                conditionMessage(error))
      )
    )
  })
  if (any(!vapply(frames, nrow, integer(1)))) {
    benchmark_gate_fail("Benchmark CSV files must contain rows")
  }
  frame = do.call(rbind, frames)
  required_columns = c(
    "schema_version", "run_id", "repetition", "warmup",
    "run_signature", "pair_signature", "model_signature", "backend",
    "threads", "status", "metric", "value"
  )
  missing_columns = setdiff(required_columns, names(frame))
  if (length(missing_columns)) {
    benchmark_gate_fail(sprintf(
      "Benchmark CSV is missing required columns: %s",
      paste(missing_columns, collapse = ", ")
    ))
  }
  row_schema = vapply(
    frame$schema_version,
    function(value) benchmark_gate_scalar_integer(
      value, "CSV schema_version", expected = 3L
    ), integer(1)
  )
  row_run_id = vapply(
    frame$run_id,
    function(value) benchmark_gate_scalar_text(value, "CSV run_id"),
    character(1)
  )
  row_repetition = vapply(
    frame$repetition,
    function(value) benchmark_gate_scalar_integer(value, "CSV repetition"),
    integer(1)
  )
  row_warmup = vapply(
    frame$warmup,
    function(value) benchmark_gate_scalar_flag(value, "CSV warmup"),
    logical(1)
  )
  row_run_signature = vapply(
    frame$run_signature,
    function(value) benchmark_gate_scalar_text(value, "CSV run_signature"),
    character(1)
  )
  row_pair_signature = vapply(
    frame$pair_signature,
    function(value) benchmark_gate_scalar_text(value, "CSV pair_signature"),
    character(1)
  )
  row_model_signature = vapply(
    frame$model_signature,
    function(value) benchmark_gate_scalar_text(value, "CSV model_signature"),
    character(1)
  )
  row_backend = vapply(
    frame$backend,
    function(value) benchmark_gate_scalar_text(value, "CSV backend"),
    character(1)
  )
  if (any(!row_backend %in% c(reference_name, candidate_name))) {
    benchmark_gate_fail("Benchmark CSV contains an unknown backend artifact")
  }
  row_threads = vapply(
    frame$threads,
    function(value) benchmark_gate_scalar_integer(value, "CSV threads"),
    integer(1)
  )
  row_status = vapply(
    frame$status,
    function(value) benchmark_gate_scalar_text(value, "CSV status"),
    character(1)
  )
  if (any(row_status != "completed")) {
    benchmark_gate_fail("At least one benchmark child failed")
  }
  row_metric = vapply(
    frame$metric,
    function(value) benchmark_gate_scalar_text(value, "CSV metric"),
    character(1)
  )
  row_value = vapply(
    seq_len(nrow(frame)),
    function(index) {
      if (is.na(frame$value[[index]])) return(NA_character_)
      as.character(frame$value[[index]])
    },
    character(1)
  )
  if (anyNA(row_value[row_metric %in% benchmark_gate_required_metrics()])) {
    benchmark_gate_fail("Required benchmark metric values must be present")
  }

  keys = paste(row_backend, row_run_id, sep = "\r")
  groups = split(seq_len(nrow(frame)), keys)
  records = lapply(names(groups), function(key) {
    indexes = groups[[key]]
    metrics = row_metric[indexes]
    if (anyDuplicated(metrics)) {
      benchmark_gate_fail(sprintf(
        "Benchmark run %s contains duplicate metric rows", key
      ))
    }
    required_metrics = benchmark_gate_required_metrics()
    missing_metrics = setdiff(required_metrics, metrics)
    if (length(missing_metrics)) {
      benchmark_gate_fail(sprintf(
        "Benchmark run %s is missing required metrics: %s", key,
        paste(missing_metrics, collapse = ", ")
      ))
    }
    indexes = indexes[order(seq_along(indexes), method = "radix")]
    record = list(
      schema_version = benchmark_gate_require_repeated(
        row_schema[indexes], "schema_version"
      ),
      run_id = benchmark_gate_require_repeated(row_run_id[indexes], "run_id"),
      repetition = benchmark_gate_require_repeated(
        row_repetition[indexes], "repetition"
      ),
      warmup = benchmark_gate_require_repeated(row_warmup[indexes], "warmup"),
      run_signature = benchmark_gate_require_repeated(
        row_run_signature[indexes], "run_signature"
      ),
      pair_signature = benchmark_gate_require_repeated(
        row_pair_signature[indexes], "pair_signature"
      ),
      model_signature = benchmark_gate_require_repeated(
        row_model_signature[indexes], "model_signature"
      ),
      backend = benchmark_gate_require_repeated(
        row_backend[indexes], "backend"
      ),
      threads = benchmark_gate_require_repeated(row_threads[indexes], "threads"),
      status = benchmark_gate_require_repeated(row_status[indexes], "status"),
      metrics = stats::setNames(row_value[indexes], metrics)
    )
    record$schema_version = as.integer(record$schema_version)
    record$repetition = as.integer(record$repetition)
    record$warmup = identical(tolower(record$warmup), "true")
    record$threads = as.integer(record$threads)
    record
  })
  names(records) = names(groups)
  for (record in records) {
    benchmark_gate_metric_numeric(record, "solve_seconds", minimum = 0)
    benchmark_gate_metric_numeric(record, "peak_rss_bytes", minimum = 0)
    benchmark_gate_metric_numeric(
      record, "max_full_relative_residual", minimum = 0
    )
    if (!benchmark_gate_metric_flag(record, "solution_finite") ||
        !benchmark_gate_metric_flag(record, "selected_outputs_finite") ||
        benchmark_gate_metric_flag(record, "dense_full_system_operations")) {
      benchmark_gate_fail(sprintf(
        "Benchmark run %s failed finite or dense-operation evidence checks",
        record$run_id
      ))
    }
  }
  measured = records[!vapply(records, function(record) record$warmup, logical(1))]
  if (!length(measured)) benchmark_gate_fail("No measured benchmark runs found")
  if (!any(vapply(measured, function(record) {
    identical(record$backend, reference_name)
  }, logical(1)))) {
    benchmark_gate_fail("No measured reference benchmark run found")
  }
  if (!any(vapply(measured, function(record) {
    identical(record$backend, candidate_name)
  }, logical(1)))) {
    benchmark_gate_fail("No measured candidate benchmark run found")
  }
  records
}

benchmark_gate_validate_numeric_leaf = function(value, label) {
  if (is.null(value) || !is.atomic(value) || typeof(value) != "double" ||
      is.object(value) || !length(value) || any(!is.finite(value))) {
    benchmark_gate_fail(sprintf(
      "%s must be a nonempty unclassed finite double leaf", label
    ))
  }
  names_value = names(value)
  if (!is.null(names_value) &&
      (length(names_value) != length(value) || anyNA(names_value) ||
       any(!nzchar(names_value)))) {
    benchmark_gate_fail(sprintf("%s has invalid names", label))
  }
  dimensions = dim(value)
  if (is.null(dimensions)) {
    if (!is.null(dimnames(value))) {
      benchmark_gate_fail(sprintf("%s has dimnames without dimensions", label))
    }
  } else {
    if (!length(dimensions) || anyNA(dimensions) ||
        any(dimensions < 1L) || any(dimensions != as.integer(dimensions)) ||
        prod(dimensions) != length(value)) {
      benchmark_gate_fail(sprintf("%s has invalid dimensions", label))
    }
    dimension_names = dimnames(value)
    if (!is.null(dimension_names)) {
      if (!is.list(dimension_names) || length(dimension_names) != length(dimensions)) {
        benchmark_gate_fail(sprintf("%s has invalid dimnames", label))
      }
      for (index in seq_along(dimensions)) {
        names_for_dimension = dimension_names[[index]]
        if (!is.null(names_for_dimension) &&
            (length(names_for_dimension) != dimensions[[index]] ||
             !is.character(names_for_dimension) ||
             anyNA(names_for_dimension) || any(!nzchar(names_for_dimension)))) {
          benchmark_gate_fail(sprintf("%s has invalid dimnames", label))
        }
      }
    }
  }
  invisible(value)
}

benchmark_gate_validate_output_tree = function(value, label) {
  if (!is.list(value) || is.object(value) || !length(value) ||
      is.null(names(value)) || length(names(value)) != length(value) ||
      anyNA(names(value)) || any(!nzchar(names(value))) ||
      anyDuplicated(names(value))) {
    benchmark_gate_fail(sprintf(
      "%s must be a nonempty named unclassed list", label
    ))
  }
  for (name in names(value)) {
    item = value[[name]]
    if (is.list(item)) {
      benchmark_gate_validate_output_tree(item, paste0(label, "$", name))
    } else {
      benchmark_gate_validate_numeric_leaf(item, paste0(label, "$", name))
    }
  }
  invisible(value)
}

benchmark_gate_validate_solution_artifacts = function(solution_files, records,
                                                      reference_name,
                                                      candidate_name) {
  if (!length(solution_files)) {
    benchmark_gate_fail("Benchmark solution evidence is required")
  }
  solutions = list()
  for (path in solution_files) {
    value = tryCatch(
      readRDS(path),
      error = function(error) benchmark_gate_fail(sprintf(
        "Could not read benchmark solution %s: %s", path,
        conditionMessage(error)
      ))
    )
    required_fields = c(
      "schema_version", "run_id", "pair_signature", "run_signature",
      "model_signature", "backend", "threads", "repetition", "warmup",
      "solution", "selected_outputs"
    )
    if (!is.list(value) || is.null(names(value)) ||
        anyDuplicated(names(value)) || length(setdiff(required_fields, names(value)))) {
      benchmark_gate_fail(sprintf(
        "Solution artifact %s has an invalid schema", path
      ))
    }
    schema_version = benchmark_gate_scalar_integer(
      value$schema_version, sprintf("solution schema_version in %s", path),
      expected = 2L
    )
    run_id = benchmark_gate_scalar_text(
      value$run_id, sprintf("solution run_id in %s", path)
    )
    pair_signature = benchmark_gate_scalar_text(
      value$pair_signature, sprintf("solution pair_signature in %s", path)
    )
    run_signature = benchmark_gate_scalar_text(
      value$run_signature, sprintf("solution run_signature in %s", path)
    )
    model_signature = benchmark_gate_scalar_text(
      value$model_signature, sprintf("solution model_signature in %s", path)
    )
    backend = benchmark_gate_scalar_text(
      value$backend, sprintf("solution backend in %s", path)
    )
    if (!backend %in% c(reference_name, candidate_name)) {
      benchmark_gate_fail("Benchmark solution contains an unknown backend artifact")
    }
    threads = benchmark_gate_scalar_integer(
      value$threads, sprintf("solution threads in %s", path)
    )
    repetition = benchmark_gate_scalar_integer(
      value$repetition, sprintf("solution repetition in %s", path)
    )
    warmup = benchmark_gate_scalar_flag(
      value$warmup, sprintf("solution warmup in %s", path)
    )
    benchmark_gate_validate_numeric_leaf(
      value$solution, sprintf("solution vector in %s", path)
    )
    benchmark_gate_validate_output_tree(
      value$selected_outputs, sprintf("selected_outputs in %s", path)
    )
    key = paste(backend, run_id, sep = "\r")
    if (key %in% names(solutions)) {
      benchmark_gate_fail(sprintf("Duplicate solution artifact for %s", key))
    }
    record = records[[key]]
    if (is.null(record)) {
      benchmark_gate_fail(sprintf(
        "Solution artifact %s has no matching CSV run", path
      ))
    }
    if (!identical(run_id, record$run_id) ||
        !identical(threads, record$threads) ||
        !identical(repetition, record$repetition) ||
        !identical(warmup, record$warmup) ||
        !identical(run_signature, record$run_signature) ||
        !identical(pair_signature, record$pair_signature) ||
        !identical(model_signature, record$model_signature)) {
      benchmark_gate_fail(sprintf(
        "Solution artifact %s disagrees with its CSV metadata", path
      ))
    }
    value$schema_version = schema_version
    value$run_id = run_id
    value$pair_signature = pair_signature
    value$run_signature = run_signature
    value$model_signature = model_signature
    value$backend = backend
    value$threads = threads
    value$repetition = repetition
    value$warmup = warmup
    solutions[[key]] = value
  }
  missing = setdiff(names(records), names(solutions))
  if (length(missing)) {
    benchmark_gate_fail(sprintf(
      "Missing solution artifact for CSV run(s): %s", paste(missing, collapse = ", ")
    ))
  }
  solutions
}

benchmark_validate_solution_artifacts = benchmark_gate_validate_solution_artifacts

benchmark_gate_solution_key = function(value) {
  paste(value$pair_signature, value$repetition, sep = "\r")
}

benchmark_gate_solution_set = function(solutions, backend) {
  selected = solutions[vapply(solutions, function(value) {
    identical(value$backend, backend) && !isTRUE(value$warmup)
  }, logical(1))]
  if (!length(selected)) {
    benchmark_gate_fail(sprintf("No measured solution artifact for %s", backend))
  }
  keys = unname(vapply(selected, benchmark_gate_solution_key, character(1)))
  if (anyDuplicated(keys)) {
    benchmark_gate_fail(sprintf(
      "Duplicate measured solution comparison key for %s", backend
    ))
  }
  order_by_key = order(keys, method = "radix")
  list(
    keys = keys[order_by_key],
    values = selected[order_by_key]
  )
}

benchmark_gate_leaf_difference = function(reference, candidate, label) {
  if (typeof(reference) != "double" || typeof(candidate) != "double" ||
      !identical(attr(reference, "class", exact = TRUE),
                 attr(candidate, "class", exact = TRUE)) ||
      !identical(names(reference), names(candidate)) ||
      !identical(dim(reference), dim(candidate)) ||
      !identical(dimnames(reference), dimnames(candidate)) ||
      length(reference) != length(candidate)) {
    benchmark_gate_fail(sprintf("Solution shape or type disagrees at %s", label))
  }
  difference = suppressWarnings(abs(reference - candidate))
  if (any(!is.finite(difference))) {
    benchmark_gate_fail(sprintf("Solution difference is nonfinite at %s", label))
  }
  max(difference)
}

benchmark_gate_tree_difference = function(reference, candidate, label) {
  if (!is.list(reference) || !is.list(candidate) ||
      !identical(names(reference), names(candidate)) ||
      length(reference) != length(candidate)) {
    benchmark_gate_fail(sprintf(
      "Selected output structure disagrees at %s", label
    ))
  }
  differences = vapply(names(reference), function(name) {
    reference_item = reference[[name]]
    candidate_item = candidate[[name]]
    item_label = paste0(label, "$", name)
    if (is.list(reference_item) || is.list(candidate_item)) {
      if (!is.list(reference_item) || !is.list(candidate_item)) {
        benchmark_gate_fail(sprintf(
          "Selected output structure disagrees at %s", item_label
        ))
      }
      benchmark_gate_tree_difference(reference_item, candidate_item, item_label)
    } else {
      benchmark_gate_leaf_difference(reference_item, candidate_item, item_label)
    }
  }, numeric(1))
  max(differences)
}

benchmark_compare_solution_pairs = function(solutions, reference_name,
                                            candidate_name,
                                            maximum_difference) {
  maximum_difference = suppressWarnings(as.numeric(maximum_difference))
  if (length(maximum_difference) != 1L || !is.finite(maximum_difference) ||
      maximum_difference < 0) {
    benchmark_gate_fail("maximum-difference must be a finite nonnegative scalar")
  }
  reference = benchmark_gate_solution_set(solutions, reference_name)
  candidate = benchmark_gate_solution_set(solutions, candidate_name)
  if (!identical(reference$keys, candidate$keys)) {
    benchmark_gate_fail(
      "Reference and candidate solution comparison keys do not match"
    )
  }
  differences = vapply(seq_along(reference$keys), function(index) {
    reference_value = reference$values[[index]]
    candidate_value = candidate$values[[index]]
    if (!identical(reference_value$pair_signature,
                   candidate_value$pair_signature) ||
        !identical(reference_value$model_signature,
                   candidate_value$model_signature)) {
      benchmark_gate_fail(sprintf(
        "Solution pair/model signatures disagree for key %s",
        reference$keys[[index]]
      ))
    }
    solution_difference = benchmark_gate_leaf_difference(
      reference_value$solution, candidate_value$solution,
      sprintf("solution key %s", reference$keys[[index]])
    )
    output_difference = benchmark_gate_tree_difference(
      reference_value$selected_outputs, candidate_value$selected_outputs,
      sprintf("selected_outputs key %s", reference$keys[[index]])
    )
    max(solution_difference, output_difference)
  }, numeric(1))
  maximum_solution_difference = max(differences)
  if (!is.finite(maximum_solution_difference) ||
      maximum_solution_difference > maximum_difference) {
    benchmark_gate_fail("A/B solution difference exceeded maximum-difference")
  }
  list(
    maximum_solution_difference = maximum_solution_difference,
    keys = reference$keys,
    differences = differences
  )
}

benchmark_gate_backend_metric = function(records, backend, metric, fun = median,
                                        minimum = NULL) {
  selected = records[vapply(records, function(record) {
    identical(record$backend, backend) && !isTRUE(record$warmup)
  }, logical(1))]
  values = vapply(
    selected,
    function(record) benchmark_gate_metric_numeric(record, metric, minimum),
    numeric(1)
  )
  result = fun(values)
  if (length(result) != 1L || !is.finite(result)) {
    benchmark_gate_fail(sprintf("Metric %s for %s is not finite", metric, backend))
  }
  result
}

benchmark_gate_run = function(input_dir, reference_name = "StructuredSchurFGMRES",
                              candidate_name = "StructuredSchurFGMRESCpp",
                              minimum_speedup = 0.20,
                              maximum_rss_ratio = 1.10,
                              maximum_residual = 2e-7,
                              maximum_difference = 1e-6,
                              output = file.path(input_dir, "comparison.csv")) {
  reference_name = benchmark_gate_scalar_text(reference_name, "reference backend")
  candidate_name = benchmark_gate_scalar_text(candidate_name, "candidate backend")
  if (identical(reference_name, candidate_name)) {
    benchmark_gate_fail("Reference and candidate backends must differ")
  }
  thresholds = c(
    minimum_speedup = minimum_speedup,
    maximum_rss_ratio = maximum_rss_ratio,
    maximum_residual = maximum_residual,
    maximum_difference = maximum_difference
  )
  thresholds = suppressWarnings(as.numeric(thresholds))
  if (any(!is.finite(thresholds)) || minimum_speedup < 0 ||
      minimum_speedup >= 1 || maximum_rss_ratio < 0 ||
      maximum_residual < 0 || maximum_difference < 0) {
    benchmark_gate_fail("Benchmark gate thresholds must be finite and valid")
  }
  minimum_speedup = thresholds[[1L]]
  maximum_rss_ratio = thresholds[[2L]]
  maximum_residual = thresholds[[3L]]
  maximum_difference = thresholds[[4L]]
  files = list.files(input_dir, pattern = "[.]csv$", full.names = TRUE)
  output_path = normalizePath(output, mustWork = FALSE)
  files = files[normalizePath(files, mustWork = FALSE) != output_path]
  records = benchmark_gate_read_csv_records(
    files, reference_name, candidate_name
  )
  solution_files = list.files(input_dir, pattern = "[.]rds$", full.names = TRUE)
  solutions = benchmark_gate_validate_solution_artifacts(
    solution_files, records, reference_name, candidate_name
  )
  comparison = benchmark_compare_solution_pairs(
    solutions, reference_name, candidate_name, maximum_difference
  )
  reference_time = benchmark_gate_backend_metric(
    records, reference_name, "solve_seconds", minimum = 0
  )
  candidate_time = benchmark_gate_backend_metric(
    records, candidate_name, "solve_seconds", minimum = 0
  )
  reference_rss = benchmark_gate_backend_metric(
    records, reference_name, "peak_rss_bytes", minimum = 0
  )
  candidate_rss = benchmark_gate_backend_metric(
    records, candidate_name, "peak_rss_bytes", minimum = 0
  )
  reference_residual = benchmark_gate_backend_metric(
    records, reference_name, "max_full_relative_residual", max, minimum = 0
  )
  candidate_residual = benchmark_gate_backend_metric(
    records, candidate_name, "max_full_relative_residual", max, minimum = 0
  )
  wall_time_ratio = candidate_time / reference_time
  peak_rss_ratio = candidate_rss / reference_rss
  if (!is.finite(wall_time_ratio) || !is.finite(peak_rss_ratio) ||
      reference_time <= 0 || reference_rss <= 0 ||
      wall_time_ratio > 1 - minimum_speedup ||
      peak_rss_ratio > maximum_rss_ratio ||
      candidate_residual > maximum_residual ||
      reference_residual > maximum_residual) {
    benchmark_gate_fail("A/B benchmark gate failed")
  }
  summary = data.frame(
    metric = c(
      "reference_median_solve_seconds", "candidate_median_solve_seconds",
      "wall_time_ratio", "peak_rss_ratio",
      "reference_max_full_relative_residual",
      "candidate_max_full_relative_residual",
      "max_abs_solution_difference"
    ),
    value = c(
      reference_time, candidate_time, wall_time_ratio, peak_rss_ratio,
      reference_residual, candidate_residual,
      comparison$maximum_solution_difference
    ),
    stringsAsFactors = FALSE
  )
  if (any(!is.finite(summary$value))) {
    benchmark_gate_fail("A/B benchmark summary contains a nonfinite value")
  }
  list(summary = summary, records = records, solutions = solutions)
}

benchmark_gate_cli = function(args = commandArgs(trailingOnly = TRUE)) {
  script_dir = benchmark_gate_script_dir()
  source(file.path(script_dir, "benchmark_config.R"), local = environment())
  input_dir = normalizePath(benchmark_get_arg(args, "--input-dir"), mustWork = TRUE)
  reference_name = benchmark_get_arg(args, "--reference", "StructuredSchurFGMRES")
  candidate_name = benchmark_get_arg(args, "--candidate", "StructuredSchurFGMRESCpp")
  minimum_speedup = benchmark_get_arg(args, "--minimum-speedup", "0.20")
  maximum_rss_ratio = benchmark_get_arg(args, "--maximum-rss-ratio", "1.10")
  maximum_residual = benchmark_get_arg(args, "--maximum-residual", "2e-7")
  maximum_difference = benchmark_get_arg(args, "--maximum-difference", "1e-6")
  output = benchmark_get_arg(args, "--output", file.path(input_dir, "comparison.csv"))
  result = benchmark_gate_run(
    input_dir = input_dir,
    reference_name = reference_name,
    candidate_name = candidate_name,
    minimum_speedup = minimum_speedup,
    maximum_rss_ratio = maximum_rss_ratio,
    maximum_residual = maximum_residual,
    maximum_difference = maximum_difference,
    output = output
  )
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  write.csv(result$summary, output, row.names = FALSE)
  invisible(result)
}

if (sys.nframe() == 0L) benchmark_gate_cli()
