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
row_comm = integer(nrow(A)); row_reg = integer(nrow(A))
for (equation in active$equations) {
  rows = seq.int(equation$row_start, equation$row_end)
  row_comm[rows] = domain_group(equation$domains, active, "comm")
  row_reg[rows] = domain_group(equation$domains, active, "reg")
}
variable_comm = integer(active$endogenous_count); variable_reg = integer(active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  positions = seq.int(variable$endo_start, variable$endo_start + variable$n - 1L)
  domains = variable$domains
  variable_comm[positions] = domain_group(domains, active, "comm", TRUE)
  variable_reg[positions] = domain_group(domains, active, "reg", TRUE)
}
col_comm = variable_comm[active$column_order]
col_reg = variable_reg[active$column_order]
rows = which(row_comm == 0L & row_reg > 0L)
cols = which(col_comm == 0L & col_reg > 0L)
G = A[rows, cols, drop = FALSE]
cat("region-only_dim=", nrow(G), "x", ncol(G), " nnz=", length(G@x), "\n", sep = "")
dm = Matrix::dmperm(G)
rs = diff(dm$r); cs = diff(dm$s)
ord = order(pmax(rs, cs), decreasing = TRUE)
cat("blocks=", length(rs), "maxrow=", max(rs), "maxcol=", max(cs),
    "singleton=", sum(rs == 1L), "\n", sep = "")
for (k in head(ord, 20L)) cat(k, " rows=", rs[k], " cols=", cs[k], "\n", sep = "")
