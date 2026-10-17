# Keep norms factored until a ratio has been formed. The Euclidean norm
# itself need not be representable even when every entry and the ratio are.
sparse_l2_parts = function(value) {
  if (any(!is.finite(value))) {
    stop("Norm received non-finite values", call. = FALSE)
  }
  scale = if (length(value)) max(abs(value)) else 0
  list(scale = scale, unit = if (scale == 0) 0 else
    sqrt(sum((value / scale)^2)))
}

sparse_scaled_l2 = function(value) {
  parts = sparse_l2_parts(value)
  parts$scale * parts$unit
}

# Preserve ||residual|| / max(1, ||rhs||), including the absolute tolerance
# semantics for small RHS vectors. Never turn a nonzero residual into zero.
sparse_relative_l2 = function(residual, rhs, absolute_floor = 1) {
  r = sparse_l2_parts(residual)
  b = sparse_l2_parts(rhs)
  if (r$scale == 0) return(0)
  common = max(absolute_floor, r$scale, b$scale)
  ratio = ((r$scale / common) * r$unit) /
    max(absolute_floor / common, (b$scale / common) * b$unit)
  if (ratio == 0) .Machine$double.xmin * .Machine$double.eps else ratio
}

sparse_compound_percent = function(value, current) {
  if (any(!is.finite(value)) || any(!is.finite(current))) {
    stop("Compounded changes contain non-finite values", call. = FALSE)
  }
  result = value + current + value * (current / 100)
  result[value == -100 | current == -100] = -100
  if (any(!is.finite(result))) {
    stop("Compounded changes contain non-finite values", call. = FALSE)
  }
  result
}

sparse_remaining_percent = function(total, applied) {
  if (any(!is.finite(total)) || any(!is.finite(applied))) {
    stop("Remaining shocks contain non-finite values", call. = FALSE)
  }
  # Add before dividing: 1 + applied / 100 loses accuracy near -100%.
  base = (100 + applied) / 100
  remaining = (total - applied) / base
  remaining[base == 0 & total == applied] = 0
  if (any(!is.finite(remaining))) {
    stop("Remaining shocks cannot be represented as finite changes",
         call. = FALSE)
  }
  remaining
}

sparse_compound_rows = function(value) {
  result = setNames(numeric(nrow(value)), rownames(value))
  for (column in seq_len(ncol(value))) {
    result = sparse_compound_percent(result, value[, column])
  }
  result
}
