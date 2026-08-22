library(Matrix)
library(Rcpp)
sourceCpp("benchmarks/.matrix-incidence.cpp", showOutput = FALSE)
A = readRDS("/tmp/tabloToR-gtap-A.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
domain_blocks = function(domains, index, set, variable = FALSE) {
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
  row_comm[rows] = domain_blocks(equation$domains, active, "comm")
  row_reg[rows] = domain_blocks(equation$domains, active, "reg")
}
variable_comm = integer(active$endogenous_count); variable_reg = integer(active$endogenous_count)
for (variable in active$variables) {
  if (isTRUE(variable$exogenous)) next
  positions = seq.int(variable$endo_start, variable$endo_start + variable$n - 1L)
  variable_comm[positions] = domain_blocks(variable$domains, active, "comm", TRUE)
  variable_reg[positions] = domain_blocks(variable$domains, active, "reg", TRUE)
}
column_comm = variable_comm[active$column_order]
column_reg = variable_reg[active$column_order]
row_group = ifelse(row_comm > 0L, row_comm, ifelse(row_reg > 0L, 65L + row_reg, 0L))
column_group = ifelse(column_comm > 0L, column_comm, ifelse(column_reg > 0L, 65L + column_reg, 0L))
incidence = matrix_incidence(
  A, as.integer(row_group + 1L), as.integer(column_group + 1L),
  as.integer(row_group + 1L), as.integer(column_group + 1L), 230L, 230L
)$region
graph = Matrix(incidence > 0, sparse = TRUE)
dm = Matrix::dmperm(graph)
rs = diff(dm$r); cs = diff(dm$s)
ord = order(pmax(rs, cs), decreasing = TRUE)
cat("block_edges=", sum(incidence > 0), "blocks=", length(rs),
    "max_scc_rows=", max(rs), "max_scc_cols=", max(cs), "\n", sep = "")
for (k in head(ord, 20L)) cat(k, " rows=", rs[k], " cols=", cs[k], "\n", sep = "")
saveRDS(incidence, "/tmp/tabloToR-gtap-commodity-regional-graph.rds", compress = FALSE)
