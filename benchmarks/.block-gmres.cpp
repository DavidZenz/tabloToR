#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <vector>

using Rcpp::IntegerVector;
using Rcpp::List;
using Rcpp::NumericVector;

struct BlockFactors {
  int size;
  std::size_t matrix_offset;
  std::size_t pivot_offset;
  int singular;
};

static double dot_product(const double *a, const double *b, int n) {
  double result = 0.0;
  for (int i = 0; i < n; ++i) result += a[i] * b[i];
  return result;
}

static bool make_regularized_pseudoinverse(
    const double *original, int size, double regularization,
    double *inverse, std::vector<double> &normal,
    std::vector<double> &rhs, std::vector<double> &solution) {
  std::size_t cells = static_cast<std::size_t>(size) * size;
  double scale = 0.0;
  for (std::size_t pos = 0; pos < cells; ++pos) {
    if (!std::isfinite(original[pos])) return false;
    scale = std::max(scale, std::abs(original[pos]));
  }
  double lambda = regularization * std::max(1.0, scale * scale);
  if (!std::isfinite(lambda) || lambda <= 0.0) return false;
  std::fill(normal.begin(), normal.begin() + cells, 0.0);
  for (int row = 0; row < size; ++row) {
    for (int left = 0; left < size; ++left) {
      double left_value = original[row * size + left];
      for (int right = 0; right < size; ++right) {
        normal[left * size + right] +=
          left_value * original[row * size + right];
      }
    }
  }
  for (int diagonal = 0; diagonal < size; ++diagonal) {
    normal[diagonal * size + diagonal] += lambda;
  }
  for (int row = 0; row < size; ++row) {
    for (int col = 0; col <= row; ++col) {
      double value = normal[row * size + col];
      for (int inner = 0; inner < col; ++inner) {
        value -= normal[row * size + inner] *
          normal[col * size + inner];
      }
      if (row == col) {
        if (!std::isfinite(value) || value <= 0.0) return false;
        normal[row * size + col] = std::sqrt(value);
      } else {
        double diagonal = normal[col * size + col];
        if (!std::isfinite(diagonal) || diagonal == 0.0) return false;
        normal[row * size + col] = value / diagonal;
      }
    }
  }
  for (int input_row = 0; input_row < size; ++input_row) {
    for (int col = 0; col < size; ++col) {
      rhs[col] = original[input_row * size + col];
    }
    for (int row = 0; row < size; ++row) {
      double value = rhs[row];
      for (int col = 0; col < row; ++col) {
        value -= normal[row * size + col] * rhs[col];
      }
      rhs[row] = value / normal[row * size + row];
    }
    for (int row = size - 1; row >= 0; --row) {
      double value = rhs[row];
      for (int col = row + 1; col < size; ++col) {
        value -= normal[col * size + row] * solution[col];
      }
      solution[row] = value / normal[row * size + row];
    }
    for (int col = 0; col < size; ++col) {
      if (!std::isfinite(solution[col])) return false;
      inverse[col * size + input_row] = solution[col];
    }
  }
  return true;
}

static void sparse_matvec(const IntegerVector &p, const IntegerVector &i,
                          const NumericVector &x, const double *value,
                          double *result, int n) {
  std::fill(result, result + n, 0.0);
  for (int col = 0; col < n; ++col) {
    double input = value[col];
    if (input == 0.0) continue;
    for (int pos = p[col]; pos < p[col + 1]; ++pos) {
      result[i[pos]] += x[pos] * input;
    }
  }
}

static void sparse_matvec_scaled(const IntegerVector &p,
                                 const IntegerVector &i,
                                 const NumericVector &x,
                                 const double *value,
                                 double *result, int n,
                                 const std::vector<double> &row_scale,
                                 const std::vector<double> &column_scale) {
  std::fill(result, result + n, 0.0);
  for (int col = 0; col < n; ++col) {
    double input = column_scale[col] * value[col];
    if (input == 0.0) continue;
    for (int pos = p[col]; pos < p[col + 1]; ++pos) {
      result[i[pos]] += x[pos] * input;
    }
  }
  for (int row = 0; row < n; ++row) result[row] *= row_scale[row];
}

static void sparse_block_matvec_scaled(const IntegerVector &p,
                                       const IntegerVector &i,
                                       const NumericVector &x,
                                       const double *value,
                                       double *result, int n,
                                       const IntegerVector &row_group,
                                       const IntegerVector &column_group,
                                       const std::vector<double> &row_scale,
                                       const std::vector<double> &column_scale) {
  std::fill(result, result + n, 0.0);
  for (int col = 0; col < n; ++col) {
    double input = column_scale[col] * value[col];
    if (input == 0.0) continue;
    int group = column_group[col];
    for (int pos = p[col]; pos < p[col + 1]; ++pos) {
      int row = i[pos];
      if (row_group[row] == group) result[row] += x[pos] * input;
    }
  }
  for (int row = 0; row < n; ++row) result[row] *= row_scale[row];
}

static void apply_block_inverse(const std::vector<BlockFactors> &blocks,
                                const std::vector<double> &lu,
                                const std::vector<int> &pivots,
                                const std::vector<int> &row_member_offsets,
                                const std::vector<int> &row_members,
                                const std::vector<int> &row_local,
                                const std::vector<int> &col_member_offsets,
                                const std::vector<int> &col_members,
                                const std::vector<int> &col_local,
                                const double *input,
                                double *output,
                                int n) {
  std::fill(output, output + n, 0.0);
  std::vector<double> work(256, 0.0);
  for (int g = 0; g < static_cast<int>(blocks.size()); ++g) {
    const BlockFactors &block = blocks[g];
    int size = block.size;
    if (size > static_cast<int>(work.size())) work.resize(size);
    std::fill(work.begin(), work.begin() + size, 0.0);
    for (int member = row_member_offsets[g]; member < row_member_offsets[g + 1]; ++member) {
      int pos = row_members[member];
      work[row_local[pos]] = input[pos];
    }
    const double *factor = lu.data() + block.matrix_offset;
    const int *pivot = pivots.data() + block.pivot_offset;
    if (block.singular == 2) {
      std::vector<double> solved(size, 0.0);
      for (int col = 0; col < size; ++col) {
        solved[col] = work[col];
        for (int row = 0; row < size; ++row) {
          solved[col] += factor[col * size + row] * work[row];
        }
      }
      for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
        int pos = col_members[member];
        output[pos] = solved[col_local[pos]];
      }
      continue;
    }
    for (int k = 0; k < size; ++k) {
      int row = pivot[k];
      if (row != k) std::swap(work[k], work[row]);
    }
    if (block.singular) {
      for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
        int pos = col_members[member];
        output[pos] = work[col_local[pos]];
      }
      continue;
    }
    for (int k = 0; k < size; ++k) {
      for (int row = k + 1; row < size; ++row) {
        work[row] -= factor[row * size + k] * work[k];
      }
    }
    for (int k = size - 1; k >= 0; --k) {
      double value = work[k];
      for (int col = k + 1; col < size; ++col) {
        value -= factor[k * size + col] * work[col];
      }
      work[k] = value / factor[k * size + k];
    }
    for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
      int pos = col_members[member];
      output[pos] = work[col_local[pos]];
    }
  }
}

