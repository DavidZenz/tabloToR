benchmark_driver_names <- function() {
  c(
    "benchmark_config.R", "run_gtap12a_sweep.R",
    "run_gtap12a_scaling.R", "check_benchmark_gate.R"
  )
}

benchmark_source_script_path <- function(name) {
  roots <- c(".", "..", file.path("..", ".."),
             file.path("..", "..", ".."))
  candidates <- unique(unlist(lapply(roots, function(root) c(
    file.path(root, "benchmarks", name),
    file.path(root, "00_pkg_src", "GEModelR", "benchmarks", name)
  ))))
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) return("")
  normalizePath(hit[[1L]], mustWork = TRUE)
}

benchmark_script_path <- function(
    name,
    installed = system.file("benchmarks", name, package = "GEModelR"),
    source = benchmark_source_script_path(name)) {
  candidates <- c(installed, source)
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) {
    stop(sprintf("Could not locate benchmark script %s", name))
  }
  normalizePath(candidates[[1L]], mustWork = TRUE)
}

benchmark_file_bytes <- function(path) {
  size <- file.info(path)$size
  readBin(path, "raw", n = size)
}

benchmark_fixture_frame <- function(run_id, threads, pair_signature,
                                    model_signature = "model-fixture",
                                    solve_seconds = 10,
                                    schur_seconds = 8,
                                    peak_rss_bytes = 100) {
  metrics <- c(
    solve_seconds = solve_seconds,
    peak_rss_bytes = peak_rss_bytes,
    max_full_relative_residual = 1e-10,
    solution_finite = "TRUE",
    selected_outputs_finite = "TRUE",
    dense_full_system_operations = "FALSE",
    diagnostics.schur_build.native_schur_build_seconds = schur_seconds
  )
  data.frame(
    schema_version = 3L,
    run_id = run_id,
    repetition = 1L,
    warmup = FALSE,
    timestamp_utc = "2026-08-22 00:00:00 UTC",
    run_signature = paste0("run-", run_id),
    pair_signature = pair_signature,
    model_signature = model_signature,
    git_commit = "fixture",
    package_name = "GEModelR",
    package_version = "0.1.0",
    option_prefix = "GEModelR.",
    native_routine_prefix = ".GEModelR_",
    r_version = "4",
    matrix_version = "1.6.3",
    platform = R.version$platform,
    backend = "StructuredSchurFGMRESCpp",
    threads = threads,
    iter = 1L,
    steps = "1",
    postsim = TRUE,
    status = "completed",
    error = "",
    metric = names(metrics),
    value = unname(metrics),
    unit = "value",
    stringsAsFactors = FALSE
  )
}

test_that("benchmark driver lookup is installed-first with source fallback", {
  name <- "run_gtap12a_sweep.R"
  source <- benchmark_source_script_path(name)
  expect_true(nzchar(source))

  installed <- tempfile("GEModelR-installed-benchmark-")
  writeLines("installed", installed)
  on.exit(unlink(installed), add = TRUE)

  expect_identical(
    benchmark_script_path(name, installed = installed, source = source),
    normalizePath(installed, mustWork = TRUE)
  )
  expect_identical(
    benchmark_script_path(name, installed = "", source = source),
    source
  )
  locator <- paste(deparse(benchmark_script_path), collapse = "\n")
  expect_match(locator, 'system.file("benchmarks", name, package = "GEModelR")',
               fixed = TRUE)

  installed_resource <- system.file("benchmarks", name, package = "GEModelR")
  if (nzchar(installed_resource)) {
    expect_identical(
      benchmark_script_path(name),
      normalizePath(installed_resource, mustWork = TRUE)
    )
  } else {
    expect_identical(benchmark_script_path(name), source)
  }
})

test_that("packaged benchmark drivers are exact source mirrors", {
  for (name in benchmark_driver_names()) {
    source <- benchmark_source_script_path(name)
    packaged <- testthat::test_path("..", "..", "inst", "benchmarks", name)
    installed <- system.file("benchmarks", name, package = "GEModelR")

    if (nzchar(source) && file.exists(packaged)) {
      expect_identical(
        benchmark_file_bytes(packaged), benchmark_file_bytes(source),
        info = paste(name, "source parity")
      )
    }
    if (nzchar(installed)) {
      expect_true(file.exists(installed), info = paste(name, "installed"))
      if (nzchar(source)) {
        expect_identical(
          benchmark_file_bytes(installed), benchmark_file_bytes(source),
          info = paste(name, "installed parity")
        )
      }
    }
    expect_true(
      (nzchar(source) && file.exists(packaged)) || nzchar(installed),
      info = name
    )
  }
})

