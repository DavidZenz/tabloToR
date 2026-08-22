library(Matrix)
if (!requireNamespace("Rcpp", quietly = TRUE)) stop("Rcpp unavailable")
source("R/sparseElimination.R")

first = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
environment = new.env(parent = globalenv())
Rcpp::sourceCpp(
  file = "inst/cpp/sparse-elimination.cpp",
  env = environment,
  showOutput = FALSE
)
compiled = list(eliminate = get("tabloToR_eliminate_blocks", environment))

activity = sparse_elimination_family(
  active, NULL, c("acts", "reg"),
  c("po", "qo", "ao", "pint", "qint", "aint", "pva", "qva", "ava", "pb"),
  c("e_qint", "e_qva", "e_qo", "e_pint", "e_pva", "e_ao", "e_ava", "e_aint", "e_po", "e_pb")
)
endowment = sparse_elimination_family(
  active, NULL, c("acts", "reg"),
  c("pes", "qes", "peb", "qfe", "pfe", "afe"),
  c("e_qfe", "e_afe", "e_pfe", "e_pes", "e_peb", "e_qes1", "e_qes2", "e_qes3")
)

keep_rows = which(first$row_group < 0L)
keep_columns = which(first$column_group < 0L)
first_rhs = first$rhs
if (length(first_rhs) != nrow(first$A)) first_rhs = first_rhs[keep_rows]
if (length(keep_rows) != nrow(first$A) ||
    length(keep_columns) != ncol(first$A)) {
  stop("first reduction coordinates do not match the saved reduced matrix")
}

full_rows = rep.int(-1L, length(activity$row_group))
full_columns = rep.int(-1L, length(activity$column_group))
take = activity$row_group >= 0L
full_rows[take] = activity$row_group[take]
take = activity$column_group >= 0L
full_columns[take] = activity$column_group[take]
offset = activity$n_groups
take = endowment$row_group >= 0L
full_rows[take] = endowment$row_group[take] + offset
take = endowment$column_group >= 0L
full_columns[take] = endowment$column_group[take] + offset
row_group = as.integer(full_rows[keep_rows])
column_group = as.integer(full_columns[keep_columns])
n_groups = as.integer(activity$n_groups + endowment$n_groups)
if (length(row_group) != nrow(first$A) ||
    length(column_group) != ncol(first$A)) {
  stop("partial block maps have incompatible dimensions")
}

probe = compiled$eliminate(
  first$A, first_rhs, row_group, column_group, n_groups, 1e-12
)
if (isTRUE(probe$ok)) stop("expected some singular activity/endowment blocks")
singular = sort(unique(as.integer(probe$singular_groups)))
usable = setdiff(seq_len(n_groups) - 1L, singular)
remap = integer(n_groups)
remap[usable + 1L] = seq_along(usable) - 1L
new_rows = rep.int(-1L, length(row_group))
new_columns = rep.int(-1L, length(column_group))
take = row_group >= 0L & !(row_group %in% singular)
new_rows[take] = remap[row_group[take] + 1L]
take = column_group >= 0L & !(column_group %in% singular)
new_columns[take] = remap[column_group[take] + 1L]

result = compiled$eliminate(
  first$A, first_rhs, new_rows, new_columns,
  as.integer(length(usable)), 1e-12
)
if (!isTRUE(result$ok)) stop("partial activity/endowment elimination failed")
cat("initial groups", n_groups, "singular", length(singular),
    "eliminated", length(usable), "retained", result$kept_dimension,
    "nnz", length(result$A@x), "\n")
saveRDS(
  list(
    A = result$A,
    rhs = result$rhs,
    row_group = new_rows,
    column_group = new_columns,
    n_groups = as.integer(length(usable)),
    singular_groups = singular
  ),
  "/tmp/tabloToR-gtap-partial-activity.rds",
  compress = FALSE
)
