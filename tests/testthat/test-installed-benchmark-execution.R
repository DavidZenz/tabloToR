benchmark_gap_process = function(command, arguments = character(),
                                  directory = NULL, environment = character()) {
  old = NULL
  if (!is.null(directory)) {
    old = setwd(directory)
    on.exit(setwd(old), add = TRUE)
  }
  output = suppressWarnings(system2(
    command, arguments, stdout = TRUE, stderr = TRUE, env = environment
  ))
  status = attr(output, "status")
  if (is.null(status)) status = 0L
  list(status = as.integer(status), output = as.character(output))
}

benchmark_gap_isolated_environment = function(library) {
  ambient = normalizePath(.libPaths(), winslash = "/", mustWork = TRUE)
  ambient = ambient[!vapply(ambient, function(path) {
    dir.exists(file.path(path, "GEModelR"))
  }, logical(1))]
  c(
    paste0("GEModelR_GAP_TEST_LIBRARY=", library),
    paste0("R_LIBS_USER=", library),
    paste0("R_LIBS_SITE=", paste(ambient, collapse = .Platform$path.sep)),
    "R_ENVIRON_USER=/dev/null",
    "R_PROFILE_USER=/dev/null"
  )
}

benchmark_gap_build_install = function() {
  source_root = normalizePath(
    testthat::test_path("..", ".."), winslash = "/", mustWork = TRUE
  )
  root = tempfile("GEModelR-installed-benchmark-")
  build_root = file.path(root, "build")
  library = file.path(root, "library")
  output_dir = file.path(root, "outputs")
  workdir = file.path(root, "unrelated-working-directory")
  dir.create(build_root, recursive = TRUE)
  dir.create(library)
  dir.create(output_dir)
  dir.create(workdir)

  build = benchmark_gap_process(
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
  install = benchmark_gap_process(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", paste0("--library=", shQuote(library)),
      shQuote(archives[[1L]])),
    directory = build_root
  )
  if (!identical(install$status, 0L)) {
    stop(paste(c("R CMD INSTALL failed:", install$output), collapse = "\n"),
         call. = FALSE)
  }
  installed_package = file.path(library, "GEModelR")
  if (!dir.exists(installed_package)) {
    stop("Isolated GEModelR installation is missing", call. = FALSE)
  }
  list(
    root = root,
    source_root = source_root,
    library = normalizePath(library, winslash = "/", mustWork = TRUE),
    installed_package = normalizePath(
      installed_package, winslash = "/", mustWork = TRUE
    ),
    output_dir = normalizePath(output_dir, winslash = "/", mustWork = TRUE),
    workdir = normalizePath(workdir, winslash = "/", mustWork = TRUE),
    environment = benchmark_gap_isolated_environment(library)
  )
}

