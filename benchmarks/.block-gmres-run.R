library(Matrix)
library(Rcpp)
old_path = Sys.getenv("PATH")
Sys.setenv(PATH = paste(unique(c("/usr/bin", "/bin",
                                strsplit(old_path, ":", fixed = TRUE)[[1L]])),
                        collapse = ":"))
source("benchmarks/.level-stats.R")
sourceCpp("benchmarks/.block-gmres.cpp")

active = readRDS("/tmp/tabloToR-gtap-active.rds")
A = readRDS("/tmp/tabloToR-gtap-A.rds")
rhs = readRDS("/tmp/tabloToR-gtap-rhs.rds")

specs = levels
specs$commodity$sets = c("comm", "reg")
specs$global = list(
  sets = character(),
  variables = c("pt", "qtm", "globalcgds", "pcgdswld", "rorg"),
  equations = c("e_pt", "e_qtm", "e_globalcgds", "e_pcgdswld", "e_rorg")
)
block_profile = Sys.getenv("BLOCK_PROFILE", "default")
regional_group_offset = NA_integer_
global_group_offset = NA_integer_
paired_group_offset = NA_integer_
if (identical(block_profile, "regional-aggregate")) {
  specs = levels[c("production", "bilateral", "commodity")]
  specs$commodity$sets = c("comm", "reg")
  specs$regional = list(
    sets = c("reg"),
    variables = c(levels$endowment$variables,
                  levels$activity$variables, levels$region$variables),
    equations = c(levels$endowment$equations,
                  levels$activity$equations, levels$region$equations)
  )
  specs$global = list(
    sets = character(),
    variables = c("pt", "qtm", "globalcgds", "pcgdswld", "rorg"),
    equations = c("e_pt", "e_qtm", "e_globalcgds", "e_pcgdswld", "e_rorg")
  )
}
if (identical(block_profile, "activity-endowment")) {
  specs = levels[c("production", "bilateral", "commodity", "region")]
  specs$commodity$sets = c("comm", "reg")
  specs$activity_endowment = list(
    sets = c("acts", "reg"),
    variables = c(levels$endowment$variables, levels$activity$variables),
    equations = c(levels$endowment$equations, levels$activity$equations)
  )
  specs$global = list(
    sets = character(),
    variables = c("pt", "qtm", "globalcgds", "pcgdswld", "rorg"),
    equations = c("e_pt", "e_qtm", "e_globalcgds", "e_pcgdswld", "e_rorg")
  )
}
if (identical(block_profile, "commodity-activity")) {
  specs = levels[c("production", "bilateral", "region")]
  specs$commodity_activity = list(
    sets = character(),
    variables = c(levels$commodity$variables,
                  levels$endowment$variables, levels$activity$variables),
    equations = c(levels$commodity$equations,
                  levels$endowment$equations, levels$activity$equations)
  )
  specs$global = list(
    sets = character(),
    variables = c("pt", "qtm", "globalcgds", "pcgdswld", "rorg"),
    equations = c("e_pt", "e_qtm", "e_globalcgds", "e_pcgdswld", "e_rorg")
  )
}
if (identical(block_profile, "commodity-activity-production")) {
  specs = levels[c("bilateral", "region")]
  specs$commodity_activity_production = list(
    sets = character(),
    variables = c(levels$production$variables, levels$commodity$variables,
                  levels$endowment$variables, levels$activity$variables),
    equations = c(levels$production$equations, levels$commodity$equations,
                  levels$endowment$equations, levels$activity$equations)
  )
  specs$global = list(
    sets = character(),
    variables = c("pt", "qtm", "globalcgds", "pcgdswld", "rorg"),
    equations = c("e_pt", "e_qtm", "e_globalcgds", "e_pcgdswld", "e_rorg")
  )
}
if (block_profile %in%
    c("commodity-activity-production-region", "commodity-activity-production-bilateral")) {
  specs = levels[c("bilateral")]
  specs$commodity_activity_production = list(
    sets = character(),
    variables = c(levels$production$variables, levels$commodity$variables,
                  levels$endowment$variables, levels$activity$variables),
    equations = c(levels$production$equations, levels$commodity$equations,
                  levels$endowment$equations, levels$activity$equations)
  )
  specs$region = levels$region
  specs$global = list(
    sets = character(),
    variables = c("pt", "qtm", "globalcgds", "pcgdswld", "rorg"),
    equations = c("e_pt", "e_qtm", "e_globalcgds", "e_pcgdswld", "e_rorg")
  )
}

