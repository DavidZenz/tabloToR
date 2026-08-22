matrix = emitted$A
b = emitted$rhs
diagonal = as.numeric(Matrix::diag(matrix))
row_norm = as.numeric(Matrix::rowSums(abs(matrix)))
column_norm = as.numeric(Matrix::colSums(abs(matrix)))
row_scale = 1 / pmax(row_norm, 1e-12)
column_scale = 1 / pmax(column_norm, 1e-12)
cat("ilut_prepare rss_hwm=", read_peak_rss(), "\n", sep = "")
Rcpp::sourceCpp("benchmarks/.eigen-ilut.cpp")
result = solve_scaled_ilut(
  matrix, b, row_scale, column_scale,
  droptol = 1e-4, fillfactor = 10L,
  max_iterations = 1000L, tolerance = 1e-7
)
solution = column_scale * result$solution
residual = as.numeric(matrix %*% solution - b)
cat(
  "ilut_status=", result$status,
  " iterations=", result$iterations,
  " error=", result$error,
  " scaled_nnz=", result$scaled_nnz,
  " residual_norm=", sqrt(sum(residual * residual)),
  " rss_hwm=", read_peak_rss(), "\n", sep = ""
)
saveRDS(solution, "/tmp/tabloToR-gtap-ilut-solution.rds")
quit(save = "no", status = 0)
