library(Matrix)
library(Rcpp)
old_cppflags = Sys.getenv("PKG_CPPFLAGS")
old_libs = Sys.getenv("PKG_LIBS")
old_path = Sys.getenv("PATH")
Sys.setenv(
  PKG_CPPFLAGS = paste(old_cppflags, "-I/usr/include/suitesparse"),
  PKG_LIBS = paste(old_libs,
                   "-lklu -lamd -lcolamd -lbtf -lsuitesparseconfig -lblas"),
  PATH = paste(unique(c("/usr/bin", "/bin",
                        strsplit(old_path, ":", fixed = TRUE)[[1L]])),
               collapse = ":")
)
code = paste(c(
  "#include <Rcpp.h>",
  "#include <klu.h>",
  "// [[Rcpp::export]]",
  "Rcpp::NumericVector tabloToR_klu_solve(Rcpp::S4 A, Rcpp::NumericVector rhs) {",
  "  Rcpp::IntegerVector p = A.slot(\"p\");",
  "  Rcpp::IntegerVector i = A.slot(\"i\");",
  "  Rcpp::IntegerVector d = A.slot(\"Dim\");",
  "  Rcpp::NumericVector x = A.slot(\"x\");",
  "  int n = d[0];",
  "  if (d[1] != n || rhs.size() != n) Rcpp::stop(\"invalid KLU dimensions\");",
  "  klu_common common;",
  "  if (!klu_defaults(&common)) Rcpp::stop(\"KLU defaults failed\");",
  "  common.tol = 0.0;",
  "  klu_symbolic *symbolic = klu_analyze(n, p.begin(), i.begin(), &common);",
  "  if (symbolic == NULL) Rcpp::stop(\"KLU symbolic analysis failed\");",
  "  klu_numeric *numeric = klu_factor(p.begin(), i.begin(), x.begin(), symbolic, &common);",
  "  if (numeric == NULL) { klu_free_symbolic(&symbolic, &common); Rcpp::stop(\"KLU numeric factorization failed\"); }",
  "  Rcpp::NumericVector result = Rcpp::clone(rhs);",
  "  int ok = klu_solve(symbolic, numeric, n, 1, result.begin(), &common);",
  "  klu_free_numeric(&numeric, &common);",
  "  klu_free_symbolic(&symbolic, &common);",
  "  if (!ok) Rcpp::stop(\"KLU solve failed\");",
  "  return result;",
  "}"
), collapse = "\n")
Rcpp::sourceCpp(code = code, showOutput = FALSE)
reduced = readRDS("/tmp/tabloToR-gtap-reduced-pb.rds")
cat("reduced", nrow(reduced$A), "x", ncol(reduced$A),
    "nnz", length(reduced$A@x), "\n")
start = proc.time()[[3L]]
solution = tabloToR_klu_solve(reduced$A, reduced$rhs)
cat("solve seconds", proc.time()[[3L]] - start,
    "finite", all(is.finite(solution)), "\n")
saveRDS(solution, "/tmp/tabloToR-gtap-reduced-klu-solution.rds",
        compress = FALSE)