row_group = rep.int(-1L, active$equation_count)
column_group = rep.int(-1L, active$endogenous_count)
next_group = 0L
for (name in names(specs)) {
  spec = specs[[name]]
  groups = if (name == "global") NULL else {
    if (name == "bilateral" &&
        identical(block_profile, "commodity-activity-production-bilateral")) {
      bilateral = fill_groups(
        active, c("comm", "reg", "reg"),
        levels$bilateral$variables, levels$bilateral$equations
      )
      comm_count = length(active$sets$comm$values)
      reg_count = length(active$sets$reg$values)
      partner_region = as.integer(Sys.getenv("BLOCK_PARTNER_REG", "82"))
      if (partner_region < 0L || partner_region >= reg_count) {
        stop("BLOCK_PARTNER_REG is outside the region set")
      }
      ca_comm = rep(seq_len(comm_count) - 1L, times = reg_count)
      ca_reg = rep(seq_len(reg_count) - 1L, each = comm_count)
      selected = as.integer(
        ((ca_comm - 1L) %% comm_count) +
        comm_count * ((ca_reg - 1L) %% reg_count) +
        comm_count * reg_count * partner_region + 1L
      )
      all_ids = seq_len(bilateral$n_groups)
      remaining = setdiff(all_ids, selected)
      to_group = rep.int(-1L, bilateral$n_groups)
      to_group[remaining] = seq_along(remaining) - 1L
      to_group[selected] = length(remaining) + seq_along(selected) - 1L
      mapped_rows = bilateral$row_group
      mapped_columns = bilateral$column_group
      take = mapped_rows >= 0L
      mapped_rows[take] = to_group[mapped_rows[take] + 1L]
      take = mapped_columns >= 0L
      mapped_columns[take] = to_group[mapped_columns[take] + 1L]
      list(row_group = mapped_rows, column_group = mapped_columns,
           n_groups = length(remaining))
    } else if (name == "commodity_activity") {
      commodity = fill_groups(
        active, c("comm", "reg"), levels$commodity$variables,
        levels$commodity$equations
      )
      activity = fill_groups(
        active, c("acts", "reg"),
        c(levels$endowment$variables, levels$activity$variables),
        c(levels$endowment$equations, levels$activity$equations)
      )
      merged_rows = commodity$row_group
      merged_columns = commodity$column_group
      take = activity$row_group >= 0L
      merged_rows[take] = activity$row_group[take]
      take = activity$column_group >= 0L
      merged_columns[take] = activity$column_group[take]
      list(row_group = merged_rows, column_group = merged_columns,
           n_groups = commodity$n_groups)
    } else if (name == "commodity_activity_production") {
      commodity = fill_groups(
        active, c("comm", "reg"), levels$commodity$variables,
        levels$commodity$equations
      )
      activity = fill_groups(
        active, c("acts", "reg"),
        c(levels$endowment$variables, levels$activity$variables),
        c(levels$endowment$equations, levels$activity$equations)
      )
      production = fill_groups(
        active, c("comm", "acts", "reg"),
        levels$production$variables, levels$production$equations
      )
      ca_rows = commodity$row_group
      ca_columns = commodity$column_group
      take = activity$row_group >= 0L
      ca_rows[take] = activity$row_group[take]
      take = activity$column_group >= 0L
      ca_columns[take] = activity$column_group[take]
      comm_count = length(active$sets$comm$values)
      reg_count = length(active$sets$reg$values)
      diagonal_production = as.integer(
        rep(seq_len(reg_count) - 1L, each = comm_count) * comm_count^2 +
        rep(seq_len(comm_count) - 1L, times = reg_count) * (comm_count + 1L)
      )
      production_to_group = rep.int(-1L, production$n_groups)
      production_to_group[diagonal_production + 1L] =
        seq_len(commodity$n_groups) - 1L
      remaining = which(production_to_group < 0L)
      production_to_group[remaining] = commodity$n_groups +
        seq_along(remaining) - 1L
      take = production$row_group >= 0L
      ca_rows[take] = production_to_group[production$row_group[take] + 1L]
      take = production$column_group >= 0L
      ca_columns[take] = production_to_group[production$column_group[take] + 1L]
      list(row_group = ca_rows, column_group = ca_columns,
           n_groups = commodity$n_groups + length(remaining))
    } else fill_groups(active, spec$sets, spec$variables, spec$equations)
  }
  if (name == "global") {
    row_ids = which(vapply(active$equations, function(e) {
      e$name %in% spec$equations
    }, logical(1)))
    column_ids = which(vapply(active$variables, function(v) {
      !isTRUE(v$exogenous) && v$name %in% spec$variables
    }, logical(1)))
    group_id = if (is.finite(global_group_offset)) global_group_offset
    else if (identical(block_profile, "regional-aggregate") &&
             is.finite(regional_group_offset)) regional_group_offset
    else next_group
    for (id in row_ids) {
      e = active$equations[[id]]
      row_group[seq.int(e$row_start, e$row_end)] = group_id
    }
    inverse = integer(active$endogenous_count)
    inverse[active$column_order] = seq_along(active$column_order)
    for (id in column_ids) {
      v = active$variables[[id]]
      positions = seq.int(v$endo_start, length.out = v$n)
      column_group[inverse[positions]] = group_id
    }
    if (!is.finite(global_group_offset) &&
        !(identical(block_profile, "regional-aggregate") &&
          is.finite(regional_group_offset))) {
      next_group = next_group + 1L
    }
  } else {
    if (name == "regional") regional_group_offset = next_group
    if (name == "regional" && identical(block_profile, "regional-aggregate")) {
      global_group_offset = next_group
    }
    if (name == "region" &&
        block_profile %in% c("activity-endowment", "commodity-activity",
                             "commodity-activity-production")) {
      global_group_offset = next_group
    }
    if (name == "commodity_activity_production" &&
        block_profile %in%
        c("commodity-activity-production-region", "commodity-activity-production-bilateral")) {
      paired_group_offset = next_group
    }
    if (name == "region" &&
        block_profile %in%
        c("commodity-activity-production-region", "commodity-activity-production-bilateral")) {
      if (!is.finite(paired_group_offset)) stop("paired groups not initialized")
      comm_count = length(active$sets$comm$values)
      take_rows = groups$row_group >= 0L
      take_columns = groups$column_group >= 0L
      row_group[take_rows] = paired_group_offset +
        groups$row_group[take_rows] * comm_count
      column_group[take_columns] = paired_group_offset +
        groups$column_group[take_columns] * comm_count
      global_group_offset = paired_group_offset
      next
    }
    allow_pair_overlap =
      name == "commodity_activity_production" &&
      identical(block_profile, "commodity-activity-production-bilateral")
    if (!allow_pair_overlap &&
        (any(groups$row_group >= 0L & row_group >= 0L) ||
        any(groups$column_group >= 0L & column_group >= 0L))) {
      stop(sprintf("overlapping block family in %s", name))
    }
    take_rows = groups$row_group >= 0L
    take_columns = groups$column_group >= 0L
    row_group[take_rows] = groups$row_group[take_rows] + next_group
    column_group[take_columns] = groups$column_group[take_columns] + next_group
    next_group = next_group + groups$n_groups
  }
}
if (any(row_group < 0L) || any(column_group < 0L)) {
  stop(sprintf("unassigned rows=%s columns=%s",
              sum(row_group < 0L), sum(column_group < 0L)))
}
cat("blocks", next_group, "rows", length(row_group),
    "columns", length(column_group), "\n")
