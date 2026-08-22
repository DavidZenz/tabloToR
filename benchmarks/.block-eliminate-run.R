library(Matrix)
library(Rcpp)
old_path = Sys.getenv("PATH")
Sys.setenv(PATH = paste(unique(c("/usr/bin", "/bin",
                                strsplit(old_path, ":", fixed = TRUE)[[1L]])),
                        collapse = ":"))
source("benchmarks/.level-stats.R")
sourceCpp("benchmarks/.block-eliminate.cpp")

active = readRDS("/tmp/tabloToR-gtap-active.rds")
A = readRDS("/tmp/tabloToR-gtap-A.rds")
rhs = readRDS("/tmp/tabloToR-gtap-rhs.rds")

production = fill_groups(
  active, levels$production$sets, levels$production$variables,
  levels$production$equations
)
bilateral = fill_groups(
  active, levels$bilateral$sets, levels$bilateral$variables,
  levels$bilateral$equations
)
row_group = rep.int(-1L, active$equation_count)
column_group = rep.int(-1L, active$endogenous_count)
take = production$row_group >= 0L
row_group[take] = production$row_group[take]
take = production$column_group >= 0L
column_group[take] = production$column_group[take]
offset = production$n_groups
take = bilateral$row_group >= 0L
row_group[take] = bilateral$row_group[take] + offset
take = bilateral$column_group >= 0L
column_group[take] = bilateral$column_group[take] + offset
n_groups = production$n_groups + bilateral$n_groups
if (any(row_group < 0L) != any(column_group < 0L) ||
    sum(row_group < 0L) != sum(column_group < 0L)) {
  stop("elimination leaves non-square dimensions")
}
cat("eliminated groups", n_groups,
    "production", production$n_groups,
    "bilateral", bilateral$n_groups,
    "kept", sum(row_group < 0L), "\n")
result = eliminate_block_diagonal(
  A, rhs, row_group, column_group, n_groups,
  pivot_tolerance = as.numeric(Sys.getenv("BLOCK_PIVOT_TOL", "1e-12"))
)
print(result[setdiff(names(result), c("A", "rhs"))])
if (isTRUE(result$ok)) {
  saveRDS(list(A = result$A, rhs = result$rhs,
               row_group = row_group, column_group = column_group,
               n_groups = n_groups),
          "/tmp/tabloToR-gtap-reduced-pb.rds", compress = FALSE)
}
