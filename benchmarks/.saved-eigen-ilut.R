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
row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(matrix))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(matrix))), 1e-12)
message("starting Eigen ILUT; RSS ", read_peak_rss())
Rcpp::sourceCpp("benchmarks/.eigen-ilut.cpp", showOutput = FALSE)
result = solve_scaled_ilut(
  matrix, b, row_scale, column_scale, droptol = 1e-4,
  fillfactor = 10L, max_iterations = 300L, tolerance = 1e-7
)
solution = column_scale * result$solution
true_residual = sqrt(sum((as.numeric(matrix %*% solution) - b)^2))
print(result[c("iterations", "error", "status", "scaled_nnz")])
message("true residual ", true_residual, "; RSS ", read_peak_rss())
saveRDS(list(result = result, true_residual = true_residual),
        "/tmp/tabloToR-gtap-eigen-ilut.rds")
