library(Matrix)
library(Rcpp)
old_path = Sys.getenv("PATH")
Sys.setenv(PATH = paste(unique(c("/usr/bin", "/bin",
                                strsplit(old_path, ":", fixed = TRUE)[[1L]])),
                        collapse = ":"))
source("benchmarks/.level-stats.R")
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
keep_rows = which(first$row_group < 0L)
keep_columns = which(first$column_group < 0L)
row_group = as.integer(full_row_group[keep_rows])
column_group = as.integer(full_column_group[keep_columns])
cat("groups", commodity$n_groups, "kept", sum(row_group < 0L),
    "selected", sum(row_group >= 0L), "\n")
stats = block_schur_stats(first$A, row_group, column_group,
                          commodity$n_groups)
print(stats[c("b_nnz", "c_nnz", "d_nnz", "cross_l", "product_upper",
               "max_b_columns", "max_c_rows")])
