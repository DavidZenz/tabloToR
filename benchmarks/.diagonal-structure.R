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
take = activity$row_group >= 0L
full_row_group[take] = activity$row_group[take]
take = activity$column_group >= 0L
full_column_group[take] = activity$column_group[take]
take = endowment$row_group >= 0L
full_row_group[take] = endowment$row_group[take]
take = endowment$column_group >= 0L
full_column_group[take] = endowment$column_group[take]
comm_count = length(active$sets$comm$values)
reg_count = length(active$sets$reg$values)
diagonal = as.integer(
  rep(seq_len(reg_count) - 1L, each = comm_count) * comm_count +
  rep(seq_len(comm_count) - 1L, times = reg_count)
)
commodity_to_group = rep.int(-1L, commodity$n_groups)
commodity_to_group[diagonal + 1L] = seq_len(activity$n_groups) - 1L
take = commodity$row_group >= 0L
selected = commodity_to_group[commodity$row_group[take] + 1L] >= 0L
rows = which(take)[selected]
full_row_group[rows] = commodity_to_group[commodity$row_group[rows] + 1L]
take = commodity$column_group >= 0L
selected = commodity_to_group[commodity$column_group[take] + 1L] >= 0L
columns = which(take)[selected]
full_column_group[columns] = commodity_to_group[commodity$column_group[columns] + 1L]
keep_rows = which(first$row_group < 0L)
keep_columns = which(first$column_group < 0L)
row_group = as.integer(full_row_group[keep_rows])
column_group = as.integer(full_column_group[keep_columns])
cat("groups", activity$n_groups, "kept", sum(row_group < 0L),
    "selected", sum(row_group >= 0L), "\n")
stats = block_schur_stats(first$A, row_group, column_group,
                          activity$n_groups)
print(stats[c("b_nnz", "c_nnz", "d_nnz", "cross_l", "product_upper",
               "max_b_columns", "max_c_rows")])
