library(Matrix)
if (!requireNamespace("Rcpp", quietly = TRUE)) stop("Rcpp unavailable")

read_rhs = function(artifact) {
  rhs = as.numeric(artifact$rhs)
  n = artifact$A@Dim[[1L]]
  if (length(rhs) == n) return(rhs)
  if (!is.null(artifact$row_group) &&
      length(rhs) == length(artifact$row_group)) {
    keep = which(artifact$row_group < 0L)
    if (length(keep) != n) stop("full RHS does not match retained rows")
    return(rhs[keep])
  }
  stop("saved RHS does not match matrix coordinates")
}

level1 = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
level2 = readRDS("/tmp/tabloToR-gtap-partial-endowment-only.rds")
level2_solution = readRDS(
  "/tmp/tabloToR-gtap-partial-endowment-btf-solution.rds"
)
if (length(level2_solution) != level2$A@Dim[[1L]]) {
  stop("second-level solution has the wrong length")
}
level1_rhs = read_rhs(level1)

environment = new.env(parent = globalenv())
Rcpp::sourceCpp(
  file = "inst/cpp/sparse-elimination.cpp",
  env = environment,
  showOutput = FALSE
)
reconstruct = get("tabloToR_reconstruct_blocks", environment)

start = proc.time()[[3L]]
level1_solution = reconstruct(
  level1$A, level1_rhs, as.numeric(level2_solution),
  level2$row_group, level2$column_group,
  as.integer(level2$n_groups), 1e-12
)
level1_residual = as.numeric(level1$A %*% level1_solution - level1_rhs)
level1_rhs_l2 = sqrt(sum(level1_rhs * level1_rhs))
level1_metrics = list(
  relative_l2 = sqrt(sum(level1_residual * level1_residual)) /
    max(1, level1_rhs_l2),
  infinity_norm = max(abs(level1_residual)),
  finite = all(is.finite(level1_solution)),
  length = length(level1_solution)
)
cat("level1", paste(names(level1_metrics), level1_metrics, sep = "="),
    "\n")
rm(level2, level2_solution, level1_residual)
gc()

full = readRDS("/tmp/tabloToR-gtap-A.rds")
full_rhs = as.numeric(readRDS("/tmp/tabloToR-gtap-rhs.rds"))
if (length(full_rhs) != full@Dim[[1L]]) stop("full RHS has the wrong length")
full_solution = reconstruct(
  full, full_rhs, as.numeric(level1_solution),
  level1$row_group, level1$column_group,
  as.integer(level1$n_groups), 1e-12
)
full_residual = as.numeric(full %*% full_solution - full_rhs)
full_rhs_l2 = sqrt(sum(full_rhs * full_rhs))
metrics = list(
  elapsed = proc.time()[[3L]] - start,
  relative_l2 = sqrt(sum(full_residual * full_residual)) /
    max(1, full_rhs_l2),
  infinity_norm = max(abs(full_residual)),
  finite = all(is.finite(full_solution)),
  length = length(full_solution),
  level1 = level1_metrics
)
print(metrics)
saveRDS(
  full_solution,
  "/tmp/tabloToR-gtap-full-two-level-solution.rds",
  compress = FALSE
)
saveRDS(metrics, "/tmp/tabloToR-gtap-full-two-level-metrics.rds")
