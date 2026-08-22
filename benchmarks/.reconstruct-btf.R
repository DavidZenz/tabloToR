library(Matrix)
if (!requireNamespace("Rcpp", quietly = TRUE)) stop("Rcpp unavailable")

full = readRDS("/tmp/tabloToR-gtap-A.rds")
rhs = readRDS("/tmp/tabloToR-gtap-rhs.rds")
reduced = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
reduced_solution = readRDS(
  "/tmp/tabloToR-gtap-reduced-btf-solution.rds"
)
if (length(reduced_solution) != nrow(reduced$A)) {
  stop("reduced solution has the wrong length")
}

environment = new.env(parent = globalenv())
Rcpp::sourceCpp(
  file = "inst/cpp/sparse-elimination.cpp",
  env = environment,
  showOutput = FALSE
)
reconstruct = get("tabloToR_reconstruct_blocks", environment)
start = proc.time()[[3L]]
solution = reconstruct(
  full, as.numeric(rhs), as.numeric(reduced_solution),
  reduced$row_group, reduced$column_group,
  as.integer(reduced$n_groups), 1e-12
)
residual = as.numeric(full %*% solution - rhs)
residual_l2 = sqrt(sum(residual * residual))
rhs_l2 = sqrt(sum(as.numeric(rhs) * as.numeric(rhs)))
metrics = list(
  elapsed = proc.time()[[3L]] - start,
  relative_l2 = residual_l2 / max(1, rhs_l2),
  infinity_norm = max(abs(residual)),
  finite = all(is.finite(solution)),
  length = length(solution)
)
print(metrics)
saveRDS(solution, "/tmp/tabloToR-gtap-full-btf-solution.rds", compress = FALSE)
saveRDS(metrics, "/tmp/tabloToR-gtap-full-btf-metrics.rds")
