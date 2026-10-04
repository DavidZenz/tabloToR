# Recognized SuiteSparse backend; portable installed support is unavailable.

sparse_suite_sparse_available = function() {
  FALSE
}

sparse_suite_sparse_unavailable = function() {
  sparse_suite_sparse_guard_old_options()
  .sparse_backend_unavailable(
    "SuiteSparse",
    "SuiteSparse is not supported in installed GEModelR builds pending portable support",
    'explicitly select backend="Matrix" for a supported sparse solve'
  )
}

sparse_suite_sparse_guard_old_options = function() {
  .identity_guard_old_options(
    "tabloToR.sparse.suite_sparse_ordering"
  )
}

sparse_suite_sparse_ordering = function() {
  sparse_suite_sparse_guard_old_options()
  ordering = tolower(as.character(getOption(
    "GEModelR.sparse.suite_sparse_ordering", "amd"
  ))[1L])
  values = c(
    cholmod = 0L,
    amd = 1L,
    given = 2L,
    metis = 3L,
    best = 4L,
    natural = 5L,
    none = 5L
  )
  if (!length(ordering) || is.na(ordering) ||
      !(ordering %in% names(values)) || ordering == "given") {
    stop(
      paste(
        "GEModelR.sparse.suite_sparse_ordering must be one of",
        "cholmod, amd, metis, best, natural"
      ),
      call. = FALSE
    )
  }
  unname(values[[ordering]])
}

sparse_suite_sparse_solver = function(A, rhs) {
  sparse_suite_sparse_unavailable()
}
