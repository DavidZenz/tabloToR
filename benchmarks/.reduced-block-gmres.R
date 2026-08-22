library(Matrix)
library(Rcpp)
old_path = Sys.getenv("PATH")
Sys.setenv(PATH = paste(unique(c("/usr/bin", "/bin",
                                strsplit(old_path, ":", fixed = TRUE)[[1L]])),
                        collapse = ":"))
source("benchmarks/.level-stats.R")
sourceCpp("benchmarks/.block-gmres.cpp")
first = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
commodity = fill_groups(
  active, c("comm", "reg"), levels$commodity$variables,
  levels$commodity$equations
)
activity = fill_groups(
  active, levels$activity$sets, levels$activity$variables,
  levels$activity$equations
)
endowment = fill_groups(
  active, levels$endowment$sets, levels$endowment$variables,
  levels$endowment$equations
)
region = fill_groups(
  active, levels$region$sets, levels$region$variables,
  levels$region$equations
)
full_row_group = rep.int(-1L, length(first$row_group))
full_column_group = rep.int(-1L, length(first$column_group))
take = commodity$row_group >= 0L
full_row_group[take] = commodity$row_group[take]
take = commodity$column_group >= 0L
full_column_group[take] = commodity$column_group[take]
take = activity$row_group >= 0L
full_row_group[take] = activity$row_group[take]
take = activity$column_group >= 0L
full_column_group[take] = activity$column_group[take]
take = endowment$row_group >= 0L
full_row_group[take] = endowment$row_group[take]
take = endowment$column_group >= 0L
full_column_group[take] = endowment$column_group[take]
comm_count = length(active$sets$comm$values)
take = region$row_group >= 0L
full_row_group[take] = region$row_group[take] * comm_count
take = region$column_group >= 0L
full_column_group[take] = region$column_group[take] * comm_count
global_equations = c("e_globalcgds", "e_pcgdswld", "e_pt", "e_qtm", "e_rorg")
global_variables = c("globalcgds", "pcgdswld", "pt", "qtm", "rorg")
global_rows = which(vapply(active$equations, function(e) {
  e$name %in% global_equations
}, logical(1)))
for (id in global_rows) {
  e = active$equations[[id]]
  full_row_group[seq.int(e$row_start, e$row_end)] = 0L
}
inverse = integer(active$endogenous_count)
inverse[active$column_order] = seq_along(active$column_order)
global_columns = which(vapply(active$variables, function(v) {
  !isTRUE(v$exogenous) && v$name %in% global_variables
}, logical(1)))
for (id in global_columns) {
  v = active$variables[[id]]
  positions = seq.int(v$endo_start, length.out = v$n)
  full_column_group[inverse[positions]] = 0L
}
keep_rows = which(first$row_group < 0L)
keep_columns = which(first$column_group < 0L)
row_group = as.integer(full_row_group[keep_rows])
column_group = as.integer(full_column_group[keep_columns])
n_groups = commodity$n_groups
if (any(row_group < 0L) || any(column_group < 0L)) {
  stop(sprintf("unassigned reduced rows=%s columns=%s",
              sum(row_group < 0L), sum(column_group < 0L)))
}
cat("reduced", nrow(first$A), "blocks", n_groups,
    "max size", max(tabulate(row_group + 1L, nbins = n_groups)), "\n")
result = solve_block_gmres(
  first$A, first$rhs, row_group, column_group, n_groups,
  restart = as.integer(Sys.getenv("REDUCED_RESTART", "20")),
  max_iterations = as.integer(Sys.getenv("REDUCED_MAX_ITER", "50")),
  tolerance = 1e-8, pivot_tolerance = 1e-10, diagonal_shift = 0,
  equilibration = 1L, smoothing = as.integer(Sys.getenv("REDUCED_SMOOTHING", "0")),
  sweep = as.integer(Sys.getenv("REDUCED_SWEEP", "0")),
  method = as.integer(Sys.getenv("REDUCED_METHOD", "0")), split_group = 0L
)
print(result[setdiff(names(result), c("solution", "singular_group_ids"))])
true_residual = first$A %*% result$solution - first$rhs
cat("true relative residual",
    sqrt(sum(true_residual * true_residual)) /
      max(1, sqrt(sum(first$rhs * first$rhs))), "\n")
saveRDS(result, "/tmp/tabloToR-gtap-reduced-block-gmres.rds", compress = FALSE)
