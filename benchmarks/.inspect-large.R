read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}
data_dir = normalizePath(".benchmark-data/GTAP 12a", mustWork = TRUE)
gtapsets = HARr::read_har(file.path(data_dir, "sets.har"))
gtapdata = HARr::read_har(file.path(data_dir, "basedata.har"))
gtapparm = HARr::read_har(file.path(data_dir, "default.prm"))
model = tabloToR::GEModel$new()
model$loadTablo(".benchmark-data/inputs/gtapv7.tab")
model$setClosure(readRDS("/tmp/tabloToR-gtap-closure.rds"))
model$loadData(
  list(gtapsets = gtapsets, gtapdata = gtapdata, gtapparm = gtapparm),
  engine = "sparse"
)
model$setShocks(readRDS("/tmp/tabloToR-gtap-shock.rds"))
estimate = model$estimateMemory(engine = "sparse", postsim = FALSE)
saveRDS(model$sparseIndex, "/tmp/tabloToR-gtap-index.rds")
saveRDS(model$sparseSpec, "/tmp/tabloToR-gtap-spec.rds")
print(estimate)
cat("equations=", model$sparseIndex$equation_count,
    " endogenous=", model$sparseIndex$endogenous_count,
    " variables=", model$sparseIndex$variable_count, "\n", sep = "")
cat("rss_hwm=", read_peak_rss(), "\n", sep = "")
invisible(NULL)

auto = tabloToR:::sparse_select_simulation_index(
  model$sparseIndex, model$sparseSpec, model$sparseState, postsim = FALSE
)
cat("auto_boundary=", ifelse(is.null(auto$simulation_boundary), NA, auto$simulation_boundary), " auto_dim=", paste(c(auto$equation_count, auto$endogenous_count), collapse = "x"), "\n", sep = "")
make_active_index = function(index, equations, closure) {
  active = index
  active$equations = index$equations[equations]
  refs = unique(unlist(lapply(active$equations, function(e) {
    vapply(e$terms, function(term) term$ref$name, character(1))
  }), use.names = FALSE))
  active$variables = Filter(function(variable) variable$name %in% refs,
                            index$variables)
  active$variable_by_name = setNames(
    as.list(seq_along(active$variables)),
    vapply(active$variables, function(variable) variable$name, character(1))
  )
  global_start = 1L
  endo_start = 1L
  for (id in seq_along(active$variables)) {
    variable = active$variables[[id]]
    variable$global_start = as.integer(global_start)
    variable$global_end = as.integer(global_start + variable$n - 1L)
    variable$exogenous = variable$name %in% closure
    if (variable$exogenous) {
      variable$endo_start = NA_integer_
    } else {
      variable$endo_start = as.integer(endo_start)
      endo_start = endo_start + variable$n
    }
    active$variables[[id]] = variable
    global_start = global_start + variable$n
  }
  active$closure_names = closure
  active$variable_count = as.integer(global_start - 1L)
  active$endogenous_count = as.integer(endo_start - 1L)
  active$row_layout_ready = FALSE
  active$pattern_cache = NULL
  active$column_order = NULL
  tabloToR:::sparse_build_row_layout(NULL, active, model$sparseState)
}

active = make_active_index(
  model$sparseIndex, seq_len(107L), model$closure
)
cat("active_equations=", active$equation_count,
    " active_endogenous=", active$endogenous_count, "\n", sep = "")
shocks = tabloToR:::sparse_resolve_shocks(
  model, model$sparseState, active
)
active$column_order = tabloToR:::sparse_lhs_column_order(
  active, model$sparseState
)
emitted = tabloToR:::sparse_emit_system(
  model$sparseState, active, shocks
)
cat("emitted_dim=", paste(dim(emitted$A), collapse = "x"),
    " nnz=", emitted$nnz, " rss_hwm=", read_peak_rss(), "\n", sep = "")
saveRDS(emitted$A, "/tmp/tabloToR-gtap-A.rds", compress = FALSE)
saveRDS(emitted$rhs, "/tmp/tabloToR-gtap-rhs.rds", compress = FALSE)
saveRDS(active, "/tmp/tabloToR-gtap-active.rds")
source("benchmarks/.coarse-tail.R")
quit(save = "no", status = 0)
b = emitted$rhs
diagonal = as.numeric(Matrix::diag(matrix))
nonzero_diagonal = diagonal[is.finite(diagonal) & diagonal != 0]
cat("diagonal_nonzero=", length(nonzero_diagonal),
    " min_abs=", min(abs(nonzero_diagonal)),
    " max_abs=", max(abs(nonzero_diagonal)), "\n", sep = "")
inv_diagonal = numeric(length(diagonal))
take = is.finite(diagonal) & abs(diagonal) > 1e-12
inv_diagonal[take] = 1 / diagonal[take]
inv_diagonal[!take] = 1
matvec = function(value) as.numeric(matrix %*% value)
norm_b = sqrt(sum(b * b))
x = numeric(length(b))
r = b
r_hat = r
p = numeric(length(b))
v = numeric(length(b))
rho_old = 1
alpha = 1
omega = 1
norm_r = sqrt(sum(r * r))
cat("bicg_start_norm=", norm_r, "\n", sep = "")
for (iteration in seq_len(50L)) {
  rho = sum(r_hat * r)
  if (!is.finite(rho) || abs(rho) < 1e-30) break
  if (iteration == 1L) {
    p = r
  } else {
    beta = (rho / rho_old) * (alpha / omega)
    p = r + beta * (p - omega * v)
  }
  p_hat = p * inv_diagonal
  v = matvec(p_hat)
  denominator = sum(r_hat * v)
  if (!is.finite(denominator) || abs(denominator) < 1e-30) break
  alpha = rho / denominator
  s = r - alpha * v
  norm_s = sqrt(sum(s * s))
  if (norm_s <= 1e-7 * max(1, norm_b)) {
    x = x + alpha * p_hat
    cat("bicg_converged_iteration=", iteration,
        " residual=", norm_s, "\n", sep = "")
    break
  }
  s_hat = s * inv_diagonal
  t = matvec(s_hat)
  tt = sum(t * t)
  if (!is.finite(tt) || tt < 1e-30) break
  omega = sum(t * s) / tt
  if (!is.finite(omega) || abs(omega) < 1e-30) break
  x = x + alpha * p_hat + omega * s_hat
  r = s - omega * t
  norm_r = sqrt(sum(r * r))
  cat("bicg_iteration=", iteration, " residual=", norm_r, "\n", sep = "")
  if (norm_r <= 1e-7 * max(1, norm_b)) break
  rho_old = rho
}
cat("bicg_final_norm=", sqrt(sum((matvec(x) - b)^2)),
    " rss_hwm=", read_peak_rss(), "\n", sep = "")
saveRDS(x, "/tmp/tabloToR-gtap-bicg-solution.rds")
quit(save = "no", status = 0)
solution = tabloToR:::solve_sparse_system(
  emitted$A, emitted$rhs, backend = "Matrix", reduction = "auto"
)
cat("solved=", length(solution), " finite=", all(is.finite(solution)),
    " rss_hwm=", read_peak_rss(), "\n", sep = "")
