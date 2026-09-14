# Keep the public native wrapper private while selecting the bounded worker path.

.GEModelR_schur_accumulate_batch_serial =
  .GEModelR_schur_accumulate_batch

.GEModelR_schur_accumulate_batch = function(
    factors, left_blocks, right_blocks, direct_external_sexp,
    regional_positions_sexp, global_positions_sexp, batch_regions_sexp,
    panel_size, threads) {
  if (as.integer(threads)[1L] > 1L) {
    return(.GEModelR_schur_accumulate_batch_parallel(
      factors, left_blocks, right_blocks, direct_external_sexp,
      regional_positions_sexp, global_positions_sexp, batch_regions_sexp,
      panel_size, threads
    ))
  }
  .GEModelR_schur_accumulate_batch_serial(
    factors, left_blocks, right_blocks, direct_external_sexp,
    regional_positions_sexp, global_positions_sexp, batch_regions_sexp,
    panel_size, threads
  )
}

.sparse_schur_cpp_symbols = c(
  .sparse_schur_cpp_symbols,
  "_GEModelR_GEModelR_schur_accumulate_batch_parallel"
)
