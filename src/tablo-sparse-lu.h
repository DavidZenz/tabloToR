#ifndef TABLOTOR_SPARSE_LU_H
#define TABLOTOR_SPARSE_LU_H

#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <string>
#include <vector>

struct TabloCscView {
  int nrow;
  int ncol;
  const int *p;
  const int *i;
  const double *x;
  int nnz;
  bool triangular;
  bool lower;
  bool unit_diagonal;
};

inline void tablo_checked_product(std::size_t left, std::size_t right,
                                  const char *name) {
  if (right != 0 && left > std::numeric_limits<std::size_t>::max() / right) {
    Rcpp::stop("%s allocation size overflows", name);
  }
}

inline TabloCscView tablo_csc_view(SEXP matrix_sexp,
                                   const char *name,
                                   int expected_rows = -1,
                                   int expected_columns = -1,
                                   int expected_triangle = 0) {
  if (!Rf_isS4(matrix_sexp)) {
    Rcpp::stop("%s must be an S4 sparse matrix", name);
  }
  Rcpp::S4 matrix(matrix_sexp);
  if (!(matrix.is("dgCMatrix") || matrix.is("dtCMatrix"))) {
    Rcpp::stop("%s must inherit from dgCMatrix or dtCMatrix", name);
  }
  Rcpp::IntegerVector dim = matrix.slot("Dim");
  Rcpp::IntegerVector p = matrix.slot("p");
  Rcpp::IntegerVector i = matrix.slot("i");
  Rcpp::NumericVector x = matrix.slot("x");
  if (dim.size() != 2 || dim[0] < 0 || dim[1] < 0 ||
      p.size() != dim[1] + 1 || i.size() != x.size()) {
    Rcpp::stop("%s has inconsistent CSC slots", name);
  }
  if ((expected_rows >= 0 && dim[0] != expected_rows) ||
      (expected_columns >= 0 && dim[1] != expected_columns)) {
    Rcpp::stop("%s has incompatible dimensions", name);
  }
  if (p[0] != 0 || p[dim[1]] != i.size()) {
    Rcpp::stop("%s has invalid CSC pointers", name);
  }
  for (int column = 0; column < dim[1]; ++column) {
    if (p[column] > p[column + 1]) {
      Rcpp::stop("%s has decreasing CSC pointers", name);
    }
    int previous = -1;
    for (int position = p[column]; position < p[column + 1]; ++position) {
      int row = i[position];
      if (row < 0 || row >= dim[0] || row <= previous ||
          !std::isfinite(x[position])) {
        Rcpp::stop("%s has invalid CSC row indices or values", name);
      }
      previous = row;
    }
  }

  bool triangular = matrix.is("dtCMatrix");
  bool lower = false;
  bool unit = false;
  if (triangular) {
    std::string uplo = Rcpp::as<std::string>(matrix.slot("uplo"));
    std::string diag = Rcpp::as<std::string>(matrix.slot("diag"));
    lower = uplo == "L";
    unit = diag == "U";
    if (uplo != "L" && uplo != "U") {
      Rcpp::stop("%s has an invalid triangular orientation", name);
    }
    if (diag != "N" && diag != "U") {
      Rcpp::stop("%s has an invalid triangular diagonal", name);
    }
    if ((expected_triangle < 0 && !lower) ||
        (expected_triangle > 0 && lower)) {
      Rcpp::stop("%s has the wrong triangular orientation", name);
    }
  } else if (expected_triangle != 0) {
    Rcpp::stop("%s must be triangular", name);
  }

  TabloCscView result = {
    dim[0], dim[1], INTEGER(p), INTEGER(i), REAL(x),
    static_cast<int>(i.size()), triangular, lower, unit
  };
  return result;
}

inline double tablo_triangular_diagonal(const TabloCscView &matrix,
                                        int column,
                                        const char *name) {
  if (matrix.unit_diagonal) return 1.0;
  for (int position = matrix.p[column]; position < matrix.p[column + 1];
       ++position) {
    if (matrix.i[position] == column) {
      double value = matrix.x[position];
      if (!std::isfinite(value) || value == 0.0) {
        Rcpp::stop("%s contains a zero or non-finite diagonal", name);
      }
      return value;
    }
  }
  Rcpp::stop("%s is missing an explicit diagonal", name);
  return NA_REAL;
}

struct TabloSparseLUView {
  int n;
  TabloCscView L;
  TabloCscView U;
  std::vector<int> p;
  std::vector<int> q;
  std::vector<double> diagonal_l;
  std::vector<double> diagonal_u;
};

inline void tablo_validate_permutation(const Rcpp::IntegerVector &value,
                                       int n, bool allow_empty,
                                       const char *name,
                                       std::vector<int> *output) {
  if (allow_empty && value.size() == 0) {
    output->resize(n);
    for (int id = 0; id < n; ++id) (*output)[id] = id;
    return;
  }
  if (value.size() != n) {
    Rcpp::stop("%s has an invalid length", name);
  }
  std::vector<unsigned char> seen(n, 0);
  output->resize(n);
  for (int id = 0; id < n; ++id) {
    int item = value[id];
    if (item < 0 || item >= n || seen[item]) {
      Rcpp::stop("%s is not a zero-based permutation", name);
    }
    seen[item] = 1;
    (*output)[id] = item;
  }
}

