#!/usr/bin/env Rscript

phase02_accept_wrapper_path = local({
  file_argument = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_argument)) {
    normalizePath(sub("^--file=", "", file_argument[[1L]]), mustWork = TRUE)
  } else {
    source_file = tryCatch(sys.frame(1L)$ofile, error = function(error) NULL)
    if (is.null(source_file)) NA_character_ else
      normalizePath(source_file, mustWork = TRUE)
  }
})

if (is.na(phase02_accept_wrapper_path)) {
  stop("Could not locate the Phase 02 acceptance wrapper", call. = FALSE)
}
phase02_accept_wrapper_root = dirname(dirname(phase02_accept_wrapper_path))
sys.source(
  file.path(phase02_accept_wrapper_root, "inst", "tools",
            "accept_phase02_baselines.R"),
  envir = environment()
)

if (sys.nframe() == 0L) phase02_accept_main()
