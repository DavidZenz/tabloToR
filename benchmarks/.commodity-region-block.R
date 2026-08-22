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
  position = which(vapply(domains, function(domain) identical(domain$set, set), logical(1)))
  lengths = vapply(domains, function(domain) length(index$sets[[domain$set]]$values), integer(1))
  if (!length(position)) return(rep(0L, prod(lengths)))
  position = position[[1L]]
  before = if (position == 1L) 1 else prod(lengths[seq_len(position - 1L)])
  after = if (position == length(lengths)) 1 else prod(lengths[(position + 1L):length(lengths)])
  if (variable) as.integer(rep(rep(seq_len(lengths[[position]]), each = before), times = after)) else
    as.integer(rep(rep(seq_len(lengths[[position]]), each = after), times = before))
}

row_comm = integer(nrow(matrix)); row_reg = integer(nrow(matrix))
for (equation in active$equations) {
  rows = seq.int(equation$row_start, equation$row_end)
  row_comm[rows] = domain_blocks(equation$domains, active, "comm")
  row_reg[rows] = domain_blocks(equation$domains, active, "reg")
}
variable_comm = integer(active$endogenous_count); variable_reg = integer(active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  positions = seq.int(variable$endo_start, variable$endo_start + variable$n - 1L)
  variable_comm[positions] = domain_blocks(variable$domains, active, "comm", TRUE)
  variable_reg[positions] = domain_blocks(variable$domains, active, "reg", TRUE)
}
column_comm = variable_comm[active$column_order]
column_reg = variable_reg[active$column_order]
row_block = ifelse(row_comm > 0L, row_comm,
                   ifelse(row_reg > 0L, 65L + row_reg, 0L))
column_block = ifelse(column_comm > 0L, column_comm,
                      ifelse(column_reg > 0L, 65L + column_reg, 0L))
row_block = as.integer(row_block)
column_block = as.integer(column_block)
counts = table(factor(row_block, levels = 0:228))
column_counts = table(factor(column_block, levels = 0:228))
if (!identical(as.integer(counts), as.integer(column_counts))) {
  stop("Commodity/regional block row and column dimensions differ")
}
cat("blocks=", length(unique(row_block)),
    "global=", counts[[1]],
    "largest=", max(counts), "\n", sep = "")
row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(matrix))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(matrix))), 1e-12)

Rcpp::sourceCpp("benchmarks/.eigen-block-gmres.cpp", showOutput = FALSE)
message("starting commodity/regional block GMRES; RSS ", read_peak_rss())
result = solve_eigen_block_gmres(
  matrix, b, row_block, column_block, row_scale, column_scale,
  as.integer(Sys.getenv("TABLO_BLOCK_RESTART", "8")),
  as.integer(Sys.getenv("TABLO_BLOCK_MAX_ITERS", "300")),
  1e-7, 0L, NULL, integer(), integer(),
  as.integer(Sys.getenv("TABLO_BLOCK_METHOD", "0")),
  as.integer(Sys.getenv("TABLO_BLOCK_DIRECT_MAX", "-1"))
)
print(result[c("converged", "iterations", "estimated_residual",
               "true_residual", "blocks", "nnz")])
message("RSS after solve ", read_peak_rss())
saveRDS(result, "/tmp/tabloToR-gtap-eigen-commodity-regional.rds")