inline TabloSparseLUView tablo_sparse_lu_view(SEXP factor_sexp,
                                              const char *name) {
  if (!Rf_isS4(factor_sexp)) {
    Rcpp::stop("%s must be a Matrix sparseLU factor", name);
  }
  Rcpp::S4 factor(factor_sexp);
  if (!factor.is("sparseLU")) {
    Rcpp::stop("%s must inherit from sparseLU", name);
  }
  Rcpp::IntegerVector dim = factor.slot("Dim");
  if (dim.size() != 2 || dim[0] < 1 || dim[0] != dim[1]) {
    Rcpp::stop("%s must be a non-empty square sparseLU factor", name);
  }
  int n = dim[0];
  TabloSparseLUView result = {
    n,
    tablo_csc_view(factor.slot("L"), "sparseLU@L", n, n, -1),
    tablo_csc_view(factor.slot("U"), "sparseLU@U", n, n, 1),
    std::vector<int>(), std::vector<int>(),
    std::vector<double>(n), std::vector<double>(n)
  };
  tablo_validate_permutation(factor.slot("p"), n, false,
                             "sparseLU@p", &result.p);
  tablo_validate_permutation(factor.slot("q"), n, true,
                             "sparseLU@q", &result.q);
  for (int column = 0; column < n; ++column) {
    result.diagonal_l[column] = tablo_triangular_diagonal(
      result.L, column, "sparseLU@L"
    );
    result.diagonal_u[column] = tablo_triangular_diagonal(
      result.U, column, "sparseLU@U"
    );
    for (int position = result.L.p[column];
         position < result.L.p[column + 1]; ++position) {
      if (result.L.i[position] < column) {
        Rcpp::stop("sparseLU@L contains an entry above the diagonal");
      }
    }
    for (int position = result.U.p[column];
         position < result.U.p[column + 1]; ++position) {
      if (result.U.i[position] > column) {
        Rcpp::stop("sparseLU@U contains an entry below the diagonal");
      }
    }
  }
  return result;
}

inline void tablo_sparse_lu_solve_inplace(const TabloSparseLUView &factor,
                                          double *values, int nrhs,
                                          std::vector<double> &workspace) {
  const int n = factor.n;
  tablo_checked_product(static_cast<std::size_t>(n),
                        static_cast<std::size_t>(nrhs),
                        "sparse LU workspace");
  workspace.resize(static_cast<std::size_t>(n) * nrhs);
  for (int rhs = 0; rhs < nrhs; ++rhs) {
    for (int row = 0; row < n; ++row) {
      double value = values[factor.p[row] + static_cast<std::size_t>(n) * rhs];
      if (!std::isfinite(value)) {
        Rcpp::stop("Sparse LU right-hand side contains non-finite values");
      }
      workspace[row + static_cast<std::size_t>(n) * rhs] = value;
    }
  }

  for (int column = 0; column < n; ++column) {
    const double diagonal = factor.diagonal_l[column];
    for (int rhs = 0; rhs < nrhs; ++rhs) {
      workspace[column + static_cast<std::size_t>(n) * rhs] /= diagonal;
    }
    for (int position = factor.L.p[column];
         position < factor.L.p[column + 1]; ++position) {
      int row = factor.L.i[position];
      if (row <= column) continue;
      double coefficient = factor.L.x[position];
      for (int rhs = 0; rhs < nrhs; ++rhs) {
        workspace[row + static_cast<std::size_t>(n) * rhs] -= coefficient *
          workspace[column + static_cast<std::size_t>(n) * rhs];
      }
    }
  }

  for (int column = n - 1; column >= 0; --column) {
    const double diagonal = factor.diagonal_u[column];
    for (int rhs = 0; rhs < nrhs; ++rhs) {
      workspace[column + static_cast<std::size_t>(n) * rhs] /= diagonal;
    }
    for (int position = factor.U.p[column];
         position < factor.U.p[column + 1]; ++position) {
      int row = factor.U.i[position];
      if (row >= column) continue;
      double coefficient = factor.U.x[position];
      for (int rhs = 0; rhs < nrhs; ++rhs) {
        workspace[row + static_cast<std::size_t>(n) * rhs] -= coefficient *
          workspace[column + static_cast<std::size_t>(n) * rhs];
      }
    }
  }

  for (int rhs = 0; rhs < nrhs; ++rhs) {
    for (int row = 0; row < n; ++row) {
      double value = workspace[row + static_cast<std::size_t>(n) * rhs];
      if (!std::isfinite(value)) {
        Rcpp::stop("Sparse LU solve produced non-finite values");
      }
      values[factor.q[row] + static_cast<std::size_t>(n) * rhs] = value;
    }
  }
}

#endif
