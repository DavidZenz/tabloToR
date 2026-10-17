#include <Rcpp.h>

#include <cstdint>
#include <iomanip>
#include <memory>
#include <sstream>

#ifdef _OPENMP
#include <omp.h>
#endif

#include "tablo-sparse-lu.h"

// [[Rcpp::export(name = ".GEModelR_schur_cpp_capabilities")]]
Rcpp::List GEModelR_schur_cpp_capabilities() {
#ifdef _OPENMP
  const bool openmp = true;
  const int max_threads = omp_get_max_threads();
#else
  const bool openmp = false;
  const int max_threads = 1;
#endif
  return Rcpp::List::create(
    Rcpp::Named("abi") = 1,
    Rcpp::Named("matrix_contract") = "sparseLU-v1",
    Rcpp::Named("lapack") = true,
    Rcpp::Named("openmp") = openmp,
    Rcpp::Named("max_threads") = max_threads,
    Rcpp::Named("kernels") = Rcpp::CharacterVector::create(
      "sparse_lu_solve", "schur_global", "schur_batch",
      "dense_lu", "pattern_hash"
    )
  );
}

// [[Rcpp::export(name = ".GEModelR_sparse_lu_solve")]]
SEXP GEModelR_sparse_lu_solve(SEXP factor_sexp, SEXP rhs_sexp) {
  // Private prepare/release operations share the existing registered arity.
  if (Rf_isNull(rhs_sexp)) {
    if (TYPEOF(factor_sexp) == EXTPTRSXP) {
      if (R_ExternalPtrTag(factor_sexp) != tablo_sparse_lu_tag()) {
        Rcpp::stop("Invalid prepared sparse LU handle");
      }
      delete static_cast<TabloPreparedSparseLU *>(R_ExternalPtrAddr(factor_sexp));
      R_ClearExternalPtr(factor_sexp);
      R_SetExternalPtrProtected(factor_sexp, R_NilValue);
      return R_NilValue;
    }
    if (!Rf_isS4(factor_sexp)) Rcpp::stop("factor must be a Matrix sparseLU factor");
    Rcpp::S4 owner = Rcpp::clone(Rcpp::S4(factor_sexp));
    std::unique_ptr<TabloPreparedSparseLU> prepared(new TabloPreparedSparseLU(
      tablo_sparse_lu_raw_view(owner, "factor")));
    Rcpp::XPtr<TabloPreparedSparseLU> pointer(
      prepared.get(), true, tablo_sparse_lu_tag(), owner);
    prepared.release();
    pointer.attr("class") = "GEModelR_prepared_sparse_lu";
    return pointer;
  }
  TabloPreparedSparseLU *prepared = TYPEOF(factor_sexp) == EXTPTRSXP ?
    tablo_prepared_sparse_lu(factor_sexp) : nullptr;
  TabloSparseLUView raw;
  if (!prepared) raw = tablo_sparse_lu_view(factor_sexp, "factor");
  const TabloSparseLUView &factor = prepared ? prepared->view : raw;
  if (!Rf_isReal(rhs_sexp) && !Rf_isInteger(rhs_sexp)) {
    Rcpp::stop("Sparse LU rhs must be numeric");
  }
  Rcpp::NumericVector rhs = Rcpp::clone(Rcpp::as<Rcpp::NumericVector>(rhs_sexp));
  SEXP dim_sexp = Rf_getAttrib(rhs, R_DimSymbol);
  int nrhs = 1;
  bool matrix = !Rf_isNull(dim_sexp);
  if (matrix) {
    Rcpp::IntegerVector dim(dim_sexp);
    if (dim.size() != 2) {
      Rcpp::stop("Sparse LU rhs must be a vector or matrix");
    }
    if (dim[0] != factor.n || dim[1] < 0) {
      Rcpp::stop("Sparse LU rhs matrix has incompatible dimensions");
    }
    nrhs = dim[1];
  } else if (rhs.size() != factor.n) {
    Rcpp::stop("Sparse LU rhs vector has incompatible length");
  }
  std::vector<double> workspace;
  tablo_sparse_lu_solve_inplace(factor, REAL(rhs), nrhs,
                               prepared ? prepared->workspace : workspace);
  return rhs;
}

static inline void tablo_hash_mix(std::uint64_t &hash, std::uint64_t value) {
  hash ^= value;
  hash *= UINT64_C(1099511628211);
}

// [[Rcpp::export(name = ".GEModelR_sparse_pattern_hash")]]
Rcpp::CharacterVector GEModelR_sparse_pattern_hash(SEXP matrix_sexp) {
  TabloCscView matrix = tablo_csc_view(matrix_sexp, "matrix");
  std::uint64_t first = UINT64_C(1469598103934665603);
  std::uint64_t second = UINT64_C(7809847782465536322);
  tablo_hash_mix(first, static_cast<std::uint64_t>(matrix.nrow));
  tablo_hash_mix(first, static_cast<std::uint64_t>(matrix.ncol));
  tablo_hash_mix(second, static_cast<std::uint64_t>(matrix.ncol));
  tablo_hash_mix(second, static_cast<std::uint64_t>(matrix.nrow));
  for (int column = 0; column <= matrix.ncol; ++column) {
    tablo_hash_mix(first, static_cast<std::uint64_t>(matrix.p[column]));
    tablo_hash_mix(second,
                   static_cast<std::uint64_t>(matrix.p[column]) +
                   UINT64_C(0x9e3779b97f4a7c15));
  }
  for (int position = 0; position < matrix.nnz; ++position) {
    tablo_hash_mix(first, static_cast<std::uint64_t>(matrix.i[position]));
    tablo_hash_mix(second,
                   static_cast<std::uint64_t>(matrix.i[position]) +
                   UINT64_C(0x517cc1b727220a95));
  }
  std::ostringstream stream;
  stream << std::hex << std::setfill('0') << std::setw(16) << first
         << std::setw(16) << second;
  return Rcpp::CharacterVector::create(stream.str());
}
