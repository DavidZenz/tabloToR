benchmark_gate_test_process = function(command, arguments = character(),
                                       directory = NULL) {
  old = NULL
  if (!is.null(directory)) {
    old = setwd(directory)
    on.exit(setwd(old), add = TRUE)
  }
  output = suppressWarnings(system2(
    command,
    c(arguments),
    stdout = TRUE,
    stderr = TRUE
  ))
  status = attr(output, "status")
  if (is.null(status)) status = 0L
  list(status = as.integer(status), output = as.character(output))
}

benchmark_gate_source_root = function() {
  candidates = c(
    testthat::test_path("..", ".."),
    testthat::test_path("..", "..", "00_pkg_src", "GEModelR")
  )
  candidates = candidates[vapply(candidates, function(path) {
    file.exists(file.path(path, "DESCRIPTION")) &&
      dir.exists(file.path(path, "R")) &&
      dir.exists(file.path(path, "benchmarks"))
  }, logical(1L))]
  if (!length(candidates)) {
    stop("GEModelR source tree is unavailable", call. = FALSE)
  }
  normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
}

benchmark_gate_test_install = function() {
  source_root = benchmark_gate_source_root()
  root = tempfile("GEModelR-benchmark-gate-install-")
  build_root = file.path(root, "build")
  library = file.path(root, "library")
  dir.create(build_root, recursive = TRUE)
  dir.create(library)

  build = benchmark_gate_test_process(
    file.path(R.home("bin"), "R"),
    c("CMD", "build", "--no-manual", shQuote(source_root)),
    directory = build_root
  )
  if (!identical(build$status, 0L)) {
    stop(paste(c("R CMD build failed:", build$output), collapse = "\n"),
         call. = FALSE)
  }
  archives = list.files(
    build_root, pattern = "^GEModelR_[^/]+[.]tar[.]gz$", full.names = TRUE
  )
  if (length(archives) != 1L) {
    stop("Expected exactly one GEModelR source archive", call. = FALSE)
  }
  install = benchmark_gate_test_process(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", paste0("--library=", shQuote(library)),
      shQuote(archives[[1L]])),
    directory = build_root
  )
  if (!identical(install$status, 0L)) {
    stop(paste(c("R CMD INSTALL failed:", install$output), collapse = "\n"),
         call. = FALSE)
  }
  script = base::system.file(
    "benchmarks", "check_benchmark_gate.R", package = "GEModelR",
    lib.loc = library
  )
  if (!nzchar(script) || !file.exists(script)) {
    stop("Installed benchmark correctness gate is missing", call. = FALSE)
  }
  list(root = root, library = library, script = normalizePath(script, mustWork = TRUE))
}

benchmark_gate_test_run_id = function(backend) {
  paste0("measured-01-", gsub("[^[:alnum:]]", "-", backend))
}

benchmark_gate_test_csv = function(path, backend, solve_seconds, pair = "pair-fixture",
                                    model = "model-fixture") {
  run_id = benchmark_gate_test_run_id(backend)
  metrics = data.frame(
    metric = c(
      "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
      "solution_finite", "selected_outputs_finite",
      "dense_full_system_operations"
    ),
    value = c(
      as.character(solve_seconds), "100", "1e-10", "TRUE", "TRUE", "FALSE"
    ),
    unit = c("seconds", "bytes", "ratio", "value", "value", "value"),
    stringsAsFactors = FALSE
  )
  metadata = data.frame(
    schema_version = rep(3L, nrow(metrics)),
    run_id = rep(run_id, nrow(metrics)),
    repetition = rep(1L, nrow(metrics)),
    warmup = rep(FALSE, nrow(metrics)),
    timestamp_utc = rep("2026-09-18 00:00:00 UTC", nrow(metrics)),
    run_signature = rep(paste0("run-", backend), nrow(metrics)),
    pair_signature = rep(pair, nrow(metrics)),
    model_signature = rep(model, nrow(metrics)),
    git_commit = rep("fixture", nrow(metrics)),
    package_name = rep("GEModelR", nrow(metrics)),
    package_version = rep("0.1.0", nrow(metrics)),
    option_prefix = rep("GEModelR.", nrow(metrics)),
    native_routine_prefix = rep(".GEModelR_", nrow(metrics)),
    r_version = rep("4", nrow(metrics)),
    matrix_version = rep("1.6.3", nrow(metrics)),
    platform = rep(R.version$platform, nrow(metrics)),
    backend = rep(backend, nrow(metrics)),
    threads = rep(1L, nrow(metrics)),
    iter = rep(1L, nrow(metrics)),
    steps = rep("1", nrow(metrics)),
    postsim = rep(TRUE, nrow(metrics)),
    status = rep("completed", nrow(metrics)),
    error = rep("", nrow(metrics)),
    stringsAsFactors = FALSE
  )
  write.csv(cbind(metadata, metrics), path, row.names = FALSE)
  run_id
}

