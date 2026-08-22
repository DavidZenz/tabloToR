#include <Rcpp.h>
#include <algorithm>
#include <utility>
#include <vector>

// [[Rcpp::export]]
Rcpp::List block_schur_stats(SEXP matrix_sexp,
                             Rcpp::IntegerVector row_group,
                             Rcpp::IntegerVector column_group,
                             int n_groups) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector p = matrix.slot("p");
  Rcpp::IntegerVector i = matrix.slot("i");
  const int n = p.size() - 1;
  if (row_group.size() != n || column_group.size() != n) {
    Rcpp::stop("group vectors must match matrix dimensions");
  }
  std::vector<std::pair<int, int> > b_pairs;
  std::vector<std::pair<int, int> > c_pairs;
  b_pairs.reserve(i.size());
  c_pairs.reserve(i.size());
  double d_nnz = 0;
  double cross_l = 0;
  std::vector<int> cross_rows;
  std::vector<int> cross_cols;
  std::vector<int> cross_row_groups;
  std::vector<int> cross_col_groups;
  for (int col = 0; col < n; ++col) {
    int cg = column_group[col];
    for (int pos = p[col]; pos < p[col + 1]; ++pos) {
      int row = i[pos];
      int rg = row_group[row];
      if (rg >= 0 && cg < 0) {
        b_pairs.push_back(std::make_pair(rg, col));
      } else if (rg < 0 && cg >= 0) {
        c_pairs.push_back(std::make_pair(cg, row));
      } else if (rg < 0 && cg < 0) {
        d_nnz += 1;
      } else if (rg != cg) {
        cross_l += 1;
        if (cross_rows.size() < 32) {
          cross_rows.push_back(row);
          cross_cols.push_back(col);
          cross_row_groups.push_back(rg);
          cross_col_groups.push_back(cg);
        }
      }
    }
  }
  std::sort(b_pairs.begin(), b_pairs.end());
  b_pairs.erase(std::unique(b_pairs.begin(), b_pairs.end()), b_pairs.end());
  std::sort(c_pairs.begin(), c_pairs.end());
  c_pairs.erase(std::unique(c_pairs.begin(), c_pairs.end()), c_pairs.end());
  std::vector<int> b_count(n_groups, 0);
  std::vector<int> c_count(n_groups, 0);
  for (const auto &entry : b_pairs) ++b_count[entry.first];
  for (const auto &entry : c_pairs) ++c_count[entry.first];
  double product_upper = 0;
  int max_b = 0;
  int max_c = 0;
  for (int group = 0; group < n_groups; ++group) {
    product_upper += static_cast<double>(b_count[group]) * c_count[group];
    max_b = std::max(max_b, b_count[group]);
    max_c = std::max(max_c, c_count[group]);
  }
  return Rcpp::List::create(
    Rcpp::_["b_nnz"] = static_cast<double>(b_pairs.size()),
    Rcpp::_["c_nnz"] = static_cast<double>(c_pairs.size()),
    Rcpp::_["d_nnz"] = d_nnz,
    Rcpp::_["cross_l"] = cross_l,
    Rcpp::_["product_upper"] = product_upper,
    Rcpp::_["max_b_columns"] = max_b,
    Rcpp::_["max_c_rows"] = max_c,
    Rcpp::_["cross_rows"] = cross_rows,
    Rcpp::_["cross_cols"] = cross_cols,
    Rcpp::_["cross_row_groups"] = cross_row_groups,
    Rcpp::_["cross_col_groups"] = cross_col_groups,
    Rcpp::_["b_count"] = b_count,
    Rcpp::_["c_count"] = c_count
  );
}

// [[Rcpp::export]]
Rcpp::NumericMatrix block_cross_family(SEXP matrix_sexp,
                                       Rcpp::IntegerVector row_group,
                                       Rcpp::IntegerVector column_group,
                                       Rcpp::IntegerVector row_family,
                                       Rcpp::IntegerVector column_family,
                                       int n_families) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector p = matrix.slot("p");
  Rcpp::IntegerVector i = matrix.slot("i");
  const int n = p.size() - 1;
  Rcpp::NumericMatrix result(n_families, n_families);
  for (int col = 0; col < n; ++col) {
    int cg = column_group[col];
    int cf = column_family[col] - 1;
    for (int pos = p[col]; pos < p[col + 1]; ++pos) {
      int row = i[pos];
      int rg = row_group[row];
      int rf = row_family[row] - 1;
      if (rg >= 0 && cg >= 0 && rg != cg &&
          rf >= 0 && rf < n_families && cf >= 0 && cf < n_families) {
        result(rf, cf) += 1.0;
      }
    }
  }
  return result;
}
