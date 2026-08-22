library(Matrix)

read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"),
                    error = function(error) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  value = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+) kB.*$", "\\1", line[[1L]]
  )))
  if (is.na(value)) NA_real_ else value * 1024
}

files = sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(files, source))
options(tabloToR.sparse.schur_progress = TRUE)

block_sequence = function(domains, index, n, set_name, variable = FALSE) {
  positions = which(vapply(domains, function(domain) {
    identical(domain$set, set_name)
  }, logical(1)))
  if (length(positions) != 1L) return(rep.int(-1L, n))
  position = positions[[1L]]
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  before = if (position == 1L) 1L else prod(lengths[seq_len(position - 1L)])
  after = if (position == length(lengths)) 1L else
    prod(lengths[(position + 1L):length(lengths)])
  if (variable) {
    as.integer(rep(rep(seq_len(lengths[[position]]), each = before),
                   times = after) - 1L)
  } else {
    as.integer(rep(rep(seq_len(lengths[[position]]), each = after),
                   times = before) - 1L)
  }
}

assign_group = function(domains, index, n, commodity_count, region_offset,
                        global_group, variable = FALSE) {
  comm = sum(vapply(domains, function(domain) {
    identical(domain$set, "comm")
  }, logical(1)))
  reg = sum(vapply(domains, function(domain) {
    identical(domain$set, "reg")
  }, logical(1)))
  if (comm == 1L) return(block_sequence(domains, index, n, "comm", variable))
  if (comm == 0L && reg == 1L) {
    return(region_offset + block_sequence(domains, index, n, "reg", variable))
  }
  if (comm == 0L && reg == 0L) return(rep.int(global_group, n))
  rep.int(-1L, n)
}

second = readRDS("/tmp/tabloToR-gtap-partial-endowment-only.rds")
first = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
commodity_count = length(active$sets$comm$values)
region_count = length(active$sets$reg$values)
region_offset = commodity_count
global_group = commodity_count + region_count
group_count = global_group + 1L

full_row_group = rep.int(-1L, active$equation_count)
for (equation in active$equations) {
  rows = seq.int(equation$row_start, equation$row_end)
  full_row_group[rows] = assign_group(
    equation$domains, active, equation$n, commodity_count, region_offset,
    global_group
  )
}
full_endogenous_group = rep.int(-1L, active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  columns = seq.int(variable$endo_start,
                    variable$endo_start + variable$n - 1L)
  full_endogenous_group[columns] = assign_group(
    variable$domains, active, variable$n, commodity_count, region_offset,
    global_group, variable = TRUE
  )
}
full_column_group = full_endogenous_group[active$column_order]
row_coords = which(first$row_group < 0L)[which(second$row_group < 0L)]
column_coords = which(first$column_group < 0L)[
  which(second$column_group < 0L)
]
row_group = as.integer(full_row_group[row_coords])
column_group = as.integer(full_column_group[column_coords])
if (any(row_group < 0L) || any(column_group < 0L)) {
  stop(sprintf("unassigned rows=%s columns=%s",
              sum(row_group < 0L), sum(column_group < 0L)))
}
cat("reduced dimension", nrow(second$A),
    "groups", group_count,
    "commodity", commodity_count,
    "regions", region_count,
    "RSS", read_peak_rss(), "\\n")

started = proc.time()[[3L]]
result = sparse_exact_schur_solve(
  second$A, second$rhs, row_group, column_group,
  local_count = commodity_count, region_count = region_count,
  global_group = global_group,
  region_batch_size = 8L, panel_size = 64L,
  restart = 80L, max_iterations = 500L, tolerance = 2e-7,
  true_residual_frequency = 1L
)
elapsed = proc.time()[[3L]] - started
cat("completed", result$converged,
    "elapsed", elapsed,
    "relative residual", result$diagnostics$true_relative_residual,
    "RSS", read_peak_rss(), "\\n")
saveRDS(list(
  solution = result$solution,
  converged = result$converged,
  diagnostics = result$diagnostics,
  elapsed_seconds = elapsed,
  peak_rss = read_peak_rss()
), "/tmp/tabloToR-gtap-schur-fgmres-result.rds", compress = FALSE)
