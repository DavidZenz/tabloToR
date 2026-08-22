#include <RcppEigen.h>

// [[Rcpp::depends(RcppEigen)]]

// [[Rcpp::export]]
Rcpp::List solve_eigen_lu(SEXP matrix_sexp, Rcpp::NumericVector rhs) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  Rcpp::IntegerVector row_indices = matrix.slot("i");
  Rcpp::IntegerVector column_pointers = matrix.slot("p");
  Rcpp::NumericVector values = matrix.slot("x");
  const int n = dimensions[0];
  Eigen::SparseMatrix<double, Eigen::ColMajor, int> A(n, n);
  A.reserve(values.size());
  for (int column = 0; column < n; ++column) {
    A.startVec(column);
    for (int entry = column_pointers[column];
         entry < column_pointers[column + 1]; ++entry) {
      A.insertBack(row_indices[entry], column) = values[entry];
    }
  }
  A.makeCompressed();
  Eigen::SparseLU<
    Eigen::SparseMatrix<double, Eigen::ColMajor, int>,
    Eigen::COLAMDOrdering<int> > solver;
  solver.analyzePattern(A);
  solver.factorize(A);
  Eigen::VectorXd b(rhs.size());
  std::copy(rhs.begin(), rhs.end(), b.data());
  Eigen::VectorXd x = solver.solve(b);
  Rcpp::NumericVector result(x.size());
  std::copy(x.data(), x.data() + x.size(), result.begin());
  return Rcpp::List::create(
    Rcpp::_["solution"] = result,
    Rcpp::_["status"] = static_cast<int>(solver.info()),
    Rcpp::_["nnz"] = A.nonZeros()
  );
}