benchmark_gate_test_solution = function(path, backend, solution,
                                        pair = "pair-fixture",
                                        model = "model-fixture") {
  run_id = benchmark_gate_test_run_id(backend)
  saveRDS(list(
    schema_version = 2L,
    run_id = run_id,
    pair_signature = pair,
    run_signature = paste0("run-", backend),
    model_signature = model,
    backend = backend,
    threads = 1L,
    repetition = 1L,
    warmup = FALSE,
    solution = setNames(as.double(solution), c("x", "y", "z")),
    selected_outputs = list(total = as.double(c(4, 5)))
  ), path, version = 3L)
}

benchmark_gate_test_cli = function(script, input_dir, output) {
  benchmark_gate_test_process(
    file.path(R.home("bin"), "Rscript"),
    c(
      "--vanilla", shQuote(script),
      paste0("--input-dir=", shQuote(input_dir)),
      "--reference=ReferenceBackend",
      "--candidate=CandidateBackend",
      "--minimum-speedup=0.20",
      "--maximum-rss-ratio=1.10",
      "--maximum-residual=2e-7",
      "--maximum-difference=1e-6",
      paste0("--output=", shQuote(output))
    )
  )
}

test_that("installed benchmark gate requires a matched solution pair", {
  source_script = file.path(
    benchmark_gate_source_root(), "benchmarks", "check_benchmark_gate.R"
  )
  source_environment = new.env(parent = globalenv())
  sys.source(source_script, envir = source_environment)
  expect_true(is.function(source_environment$benchmark_validate_solution_artifacts))
  expect_true(is.function(source_environment$benchmark_compare_solution_pairs))

  installed = benchmark_gate_test_install()
  on.exit(unlink(installed$root, recursive = TRUE, force = TRUE), add = TRUE)
  evidence = file.path(installed$root, "evidence")
  dir.create(evidence)

  reference = benchmark_gate_test_csv(
    file.path(evidence, "reference.csv"), "ReferenceBackend", 1
  )
  candidate = benchmark_gate_test_csv(
    file.path(evidence, "candidate.csv"), "CandidateBackend", 0.5
  )
  benchmark_gate_test_solution(
    file.path(evidence, paste0(reference, ".rds")),
    "ReferenceBackend", c(1, 2, 3)
  )
  benchmark_gate_test_solution(
    file.path(evidence, paste0(candidate, ".rds")),
    "CandidateBackend", c(1, 2, 3)
  )

  output = file.path(evidence, "comparison.csv")
  result = benchmark_gate_test_cli(installed$script, evidence, output)
  expect_equal(
    result$status, 0L,
    info = paste(c("Installed gate output:", result$output), collapse = "\n")
  )
  expect_true(file.exists(output))
  summary = read.csv(output, stringsAsFactors = FALSE)
  difference = summary$value[summary$metric == "max_abs_solution_difference"]
  expect_length(difference, 1L)
  expect_true(is.finite(as.numeric(difference)))
  expect_equal(as.numeric(difference), 0)

  csv_only = file.path(installed$root, "csv-only")
  dir.create(csv_only)
  file.copy(
    list.files(evidence, pattern = "[.]csv$", full.names = TRUE),
    csv_only
  )
  csv_only_output = file.path(csv_only, "comparison.csv")
  csv_only_result = benchmark_gate_test_cli(
    installed$script, csv_only, csv_only_output
  )
  expect_false(
    identical(csv_only_result$status, 0L),
    info = paste(c("CSV-only gate output:", csv_only_result$output), collapse = "\n")
  )
})


