matrix = emitted$A
b = emitted$rhs
row_norm = as.numeric(Matrix::rowSums(abs(matrix)))
column_norm = as.numeric(Matrix::colSums(abs(matrix)))
row_scale = 1 / pmax(row_norm, 1e-12)
column_scale = 1 / pmax(column_norm, 1e-12)
group_by_endo = integer(active$endogenous_count)
next_group = 1L
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  start = variable$endo_start
  finish = variable$endo_start + variable$n - 1L
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
  ))
  group_by_endo[seq.int(start, finish)] = next_group + values - 1L
  next_group = next_group + lengths[[position]]
}
group_count = next_group - 1L
row_group = group_by_endo[active$column_order]
column_group = row_group
group_rows = tabulate(row_group, nbins = group_count)
if (any(group_rows == 0L)) stop("Coarse groups contain empty rows", call. = FALSE)
message("coarse groups ", group_count, "; largest ",
        max(group_rows), "; RSS ", read_peak_rss())
entry_columns = rep.int(seq_len(ncol(matrix)), diff(matrix@p))
entry_rows = matrix@i + 1L
coarse_i = row_group[entry_rows]
coarse_j = column_group[entry_columns]
coarse_x = matrix@x *
  row_scale[entry_rows] * column_scale[entry_columns] /
  group_rows[coarse_i]
coarse = Matrix::sparseMatrix(
  i = coarse_i, j = coarse_j, x = coarse_x,
  dims = c(group_count, group_count), repr = "C"
)
coarse = Matrix::drop0(coarse)
message("coarse nnz ", length(coarse@x), "; RSS ", read_peak_rss())
rm(entry_columns, entry_rows, coarse_i, coarse_j, coarse_x)
gc()
regularization = as.numeric(getOption(
  "tabloToR.sparse.coarse_regularization", 1e-8
))[1L]
coarse = coarse + Matrix::Diagonal(
  nrow(coarse), x = regularization
)
factor = tryCatch(
  Matrix::lu(coarse, order = 3L),
  error = function(error) {
    stop(sprintf("Regularized coarse factorization failed: %s",
                conditionMessage(error)), call. = FALSE)
  }
)
rm(coarse)
gc()
message("coarse factor ready; RSS ", read_peak_rss())
diagonal = as.numeric(Matrix::diag(matrix))
scaled_diagonal = row_scale * diagonal * column_scale
inverse_diagonal = numeric(length(scaled_diagonal))
take = is.finite(scaled_diagonal) & abs(scaled_diagonal) > 1e-12
inverse_diagonal[take] = 1 / scaled_diagonal[take]
inverse_diagonal[!take] = 1
precondition = function(value) {
  fine = inverse_diagonal * value
  coarse_residual = value - operator_base(fine)
  coarse_rhs = as.numeric(rowsum(coarse_residual, row_group, reorder = FALSE))
  coarse_rhs = coarse_rhs / group_rows
  coarse_solution = as.numeric(Matrix::solve(factor, coarse_rhs))
  fine + coarse_solution[column_group]
}
operator_base = function(value) {
  row_scale * as.numeric(matrix %*% (column_scale * value))
}
operator = function(value) operator_base(precondition(value))
rhs = row_scale * b
rhs_norm = sqrt(sum(rhs * rhs))
solution_scaled = numeric(length(rhs))
restart = 10L
max_restart = 5L
tol = 1e-7
converged = FALSE
for (restart_id in seq_len(max_restart)) {
  residual = rhs - operator(solution_scaled)
  beta = sqrt(sum(residual * residual))
  message("coarse GMRES restart ", restart_id, "; residual ", beta)
  if (beta <= tol * max(1, rhs_norm)) {
    converged = TRUE
    break
  }
  basis = vector("list", restart + 1L)
  basis[[1L]] = residual / beta
  hessenberg = matrix(0, restart + 1L, restart)
  target = numeric(restart + 1L)
  target[[1L]] = beta
  inner = 0L
  for (j in seq_len(restart)) {
    inner = j
    value = operator(basis[[j]])
    for (i in seq_len(j)) {
      hessenberg[i, j] = sum(basis[[i]] * value)
      value = value - hessenberg[i, j] * basis[[i]]
    }
    next_norm = sqrt(sum(value * value))
    hessenberg[j + 1L, j] = next_norm
    if (next_norm > 0 && is.finite(next_norm)) {
      basis[[j + 1L]] = value / next_norm
    }
    coefficients = qr.solve(
      hessenberg[seq_len(j + 1L), seq_len(j), drop = FALSE],
      target[seq_len(j + 1L)]
    )
    estimate = sqrt(sum(
      (hessenberg[seq_len(j + 1L), seq_len(j), drop = FALSE] %*%
         coefficients - target[seq_len(j + 1L)])^2
    ))
    message("coarse GMRES inner ", j, "; estimated residual ", estimate)
    if (estimate <= tol * max(1, rhs_norm) ||
        !length(basis[[j + 1L]])) break
  }
  correction = numeric(length(solution_scaled))
  for (i in seq_len(inner)) {
    correction = correction + coefficients[[i]] * basis[[i]]
  }
  solution_scaled = solution_scaled + correction
}
solution = column_scale * precondition(solution_scaled)
residual = as.numeric(matrix %*% solution - b)
message("coarse GMRES converged ", converged,
        "; true residual ", sqrt(sum(residual * residual)),
        "; RSS ", read_peak_rss())
saveRDS(solution, "/tmp/tabloToR-gtap-coarse-solution.rds")
quit(save = "no", status = 0)
