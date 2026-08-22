library(Matrix)

read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}

matrix = readRDS("/tmp/tabloToR-gtap-A.rds")
b = readRDS("/tmp/tabloToR-gtap-rhs.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")

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

group_by_endo = integer(active$endogenous_count)
next_group = 0L
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  start = variable$endo_start
  finish = start + variable$n - 1L
  positions = which(vapply(variable$domains, function(domain) {
    identical(domain$set, "reg")
  }, logical(1)))
  if (!length(positions)) {
    group_by_endo[seq.int(start, finish)] = next_group
    next_group = next_group + 1L
    next
  }
  position = positions[[1L]]
  lengths = variable$lengths
  before = if (position == 1L) 1 else prod(lengths[seq_len(position - 1L)])
  after = if (position == length(lengths)) 1 else
    prod(lengths[(position + 1L):length(lengths)])
  values = as.integer(rep(
    rep(seq_len(lengths[[position]]), each = before), times = after
  )) - 1L
  group_by_endo[seq.int(start, finish)] = next_group + values
  next_group = next_group + lengths[[position]]
}
group_count = next_group
row_group = group_by_endo[active$column_order]
column_group = row_group
group_rows = tabulate(row_group + 1L, nbins = group_count)

row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(matrix))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(matrix))), 1e-12)
entry_columns = rep.int(seq_len(ncol(matrix)), diff(matrix@p))
entry_rows = matrix@i + 1L
coarse = Matrix::sparseMatrix(
  i = row_group[entry_rows] + 1L,
  j = column_group[entry_columns] + 1L,
  x = matrix@x * row_scale[entry_rows] * column_scale[entry_columns] /
    group_rows[row_group[entry_rows] + 1L],
  dims = c(group_count, group_count), repr = "C"
)
coarse = Matrix::drop0(coarse)
message("coarse groups ", group_count, "; nnz ", length(coarse@x),
        "; RSS before C++ ", read_peak_rss())

Rcpp::sourceCpp("benchmarks/.eigen-block-gmres.cpp", showOutput = FALSE)
result = solve_eigen_block_gmres(
  matrix, b, as.integer(row_block), as.integer(column_block),
  row_scale, column_scale, 8L, 80L, 1e-7, 0L, coarse,
  as.integer(row_group), as.integer(column_group)
)
print(result[c("converged", "iterations", "estimated_residual",
               "true_residual", "blocks", "nnz")])
message("RSS after solve ", read_peak_rss())
saveRDS(result, "/tmp/tabloToR-gtap-eigen-twolevel.rds")
