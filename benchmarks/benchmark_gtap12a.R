#!/usr/bin/env Rscript

redirect_file = grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
redirect_dir = dirname(normalizePath(sub("^--file=", "", redirect_file), mustWork = TRUE))
source(file.path(redirect_dir, "benchmark_gtap12a_run.R"))
quit(save = "no", status = 0L)


get_arg <- function(args, name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1]], fixed = TRUE)
}

get_flag <- function(args, name, default = FALSE) {
  value <- get_arg(args, name)
  if (is.null(value)) return(default)
  tolower(value) %in% c("1", "true", "yes", "y")
}

parse_integer <- function(value, default) {
  if (is.null(value)) return(default)
  parsed <- suppressWarnings(as.integer(value))
  if (is.na(parsed) || parsed < 1L) {
    stop(sprintf("%s must be a positive integer", value), call. = FALSE)
  }
  parsed
}

find_input <- function(data_dir, candidates, label) {
  paths <- file.path(data_dir, candidates)
  hit <- paths[file.exists(paths)]
  if (!length(hit)) {
    stop(sprintf(
      "Could not find %s under %s (tried %s)",
      label, data_dir, paste(candidates, collapse = ", ")
    ), call. = FALSE)
  }
  hit[[1]]
}

read_peak_rss <- function() {
  status <- tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line <- grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb <- suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}

read_physical_ram <- function() {
  info <- tryCatch(readLines("/proc/meminfo"), error = function(e) character())
  line <- grep("^MemTotal:", info, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb <- suppressWarnings(as.numeric(sub(
    "^MemTotal:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}

read_closure <- function(args) {
  closure_file <- get_arg(args, "--closure-file")
  if (!is.null(closure_file)) {
    value <- readRDS(closure_file)
    return(as.character(value))
  }
  raw <- get_arg(args, "--closure")
  if (is.null(raw) || !nzchar(raw)) {
    stop(
      "Pass --closure=var1,var2,... or --closure-file=closure.rds",
      call. = FALSE
    )
  }
  trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
}

as_metrics <- function(values) {
  data.frame(
    metric = names(values),
    value = unname(vapply(values, function(value) {
      if (length(value) != 1L || is.null(value)) NA_character_
      else as.character(value)
    }, character(1))),
    stringsAsFactors = FALSE
  )
}

args <- commandArgs(trailingOnly = TRUE)
data_dir <- normalizePath(
  get_arg(args, "--data-dir", "."),
  mustWork = TRUE
)
tablo_path <- get_arg(args, "--tablo", file.path(data_dir, "gtapv7.tab"))
if (!file.exists(tablo_path)) {
  stop(sprintf("TABLO file does not exist: %s", tablo_path), call. = FALSE)
}
closure <- read_closure(args)
iter <- parse_integer(get_arg(args, "--iter"), 3L)
steps_raw <- get_arg(args, "--steps", "1,3")
steps <- suppressWarnings(as.integer(strsplit(steps_raw, ",", fixed = TRUE)[[1]]))
if (!length(steps) || anyNA(steps) || any(steps < 1L)) {
  stop("--steps must be a comma-separated list of positive integers",
       call. = FALSE)
}
postsim <- get_flag(args, "--postsim", TRUE)
diagnostics <- get_flag(args, "--diagnostics", TRUE)
output <- get_arg(
  args, "--output",
  file.path(data_dir, "gtap12a-sparse-benchmark.csv")
)
backend <- get_arg(args, "--backend", "Matrix")
memory_budget <- get_arg(args, "--memory-budget")
if (!is.null(memory_budget)) memory_budget <- as.numeric(memory_budget)

if (!requireNamespace("HARr", quietly = TRUE)) {
  stop(
    "The benchmark requires HARr::read_har(); install/configure HARr on the target machine.",
    call. = FALSE
  )
}
if (!requireNamespace("tabloToR", quietly = TRUE)) {
  stop("Install tabloToR before running this benchmark.", call. = FALSE)
}

sets_path <- find_input(data_dir, c("sets.har", "gsdgset.har"), "GTAP sets")
data_path <- find_input(data_dir, c("basedata.har", "gsdgdat.har"), "GTAP data")
parm_path <- find_input(
  data_dir, c("default.prm", "gsdgpar.har"), "GTAP parameters"
)

read_start <- proc.time()[[3L]]
gtapsets <- HARr::read_har(sets_path)
gtapdata <- HARr::read_har(data_path)
gtapparm <- HARr::read_har(parm_path)
read_seconds <- proc.time()[[3L]] - read_start

model <- tabloToR::GEModel$new()
load_tablo_start <- proc.time()[[3L]]
model$loadTablo(tablo_path)
load_tablo_seconds <- proc.time()[[3L]] - load_tablo_start
model$setClosure(closure)
model$setMemoryBudget(memory_budget)

load_data_start <- proc.time()[[3L]]
model$loadData(
  list(gtapsets = gtapsets, gtapdata = gtapdata, gtapparm = gtapparm),
  engine = "sparse"
)
load_data_seconds <- proc.time()[[3L]] - load_data_start

shock_file <- get_arg(args, "--shocks-file")
if (!is.null(shock_file)) model$setShocks(readRDS(shock_file))

rss_before <- read_peak_rss()
solve_error <- NULL
solve_seconds <- NA_real_
solve_start <- proc.time()[[3L]]
tryCatch(
  model$solveModel(
    iter = iter,
    steps = steps,
    engine = "sparse",
    postsim = postsim,
    diagnostics = diagnostics,
    output = "compact",
    backend = backend,
    reduction = "auto",
    memory_budget = memory_budget
  ),
  error = function(error) solve_error <<- conditionMessage(error)
)
solve_seconds <- proc.time()[[3L]] - solve_start
rss_after <- read_peak_rss()

diagnostics_value <- model$lastDiagnostics
estimate <- if (length(diagnostics_value)) {
  diagnostics_value$estimated_memory
} else list()
metrics <- c(
  status = if (is.null(solve_error)) "completed" else "failed",
  error = if (is.null(solve_error)) "" else solve_error,
  data_dir = data_dir,
  tablo = tablo_path,
  engine = "sparse",
  backend = backend,
  iter = iter,
  steps = paste(steps, collapse = ","),
  postsim = postsim,
  closure_variables = length(closure),
  read_seconds = read_seconds,
  load_tablo_seconds = load_tablo_seconds,
  load_data_seconds = load_data_seconds,
  solve_seconds = solve_seconds,
  physical_ram_bytes = read_physical_ram(),
  peak_rss_before_bytes = rss_before,
  peak_rss_after_bytes = rss_after,
  equation_positions = estimate$equation_positions,
  variable_positions = estimate$variable_positions,
  endogenous_positions = estimate$endogenous_positions,
  estimated_sparse_triplets = estimate$estimated_sparse_triplets,
  estimated_peak_bytes = estimate$estimated_peak_bytes,
  max_sparse_nonzeros = diagnostics_value$max_sparse_nonzeros,
  dense_fallback = diagnostics_value$dense_fallback,
  post_simulation_retained = diagnostics_value$post_simulation_retained
)
if (length(diagnostics_value$phase_seconds)) {
  metrics <- c(metrics, diagnostics_value$phase_seconds)
}
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(as_metrics(metrics), output, row.names = FALSE, na = "")
cat(sprintf("Benchmark result written to %s\\n", output))
if (!is.null(solve_error)) stop(solve_error, call. = FALSE)
