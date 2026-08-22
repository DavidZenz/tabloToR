read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}
library(Matrix)
matrix = readRDS("/tmp/tabloToR-gtap-A.rds")
b = readRDS("/tmp/tabloToR-gtap-rhs.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
region_index = function(domains) {
  positions = which(vapply(domains, function(domain) {
    identical(domain$set, "reg")
  }, logical(1)))
  if (!length(positions)) return(NA_integer_)
  positions[[1L]]
}
domain_blocks = function(domains, index, count) {
  position = region_index(domains)
  if (is.na(position)) return(rep(0L, count))
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
  start = variable$endo_start
  finish = variable$endo_start + variable$n - 1L
  if (!length(positions)) next
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
block_ids = sort(unique(row_block))
block_rows = lapply(block_ids, function(block) which(row_block == block))
block_columns = lapply(block_ids, function(block) which(column_block == block))
message("blocks ", length(block_ids), "; largest ",
        max(vapply(block_rows, length, integer(1))),
        "; RSS ", read_peak_rss())
rows = block_rows[[which(block_ids == 1L)[[1L]]]]
columns = block_columns[[which(block_ids == 1L)[[1L]]]]
regional = matrix[rows, columns, drop = FALSE]
row_norm = as.numeric(Matrix::rowSums(abs(matrix)))
column_norm = as.numeric(Matrix::colSums(abs(matrix)))
row_scale = 1 / pmax(row_norm, 1e-12)
column_scale = 1 / pmax(column_norm, 1e-12)
local_rows = regional@i + 1L
local_columns = rep.int(seq_len(ncol(regional)), diff(regional@p))
regional@x = regional@x * row_scale[rows[local_rows]] *
  column_scale[columns[local_columns]]
regional = Matrix::drop0(regional)
Rcpp::sourceCpp("benchmarks/.eigen-block.cpp")
message("eigen factor start dim ", nrow(regional),
        " nnz ", length(regional@x), "; RSS ", read_peak_rss())
result = solve_eigen_lu(regional, row_scale[rows] * b[rows])
message("status ", result$status, "; RSS ", read_peak_rss())
saveRDS(result, "/tmp/tabloToR-gtap-eigen-one.rds")
