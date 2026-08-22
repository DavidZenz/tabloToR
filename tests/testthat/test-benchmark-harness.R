benchmark_script_path <- function(name) {
  roots <- c(".", "..", file.path("..", ".."),
             file.path("..", "..", ".."))
  candidates <- unique(unlist(lapply(roots, function(root) c(
    file.path(root, "benchmarks", name),
    file.path(root, "00_pkg_src", "tabloToR", "benchmarks", name)
  ))))
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) stop(sprintf("Could not locate benchmark script %s", name))
  normalizePath(hit[[1L]], mustWork = TRUE)
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
    package_version = "0.1.0",
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
  output_dir <- tempfile("tabloToR panel sweep ")
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
  output_dir <- tempfile("tabloToR thread scaling ")
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
