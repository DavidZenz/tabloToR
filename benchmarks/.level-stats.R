library(Matrix)
library(Rcpp)
old_path = Sys.getenv("PATH")
Sys.setenv(PATH = paste(unique(c("/usr/bin", "/bin",
                                strsplit(old_path, ":", fixed = TRUE)[[1L]])),
                        collapse = ":"))
source("R/sparsePartition.R")
sourceCpp("benchmarks/.block-stats.cpp")

active = readRDS("/tmp/tabloToR-gtap-active.rds")

domain_key = function(domains) {
  paste(vapply(domains, function(domain) domain$set, character(1)), collapse = ",")
}

group_sequence = function(domains, index, selected_sets, n, variable = FALSE) {
  if (!length(domains)) return(rep.int(0L, n))
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  seen = list()
  values = vector("list", length(selected_sets))
  for (id in seq_along(selected_sets)) {
    set_name = selected_sets[[id]]
    occurrence = if (is.null(seen[[set_name]])) 1L else seen[[set_name]] + 1L
    seen[[set_name]] = occurrence
    positions = which(vapply(domains, function(domain) {
      identical(domain$set, set_name)
    }, logical(1)))
    if (length(positions) < occurrence) return(rep.int(0L, n))
    position = positions[[occurrence]]
    before = if (position == 1L) 1 else prod(lengths[seq_len(position - 1L)])
    after = if (position == length(lengths)) 1 else
      prod(lengths[(position + 1L):length(lengths)])
    values[[id]] = if (variable) {
      as.integer(rep(rep(seq_len(lengths[[position]]), each = before),
                     times = after))
    } else {
      as.integer(rep(rep(seq_len(lengths[[position]]), each = after),
                     times = before))
    }
  }
  code = numeric(n)
  multiplier = 1
  for (id in seq_along(selected_sets)) {
    code = code + values[[id]] * multiplier
    multiplier = multiplier * (length(index$sets[[selected_sets[[id]]]]$values) + 1)
  }
  as.integer(code)
}

fill_groups = function(index, selected_sets, variable_names, equation_names) {
  n = index$endogenous_count
  inverse = integer(n)
  inverse[index$column_order] = seq_len(n)
  row_group = rep.int(-1L, index$equation_count)
  col_group = rep.int(-1L, n)
  for (equation in index$equations) {
    if (!(equation$name %in% equation_names)) next
    rows = seq.int(equation$row_start, equation$row_end)
    values = group_sequence(equation$domains, index, selected_sets,
                            equation$n, variable = FALSE)
    if (any(values == 0L)) {
      stop(sprintf("Equation %s has an unindexed block", equation$name))
    }
    row_group[rows] = values
  }
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous) || !(variable$name %in% variable_names)) next
    positions = seq.int(variable$endo_start, length.out = variable$n)
    columns = inverse[positions]
    values = group_sequence(variable$domains, index, selected_sets,
                            variable$n, variable = TRUE)
    if (any(values == 0L)) {
      stop(sprintf("Variable %s has an unindexed block", variable$name))
    }
    col_group[columns] = values
  }
  row_values = sort(unique(row_group[row_group >= 0L]))
  col_values = sort(unique(col_group[col_group >= 0L]))
  if (!identical(row_values, col_values)) {
    stop("row/column group IDs do not match")
  }
  remap = integer(max(c(row_values, col_values)) + 1L)
  remap[row_values + 1L] = seq_along(row_values) - 1L
  row_group[row_group >= 0L] = remap[row_group[row_group >= 0L] + 1L]
  col_group[col_group >= 0L] = remap[col_group[col_group >= 0L] + 1L]
  list(row_group = as.integer(row_group), column_group = as.integer(col_group),
       n_groups = length(row_values))
}

