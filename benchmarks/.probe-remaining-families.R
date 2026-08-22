library(Matrix)
if (!requireNamespace("Rcpp", quietly = TRUE)) stop("Rcpp unavailable")
source("R/sparseElimination.R")
source("benchmarks/.level-stats.R")

first = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
second = readRDS("/tmp/tabloToR-gtap-partial-endowment-only.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
keep_first = which(first$row_group < 0L)
keep_second = which(second$row_group < 0L)
rhs = as.numeric(second$rhs)
if (length(rhs) != second$A@Dim[[1L]]) stop("second RHS has wrong length")

environment = new.env(parent = globalenv())
Rcpp::sourceCpp(
  file = "inst/cpp/sparse-elimination.cpp",
  env = environment,
  showOutput = FALSE
)
eliminate = get("tabloToR_eliminate_blocks", environment)

run_family = function(label, sets, variables, equations, output) {
  family = sparse_elimination_family(
    active, NULL, sets, variables, equations
  )
  row_group = family$row_group[keep_first][keep_second]
  column_group = family$column_group[keep_first][keep_second]
  cat(label, "groups", family$n_groups,
      "selected", sum(row_group >= 0L), "\n")
  probe = tryCatch(
    eliminate(
      second$A, rhs, as.integer(row_group), as.integer(column_group),
      as.integer(family$n_groups), 1e-12
    ),
    error = function(error) error
  )
  if (inherits(probe, "error")) {
    cat(label, "not block diagonal:", conditionMessage(probe), "\n")
    return(invisible(NULL))
  }
  singular = sort(unique(as.integer(probe$singular_groups)))
  cat(label, "ok", isTRUE(probe$ok),
      "singular", length(singular),
      "selected", sum(row_group >= 0L),
      "retained", probe$kept_dimension, "\n")
  if (!isTRUE(probe$ok)) return(invisible(NULL))
  saveRDS(
    list(
      A = probe$A, rhs = probe$rhs,
      row_group = as.integer(row_group),
      column_group = as.integer(column_group),
      n_groups = as.integer(family$n_groups),
      family = label
    ),
    output,
    compress = FALSE
  )
  invisible(NULL)
}

run_family(
  "commodity", c("reg"),
  levels$commodity$variables, levels$commodity$equations,
  "/tmp/tabloToR-gtap-partial-commodity-only.rds"
)
run_family(
  "region", c("reg"),
  levels$region$variables, levels$region$equations,
  "/tmp/tabloToR-gtap-partial-region-only.rds"
)
