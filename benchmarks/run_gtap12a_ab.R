#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
output_dir <- benchmark_get_arg(args, "--output-dir")
if (is.null(output_dir)) stop("--output-dir is required", call. = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
reference <- benchmark_get_arg(args, "--reference", "StructuredSchurFGMRES")
candidate <- benchmark_get_arg(args, "--candidate", "StructuredSchurFGMRESCpp")
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 1L, 0L)
repetitions <- benchmark_integer(
  benchmark_get_arg(args, "--repetitions"), 3L, 1L
)
threads <- benchmark_integer(benchmark_get_arg(args, "--threads"), 1L, 1L)
required <- c("--data-dir", "--tablo", "--closure-file")
for (name in required) {
  if (is.null(benchmark_get_arg(args, name))) {
    stop(sprintf("%s is required", name), call. = FALSE)
  }
}
forward_names <- c(
  "--data-dir", "--tablo", "--closure-file", "--shocks-file",
  "--iter", "--steps", "--postsim", "--memory-budget",
  "--panel-size", "--region-batch-size"
)
forward <- character()
for (name in forward_names) {
  value <- benchmark_get_arg(args, name)
  if (!is.null(value)) forward <- c(forward, paste0(name, "=", value))
}
child <- file.path(script_dir, "benchmark_gtap12a_run.R")
run_child <- function(backend, repetition, warmup, order) {
  safe_backend <- gsub("[^[:alnum:]]", "-", backend)
  run_id <- sprintf("%s-%02d-%s", if (warmup) "warmup" else "measured",
                    repetition, safe_backend)
  output <- file.path(output_dir, paste0(run_id, ".csv"))
  solution <- file.path(output_dir, paste0(run_id, ".rds"))
  child_args <- c(
    child, forward,
    paste0("--backend=", backend),
    paste0("--threads=", if (identical(backend, candidate)) threads else 1L),
    paste0("--run-id=", run_id),
    paste0("--repetition=", repetition),
    paste0("--warmup=", tolower(warmup)),
    "--diagnostics=true",
    paste0("--output=", output),
    paste0("--solution-output=", solution)
  )
  log <- file.path(output_dir, paste0(run_id, ".log"))
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c("--vanilla", child_args), stdout = log, stderr = log)
  if (!identical(status, 0L)) {
    stop(sprintf("Benchmark child %s failed; see %s", run_id, log),
         call. = FALSE)
  }
}
for (id in seq_len(warmups)) {
  for (backend in c(reference, candidate)) run_child(backend, id, TRUE, 1L)
}
for (id in seq_len(repetitions)) {
  order <- if (id %% 2L) c(reference, candidate) else c(candidate, reference)
  for (backend in order) run_child(backend, id, FALSE, id)
}
gate_args <- c(
  file.path(script_dir, "check_benchmark_gate.R"),
  paste0("--input-dir=", output_dir),
  paste0("--reference=", reference), paste0("--candidate=", candidate),
  paste0("--minimum-speedup=", benchmark_get_arg(args, "--minimum-speedup", "0.20")),
  paste0("--maximum-rss-ratio=", benchmark_get_arg(args, "--maximum-rss-ratio", "1.10")),
  paste0("--maximum-residual=", benchmark_get_arg(args, "--maximum-residual", "2e-7")),
  paste0("--maximum-difference=", benchmark_get_arg(args, "--maximum-difference", "1e-6"))
)
status <- system2(file.path(R.home("bin"), "Rscript"),
                  c("--vanilla", gate_args))
if (!identical(status, 0L)) stop("A/B gate failed", call. = FALSE)
