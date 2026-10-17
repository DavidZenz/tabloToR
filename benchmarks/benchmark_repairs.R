#!/usr/bin/env Rscript
# Run in separate processes, with identical REPAIR_LIBRARY/REPAIR_DEPENDENCIES
# inputs except for the before/after package. Outputs contain no licensed data.
.libPaths(c(Sys.getenv("REPAIR_LIBRARY"), Sys.getenv("REPAIR_DEPENDENCIES"),
            .libPaths()))
library(GEModelR)
library(Matrix)
options(GEModelR.sparse.schur_cpp_threads = 1L)
ns = asNamespace("GEModelR")
private = function(name) get(name, ns)
runtime = private(".sparse_schur_cpp_runtime")
prepared_available = exists("live_sparse_factors", runtime, inherits = FALSE)
output = Sys.getenv("REPAIR_OUTPUT", "repair-components.csv")
records = list()
measure = function(name, fun, calls, error = 0, retained = 0, setup = 0) {
  for (i in 1:3) invisible(fun())
  times = numeric(7L)
  for (i in seq_along(times)) {
    gc()
    started = proc.time()[[3L]]
    for (call in seq_len(calls)) invisible(fun())
    times[i] = (proc.time()[[3L]] - started) / calls
  }
  trace = tempfile()
  Rprofmem(trace)
  invisible(fun())
  Rprofmem(NULL)
  allocations = suppressWarnings(as.numeric(sub(" .*", "", readLines(trace))))
  unlink(trace)
  rss = NA_real_
  if (file.exists("/proc/self/status")) {
    status = readLines("/proc/self/status")
    rss = as.numeric(strsplit(trimws(status[startsWith(status, "VmHWM:")]),
                              "[[:space:]]+")[[1L]][2L]) * 1024
  }
  records[[length(records) + 1L]] <<- data.frame(
    workload = name, prepared_available = prepared_available,
    repetition = seq_along(times), elapsed_seconds = times,
    median_seconds = median(times), min_seconds = min(times), max_seconds = max(times),
    setup_seconds = setup, retained_bytes = retained,
    r_allocation_bytes = sum(allocations, na.rm = TRUE), process_peak_rss_bytes = rss,
    max_abs_difference = error, seed = 171017L, threads = 1L,
    r = R.version.string, Matrix = as.character(packageVersion("Matrix")),
    Rcpp = as.character(packageVersion("Rcpp")), platform = R.version$platform,
    blas = unname(extSoftVersion()["BLAS"]),
    cxx = paste(system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX17"),
                         stdout = TRUE), collapse = " ")
  )
}
set.seed(171017)
for (n in c(512L, 2469L)) {
  A = rsparsematrix(n, n, .02) + Diagonal(n, n)
  factor = lu(A, order = 3L)
  rhs = matrix(rnorm(n), n, 1L)
  started = proc.time()[[3L]]
  handle = if (prepared_available) private(".GEModelR_sparse_lu_solve")(factor, NULL) else
    factor
  setup = proc.time()[[3L]] - started
  native = function() private(".GEModelR_sparse_lu_solve")(handle, rhs)
  difference = max(abs(native() - as.matrix(solve(factor, rhs))))
  stopifnot(difference < 1e-10)
  measure(paste0("lu-", n, "-integrated"), native,
          if (n == 512L) 100L else 10L, difference, setup = setup)
  if (prepared_available) private(".GEModelR_sparse_lu_solve")(handle, NULL)
}
runtime$active = TRUE
runtime$state = private("sparse_make_state")(list())
runtime$index_key = "repair-components"
n = 64L + 8L * 128L + 4L
groups = c(rep(0L, 64L), rep(1:8, each = 128L), rep(9L, 4L))
A = rsparsematrix(n, n, .005) + Diagonal(n, 10)
system = private(".sparse_exact_schur_build_cpp")(
  A, groups, groups, 1L, 8L, 9L,
  row_scale = rep(1, n), column_scale = rep(1, n))
oracle = system
oracle$regional_transfers = NULL
value = rnorm(length(system$external_columns))
apply = private("sparse_exact_schur_apply_preconditioner")
difference = max(replicate(30L, {
  value = rnorm(length(system$external_columns))
  max(abs(apply(system, value) - apply(oracle, value)))
}))
stopifnot(difference < 1e-10)
measure("regional-preconditioner", function() apply(system, value), 40L, difference,
        if (is.null(system$regional_transfers)) 0 else
          as.numeric(object.size(system$regional_transfers)))
private(".sparse_cpp_release_live_factors")()
runtime$active = FALSE
runtime$state = NULL
write.csv(do.call(rbind, records), output, row.names = FALSE)
cat("Saved", normalizePath(output), "\n")
