#include <RcppEigen.h>
#include <algorithm>
#include <memory>
#include <vector>

// [[Rcpp::depends(RcppEigen)]]

typedef Eigen::SparseMatrix<double, Eigen::ColMajor, int> Sparse;
typedef Eigen::SparseLU<Sparse, Eigen::COLAMDOrdering<int> > DirectFactor;

// [[Rcpp::export]]
Rcpp::List solve_eigen_one_direct(
    SEXP matrix_sexp,
    Rcpp::NumericVector rhs,
    Rcpp::IntegerVector row_group,
    Rcpp::IntegerVector column_group,
    int target) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  Rcpp::IntegerVector row_indices = matrix.slot("i");
  Rcpp::IntegerVector column_pointers = matrix.slot("p");
  Rcpp::NumericVector values = matrix.slot("x");
  const int n = dimensions[0];
  if (dimensions[1] != n || rhs.size() != n ||
      row_group.size() != n || column_group.size() != n) {
    Rcpp::stop("Inconsistent matrix or group dimensions");
  }
  std::vector<int> rows;
  std::vector<int> columns;
  for (int i = 0; i < n; ++i) {
    if (row_group[i] == target) rows.push_back(i);
    if (column_group[i] == target) columns.push_back(i);
  }
  if (rows.size() != columns.size()) Rcpp::stop("Block is not square");
  std::vector<int> row_position(n, -1);
  for (size_t k = 0; k < rows.size(); ++k) row_position[rows[k]] = k;
  std::vector<Eigen::Triplet<double, int> > triplets;
  for (size_t k = 0; k < columns.size(); ++k) {
    const int column = columns[k];
    for (int entry = column_pointers[column];
         entry < column_pointers[column + 1]; ++entry) {
      const int row = row_indices[entry];
      if (row_group[row] == target) {
        triplets.push_back(Eigen::Triplet<double, int>(
          row_position[row], static_cast<int>(k), values[entry]));
      }
    }
  }
  Sparse block(static_cast<int>(rows.size()), static_cast<int>(columns.size()));
  block.setFromTriplets(triplets.begin(), triplets.end());
  DirectFactor factor;
  factor.compute(block);
  if (factor.info() != Eigen::Success) {
    Rcpp::stop("Eigen direct factorization failed");
  }
  Eigen::VectorXd local_rhs(rows.size());
  for (size_t k = 0; k < rows.size(); ++k) local_rhs[k] = rhs[rows[k]];
  Eigen::VectorXd local_solution = factor.solve(local_rhs);
  if (factor.info() != Eigen::Success || !local_solution.allFinite()) {
    Rcpp::stop("Eigen direct solve failed");
  }
  Rcpp::NumericVector solution(rows.size());
  for (size_t k = 0; k < rows.size(); ++k) solution[k] = local_solution[k];
  return Rcpp::List::create(
    Rcpp::_["solution"] = solution,
    Rcpp::_["rows"] = Rcpp::wrap(rows),
    Rcpp::_["nnz"] = block.nonZeros()
  );
}
