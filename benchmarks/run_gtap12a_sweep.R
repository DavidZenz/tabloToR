#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
output_dir <- benchmark_get_arg(args, "--output-dir")
if (is.null(output_dir)) stop("--output-dir is required", call. = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
panels <- as.integer(strsplit(
  benchmark_get_arg(args, "--panel-sizes", "64,256,512,1024"), ",", fixed = TRUE
)[[1L]])
batches <- as.integer(strsplit(
  benchmark_get_arg(args, "--batch-sizes", "8"), ",", fixed = TRUE
)[[1L]])
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 1L, 0L)
repetitions <- benchmark_integer(benchmark_get_arg(args, "--repetitions"), 3L, 1L)
backend <- benchmark_get_arg(args, "--backend", "StructuredSchurFGMRES")
forward_names <- c("--data-dir", "--tablo", "--closure-file", "--shocks-file",
                   "--iter", "--steps", "--postsim", "--memory-budget")
forward <- unlist(lapply(forward_names, function(name) {
  value <- benchmark_get_arg(args, name)
  if (is.null(value)) character() else paste0(name, "=", value)
}), use.names = FALSE)
child <- file.path(script_dir, "benchmark_gtap12a_run.R")
for (panel in panels) for (batch in batches) {
  for (id in seq_len(warmups + repetitions)) {
    warmup <- id <= warmups
    repetition <- if (warmup) id else id - warmups
    run_id <- sprintf("p%s-b%s-%s-%02d", panel, batch,
                      if (warmup) "warmup" else "measured", repetition)
    output <- file.path(output_dir, paste0(run_id, ".csv"))
    child_args <- c(
      "--vanilla", child, forward, paste0("--backend=", backend),
      paste0("--panel-size=", panel), paste0("--region-batch-size=", batch),
      paste0("--run-id=", run_id), paste0("--repetition=", repetition),
      paste0("--warmup=", tolower(warmup)), "--diagnostics=true",
      paste0("--output=", output)
    )
    status <- system2(file.path(R.home("bin"), "Rscript"), child_args)
    if (!identical(status, 0L)) stop(sprintf("Sweep child %s failed", run_id),
                                     call. = FALSE)
  }
}
files <- list.files(output_dir, pattern = "\\.csv$", full.names = TRUE)
frame <- do.call(rbind, lapply(files, read.csv, stringsAsFactors = FALSE))
frame <- frame[!as.logical(frame$warmup), ]
config <- unique(frame[c("run_id", "backend")])
config$panel_size <- as.integer(sub("^p([0-9]+)-.*$", "\\1", config$run_id))
config$batch_size <- as.integer(sub("^p[0-9]+-b([0-9]+)-.*$", "\\1", config$run_id))
config$solve_seconds <- vapply(config$run_id, function(id) {
  benchmark_metric_value(frame[frame$run_id == id, ], "solve_seconds")
}, numeric(1))
config$peak_rss_bytes <- vapply(config$run_id, function(id) {
  benchmark_metric_value(frame[frame$run_id == id, ], "peak_rss_bytes")
}, numeric(1))
summary <- aggregate(cbind(solve_seconds, peak_rss_bytes) ~ panel_size + batch_size,
                     config, median)
write.csv(summary, file.path(output_dir, "sweep-summary.csv"), row.names = FALSE)