static void solve_block_group(const std::vector<BlockFactors> &blocks,
                              const std::vector<double> &lu,
                              const std::vector<int> &pivots,
                              const std::vector<unsigned char> &zero_pivots,
                              const std::vector<int> &row_member_offsets,
                              const std::vector<int> &row_members,
                              const std::vector<int> &row_local,
                              const std::vector<int> &col_member_offsets,
                              const std::vector<int> &col_members,
                              const std::vector<int> &col_local,
                              int g,
                              const double *input,
                              double *output,
                              std::vector<double> &work) {
  const BlockFactors &block = blocks[g];
  int size = block.size;
  if (size > static_cast<int>(work.size())) work.resize(size);
  std::fill(work.begin(), work.begin() + size, 0.0);
  for (int member = row_member_offsets[g]; member < row_member_offsets[g + 1]; ++member) {
    int pos = row_members[member];
    work[row_local[pos]] = input[pos];
  }
  const double *factor = lu.data() + block.matrix_offset;
  const int *pivot = pivots.data() + block.pivot_offset;
  if (block.singular == 2) {
    std::vector<double> solved(size, 0.0);
    for (int col = 0; col < size; ++col) {
      solved[col] = work[col];
      for (int row = 0; row < size; ++row) {
        solved[col] += factor[col * size + row] * work[row];
      }
    }
    for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
      int pos = col_members[member];
      output[pos] = solved[col_local[pos]];
    }
    return;
  }
  for (int k = 0; k < size; ++k) {
    int row = pivot[k];
    if (row != k) std::swap(work[k], work[row]);
  }
  if (block.singular) {
    for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
      int pos = col_members[member];
      output[pos] = work[col_local[pos]];
    }
    return;
  }
  for (int k = 0; k < size; ++k) {
    for (int row = k + 1; row < size; ++row) {
      work[row] -= factor[row * size + k] * work[k];
    }
  }
  for (int k = size - 1; k >= 0; --k) {
    if (zero_pivots[block.pivot_offset + k]) {
      work[k] = 0.0;
      continue;
    }
    double value = work[k];
    for (int col = k + 1; col < size; ++col) {
      value -= factor[k * size + col] * work[col];
    }
    work[k] = value / factor[k * size + k];
  }
  for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
    int pos = col_members[member];
    output[pos] = work[col_local[pos]];
  }
}

static void apply_gauss_seidel_inverse(const IntegerVector &p,
                                       const IntegerVector &i,
                                       const NumericVector &matrix_x,
                                       const std::vector<double> &row_scale,
                                       const std::vector<double> &column_scale,
                                       const std::vector<BlockFactors> &blocks,
                                       const std::vector<double> &lu,
                                       const std::vector<int> &pivots,
                                       const std::vector<unsigned char> &zero_pivots,
                                       const std::vector<int> &row_member_offsets,
                                       const std::vector<int> &row_members,
                                       const std::vector<int> &row_local,
                                       const std::vector<int> &col_member_offsets,
                                       const std::vector<int> &col_members,
                                       const std::vector<int> &col_local,
                                       const double *input,
                                       double *output,
                                       int n,
                                       int direction,
                                       int first_group = 0,
                                       int last_group = -1) {
  int n_groups = static_cast<int>(blocks.size());
  std::vector<double> residual(input, input + n);
  std::vector<double> work(256, 0.0);
  std::fill(output, output + n, 0.0);
  if (last_group < 0) last_group = n_groups - 1;
  int group_count = last_group - first_group + 1;
  for (int order = 0; order < group_count; ++order) {
    int g = direction > 0 ? first_group + order : last_group - order;
    solve_block_group(blocks, lu, pivots, zero_pivots, row_member_offsets, row_members,
                      row_local, col_member_offsets, col_members, col_local,
                      g, residual.data(), output, work);
    for (int member = col_member_offsets[g]; member < col_member_offsets[g + 1]; ++member) {
      int col = col_members[member];
      double scaled = column_scale[col] * output[col];
      if (scaled == 0.0) continue;
      for (int pos = p[col]; pos < p[col + 1]; ++pos) {
        int row = i[pos];
        residual[row] -= row_scale[row] * matrix_x[pos] * scaled;
      }
    }
  }
}

static void apply_symmetric_gauss_seidel_inverse(
    const IntegerVector &p,
    const IntegerVector &i,
    const NumericVector &matrix_x,
    const std::vector<double> &row_scale,
    const std::vector<double> &column_scale,
    const std::vector<BlockFactors> &blocks,
    const std::vector<double> &lu,
    const std::vector<int> &pivots,
    const std::vector<unsigned char> &zero_pivots,
    const std::vector<int> &row_member_offsets,
    const std::vector<int> &row_members,
    const std::vector<int> &row_local,
    const std::vector<int> &col_member_offsets,
    const std::vector<int> &col_members,
    const std::vector<int> &col_local,
    const double *input,
    double *output,
    int n) {
  std::vector<double> residual(n, 0.0);
  std::vector<double> correction(n, 0.0);
  std::vector<double> matvec(n, 0.0);
  apply_gauss_seidel_inverse(
    p, i, matrix_x, row_scale, column_scale, blocks, lu, pivots,
    zero_pivots,
    row_member_offsets, row_members, row_local,
    col_member_offsets, col_members, col_local,
    input, output, n, 1);
  sparse_matvec_scaled(p, i, matrix_x, output, matvec.data(), n,
                       row_scale, column_scale);
  for (int pos = 0; pos < n; ++pos) residual[pos] = input[pos] - matvec[pos];
  apply_gauss_seidel_inverse(
    p, i, matrix_x, row_scale, column_scale, blocks, lu, pivots,
    zero_pivots,
    row_member_offsets, row_members, row_local,
    col_member_offsets, col_members, col_local,
    residual.data(), correction.data(), n, -1);
  for (int pos = 0; pos < n; ++pos) output[pos] += correction[pos];
}

static void apply_smoothed_inverse(const IntegerVector &p,
                                   const IntegerVector &i,
                                   const NumericVector &matrix_x,
                                   const IntegerVector &row_group,
                                   const IntegerVector &column_group,
                                   const std::vector<double> &row_scale,
                                   const std::vector<double> &column_scale,
                                   const std::vector<BlockFactors> &blocks,
                                   const std::vector<double> &lu,
                                   const std::vector<int> &pivots,
                                   const std::vector<int> &row_member_offsets,
                                   const std::vector<int> &row_members,
                                   const std::vector<int> &row_local,
                                   const std::vector<int> &col_member_offsets,
                                   const std::vector<int> &col_members,
                                   const std::vector<int> &col_local,
                                   const double *input,
                                   double *output,
                                   int n,
                                   int smoothing,
                                   double *full_product,
                                   double *block_product,
                                   double *correction) {
  apply_block_inverse(blocks, lu, pivots, row_member_offsets, row_members,
                      row_local, col_member_offsets, col_members, col_local,
                      input, output, n);
  for (int pass = 0; pass < smoothing; ++pass) {
    sparse_matvec_scaled(p, i, matrix_x, output, full_product, n,
                         row_scale, column_scale);
    sparse_block_matvec_scaled(p, i, matrix_x, output, block_product, n,
                               row_group, column_group,
                               row_scale, column_scale);
    for (int g = 0; g < static_cast<int>(blocks.size()); ++g) {
      if (!blocks[g].singular) continue;
      int width = blocks[g].size;
      for (int k = 0; k < width; ++k) {
        int row = row_members[row_member_offsets[g] + k];
        int col = col_members[col_member_offsets[g] + k];
        block_product[row] = output[col];
      }
    }
    for (int pos = 0; pos < n; ++pos) {
      correction[pos] = input[pos] - full_product[pos] + block_product[pos];
    }
    apply_block_inverse(blocks, lu, pivots, row_member_offsets, row_members,
                        row_local, col_member_offsets, col_members, col_local,
                        correction, output, n);
  }
}

