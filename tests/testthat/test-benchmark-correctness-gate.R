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

benchmark_gate_test_install = function() {
  source_root = normalizePath(
    testthat::test_path("..", ".."), winslash = "/", mustWork = TRUE
  )
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
  source_script = testthat::test_path(
    "..", "..", "benchmarks", "check_benchmark_gate.R"
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
