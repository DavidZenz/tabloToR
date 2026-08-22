library(Matrix)
library(Rcpp)
source("R/sparseSuiteSparse.R")
reduced = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
options(tabloToR.sparse.suite_sparse_ordering =
          Sys.getenv("REDUCED_UMFPACK_ORDER", "amd"))
cat("reduced", nrow(reduced$A), "x", ncol(reduced$A),
    "nnz", length(reduced$A@x), "ordering",
    getOption("tabloToR.sparse.suite_sparse_ordering"), "\n")
start = proc.time()[[3L]]
solution = sparse_suite_sparse_solver(reduced$A, reduced$rhs)
cat("solve seconds", proc.time()[[3L]] - start,
    "finite", all(is.finite(solution)), "\n")
saveRDS(solution, "/tmp/tabloToR-gtap-reduced-umfpack-solution.rds",
        compress = FALSE)
