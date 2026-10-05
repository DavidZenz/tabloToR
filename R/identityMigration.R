.identity_public_option_replacements = c(
  "tabloToR.serialization.max_bytes" =
    "GEModelR.serialization.max_bytes",
  "tabloToR.serialization.max_elements" =
    "GEModelR.serialization.max_elements",
  "tabloToR.sparse.lu_order" = "GEModelR.sparse.lu_order",
  "tabloToR.sparse.schur_cpp_threads" =
    "GEModelR.sparse.schur_cpp_threads",
  "tabloToR.sparse.schur_max_iterations" =
    "GEModelR.sparse.schur_max_iterations",
  "tabloToR.sparse.schur_panel_size" =
    "GEModelR.sparse.schur_panel_size",
  "tabloToR.sparse.schur_refinement_iterations" =
    "GEModelR.sparse.schur_refinement_iterations",
  "tabloToR.sparse.schur_region_batch_size" =
    "GEModelR.sparse.schur_region_batch_size",
  "tabloToR.sparse.schur_restart" =
    "GEModelR.sparse.schur_restart",
  "tabloToR.sparse.schur_tolerance" =
    "GEModelR.sparse.schur_tolerance",
  "tabloToR.sparse.structured_residual_tolerance" =
    "GEModelR.sparse.structured_residual_tolerance",
  "tabloToR.sparse.suite_sparse_ordering" =
    "GEModelR.sparse.suite_sparse_ordering"
)

.identity_option_stop = function(old_key, replacement) {
  stop(sprintf(
    paste(
      "Option '%s' is no longer supported.",
      "Use '%s' instead; see MIGRATION.md."
    ),
    old_key, replacement
  ), call. = FALSE)
}

.identity_guard_old_options = function(
    old_keys, .options = options()) {
  old_keys = as.character(old_keys)
  unknown = setdiff(old_keys, names(.identity_public_option_replacements))
  if (length(unknown)) {
    stop(sprintf(
      "Unknown public option migration key: %s", unknown[[1L]]
    ), call. = FALSE)
  }
  present = old_keys[old_keys %in% names(.options)]
  if (length(present)) {
    old_key = present[[1L]]
    .identity_option_stop(
      old_key, .identity_public_option_replacements[[old_key]]
    )
  }
  invisible(NULL)
}
