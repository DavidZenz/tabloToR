# Optional SuiteSparse/UMFPACK backend for the sparse execution engine.

sparse_suite_sparse_available = function() {
  if (!requireNamespace("Rcpp", quietly = TRUE)) return(FALSE)
  if (!file.exists("/usr/include/suitesparse/umfpack.h")) return(FALSE)
  library_candidates = c(
    "/lib/x86_64-linux-gnu/libumfpack.so",
    "/lib/x86_64-linux-gnu/libumfpack.so.5",
    "/usr/lib/x86_64-linux-gnu/libumfpack.so",
    "/usr/lib/x86_64-linux-gnu/libumfpack.so.5"
  )
  any(file.exists(library_candidates))
}

sparse_suite_sparse_ordering = function() {
  ordering = tolower(as.character(getOption(
    "tabloToR.sparse.suite_sparse_ordering", "amd"
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
        "tabloToR.sparse.suite_sparse_ordering must be one of",
        "cholmod, amd, metis, best, natural"
      ),
      call. = FALSE
    )
  }
  unname(values[[ordering]])
}

sparse_suite_sparse_cpp = paste(c(
  '#include <Rcpp.h>',
  '#include <umfpack.h>',
  '// [[Rcpp::export]]',
  'Rcpp::NumericVector tabloToR_umfpack_solve(',
  '    Rcpp::S4 A, Rcpp::NumericVector rhs, int ordering) {',
  '  Rcpp::IntegerVector p = A.slot("p");',
  '  Rcpp::IntegerVector i = A.slot("i");',
  '  Rcpp::IntegerVector dimensions = A.slot("Dim");',
  '  Rcpp::NumericVector x = A.slot("x");',
  '  int n = dimensions[0];',
  '  if (dimensions[1] != n || rhs.size() != n) {',
  '    Rcpp::stop("UMFPACK received a non-square system or invalid RHS");',
  '  }',
  '  double control[UMFPACK_CONTROL];',
  '  umfpack_di_defaults(control);',
  '  control[UMFPACK_ORDERING] = ordering;',
  '  void *symbolic = NULL;',
  '  void *numeric = NULL;',
  '  int status = umfpack_di_symbolic(',
  '      n, n, p.begin(), i.begin(), x.begin(),',
  '      &symbolic, control, NULL);',
  '  if (status != UMFPACK_OK) {',
  '    Rcpp::stop("UMFPACK symbolic analysis failed (status %d)", status);',
  '  }',
  '  status = umfpack_di_numeric(',
  '      p.begin(), i.begin(), x.begin(), symbolic,',
  '      &numeric, control, NULL);',
  '  umfpack_di_free_symbolic(&symbolic);',
  '  if (status != UMFPACK_OK) {',
  '    if (numeric != NULL) umfpack_di_free_numeric(&numeric);',
  '    Rcpp::stop("UMFPACK numeric factorization failed (status %d)", status);',
  '  }',
  '  Rcpp::NumericVector solution(n);',
  '  status = umfpack_di_solve(',
  '      UMFPACK_A, p.begin(), i.begin(), x.begin(),',
  '      solution.begin(), rhs.begin(), numeric, NULL, NULL);',
  '  umfpack_di_free_numeric(&numeric);',
  '  if (status != UMFPACK_OK) {',
  '    Rcpp::stop("UMFPACK solve failed (status %d)", status);',
  '  }',
  '  return solution;',
  '}'
), collapse = "\n")

sparse_suite_sparse_solver = local({
  compiled_solver = NULL
  function(A, rhs) {
    if (!sparse_suite_sparse_available()) {
      stop(
        paste(
          "backend='SuiteSparse' requires Rcpp and a 64-bit SuiteSparse",
          "installation with umfpack.h and libumfpack."
        ),
        call. = FALSE
      )
    }
    if (is.null(compiled_solver)) {
      old_cppflags = Sys.getenv("PKG_CPPFLAGS")
      old_libs = Sys.getenv("PKG_LIBS")
      old_path = Sys.getenv("PATH")
      on.exit({
        Sys.setenv(
          PKG_CPPFLAGS = old_cppflags,
          PKG_LIBS = old_libs,
          PATH = old_path
        )
      }, add = TRUE)
      Sys.setenv(
        PKG_CPPFLAGS = paste(
          old_cppflags, "-I/usr/include/suitesparse"
        ),
        PKG_LIBS = paste(
          old_libs,
          "-lumfpack -lamd -lcolamd -lsuitesparseconfig -lblas"
        ),
        PATH = paste(
          unique(c("/usr/bin", "/bin", strsplit(old_path, ":", fixed = TRUE)[[1]])),
          collapse = ":"
        )
      )
      Rcpp::sourceCpp(
        code = sparse_suite_sparse_cpp,
        env = environment(),
        showOutput = FALSE
      )
      compiled_solver = get(
        "tabloToR_umfpack_solve", envir = environment()
      )
    }
    as.numeric(compiled_solver(
      A, as.numeric(rhs), as.integer(sparse_suite_sparse_ordering())
    ))
  }
})
