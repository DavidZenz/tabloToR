gtap12a_preflight_source = function() {
  testthat::skip_if_not(
    file.exists(testthat::test_path("..", "..", "DESCRIPTION")) &&
      dir.exists(testthat::test_path("..", "..", "R")),
    "Reference preflight tool tests require the package source tree"
  )
  path = testthat::test_path("..", "..", "benchmarks",
                             "preflight_gtap12a_reference.R")
  environment = new.env(parent = globalenv())
  sys.source(path, envir = environment)
  environment
}

gtap12a_preflight_fixture = function(preflight) {
  skip_if_not_installed("GEModelR")
  package_root = system.file(package = "GEModelR")
  skip_if(!nzchar(package_root) || !dir.exists(package_root),
         "The installed GEModelR package is required for identity fixtures")

  root = tempfile("GEModelR-reference-preflight-")
  reference_dir = file.path(root, "reference")
  data_dir = file.path(root, "data")
  dir.create(reference_dir, recursive = TRUE)
  dir.create(data_dir, recursive = TRUE)
  tablo = file.path(root, "fixture.tab")
  closure_file = file.path(root, "closure.rds")
  writeLines("synthetic model input", tablo)
  writeLines("synthetic sets", file.path(data_dir, "sets.har"))
  writeLines("synthetic data", file.path(data_dir, "basedata.har"))
  writeLines("synthetic parameters", file.path(data_dir, "default.prm"))
  saveRDS(c("x", "y"), closure_file, version = 3L)

  revision = paste(rep("b", 40L), collapse = "")

  config = preflight$preflight_model_config(
    data_dir = data_dir, tablo_path = tablo, closure_file = closure_file,
    shocks_file = NULL, iter = 3L, steps = c(1L, 3L), postsim = TRUE
  )
  model_signature = preflight$benchmark_signature(config)
  pair_config = c(config, list(
    panel_size = 64L, region_batch_size = 8L, memory_budget = NULL
  ))
  pair_signature = preflight$benchmark_signature(pair_config)
  reference_backend = "StructuredSchurFGMRES"
  candidate_backend = "StructuredSchurFGMRESCpp"
  reference_threads = 1L
  candidate_threads = 4L
  reference_run_signature = preflight$benchmark_signature(c(
    pair_config,
    list(backend = reference_backend, threads = reference_threads)
  ))
  candidate_run_signature = preflight$benchmark_signature(c(
    pair_config,
    list(backend = candidate_backend, threads = candidate_threads)
  ))
  installed_signature = preflight$benchmark_hash_tree(package_root)
  package_version = as.character(utils::packageVersion("GEModelR"))
  current_commit = revision
  common_record = list(
    schema_version = "1",
    package_name = "GEModelR",
    package_version = package_version,
    source_commit = current_commit,
    source_archive_sha256 = paste(rep("a", 64L), collapse = ""),
    installed_package_signature = installed_signature,
    compiler_identity = "synthetic compiler 1.0 (recorded at build)",
    compiler_flags = "synthetic recorded flags",
    r_version = R.version.string,
    matrix_version = as.character(utils::packageVersion("Matrix")),
    rcpp_version = as.character(utils::packageVersion("Rcpp")),
    blas = preflight$benchmark_blas(),
    platform = R.version$platform,
    cpu = preflight$benchmark_cpu(),
    ram_bytes = format(preflight$benchmark_physical_ram(), scientific = FALSE),
    model_signature = model_signature,
    pair_signature = pair_signature,
    iter = "3",
    steps = "1,3",
    postsim = "true",
    panel_size = "64",
    region_batch_size = "8",
    memory_budget = "none"
  )
  reference_record = common_record
  reference_record$backend = reference_backend
  reference_record$threads = as.character(reference_threads)
  reference_record$run_signature = reference_run_signature
  candidate_record = common_record
  candidate_record$backend = candidate_backend
  candidate_record$threads = as.character(candidate_threads)
  candidate_record$run_signature = candidate_run_signature
  reference_build_record = file.path(root, "reference-build.dcf")
  candidate_build_record = file.path(root, "candidate-build.dcf")
  write.dcf(as.data.frame(as.list(reference_record),
                          stringsAsFactors = FALSE), reference_build_record)
  write.dcf(as.data.frame(as.list(candidate_record),
                          stringsAsFactors = FALSE), candidate_build_record)

  metrics = data.frame(
    metric = c(
      "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
      "solution_finite", "selected_outputs_finite",
      "dense_full_system_operations"
    ),
    value = c("10", "1000", "1e-8", "TRUE", "TRUE", "FALSE"),
    unit = c("seconds", "bytes", "ratio", "value", "value", "value"),
    stringsAsFactors = FALSE
  )
  ids = c("warmup-01", "measured-01", "measured-02", "measured-03")
  for (index in seq_along(ids)) {
    warmup = index == 1L
    run_id = ids[[index]]
    metadata = data.frame(
      schema_version = 3L,
      run_id = run_id,
      repetition = if (warmup) 1L else index - 1L,
      warmup = warmup,
      timestamp_utc = "2026-10-21 00:00:00 UTC",
      run_signature = reference_run_signature,
      pair_signature = pair_signature,
      model_signature = model_signature,
      git_commit = current_commit,
      package_name = "GEModelR",
      package_version = package_version,
      installed_package_signature = installed_signature,
      option_prefix = "GEModelR.",
      native_routine_prefix = ".GEModelR_",
      r_version = R.version$major,
      matrix_version = common_record$matrix_version,
      rcpp_version = common_record$rcpp_version,
      platform = R.version$platform,
      backend = reference_backend,
      threads = reference_threads,
      iter = 3L,
      steps = "1,3",
      postsim = TRUE,
      status = "completed",
      error = "",
      stringsAsFactors = FALSE
    )
    csv = file.path(reference_dir, paste0(run_id, ".csv"))
    write.csv(cbind(metadata[rep(1L, nrow(metrics)), , drop = FALSE], metrics),
              csv, row.names = FALSE, na = "")
    solution = file.path(reference_dir, paste0(run_id, ".rds"))
    saveRDS(list(
      schema_version = 2L,
      run_id = run_id,
      pair_signature = pair_signature,
      run_signature = reference_run_signature,
      model_signature = model_signature,
      backend = reference_backend,
      threads = reference_threads,
      repetition = if (warmup) 1L else index - 1L,
      warmup = warmup,
      solution = c(x = 1, y = 2),
      selected_outputs = list(total = c(3, 4))
    ), solution, version = 3L)
  }

  list(
    root = root,
    reference_dir = reference_dir,
    data_dir = data_dir,
    tablo = tablo,
    closure_file = closure_file,
    reference_build_record = reference_build_record,
    candidate_build_record = candidate_build_record,
    options = list(
      reference_dir = reference_dir,
      data_dir = data_dir,
      tablo = tablo,
      closure_file = closure_file,
      reference_build_record = reference_build_record,
      candidate_build_record = candidate_build_record
    )
  )
}