test_that("active benchmark producers use exact GEModelR identity", {
  expected <- list(
    benchmark_config.R = c(
      "GEModelR-benchmark-hash-", "GEModelR-benchmark-signature-"
    ),
    benchmark_gtap12a.R = c(
      'requireNamespace("GEModelR"', "GEModelR::GEModel$new()"
    ),
    benchmark_gtap12a_run.R = c(
      'package_name = "GEModelR"', 'packageVersion("GEModelR")',
      'system.file(package = "GEModelR")',
      "GEModelR.sparse.schur_panel_size", "GEModelR::GEModel$new()"
    ),
    benchmark_schur_cpp.R = c(
      'getFromNamespace(".sparse_schur_cpp_runtime", "GEModelR")'
    ),
    benchmark_sparse_lu_cpp.R = c(
      'getFromNamespace(".GEModelR_sparse_lu_solve", "GEModelR")'
    )
  )
  for (name in names(expected)) {
    path <- benchmark_source_script_path(name)
    expect_true(nzchar(path), info = name)
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_false(grepl("tabloToR", text, fixed = TRUE), info = name)
    for (literal in expected[[name]]) {
      expect_true(grepl(literal, text, fixed = TRUE),
                  info = paste(name, literal))
    }
  }
})

test_that("benchmark metadata rows carry current identity fields", {
  frame <- benchmark_fixture_frame("identity", 1L, "pair")
  expect_identical(unique(frame$package_name), "GEModelR")
  expect_identical(unique(frame$option_prefix), "GEModelR.")
  expect_identical(unique(frame$native_routine_prefix), ".GEModelR_")
})

run_benchmark_summary <- function(script, args) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    shQuote(c("--vanilla", benchmark_script_path(script), args)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  if (is.null(status)) 0L else as.integer(status)
}

test_that("panel sweep summary validates correctness across tuning signatures", {
  output_dir <- tempfile("GEModelR panel sweep ")
  dir.create(output_dir)
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  for (panel in c(64L, 256L, 512L, 1024L)) {
    run_id <- sprintf("p%s-b8-measured-01", panel)
    frame <- benchmark_fixture_frame(
      run_id, 4L, paste0("pair-", panel),
      solve_seconds = panel / 64, peak_rss_bytes = 100 + panel
    )
    write.csv(frame, file.path(output_dir, paste0(run_id, ".csv")),
              row.names = FALSE)
  }
  status <- run_benchmark_summary("run_gtap12a_sweep.R", c(
    paste0("--output-dir=", output_dir),
    "--panel-sizes=64,256,512,1024", "--batch-sizes=8",
    "--summarize-only=true"
  ))
  expect_equal(status, 0L)
  summary <- read.csv(file.path(output_dir, "sweep-summary.csv"))
  expect_setequal(summary$panel_size, c(64L, 256L, 512L, 1024L))
  expect_true(all(summary$all_finite))
  expect_false(any(summary$dense_full_system_operations))
  expect_true(all(summary$max_full_relative_residual <= 2e-7))
})

test_that("thread scaling summary enforces solution equivalence", {
  output_dir <- tempfile("GEModelR thread scaling ")
  dir.create(output_dir)
  on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
  timing <- data.frame(
    threads = c(1L, 2L, 4L, 8L),
    solve = c(10, 7, 5, 4.8),
    schur = c(8, 5, 3, 2.8),
    rss = c(100, 102, 105, 106)
  )
  for (id in seq_len(nrow(timing))) {
    thread <- timing$threads[[id]]
    run_id <- sprintf("t%s-measured-01", thread)
    frame <- benchmark_fixture_frame(
      run_id, thread, "pair-fixture",
      solve_seconds = timing$solve[[id]],
      schur_seconds = timing$schur[[id]],
      peak_rss_bytes = timing$rss[[id]]
    )
    write.csv(frame, file.path(output_dir, paste0(run_id, ".csv")),
              row.names = FALSE)
    saveRDS(list(
      schema_version = 2L, run_id = run_id,
      pair_signature = "pair-fixture",
      backend = "StructuredSchurFGMRESCpp", threads = thread,
      solution = c(1, 2, 3)
    ), file.path(output_dir, paste0(run_id, ".rds")))
  }
  args <- c(
    paste0("--output-dir=", output_dir), "--threads=1,2,4,8",
    "--summarize-only=true"
  )
  expect_equal(run_benchmark_summary("run_gtap12a_scaling.R", args), 0L)
  summary <- read.csv(file.path(output_dir, "scaling-summary.csv"))
  expect_equal(summary$max_abs_solution_difference, rep(0, 4))

  bad_path <- file.path(output_dir, "t8-measured-01.rds")
  bad <- readRDS(bad_path)
  bad$solution[[1L]] <- bad$solution[[1L]] + 1e-4
  saveRDS(bad, bad_path)
  expect_false(identical(
    run_benchmark_summary("run_gtap12a_scaling.R", args), 0L
  ))
})
