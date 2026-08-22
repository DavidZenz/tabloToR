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
if (is.null(active$column_order) || length(active$column_order) != ncol(matrix)) {
  stop("A row-to-column permutation is required for regional blocks")
}
column_block = variable_block[active$column_order]
block_ids = sort(unique(row_block))
if (!identical(block_ids, sort(unique(column_block)))) {
  stop("Regional row and column block IDs differ")
}
block_rows = lapply(block_ids, function(block) which(row_block == block))
block_columns = lapply(block_ids, function(block) which(column_block == block))
if (!all(vapply(seq_along(block_ids), function(id) {
  length(block_rows[[id]]) == length(block_columns[[id]])
}, logical(1)))) {
  stop("Regional blocks are not square")
}
message("block count ", length(block_ids), "; largest ",
        max(vapply(block_rows, length, integer(1))),
        "; RSS ", read_peak_rss())

row_norm = as.numeric(Matrix::rowSums(abs(matrix)))
column_norm = as.numeric(Matrix::colSums(abs(matrix)))
row_scale = 1 / pmax(row_norm, 1e-12)
column_scale = 1 / pmax(column_norm, 1e-12)

factors = vector("list", length(block_ids))
for (id in seq_along(block_ids)) {
  rows = block_rows[[id]]
  columns = block_columns[[id]]
  block = matrix[rows, columns, drop = FALSE]
  block_i = integer()
  block_x = numeric()
  if (length(block@x)) {
    block_i = block@i + 1L
    block_x = block@x * row_scale[rows[block_i]] *
      column_scale[columns[rep.int(seq_len(ncol(block)), diff(block@p))]]
    block@x = block_x
    block = Matrix::drop0(block)
  }
  factors[[id]] = Matrix::lu(block, order = 3L)
  message("factor ", id, "/", length(block_ids),
          " dim ", length(rows), " nnz ", length(block@x),
          "; RSS ", read_peak_rss())
  rm(block, block_i, block_x)
  gc()
}
message("all block factors ready; RSS ", read_peak_rss())

apply_block_inverse = function(value) {
  result = numeric(length(value))
  for (id in seq_along(block_ids)) {
    rows = block_rows[[id]]
    columns = block_columns[[id]]
    result[columns] = as.numeric(Matrix::solve(
      factors[[id]], value[rows]
    ))
  }
  result
}
operator_base = function(value) {
  row_scale * as.numeric(matrix %*% (column_scale * value))
}
operator = function(value) operator_base(apply_block_inverse(value))
rhs = row_scale * b
rhs_norm = sqrt(sum(rhs * rhs))
solution_z = numeric(length(rhs))
restart = 10L
max_restart = 30L
tol = 1e-7
converged = FALSE
for (restart_id in seq_len(max_restart)) {
  residual = rhs - operator(solution_z)
  beta = sqrt(sum(residual * residual))
  message("block-right GMRES restart ", restart_id,
          "; residual ", beta, "; RSS ", read_peak_rss())
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
  coefficients = numeric()
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
    message("inner ", j, "; estimated residual ", estimate)
    if (estimate <= tol * max(1, rhs_norm) ||
        !length(basis[[j + 1L]])) break
  }
  correction = numeric(length(solution_z))
  for (i in seq_len(inner)) {
    correction = correction + coefficients[[i]] * basis[[i]]
  }
  solution_z = solution_z + correction
  rm(basis, hessenberg, target, correction, value)
  gc()
}
solution_scaled = apply_block_inverse(solution_z)
solution = column_scale * solution_scaled
residual = as.numeric(matrix %*% solution - b)
message("block-right GMRES converged ", converged,
        "; true residual ", sqrt(sum(residual * residual)),
        "; RSS ", read_peak_rss())
saveRDS(solution, "/tmp/tabloToR-gtap-block-all-solution.rds")
quit(save = "no", status = 0)
