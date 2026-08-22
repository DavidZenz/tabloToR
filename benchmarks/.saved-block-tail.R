read_peak_rss = function() {
  status = tryCatch(readLines("/proc/self/status"), error = function(e) character())
  line = grep("^VmHWM:", status, value = TRUE)
  if (!length(line)) return(NA_real_)
  kb = suppressWarnings(as.numeric(sub(
    "^VmHWM:[[:space:]]*([0-9]+)[[:space:]]*kB.*$", "\\1", line[[1]]
  )))
  if (is.na(kb)) NA_real_ else kb * 1024
}
matrix = readRDS("/tmp/tabloToR-gtap-A.rds")
b = readRDS("/tmp/tabloToR-gtap-rhs.rds")
active = readRDS("/tmp/tabloToR-gtap-active.rds")
emitted = list(A = matrix, rhs = b)
source("benchmarks/.block-all-tail.R")