benchmark_gate_task2_source_script = function() {
  normalizePath(
    file.path(benchmark_gate_source_root(), "benchmarks", "check_benchmark_gate.R"),
    mustWork = TRUE
  )
}

benchmark_gate_task2_run_id = function(backend, repetition = 1L,
                                       warmup = FALSE, tag = NULL) {
  prefix = if (isTRUE(warmup)) "warmup" else "measured"
  suffix = if (is.null(tag)) {
    gsub("[^[:alnum:]]", "-", backend)
  } else {
    as.character(tag)
  }
  sprintf("%s-%02d-%s", prefix, as.integer(repetition), suffix)
}

benchmark_gate_task2_write_csv = function(
    path, backend, solve_seconds = 1, repetition = 1L, warmup = FALSE,
    pair = "pair-fixture", model = "model-fixture", run_id = NULL,
    run_signature = NULL, metric_values = list(), metadata_values = list()) {
  if (is.null(run_id)) {
    run_id = benchmark_gate_task2_run_id(backend, repetition, warmup)
  }
  if (is.null(run_signature)) run_signature = paste0("run-", run_id)
  metrics = data.frame(
    metric = c(
      "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
      "solution_finite", "selected_outputs_finite",
      "dense_full_system_operations"
    ),
    value = c(as.character(solve_seconds), "100", "1e-10",
              "TRUE", "TRUE", "FALSE"),
    unit = c("seconds", "bytes", "ratio", "value", "value", "value"),
    stringsAsFactors = FALSE
  )
  if (length(metric_values)) {
    for (name in names(metric_values)) {
      index = match(name, metrics$metric)
      if (is.na(index)) stop(sprintf("Unknown fixture metric: %s", name))
      metrics$value[[index]] = as.character(metric_values[[name]])
    }
  }
  metadata = data.frame(
    schema_version = rep(3L, nrow(metrics)),
    run_id = rep(run_id, nrow(metrics)),
    repetition = rep(as.integer(repetition), nrow(metrics)),
    warmup = rep(isTRUE(warmup), nrow(metrics)),
    timestamp_utc = rep("2026-09-18 00:00:00 UTC", nrow(metrics)),
    run_signature = rep(run_signature, nrow(metrics)),
    pair_signature = rep(pair, nrow(metrics)),
    model_signature = rep(model, nrow(metrics)),
    git_commit = rep("fixture", nrow(metrics)),
    package_name = rep("GEModelR", nrow(metrics)),
    package_version = rep("0.1.0", nrow(metrics)),
    option_prefix = rep("GEModelR.", nrow(metrics)),
    native_routine_prefix = rep(".GEModelR_", nrow(metrics)),
    r_version = rep("4", nrow(metrics)),
    matrix_version = rep("1.6.3", nrow(metrics)),
    platform = rep(R.version$platform, nrow(metrics)),
    backend = rep(backend, nrow(metrics)),
    threads = rep(1L, nrow(metrics)),
    iter = rep(1L, nrow(metrics)),
    steps = rep("1", nrow(metrics)),
    postsim = rep(TRUE, nrow(metrics)),
    status = rep("completed", nrow(metrics)),
    error = rep("", nrow(metrics)),
    stringsAsFactors = FALSE
  )
  if (length(metadata_values)) {
    for (name in names(metadata_values)) {
      if (!name %in% names(metadata)) {
        stop(sprintf("Unknown fixture metadata: %s", name))
      }
      value = metadata_values[[name]]
      if (length(value) == 1L) value = rep(value, nrow(metadata))
      if (length(value) != nrow(metadata)) {
        stop(sprintf("Fixture metadata length mismatch: %s", name))
      }
      metadata[[name]] = value
    }
  }
  write.csv(cbind(metadata, metrics), path, row.names = FALSE)
  run_id
}

