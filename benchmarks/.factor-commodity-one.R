library(Matrix)

matrix = readRDS("/tmp/tabloToR-gtap-A.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
b = readRDS("/tmp/tabloToR-gtap-rhs.rds")

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
  p = which(vapply(domains, function(d) identical(d$set, set), logical(1)))
  lengths = vapply(domains, function(d) length(index$sets[[d$set]]$values), integer(1))
  if (!length(p)) return(rep(0L, prod(lengths)))
  p = p[[1L]]
  before = if (p == 1L) 1 else prod(lengths[seq_len(p - 1L)])
  after = if (p == length(lengths)) 1 else prod(lengths[(p + 1L):length(lengths)])
  if (variable) as.integer(rep(rep(seq_len(lengths[[p]]), each = before), times = after)) else
    as.integer(rep(rep(seq_len(lengths[[p]]), each = after), times = before))
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
row_group = ifelse(row_comm > 0L, row_comm, ifelse(row_reg > 0L, 65L + row_reg, 0L))
column_group = ifelse(column_comm > 0L, column_comm, ifelse(column_reg > 0L, 65L + column_reg, 0L))
rows = which(row_group == 1L)
columns = which(column_group == 1L)
B = matrix[rows, columns, drop = FALSE]
cat("block_dim=", nrow(B), "x", ncol(B), " nnz=", length(B@x),
    " rss_before=", read_peak_rss(), "\n", sep = "")
if (identical(Sys.getenv("TABLO_ONE_BACKEND", "Matrix"), "Eigen")) {
  Rcpp::sourceCpp("benchmarks/.eigen-one-direct.cpp", showOutput = FALSE)
  result = solve_eigen_one_direct(
    matrix, b, as.integer(row_group), as.integer(column_group), 1L
  )
  solution = result$solution
  cat("finite=", all(is.finite(solution)),
      " residual=", sqrt(sum((as.numeric(B %*% solution) - b[rows])^2)),
      " rss_after_factor=", read_peak_rss(), "\n", sep = "")
  saveRDS(result, "/tmp/tabloToR-commodity1-eigen-direct.rds")
  quit(save = "no", status = 0)
}
factor = Matrix::lu(B, order = 3L)
cat("L_nnz=", length(factor@L@x), " U_nnz=", length(factor@U@x),
    " rss_after_factor=", read_peak_rss(), "\n", sep = "")
rhs = b[rows]
solution = as.numeric(Matrix::solve(factor, rhs))
cat("finite=", all(is.finite(solution)),
    "residual=", sqrt(sum((as.numeric(B %*% solution) - rhs)^2)),
    " rss_after_solve=", read_peak_rss(), "\n", sep = "")
saveRDS(factor, "/tmp/tabloToR-commodity1-lu.rds", compress = FALSE)
