#!/usr/bin/env Rscript

source(file.path(benchmark_script_dir <- local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE))
}), "benchmark_config.R"))

args <- commandArgs(trailingOnly = TRUE)
data_dir <- normalizePath(benchmark_get_arg(args, "--data-dir", "."),
                          mustWork = TRUE)
tablo_path <- normalizePath(
  benchmark_get_arg(args, "--tablo", file.path(data_dir, "gtapv7.tab")),
  mustWork = TRUE
)
closure_file <- benchmark_get_arg(args, "--closure-file")
shocks_file <- benchmark_get_arg(args, "--shocks-file")
if (is.null(closure_file) || !file.exists(closure_file)) {
  stop("--closure-file must identify a readable RDS", call. = FALSE)
}
closure_file <- normalizePath(closure_file, mustWork = TRUE)
if (!is.null(shocks_file)) shocks_file <- normalizePath(shocks_file, mustWork = TRUE)
backend <- benchmark_get_arg(args, "--backend", "StructuredSchurFGMRES")
threads <- benchmark_integer(benchmark_get_arg(args, "--threads"), 1L, 1L)
iter <- benchmark_integer(benchmark_get_arg(args, "--iter"), 3L, 1L)
steps <- as.integer(strsplit(
  benchmark_get_arg(args, "--steps", "1,3"), ",", fixed = TRUE
)[[1L]])
if (!length(steps) || anyNA(steps) || any(steps < 1L)) {
  stop("--steps must contain positive comma-separated integers", call. = FALSE)
}
postsim <- benchmark_flag(args, "--postsim", TRUE)
diagnostics <- benchmark_flag(args, "--diagnostics", TRUE)
warmup <- benchmark_flag(args, "--warmup", FALSE)
repetition <- benchmark_integer(benchmark_get_arg(args, "--repetition"), 1L, 1L)
run_id <- benchmark_get_arg(args, "--run-id", sprintf("run-%s", Sys.getpid()))
output <- benchmark_get_arg(args, "--output", file.path(data_dir, paste0(run_id, ".csv")))
solution_output <- benchmark_get_arg(args, "--solution-output")
panel_size <- benchmark_integer(
  benchmark_get_arg(args, "--panel-size"), 64L, 1L
)
batch_size <- benchmark_integer(
  benchmark_get_arg(args, "--region-batch-size"), 8L, 1L
)
memory_budget <- suppressWarnings(as.numeric(
  benchmark_get_arg(args, "--memory-budget", NA_character_)
))
if (!is.finite(memory_budget)) memory_budget <- NULL
closure <- readRDS(closure_file)
shocks <- if (is.null(shocks_file)) NULL else readRDS(shocks_file)

