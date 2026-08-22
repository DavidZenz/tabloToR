# Deterministic, proprietary-data-free smoke test and benchmark for R/sparseSchur.R.

sparse_schur_benchmark_load = function() {
  if (exists("sparse_schur_solve", mode = "function")) return(invisible(NULL))
  command_arguments = commandArgs(trailingOnly = FALSE)
  file_argument = grep("^--file=", command_arguments, value = TRUE)
  script_directory = if (length(file_argument)) {
    dirname(normalizePath(sub("^--file=", "", file_argument[[1L]])))
  } else {
    getwd()
  }
  candidates = c(
    file.path(getwd(), "R", "sparseSchur.R"),
    file.path(script_directory, "..", "R", "sparseSchur.R")
  )
  source_file = candidates[file.exists(candidates)][[1L]]
  source(source_file, local = .GlobalEnv)
  invisible(NULL)
}

sparse_schur_synthetic_system = function() {
  sparse_schur_benchmark_load()
  Matrix::sparseMatrix(
    i = c(1L, 2L, 3L, 4L, 5L, 6L,
           1L, 4L, 2L, 3L, 4L, 5L, 6L, 4L, 5L, 6L),
    j = c(1L, 2L, 3L, 4L, 5L, 6L,
           4L, 1L, 3L, 2L, 5L, 4L, 5L, 6L, 4L, 5L),
    x = c(4, 3, 2, 5, 4, 3,
          0.3, 0.2, 0.4, 0.1, 0.2, 0.3, 0.2, 0.1, 0.1, 0.4),
    dims = c(6L, 6L)
  )
}

run_sparse_schur_synthetic_test = function(verbose = TRUE) {
  sparse_schur_benchmark_load()
  A = sparse_schur_synthetic_system()
  row_group = as.integer(c(1L, 1L, 1L, 2L, 2L, 2L))
  column_group = row_group
  expected = c(1, -2, 0.5, 3, -1, 2)
  rhs = as.numeric(A %*% expected)
  result = sparse_schur_solve(
    A, rhs, row_group, column_group,
    restart = 4L, max_iterations = 20L, tolerance = 1e-11,
    true_residual_frequency = 1L
  )
  error = max(abs(result$solution - expected))
  residual = result$diagnostics$full_true_relative_residual
  ok = isTRUE(result$converged) && error < 1e-8 && residual < 1e-8
  if (isTRUE(verbose)) {
    cat(sprintf(
      paste0("synthetic Schur test: %s; separator=%d; factors=%d; ",
             "solution_error=%.3e; true_relative_residual=%.3e\n"),
      if (ok) "PASS" else "FAIL",
      result$diagnostics$separator_size,
      result$diagnostics$local_factor_count,
      error,
      residual
    ))
  }
  if (!ok) stop("synthetic sparse Schur test failed", call. = FALSE)
  list(
    ok = ok,
    result = result,
    solution_error = error,
    true_relative_residual = residual
  )
}

benchmark_sparse_schur_synthetic = function(repetitions = 3L) {
  sparse_schur_benchmark_load()
  repetitions = as.integer(repetitions)[1L]
  if (is.na(repetitions) || repetitions < 1L) {
    stop("repetitions must be positive", call. = FALSE)
  }
  A = sparse_schur_synthetic_system()
  row_group = as.integer(c(1L, 1L, 1L, 2L, 2L, 2L))
  expected = c(1, -2, 0.5, 3, -1, 2)
  rhs = as.numeric(A %*% expected)
  elapsed = numeric(repetitions)
  results = vector("list", repetitions)
  for (run in seq_len(repetitions)) {
    started = proc.time()[["elapsed"]]
    results[[run]] = sparse_schur_solve(
      A, rhs, row_group, row_group,
      restart = 4L, max_iterations = 20L, tolerance = 1e-11
    )
    elapsed[[run]] = proc.time()[["elapsed"]] - started
  }
  data.frame(
    run = seq_len(repetitions),
    elapsed_seconds = elapsed,
    converged = vapply(results, function(x) isTRUE(x$converged), logical(1)),
    separator_size = vapply(
      results, function(x) x$diagnostics$separator_size, integer(1)
    ),
    true_relative_residual = vapply(
      results,
      function(x) x$diagnostics$full_true_relative_residual,
      numeric(1)
    )
  )
}

if (identical(Sys.getenv("TABLOR_RUN_SPARSE_SCHUR_TEST"), "1")) {
  print(run_sparse_schur_synthetic_test())
  print(benchmark_sparse_schur_synthetic())
}

