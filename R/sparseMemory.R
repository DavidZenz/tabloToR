# Simultaneously live storage for the structured Schur construction. Counts
# use the original partition, conservatively including rows later eliminated.
# Sparse LU fill remains an estimate; dense blocks and worker buffers are
# explicit allocations and must not be omitted from the preflight guard.
sparse_schur_memory = function(partition, backend) {
  zero = list(dense_matrix_bytes = 0, dense_factor_bytes = 0,
              dense_workspace_bytes = 0, coupling_bytes = 0,
              worker_workspace_bytes = 0, krylov_bytes = 0,
              sparse_factor_scratch_bytes = 0)
  external = partition$external
  if (is.null(external) || !backend %in%
      c("StructuredSchurFGMRES", "StructuredSchurFGMRESCpp")) return(zero)
  counts = tabulate(external$row_group + 1L,
                    nbins = external$global_group + 1L)
  local = counts[seq_len(external$commodity_count)]
  regional = counts[external$commodity_count + seq_len(external$region_count)]
  global = counts[external$global_group + 1L]
  panel = as.double(getOption("GEModelR.sparse.schur_panel_size", 64L))
  threads = if (backend == "StructuredSchurFGMRESCpp")
    as.double(getOption("GEModelR.sparse.schur_cpp_threads", 1L)) else 1
  restart = as.double(getOption("GEModelR.sparse.schur_restart", 80L))
  if (any(!is.finite(c(panel, threads, restart))) ||
      any(c(panel, threads, restart) < 1)) {
    stop("Schur workspace options must be positive finite values", call. = FALSE)
  }
  list(
    dense_matrix_bytes = 8 * (sum(as.double(regional)^2) + global^2),
    dense_factor_bytes = 8 * (sum(as.double(regional)^2) + global^2) +
      4 * (sum(regional) + global),
    dense_workspace_bytes = 16 * (max(c(0, regional))^2 + global^2),
    coupling_bytes = 8 * 4 * sum(regional) * global,
    worker_workspace_bytes = 8 * min(threads, max(1, length(regional))) * panel *
      (2 * max(c(0, local)) + sum(regional) + global),
    krylov_bytes = 8 * (sum(regional) + global) * (2 * restart + 4),
    # Sparse factor payload/fill is estimated separately from triplet capacity
    # in sparse_estimate_memory(). Add permutations, diagonal views and the
    # bounded 32-RHS native workspace here. Original group counts can include
    # millions of rows removed before Schur construction; do not assume dense
    # factors of those original dimensions will be allocated.
    sparse_factor_scratch_bytes = (24 + 8 * 32) * sum(local)
  )
}
