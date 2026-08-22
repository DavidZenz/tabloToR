#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
threads <- as.integer(strsplit(
  benchmark_get_arg(args, "--threads", "1,2,4,8"), ",", fixed = TRUE
)[[1L]])
output_dir <- benchmark_get_arg(args, "--output-dir")
if (is.null(output_dir)) stop("--output-dir is required", call. = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 1L, 0L)
repetitions <- benchmark_integer(benchmark_get_arg(args, "--repetitions"), 3L, 1L)
forward_names <- c("--data-dir", "--tablo", "--closure-file", "--shocks-file",
                   "--iter", "--steps", "--postsim", "--memory-budget",
                   "--panel-size", "--region-batch-size")
forward <- unlist(lapply(forward_names, function(name) {
  value <- benchmark_get_arg(args, name)
  if (is.null(value)) character() else paste0(name, "=", value)
}), use.names = FALSE)
child <- file.path(script_dir, "benchmark_gtap12a_run.R")
for (thread in threads) for (id in seq_len(warmups + repetitions)) {
  warmup <- id <= warmups
  repetition <- if (warmup) id else id - warmups
  run_id <- sprintf("t%s-%s-%02d", thread,
                    if (warmup) "warmup" else "measured", repetition)
  output <- file.path(output_dir, paste0(run_id, ".csv"))
  solution <- file.path(output_dir, paste0(run_id, ".rds"))
  child_args <- c(
    "--vanilla", child, forward,
    "--backend=StructuredSchurFGMRESCpp", paste0("--threads=", thread),
    paste0("--run-id=", run_id), paste0("--repetition=", repetition),
    paste0("--warmup=", tolower(warmup)), "--diagnostics=true",
    paste0("--output=", output), paste0("--solution-output=", solution)
  )
  status <- system2(file.path(R.home("bin"), "Rscript"), child_args)
  if (!identical(status, 0L)) stop(sprintf("Scaling child %s failed", run_id),
                                   call. = FALSE)
}
files <- list.files(output_dir, pattern = "\\.csv$", full.names = TRUE)
frame <- do.call(rbind, lapply(files, read.csv, stringsAsFactors = FALSE))
frame <- frame[!as.logical(frame$warmup), ]
summary <- do.call(rbind, lapply(threads, function(thread) {
  take <- frame$threads == thread
  data.frame(
    threads = thread,
    solve_seconds = median(suppressWarnings(as.numeric(
      frame$value[take & frame$metric == "solve_seconds"]
    ))),
    schur_seconds = median(suppressWarnings(as.numeric(
      frame$value[take & frame$metric ==
        "diagnostics.schur_build.native_schur_build_seconds"]
    ))),
    peak_rss_bytes = median(suppressWarnings(as.numeric(
      frame$value[take & frame$metric == "peak_rss_bytes"]
    )))
  )
}))
write.csv(summary, file.path(output_dir, "scaling-summary.csv"), row.names = FALSE)
one <- summary[summary$threads == 1L, ]
four <- summary[summary$threads == 4L, ]
if (nrow(four) && (four$solve_seconds / one$solve_seconds > 0.90 ||
                   four$schur_seconds / one$schur_seconds > 0.80 ||
                   four$peak_rss_bytes / one$peak_rss_bytes > 1.10)) {
  stop("Four-thread scaling gate failed", call. = FALSE)
}
