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
keep_rows = which(first$row_group < 0L)
keep_columns = which(first$column_group < 0L)
first_rhs = first$rhs
if (length(first_rhs) != nrow(first$A)) first_rhs = first_rhs[keep_rows]

run_family = function(label, sets, variables, equations, output) {
  family = sparse_elimination_family(
    active, NULL, sets, variables, equations
  )
  row_group = as.integer(family$row_group[keep_rows])
  column_group = as.integer(family$column_group[keep_columns])
  cat(label, "groups", family$n_groups,
      "selected", sum(row_group >= 0L), "\n")
  cat("inputs", nrow(first$A), length(first_rhs), length(row_group),
      length(column_group), as.integer(family$n_groups),
      "rhs finite", all(is.finite(first_rhs)), "\n")
  probe = tryCatch(
    compiled$eliminate(
      first$A, first_rhs, row_group, column_group,
      as.integer(family$n_groups), 1e-12
    ),
    error = function(error) error
  )
  if (inherits(probe, "error")) {
    cat(label, "not block diagonal:", conditionMessage(probe), "\n")
    return(invisible(NULL))
  }
  singular = sort(unique(as.integer(probe$singular_groups)))
  usable = setdiff(seq_len(family$n_groups) - 1L, singular)
  cat(label, "probe ok", isTRUE(probe$ok), "singular count",
      probe$singular_count, "reported", length(singular),
      "usable", length(usable), "\n")
  if (!length(usable)) return(invisible(NULL))
  remap = integer(family$n_groups)
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
  if (!isTRUE(result$ok)) stop(label, " selective elimination failed")
  cat(label, "singular", length(singular), "eliminated", length(usable),
      "retained", result$kept_dimension, "nnz", length(result$A@x), "\n")
  saveRDS(
    list(
      A = result$A,
      rhs = result$rhs,
      row_group = new_rows,
      column_group = new_columns,
      n_groups = as.integer(length(usable)),
      singular_groups = singular,
      family = label
    ),
    output,
    compress = FALSE
  )
  invisible(NULL)
}

run_family(
  "activity", c("acts", "reg"),
  c("po", "qo", "ao", "pint", "qint", "aint", "pva", "qva", "ava", "pb"),
  c("e_qint", "e_qva", "e_qo", "e_pint", "e_pva", "e_ao", "e_ava", "e_aint", "e_po", "e_pb"),
  "/tmp/tabloToR-gtap-partial-activity-only.rds"
)
run_family(
  "endowment", c("acts", "reg"),
  c("pes", "qes", "peb", "qfe", "pfe", "afe"),
  c("e_qfe", "e_afe", "e_pfe", "e_pes", "e_peb", "e_qes1", "e_qes2", "e_qes3"),
  "/tmp/tabloToR-gtap-partial-endowment-only.rds"
)
