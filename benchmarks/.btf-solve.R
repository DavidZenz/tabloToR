library(Matrix)
input_path = Sys.getenv("BTF_INPUT", "/tmp/tabloToR-gtap-reduced-pb.rds")
output_path = Sys.getenv("BTF_OUTPUT",
                         "/tmp/tabloToR-gtap-reduced-btf-solution.rds")
z = readRDS(input_path)
original_rhs = as.numeric(z$rhs)
rhs = original_rhs
if (length(rhs) != nrow(z$A)) {
  if (length(rhs) != length(z$row_group)) {
    stop("saved RHS does not match either full or reduced coordinates")
  }
  rhs = rhs[which(z$row_group < 0L)]
}
original_rhs = rhs
start = proc.time()[[3L]]
d = Matrix::dmperm(z$A, nAns = 4L, seed = 0L)
nb = length(d$r) - 1L
sizes = diff(d$r)
if (!identical(sizes, diff(d$s))) stop("DMperm has non-square diagonal blocks")
cat("blocks", nb, "max", max(sizes), "\n")
permuted = z$A[d$p, d$q, drop = FALSE]
rhs = rhs[d$p]
solution = numeric(nrow(permuted))
p = permuted@p
i = permuted@i
x = permuted@x
for (block in nb:1L) {
  row_start = d$r[[block]] + 1L
  row_end = d$r[[block + 1L]]
  col_start = d$s[[block]] + 1L
  col_end = d$s[[block + 1L]]
  size = row_end - row_start + 1L
  if (size == 1L) {
    column = col_start
    row = row_start
    first = p[[column]] + 1L
    last = p[[column + 1L]]
    diagonal = 0
    if (first <= last) {
      positions = first:last
      diagonal = sum(x[positions][i[positions] == row - 1L])
      earlier = positions[i[positions] < row - 1L]
      if (length(earlier)) rhs[i[earlier] + 1L] =
        rhs[i[earlier] + 1L] - x[earlier] * (rhs[[row]] / diagonal)
    }
    if (!is.finite(diagonal) || diagonal == 0) stop("zero BTF singleton")
    solution[[column]] = rhs[[row]] / diagonal
  } else {
    rows = row_start:row_end
    columns = col_start:col_end
    local = permuted[rows, columns, drop = FALSE]
    local_solution = as.numeric(Matrix::solve(
      Matrix::lu(local, order = 3L), rhs[rows]
    ))
    if (any(!is.finite(local_solution))) stop("non-finite BTF block solution")
    solution[columns] = local_solution
    if (row_start > 1L) {
      update = permuted[seq_len(row_start - 1L), columns, drop = FALSE] %*%
        local_solution
      rhs[seq_len(row_start - 1L)] = rhs[seq_len(row_start - 1L)] -
        as.numeric(update)
    }
    rm(local, local_solution)
  }
  if (block %% 10000L == 0L || block == 1L) {
    cat("block", block, "size", size, "elapsed",
        proc.time()[[3L]] - start, "\n")
  }
}
result = numeric(length(solution))
result[d$q] = solution
residual = z$A %*% result - original_rhs
cat("elapsed", proc.time()[[3L]] - start,
    "true relative residual",
    sqrt(sum(residual * residual)) /
      max(1, sqrt(sum(original_rhs * original_rhs))),
    "finite", all(is.finite(result)), "\n")
saveRDS(result, output_path, compress = FALSE)
