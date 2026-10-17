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
sparse_relative_l2 = function(residual, rhs) {
  r = sparse_l2_parts(residual)
  b = sparse_l2_parts(rhs)
  if (r$scale == 0) return(0)
  common = max(1, r$scale, b$scale)
  ratio = ((r$scale / common) * r$unit) /
    max(1 / common, (b$scale / common) * b$unit)
  if (ratio == 0) .Machine$double.xmin * .Machine$double.eps else ratio
}
