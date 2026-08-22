library(Matrix)

matrix = readRDS("/tmp/tabloToR-gtap-A.rds")
b = readRDS("/tmp/tabloToR-gtap-rhs.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")

read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}

domain_blocks = function(domains, index, set, variable = FALSE) {
  position = which(vapply(domains, function(domain) {
    identical(domain$set, set)
  }, logical(1)))
  if (!length(position)) return(rep(0L, prod(vapply(
    domains, function(domain) length(index$sets[[domain$set]]$values), integer(1)
  ))))
  position = position[[1L]]
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  before = if (position == 1L) 1 else prod(lengths[seq_len(position - 1L)])
  after = if (position == length(lengths)) 1 else
    prod(lengths[(position + 1L):length(lengths)])
  if (variable) {
    as.integer(rep(rep(seq_len(lengths[[position]]), each = before), times = after))
  } else {
    as.integer(rep(rep(seq_len(lengths[[position]]), each = after), times = before))
  }
}

row_block = integer(nrow(matrix))
for (equation in active$equations) {
  rows = seq.int(equation$row_start, equation$row_end)
  row_block[rows] = domain_blocks(equation$domains, active, "comm")
}
variable_block = integer(active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  start = variable$endo_start
  finish = start + variable$n - 1L
  variable_block[seq.int(start, finish)] = domain_blocks(
    variable$domains, active, "comm", variable = TRUE
  )
}
column_block = variable_block[active$column_order]
if (anyNA(row_block) || anyNA(column_block) ||
    !identical(as.integer(sum(row_block == 0L)),
               as.integer(sum(column_block == 0L)))) {
  stop("Invalid commodity partition")
}
row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(matrix))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(matrix))), 1e-12)

message("commodity blocks ", length(unique(row_block)),
        "; global rows ", sum(row_block == 0L),
        "; RSS before C++ ", read_peak_rss())
Rcpp::sourceCpp("benchmarks/.eigen-block-gmres.cpp", showOutput = FALSE)
message("starting commodity block GMRES; RSS ", read_peak_rss())
result = solve_eigen_block_gmres(
  matrix, b, as.integer(row_block), as.integer(column_block),
  row_scale, column_scale, 8L, 300L, 1e-7, 0L,
  NULL, integer(), integer(), 0L
)
print(result[c("converged", "iterations", "estimated_residual",
               "true_residual", "blocks", "nnz")])
message("RSS after solve ", read_peak_rss())
saveRDS(result, "/tmp/tabloToR-gtap-eigen-commodity.rds")
