library(Matrix)
library(Rcpp)

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

block_sequence = function(domains, index, n, set_name, variable = FALSE) {
  positions = which(vapply(domains, function(domain) {
    identical(domain$set, set_name)
  }, logical(1)))
  if (length(positions) != 1L) return(rep.int(-1L, n))
  position = positions[[1L]]
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  before = if (position == 1L) 1L else {
    prod(lengths[seq_len(position - 1L)])
  }
  after = if (position == length(lengths)) 1L else {
    prod(lengths[(position + 1L):length(lengths)])
  }
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
  if (comm == 1L) {
    return(block_sequence(domains, index, n, "comm", variable))
  }
  if (comm == 0L && reg == 1L) {
    return(region_offset + block_sequence(
      domains, index, n, "reg", variable
    ))
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
row_counts = tabulate(row_group + 1L, nbins = group_count)
column_counts = tabulate(column_group + 1L, nbins = group_count)
if (!identical(row_counts, column_counts)) {
  stop("mixed block partition is not square")
}
cat("dimension", nrow(second$A), "groups", group_count,
    "commodity block", row_counts[[1L]],
    "regional range", paste(range(row_counts[(region_offset + 1L):global_group]),
                             collapse = "-"),
    "global", row_counts[[global_group + 1L]], "RSS", read_peak_rss(),
    "\n")

row_scale = 1 / pmax(as.numeric(Matrix::rowSums(abs(second$A))), 1e-12)
column_scale = 1 / pmax(as.numeric(Matrix::colSums(abs(second$A))), 1e-12)
entry_columns = rep.int(seq_len(ncol(second$A)), diff(second$A@p))
entry_rows = second$A@i + 1L
coarse = Matrix::sparseMatrix(
  i = row_group[entry_rows] + 1L,
  j = column_group[entry_columns] + 1L,
  x = second$A@x * row_scale[entry_rows] *
    column_scale[entry_columns] /
    row_counts[row_group[entry_rows] + 1L],
  dims = c(group_count, group_count), repr = "C"
)
coarse = Matrix::drop0(coarse)
rm(entry_columns, entry_rows)
gc(verbose = FALSE)
cat("coarse nonzeros", length(coarse@x), "RSS", read_peak_rss(), "\n")
Rcpp::sourceCpp("benchmarks/.eigen-block-gmres.cpp", showOutput = FALSE,
                rebuild = TRUE)
cat("starting block Krylov RSS", read_peak_rss(), "\n")
result = solve_eigen_block_gmres(
  second$A, second$rhs, row_group, column_group,
  row_scale, column_scale,
  restart = 50L, max_iterations = 500L, tolerance = 1e-9,
  forward_sweep = 0L, coarse_sexp = NULL,
  coarse_row_group = integer(), coarse_column_group = integer(),
  method = 3L, direct_block_max = 0L,
  split_group = 65L
)
print(result[setdiff(names(result), "solution")])
residual = as.numeric(second$A %*% result$solution - second$rhs)
cat("true relative residual",
    sqrt(sum(residual * residual)) /
      max(1, sqrt(sum(as.numeric(second$rhs)^2))),
    "RSS", read_peak_rss(), "\n")
saveRDS(result, "/tmp/tabloToR-gtap-second-eigen-block.rds",
        compress = FALSE)
