library(Matrix)

matrix = readRDS("/tmp/tabloToR-gtap-A.rds")
b = readRDS("/tmp/tabloToR-gtap-rhs.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")

read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1L]]
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

encode = function(comm, reg) {
  ifelse(comm > 0L & reg > 0L, comm + 1000L * reg,
         ifelse(comm > 0L, comm,
                ifelse(reg > 0L, 1000L * reg, 0L)))
}
row_code = encode(row_comm, row_reg)
column_code = encode(column_comm, column_reg)
codes = sort(unique(c(row_code, column_code)))
row_block = as.integer(match(row_code, codes) - 1L)
column_block = as.integer(match(column_code, codes) - 1L)
row_counts = tabulate(row_block + 1L, nbins = length(codes))
column_counts = tabulate(column_block + 1L, nbins = length(codes))
if (!identical(row_counts, column_counts)) stop("Pair block dimensions differ")
cat("blocks=", length(codes), "largest=", max(row_counts),
    "direct_max=", Sys.getenv("TABLO_PAIR_DIRECT_MAX", "10000"), "\\n", sep = "")

row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(matrix))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(matrix))), 1e-12)
Rcpp::sourceCpp("benchmarks/.eigen-block-gmres.cpp", showOutput = FALSE)
message("starting commodity/regional pair-block GMRES; RSS ", read_peak_rss())
result = solve_eigen_block_gmres(
  matrix, b, row_block, column_block, row_scale, column_scale,
  8L, as.integer(Sys.getenv("TABLO_PAIR_MAX_ITERS", "50")),
  1e-7, 0L, NULL, integer(), integer(), 0L,
  as.integer(Sys.getenv("TABLO_PAIR_DIRECT_MAX", "10000"))
)
print(result[c("converged", "iterations", "estimated_residual",
               "true_residual", "blocks", "nnz")])
message("RSS after solve ", read_peak_rss())
saveRDS(result, "/tmp/tabloToR-gtap-eigen-commodity-regional-pair.rds")