find_input <- function(candidates, label) {
  paths <- file.path(data_dir, candidates)
  hit <- paths[file.exists(paths)]
  if (!length(hit)) stop(sprintf("Could not find %s under %s", label, data_dir),
                         call. = FALSE)
  normalizePath(hit[[1L]], mustWork = TRUE)
}
sets_path <- find_input(c("sets.har", "gsdgset.har"), "GTAP sets")
data_path <- find_input(c("basedata.har", "gsdgdat.har"), "GTAP data")
parameter_path <- find_input(c("default.prm", "gsdgpar.har"), "GTAP parameters")
model_config <- list(
  tablo = benchmark_hash_file(tablo_path),
  sets = benchmark_hash_file(sets_path),
  data = benchmark_hash_file(data_path),
  parameters = benchmark_hash_file(parameter_path),
  closure_file = benchmark_hash_file(closure_file),
  closure = benchmark_hash_object(sort(as.character(closure))),
  shocks_file = benchmark_hash_file(shocks_file),
  shocks = benchmark_hash_object(shocks),
  package_version = as.character(utils::packageVersion("tabloToR")),
  r_version = R.version.string,
  matrix_version = as.character(utils::packageVersion("Matrix")),
  rcpp_version = as.character(utils::packageVersion("Rcpp")),
  iter = iter, steps = steps, postsim = postsim,
  platform = R.version$platform, cpu = benchmark_cpu(),
  ram = benchmark_physical_ram(), blas = benchmark_blas()
)
model_signature <- benchmark_signature(model_config)
pair_config <- c(model_config, list(
  panel_size = panel_size, region_batch_size = batch_size,
  memory_budget = memory_budget
))
pair_signature <- benchmark_signature(pair_config)
run_signature <- benchmark_signature(c(
  pair_config, list(backend = backend, threads = threads)
))
metadata <- list(
  schema_version = 3L, run_id = run_id, repetition = repetition,
  warmup = warmup, timestamp_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  run_signature = run_signature, pair_signature = pair_signature,
  model_signature = model_signature,
  git_commit = tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[1L],
                        error = function(error) NA_character_),
  package_version = pair_config$package_version,
  r_version = R.version$major, matrix_version = pair_config$matrix_version,
  platform = R.version$platform, backend = backend, threads = threads,
  iter = iter, steps = paste(steps, collapse = ","), postsim = postsim,
  status = "failed", error = ""
)
metrics <- list(
  physical_ram_bytes = benchmark_physical_ram(),
  peak_rss_bytes = NA_real_
)
failure <- NULL
started <- proc.time()[[3L]]
tryCatch({
  if (!requireNamespace("HARr", quietly = TRUE)) {
    stop("HARr is required for GTAP benchmarks", call. = FALSE)
  }
  options(
    tabloToR.sparse.schur_panel_size = panel_size,
    tabloToR.sparse.schur_region_batch_size = batch_size,
    tabloToR.sparse.schur_cpp_threads = threads
  )
  read_started <- proc.time()[[3L]]
  inputs <- list(
    gtapsets = HARr::read_har(sets_path),
    gtapdata = HARr::read_har(data_path),
    gtapparm = HARr::read_har(parameter_path)
  )
  metrics$read_seconds <- proc.time()[[3L]] - read_started
  model <- tabloToR::GEModel$new()
  load_tablo_started <- proc.time()[[3L]]
  model$loadTablo(tablo_path)
  metrics$load_tablo_seconds <- proc.time()[[3L]] - load_tablo_started
  model$setClosure(closure)
  model$setMemoryBudget(memory_budget)
  load_data_started <- proc.time()[[3L]]
  model$loadData(inputs, engine = "sparse")
  metrics$load_data_seconds <- proc.time()[[3L]] - load_data_started
  if (!is.null(shocks)) model$setShocks(shocks)
  solve_started <- proc.time()[[3L]]
  model$solveModel(
    iter = iter, steps = steps, engine = "sparse", postsim = postsim,
    diagnostics = diagnostics, output = "compact", backend = backend,
    reduction = "auto", memory_budget = memory_budget
  )
  metrics$solve_seconds <- proc.time()[[3L]] - solve_started
  metrics$max_full_relative_residual <-
    model$lastDiagnostics$max_full_relative_residual
  metrics$solution_finite <- all(is.finite(model$solution))
  metrics$selected_outputs_finite <- all(vapply(
    model$compactOutput, function(value) all(is.finite(value)), logical(1)
  ))
  metrics$dense_full_system_operations <- isTRUE(
    model$lastDiagnostics$solver_diagnostics$reduced_diagnostics$
      dense_full_system_operations
  )
  metrics <- c(metrics, benchmark_flatten(model$lastDiagnostics, "diagnostics"))
  if (!is.null(solution_output)) {
    dir.create(dirname(solution_output), recursive = TRUE, showWarnings = FALSE)
    saveRDS(list(
      schema_version = 2L, run_id = run_id,
      pair_signature = pair_signature, run_signature = run_signature,
      model_signature = model_signature,
      backend = backend, threads = threads, solution = unname(model$solution),
      selected_outputs = model$compactOutput
    ), solution_output, version = 3L)
  }
  metadata$status <- "completed"
}, error = function(error) {
  failure <<- conditionMessage(error)
  metadata$error <<- failure
})
metrics$total_seconds <- proc.time()[[3L]] - started
metrics$peak_rss_bytes <- benchmark_peak_rss()
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(benchmark_metric_frame(metadata, metrics), output,
          row.names = FALSE, na = "")
if (!is.null(failure)) stop(failure, call. = FALSE)
