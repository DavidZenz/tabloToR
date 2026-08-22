matrix = emitted$A
b = emitted$rhs
diagonal = as.numeric(Matrix::diag(matrix))
row_norm = as.numeric(Matrix::rowSums(abs(matrix)))
column_norm = as.numeric(Matrix::colSums(abs(matrix)))
row_scale = 1 / pmax(row_norm, 1e-12)
column_scale = 1 / pmax(column_norm, 1e-12)
diagonal_scaled = row_scale * diagonal * column_scale
nonzero_diagonal = diagonal_scaled[is.finite(diagonal_scaled) &
                                    diagonal_scaled != 0]
cat("scaled_diagonal_nonzero=", length(nonzero_diagonal),
    " min_abs=", min(abs(nonzero_diagonal)),
    " max_abs=", max(abs(nonzero_diagonal)), "\n", sep = "")
preconditioner = numeric(length(diagonal_scaled))
take = is.finite(diagonal_scaled) & abs(diagonal_scaled) > 1e-12
preconditioner[take] = 1 / diagonal_scaled[take]
preconditioner[!take] = 1
operator = function(value) {
  preconditioner * row_scale *
    as.numeric(matrix %*% (column_scale * value))
}
rhs = preconditioner * row_scale * b
rhs_norm = sqrt(sum(rhs * rhs))
solution_scaled = numeric(length(rhs))
residual = rhs - operator(solution_scaled)
shadow = residual
search = numeric(length(rhs))
product = numeric(length(rhs))
rho_old = 1
alpha = 1
omega = 1
converged = FALSE
tol = 1e-7
max_iteration = 100L
for (iteration in seq_len(max_iteration)) {
  rho = sum(shadow * residual)
  if (!is.finite(rho) || abs(rho) < 1e-30) break
  if (iteration == 1L) {
    search = residual
  } else {
    beta = (rho / rho_old) * (alpha / omega)
    search = residual + beta * (search - omega * product)
  }
  product = operator(search)
  denominator = sum(shadow * product)
  if (!is.finite(denominator) || abs(denominator) < 1e-30) break
  alpha = rho / denominator
  intermediate = residual - alpha * product
  intermediate_norm = sqrt(sum(intermediate * intermediate))
  if (intermediate_norm <= tol * max(1, rhs_norm)) {
    solution_scaled = solution_scaled + alpha * search
    converged = TRUE
    cat("bicgstab_converged_iteration=", iteration,
        " residual=", intermediate_norm, "\n", sep = "")
    break
  }
  correction = operator(intermediate)
  denominator = sum(correction * correction)
  if (!is.finite(denominator) || denominator < 1e-30) break
  omega = sum(correction * intermediate) / denominator
  if (!is.finite(omega) || abs(omega) < 1e-30) break
  solution_scaled = solution_scaled + alpha * search + omega * intermediate
  residual = intermediate - omega * correction
  residual_norm = sqrt(sum(residual * residual))
  if (iteration %% 5L == 0L) {
    cat("bicgstab_iteration=", iteration,
        " residual=", residual_norm, "\n", sep = "")
  }
  if (residual_norm <= tol * max(1, rhs_norm)) {
    converged = TRUE
    break
  }
  rho_old = rho
}
solution = column_scale * solution_scaled
residual = as.numeric(matrix %*% solution - b)
cat("bicgstab_converged=", converged,
    " residual_norm=", sqrt(sum(residual * residual)),
    " rss_hwm=", read_peak_rss(), "\n", sep = "")
saveRDS(solution, "/tmp/tabloToR-gtap-bicgstab-solution.rds")
