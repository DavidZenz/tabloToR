library(Matrix)
reduced = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
A = reduced$A
rhs = reduced$rhs
cat("reduced", nrow(A), "x", ncol(A), "nnz", length(A@x), "\n")
start = proc.time()[[3L]]
factor = Matrix::lu(A, order = as.integer(Sys.getenv("REDUCED_LU_ORDER", "3")))
factor_time = proc.time()[[3L]] - start
cat("factor seconds", factor_time,
    "L nnz", length(factor@L@x),
    "U nnz", length(factor@U@x),
    "\n")
start = proc.time()[[3L]]
solution = as.numeric(Matrix::solve(factor, rhs))
cat("solve seconds", proc.time()[[3L]] - start,
    "finite", all(is.finite(solution)), "\n")
saveRDS(solution, "/tmp/tabloToR-gtap-reduced-solution.rds", compress = FALSE)
rm(factor, A, rhs, reduced)
gc(verbose = FALSE)
