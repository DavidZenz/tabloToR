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

domain_blocks = function(domains, index, count) {
  position = which(vapply(domains, function(domain) {
    identical(domain$set, "reg")
  }, logical(1)))
  if (!length(position)) return(rep(0L, count))
  position = position[[1L]]
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  before = if (position == 1L) 1 else prod(lengths[seq_len(position - 1L)])
  after = if (position == length(lengths)) 1 else
    prod(lengths[(position + 1L):length(lengths)])
  as.integer(rep(
    rep(seq_len(lengths[[position]]), each = after), times = before
  ))
}

row_block = integer(nrow(matrix))
for (equation in active$equations) {
  rows = seq.int(equation$row_start, equation$row_end)
  row_block[rows] = domain_blocks(equation$domains, active, equation$n)
}
variable_block = integer(active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  positions = which(vapply(variable$domains, function(domain) {
    identical(domain$set, "reg")
  }, logical(1)))
  if (!length(positions)) next
  start = variable$endo_start
  finish = start + variable$n - 1L
  position = positions[[1L]]
  lengths = variable$lengths
  before = if (position == 1L) 1 else prod(lengths[seq_len(position - 1L)])
  after = if (position == length(lengths)) 1 else
    prod(lengths[(position + 1L):length(lengths)])
  variable_block[seq.int(start, finish)] = as.integer(rep(
    rep(seq_len(lengths[[position]]), each = before), times = after
  ))
}
column_block = variable_block[active$column_order]
row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(matrix))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(matrix))), 1e-12)

message("blocks ", length(unique(row_block)), "; RSS before C++ ", read_peak_rss())
Rcpp::sourceCpp("benchmarks/.eigen-block-gmres.cpp", showOutput = FALSE)
message("starting Eigen block GMRES; RSS ", read_peak_rss())
result = solve_eigen_block_gmres(
  matrix, b, as.integer(row_block), as.integer(column_block),
  row_scale, column_scale, 8L, 150L, 1e-7, 0L,
  NULL, integer(), integer(), 2L
)
print(result[c("converged", "iterations", "estimated_residual",
               "true_residual", "blocks", "nnz")])
message("RSS after solve ", read_peak_rss())
saveRDS(result, "/tmp/tabloToR-gtap-eigen-block-gmres.rds")
