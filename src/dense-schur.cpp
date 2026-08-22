#include <Rcpp.h>
#include <R_ext/Lapack.h>

#include <algorithm>
#include <cmath>
#include <vector>

struct TabloDenseLU {
  int n;
  std::vector<double> factor;
  std::vector<int> pivot;
  bool released;

  explicit TabloDenseLU(int dimension)
    : n(dimension), factor(static_cast<std::size_t>(dimension) * dimension),
      pivot(dimension), released(false) {}
};

static TabloDenseLU *tablo_dense_lu_get(SEXP pointer_sexp) {
  if (TYPEOF(pointer_sexp) != EXTPTRSXP) {
    Rcpp::stop("Dense LU handle must be an external pointer");
  }
  TabloDenseLU *pointer = static_cast<TabloDenseLU *>(
    R_ExternalPtrAddr(pointer_sexp)
  );
  if (pointer == NULL || pointer->released) {
    Rcpp::stop("Dense LU handle has been released");
  }
  return pointer;
}

static void tablo_dense_lu_finalizer(SEXP pointer_sexp) {
  TabloDenseLU *pointer = static_cast<TabloDenseLU *>(
    R_ExternalPtrAddr(pointer_sexp)
  );
  if (pointer != NULL) {
    pointer->released = true;
    delete pointer;
    R_ClearExternalPtr(pointer_sexp);
  }
}

// [[Rcpp::export(name = ".tabloToR_dense_lu_factor")]]
SEXP tabloToR_dense_lu_factor(Rcpp::NumericMatrix matrix) {
  if (matrix.nrow() < 1 || matrix.nrow() != matrix.ncol()) {
    Rcpp::stop("Dense LU factor requires a non-empty square matrix");
  }
  if (std::any_of(matrix.begin(), matrix.end(),
                  [](double value) { return !std::isfinite(value); })) {
    Rcpp::stop("Dense LU factor matrix contains non-finite values");
  }
  TabloDenseLU *factor = new TabloDenseLU(matrix.nrow());
  std::copy(matrix.begin(), matrix.end(), factor->factor.begin());
  int info = 0;
  F77_CALL(dgetrf)(&factor->n, &factor->n, factor->factor.data(), &factor->n,
                   factor->pivot.data(), &info);
  if (info != 0) {
    delete factor;
    if (info > 0) {
      Rcpp::stop("Dense LU factorization found a singular matrix at pivot %d",
                 info);
    }
    Rcpp::stop("Dense LU factorization rejected argument %d", -info);
  }
  SEXP pointer = PROTECT(R_MakeExternalPtr(factor, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(pointer, tablo_dense_lu_finalizer, TRUE);
  Rf_setAttrib(pointer, R_ClassSymbol,
               Rcpp::CharacterVector::create("tabloToR_dense_lu"));
  UNPROTECT(1);
  return pointer;
}

// [[Rcpp::export(name = ".tabloToR_dense_lu_solve")]]
SEXP tabloToR_dense_lu_solve(SEXP pointer_sexp, SEXP rhs_sexp) {
  TabloDenseLU *factor = tablo_dense_lu_get(pointer_sexp);
  if (!Rf_isReal(rhs_sexp) && !Rf_isInteger(rhs_sexp)) {
    Rcpp::stop("Dense LU rhs must be numeric");
  }
  Rcpp::NumericVector rhs = Rcpp::clone(Rcpp::as<Rcpp::NumericVector>(rhs_sexp));
  SEXP dim_sexp = Rf_getAttrib(rhs, R_DimSymbol);
  int nrhs = 1;
  if (!Rf_isNull(dim_sexp)) {
    Rcpp::IntegerVector dim(dim_sexp);
    if (dim.size() != 2) {
      Rcpp::stop("Dense LU rhs must be a vector or matrix");
    }
    if (dim[0] != factor->n || dim[1] < 0) {
      Rcpp::stop("Dense LU rhs matrix has incompatible dimensions");
    }
    nrhs = dim[1];
  } else if (rhs.size() != factor->n) {
    Rcpp::stop("Dense LU rhs vector has incompatible length");
  }
  if (std::any_of(rhs.begin(), rhs.end(),
                  [](double value) { return !std::isfinite(value); })) {
    Rcpp::stop("Dense LU rhs contains non-finite values");
  }
  char trans = 'N';
  int info = 0;
  int leading = factor->n;
  F77_CALL(dgetrs)(&trans, &factor->n, &nrhs, factor->factor.data(),
                   &factor->n, factor->pivot.data(), REAL(rhs), &leading,
                   &info FCONE);
  if (info != 0) {
    Rcpp::stop("Dense LU solve rejected argument %d", -info);
  }
  if (std::any_of(rhs.begin(), rhs.end(),
                  [](double value) { return !std::isfinite(value); })) {
    Rcpp::stop("Dense LU solve produced non-finite values");
  }
  return rhs;
}

// [[Rcpp::export(name = ".tabloToR_dense_lu_release")]]
void tabloToR_dense_lu_release(SEXP pointer_sexp) {
  if (TYPEOF(pointer_sexp) != EXTPTRSXP) return;
  tablo_dense_lu_finalizer(pointer_sexp);
}