levels = list(
  production = list(
    sets = c("comm", "acts", "reg"),
    variables = c("qfd", "qfm", "pfd", "pfm", "ps", "qca", "pca", "pfa", "qfa", "afa"),
    equations = c("e_qfa", "e_qfd", "e_qfm", "e_pfa", "e_afa", "e_qca", "e_ps", "e_pca", "e_pfd", "e_pfm")
  ),
  endowment = list(
    sets = c("acts", "reg"),
    variables = c("pes", "qes", "peb", "qfe", "pfe", "afe"),
    equations = c("e_qfe", "e_afe", "e_pfe", "e_pes", "e_peb", "e_qes1", "e_qes2", "e_qes3")
  ),
  bilateral = list(
    sets = c("comm", "reg", "reg"),
    variables = c("qxs", "pfob", "pcif", "pmds", "ptrans", "qtmfsd", "atmfsd"),
    equations = c("e_qxs", "e_ptrans", "e_pfob", "e_pcif", "e_pmds", "e_qtmfsd", "e_atmfsd")
  ),
  commodity = list(
    sets = c("reg"),
    variables = c("pds", "pms", "qgd", "qgm", "pgd", "pgm", "qpd", "qpm", "ppd", "ppm", "qid", "qim", "pid", "pim", "qms", "qc", "ppa", "qpa", "pga", "qga", "pia", "qia", "pr", "qds", "tpd", "tpm"),
    equations = c("e_qc", "e_qpa", "e_qpd", "e_qpm", "e_ppa", "e_qga", "e_qgd", "e_qgm", "e_pga", "e_qia", "e_qid", "e_qim", "e_pia", "e_qms", "e_pms", "e_pr", "e_qds", "e_pds", "e_ppd", "e_ppm", "e_pgd", "e_pgm", "e_pid", "e_pim", "e_tpd", "e_tpm")
  ),
  activity = list(
    sets = c("acts", "reg"),
    variables = c("po", "qo", "ao", "pint", "qint", "aint", "pva", "qva", "ava", "pb"),
    equations = c("e_qint", "e_qva", "e_qo", "e_pint", "e_pva", "e_ao", "e_ava", "e_aint", "e_po", "e_pb")
  ),
  region = list(
    sets = c("reg"),
    variables = c("psave", "qsave", "pinv", "kb", "y", "pgov", "yg", "ug", "ppriv", "yp", "uepriv", "up", "fincome", "del_indtaxr", "uelas", "dpav", "p", "dpsum", "u", "qpriv", "qgov", "qinv", "ke", "rore", "rorc", "rental", "del_taxrout", "del_taxrfu", "del_taxriu", "del_taxrpc", "del_taxrgc", "del_taxric", "del_taxrexp", "del_taxrimp", "del_taxrinc", "del_ttaxr", "pfactor", "qst", "pe", "expand"),
    equations = c("e_fincome", "e_y", "e_qsave", "e_yg", "e_yp", "e_uelas", "e_dpav", "e_p", "e_u", "e_dpsum", "e_uepriv", "e_ppriv", "e_qpriv", "e_up", "e_pgov", "e_qgov", "e_ug", "e_pinv", "e_ke", "e_rental", "e_rorc", "e_kb", "e_rore", "e_qinv", "e_psave", "e_del_taxrout", "e_del_taxrfu", "e_del_taxriu", "e_del_taxrpc", "e_del_taxrgc", "e_del_taxric", "e_del_taxrexp", "e_del_taxrimp", "e_del_taxrinc", "e_del_indtaxr", "e_del_ttaxr", "e_pfactor", "e_qst", "e_pe1", "e_pe2", "e_expand")
  )
)

if (identical(Sys.getenv("RUN_LEVEL_STATS"), "1")) for (name in names(levels)) {
  spec = levels[[name]]
  groups = fill_groups(active, spec$sets, spec$variables, spec$equations)
  cat("level", name, "groups", groups$n_groups,
      "Lrows", sum(groups$row_group >= 0L),
      "Lcols", sum(groups$column_group >= 0L), "\n")
  stats = block_schur_stats(
    readRDS("/tmp/tabloToR-gtap-A.rds"),
    groups$row_group, groups$column_group, groups$n_groups
  )
  print(stats[c("b_nnz", "c_nnz", "d_nnz", "cross_l", "product_upper", "max_b_columns", "max_c_rows")])
  if (stats$cross_l > 0) {
    print(data.frame(row = stats$cross_rows, col = stats$cross_cols,
                     row_group = stats$cross_row_groups,
                     col_group = stats$cross_col_groups))
  }
}
