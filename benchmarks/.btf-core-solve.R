library(Matrix)
z = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
d = Matrix::dmperm(z$A, nAns = 4L, seed = 0L)
sizes = diff(d$r)
block = which.max(sizes)
rows = seq.int(d$r[[block]] + 1L, d$r[[block + 1L]])
columns = seq.int(d$s[[block]] + 1L, d$s[[block + 1L]])
core = z$A[d$p[rows], d$q[columns], drop = FALSE]
rhs = z$rhs[d$p[rows]]
cat("core block", block, "dimension", nrow(core),
    "nnz", length(core@x), "\n")
start = proc.time()[[3L]]
factor = Matrix::lu(core, order = as.integer(Sys.getenv("BTF_LU_ORDER", "3")))
cat("factor seconds", proc.time()[[3L]] - start,
    "L nnz", length(factor@L@x),
    "U nnz", length(factor@U@x), "\n")
start = proc.time()[[3L]]
solution = as.numeric(Matrix::solve(factor, rhs))
cat("solve seconds", proc.time()[[3L]] - start,
    "finite", all(is.finite(solution)), "\n")
saveRDS(list(block = block, p = d$p, q = d$q, r = d$r, s = d$s,
             solution = solution),
        "/tmp/tabloToR-gtap-btf-core-solution.rds", compress = FALSE)
