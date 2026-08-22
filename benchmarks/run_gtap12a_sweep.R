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
if (!length(panels) || anyNA(panels) || any(panels < 1L) ||
    !length(batches) || anyNA(batches) || any(batches < 1L)) {
  stop("Panel and batch sizes must be positive integers", call. = FALSE)
}
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 1L, 0L)
repetitions <- benchmark_integer(benchmark_get_arg(args, "--repetitions"), 3L, 1L)
backend <- benchmark_get_arg(args, "--backend", "StructuredSchurFGMRES")
summarize_only <- benchmark_flag(args, "--summarize-only", FALSE)
resume <- benchmark_flag(args, "--resume", FALSE)
forward_names <- c("--data-dir", "--tablo", "--closure-file", "--shocks-file",
                   "--iter", "--steps", "--postsim", "--memory-budget",
                   "--threads")
forward <- unlist(lapply(forward_names, function(name) {
  value <- benchmark_get_arg(args, name)
  if (is.null(value)) character() else paste0(name, "=", value)
}), use.names = FALSE)
child <- file.path(script_dir, "benchmark_gtap12a_run.R")
if (!summarize_only) {
for (panel in panels) for (batch in batches) {
  for (id in seq_len(warmups + repetitions)) {
    warmup <- id <= warmups
    repetition <- if (warmup) id else id - warmups
    run_id <- sprintf("p%s-b%s-%s-%02d", panel, batch,
                      if (warmup) "warmup" else "measured", repetition)
    output <- file.path(output_dir, paste0(run_id, ".csv"))
    if (resume && file.exists(output)) next
    child_args <- c(
      "--vanilla", child, forward, paste0("--backend=", backend),
      paste0("--panel-size=", panel), paste0("--region-batch-size=", batch),
      paste0("--run-id=", run_id), paste0("--repetition=", repetition),
      paste0("--warmup=", tolower(warmup)), "--diagnostics=true",
      paste0("--output=", output)
    )
    status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(child_args))
    if (!identical(status, 0L)) stop(sprintf("Sweep child %s failed", run_id),
                                     call. = FALSE)
  }
}
}
summary_path <- file.path(output_dir, "sweep-summary.csv")
files <- setdiff(
  list.files(output_dir, pattern = "\\.csv$", full.names = TRUE),
  summary_path
)
if (!length(files)) stop("No panel sweep CSV files found", call. = FALSE)
frame <- do.call(rbind, lapply(files, read.csv, stringsAsFactors = FALSE))
if (any(frame$status != "completed")) {
  stop("At least one panel sweep child failed", call. = FALSE)
}
if ("model_signature" %in% names(frame)) {
  signatures <- unique(frame$model_signature[nzchar(frame$model_signature)])
  if (length(signatures) != 1L) {
    stop("Panel sweep model signatures do not match", call. = FALSE)
  }
} else {
  identity_columns <- c("git_commit", "package_version", "r_version",
                        "matrix_version", "platform", "iter", "steps",
                        "postsim")
  mismatched <- vapply(frame[identity_columns], function(value) {
    length(unique(value)) != 1L
  }, logical(1))
  if (any(mismatched)) {
    stop("Legacy panel sweep metadata do not match", call. = FALSE)
  }
}
frame <- frame[!as.logical(frame$warmup), ]
config <- unique(frame[c("run_id", "backend", "threads")])
config$panel_size <- as.integer(sub("^p([0-9]+)-.*$", "\\1", config$run_id))
config$batch_size <- as.integer(sub("^p[0-9]+-b([0-9]+)-.*$", "\\1", config$run_id))
if (!all(panels %in% config$panel_size) || !all(batches %in% config$batch_size)) {
  stop("Sweep files do not cover every requested panel and batch size", call. = FALSE)
}
config$solve_seconds <- vapply(config$run_id, function(id) {
  benchmark_metric_value(frame[frame$run_id == id, ], "solve_seconds")
}, numeric(1))
config$peak_rss_bytes <- vapply(config$run_id, function(id) {
  benchmark_metric_value(frame[frame$run_id == id, ], "peak_rss_bytes")
}, numeric(1))
config$max_full_relative_residual <- vapply(config$run_id, function(id) {
  benchmark_metric_value(
    frame[frame$run_id == id, ], "max_full_relative_residual"
  )
}, numeric(1))
metric_flag <- function(id, metric) {
  value <- frame$value[frame$run_id == id & frame$metric == metric]
  length(value) == 1L && identical(tolower(value[[1L]]), "true")
}
config$solution_finite <- vapply(
  config$run_id, metric_flag, logical(1), metric = "solution_finite"
)
config$selected_outputs_finite <- vapply(
  config$run_id, metric_flag, logical(1), metric = "selected_outputs_finite"
)
config$dense_full_system_operations <- vapply(
  config$run_id, metric_flag, logical(1),
  metric = "dense_full_system_operations"
)
groups <- c("panel_size", "batch_size", "backend", "threads")
summary <- aggregate(
  config[c("solve_seconds", "peak_rss_bytes")], config[groups], median
)
residual <- aggregate(
  config["max_full_relative_residual"], config[groups], max
)
summary <- merge(summary, residual, by = groups, sort = TRUE)
summary$all_finite <- vapply(seq_len(nrow(summary)), function(id) {
  take <- config$panel_size == summary$panel_size[[id]] &
    config$batch_size == summary$batch_size[[id]] &
    config$backend == summary$backend[[id]] &
    config$threads == summary$threads[[id]]
  all(config$solution_finite[take] & config$selected_outputs_finite[take])
}, logical(1))
summary$dense_full_system_operations <- vapply(
  seq_len(nrow(summary)), function(id) {
    take <- config$panel_size == summary$panel_size[[id]] &
      config$batch_size == summary$batch_size[[id]] &
      config$backend == summary$backend[[id]] &
      config$threads == summary$threads[[id]]
    any(config$dense_full_system_operations[take])
  }, logical(1)
)
write.csv(summary, summary_path, row.names = FALSE)
if (any(!config$solution_finite) || any(!config$selected_outputs_finite) ||
    any(config$dense_full_system_operations) ||
    any(!is.finite(config$max_full_relative_residual)) ||
    any(config$max_full_relative_residual > 2e-7)) {
  stop("Panel sweep correctness gate failed", call. = FALSE)
}