static double vector_norm(const double *value, int n) {
  return std::sqrt(dot_product(value, value, n));
}

// [[Rcpp::export]]
Rcpp::List solve_block_gmres(SEXP matrix_sexp, NumericVector rhs,
                             IntegerVector row_group,
                             IntegerVector column_group,
                             int n_groups, int restart, int max_iterations,
                             double tolerance, double pivot_tolerance,
                             double diagonal_shift,
                             int equilibration, int smoothing, int sweep, int method, int split_group) {
  Rcpp::S4 matrix(matrix_sexp);
  IntegerVector p = matrix.slot("p");
  IntegerVector i = matrix.slot("i");
  NumericVector x = matrix.slot("x");
  IntegerVector dimensions = matrix.slot("Dim");
  int n = dimensions[0];
  if (dimensions[1] != n || rhs.size() != n ||
      row_group.size() != n || column_group.size() != n) {
    Rcpp::stop("block GMRES received incompatible dimensions");
  }
  if (n_groups < 1 || restart < 1 || max_iterations < 1 ||
      !std::isfinite(tolerance) || tolerance <= 0 ||
      !std::isfinite(pivot_tolerance) || pivot_tolerance <= 0 ||
      !std::isfinite(diagonal_shift) || diagonal_shift < 0 ||
      (equilibration != 0 && equilibration != 1) || smoothing < 0 ||
      sweep < -4 || sweep > 2 || method < 0 || method > 8 ||
      split_group < 0 || split_group > n_groups) {
    Rcpp::stop("invalid block GMRES controls");
  }

  std::vector<double> row_scale(n, 1.0);
  std::vector<double> column_scale(n, 1.0);
  if (equilibration) {
    std::vector<double> row_norm(n, 0.0);
    std::vector<double> column_norm(n, 0.0);
    for (int col = 0; col < n; ++col) {
      for (int pos = p[col]; pos < p[col + 1]; ++pos) {
        double magnitude = std::abs(x[pos]);
        row_norm[i[pos]] = std::max(row_norm[i[pos]], magnitude);
        column_norm[col] = std::max(column_norm[col], magnitude);
      }
    }
    for (int pos = 0; pos < n; ++pos) {
      row_scale[pos] = 1.0 / std::max(row_norm[pos], 1e-12);
      column_scale[pos] = 1.0 / std::max(column_norm[pos], 1e-12);
    }
  }

  std::vector<int> row_size(n_groups, 0);
  std::vector<int> col_size(n_groups, 0);
  std::vector<int> row_local(n, -1);
  std::vector<int> col_local(n, -1);
  for (int pos = 0; pos < n; ++pos) {
    int rg = row_group[pos];
    int cg = column_group[pos];
    if (rg < 0 || rg >= n_groups || cg < 0 || cg >= n_groups) {
      Rcpp::stop("all rows and columns must belong to a block");
    }
    row_local[pos] = row_size[rg]++;
    col_local[pos] = col_size[cg]++;
  }
  for (int g = 0; g < n_groups; ++g) {
    if (row_size[g] != col_size[g] || row_size[g] == 0) {
      Rcpp::stop("block row and column sizes do not match");
    }
  }
  std::vector<int> member_offsets(n_groups + 1, 0);
  std::vector<int> col_member_offsets(n_groups + 1, 0);
  for (int g = 0; g < n_groups; ++g) {
    member_offsets[g + 1] = member_offsets[g] + row_size[g];
    col_member_offsets[g + 1] = col_member_offsets[g] + col_size[g];
  }
  std::vector<int> members(n, -1);
  std::vector<int> col_members(n, -1);
  std::vector<int> member_cursor = member_offsets;
  std::vector<int> col_member_cursor = col_member_offsets;
  for (int pos = 0; pos < n; ++pos) {
    int g = row_group[pos];
    members[member_cursor[g]++] = pos;
    g = column_group[pos];
    col_members[col_member_cursor[g]++] = pos;
  }

  std::vector<BlockFactors> blocks(n_groups);
  int max_block = 0;
  std::size_t matrix_total = 0;
  std::size_t pivot_total = 0;
  for (int g = 0; g < n_groups; ++g) {
    blocks[g].size = row_size[g];
    max_block = std::max(max_block, row_size[g]);
    blocks[g].matrix_offset = matrix_total;
    blocks[g].pivot_offset = pivot_total;
    blocks[g].singular = 0;
    matrix_total += static_cast<std::size_t>(row_size[g]) * row_size[g];
    pivot_total += row_size[g];
  }
  std::vector<double> lu(matrix_total, 0.0);
  std::vector<int> pivots(pivot_total, 0);
  std::vector<unsigned char> zero_pivots(pivot_total, 0);
  std::vector<double> original(static_cast<std::size_t>(max_block) * max_block, 0.0);
  std::vector<double> normal(static_cast<std::size_t>(max_block) * max_block, 0.0);
  std::vector<double> local_rhs(max_block, 0.0);
  std::vector<double> local_solution(max_block, 0.0);
  for (int col = 0; col < n; ++col) {
    int cg = column_group[col];
    int cpos = col_local[col];
    int size = blocks[cg].size;
    for (int pos = p[col]; pos < p[col + 1]; ++pos) {
      int row = i[pos];
      int rg = row_group[row];
      if (rg == cg) {
        lu[blocks[cg].matrix_offset +
           static_cast<std::size_t>(row_local[row]) * size + cpos] +=
          x[pos] * row_scale[row] * column_scale[col];
      }
    }
  }

  int singular_blocks = 0;
  std::vector<int> singular_group_ids;
  double min_abs_pivot = std::numeric_limits<double>::infinity();
  for (int g = 0; g < n_groups; ++g) {
    int size = blocks[g].size;
    double *factor = lu.data() + blocks[g].matrix_offset;
    int *pivot = pivots.data() + blocks[g].pivot_offset;
    std::size_t cells = static_cast<std::size_t>(size) * size;
    std::copy(factor, factor + cells, original.begin());
    if (diagonal_shift != 0.0) {
      for (int diagonal = 0; diagonal < size; ++diagonal) {
        original[static_cast<std::size_t>(diagonal) * size + diagonal] +=
          diagonal_shift;
      }
    }
    for (int k = 0; k < size; ++k) {
      if (diagonal_shift != 0.0) factor[k * size + k] += diagonal_shift;
      int best = k;
      double best_value = std::abs(factor[k * size + k]);
      for (int row = k + 1; row < size; ++row) {
        double candidate = std::abs(factor[row * size + k]);
        if (candidate > best_value) {
          best = row;
          best_value = candidate;
        }
      }
      pivot[k] = best;
      if (best != k) {
        for (int col = 0; col < size; ++col) {
          std::swap(factor[k * size + col], factor[best * size + col]);
        }
      }
      double diagonal = factor[k * size + k];
      min_abs_pivot = std::min(min_abs_pivot, std::abs(diagonal));
      if (!std::isfinite(diagonal) || std::abs(diagonal) < pivot_tolerance) {
        blocks[g].singular = 1;
        zero_pivots[blocks[g].pivot_offset + k] = 1;
        ++singular_blocks;
        double replacement = (diagonal < 0 ? -pivot_tolerance : pivot_tolerance);
        if (!std::isfinite(replacement) || replacement == 0.0) replacement = pivot_tolerance;
        factor[k * size + k] = replacement;
        diagonal = replacement;
      }
      for (int row = k + 1; row < size; ++row) {
        factor[row * size + k] /= diagonal;
        double multiplier = factor[row * size + k];
        for (int col = k + 1; col < size; ++col) {
          factor[row * size + col] -= multiplier * factor[k * size + col];
        }
      }
    }
    if (blocks[g].singular && make_regularized_pseudoinverse(
        original.data(), size, 1e-8, factor, normal,
        local_rhs, local_solution)) {
      blocks[g].singular = 2;
    }
    if (blocks[g].singular) singular_group_ids.push_back(g);
  }

  std::vector<double> raw_rhs(rhs.begin(), rhs.end());
  std::vector<double> b(n, 0.0);
  for (int pos = 0; pos < n; ++pos) b[pos] = row_scale[pos] * raw_rhs[pos];
  std::vector<double> preconditioned_rhs(n, 0.0);
  std::vector<double> full_product(n, 0.0);
  std::vector<double> block_product(n, 0.0);
  std::vector<double> correction(n, 0.0);
  auto apply_preconditioner = [&](const double *input, double *output) {
    if (sweep == -4) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        input, output, n, -1);
      sparse_matvec_scaled(p, i, x, output, full_product.data(), n,
                           row_scale, column_scale);
      for (int pos = 0; pos < n; ++pos) {
        correction[pos] = input[pos] - full_product[pos];
      }
      if (split_group < n_groups) {
        apply_gauss_seidel_inverse(
          p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
          member_offsets, members, row_local,
          col_member_offsets, col_members, col_local,
          correction.data(), block_product.data(), n, -1,
          split_group, n_groups - 1);
        for (int pos = 0; pos < n; ++pos) {
          output[pos] += block_product[pos];
        }
      }
    } else if (sweep == -3) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        input, output, n, -1);
      sparse_matvec_scaled(p, i, x, output, full_product.data(), n,
                           row_scale, column_scale);
      for (int pos = 0; pos < n; ++pos) {
        correction[pos] = input[pos] - full_product[pos];
      }
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        correction.data(), block_product.data(), n, 1);
      for (int pos = 0; pos < n; ++pos) {
        output[pos] += block_product[pos];
      }
    } else if (sweep == -2) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        input, output, n, -1);
      sparse_matvec_scaled(p, i, x, output, full_product.data(), n,
                           row_scale, column_scale);
      for (int pos = 0; pos < n; ++pos) {
        correction[pos] = input[pos] - full_product[pos];
      }
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        correction.data(), block_product.data(), n, -1);
      for (int pos = 0; pos < n; ++pos) {
        output[pos] += block_product[pos];
      }
    } else if (sweep == 2) {
      apply_symmetric_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        input, output, n);
    } else if (sweep != 0) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        input, output, n, sweep);
    } else {
      apply_smoothed_inverse(
        p, i, x, row_group, column_group, row_scale, column_scale,
        blocks, lu, pivots, member_offsets, members, row_local,
        col_member_offsets, col_members, col_local, input, output, n,
        smoothing, full_product.data(), block_product.data(),
        correction.data());
    }
  };
  apply_preconditioner(b.data(), preconditioned_rhs.data());
  double beta = vector_norm(preconditioned_rhs.data(), n);
  double target = tolerance * std::max(1.0, beta);
  std::vector<double> solution(n, 0.0);
  std::vector<double> residual(n, 0.0);
  std::vector<double> matvec(n, 0.0);
  std::vector<double> preconditioned(n, 0.0);
  std::vector<double> raw_matvec(n, 0.0);
  std::vector<double> raw_residual(n, 0.0);
  std::vector<double> unscaled_solution(n, 0.0);
  int iterations = 0;
  double estimated_residual = beta;
  double true_residual = std::numeric_limits<double>::infinity();
  bool converged = false;
  int actual_restart = std::min(restart, 64);
  std::vector<double> basis;
  if (method == 0 || method == 3 || method == 6) basis.assign(static_cast<std::size_t>(actual_restart + 1) * n, 0.0);
  std::vector<double> h(static_cast<std::size_t>(actual_restart + 1) * actual_restart, 0.0);
  std::vector<double> cs(actual_restart, 0.0);
  std::vector<double> sn(actual_restart, 0.0);
  double refinement_alpha = std::numeric_limits<double>::quiet_NaN();
  double refinement_direction_norm = 0.0;
  double schur_rhs_norm = std::numeric_limits<double>::quiet_NaN();
  double schur_operator_norm = std::numeric_limits<double>::quiet_NaN();
  std::vector<double> g(actual_restart + 1, 0.0);
  std::vector<double> y(actual_restart, 0.0);

  auto basis_at = [&](int k) { return basis.data() + static_cast<std::size_t>(k) * n; };
  auto h_at = [&](int row, int col) -> double & {
    return h[static_cast<std::size_t>(col) * (actual_restart + 1) + row];
  };

  if (method == 8) {
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      b.data(), solution.data(), n, -1);
    sparse_matvec_scaled(p, i, x, solution.data(), matvec.data(), n,
                         row_scale, column_scale);
    for (int pos = 0; pos < n; ++pos) {
      residual[pos] = b[pos] - matvec[pos];
    }
    double forward_norm = vector_norm(residual.data(), n);
    estimated_residual = forward_norm;
    ++iterations;
    target = tolerance * std::max(1.0, forward_norm);
    while (iterations < max_iterations && forward_norm > target) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        residual.data(), preconditioned.data(), n, 1);
      sparse_matvec_scaled(p, i, x, preconditioned.data(), matvec.data(), n,
                           row_scale, column_scale);
      double denominator = dot_product(matvec.data(), matvec.data(), n);
      if (!std::isfinite(denominator) || denominator < 1e-30) break;
      double numerator = dot_product(matvec.data(), residual.data(), n);
      double alpha = numerator / denominator;
      if (!std::isfinite(alpha)) break;
      for (int pos = 0; pos < n; ++pos) {
        solution[pos] += alpha * preconditioned[pos];
        residual[pos] -= alpha * matvec[pos];
      }
      forward_norm = vector_norm(residual.data(), n);
      if (!std::isfinite(forward_norm)) break;
      estimated_residual = forward_norm;
      ++iterations;
    }
    preconditioned_rhs = residual;
    beta = forward_norm;
  } else if (method == 7) {
    if (split_group <= 0 || split_group >= n_groups) {
      Rcpp::stop("alternating mode requires a nonempty bilateral and Schur range");
    }
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      b.data(), solution.data(), n, -1);
    sparse_matvec_scaled(p, i, x, solution.data(), matvec.data(), n,
                         row_scale, column_scale);
    for (int pos = 0; pos < n; ++pos) {
      residual[pos] = b[pos] - matvec[pos];
    }
    double alternating_norm = vector_norm(residual.data(), n);
    estimated_residual = alternating_norm;
    ++iterations;
    target = tolerance * std::max(1.0, alternating_norm);
    while (iterations < max_iterations && alternating_norm > target) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        residual.data(), preconditioned.data(), n, -1,
        0, split_group - 1);
      sparse_matvec_scaled(p, i, x, preconditioned.data(), matvec.data(), n,
                           row_scale, column_scale);
      for (int pos = 0; pos < n; ++pos) {
        solution[pos] += preconditioned[pos];
        residual[pos] -= matvec[pos];
      }
      alternating_norm = vector_norm(residual.data(), n);
      estimated_residual = alternating_norm;
      ++iterations;
      if (!std::isfinite(alternating_norm) ||
          alternating_norm <= target || iterations >= max_iterations) break;
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        residual.data(), preconditioned.data(), n, -1,
        split_group, n_groups - 1);
      sparse_matvec_scaled(p, i, x, preconditioned.data(), matvec.data(), n,
                           row_scale, column_scale);
      for (int pos = 0; pos < n; ++pos) {
        solution[pos] += preconditioned[pos];
        residual[pos] -= matvec[pos];
      }
      alternating_norm = vector_norm(residual.data(), n);
      estimated_residual = alternating_norm;
      ++iterations;
    }
    preconditioned_rhs = residual;
    beta = alternating_norm;
  } else if (method == 6) {
    if (split_group <= 0 || split_group >= n_groups) {
      Rcpp::stop("Schur mode requires a nonempty bilateral and Schur range");
    }
    std::vector<double> schur_rhs(n, 0.0);
    std::vector<double> schur_residual(n, 0.0);
    std::vector<double> schur_solution(n, 0.0);
    std::vector<double> schur_direction(n, 0.0);
    std::vector<double> schur_operator(n, 0.0);
    std::vector<double> block_rhs(n, 0.0);
    std::vector<double> block_solution(n, 0.0);
    auto apply_schur = [&](const double *input, double *output) {
      sparse_matvec_scaled(p, i, x, input, full_product.data(), n,
                           row_scale, column_scale);
      std::fill(block_rhs.begin(), block_rhs.end(), 0.0);
      for (int pos = 0; pos < split_group; ++pos) {
        block_rhs[pos] = full_product[pos];
      }
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        block_rhs.data(), block_solution.data(), n, -1,
        0, split_group - 1);
      sparse_matvec_scaled(p, i, x, block_solution.data(),
                           block_product.data(), n, row_scale, column_scale);
      std::fill(output, output + n, 0.0);
      for (int pos = split_group; pos < n; ++pos) {
        output[pos] = full_product[pos] - block_product[pos];
      }
    };
    bool staged = sweep == -2;
    if (staged) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        b.data(), solution.data(), n, -1);
      sparse_matvec_scaled(p, i, x, solution.data(),
                           full_product.data(), n, row_scale, column_scale);
      for (int pos = 0; pos < n; ++pos) {
        residual[pos] = b[pos] - full_product[pos];
      }
    }
    for (int pos = 0; pos < split_group; ++pos) {
      block_rhs[pos] = staged ? residual[pos] : b[pos];
    }
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      block_rhs.data(), block_solution.data(), n, -1,
      0, split_group - 1);
    sparse_matvec_scaled(p, i, x, block_solution.data(),
                         full_product.data(), n, row_scale, column_scale);
    for (int pos = split_group; pos < n; ++pos) {
      schur_rhs[pos] = (staged ? residual[pos] : b[pos]) -
        full_product[pos];
      schur_residual[pos] = schur_rhs[pos];
    }
    double schur_beta = vector_norm(schur_residual.data(), n);
    schur_rhs_norm = schur_beta;
    target = tolerance * std::max(1.0, schur_beta);
    std::vector<double> z_basis(
      static_cast<std::size_t>(actual_restart) * n, 0.0);
    while (iterations < max_iterations && schur_beta > target) {
      std::fill(h.begin(), h.end(), 0.0);
      std::fill(g.begin(), g.end(), 0.0);
      double *first = basis_at(0);
      for (int pos = 0; pos < n; ++pos) {
        first[pos] = schur_residual[pos] / schur_beta;
      }
      g[0] = schur_beta;
      int inner_done = 0;
      for (int j = 0; j < actual_restart && iterations < max_iterations; ++j) {
        if (sweep == 0 || sweep == -2) {
          std::fill(schur_direction.begin(), schur_direction.end(), 0.0);
          for (int pos = split_group; pos < n; ++pos) {
            schur_direction[pos] = basis_at(j)[pos];
          }
        } else {
          apply_gauss_seidel_inverse(
            p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
            member_offsets, members, row_local,
            col_member_offsets, col_members, col_local,
            basis_at(j), schur_direction.data(), n, -1,
            split_group, n_groups - 1);
        }
        double *z = z_basis.data() + static_cast<std::size_t>(j) * n;
        std::copy(schur_direction.begin(), schur_direction.end(), z);
        apply_schur(z, schur_operator.data());
        for (int k = 0; k <= j; ++k) {
          double value = dot_product(basis_at(k), schur_operator.data(), n);
          h_at(k, j) = value;
          for (int pos = split_group; pos < n; ++pos) {
            schur_operator[pos] -= value * basis_at(k)[pos];
          }
        }
        schur_operator_norm = vector_norm(schur_operator.data(), n);
        double next_norm = vector_norm(schur_operator.data(), n);
        h_at(j + 1, j) = next_norm;
        if (next_norm > 0.0 && std::isfinite(next_norm)) {
          double *next = basis_at(j + 1);
          std::fill(next, next + n, 0.0);
          for (int pos = split_group; pos < n; ++pos) {
            next[pos] = schur_operator[pos] / next_norm;
          }
        }
        for (int k = 0; k < j; ++k) {
          double top = cs[k] * h_at(k, j) + sn[k] * h_at(k + 1, j);
          h_at(k + 1, j) = -sn[k] * h_at(k, j) +
            cs[k] * h_at(k + 1, j);
          h_at(k, j) = top;
        }
        double denominator = std::hypot(h_at(j, j), h_at(j + 1, j));
        if (denominator == 0.0 || !std::isfinite(denominator)) {
          cs[j] = 1.0;
          sn[j] = 0.0;
        } else {
          cs[j] = h_at(j, j) / denominator;
          sn[j] = h_at(j + 1, j) / denominator;
        }
        h_at(j, j) = cs[j] * h_at(j, j) +
          sn[j] * h_at(j + 1, j);
        h_at(j + 1, j) = 0.0;
        g[j + 1] = -sn[j] * g[j];
        g[j] = cs[j] * g[j];
        estimated_residual = std::abs(g[j + 1]);
        ++iterations;
        inner_done = j + 1;
        if (estimated_residual <= target || next_norm == 0.0) break;
      }
      if (inner_done == 0) break;
      for (int row = inner_done - 1; row >= 0; --row) {
        double value = g[row];
        for (int col = row + 1; col < inner_done; ++col) {
          value -= h_at(row, col) * y[col];
        }
        y[row] = value / h_at(row, row);
      }
      for (int col = 0; col < inner_done; ++col) {
        const double *z = z_basis.data() + static_cast<std::size_t>(col) * n;
        double value = y[col];
        for (int pos = split_group; pos < n; ++pos) {
          schur_solution[pos] += value * z[pos];
        }
      }
      apply_schur(schur_solution.data(), schur_operator.data());
      for (int pos = split_group; pos < n; ++pos) {
        schur_residual[pos] = schur_rhs[pos] - schur_operator[pos];
      }
      schur_beta = vector_norm(schur_residual.data(), n);
      estimated_residual = schur_beta;
      if (!std::isfinite(schur_beta)) break;
      if (schur_beta <= target) {
        converged = true;
        break;
      }
      std::fill(y.begin(), y.end(), 0.0);
    }
    apply_schur(schur_solution.data(), schur_operator.data());
    std::fill(block_rhs.begin(), block_rhs.end(), 0.0);
    for (int pos = 0; pos < split_group; ++pos) {
      block_rhs[pos] = (staged ? residual[pos] : b[pos]) -
        full_product[pos];
    }
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      block_rhs.data(), block_solution.data(), n, -1,
      0, split_group - 1);
    for (int pos = 0; pos < n; ++pos) {
      solution[pos] = (staged ? solution[pos] : 0.0) +
        schur_solution[pos] + block_solution[pos];
    }
    refinement_alpha = vector_norm(schur_solution.data(), n);
    refinement_direction_norm = vector_norm(block_solution.data(), n);
    preconditioned_rhs = schur_residual;
    beta = schur_beta;
  } else if (method == 5) {
    if (split_group <= 0 || split_group >= n_groups) {
      Rcpp::stop("Schur mode requires a nonempty bilateral and Schur range");
    }
    std::vector<double> schur_rhs(n, 0.0);
    std::vector<double> schur_residual(n, 0.0);
    std::vector<double> schur_solution(n, 0.0);
    std::vector<double> schur_direction(n, 0.0);
    std::vector<double> schur_operator(n, 0.0);
    std::vector<double> block_rhs(n, 0.0);
    std::vector<double> block_solution(n, 0.0);
    for (int pos = 0; pos < split_group; ++pos) {
      block_rhs[pos] = b[pos];
    }
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      block_rhs.data(), block_solution.data(), n, -1,
      0, split_group - 1);
    sparse_matvec_scaled(p, i, x, block_solution.data(),
                         full_product.data(), n, row_scale, column_scale);
    for (int pos = split_group; pos < n; ++pos) {
      schur_rhs[pos] = b[pos] - full_product[pos];
      schur_residual[pos] = schur_rhs[pos];
    }
    double schur_norm = vector_norm(schur_residual.data(), n);
    estimated_residual = schur_norm;
    target = tolerance * std::max(1.0, schur_norm);
    while (iterations < max_iterations && schur_norm > target) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        schur_residual.data(), schur_direction.data(), n, -1,
        split_group, n_groups - 1);
      sparse_matvec_scaled(p, i, x, schur_direction.data(),
                           full_product.data(), n, row_scale, column_scale);
      std::fill(block_rhs.begin(), block_rhs.end(), 0.0);
      for (int pos = 0; pos < split_group; ++pos) {
        block_rhs[pos] = full_product[pos];
      }
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        block_rhs.data(), block_solution.data(), n, -1,
        0, split_group - 1);
      sparse_matvec_scaled(p, i, x, block_solution.data(),
                           block_product.data(), n, row_scale, column_scale);
      double denominator = 0.0;
      double numerator = 0.0;
      for (int pos = split_group; pos < n; ++pos) {
        schur_operator[pos] = full_product[pos] - block_product[pos];
        denominator += schur_operator[pos] * schur_operator[pos];
        numerator += schur_operator[pos] * schur_residual[pos];
      }
      if (!std::isfinite(denominator) || denominator < 1e-30) break;
      double alpha = numerator / denominator;
      if (!std::isfinite(alpha)) break;
      for (int pos = split_group; pos < n; ++pos) {
        schur_solution[pos] += alpha * schur_direction[pos];
        schur_residual[pos] -= alpha * schur_operator[pos];
      }
      schur_norm = vector_norm(schur_residual.data(), n);
      if (!std::isfinite(schur_norm)) break;
      estimated_residual = schur_norm;
      ++iterations;
    }
    sparse_matvec_scaled(p, i, x, schur_solution.data(),
                         full_product.data(), n, row_scale, column_scale);
    std::fill(block_rhs.begin(), block_rhs.end(), 0.0);
    for (int pos = 0; pos < split_group; ++pos) {
      block_rhs[pos] = b[pos] - full_product[pos];
    }
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      block_rhs.data(), block_solution.data(), n, -1,
      0, split_group - 1);
    for (int pos = 0; pos < n; ++pos) {
      solution[pos] = schur_solution[pos] + block_solution[pos];
    }
    preconditioned_rhs = schur_residual;
    beta = schur_norm;
  } else if (method == 4) {
    std::vector<double> staged_residual = b;
    apply_gauss_seidel_inverse(
      p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
      member_offsets, members, row_local,
      col_member_offsets, col_members, col_local,
      b.data(), solution.data(), n, -1);
    sparse_matvec_scaled(p, i, x, solution.data(), matvec.data(), n,
                         row_scale, column_scale);
    for (int pos = 0; pos < n; ++pos) {
      staged_residual[pos] = b[pos] - matvec[pos];
    }
    double residual_norm = vector_norm(staged_residual.data(), n);
    estimated_residual = residual_norm;
    ++iterations;
    target = tolerance * std::max(1.0, residual_norm);
    while (iterations < max_iterations && residual_norm > target &&
           split_group < n_groups) {
      apply_gauss_seidel_inverse(
        p, i, x, row_scale, column_scale, blocks, lu, pivots, zero_pivots,
        member_offsets, members, row_local,
        col_member_offsets, col_members, col_local,
        staged_residual.data(), preconditioned.data(), n, -1,
        split_group, n_groups - 1);
      sparse_matvec_scaled(p, i, x, preconditioned.data(), matvec.data(), n,
                           row_scale, column_scale);
      double denominator = 0.0;
      double numerator = 0.0;
      for (int pos = 0; pos < n; ++pos) {
        if (row_group[pos] >= split_group) {
          denominator += matvec[pos] * matvec[pos];
          numerator += matvec[pos] * staged_residual[pos];
        }
      }
      if (!std::isfinite(denominator) || denominator < 1e-30) break;
      double alpha = numerator / denominator;
      refinement_alpha = alpha;
      refinement_direction_norm = vector_norm(preconditioned.data(), n);
      if (!std::isfinite(alpha)) break;
      for (int pos = 0; pos < n; ++pos) {
        solution[pos] += alpha * preconditioned[pos];
        staged_residual[pos] -= alpha * matvec[pos];
      }
      residual_norm = vector_norm(staged_residual.data(), n);
      if (!std::isfinite(residual_norm)) break;
      estimated_residual = residual_norm;
      ++iterations;
    }
    preconditioned_rhs = staged_residual;
    beta = residual_norm;
  } else if (method == 3) {
    std::vector<double> right_solution(n, 0.0);
    std::vector<double> right_residual = raw_rhs;
    std::vector<double> right_matvec(n, 0.0);
    std::vector<double> preconditioner_input(n, 0.0);
    std::vector<double> z_basis(
      static_cast<std::size_t>(actual_restart) * n, 0.0);
    double raw_beta = vector_norm(right_residual.data(), n);
    target = tolerance * std::max(1.0, raw_beta);
    while (iterations < max_iterations && raw_beta > target) {
      std::fill(h.begin(), h.end(), 0.0);
      std::fill(g.begin(), g.end(), 0.0);
      double *first = basis_at(0);
      for (int pos = 0; pos < n; ++pos) {
        first[pos] = right_residual[pos] / raw_beta;
      }
      g[0] = raw_beta;
      int inner_done = 0;
      for (int j = 0; j < actual_restart && iterations < max_iterations; ++j) {
        for (int pos = 0; pos < n; ++pos) {
          preconditioner_input[pos] = row_scale[pos] * basis_at(j)[pos];
        }
        apply_preconditioner(preconditioner_input.data(),
                             preconditioned.data());
        double *z = z_basis.data() + static_cast<std::size_t>(j) * n;
        for (int pos = 0; pos < n; ++pos) {
          z[pos] = column_scale[pos] * preconditioned[pos];
        }
        sparse_matvec(p, i, x, z, right_matvec.data(), n);
        for (int k = 0; k <= j; ++k) {
          double value = dot_product(basis_at(k), right_matvec.data(), n);
          h_at(k, j) = value;
          for (int pos = 0; pos < n; ++pos) {
            right_matvec[pos] -= value * basis_at(k)[pos];
          }
        }
        double next_norm = vector_norm(right_matvec.data(), n);
        h_at(j + 1, j) = next_norm;
        if (next_norm > 0.0 && std::isfinite(next_norm)) {
          double *next = basis_at(j + 1);
          for (int pos = 0; pos < n; ++pos) {
            next[pos] = right_matvec[pos] / next_norm;
          }
        }
        for (int k = 0; k < j; ++k) {
          double top = cs[k] * h_at(k, j) + sn[k] * h_at(k + 1, j);
          h_at(k + 1, j) = -sn[k] * h_at(k, j) +
            cs[k] * h_at(k + 1, j);
          h_at(k, j) = top;
        }
        double denominator = std::hypot(h_at(j, j), h_at(j + 1, j));
        if (denominator == 0.0 || !std::isfinite(denominator)) {
          cs[j] = 1.0;
          sn[j] = 0.0;
        } else {
          cs[j] = h_at(j, j) / denominator;
          sn[j] = h_at(j + 1, j) / denominator;
        }
        h_at(j, j) = cs[j] * h_at(j, j) +
          sn[j] * h_at(j + 1, j);
        h_at(j + 1, j) = 0.0;
        g[j + 1] = -sn[j] * g[j];
        g[j] = cs[j] * g[j];
        estimated_residual = std::abs(g[j + 1]);
        ++iterations;
        inner_done = j + 1;
        if (estimated_residual <= target || next_norm == 0.0) break;
      }
      if (inner_done == 0) break;
      for (int row = inner_done - 1; row >= 0; --row) {
        double value = g[row];
        for (int col = row + 1; col < inner_done; ++col) {
          value -= h_at(row, col) * y[col];
        }
        y[row] = value / h_at(row, row);
      }
      for (int col = 0; col < inner_done; ++col) {
        const double *z = z_basis.data() + static_cast<std::size_t>(col) * n;
        double value = y[col];
        for (int pos = 0; pos < n; ++pos) {
          right_solution[pos] += value * z[pos];
        }
      }
      sparse_matvec(p, i, x, right_solution.data(), right_matvec.data(), n);
      for (int pos = 0; pos < n; ++pos) {
        right_residual[pos] = raw_rhs[pos] - right_matvec[pos];
      }
      raw_beta = vector_norm(right_residual.data(), n);
      true_residual = raw_beta /
        std::max(1.0, vector_norm(raw_rhs.data(), n));
      if (true_residual <= tolerance) {
        converged = true;
        break;
      }
      std::fill(y.begin(), y.end(), 0.0);
    }
    for (int pos = 0; pos < n; ++pos) {
      solution[pos] = right_solution[pos] / column_scale[pos];
    }
    beta = raw_beta;
  } else if (method == 2) {
    std::vector<double> richardson_residual = b;
    double residual_norm = vector_norm(richardson_residual.data(), n);
    target = tolerance * std::max(1.0, residual_norm);
    while (iterations < max_iterations && residual_norm > target) {
      apply_preconditioner(richardson_residual.data(), preconditioned.data());
      sparse_matvec_scaled(p, i, x, preconditioned.data(), matvec.data(), n,
                           row_scale, column_scale);
      double denominator = dot_product(matvec.data(), matvec.data(), n);
      if (!std::isfinite(denominator) || denominator < 1e-30) break;
      double numerator = dot_product(matvec.data(),
                                     richardson_residual.data(), n);
      double alpha = numerator / denominator;
      if (!std::isfinite(alpha)) break;
      for (int pos = 0; pos < n; ++pos) {
        solution[pos] += alpha * preconditioned[pos];
        richardson_residual[pos] -= alpha * matvec[pos];
      }
      residual_norm = vector_norm(richardson_residual.data(), n);
      if (!std::isfinite(residual_norm)) break;
      estimated_residual = residual_norm;
      ++iterations;
    }
    preconditioned_rhs = richardson_residual;
    beta = residual_norm;
  } else if (method == 1) {
    std::vector<double> r_bicg = preconditioned_rhs;
    std::vector<double> rhat_bicg = r_bicg;
    std::vector<double> p_bicg(n, 0.0);
    std::vector<double> v_bicg(n, 0.0);
    std::vector<double> s_bicg(n, 0.0);
    std::vector<double> t_bicg(n, 0.0);
    double rho_old = 1.0;
    double alpha_bicg = 1.0;
    double omega_bicg = 1.0;
    double residual_norm = beta;
    while (iterations < max_iterations && residual_norm > target) {
      double rho = dot_product(rhat_bicg.data(), r_bicg.data(), n);
      if (!std::isfinite(rho) || std::abs(rho) < 1e-30) break;
      if (iterations == 0) {
        p_bicg = r_bicg;
      } else {
        if (!std::isfinite(omega_bicg) || std::abs(omega_bicg) < 1e-30) break;
        double beta_bicg = (rho / rho_old) * (alpha_bicg / omega_bicg);
        for (int pos = 0; pos < n; ++pos) {
          p_bicg[pos] = r_bicg[pos] + beta_bicg *
            (p_bicg[pos] - omega_bicg * v_bicg[pos]);
        }
      }
      sparse_matvec_scaled(p, i, x, p_bicg.data(), matvec.data(), n,
                           row_scale, column_scale);
      apply_preconditioner(matvec.data(), preconditioned.data());
      v_bicg = preconditioned;
      double denominator = dot_product(rhat_bicg.data(), v_bicg.data(), n);
      if (!std::isfinite(denominator) || std::abs(denominator) < 1e-30) break;
      alpha_bicg = rho / denominator;
      for (int pos = 0; pos < n; ++pos) {
        s_bicg[pos] = r_bicg[pos] - alpha_bicg * v_bicg[pos];
      }
      double s_norm = vector_norm(s_bicg.data(), n);
      if (!std::isfinite(s_norm)) break;
      if (s_norm <= target) {
        for (int pos = 0; pos < n; ++pos) solution[pos] += alpha_bicg * p_bicg[pos];
        r_bicg = s_bicg;
        residual_norm = s_norm;
        estimated_residual = residual_norm;
        ++iterations;
        break;
      }
      sparse_matvec_scaled(p, i, x, s_bicg.data(), matvec.data(), n,
                           row_scale, column_scale);
      apply_preconditioner(matvec.data(), preconditioned.data());
      t_bicg = preconditioned;
      double tt = dot_product(t_bicg.data(), t_bicg.data(), n);
      if (!std::isfinite(tt) || tt < 1e-30) break;
      omega_bicg = dot_product(t_bicg.data(), s_bicg.data(), n) / tt;
      if (!std::isfinite(omega_bicg) || std::abs(omega_bicg) < 1e-30) break;
      for (int pos = 0; pos < n; ++pos) {
        solution[pos] += alpha_bicg * p_bicg[pos] + omega_bicg * s_bicg[pos];
        r_bicg[pos] = s_bicg[pos] - omega_bicg * t_bicg[pos];
      }
      residual_norm = vector_norm(r_bicg.data(), n);
      if (!std::isfinite(residual_norm)) break;
      estimated_residual = residual_norm;
      ++iterations;
      rho_old = rho;
    }
    preconditioned_rhs = r_bicg;
    beta = residual_norm;
  } else {
    while (iterations < max_iterations && beta > target) {
    std::fill(h.begin(), h.end(), 0.0);
    std::fill(g.begin(), g.end(), 0.0);
    double *first = basis_at(0);
    for (int pos = 0; pos < n; ++pos) first[pos] = preconditioned_rhs[pos] / beta;
    g[0] = beta;
    int inner_done = 0;
    for (int j = 0; j < actual_restart && iterations < max_iterations; ++j) {
      double *v = basis_at(j);
      sparse_matvec_scaled(p, i, x, v, matvec.data(), n,
                           row_scale, column_scale);
      apply_preconditioner(matvec.data(), preconditioned.data());
      for (int k = 0; k <= j; ++k) {
        double value = dot_product(basis_at(k), preconditioned.data(), n);
        h_at(k, j) = value;
        for (int pos = 0; pos < n; ++pos) {
          preconditioned[pos] -= value * basis_at(k)[pos];
        }
      }
      double next_norm = vector_norm(preconditioned.data(), n);
      h_at(j + 1, j) = next_norm;
      if (next_norm > 0.0 && std::isfinite(next_norm)) {
        double *next = basis_at(j + 1);
        for (int pos = 0; pos < n; ++pos) next[pos] = preconditioned[pos] / next_norm;
      }
      for (int k = 0; k < j; ++k) {
        double top = cs[k] * h_at(k, j) + sn[k] * h_at(k + 1, j);
        h_at(k + 1, j) = -sn[k] * h_at(k, j) + cs[k] * h_at(k + 1, j);
        h_at(k, j) = top;
      }
      double denominator = std::hypot(h_at(j, j), h_at(j + 1, j));
      if (denominator == 0.0 || !std::isfinite(denominator)) {
        cs[j] = 1.0;
        sn[j] = 0.0;
      } else {
        cs[j] = h_at(j, j) / denominator;
        sn[j] = h_at(j + 1, j) / denominator;
      }
      h_at(j, j) = cs[j] * h_at(j, j) + sn[j] * h_at(j + 1, j);
      h_at(j + 1, j) = 0.0;
      g[j + 1] = -sn[j] * g[j];
      g[j] = cs[j] * g[j];
      estimated_residual = std::abs(g[j + 1]);
      ++iterations;
      inner_done = j + 1;
      if (estimated_residual <= target || next_norm == 0.0) break;
    }
    if (inner_done == 0) break;
    for (int row = inner_done - 1; row >= 0; --row) {
      double value = g[row];
      for (int col = row + 1; col < inner_done; ++col) value -= h_at(row, col) * y[col];
      y[row] = value / h_at(row, row);
    }
    for (int col = 0; col < inner_done; ++col) {
      double value = y[col];
      for (int pos = 0; pos < n; ++pos) solution[pos] += value * basis_at(col)[pos];
    }
    sparse_matvec_scaled(p, i, x, solution.data(), matvec.data(), n,
                         row_scale, column_scale);
    for (int pos = 0; pos < n; ++pos) residual[pos] = b[pos] - matvec[pos];
    apply_preconditioner(residual.data(), preconditioned_rhs.data());
    beta = vector_norm(preconditioned_rhs.data(), n);
    for (int pos = 0; pos < n; ++pos) {
      unscaled_solution[pos] = column_scale[pos] * solution[pos];
    }
    sparse_matvec(p, i, x, unscaled_solution.data(), raw_matvec.data(), n);
    for (int pos = 0; pos < n; ++pos) raw_residual[pos] = raw_matvec[pos] - raw_rhs[pos];
    true_residual = vector_norm(raw_residual.data(), n) /
      std::max(1.0, vector_norm(raw_rhs.data(), n));
    if (true_residual <= tolerance) {
      converged = true;
      break;
    }
    std::fill(y.begin(), y.end(), 0.0);
  }
  }
  if (!std::isfinite(true_residual)) {
    for (int pos = 0; pos < n; ++pos) {
      unscaled_solution[pos] = column_scale[pos] * solution[pos];
    }
    sparse_matvec(p, i, x, unscaled_solution.data(), raw_matvec.data(), n);
    for (int pos = 0; pos < n; ++pos) raw_residual[pos] = raw_matvec[pos] - raw_rhs[pos];
    true_residual = vector_norm(raw_residual.data(), n) /
      std::max(1.0, vector_norm(raw_rhs.data(), n));
  }
  NumericVector returned_solution(n);
  for (int pos = 0; pos < n; ++pos) returned_solution[pos] = column_scale[pos] * solution[pos];
  return List::create(
    Rcpp::_["solution"] = returned_solution,
    Rcpp::_["converged"] = converged,
    Rcpp::_["iterations"] = iterations,
    Rcpp::_["estimated_preconditioned_residual"] = estimated_residual,
    Rcpp::_["true_relative_residual"] = true_residual,
    Rcpp::_["schur_rhs_norm"] = schur_rhs_norm,
    Rcpp::_["schur_operator_norm"] = schur_operator_norm,
    Rcpp::_["singular_blocks"] = singular_blocks,
    Rcpp::_["refinement_alpha"] = refinement_alpha,
    Rcpp::_["refinement_direction_norm"] = refinement_direction_norm,
    Rcpp::_["n_blocks"] = n_groups,
    Rcpp::_["max_block_size"] = max_block,
    Rcpp::_["min_abs_pivot"] = min_abs_pivot,
    Rcpp::_["smoothing"] = smoothing,
    Rcpp::_["sweep"] = sweep,
    Rcpp::_["method"] = method,
    Rcpp::_["singular_group_ids"] = singular_group_ids,
    Rcpp::_["factor_bytes"] = static_cast<double>(matrix_total * sizeof(double) + pivot_total * sizeof(int))
  );
}
