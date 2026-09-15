#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
input_dir <- normalizePath(benchmark_get_arg(args, "--input-dir"), mustWork = TRUE)
reference_name <- benchmark_get_arg(args, "--reference", "StructuredSchurFGMRES")
candidate_name <- benchmark_get_arg(args, "--candidate", "StructuredSchurFGMRESCpp")
minimum_speedup <- as.numeric(benchmark_get_arg(args, "--minimum-speedup", "0.20"))
maximum_rss_ratio <- as.numeric(benchmark_get_arg(args, "--maximum-rss-ratio", "1.10"))
maximum_residual <- as.numeric(benchmark_get_arg(args, "--maximum-residual", "2e-7"))
maximum_difference <- as.numeric(benchmark_get_arg(args, "--maximum-difference", "1e-6"))
output <- benchmark_get_arg(args, "--output", file.path(input_dir, "comparison.csv"))
files <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE)
files <- setdiff(files, output)
if (!length(files)) stop("No benchmark CSV files found", call. = FALSE)
frames <- lapply(files, read.csv, stringsAsFactors = FALSE)
frame <- do.call(rbind, frames)
if (any(frame$status != "completed")) {
  stop("At least one benchmark child failed", call. = FALSE)
}
if (length(unique(frame$pair_signature)) != 1L) {
  stop("Benchmark pair signatures do not match", call. = FALSE)
}
measured <- frame[!as.logical(frame$warmup), , drop = FALSE]
backend_metric <- function(backend, metric, fun = median) {
  values <- suppressWarnings(as.numeric(measured$value[
    measured$backend == backend & measured$metric == metric
  ]))
  values <- values[is.finite(values)]
  if (!length(values)) return(NA_real_)
  fun(values)
}
reference_time <- backend_metric(reference_name, "solve_seconds")
candidate_time <- backend_metric(candidate_name, "solve_seconds")
reference_rss <- backend_metric(reference_name, "peak_rss_bytes")
candidate_rss <- backend_metric(candidate_name, "peak_rss_bytes")
reference_residual <- backend_metric(
  reference_name, "max_full_relative_residual", max
)
candidate_residual <- backend_metric(
  candidate_name, "max_full_relative_residual", max
)
solution_files <- list.files(input_dir, pattern = "\\.rds$", full.names = TRUE)
solutions <- lapply(solution_files, readRDS)
reference_solutions <- Filter(
  function(value) identical(value$backend, reference_name), solutions
)
candidate_solutions <- Filter(
  function(value) identical(value$backend, candidate_name), solutions
)
differences <- numeric()
if (length(reference_solutions) && length(candidate_solutions)) {
  for (candidate in candidate_solutions) {
    reference <- reference_solutions[[min(
      length(reference_solutions), length(differences) + 1L
    )]]
    if (!identical(candidate$pair_signature, reference$pair_signature)) {
      stop("Solution artifacts have mismatched pair signatures", call. = FALSE)
    }
    if (length(candidate$solution) != length(reference$solution)) {
      stop("Solution artifacts have different dimensions", call. = FALSE)
    }
    differences <- c(differences, max(abs(
      candidate$solution - reference$solution
    )))
  }
}
maximum_solution_difference <- if (length(differences)) max(differences) else NA_real_
summary <- data.frame(
  metric = c(
    "reference_median_solve_seconds", "candidate_median_solve_seconds",
    "wall_time_ratio", "peak_rss_ratio",
    "reference_max_full_relative_residual",
    "candidate_max_full_relative_residual",
    "max_abs_solution_difference"
  ),
  value = c(
    reference_time, candidate_time, candidate_time / reference_time,
    candidate_rss / reference_rss, reference_residual, candidate_residual,
    maximum_solution_difference
  ), stringsAsFactors = FALSE
)
write.csv(summary, output, row.names = FALSE)
if (!is.finite(reference_time) || !is.finite(candidate_time) ||
    candidate_time / reference_time > 1 - minimum_speedup ||
    candidate_rss / reference_rss > maximum_rss_ratio ||
    candidate_residual > maximum_residual ||
    (!is.na(maximum_solution_difference) &&
       maximum_solution_difference > maximum_difference)) {
  stop("A/B benchmark gate failed", call. = FALSE)
}
