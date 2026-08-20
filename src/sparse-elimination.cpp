#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <vector>

struct TabloEdge {
  int group;
  int external;
  int local;
  double value;
};

struct TabloTriplet {
  int row;
  int column;
  double value;
};

static void tablo_validate_groups(const Rcpp::IntegerVector &group,
                                  int n, int n_groups, const char *name) {
  if (group.size() != n) Rcpp::stop("%s must have length n", name);
  for (int pos = 0; pos < n; ++pos) {
    if (group[pos] < -1 || group[pos] >= n_groups) {
      Rcpp::stop("%s contains an invalid block id", name);
    }
  }
}

static void tablo_layout(const Rcpp::IntegerVector &row_group,
                         const Rcpp::IntegerVector &column_group,
                         int n_groups, std::vector<int> &row_local,
                         std::vector<int> &column_local,
                         std::vector<int> &row_size,
                         std::vector<int> &column_size,
                         std::vector<int> &row_members,
                         std::vector<int> &column_members,
                         std::vector<int> &row_offsets,
                         std::vector<int> &column_offsets) {
  int n = row_group.size();
  row_local.assign(n, -1);
  column_local.assign(n, -1);
  row_size.assign(n_groups, 0);
  column_size.assign(n_groups, 0);
  for (int pos = 0; pos < n; ++pos) {
    int group = row_group[pos];
    if (group >= 0) row_local[pos] = row_size[group]++;
    group = column_group[pos];
    if (group >= 0) column_local[pos] = column_size[group]++;
  }
  row_offsets.assign(n_groups + 1, 0);
  column_offsets.assign(n_groups + 1, 0);
  for (int group = 0; group < n_groups; ++group) {
    if (row_size[group] != column_size[group] || row_size[group] == 0) {
      Rcpp::stop("eliminated block %d is not square and non-empty", group);
    }
    row_offsets[group + 1] = row_offsets[group] + row_size[group];
    column_offsets[group + 1] = column_offsets[group] + column_size[group];
  }
  row_members.assign(row_offsets.back(), -1);
  column_members.assign(column_offsets.back(), -1);
  std::vector<int> row_cursor = row_offsets;
  std::vector<int> column_cursor = column_offsets;
  for (int pos = 0; pos < n; ++pos) {
    int group = row_group[pos];
    if (group >= 0) row_members[row_cursor[group]++] = pos;
    group = column_group[pos];
    if (group >= 0) column_members[column_cursor[group]++] = pos;
  }
}

static bool tablo_factor(std::vector<double> &factor, int size,
                         std::vector<int> &pivot, double tolerance) {
  double scale = 0.0;
  for (double value : factor) {
    if (!std::isfinite(value)) return false;
    scale = std::max(scale, std::abs(value));
  }
  double threshold = tolerance * std::max(1.0, scale);
  pivot.assign(size, 0);
  for (int k = 0; k < size; ++k) {
    int best = k;
    double best_value = std::abs(factor[k * size + k]);
    for (int row = k + 1; row < size; ++row) {
      double candidate = std::abs(factor[row * size + k]);
      if (candidate > best_value) {
        best = row;
        best_value = candidate;
      }
    }
    if (!std::isfinite(best_value) || best_value <= threshold) return false;
    pivot[k] = best;
    if (best != k) {
      for (int column = 0; column < size; ++column) {
        std::swap(factor[k * size + column],
                  factor[best * size + column]);
      }
    }
    double diagonal = factor[k * size + k];
    for (int row = k + 1; row < size; ++row) {
      factor[row * size + k] /= diagonal;
      for (int column = k + 1; column < size; ++column) {
        factor[row * size + column] -=
          factor[row * size + k] * factor[k * size + column];
      }
    }
  }
  return true;
}

static void tablo_solve(const std::vector<double> &factor,
                        const std::vector<int> &pivot, int size,
                        std::vector<double> &value) {
  for (int k = 0; k < size; ++k) {
    int row = pivot[k];
    if (row != k) std::swap(value[k], value[row]);
  }
  for (int k = 0; k < size; ++k) {
    for (int row = k + 1; row < size; ++row) {
      value[row] -= factor[row * size + k] * value[k];
    }
  }
  for (int k = size - 1; k >= 0; --k) {
    double result = value[k];
    for (int column = k + 1; column < size; ++column) {
      result -= factor[k * size + column] * value[column];
    }
    value[k] = result / factor[k * size + k];
  }
}

static bool tablo_edge_less(const TabloEdge &left, const TabloEdge &right) {
  if (left.group != right.group) return left.group < right.group;
  if (left.external != right.external) return left.external < right.external;
  return left.local < right.local;
}

