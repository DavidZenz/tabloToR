matrix = emitted$A
b = emitted$rhs
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
block_rows = lapply(seq_len(163L), function(region) {
  which(row_block == region)
})
block_columns = lapply(seq_len(163L), function(region) {
  which(column_block == region)
})
if (!all(vapply(seq_len(163L), function(region) {
  length(block_rows[[region]]) == length(block_columns[[region]])
}, logical(1)))) {
  stop("Regional blocks are not square", call. = FALSE)
}
row_norm = as.numeric(Matrix::rowSums(abs(matrix)))
column_norm = as.numeric(Matrix::colSums(abs(matrix)))
row_scale = 1 / pmax(row_norm, 1e-12)
column_scale = 1 / pmax(column_norm, 1e-12)
region_rows = block_rows[[1L]]
region_columns = block_columns[[1L]]
message("regional block dimension ", length(region_rows),
        "; RSS ", read_peak_rss())
regional = matrix[region_rows, region_columns, drop = FALSE]
regional_i = regional@i
regional_p = regional@p
regional_x = regional@x
for (column in seq_len(ncol(regional))) {
  start = regional_p[[column]] + 1L
  finish = regional_p[[column + 1L]]
  if (finish >= start) {
    regional_x[start:finish] = regional_x[start:finish] *
      row_scale[region_rows[regional_i[start:finish] + 1L]] *
      column_scale[region_columns[[column]]]
  }
}
regional@x = regional_x
regional = Matrix::drop0(regional)
message("regional nnz ", length(regional@x), "; RSS ", read_peak_rss())
factor = tryCatch(
  Matrix::lu(regional, order = 3L),
  error = function(error) {
    stop(sprintf("Regional factorization failed: %s",
                conditionMessage(error)), call. = FALSE)
  }
)
rm(regional, regional_i, regional_p, regional_x)
gc()
message("regional factor ready; RSS ", read_peak_rss())
diagonal = as.numeric(Matrix::diag(matrix))
scaled_diagonal = row_scale * diagonal * column_scale
inverse_diagonal = numeric(length(scaled_diagonal))
take = is.finite(scaled_diagonal) & abs(scaled_diagonal) > 1e-12
inverse_diagonal[take] = 1 / scaled_diagonal[take]
inverse_diagonal[!take] = 1
precondition = function(value) {
  result = inverse_diagonal * value
  for (region in seq_len(163L)) {
    result[block_columns[[region]]] = as.numeric(Matrix::solve(
      factor, value[block_rows[[region]]]
    ))
  }
  result
}
operator_base = function(value) {
  row_scale * as.numeric(matrix %*% (column_scale * value))
}
operator = function(value) precondition(operator_base(value))
rhs = precondition(row_scale * b)
rhs_norm = sqrt(sum(rhs * rhs))
solution_scaled = numeric(length(rhs))
restart = 10L
max_restart = 5L
tol = 1e-7
converged = FALSE
for (restart_id in seq_len(max_restart)) {
  residual = rhs - operator(solution_scaled)
  beta = sqrt(sum(residual * residual))
  message("block GMRES restart ", restart_id, "; residual ", beta)
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
    message("block GMRES inner ", j, "; estimated residual ", estimate)
    if (estimate <= tol * max(1, rhs_norm) ||
        !length(basis[[j + 1L]])) break
  }
  correction = numeric(length(solution_scaled))
  for (i in seq_len(inner)) {
    correction = correction + coefficients[[i]] * basis[[i]]
  }
  solution_scaled = solution_scaled + correction
}
solution = column_scale * solution_scaled
residual = as.numeric(matrix %*% solution - b)
message("block GMRES converged ", converged,
        "; true residual ", sqrt(sum(residual * residual)),
        "; RSS ", read_peak_rss())
saveRDS(solution, "/tmp/tabloToR-gtap-block-solution.rds")
quit(save = "no", status = 0)
