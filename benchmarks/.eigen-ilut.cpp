#include <RcppEigen.h>

// [[Rcpp::depends(RcppEigen)]]

// [[Rcpp::export]]
Rcpp::List solve_scaled_ilut(
    SEXP matrix_sexp,
    Rcpp::NumericVector rhs,
    Rcpp::NumericVector row_scale,
    Rcpp::NumericVector column_scale,
    double droptol = 1e-4,
    int fillfactor = 10,
    int max_iterations = 1000,
    double tolerance = 1e-7) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  Rcpp::IntegerVector row_indices = matrix.slot("i");
  Rcpp::IntegerVector column_pointers = matrix.slot("p");
  Rcpp::NumericVector values = matrix.slot("x");
  const int rows = dimensions[0];
  const int columns = dimensions[1];

  Eigen::SparseMatrix<double, Eigen::ColMajor, int> scaled(rows, columns);
  scaled.reserve(values.size());
  for (int column = 0; column < columns; ++column) {
    scaled.startVec(column);
    for (int entry = column_pointers[column];
         entry < column_pointers[column + 1]; ++entry) {
      const int row = row_indices[entry];
      const double value =
          values[entry] * row_scale[row] * column_scale[column];
      if (value != 0.0) {
        scaled.insertBack(row, column) = value;
      }
    }
  }
  scaled.makeCompressed();

  Eigen::VectorXd scaled_rhs(rhs.size());
  for (int row = 0; row < rows; ++row) {
    scaled_rhs[row] = row_scale[row] * rhs[row];
  }

  typedef Eigen::IncompleteLUT<double, int> Preconditioner;
  Eigen::BiCGSTAB<
      Eigen::SparseMatrix<double, Eigen::ColMajor, int>,
      Preconditioner> solver;
  solver.preconditioner().setDroptol(droptol);
  solver.preconditioner().setFillfactor(fillfactor);
  solver.setMaxIterations(max_iterations);
  solver.setTolerance(tolerance);
  solver.compute(scaled);
  Eigen::VectorXd solution = solver.solve(scaled_rhs);

  Rcpp::NumericVector output(solution.size());
  std::copy(solution.data(), solution.data() + solution.size(), output.begin());
  return Rcpp::List::create(
      Rcpp::_["solution"] = output,
      Rcpp::_["iterations"] = solver.iterations(),
      Rcpp::_["error"] = solver.error(),
      Rcpp::_["status"] = static_cast<int>(solver.info()),
      Rcpp::_["scaled_nnz"] = scaled.nonZeros());
}