benchmark_gate_task2_write_solution = function(
    path, backend, solution = as.double(c(1, 2, 3)),
    repetition = 1L, warmup = FALSE, pair = "pair-fixture",
    model = "model-fixture", run_id = NULL, run_signature = NULL,
    selected_outputs = list(total = as.double(c(4, 5))), fields = list()) {
  if (is.null(run_id)) {
    run_id = benchmark_gate_task2_run_id(backend, repetition, warmup)
  }
  if (is.null(run_signature)) run_signature = paste0("run-", run_id)
  if (is.double(solution) && is.null(dim(solution)) &&
      is.null(names(solution)) && length(solution) == 3L) {
    solution = setNames(solution, c("x", "y", "z"))
  }
  value = list(
    schema_version = 2L,
    run_id = run_id,
    pair_signature = pair,
    run_signature = run_signature,
    model_signature = model,
    backend = backend,
    threads = 1L,
    repetition = as.integer(repetition),
    warmup = isTRUE(warmup),
    solution = solution,
    selected_outputs = selected_outputs
  )
  if (length(fields)) {
    for (name in names(fields)) value[[name]] = fields[[name]]
  }
  saveRDS(value, path, version = 3L)
  invisible(value)
}

benchmark_gate_task2_find = function(root, backend, extension) {
  paths = list.files(root, pattern = paste0("[.]", extension, "$"),
                     full.names = TRUE)
  hit = paths[vapply(paths, function(path) {
    grepl(backend, basename(path), fixed = TRUE)
  }, logical(1))]
  if (!length(hit)) stop(sprintf("No %s fixture for %s", extension, backend))
  hit[[1L]]
}

benchmark_gate_task2_fixture = function(root, repetitions = 1L,
                                        include_warmups = FALSE,
                                        warmup_rds = TRUE) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  for (repetition in as.integer(repetitions)) {
    reference = as.double(c(repetition, repetition + 1, repetition + 2))
    candidate = reference
    reference_id = benchmark_gate_task2_run_id(
      "ReferenceBackend", repetition, FALSE
    )
    candidate_id = benchmark_gate_task2_run_id(
      "CandidateBackend", repetition, FALSE
    )
    benchmark_gate_task2_write_csv(
      file.path(root, paste0("z-ReferenceBackend-", repetition, ".csv")),
      "ReferenceBackend", solve_seconds = 1, repetition = repetition,
      run_id = reference_id
    )
    benchmark_gate_task2_write_csv(
      file.path(root, paste0("a-CandidateBackend-", repetition, ".csv")),
      "CandidateBackend", solve_seconds = 0.5, repetition = repetition,
      run_id = candidate_id
    )
    benchmark_gate_task2_write_solution(
      file.path(root, paste0("z-ReferenceBackend-", repetition, ".rds")),
      "ReferenceBackend", reference, repetition = repetition, run_id = reference_id,
      selected_outputs = list(total = as.double(c(repetition + 3, repetition + 4)))
    )
    benchmark_gate_task2_write_solution(
      file.path(root, paste0("a-CandidateBackend-", repetition, ".rds")),
      "CandidateBackend", candidate, repetition = repetition, run_id = candidate_id,
      selected_outputs = list(total = as.double(c(repetition + 3, repetition + 4)))
    )
  }
  if (isTRUE(include_warmups)) {
    warmup_repetition = 1L
    reference_id = benchmark_gate_task2_run_id(
      "ReferenceBackend", warmup_repetition, TRUE
    )
    candidate_id = benchmark_gate_task2_run_id(
      "CandidateBackend", warmup_repetition, TRUE
    )
    benchmark_gate_task2_write_csv(
      file.path(root, "warmup-ReferenceBackend.csv"), "ReferenceBackend",
      solve_seconds = 1, repetition = warmup_repetition, warmup = TRUE,
      run_id = reference_id
    )
    benchmark_gate_task2_write_csv(
      file.path(root, "warmup-CandidateBackend.csv"), "CandidateBackend",
      solve_seconds = 0.5, repetition = warmup_repetition, warmup = TRUE,
      run_id = candidate_id
    )
    if (isTRUE(warmup_rds)) {
      benchmark_gate_task2_write_solution(
        file.path(root, "warmup-ReferenceBackend.rds"), "ReferenceBackend",
        repetition = warmup_repetition, warmup = TRUE, run_id = reference_id
      )
      benchmark_gate_task2_write_solution(
        file.path(root, "warmup-CandidateBackend.rds"), "CandidateBackend",
        repetition = warmup_repetition, warmup = TRUE, run_id = candidate_id
      )
    }
  }
  invisible(root)
}

