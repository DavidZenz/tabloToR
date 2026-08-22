library(Matrix)

A = readRDS("/tmp/tabloToR-gtap-A.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")

domain_group = function(domains, index, set, variable = FALSE) {
  p = which(vapply(domains, function(d) identical(d$set, set), logical(1)))
  lengths = vapply(domains, function(d) length(index$sets[[d$set]]$values), integer(1))
  if (!length(p)) return(rep(0L, prod(lengths)))
  p = p[[1L]]
  before = if (p == 1L) 1 else prod(lengths[seq_len(p - 1L)])
  after = if (p == length(lengths)) 1 else prod(lengths[(p + 1L):length(lengths)])
  if (variable) as.integer(rep(rep(seq_len(lengths[[p]]), each = before), times = after)) else
    as.integer(rep(rep(seq_len(lengths[[p]]), each = after), times = before))
}

row_group = integer(nrow(A))
for (equation in active$equations) {
  rows = seq.int(equation$row_start, equation$row_end)
  row_group[rows] = domain_group(equation$domains, active, "comm")
}
variable_group = integer(active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  positions = seq.int(variable$endo_start, variable$endo_start + variable$n - 1L)
  variable_group[positions] = domain_group(
    variable$domains, active, "comm", variable = TRUE
  )
}
column_group = variable_group[active$column_order]
global_rows = which(row_group == 0L)
global_columns = which(column_group == 0L)
G = A[global_rows, global_columns, drop = FALSE]
cat("global_dim=", nrow(G), "x", ncol(G), " nnz=", length(G@x), "\n", sep = "")
dm = Matrix::dmperm(G)
cat("row_breaks=", paste(head(dm$r, 20L), collapse = ","),
    "... count=", length(dm$r) - 1L, "\n", sep = "")
cat("col_breaks=", paste(head(dm$s, 20L), collapse = ","),
    "... count=", length(dm$s) - 1L, "\n", sep = "")
saveRDS(dm, "/tmp/tabloToR-gtap-global-dmperm.rds", compress = FALSE)
