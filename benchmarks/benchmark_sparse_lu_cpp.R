#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
warmups <- benchmark_integer(benchmark_get_arg(args, "--warmups"), 5L, 0L)
repetitions <- benchmark_integer(
  benchmark_get_arg(args, "--repetitions"), 30L, 1L
)
output <- benchmark_get_arg(args, "--output", tempfile(fileext = ".csv"))
native_solve <- getFromNamespace(".tabloToR_sparse_lu_solve", "tabloToR")
set.seed(191)
results <- list()
for (size in c(512L, 2469L)) {
  A <- Matrix::rsparsematrix(size, size, density = 0.02) +
    Matrix::Diagonal(size, size)
  factor <- Matrix::lu(A, order = 3L)
  for (width in c(1L, 64L, 256L, 512L)) {
    rhs <- matrix(rnorm(size * width), size, width)
    run <- function(fun) {
      for (id in seq_len(warmups)) invisible(fun(factor, rhs))
      times <- numeric(repetitions)
      answer <- NULL
      for (id in seq_len(repetitions)) {
        started <- proc.time()[[3L]]
        answer <- fun(factor, rhs)
        times[[id]] <- proc.time()[[3L]] - started
      }
      list(times = times, answer = answer)
    }
    reference <- run(function(factor, rhs) as.matrix(Matrix::solve(factor, rhs)))
    native <- run(native_solve)
    for (implementation in c("Matrix", "Cpp")) {
      value <- if (implementation == "Matrix") reference else native
      results[[length(results) + 1L]] <- data.frame(
        size = size, width = width, implementation = implementation,
        median_seconds = median(value$times),
        p90_seconds = unname(quantile(value$times, 0.9)),
        max_abs_difference = max(abs(native$answer - reference$answer)),
        relative_residual = sqrt(sum((A %*% value$answer - rhs)^2)) /
          max(1, sqrt(sum(rhs^2))), stringsAsFactors = FALSE
      )
    }
  }
}
result <- do.call(rbind, results)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(result, output, row.names = FALSE)
bad_accuracy <- any(result$max_abs_difference > 1e-10 |
                    result$relative_residual > 1e-10)
wide <- reshape(result, idvar = c("size", "width"), timevar = "implementation",
                direction = "wide")
speed <- wide$median_seconds.Cpp / wide$median_seconds.Matrix
target = wide$size == max(wide$size) &
  wide$width %in% c(64L, 256L)
bad_speed <- any(speed[target] > 0.85)
if (bad_accuracy || bad_speed) stop("Sparse LU benchmark gate failed", call. = FALSE)
