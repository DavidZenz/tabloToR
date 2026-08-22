#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 2L, 0L)
repetitions <- benchmark_integer(
  benchmark_get_arg(args, "--repetitions"), 15L, 1L
)
output <- benchmark_get_arg(args, "--output", tempfile(fileext = ".csv"))
set.seed(211)
local_count <- 4L
region_count <- 8L
local_size <- 96L
region_size <- 20L
global_size <- 4L
sizes <- c(rep(local_size, local_count), rep(region_size, region_count),
           global_size)
group <- rep.int(seq_along(sizes) - 1L, sizes)
n <- sum(sizes)
dense <- matrix(0, n, n)
starts <- cumsum(c(1L, head(sizes, -1L)))
for (id in seq_along(sizes)) {
  positions <- seq.int(starts[[id]], length.out = sizes[[id]])
  block <- matrix(rnorm(length(positions)^2, sd = 0.02),
                  length(positions), length(positions))
  diag(block) <- diag(block) + 5
  dense[positions, positions] <- block
}
local_positions <- which(group < local_count)
external_positions <- which(group >= local_count)
coupling <- matrix(rnorm(length(local_positions) * length(external_positions),
                         sd = 0.003),
                   length(local_positions), length(external_positions))
coupling[abs(coupling) < 0.004] <- 0
dense[local_positions, external_positions] <- coupling
dense[external_positions, local_positions] <- t(coupling) * 0.7
A <- Matrix::Matrix(dense, sparse = TRUE)
rhs <- rnorm(n)
runtime <- getFromNamespace(".sparse_schur_cpp_runtime", "tabloToR")
runtime$state <- getFromNamespace("sparse_make_state", "tabloToR")(list())
runtime$index_key <- "schur-microbenchmark"
on.exit({
  runtime$active <- FALSE
  runtime$state <- NULL
  runtime$index_key <- NULL
}, add = TRUE)
r_builder <- getFromNamespace(".sparse_exact_schur_build_reference", "tabloToR")
cpp_builder <- getFromNamespace(".sparse_exact_schur_build_cpp", "tabloToR")
release <- getFromNamespace(".sparse_cpp_release_live_factors", "tabloToR")
run <- function(implementation) {
  fun <- if (implementation == "R") r_builder else cpp_builder
  times <- numeric(warmups + repetitions)
  for (id in seq_along(times)) {
    runtime$active <- implementation == "Cpp"
    started <- proc.time()[[3L]]
    system <- fun(
      A, group, group, local_count, region_count,
      local_count + region_count, rhs = rhs,
      panel_size = 64L, region_batch_size = 4L
    )
    times[[id]] <- proc.time()[[3L]] - started
    if (implementation == "Cpp") release()
    rm(system)
    gc(verbose = FALSE)
  }
  measured <- if (warmups) times[-seq_len(warmups)] else times
  data.frame(
    implementation = implementation,
    median_seconds = median(measured),
    p90_seconds = unname(quantile(measured, 0.9)),
    peak_rss_bytes = benchmark_peak_rss(), stringsAsFactors = FALSE
  )
}
result <- rbind(run("R"), run("Cpp"))
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(result, output, row.names = FALSE)
ratio <- result$median_seconds[result$implementation == "Cpp"] /
  result$median_seconds[result$implementation == "R"]
rss_ratio <- result$peak_rss_bytes[result$implementation == "Cpp"] /
  result$peak_rss_bytes[result$implementation == "R"]
if (ratio > 0.80 || rss_ratio > 1.10) {
  stop("Fused Schur benchmark gate failed", call. = FALSE)
}
