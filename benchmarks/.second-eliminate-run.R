library(Matrix)
library(Rcpp)
old_path = Sys.getenv("PATH")
Sys.setenv(PATH = paste(unique(c("/usr/bin", "/bin",
                                strsplit(old_path, ":", fixed = TRUE)[[1L]])),
                        collapse = ":"))
source("benchmarks/.level-stats.R")
sourceCpp("benchmarks/.block-eliminate.cpp")

first = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
activity = fill_groups(
  active, levels$activity$sets, levels$activity$variables,
  levels$activity$equations
)
endowment = fill_groups(
  active, levels$endowment$sets, levels$endowment$variables,
  levels$endowment$equations
)
full_row_group = rep.int(-1L, length(first$row_group))
full_column_group = rep.int(-1L, length(first$column_group))
take = activity$row_group >= 0L
full_row_group[take] = activity$row_group[take]
take = activity$column_group >= 0L
full_column_group[take] = activity$column_group[take]
take = endowment$row_group >= 0L
full_row_group[take] = endowment$row_group[take]
take = endowment$column_group >= 0L
full_column_group[take] = endowment$column_group[take]
keep_rows = which(first$row_group < 0L)
keep_columns = which(first$column_group < 0L)
row_group = as.integer(full_row_group[keep_rows])
column_group = as.integer(full_column_group[keep_columns])
cat("second-level groups", activity$n_groups,
    "kept", sum(row_group < 0L),
    "activity/endowment positions", sum(row_group >= 0L), "\n")
result = eliminate_block_diagonal(
  first$A, first$rhs, row_group, column_group, activity$n_groups,
  pivot_tolerance = as.numeric(Sys.getenv("BLOCK_PIVOT_TOL", "1e-12"))
)
print(result[setdiff(names(result), c("A", "rhs"))])
if (isTRUE(result$ok)) {
  saveRDS(list(A = result$A, rhs = result$rhs,
               row_group = row_group, column_group = column_group,
               n_groups = activity$n_groups),
          "/tmp/tabloToR-gtap-reduced-pabe.rds", compress = FALSE)
}