benchmark_gate_task2_cli = function(
    root, output = tempfile("GEModelR-benchmark-gate-summary-", fileext = ".csv"),
    maximum_difference = "1e-6") {
  benchmark_gate_test_process(
    file.path(R.home("bin"), "Rscript"),
    c(
      "--vanilla", shQuote(benchmark_gate_task2_source_script()),
      paste0("--input-dir=", shQuote(root)),
      "--reference=ReferenceBackend",
      "--candidate=CandidateBackend",
      "--minimum-speedup=0.20",
      "--maximum-rss-ratio=1.10",
      "--maximum-residual=2e-7",
      paste0("--maximum-difference=", maximum_difference),
      paste0("--output=", shQuote(output))
    )
  )
}

benchmark_gate_task2_expect_failure = function(
    label, mutate = function(root) invisible(root),
    build = benchmark_gate_task2_fixture) {
  root = tempfile("GEModelR-benchmark-gate-case-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  build(root)
  mutate(root)
  result = benchmark_gate_task2_cli(root)
  testthat::expect_false(
    identical(result$status, 0L),
    info = paste(c(label, result$output), collapse = "\n")
  )
  invisible(result)
}

benchmark_gate_task2_case_solution = function(root, backend = "CandidateBackend") {
  benchmark_gate_task2_find(root, backend, "rds")
}

test_that("benchmark correctness gate rejects malformed and incomplete evidence", {
  benchmark_gate_task2_expect_failure(
    "both backends absent",
    function(root) {
      unlink(list.files(root, full.names = TRUE), force = TRUE)
    },
    build = function(root) {
      dir.create(root, recursive = TRUE, showWarnings = FALSE)
    }
  )
  benchmark_gate_task2_expect_failure(
    "one backend absent",
    function(root) {
      unlink(list.files(root, pattern = "CandidateBackend",
                        full.names = TRUE), force = TRUE)
    }
  )
  benchmark_gate_task2_expect_failure(
    "unequal measured counts",
    function(root) {
      unlink(list.files(root, pattern = "CandidateBackend-2",
                        full.names = TRUE), force = TRUE)
    },
    build = function(root) benchmark_gate_task2_fixture(root, 1:2)
  )
  benchmark_gate_task2_expect_failure(
    "duplicate per-backend run IDs",
    function(root) {
      reference_csv = benchmark_gate_task2_find(root, "ReferenceBackend", "csv")
      reference_rds = benchmark_gate_task2_find(root, "ReferenceBackend", "rds")
      file.copy(reference_csv, file.path(root, "duplicate-reference.csv"))
      file.copy(reference_rds, file.path(root, "duplicate-reference.rds"))
    }
  )
  benchmark_gate_task2_expect_failure(
    "duplicate comparison keys under different run IDs",
    function(root) {
      benchmark_gate_task2_write_csv(
        file.path(root, "extra-reference.csv"), "ReferenceBackend",
        run_id = "measured-other-reference", repetition = 1L
      )
      benchmark_gate_task2_write_solution(
        file.path(root, "extra-reference.rds"), "ReferenceBackend",
        run_id = "measured-other-reference", repetition = 1L
      )
    }
  )
  benchmark_gate_task2_expect_failure(
    "missing repetition",
    function(root) {
      path = benchmark_gate_task2_find(root, "ReferenceBackend", "csv")
      frame = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
      frame$repetition[[1L]] = NA_integer_
      write.csv(frame, path, row.names = FALSE)
    }
  )
  benchmark_gate_task2_expect_failure(
    "missing RDS counterpart",
    function(root) {
      unlink(benchmark_gate_task2_find(root, "CandidateBackend", "rds"))
    }
  )
  benchmark_gate_task2_expect_failure(
    "missing CSV counterpart",
    function(root) {
      unlink(benchmark_gate_task2_find(root, "CandidateBackend", "csv"))
    }
  )
  benchmark_gate_task2_expect_failure(
    "unrelated backend CSV artifact",
    function(root) {
      benchmark_gate_task2_write_csv(
        file.path(root, "unrelated.csv"), "UnrelatedBackend"
      )
    }
  )
  benchmark_gate_task2_expect_failure(
    "unrelated backend RDS artifact",
    function(root) {
      benchmark_gate_task2_write_solution(
        file.path(root, "unrelated.rds"), "UnrelatedBackend"
      )
    }
  )
  benchmark_gate_task2_expect_failure(
    "malformed RDS",
    function(root) {
      saveRDS(list(not_a_solution = TRUE),
              benchmark_gate_task2_case_solution(root))
    }
  )
  benchmark_gate_task2_expect_failure(
    "CSV/RDS metadata disagreement",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$threads = 2L
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "unequal pair signatures",
    function(root) {
      csv = benchmark_gate_task2_find(root, "CandidateBackend", "csv")
      frame = read.csv(csv, stringsAsFactors = FALSE, check.names = FALSE)
      frame$pair_signature = "different-pair"
      write.csv(frame, csv, row.names = FALSE)
      rds = benchmark_gate_task2_case_solution(root)
      value = readRDS(rds)
      value$pair_signature = "different-pair"
      saveRDS(value, rds, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "unequal model signatures",
    function(root) {
      csv = benchmark_gate_task2_find(root, "CandidateBackend", "csv")
      frame = read.csv(csv, stringsAsFactors = FALSE, check.names = FALSE)
      frame$model_signature = "different-model"
      write.csv(frame, csv, row.names = FALSE)
      rds = benchmark_gate_task2_case_solution(root)
      value = readRDS(rds)
      value$model_signature = "different-model"
      saveRDS(value, rds, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "bad per-backend run signature",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$run_signature = "wrong-run-signature"
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "missing required metric",
    function(root) {
      path = benchmark_gate_task2_find(root, "ReferenceBackend", "csv")
      frame = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
      frame = frame[frame$metric != "solve_seconds", , drop = FALSE]
      write.csv(frame, path, row.names = FALSE)
    }
  )
  benchmark_gate_task2_expect_failure(
    "repeated CSV metadata disagreement",
    function(root) {
      path = benchmark_gate_task2_find(root, "ReferenceBackend", "csv")
      frame = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
      frame$pair_signature[[1L]] = "different-row-pair"
      write.csv(frame, path, row.names = FALSE)
    }
  )
  benchmark_gate_task2_expect_failure(
    "same-length matrix versus vector",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$solution = matrix(as.double(c(1, 2, 3)), nrow = 1L)
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "permuted solution names",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$solution = setNames(as.double(c(1, 2, 3)), c("y", "x", "z"))
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "integer substituted for double",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$solution = setNames(as.integer(c(1, 2, 3)), c("x", "y", "z"))
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "logical substituted for double",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$solution = setNames(c(TRUE, FALSE, TRUE), c("x", "y", "z"))
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "selected output field disagreement",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$selected_outputs = list(other = as.double(c(4, 5)))
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "selected output order disagreement",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$selected_outputs = list(second = as.double(5), first = as.double(4))
      saveRDS(value, path, version = 3L)
    }
  )
  benchmark_gate_task2_expect_failure(
    "selected output shape disagreement",
    function(root) {
      path = benchmark_gate_task2_case_solution(root)
      value = readRDS(path)
      value$selected_outputs = list(total = matrix(as.double(c(4, 5)), nrow = 2L))
      saveRDS(value, path, version = 3L)
    }
  )
  bad_solutions = list(
    empty = double(),
    null = NULL,
    na = c(1, NA_real_, 3),
    nan = c(1, NaN, 3),
    inf = c(1, Inf, 3)
  )
  for (bad_name in names(bad_solutions)) {
    bad_value = bad_solutions[[bad_name]]
    benchmark_gate_task2_expect_failure(
      paste("invalid solution", bad_name),
      function(root, bad_solution = bad_value) {
        path = benchmark_gate_task2_case_solution(root)
        value = readRDS(path)
        value$solution = bad_solution
        saveRDS(value, path, version = 3L)
      }
    )
  }
  benchmark_gate_task2_expect_failure(
    "finite solution subtraction overflow",
    function(root) {
      reference = benchmark_gate_task2_find(root, "ReferenceBackend", "rds")
      candidate = benchmark_gate_task2_case_solution(root)
      reference_value = readRDS(reference)
      candidate_value = readRDS(candidate)
      reference_value$solution = setNames(
        c(1e308, 1e308, 1e308), c("x", "y", "z")
      )
      candidate_value$solution = setNames(
        c(-1e308, -1e308, -1e308), c("x", "y", "z")
      )
      saveRDS(reference_value, reference, version = 3L)
      saveRDS(candidate_value, candidate, version = 3L)
    }
  )
})

test_that("benchmark correctness gate handles warmups, ordering, and boundaries", {
  warmup_root = tempfile("GEModelR-benchmark-warmup-")
  dir.create(warmup_root)
  on.exit(unlink(warmup_root, recursive = TRUE, force = TRUE), add = TRUE)
  benchmark_gate_task2_fixture(
    warmup_root, include_warmups = TRUE, warmup_rds = FALSE
  )
  warmup_result = benchmark_gate_task2_cli(
    warmup_root, output = tempfile("GEModelR-warmup-summary-", fileext = ".csv")
  )
  expect_equal(
    warmup_result$status, 0L,
    info = paste(c("Warmup-only artifact output:", warmup_result$output),
                 collapse = "\n")
  )

  invalid_warmup_root = tempfile("GEModelR-invalid-warmup-")
  dir.create(invalid_warmup_root)
  on.exit(unlink(invalid_warmup_root, recursive = TRUE, force = TRUE), add = TRUE)
  benchmark_gate_task2_fixture(
    invalid_warmup_root, include_warmups = TRUE, warmup_rds = TRUE
  )
  warmup_rds = file.path(invalid_warmup_root, "warmup-CandidateBackend.rds")
  value = readRDS(warmup_rds)
  value$warmup = FALSE
  saveRDS(value, warmup_rds, version = 3L)
  invalid_warmup_result = benchmark_gate_task2_cli(
    invalid_warmup_root,
    output = tempfile("GEModelR-invalid-warmup-summary-", fileext = ".csv")
  )
  expect_false(identical(invalid_warmup_result$status, 0L))

  baseline_root = tempfile("GEModelR-benchmark-order-baseline-")
  reordered_root = tempfile("GEModelR-benchmark-order-reordered-")
  dir.create(baseline_root)
  dir.create(reordered_root)
  on.exit(unlink(baseline_root, recursive = TRUE, force = TRUE), add = TRUE)
  on.exit(unlink(reordered_root, recursive = TRUE, force = TRUE), add = TRUE)
  benchmark_gate_task2_fixture(baseline_root, repetitions = 1:2)
  benchmark_gate_task2_fixture(reordered_root, repetitions = 1:2)
  for (path in list.files(reordered_root, pattern = "[.]csv$",
                          full.names = TRUE)) {
    frame = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    write.csv(frame[rev(seq_len(nrow(frame))), , drop = FALSE],
              path, row.names = FALSE)
  }
  for (extension in c("csv", "rds")) {
    paths = list.files(reordered_root, pattern = paste0("[.]", extension, "$"),
                       full.names = TRUE)
    temporary = file.path(reordered_root, paste0("temporary-", extension))
    dir.create(temporary)
    file.rename(paths, file.path(temporary, basename(paths)))
    shuffled = file.path(reordered_root, paste0("shuffled-", seq_along(paths),
                                                 ".", extension))
    file.rename(list.files(temporary, full.names = TRUE), shuffled)
    unlink(temporary, recursive = TRUE, force = TRUE)
  }
  baseline_output = tempfile("GEModelR-order-baseline-", fileext = ".csv")
  reordered_output = tempfile("GEModelR-order-reordered-", fileext = ".csv")
  baseline_result = benchmark_gate_task2_cli(
    baseline_root, output = baseline_output
  )
  reordered_result = benchmark_gate_task2_cli(
    reordered_root, output = reordered_output
  )
  expect_equal(baseline_result$status, 0L)
  expect_equal(reordered_result$status, 0L)
  expect_equal(read.csv(baseline_output), read.csv(reordered_output))

  for (difference in c(0, 0.5, 0.75)) {
    root = tempfile("GEModelR-benchmark-boundary-")
    dir.create(root)
    on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
    benchmark_gate_task2_fixture(root)
    candidate = benchmark_gate_task2_case_solution(root)
    value = readRDS(candidate)
    value$solution[[1L]] = 1 + difference
    saveRDS(value, candidate, version = 3L)
    result = benchmark_gate_task2_cli(
      root, maximum_difference = "0.5",
      output = tempfile("GEModelR-boundary-summary-", fileext = ".csv")
    )
    if (difference <= 0.5) {
      expect_equal(result$status, 0L, info = paste("difference", difference))
    } else {
      expect_false(identical(result$status, 0L),
                   info = paste("difference", difference))
    }
  }

  duplicate_root = tempfile("GEModelR-benchmark-duplicate-key-")
  dir.create(duplicate_root)
  on.exit(unlink(duplicate_root, recursive = TRUE, force = TRUE), add = TRUE)
  benchmark_gate_task2_fixture(duplicate_root)
  benchmark_gate_task2_write_csv(
    file.path(duplicate_root, "duplicate-key.csv"), "ReferenceBackend",
    run_id = "different-reference-run", repetition = 1L
  )
  benchmark_gate_task2_write_solution(
    file.path(duplicate_root, "duplicate-key.rds"), "ReferenceBackend",
    run_id = "different-reference-run", repetition = 1L
  )
  duplicate_result = benchmark_gate_task2_cli(
    duplicate_root,
    output = tempfile("GEModelR-duplicate-summary-", fileext = ".csv")
  )
  expect_false(identical(duplicate_result$status, 0L))
})

test_that("benchmark correctness evidence preserves Phase 02 authority and mirrors", {
  source = benchmark_gate_task2_source_script()
  installed = testthat::test_path(
    "..", "..", "inst", "benchmarks", "check_benchmark_gate.R"
  )
  expect_identical(
    readBin(source, "raw", n = file.info(source)$size),
    readBin(installed, "raw", n = file.info(installed)$size)
  )
  tolerances = loadNumericalTolerances()
  strict = tolerances[
    tolerances$fixture == "three-region" &
      tolerances$conditioning == "ordinary", , drop = FALSE
  ]
  external = tolerances[
    tolerances$fixture == "full-gtap-external" &
      tolerances$conditioning == "ill-conditioned", , drop = FALSE
  ]
  expect_equal(strict$solution_rtol, 1e-8)
  expect_equal(external$solution_rtol, 2e-7)
  expect_equal(external$residual_rtol, 2e-7)
})
