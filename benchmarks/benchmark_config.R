benchmark_get_arg <- function(args, name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1L]], fixed = TRUE)
}

benchmark_flag <- function(args, name, default = FALSE) {
  value <- benchmark_get_arg(args, name)
  if (is.null(value)) return(default)
  tolower(value) %in% c("1", "true", "yes", "y")
}

benchmark_integer <- function(value, default, minimum = 0L) {
  if (is.null(value)) return(as.integer(default))
  result <- suppressWarnings(as.integer(value)[1L])
  if (is.na(result) || result < minimum) {
    stop(sprintf("Expected an integer of at least %s, got %s", minimum, value),
         call. = FALSE)
  }
  result
}

benchmark_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(file_arg)) return(normalizePath("benchmarks", mustWork = TRUE))
  dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE))
}

benchmark_hash_file <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  unname(tools::md5sum(normalizePath(path, mustWork = TRUE))[[1L]])
}

benchmark_hash_object <- function(value) {
  path <- tempfile("tabloToR-benchmark-hash-")
  on.exit(unlink(path), add = TRUE)
  saveRDS(value, path, version = 3L)
  benchmark_hash_file(path)
}

benchmark_signature <- function(value) {
  lines <- capture.output(dput(value, control = c("keepNA", "keepInteger")))
  path <- tempfile("tabloToR-benchmark-signature-")
  on.exit(unlink(path), add = TRUE)
  writeLines(lines, path, useBytes = TRUE)
  benchmark_hash_file(path)
}

benchmark_peak_rss <- function() {
  status <- tryCatch(readLines("/proc/self/status"),
                     error = function(error) character())
  line <- grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  value <- suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1L]]
  )))
  if (is.na(value)) NA_real_ else value * 1024
}

benchmark_physical_ram <- function() {
  info <- tryCatch(readLines("/proc/meminfo"),
                   error = function(error) character())
  line <- grep("^MemTotal:", info, value = TRUE)
  if (!length(line)) return(NA_real_)
  value <- suppressWarnings(as.numeric(sub(
    "^MemTotal:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1L]]
  )))
  if (is.na(value)) NA_real_ else value * 1024
}

benchmark_cpu <- function() {
  info <- tryCatch(readLines("/proc/cpuinfo"),
                   error = function(error) character())
  line <- grep("^model name", info, value = TRUE)
  if (length(line)) trimws(sub("^[^:]+:", "", line[[1L]])) else NA_character_
}

benchmark_blas <- function() {
  paths <- tryCatch(extSoftVersion(), error = function(error) character())
  paste(names(paths), paths, collapse = ";")
}

benchmark_flatten <- function(value, prefix = NULL) {
  result <- list()
  if (!is.list(value)) return(result)
  for (name in names(value)) {
    item <- value[[name]]
    key <- if (is.null(prefix)) name else paste(prefix, name, sep = ".")
    if (is.list(item)) {
      result <- c(result, benchmark_flatten(item, key))
    } else if (length(item) == 1L &&
               (is.numeric(item) || is.logical(item) || is.character(item))) {
      result[[key]] <- item
    }
  }
  result
}

benchmark_metric_frame <- function(metadata, metrics) {
  if (!length(metrics)) metrics <- list(empty = NA_character_)
  base <- as.data.frame(metadata, stringsAsFactors = FALSE)
  base <- base[rep(1L, length(metrics)), , drop = FALSE]
  base$metric <- names(metrics)
  base$value <- vapply(metrics, function(value) {
    if (!length(value) || is.null(value) || is.na(value)) "" else as.character(value)
  }, character(1))
  base$unit <- vapply(names(metrics), function(name) {
    if (grepl("seconds$", name)) "seconds"
    else if (grepl("bytes$", name)) "bytes"
    else if (grepl("residual|difference|ratio", name)) "ratio"
    else "value"
  }, character(1))
  base
}

benchmark_metric_value <- function(frame, name) {
  hit <- frame$value[frame$metric == name]
  if (!length(hit)) return(NA_real_)
  suppressWarnings(as.numeric(hit[[1L]]))
}