static bool tablo_triplet_less(const TabloTriplet &left,
                               const TabloTriplet &right) {
  if (left.row != right.row) return left.row < right.row;
  return left.column < right.column;
}

static std::size_t tablo_edge_begin(const std::vector<TabloEdge> &edges,
                                    int group) {
  return std::lower_bound(
    edges.begin(), edges.end(), group,
    [](const TabloEdge &edge, int value) { return edge.group < value; }
  ) - edges.begin();
}

static std::size_t tablo_edge_end(const std::vector<TabloEdge> &edges,
                                  int group) {
  return std::upper_bound(
    edges.begin(), edges.end(), group,
    [](int value, const TabloEdge &edge) { return value < edge.group; }
  ) - edges.begin();
}

static double tablo_edge_dot(const std::vector<TabloEdge> &edges,
                             std::size_t first, std::size_t last,
                             const std::vector<double> &value) {
  double result = 0.0;
  for (std::size_t pos = first; pos < last; ++pos) {
    result += edges[pos].value * value[edges[pos].local];
  }
  return result;
}

static SEXP tablo_sparse_matrix(std::vector<TabloTriplet> &triplets,
                                int rows, int columns) {
  std::sort(triplets.begin(), triplets.end(), tablo_triplet_less);
  std::size_t output = 0;
  for (std::size_t pos = 0; pos < triplets.size();) {
    std::size_t end = pos + 1;
    double value = triplets[pos].value;
    while (end < triplets.size() &&
           triplets[end].row == triplets[pos].row &&
           triplets[end].column == triplets[pos].column) {
      value += triplets[end].value;
      ++end;
    }
    if (!std::isfinite(value)) Rcpp::stop("Schur aggregation produced a non-finite value");
    if (value != 0.0) {
      triplets[output++] = {triplets[pos].row, triplets[pos].column, value};
    }
    pos = end;
  }
  triplets.resize(output);
  Rcpp::IntegerVector pointer(columns + 1, 0);
  for (const auto &entry : triplets) ++pointer[entry.column + 1];
  for (int column = 0; column < columns; ++column) {
    pointer[column + 1] += pointer[column];
  }
  Rcpp::IntegerVector row_index(triplets.size());
  Rcpp::NumericVector value(triplets.size());
  std::vector<int> cursor(pointer.begin(), pointer.end());
  for (const auto &entry : triplets) {
    int position = cursor[entry.column]++;
    row_index[position] = entry.row;
    value[position] = entry.value;
  }
  Rcpp::S4 result("dgCMatrix");
  result.slot("i") = row_index;
  result.slot("p") = pointer;
  result.slot("x") = value;
  result.slot("Dim") = Rcpp::IntegerVector::create(rows, columns);
  result.slot("Dimnames") = Rcpp::List::create(R_NilValue, R_NilValue);
  return result;
}