benchmark_gap_script = function(state, name) {
  path = base::system.file(
    "benchmarks", name, package = "GEModelR", lib.loc = state$library
  )
  if (!nzchar(path) || !file.exists(path)) {
    stop(sprintf("Installed benchmark resource is missing: %s", name),
         call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

benchmark_gap_run_path = function(state, path, arguments) {
  benchmark_gap_process(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(path),
      vapply(arguments, shQuote, character(1))),
    directory = state$workdir,
    environment = state$environment
  )
}

benchmark_gap_run_script = function(state, name, arguments) {
  benchmark_gap_run_path(state, benchmark_gap_script(state, name), arguments)
}

benchmark_gap_hash_file = function(path) {
  unname(tools::md5sum(normalizePath(path, mustWork = TRUE))[[1L]])
}

benchmark_gap_three_region_files = function(root) {
  input = file.path(root, "input.rds")
  closure = file.path(root, "closure.rds")
  shocks = file.path(root, "shocks.rds")
  saveRDS(three_region_input_data(), input, version = 3L)
  saveRDS("tax", closure, version = 3L)
  saveRDS(setNames(
    c(1, 2, -1),
    c('tax["north"]', 'tax["south"]', 'tax["east"]')
  ), shocks, version = 3L)
  list(input = input, closure = closure, shocks = shocks)
}

benchmark_gap_metric = function(frame, name) {
  value = frame$value[frame$metric == name]
  if (length(value) != 1L) return(NA_character_)
  as.character(value[[1L]])
}

test_that("installed sweep executes the packaged child with RDS input", {
  state = benchmark_gap_build_install()
  on.exit(unlink(state$root, recursive = TRUE, force = TRUE), add = TRUE)
  inputs = benchmark_gap_three_region_files(state$root)
  tablo = file.path(state$source_root, "tests", "testthat", "fixtures", "three-region.tab")
  installed_sweep = benchmark_gap_script(state, "run_gtap12a_sweep.R")
  testthat::expect_true(startsWith(installed_sweep, file.path(state$library, "GEModelR")), info = installed_sweep)
  testthat::expect_identical(normalizePath(find.package("GEModelR", lib.loc = state$library), winslash = "/", mustWork = TRUE), state$installed_package)
  output = file.path(state$output_dir, "p64-b8-measured-01.csv")

  result = benchmark_gap_run_script(state, "run_gtap12a_sweep.R", c(
    paste0("--data-dir=", state$output_dir),
    paste0("--tablo=", tablo),
    paste0("--input-rds=", inputs$input),
    paste0("--closure-file=", inputs$closure),
    paste0("--shocks-file=", inputs$shocks),
    "--iter=1", "--steps=1", "--postsim=false", "--backend=Matrix",
    "--panel-sizes=64", "--batch-sizes=8", "--warmups=0",
    "--repetitions=1", paste0("--output-dir=", state$output_dir)
  ))
  testthat::expect_equal(
    result$status, 0L,
    info = paste(c("Installed sweep output:", result$output), collapse = "\n")
  )
  if (!identical(result$status, 0L)) return(invisible(NULL))

  testthat::expect_true(file.exists(output))
  summary_path = file.path(state$output_dir, "sweep-summary.csv")
  testthat::expect_true(file.exists(summary_path))
  frame = read.csv(output, stringsAsFactors = FALSE)
  summary = read.csv(summary_path, stringsAsFactors = FALSE)
  testthat::expect_identical(unique(frame$status), "completed")
  testthat::expect_identical(unique(frame$package_name), "GEModelR")
  testthat::expect_identical(unique(frame$option_prefix), "GEModelR.")
  testthat::expect_identical(
    unique(frame$native_routine_prefix), ".GEModelR_"
  )
  residual = suppressWarnings(as.numeric(
    benchmark_gap_metric(frame, "max_full_relative_residual")
  ))
  testthat::expect_true(is.finite(residual) && residual <= 2e-7)
  testthat::expect_identical(
    benchmark_gap_metric(frame, "solution_finite"), "TRUE"
  )
  testthat::expect_identical(
    benchmark_gap_metric(frame, "selected_outputs_finite"), "TRUE"
  )
  testthat::expect_identical(
    benchmark_gap_metric(frame, "dense_full_system_operations"), "FALSE"
  )
  testthat::expect_true(nrow(summary) == 1L && isTRUE(summary$all_finite[[1L]]))
  testthat::expect_true(is.finite(summary$max_full_relative_residual[[1L]]) &&
                        summary$max_full_relative_residual[[1L]] <= 2e-7)

  source_child = file.path(
    state$source_root, "benchmarks", "benchmark_gtap12a_run.R"
  )
  packaged_child = file.path(
    state$source_root, "inst", "benchmarks", "benchmark_gtap12a_run.R"
  )
  installed_child = benchmark_gap_script(
    state, "benchmark_gtap12a_run.R"
  )
  testthat::expect_true(file.exists(packaged_child))
  testthat::expect_identical(
    benchmark_gap_hash_file(source_child), benchmark_gap_hash_file(packaged_child)
  )
  testthat::expect_identical(
    benchmark_gap_hash_file(source_child), benchmark_gap_hash_file(installed_child)
  )
  testthat::expect_true(
    startsWith(installed_child, file.path(state$library, "GEModelR"))
  )

  invalid = file.path(state$root, "invalid-input.rds")
  saveRDS("not a loadData input list", invalid, version = 3L)
  invalid_result = benchmark_gap_run_script(
    state, "benchmark_gtap12a_run.R", c(
      paste0("--data-dir=", state$output_dir),
      paste0("--tablo=", tablo),
      paste0("--input-rds=", invalid),
      paste0("--closure-file=", inputs$closure),
      paste0("--output=", file.path(state$output_dir, "invalid.csv")),
      "--iter=1", "--steps=1", "--postsim=false", "--backend=Matrix"
    )
  )
  testthat::expect_false(identical(invalid_result$status, 0L))
})

test_that("installed scaling executes native child and fails closed", {
  state = benchmark_gap_build_install()
  on.exit(unlink(state$root, recursive = TRUE, force = TRUE), add = TRUE)
  inputs = benchmark_gap_three_region_files(state$root)
  tablo = file.path(
    state$source_root, "tests", "testthat", "fixtures", "three-region.tab"
  )
  scaling_output = file.path(state$output_dir, "scaling")
  scaling_args = c(
    paste0("--data-dir=", scaling_output),
    paste0("--tablo=", tablo),
    paste0("--input-rds=", inputs$input),
    paste0("--closure-file=", inputs$closure),
    paste0("--shocks-file=", inputs$shocks),
    "--threads=1", "--iter=1", "--steps=1", "--postsim=false",
    "--panel-size=64", "--region-batch-size=8", "--warmups=0",
    "--repetitions=1", paste0("--output-dir=", scaling_output)
  )
  result = benchmark_gap_run_script(
    state, "run_gtap12a_scaling.R", scaling_args
  )
  testthat::expect_equal(
    result$status, 0L,
    info = paste(c("Installed scaling output:", result$output), collapse = "\n")
  )
  if (!identical(result$status, 0L)) return(invisible(NULL))

  csv_path = file.path(scaling_output, "t1-measured-01.csv")
  solution_path = file.path(scaling_output, "t1-measured-01.rds")
  summary_path = file.path(scaling_output, "scaling-summary.csv")
  testthat::expect_true(file.exists(csv_path))
  testthat::expect_true(file.exists(solution_path))
  testthat::expect_true(file.exists(summary_path))

  frame = read.csv(csv_path, stringsAsFactors = FALSE)
  solution = readRDS(solution_path)
  summary = read.csv(summary_path, stringsAsFactors = FALSE)
  testthat::expect_identical(unique(frame$status), "completed")
  testthat::expect_identical(unique(frame$package_name), "GEModelR")
  testthat::expect_identical(unique(frame$option_prefix), "GEModelR.")
  testthat::expect_identical(
    unique(frame$native_routine_prefix), ".GEModelR_"
  )
  testthat::expect_identical(
    unique(frame$backend), "StructuredSchurFGMRESCpp"
  )
  testthat::expect_identical(as.integer(unique(frame$threads)), 1L)
  testthat::expect_true(
    any(frame$metric == "diagnostics.schur_build.native_schur_build_seconds")
  )
  testthat::expect_identical(solution$schema_version, 2L)
  testthat::expect_identical(solution$repetition, 1L)
  testthat::expect_identical(solution$warmup, FALSE)
  testthat::expect_identical(solution$run_id, unique(frame$run_id))
  testthat::expect_identical(
    solution$pair_signature, unique(frame$pair_signature)
  )
  testthat::expect_identical(
    solution$run_signature, unique(frame$run_signature)
  )
  testthat::expect_identical(
    solution$model_signature, unique(frame$model_signature)
  )
  testthat::expect_true(
    length(solution$solution) > 0L && all(is.finite(solution$solution))
  )
  testthat::expect_true(nrow(summary) == 1L)
  testthat::expect_true(
    is.finite(summary$max_abs_solution_difference[[1L]]) &&
      summary$max_abs_solution_difference[[1L]] == 0
  )

  invalid = file.path(state$root, "invalid-scaling-input.rds")
  saveRDS("not a loadData input list", invalid, version = 3L)
  invalid_output = file.path(state$output_dir, "invalid-scaling")
  invalid_result = benchmark_gap_run_script(
    state, "run_gtap12a_scaling.R", c(
      paste0("--data-dir=", invalid_output),
      paste0("--tablo=", tablo),
      paste0("--input-rds=", invalid),
      paste0("--closure-file=", inputs$closure),
      paste0("--shocks-file=", inputs$shocks),
      "--threads=1", "--iter=1", "--steps=1", "--postsim=false",
      "--panel-size=64", "--region-batch-size=8", "--warmups=0",
      "--repetitions=1", paste0("--output-dir=", invalid_output)
    )
  )
  testthat::expect_false(identical(invalid_result$status, 0L))

  resource_root = file.path(state$root, "resource-copies")
  dir.create(resource_root)
  config = benchmark_gap_script(state, "benchmark_config.R")
  scaling = benchmark_gap_script(state, "run_gtap12a_scaling.R")
  child = benchmark_gap_script(state, "benchmark_gtap12a_run.R")
  missing_child_root = file.path(resource_root, "missing-child")
  dir.create(missing_child_root)
  file.copy(c(config, scaling), missing_child_root)
  missing_child_result = benchmark_gap_run_path(
    state, file.path(missing_child_root, "run_gtap12a_scaling.R"), scaling_args
  )
  testthat::expect_false(identical(missing_child_result$status, 0L))

  missing_config_root = file.path(resource_root, "missing-config")
  dir.create(missing_config_root)
  file.copy(c(scaling, child), missing_config_root)
  missing_config_result = benchmark_gap_run_path(
    state, file.path(missing_config_root, "run_gtap12a_scaling.R"), scaling_args
  )
  testthat::expect_false(identical(missing_config_result$status, 0L))
})
