#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
threads <- as.integer(strsplit(
  benchmark_get_arg(args, "--threads", "1,2,4,8"), ",", fixed = TRUE
)[[1L]])
if (!length(threads) || anyNA(threads) || any(threads < 1L)) {
  stop("Thread counts must be positive integers", call. = FALSE)
}
output_dir <- benchmark_get_arg(args, "--output-dir")
if (is.null(output_dir)) stop("--output-dir is required", call. = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 1L, 0L)
repetitions <- benchmark_integer(benchmark_get_arg(args, "--repetitions"), 3L, 1L)
summarize_only <- benchmark_flag(args, "--summarize-only", FALSE)
resume <- benchmark_flag(args, "--resume", FALSE)
forward_names <- c("--data-dir", "--tablo", "--closure-file", "--shocks-file",
                   "--iter", "--steps", "--postsim", "--memory-budget",
                   "--panel-size", "--region-batch-size")
forward <- unlist(lapply(forward_names, function(name) {
  value <- benchmark_get_arg(args, name)
  if (is.null(value)) character() else paste0(name, "=", value)
}), use.names = FALSE)
child <- file.path(script_dir, "benchmark_gtap12a_run.R")
if (!summarize_only) {
for (thread in threads) for (id in seq_len(warmups + repetitions)) {
  warmup <- id <= warmups
  repetition <- if (warmup) id else id - warmups
  run_id <- sprintf("t%s-%s-%02d", thread,
                    if (warmup) "warmup" else "measured", repetition)
  output <- file.path(output_dir, paste0(run_id, ".csv"))
  solution <- file.path(output_dir, paste0(run_id, ".rds"))
  if (resume && file.exists(output) && file.exists(solution)) next
  child_args <- c(
    "--vanilla", child, forward,
    "--backend=StructuredSchurFGMRESCpp", paste0("--threads=", thread),
    paste0("--run-id=", run_id), paste0("--repetition=", repetition),
    paste0("--warmup=", tolower(warmup)), "--diagnostics=true",
    paste0("--output=", output), paste0("--solution-output=", solution)
  )
  status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(child_args))
  if (!identical(status, 0L)) stop(sprintf("Scaling child %s failed", run_id),
                                   call. = FALSE)
}
}
summary_path <- file.path(output_dir, "scaling-summary.csv")
files <- setdiff(
  list.files(output_dir, pattern = "\\.csv$", full.names = TRUE),
  summary_path
)
if (!length(files)) stop("No scaling CSV files found", call. = FALSE)
frame <- do.call(rbind, lapply(files, read.csv, stringsAsFactors = FALSE))
if (any(frame$status != "completed")) {
  stop("At least one scaling child failed", call. = FALSE)
}
if (length(unique(frame$pair_signature)) != 1L) {
  stop("Scaling pair signatures do not match", call. = FALSE)
}
frame <- frame[!as.logical(frame$warmup), ]
if (!all(threads %in% unique(frame$threads))) {
  stop("Scaling CSV files do not cover every requested thread count", call. = FALSE)
}
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
    ))),
    max_full_relative_residual = max(suppressWarnings(as.numeric(
      frame$value[take & frame$metric == "max_full_relative_residual"]
    )))
  )
}))
solution_files <- list.files(output_dir, pattern = "\\.rds$", full.names = TRUE)
solutions <- lapply(solution_files, readRDS)
solution_threads <- vapply(solutions, function(value) {
  if (!is.null(value$threads)) return(as.integer(value$threads))
  as.integer(sub("^t([0-9]+)-.*$", "\\1", value$run_id))
}, integer(1))
if (!all(threads %in% solution_threads)) {
  stop("Scaling solution files do not cover every requested thread count", call. = FALSE)
}
reference_positions <- which(solution_threads == 1L)
if (!length(reference_positions)) {
  stop("Scaling comparison requires a one-thread reference", call. = FALSE)
}
reference_solution <- solutions[[reference_positions[[1L]]]]
differences <- vapply(solutions, function(value) {
  if (!identical(value$pair_signature, reference_solution$pair_signature)) {
    stop("Scaling solution signatures do not match", call. = FALSE)
  }
  if (length(value$solution) != length(reference_solution$solution)) {
    stop("Scaling solution dimensions do not match", call. = FALSE)
  }
  max(abs(value$solution - reference_solution$solution))
}, numeric(1))
summary$max_abs_solution_difference <- vapply(threads, function(thread) {
  max(differences[solution_threads == thread])
}, numeric(1))
metric_true <- function(metric) {
  value <- frame$value[frame$metric == metric]
  length(value) && all(tolower(value) == "true")
}
metric_false <- function(metric) {
  value <- frame$value[frame$metric == metric]
  length(value) && all(tolower(value) == "false")
}
write.csv(summary, summary_path, row.names = FALSE)
one <- summary[summary$threads == 1L, ]
four <- summary[summary$threads == 4L, ]
scaling_failed <- nrow(one) && nrow(four) && (
  four$solve_seconds / one$solve_seconds > 0.90 ||
  four$schur_seconds / one$schur_seconds > 0.80 ||
  four$peak_rss_bytes / one$peak_rss_bytes > 1.10
)
if (!metric_true("solution_finite") ||
    !metric_true("selected_outputs_finite") ||
    !metric_false("dense_full_system_operations") ||
    any(!is.finite(summary$max_full_relative_residual)) ||
    any(summary$max_full_relative_residual > 2e-7) ||
    any(summary$max_abs_solution_difference > 1e-6) || scaling_failed) {
  stop("Thread scaling gate failed", call. = FALSE)
}