// [[Rcpp::export]]
Rcpp::List tabloToR_eliminate_blocks(SEXP matrix_sexp, Rcpp::NumericVector rhs,
                                     Rcpp::IntegerVector row_group,
                                     Rcpp::IntegerVector column_group,
                                     int n_groups, double pivot_tolerance) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector p = matrix.slot("p");
  Rcpp::IntegerVector i = matrix.slot("i");
  Rcpp::NumericVector x = matrix.slot("x");
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  int n = dimensions[0];
  if (dimensions[1] != n || rhs.size() != n || n_groups < 1 ||
      !std::isfinite(pivot_tolerance) || pivot_tolerance <= 0.0) {
    Rcpp::stop("invalid block elimination dimensions or controls");
  }
  tablo_validate_groups(row_group, n, n_groups, "row_group");
  tablo_validate_groups(column_group, n, n_groups, "column_group");
  std::vector<int> row_local, column_local, row_size, column_size;
  std::vector<int> row_members, column_members, row_offsets, column_offsets;
  tablo_layout(row_group, column_group, n_groups, row_local, column_local,
               row_size, column_size, row_members, column_members,
               row_offsets, column_offsets);
  std::vector<int> row_keep(n, -1), column_keep(n, -1);
  int kept_rows = 0;
  int kept_columns = 0;
  for (int pos = 0; pos < n; ++pos) {
    if (row_group[pos] < 0) row_keep[pos] = kept_rows++;
    if (column_group[pos] < 0) column_keep[pos] = kept_columns++;
  }
  if (kept_rows != kept_columns) {
    Rcpp::stop("row and column elimination leaves different dimensions");
  }
  std::vector<TabloEdge> left, right;
  std::vector<TabloTriplet> triplets;
  left.reserve(x.size() / 8);
  right.reserve(x.size() / 8);
  triplets.reserve(x.size() / 2);
  for (int column = 0; column < n; ++column) {
    int cg = column_group[column];
    for (int pos = p[column]; pos < p[column + 1]; ++pos) {
      int row = i[pos];
      int rg = row_group[row];
      if (rg >= 0 && cg >= 0) {
        if (rg != cg) {
          Rcpp::stop("eliminated blocks are coupled by an off-diagonal entry");
        }
      } else if (rg >= 0) {
        right.push_back({rg, column_keep[column], row_local[row], x[pos]});
      } else if (cg >= 0) {
        left.push_back({cg, row_keep[row], column_local[column], x[pos]});
      } else {
        triplets.push_back({row_keep[row], column_keep[column], x[pos]});
      }
    }
  }
  std::sort(left.begin(), left.end(), tablo_edge_less);
  std::sort(right.begin(), right.end(), tablo_edge_less);
  double product_upper = 0.0;
  for (int group = 0; group < n_groups; ++group) {
    std::size_t lf = tablo_edge_begin(left, group);
    std::size_t le = tablo_edge_end(left, group);
    std::size_t rf = tablo_edge_begin(right, group);
    std::size_t re = tablo_edge_end(right, group);
    int left_count = 0;
    int right_count = 0;
    for (std::size_t pos = lf; pos < le;) {
      ++left_count;
      int external = left[pos].external;
      while (pos < le && left[pos].external == external) ++pos;
    }
    for (std::size_t pos = rf; pos < re;) {
      ++right_count;
      int external = right[pos].external;
      while (pos < re && right[pos].external == external) ++pos;
    }
    product_upper += static_cast<double>(left_count) * right_count;
  }
  Rcpp::NumericVector reduced_rhs(kept_rows, 0.0);
  for (int pos = 0; pos < n; ++pos) {
    if (row_group[pos] < 0) reduced_rhs[row_keep[pos]] = rhs[pos];
  }
  int max_block = 0;
  int singular_count = 0;
  std::vector<int> singular_groups;
  std::vector<double> factor, local_value;
  std::vector<int> pivot;
  for (int group = 0; group < n_groups; ++group) {
    int size = row_size[group];
    max_block = std::max(max_block, size);
    factor.assign(static_cast<std::size_t>(size) * size, 0.0);
    for (int member = column_offsets[group];
         member < column_offsets[group + 1]; ++member) {
      int column = column_members[member];
      for (int pos = p[column]; pos < p[column + 1]; ++pos) {
        int row = i[pos];
        if (row_group[row] == group) {
          factor[static_cast<std::size_t>(row_local[row]) * size +
                 column_local[column]] += x[pos];
        }
      }
    }
    if (!tablo_factor(factor, size, pivot, pivot_tolerance)) {
      ++singular_count;
      singular_groups.push_back(group);
      continue;
    }
    std::size_t lf = tablo_edge_begin(left, group);
    std::size_t le = tablo_edge_end(left, group);
    std::size_t rf = tablo_edge_begin(right, group);
    std::size_t re = tablo_edge_end(right, group);
    for (std::size_t right_pos = rf; right_pos < re;) {
      int external_column = right[right_pos].external;
      local_value.assign(size, 0.0);
      while (right_pos < re && right[right_pos].external == external_column) {
        local_value[right[right_pos].local] += right[right_pos].value;
        ++right_pos;
      }
      tablo_solve(factor, pivot, size, local_value);
      for (std::size_t left_pos = lf; left_pos < le;) {
        int external_row = left[left_pos].external;
        std::size_t row_end = left_pos + 1;
        while (row_end < le && left[row_end].external == external_row) ++row_end;
        double value = -tablo_edge_dot(left, left_pos, row_end, local_value);
        if (value != 0.0) triplets.push_back({external_row, external_column, value});
        left_pos = row_end;
      }
    }
    local_value.assign(size, 0.0);
    for (int member = row_offsets[group];
         member < row_offsets[group + 1]; ++member) {
      int row = row_members[member];
      local_value[row_local[row]] = rhs[row];
    }
    tablo_solve(factor, pivot, size, local_value);
    for (std::size_t left_pos = lf; left_pos < le;) {
      int external_row = left[left_pos].external;
      std::size_t row_end = left_pos + 1;
      while (row_end < le && left[row_end].external == external_row) ++row_end;
      reduced_rhs[external_row] -= tablo_edge_dot(
        left, left_pos, row_end, local_value
      );
      left_pos = row_end;
    }
  }
  if (singular_count) {
    return Rcpp::List::create(
      Rcpp::_["ok"] = false,
      Rcpp::_["singular_count"] = singular_count,
      Rcpp::_["singular_groups"] = singular_groups,
      Rcpp::_["kept_dimension"] = kept_rows,
      Rcpp::_["product_upper"] = product_upper,
      Rcpp::_["max_block"] = max_block
    );
  }
  SEXP reduced_matrix = tablo_sparse_matrix(triplets, kept_rows, kept_rows);
  return Rcpp::List::create(
    Rcpp::_["ok"] = true,
    Rcpp::_["A"] = reduced_matrix,
    Rcpp::_["rhs"] = reduced_rhs,
    Rcpp::_["kept_dimension"] = kept_rows,
    Rcpp::_["reduced_nnz"] = static_cast<double>(triplets.size()),
    Rcpp::_["left_nnz"] = static_cast<double>(left.size()),
    Rcpp::_["right_nnz"] = static_cast<double>(right.size()),
    Rcpp::_["product_upper"] = product_upper,
    Rcpp::_["max_block"] = max_block
  );
}

