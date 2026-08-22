#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
List matrix_incidence(SEXP matrix_sexp,
                      IntegerVector row_family,
                      IntegerVector column_family,
                      IntegerVector row_region,
                      IntegerVector column_region,
                      int n_family,
                      int n_region) {
  S4 matrix(matrix_sexp);
  IntegerVector p = matrix.slot("p");
  IntegerVector i = matrix.slot("i");
  NumericVector x = matrix.slot("x");
  NumericMatrix family(n_family, n_family);
  NumericMatrix region(n_region, n_region);
  NumericMatrix family_region(n_family, n_region);
  NumericVector family_nnz(n_family);
  NumericVector column_nnz(column_family.size());
  for (int col = 0; col < column_family.size(); ++col) {
    int cf = column_family[col] - 1;
    int cr = column_region[col] - 1;
    int start = p[col];
    int end = p[col + 1];
    for (int pos = start; pos < end; ++pos) {
      int row = i[pos];
      int rf = row_family[row] - 1;
      int rr = row_region[row] - 1;
      double value = x[pos];
      if (rf >= 0 && rf < n_family && cf >= 0 && cf < n_family) {
        family(rf, cf) += 1.0;
        family_nnz[rf] += 1.0;
      }
      if (rr >= 0 && rr < n_region && cr >= 0 && cr < n_region) {
        region(rr, cr) += 1.0;
      }
      if (rf >= 0 && rf < n_family && cr >= 0 && cr < n_region) {
        family_region(rf, cr) += 1.0;
      }
      column_nnz[col] += 1.0;
      (void)value;
    }
  }
  return List::create(_["family"] = family,
                      _["region"] = region,
                      _["family_region"] = family_region,
                      _["family_nnz"] = family_nnz,
                      _["column_nnz"] = column_nnz);
}
