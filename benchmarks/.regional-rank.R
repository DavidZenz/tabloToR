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
scaled = Matrix::Diagonal(x = row_scale) %*% second$A %*%
  Matrix::Diagonal(x = column_scale)
rows_by_group = lapply(0:global_group, function(id) which(row_group == id))
columns_by_group = lapply(0:global_group, function(id) which(column_group == id))
local_lu = vector("list", commodity_count)
for (group in 0:(commodity_count - 1L)) {
  local_rows = rows_by_group[[group + 1L]]
  local_columns = columns_by_group[[group + 1L]]
  local_lu[[group + 1L]] = Matrix::lu(
    scaled[local_rows, local_columns, drop = FALSE]
  )
}
rm(local_rows, local_columns)
blocks = vector("list", region_count + 1L)
batch_size = 8L
external_ids = commodity_count:(commodity_count + region_count)
for (batch_start in seq.int(1L, length(external_ids), by = batch_size)) {
  batch_end = min(batch_start + batch_size - 1L, length(external_ids))
  ids = external_ids[batch_start:batch_end]
  batch_rows = lapply(ids, function(id) rows_by_group[[id + 1L]])
  batch_columns = lapply(ids, function(id) columns_by_group[[id + 1L]])
  batch_columns_all = unlist(batch_columns, use.names = FALSE)
  column_offsets = c(0L, cumsum(vapply(batch_columns, length, integer(1))))
  blocks_batch = lapply(seq_along(ids), function(j) {
    as.matrix(scaled[batch_rows[[j]], batch_columns[[j]], drop = FALSE])
  })
  for (group in 0:(commodity_count - 1L)) {
    local_rows = rows_by_group[[group + 1L]]
    local_columns = columns_by_group[[group + 1L]]
    local_rhs = as.matrix(scaled[local_rows, batch_columns_all, drop = FALSE])
    local_solution = solve(local_lu[[group + 1L]], local_rhs)
    for (j in seq_along(ids)) {
      column_range = (column_offsets[[j]] + 1L):column_offsets[[j + 1L]]
      correction = scaled[batch_rows[[j]], local_columns, drop = FALSE] %*%
        local_solution[, column_range, drop = FALSE]
      blocks_batch[[j]] = blocks_batch[[j]] - as.matrix(correction)
    }
    rm(local_rows, local_columns, local_rhs, local_solution, correction)
  }
  for (j in seq_along(ids)) {
    blocks[[ids[[j]] - commodity_count + 1L]] = blocks_batch[[j]]
  }
  cat("Schur diagonal blocks", batch_start, "-", batch_end,
      "/", length(external_ids), "RSS", read_peak_rss(), "\n")
  rm(ids, batch_rows, batch_columns, batch_columns_all, column_offsets,
     blocks_batch)
}
saveRDS(list(blocks = blocks, row_scale = row_scale,
             column_scale = column_scale),
        "/tmp/tabloToR-gtap-schur-diagonal.rds", compress = FALSE)