print(summary(as.numeric(tabulate(row_group, nbins = next_group))))
if (identical(Sys.getenv("BLOCK_DUMP"), "1")) {
  saveRDS(list(row_group = row_group, column_group = column_group,
               n_groups = next_group),
          "/tmp/tabloToR-gtap-block-groups.rds", compress = FALSE)
  quit(save = "no", status = 0)
}

block_max_iterations = as.integer(Sys.getenv("BLOCK_MAX_ITER", "50"))
block_restart = as.integer(Sys.getenv("BLOCK_RESTART", "10"))
block_shift = as.numeric(Sys.getenv("BLOCK_SHIFT", "0"))
block_smoothing = as.integer(Sys.getenv("BLOCK_SMOOTHING", "1"))
block_sweep = as.integer(Sys.getenv("BLOCK_SWEEP", "0"))
block_method = as.integer(Sys.getenv("BLOCK_METHOD", "0"))
block_split = as.integer(Sys.getenv("BLOCK_SPLIT", "0"))
block_equilibration = as.integer(Sys.getenv("BLOCK_EQ", "1"))
result = solve_block_gmres(
  A, rhs, row_group, column_group, next_group,
  restart = block_restart, max_iterations = block_max_iterations, tolerance = 1e-7,
  pivot_tolerance = 1e-10, diagonal_shift = block_shift,
  equilibration = block_equilibration, smoothing = block_smoothing, sweep = block_sweep,
  method = block_method, split_group = block_split
)
print(result[setdiff(names(result), c("solution", "singular_group_ids"))])
saveRDS(result, "/tmp/tabloToR-gtap-block-gmres-hierarchical.rds", compress = FALSE)
