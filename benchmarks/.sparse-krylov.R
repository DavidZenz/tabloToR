# Bounded-memory Krylov helpers for structured sparse systems.

sparse_block_sequence = function(domains, lengths, block_set, count) {
  position = which(vapply(domains, function(domain) {
    identical(domain$set, block_set)
  }, logical(1)))
  if (!length(position)) return(integer(count))
  position = position[[1L]]
  before = if (position == 1L) 1 else {
    prod(lengths[seq_len(position - 1L)])
  }
  after = if (position == length(lengths)) 1 else {
    prod(lengths[(position + 1L):length(lengths)])
  }
  as.integer(rep(
    rep(seq_len(lengths[[position]]), each = after), times = before
  ))
}

sparse_block_partition = function(index, state = NULL, block_set = NULL) {
  if (is.null(block_set) || !length(block_set)) {
    block_set = getOption("tabloToR.sparse.block_set", "reg")
  }
  block_set = as.character(block_set)[1L]
  set = index$sets[[block_set]]
  if (is.null(set) || !length(set$values)) return(NULL)
  if (is.null(index$column_order) ||
      length(index$column_order) != index$endogenous_count) {
    return(NULL)
  }

  row_block = integer(index$equation_count)
  for (equation in index$equations) {
    rows = seq.int(equation$row_start, equation$row_end)
    lengths = vapply(equation$domains, function(domain) {
      length(index$sets[[domain$set]]$values)
    }, integer(1))
    row_block[rows] = sparse_block_sequence(
      equation$domains, lengths, block_set, equation$n
    )
  }

  variable_block = integer(index$endogenous_count)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous)) next
    start = variable$endo_start
    finish = start + variable$n - 1L
    variable_block[seq.int(start, finish)] = sparse_block_sequence(
      variable$domains, variable$lengths, block_set, variable$n
    )
  }
  column_block = variable_block[index$column_order]
  row_ids = sort(unique(row_block))
  column_ids = sort(unique(column_block))
  if (!identical(row_ids, column_ids)) return(NULL)
  rows = lapply(row_ids, function(id) which(row_block == id))
  columns = lapply(row_ids, function(id) which(column_block == id))
  if (!all(vapply(seq_along(rows), function(id) {
    length(rows[[id]]) == length(columns[[id]])
  }, logical(1)))) {
    return(NULL)
  }
  list(
    set = block_set,
    ids = as.integer(row_ids),
    count = as.integer(length(rows)),
    row_block = row_block,
    column_block = column_block,
    rows = rows,
    columns = columns,
    dimensions = as.integer(vapply(rows, length, integer(1)))
  )
}

sparse_scaled_block_factors = function(A, partition, row_scale,
                                       column_scale) {
  lu_order = suppressWarnings(as.integer(getOption(
    "tabloToR.sparse.block_lu_order", 3L
  ))[1L])
  if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
    stop("tabloToR.sparse.block_lu_order must be an integer from 0 to 3",
         call. = FALSE)
  }
  factors = vector("list", partition$count)
  for (id in seq_len(partition$count)) {
    rows = partition$rows[[id]]
    columns = partition$columns[[id]]
    block = A[rows, columns, drop = FALSE]
    if (length(block@x)) {
      local_rows = block@i + 1L
      local_columns = rep.int(seq_len(ncol(block)), diff(block@p))
      block@x = block@x * row_scale[rows[local_rows]] *
        column_scale[columns[local_columns]]
      block = Matrix::drop0(block)
    }
    if (!length(block@x)) {
      stop(sprintf(
        "Sparse block %s has no coefficients; cannot build a block preconditioner",
        partition$ids[[id]]
      ), call. = FALSE)
    }
    factors[[id]] = tryCatch(
      Matrix::lu(block, order = lu_order),
      error = function(error) {
        stop(sprintf(
          "Sparse block %s factorization failed: %s",
          partition$ids[[id]], conditionMessage(error)
        ), call. = FALSE)
      }
    )
    rm(block)
    gc(verbose = FALSE)
  }
  factors
}