// [[Rcpp::export]]
Rcpp::NumericVector tabloToR_reconstruct_blocks(
    SEXP matrix_sexp, Rcpp::NumericVector rhs,
    Rcpp::NumericVector reduced_solution,
    Rcpp::IntegerVector row_group, Rcpp::IntegerVector column_group,
    int n_groups, double pivot_tolerance) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector p = matrix.slot("p");
  Rcpp::IntegerVector i = matrix.slot("i");
  Rcpp::NumericVector x = matrix.slot("x");
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  int n = dimensions[0];
  if (dimensions[1] != n || rhs.size() != n || n_groups < 1 ||
      !std::isfinite(pivot_tolerance) || pivot_tolerance <= 0.0) {
    Rcpp::stop("invalid block reconstruction dimensions or controls");
  }
  tablo_validate_groups(row_group, n, n_groups, "row_group");
  tablo_validate_groups(column_group, n, n_groups, "column_group");
  std::vector<int> row_local, column_local, row_size, column_size;
  std::vector<int> row_members, column_members, row_offsets, column_offsets;
  tablo_layout(row_group, column_group, n_groups, row_local, column_local,
               row_size, column_size, row_members, column_members,
               row_offsets, column_offsets);
  std::vector<int> column_keep(n, -1);
  int kept_columns = 0;
  for (int pos = 0; pos < n; ++pos) {
    if (column_group[pos] < 0) column_keep[pos] = kept_columns++;
  }
  if (reduced_solution.size() != kept_columns) {
    Rcpp::stop("reduced solution has the wrong length");
  }
  Rcpp::NumericVector result(n, 0.0);
  std::vector<double> local_rhs(n, 0.0);
  for (int pos = 0; pos < n; ++pos) local_rhs[pos] = rhs[pos];
  for (int column = 0; column < n; ++column) {
    if (column_group[column] >= 0) continue;
    double value = reduced_solution[column_keep[column]];
    result[column] = value;
    if (value == 0.0) continue;
    for (int pos = p[column]; pos < p[column + 1]; ++pos) {
      int row = i[pos];
      if (row_group[row] >= 0) local_rhs[row] -= x[pos] * value;
    }
  }
  std::vector<double> factor, local_value;
  std::vector<int> pivot;
  for (int group = 0; group < n_groups; ++group) {
    int size = row_size[group];
    factor.assign(static_cast<std::size_t>(size) * size, 0.0);
    for (int member = column_offsets[group];
         member < column_offsets[group + 1]; ++member) {
      int column = column_members[member];
      for (int pos = p[column]; pos < p[column + 1]; ++pos) {
        int row = i[pos];
        if (row_group[row] == group) {
          factor[static_cast<std::size_t>(row_local[row]) * size +
                 column_local[column]] += x[pos];
        } else if (row_group[row] >= 0) {
          Rcpp::stop("eliminated blocks are coupled during reconstruction");
        }
      }
    }
    if (!tablo_factor(factor, size, pivot, pivot_tolerance)) {
      Rcpp::stop("an eliminated block is singular during reconstruction");
    }
    local_value.assign(size, 0.0);
    for (int member = row_offsets[group];
         member < row_offsets[group + 1]; ++member) {
      int row = row_members[member];
      local_value[row_local[row]] = local_rhs[row];
    }
    tablo_solve(factor, pivot, size, local_value);
    for (int member = column_offsets[group];
         member < column_offsets[group + 1]; ++member) {
      int column = column_members[member];
      result[column] = local_value[column_local[column]];
    }
  }
  return result;
}
