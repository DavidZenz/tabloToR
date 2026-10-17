#!/usr/bin/env Rscript
# Each invocation starts with one installed package. A seeded run changes only
# file order; testthat's shuffle=TRUE also shuffles helper declarations.
main = function() {
  library_path = Sys.getenv("REPAIR_LIBRARY")
  if (!nzchar(library_path)) stop("Set REPAIR_LIBRARY to an installed library")
  .libPaths(c(library_path, Sys.getenv("REPAIR_DEPENDENCIES"), .libPaths()))
  seed = Sys.getenv("REPAIR_ORDER_SEED")
  if (nzchar(seed)) {
    seed = suppressWarnings(as.integer(seed))
    if (length(seed) != 1L || is.na(seed)) stop("REPAIR_ORDER_SEED must be an integer")
    temporary = tempfile("GEModelR-test-order-")
    dir.create(temporary)
    on.exit(unlink(temporary, recursive = TRUE), add = TRUE)
    package_path = find.package("GEModelR", lib.loc = library_path)
    stopifnot(file.copy(package_path, temporary, recursive = TRUE))
    directory = file.path(temporary, "GEModelR", "tests", "testthat")
    files = list.files(directory, pattern = "^test-.*[.]R$", full.names = TRUE)
    set.seed(seed)
    files = sample(files)
    for (i in seq_along(files)) {
      target = file.path(directory, sprintf("test-%03d-%s", i,
                                            sub("^test-", "", basename(files[i]))))
      stopifnot(file.rename(files[i], target))
    }
    .libPaths(c(temporary, .libPaths()))
  }
  library(GEModelR)
  filter = Sys.getenv("REPAIR_FILTER")
  if (!nzchar(filter)) filter = NULL
  result = testthat::test_package("GEModelR", filter = filter,
                                  reporter = "summary", stop_on_failure = FALSE)
  destination = Sys.getenv("REPAIR_RESULTS")
  if (nzchar(destination)) saveRDS(result, destination)
  tab = as.data.frame(result)
  cat(sprintf("RESULT: %s passed, %s failed assertions, %s errors, %s skips\n",
              sum(tab$passed), sum(tab$failed), sum(tab$error), sum(tab$skipped)))
  if (any(tab$failed > 0 | tab$error)) stop("Repair verification failed")
  invisible(result)
}
main()
