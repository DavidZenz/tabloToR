#include <RcppEigen.h>
#include <Eigen/IterativeLinearSolvers>
#include <cmath>
#include <algorithm>
#include <memory>
#include <vector>

// [[Rcpp::depends(RcppEigen)]]

typedef Eigen::SparseMatrix<double, Eigen::ColMajor, int> Sparse;
typedef Eigen::IncompleteLUT<double, int> SparseFactor;
typedef Eigen::SparseLU<Sparse, Eigen::COLAMDOrdering<int> > DirectFactor;
typedef Eigen::PartialPivLU<Eigen::MatrixXd> DenseFactor;

static Eigen::VectorXd apply_block_inverse(
    const Eigen::VectorXd& value,
    const std::vector<std::vector<int> >& rows,
    const std::vector<std::vector<int> >& columns,
    const std::vector<std::unique_ptr<SparseFactor> >& factors,
    const std::vector<Eigen::VectorXd>& diagonal_inverse,
    const std::vector<std::unique_ptr<DirectFactor> >& direct_factors) {
  Eigen::VectorXd result = Eigen::VectorXd::Zero(value.size());
  for (size_t id = 0; id < factors.size(); ++id) {
    if (!factors[id] && !direct_factors[id]) continue;
    const std::vector<int>& block_rows = rows[id];
    const std::vector<int>& block_columns = columns[id];
    Eigen::VectorXd local(block_rows.size());
    for (size_t k = 0; k < block_rows.size(); ++k) {
      local[static_cast<Eigen::Index>(k)] = value[block_rows[k]];
    }
    bool fallback = false;
    Eigen::VectorXd solved;
    if (direct_factors[id]) {
      fallback = direct_factors[id]->info() != Eigen::Success;
      if (!fallback) solved = direct_factors[id]->solve(local);
    } else {
      fallback = factors[id]->info() != Eigen::Success;
      if (!fallback) solved = factors[id]->solve(local);
    }
    fallback = fallback || !solved.allFinite();
    if (fallback) solved = diagonal_inverse[id].cwiseProduct(local);
    if (!solved.allFinite()) {
      Rcpp::stop("Eigen block %d preconditioner produced non-finite values",
                 static_cast<int>(id));
    }
    for (size_t k = 0; k < block_columns.size(); ++k) {
      result[block_columns[k]] = solved[static_cast<Eigen::Index>(k)];
    }
  }
  return result;
}

// [[Rcpp::export]]
Rcpp::List solve_eigen_block_gmres(
    SEXP matrix_sexp,
    Rcpp::NumericVector rhs,
    Rcpp::IntegerVector row_block,
    Rcpp::IntegerVector column_block,
    Rcpp::NumericVector row_scale,
    Rcpp::NumericVector column_scale,
    int restart = 8,
    int max_iterations = 120,
    double tolerance = 1e-7,
    int forward_sweep = 0,
    SEXP coarse_sexp = R_NilValue,
    Rcpp::IntegerVector coarse_row_group = Rcpp::IntegerVector(),
    Rcpp::IntegerVector coarse_column_group = Rcpp::IntegerVector(),
    int method = 0,
    int direct_block_max = -1,
    int split_group = 0) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  Rcpp::IntegerVector row_indices = matrix.slot("i");
  Rcpp::IntegerVector column_pointers = matrix.slot("p");
  Rcpp::NumericVector values = matrix.slot("x");
  const int n = dimensions[0];
  if (dimensions[1] != n || rhs.size() != n ||
      row_block.size() != n || column_block.size() != n ||
      row_scale.size() != n || column_scale.size() != n) {
    Rcpp::stop("Eigen block GMRES received inconsistent dimensions");
  }
  if (restart < 2 || max_iterations < 1 ||
      !R_finite(tolerance) || tolerance <= 0 ||
      (forward_sweep != 0 && forward_sweep != 1 && forward_sweep != 2) ||
      (coarse_sexp != R_NilValue &&
       (coarse_row_group.size() != n || coarse_column_group.size() != n)) ||
      (method < 0 || method > 3) ||
      direct_block_max < -1) {
    Rcpp::stop("Invalid Eigen block GMRES controls");
  }

  Sparse A(n, n);
  A.reserve(values.size());
  for (int column = 0; column < n; ++column) {
    A.startVec(column);
    for (int entry = column_pointers[column];
         entry < column_pointers[column + 1]; ++entry) {
      const int row = row_indices[entry];
      const double value = values[entry] * row_scale[row] *
        column_scale[column];
      if (value != 0.0) A.insertBack(row, column) = value;
    }
  }
  A.makeCompressed();

  int maximum_block = 0;
  for (int i = 0; i < n; ++i) {
    maximum_block = std::max(maximum_block, row_block[i]);
    maximum_block = std::max(maximum_block, column_block[i]);
  }
  std::vector<std::vector<int> > rows(maximum_block + 1);
  std::vector<std::vector<int> > columns(maximum_block + 1);
  for (int i = 0; i < n; ++i) {
    if (row_block[i] < 0 || column_block[i] < 0) {
      Rcpp::stop("Eigen block IDs must be nonnegative");
    }
    rows[row_block[i]].push_back(i);
    columns[column_block[i]].push_back(i);
  }
  for (int id = 0; id <= maximum_block; ++id) {
    if (rows[id].size() != columns[id].size()) {
      Rcpp::stop("Eigen block row and column dimensions differ");
    }
  }

  std::vector<std::unique_ptr<SparseFactor> > factors(maximum_block + 1);
  std::vector<std::unique_ptr<DirectFactor> > direct_factors(maximum_block + 1);
  std::vector<Eigen::VectorXd> diagonal_inverse(maximum_block + 1);
  std::vector<int> row_position(n, -1);
  for (int id = 0; id <= maximum_block; ++id) {
    if (rows[id].empty()) continue;
    for (size_t k = 0; k < rows[id].size(); ++k) {
      row_position[rows[id][k]] = static_cast<int>(k);
    }
    std::vector<Eigen::Triplet<double, int> > triplets;
    Eigen::VectorXd diagonal = Eigen::VectorXd::Zero(rows[id].size());
    double scale = 1.0;
    for (size_t k = 0; k < columns[id].size(); ++k) {
      const int column = columns[id][k];
      for (int entry = A.outerIndexPtr()[column];
           entry < A.outerIndexPtr()[column + 1]; ++entry) {
        const int row = A.innerIndexPtr()[entry];
        if (row_block[row] == id) {
          const double value = A.valuePtr()[entry];
          scale = std::max(scale, std::abs(value));
          const int local_row = row_position[row];
          if (local_row == static_cast<int>(k)) diagonal[static_cast<int>(k)] = value;
          triplets.push_back(Eigen::Triplet<double, int>(
            row_position[row], static_cast<int>(k), value
          ));
        }
      }
    }
    const bool external_block = split_group > 0 && id >= split_group;
    const bool local_block = split_group > 0 && id < split_group;
    const bool use_direct = local_block || id == 1 ||
      (direct_block_max >= 0 &&
       static_cast<int>(rows[id].size()) <= direct_block_max);
    const double shift = external_block ?
      (use_direct ? 1e-8 : 1e-3) * scale :
      (use_direct ? 0.0 : 1e-4 * scale);
    diagonal.array() += shift;
    diagonal_inverse[id] = diagonal.array().inverse().matrix();
    triplets.reserve(triplets.size() + rows[id].size());
    for (size_t diagonal = 0; diagonal < rows[id].size(); ++diagonal) {
      triplets.push_back(Eigen::Triplet<double, int>(
        static_cast<int>(diagonal), static_cast<int>(diagonal), shift));
    }
    Sparse block(static_cast<int>(rows[id].size()),
                 static_cast<int>(columns[id].size()));
    block.setFromTriplets(triplets.begin(), triplets.end());
    if (use_direct) {
      direct_factors[id].reset(new DirectFactor());
      direct_factors[id]->compute(block);
      if (direct_factors[id]->info() != Eigen::Success) {
        Rcpp::stop("Eigen direct block factorization failed for block %d (dimension %d)",
                   id, static_cast<int>(rows[id].size()));
      }
    } else {
      factors[id].reset(new SparseFactor());
      factors[id]->setDroptol(1e-4);
      factors[id]->setFillfactor(10);
      factors[id]->compute(block);
    }
    if (!direct_factors[id] && factors[id]->info() != Eigen::Success) {
      Rcpp::stop("Eigen regional block factorization failed for block %d (dimension %d, nnz %d)",
                 id, static_cast<int>(rows[id].size()),
                 static_cast<int>(block.nonZeros()));
    }
    for (size_t k = 0; k < rows[id].size(); ++k) {
      row_position[rows[id][k]] = -1;
    }
  }

  std::unique_ptr<SparseFactor> coarse_factor;
  std::vector<int> coarse_sizes;
  int coarse_count = 0;
  if (coarse_sexp != R_NilValue) {
    Rcpp::S4 coarse_matrix(coarse_sexp);
    Rcpp::IntegerVector coarse_dimensions = coarse_matrix.slot("Dim");
    Rcpp::IntegerVector coarse_indices = coarse_matrix.slot("i");
    Rcpp::IntegerVector coarse_pointers = coarse_matrix.slot("p");
    Rcpp::NumericVector coarse_values = coarse_matrix.slot("x");
    if (coarse_dimensions.size() != 2 ||
        coarse_dimensions[0] != coarse_dimensions[1] ||
        coarse_row_group.size() != n ||
        coarse_column_group.size() != n) {
      Rcpp::stop("Invalid coarse system dimensions");
    }
    coarse_count = coarse_dimensions[0];
    coarse_sizes.assign(coarse_count, 0);
    for (int i = 0; i < n; ++i) {
      const int row_group = coarse_row_group[i];
      const int column_group = coarse_column_group[i];
      if (row_group < 0 || row_group >= coarse_count ||
          column_group < 0 || column_group >= coarse_count) {
        Rcpp::stop("Coarse group IDs are outside the coarse system");
      }
      ++coarse_sizes[row_group];
    }
    for (int group = 0; group < coarse_count; ++group) {
      if (coarse_sizes[group] == 0) {
        Rcpp::stop("Coarse system contains an empty row group");
      }
    }
    Sparse coarse(coarse_count, coarse_count);
    coarse.reserve(coarse_values.size());
    for (int column = 0; column < coarse_count; ++column) {
      coarse.startVec(column);
      for (int entry = coarse_pointers[column];
           entry < coarse_pointers[column + 1]; ++entry) {
        const int row = coarse_indices[entry];
        const double value = coarse_values[entry];
        if (value != 0.0) coarse.insertBack(row, column) = value;
      }
    }
    coarse.makeCompressed();
    double coarse_scale = 1.0;
    for (int entry = 0; entry < coarse.nonZeros(); ++entry) {
      coarse_scale = std::max(coarse_scale,
                              std::abs(coarse.valuePtr()[entry]));
    }
    const double coarse_shift = 1e-8 * coarse_scale;
    for (int diagonal = 0; diagonal < coarse.rows(); ++diagonal) {
      coarse.coeffRef(diagonal, diagonal) += coarse_shift;
    }
    coarse.makeCompressed();
    coarse_factor.reset(new SparseFactor());
    coarse_factor->compute(coarse);
    if (coarse_factor->info() != Eigen::Success) {
      double scale = 1.0;
      for (int entry = 0; entry < coarse.nonZeros(); ++entry) {
        scale = std::max(scale, std::abs(coarse.valuePtr()[entry]));
      }
      const double shift = 1e-8 * scale;
      for (int diagonal = 0; diagonal < coarse.rows(); ++diagonal) {
        coarse.coeffRef(diagonal, diagonal) += shift;
      }
      coarse.makeCompressed();
      coarse_factor->compute(coarse);
    }
    if (coarse_factor->info() != Eigen::Success) {
      Rcpp::stop("Eigen coarse factorization failed");
    }
  }

  Eigen::VectorXd scaled_rhs(n);
  for (int i = 0; i < n; ++i) scaled_rhs[i] = row_scale[i] * rhs[i];
  Eigen::VectorXd solution_z = Eigen::VectorXd::Zero(n);
  int iterations = 0;
  bool converged = false;
  double estimated_residual = R_PosInf;

  auto apply_B = [&](const Eigen::VectorXd& value) {
    // A already stores D_r A_original D_c.  The Krylov variable is z
    // where x = D_c z, so applying the scaled operator must not apply the
    // diagonal scalings a second time.
    return Eigen::VectorXd(A * value);
  };
  auto apply_fine = [&](const Eigen::VectorXd& value) {
    if (!forward_sweep) {
      return apply_block_inverse(value, rows, columns, factors, diagonal_inverse, direct_factors);
    }
    Eigen::VectorXd work = value;
    Eigen::VectorXd result = Eigen::VectorXd::Zero(n);
    for (int id = 0; id <= maximum_block; ++id) {
      const std::vector<int>& block_rows = rows[id];
      const std::vector<int>& block_columns = columns[id];
      Eigen::VectorXd local(block_rows.size());
      for (size_t k = 0; k < block_rows.size(); ++k) {
        local[static_cast<Eigen::Index>(k)] = work[block_rows[k]];
      }
      Eigen::VectorXd solved;
      bool fallback = false;
      if (direct_factors[id]) {
        fallback = direct_factors[id]->info() != Eigen::Success;
        if (!fallback) solved = direct_factors[id]->solve(local);
      } else if (factors[id]) {
        fallback = factors[id]->info() != Eigen::Success;
        if (!fallback) solved = factors[id]->solve(local);
      } else {
        fallback = true;
      }
      fallback = fallback || !solved.allFinite();
      if (fallback) solved = diagonal_inverse[id].cwiseProduct(local);
      if (!solved.allFinite()) {
        Rcpp::stop("Eigen forward block solve failed");
      }
      for (size_t k = 0; k < block_columns.size(); ++k) {
        const int column = block_columns[k];
        const double value = solved[static_cast<Eigen::Index>(k)];
        result[column] = value;
        for (int entry = A.outerIndexPtr()[column];
             entry < A.outerIndexPtr()[column + 1]; ++entry) {
          const int row = A.innerIndexPtr()[entry];
          if (row_block[row] > id) {
            work[row] -= A.valuePtr()[entry] * value;
          }
        }
      }
    }
    return result;
  };
  auto apply_Q = [&](const Eigen::VectorXd& value) {
    if (!coarse_factor) {
      return apply_fine(value);
    }
    Eigen::VectorXd fine = apply_fine(value);
    Eigen::VectorXd residual = value - apply_B(fine);
    Eigen::VectorXd coarse_rhs = Eigen::VectorXd::Zero(coarse_count);
    for (int i = 0; i < n; ++i) {
      const int group = coarse_row_group[i];
      coarse_rhs[group] += residual[i] / coarse_sizes[group];
    }
    Eigen::VectorXd coarse_solution = coarse_factor->solve(coarse_rhs);
    if (coarse_factor->info() != Eigen::Success) {
      Rcpp::stop("Eigen coarse solve failed");
    }
    Eigen::VectorXd result = fine;
    for (int i = 0; i < n; ++i) {
      result[i] += coarse_solution[coarse_column_group[i]];
    }
    return result;
  };
  auto apply_operator = [&](const Eigen::VectorXd& value) {
    if (method == 2) return apply_Q(apply_B(value));
    return apply_B(apply_Q(value));
  };
  Eigen::VectorXd effective_rhs = method == 2 ?
    apply_Q(scaled_rhs) : scaled_rhs;
  const double rhs_norm = effective_rhs.norm();

  if (method == 3) {
    if (split_group <= 0 || split_group > maximum_block) {
      Rcpp::stop("Schur mode requires a nonempty local block range");
    }
    std::vector<std::unique_ptr<DenseFactor> > schur_block_factors(
      maximum_block + 1
    );
    auto solve_range = [&](const Eigen::VectorXd& input,
                           int first_group, int last_group) {
      Eigen::VectorXd result = Eigen::VectorXd::Zero(n);
      for (int id = first_group; id <= last_group; ++id) {
        const std::vector<int>& block_rows = rows[id];
        const std::vector<int>& block_columns = columns[id];
        Eigen::VectorXd local(block_rows.size());
        for (size_t k = 0; k < block_rows.size(); ++k) {
          local[static_cast<Eigen::Index>(k)] = input[block_rows[k]];
        }
        Eigen::VectorXd solved;
        if (schur_block_factors[id]) {
          solved = schur_block_factors[id]->solve(local);
        } else if (direct_factors[id]) {
          solved = direct_factors[id]->solve(local);
        } else if (factors[id]) {
          solved = factors[id]->solve(local);
        } else {
          solved = diagonal_inverse[id].cwiseProduct(local);
        }
        if (!solved.allFinite()) {
          Rcpp::stop("Eigen Schur block solve produced non-finite values");
        }
        for (size_t k = 0; k < block_columns.size(); ++k) {
          result[block_columns[k]] = solved[static_cast<Eigen::Index>(k)];
        }
      }
      return result;
    };
    auto external_norm = [&](const Eigen::VectorXd& value) {
      double sum = 0.0;
      for (int id = split_group; id <= maximum_block; ++id) {
        for (size_t k = 0; k < rows[id].size(); ++k) {
          const double entry = value[rows[id][k]];
          sum += entry * entry;
        }
      }
      return std::sqrt(sum);
    };
    auto external_dot = [&](const Eigen::VectorXd& left,
                            const Eigen::VectorXd& right) {
      double sum = 0.0;
      for (int id = split_group; id <= maximum_block; ++id) {
        for (size_t k = 0; k < rows[id].size(); ++k) {
          sum += left[rows[id][k]] * right[rows[id][k]];
        }
      }
      return sum;
    };
    auto apply_schur = [&](const Eigen::VectorXd& input) {
      Eigen::VectorXd full_product = apply_B(input);
      Eigen::VectorXd local_solution = solve_range(
        full_product, 0, split_group - 1
      );
      Eigen::VectorXd local_product = apply_B(local_solution);
      Eigen::VectorXd result = Eigen::VectorXd::Zero(n);
      for (int id = split_group; id <= maximum_block; ++id) {
        for (size_t k = 0; k < rows[id].size(); ++k) {
          const int row = rows[id][k];
          result[row] = full_product[row] - local_product[row];
        }
      }
      return result;
    };
    std::vector<int> local_position(n, -1);
    std::vector<int> external_position(n, -1);
    for (int id = split_group; id <= maximum_block; ++id) {
      const std::vector<int>& block_rows = rows[id];
      const std::vector<int>& block_columns = columns[id];
      const int block_size = static_cast<int>(block_rows.size());
      Eigen::MatrixXd block = Eigen::MatrixXd::Zero(
        block_size, block_size
      );
      for (int k = 0; k < block_size; ++k) {
        external_position[block_rows[k]] = k;
      }
      for (int column_position = 0;
          column_position < block_size; ++column_position) {
        const int column = block_columns[column_position];
        for (int entry = A.outerIndexPtr()[column];
           entry < A.outerIndexPtr()[column + 1]; ++entry) {
          const int row = A.innerIndexPtr()[entry];
          if (row_block[row] == id) {
            block(external_position[row], column_position) +=
              A.valuePtr()[entry];
          }
        }
      }
      for (int local_id = 0; local_id < split_group; ++local_id) {
        const std::vector<int>& local_rows = rows[local_id];
        const std::vector<int>& local_columns = columns[local_id];
        const int local_size = static_cast<int>(local_rows.size());
        for (int k = 0; k < local_size; ++k) {
          local_position[local_rows[k]] = k;
        }
        Eigen::MatrixXd local_rhs = Eigen::MatrixXd::Zero(
          local_size, block_size
        );
        for (int column_position = 0;
            column_position < block_size; ++column_position) {
          const int column = block_columns[column_position];
          for (int entry = A.outerIndexPtr()[column];
             entry < A.outerIndexPtr()[column + 1]; ++entry) {
            const int row = A.innerIndexPtr()[entry];
            if (row_block[row] == local_id) {
              local_rhs(local_position[row], column_position) =
                A.valuePtr()[entry];
            }
          }
        }
        Eigen::MatrixXd local_solution;
        if (direct_factors[local_id]) {
          local_solution = direct_factors[local_id]->solve(local_rhs);
        } else if (factors[local_id]) {
          local_solution = factors[local_id]->solve(local_rhs);
        } else {
          local_solution = local_rhs;
          for (int k = 0; k < local_size; ++k) {
            local_solution.row(k) *= diagonal_inverse[local_id][k];
          }
        }
        if (!local_solution.allFinite()) {
          Rcpp::stop("Schur diagonal local solve produced non-finite values");
        }
        for (int local_column_position = 0;
            local_column_position < local_size; ++local_column_position) {
          const int column = local_columns[local_column_position];
          for (int entry = A.outerIndexPtr()[column];
             entry < A.outerIndexPtr()[column + 1]; ++entry) {
            const int row = A.innerIndexPtr()[entry];
            if (row_block[row] == id) {
              const int external_row = external_position[row];
              for (int column_position = 0;
                  column_position < block_size; ++column_position) {
                block(external_row, column_position) -=
                  A.valuePtr()[entry] *
                    local_solution(local_column_position, column_position);
              }
            }
          }
        }
        for (int k = 0; k < local_size; ++k) {
          local_position[local_rows[k]] = -1;
        }
      }
      double block_scale = 1.0;
      for (int row = 0; row < block_size; ++row) {
        for (int column = 0; column < block_size; ++column) {
          block_scale = std::max(block_scale, std::abs(block(row, column)));
        }
      }
      double block_shift = 1e-6 * block_scale;
      block.diagonal().array() += block_shift;
      std::unique_ptr<DenseFactor> factor(new DenseFactor());
      factor->compute(block);
      if (!R_finite(factor->rcond()) || factor->rcond() < 1e-12) {
        block_shift = 1e-4 * block_scale;
        block.diagonal().array() += 1e-4 * block_scale;
        factor->compute(block);
      }
      if (!R_finite(factor->rcond()) || factor->rcond() < 1e-12) {
        Rcpp::stop("Schur diagonal block factorization failed for block %d", id);
      }
      schur_block_factors[id] = std::move(factor);
      for (int k = 0; k < block_size; ++k) {
        external_position[block_rows[k]] = -1;
      }
      if ((id - split_group + 1) % 16 == 0 || id == maximum_block) {
        Rcpp::Rcout << "built Schur diagonal block "
                        << id - split_group + 1 << "/"
                        << maximum_block - split_group + 1 << std::endl;
      }
    }
    // Build an exact Galerkin operator on the 164 aggregate external
    // groups without materializing the full Schur complement.  P maps an
    // aggregate value to a constant vector on its external block and R
    // averages the resulting equations over the corresponding row block.
    const int external_count = maximum_block - split_group + 1;
    Eigen::MatrixXd coarse_schur = Eigen::MatrixXd::Zero(
      external_count, external_count
    );
    for (int coarse_column = 0;
         coarse_column < external_count; ++coarse_column) {
      Eigen::VectorXd basis = Eigen::VectorXd::Zero(n);
      const std::vector<int>& block_columns = columns[
        split_group + coarse_column
      ];
      for (size_t k = 0; k < block_columns.size(); ++k) {
        basis[block_columns[k]] = 1.0;
      }
      Eigen::VectorXd product = apply_schur(basis);
      for (int coarse_row = 0; coarse_row < external_count; ++coarse_row) {
        const std::vector<int>& block_rows = rows[split_group + coarse_row];
        double sum = 0.0;
        for (size_t k = 0; k < block_rows.size(); ++k) {
          sum += product[block_rows[k]];
        }
        coarse_schur(coarse_row, coarse_column) =
          sum / static_cast<double>(block_rows.size());
      }
      if ((coarse_column + 1) % 16 == 0 ||
          coarse_column + 1 == external_count) {
        Rcpp::Rcout << "built Schur coarse column " << coarse_column + 1
                    << "/" << external_count << std::endl;
      }
    }
    double coarse_scale = coarse_schur.cwiseAbs().maxCoeff();
    if (!R_finite(coarse_scale) || coarse_scale <= 0.0) {
      Rcpp::stop("Invalid matrix-free Schur coarse operator");
    }
    Eigen::FullPivLU<Eigen::MatrixXd> coarse_factor;
    coarse_factor.compute(coarse_schur);
    if (!coarse_factor.isInvertible()) {
      const double coarse_shift = 1e-10 * std::max(1.0, coarse_scale);
      coarse_schur.diagonal().array() += coarse_shift;
      coarse_factor.compute(coarse_schur);
    }
    if (!coarse_factor.isInvertible()) {
      Rcpp::stop("Matrix-free Schur coarse factorization failed");
    }
    int preconditioner_calls = 0;
    auto apply_external_preconditioner = [&](const Eigen::VectorXd& input) {
      Eigen::VectorXd result = solve_range(
        input, split_group, maximum_block
      );
      Eigen::VectorXd fine_product = apply_schur(result);
      Eigen::VectorXd coarse_rhs = Eigen::VectorXd::Zero(external_count);
      for (int coarse_row = 0; coarse_row < external_count; ++coarse_row) {
        const std::vector<int>& block_rows = rows[split_group + coarse_row];
        double sum = 0.0;
        for (size_t k = 0; k < block_rows.size(); ++k) {
          sum += input[block_rows[k]] - fine_product[block_rows[k]];
        }
        coarse_rhs[coarse_row] =
          sum / static_cast<double>(block_rows.size());
      }
      Eigen::VectorXd coarse_solution = coarse_factor.solve(coarse_rhs);
      if (!coarse_solution.allFinite()) {
        Rcpp::stop("Matrix-free Schur coarse solve produced non-finite values");
      }
      if (preconditioner_calls++ == 0) {
        Rcpp::Rcout << "coarse rcond " << coarse_factor.rcond()
                    << " rhs " << coarse_rhs.norm()
                    << " correction " << coarse_solution.norm()
                    << " fine " << result.norm()
                    << std::endl;
      }
      for (int coarse_column = 0;
           coarse_column < external_count; ++coarse_column) {
        const std::vector<int>& block_columns = columns[
          split_group + coarse_column
        ];
        for (size_t k = 0; k < block_columns.size(); ++k) {
          result[block_columns[k]] += coarse_solution[coarse_column];
        }
      }
      return result;
    };
    Eigen::VectorXd local_solution = solve_range(
      scaled_rhs, 0, split_group - 1
    );
    Eigen::VectorXd local_product = apply_B(local_solution);
    Eigen::VectorXd schur_rhs = Eigen::VectorXd::Zero(n);
    for (int id = split_group; id <= maximum_block; ++id) {
      for (size_t k = 0; k < rows[id].size(); ++k) {
        const int row = rows[id][k];
        schur_rhs[row] = scaled_rhs[row] - local_product[row];
      }
    }
    const double schur_rhs_norm = external_norm(schur_rhs);
    const double target = tolerance * std::max(1.0, schur_rhs_norm);
    Eigen::VectorXd schur_solution = Eigen::VectorXd::Zero(n);
    while (iterations < max_iterations && !converged) {
      Eigen::VectorXd residual = schur_rhs - apply_schur(schur_solution);
      const double beta = external_norm(residual);
      estimated_residual = beta;
      if (!R_finite(beta)) break;
      if (beta <= target) {
        converged = true;
        break;
      }
      std::vector<Eigen::VectorXd> basis;
      std::vector<Eigen::VectorXd> preconditioned_basis;
      basis.reserve(restart + 1);
      preconditioned_basis.reserve(restart);
      basis.push_back(residual / beta);
      std::vector<std::vector<double> > hessenberg(
        restart + 1, std::vector<double>(restart, 0.0)
      );
      std::vector<double> rotations_c(restart, 1.0);
      std::vector<double> rotations_s(restart, 0.0);
      std::vector<double> target_vector(restart + 1, 0.0);
      target_vector[0] = beta;
      int inner = 0;
      while (inner < restart && iterations < max_iterations) {
        ++inner;
        ++iterations;
        Eigen::VectorXd direction = apply_external_preconditioner(
          basis[inner - 1]
        );
        preconditioned_basis.push_back(direction);
        Eigen::VectorXd value = apply_schur(direction);
        for (int id = 0; id < inner; ++id) {
          const double coefficient = external_dot(basis[id], value);
          hessenberg[id][inner - 1] = coefficient;
          value -= coefficient * basis[id];
        }
        const double next_norm = external_norm(value);
        hessenberg[inner][inner - 1] = next_norm;
        if (next_norm > 0.0 && R_finite(next_norm)) {
          basis.push_back(value / next_norm);
        }
        for (int id = 0; id < inner - 1; ++id) {
          const double upper = hessenberg[id][inner - 1];
          const double lower = hessenberg[id + 1][inner - 1];
          hessenberg[id][inner - 1] = rotations_c[id] * upper +
            rotations_s[id] * lower;
          hessenberg[id + 1][inner - 1] = -rotations_s[id] * upper +
            rotations_c[id] * lower;
        }
        const double diagonal = hessenberg[inner - 1][inner - 1];
        const double subdiagonal = hessenberg[inner][inner - 1];
        const double rotation_norm = std::hypot(diagonal, subdiagonal);
        if (rotation_norm > 0.0 && R_finite(rotation_norm)) {
          rotations_c[inner - 1] = diagonal / rotation_norm;
          rotations_s[inner - 1] = subdiagonal / rotation_norm;
          hessenberg[inner - 1][inner - 1] = rotation_norm;
          hessenberg[inner][inner - 1] = 0.0;
          const double upper = target_vector[inner - 1];
          const double lower = target_vector[inner];
          target_vector[inner - 1] = rotations_c[inner - 1] * upper +
            rotations_s[inner - 1] * lower;
          target_vector[inner] = -rotations_s[inner - 1] * upper +
            rotations_c[inner - 1] * lower;
        }
        estimated_residual = std::abs(target_vector[inner]);
        if (estimated_residual <= target || next_norm == 0.0 ||
            !R_finite(next_norm)) break;
      }
      if (!inner) break;
      std::vector<double> coefficients(inner, 0.0);
      for (int id = inner - 1; id >= 0; --id) {
        double value = target_vector[id];
        for (int next = id + 1; next < inner; ++next) {
          value -= hessenberg[id][next] * coefficients[next];
        }
        if (std::abs(hessenberg[id][id]) > 0.0) {
          coefficients[id] = value / hessenberg[id][id];
        }
      }
      for (int id = 0; id < inner; ++id) {
        schur_solution += coefficients[id] * preconditioned_basis[id];
      }
    }
    local_product = apply_B(schur_solution);
    Eigen::VectorXd remaining = scaled_rhs - local_product;
    local_solution = solve_range(remaining, 0, split_group - 1);
    solution_z = schur_solution + local_solution;
  } else if (method == 0) {
  while (iterations < max_iterations && !converged) {
    Eigen::VectorXd residual = effective_rhs - apply_operator(solution_z);
    const double beta = residual.norm();
    if (beta <= tolerance * std::max(1.0, rhs_norm)) {
      converged = true;
      estimated_residual = beta;
      break;
    }
    std::vector<Eigen::VectorXd> basis;
    basis.reserve(restart + 1);
    basis.push_back(residual / beta);
    std::vector<std::vector<double> > hessenberg(
      restart + 1, std::vector<double>(restart, 0.0)
    );
    std::vector<double> rotations_c(restart, 1.0);
    std::vector<double> rotations_s(restart, 0.0);
    std::vector<double> target(restart + 1, 0.0);
    target[0] = beta;
    int inner = 0;
    std::vector<double> coefficients;
    while (inner < restart && iterations < max_iterations) {
      ++inner;
      ++iterations;
      Eigen::VectorXd value = apply_operator(basis[inner - 1]);
      for (int i = 0; i < inner; ++i) {
        const Eigen::VectorXd &basis_value = basis[i];
        hessenberg[i][inner - 1] = basis_value.dot(value);
        value -= hessenberg[i][inner - 1] * basis_value;
      }
      const double next_norm = value.norm();
      hessenberg[inner][inner - 1] = next_norm;
      if (next_norm > 0 && R_finite(next_norm)) {
        basis.push_back(value / next_norm);
      }
      for (int i = 0; i < inner - 1; ++i) {
        const double upper = hessenberg[i][inner - 1];
        const double lower = hessenberg[i + 1][inner - 1];
        hessenberg[i][inner - 1] = rotations_c[i] * upper +
          rotations_s[i] * lower;
        hessenberg[i + 1][inner - 1] = -rotations_s[i] * upper +
          rotations_c[i] * lower;
      }
      const double diagonal = hessenberg[inner - 1][inner - 1];
      const double subdiagonal = hessenberg[inner][inner - 1];
      const double rotation_norm = std::hypot(diagonal, subdiagonal);
      if (rotation_norm > 0 && R_finite(rotation_norm)) {
        rotations_c[inner - 1] = diagonal / rotation_norm;
        rotations_s[inner - 1] = subdiagonal / rotation_norm;
        hessenberg[inner - 1][inner - 1] = rotation_norm;
        hessenberg[inner][inner - 1] = 0.0;
        const double target_upper = target[inner - 1];
        const double target_lower = target[inner];
        target[inner - 1] = rotations_c[inner - 1] * target_upper +
          rotations_s[inner - 1] * target_lower;
        target[inner] = -rotations_s[inner - 1] * target_upper +
          rotations_c[inner - 1] * target_lower;
      }
      estimated_residual = std::abs(target[inner]);
      if (estimated_residual <= tolerance * std::max(1.0, rhs_norm) ||
          next_norm == 0 || !R_finite(next_norm)) break;
    }
    coefficients.assign(inner, 0.0);
    for (int i = inner - 1; i >= 0; --i) {
      double value = target[i];
      for (int j = i + 1; j < inner; ++j) {
        value -= hessenberg[i][j] * coefficients[j];
      }
      if (std::abs(hessenberg[i][i]) > 0) {
        coefficients[i] = value / hessenberg[i][i];
      }
    }
    for (int i = 0; i < inner; ++i) {
      solution_z += coefficients[i] * basis[i];
    }
  }

  } else {
    Eigen::VectorXd residual = effective_rhs;
    Eigen::VectorXd shadow = residual;
    Eigen::VectorXd search = Eigen::VectorXd::Zero(n);
    Eigen::VectorXd product = Eigen::VectorXd::Zero(n);
    double rho_old = 1.0;
    double alpha = 1.0;
    double omega = 1.0;
    while (iterations < max_iterations && !converged) {
      const double rho = shadow.dot(residual);
      if (!R_finite(rho) || std::abs(rho) < 1e-30) break;
      if (iterations == 0) {
        search = residual;
      } else {
        const double beta = (rho / rho_old) * (alpha / omega);
        search = residual + beta * (search - omega * product);
      }
      product = apply_operator(search);
      const double denominator = shadow.dot(product);
      if (!R_finite(denominator) || std::abs(denominator) < 1e-30) break;
      alpha = rho / denominator;
      Eigen::VectorXd intermediate = residual - alpha * product;
      const double intermediate_norm = intermediate.norm();
      if (intermediate_norm <= tolerance * std::max(1.0, rhs_norm)) {
        solution_z += alpha * search;
        estimated_residual = intermediate_norm;
        ++iterations;
        converged = true;
        break;
      }
      Eigen::VectorXd correction = apply_operator(intermediate);
      const double correction_norm = correction.squaredNorm();
      if (!R_finite(correction_norm) || correction_norm < 1e-30) break;
      omega = correction.dot(intermediate) / correction_norm;
      if (!R_finite(omega) || std::abs(omega) < 1e-30) break;
      solution_z += alpha * search + omega * intermediate;
      residual = intermediate - omega * correction;
      estimated_residual = residual.norm();
      rho_old = rho;
      ++iterations;
      if (estimated_residual <= tolerance * std::max(1.0, rhs_norm)) {
        converged = true;
      }
    }
  }

  Eigen::VectorXd scaled_solution = (method == 2 || method == 3) ? solution_z :
    apply_Q(solution_z);
  Eigen::VectorXd solution(n);
  for (int i = 0; i < n; ++i) solution[i] = column_scale[i] * scaled_solution[i];
  Eigen::VectorXd scaled_residual = apply_B(scaled_solution) - scaled_rhs;
  Eigen::VectorXd true_residual_vector(n);
  for (int i = 0; i < n; ++i) {
    true_residual_vector[i] = scaled_residual[i] / row_scale[i];
  }
  const double true_residual = true_residual_vector.norm();
  Rcpp::NumericVector result(n);
  std::copy(solution.data(), solution.data() + n, result.begin());
  return Rcpp::List::create(
    Rcpp::_["solution"] = result,
    Rcpp::_["converged"] = converged,
    Rcpp::_["iterations"] = iterations,
    Rcpp::_["estimated_residual"] = estimated_residual,
    Rcpp::_["true_residual"] = true_residual,
    Rcpp::_["blocks"] = maximum_block + 1,
    Rcpp::_["nnz"] = A.nonZeros()
  );
}

// [[Rcpp::export]]
Rcpp::List solve_eigen_ilut(
    SEXP matrix_sexp,
    Rcpp::NumericVector rhs,
    Rcpp::NumericVector row_scale,
    Rcpp::NumericVector column_scale,
    int max_iterations = 1000,
    double tolerance = 1e-8,
    double droptol = 1e-3,
    int fillfactor = 10) {
  Rcpp::S4 matrix(matrix_sexp);
  Rcpp::IntegerVector dimensions = matrix.slot("Dim");
  Rcpp::IntegerVector row_indices = matrix.slot("i");
  Rcpp::IntegerVector column_pointers = matrix.slot("p");
  Rcpp::NumericVector values = matrix.slot("x");
  const int n = dimensions[0];
  if (dimensions[1] != n || rhs.size() != n ||
      row_scale.size() != n || column_scale.size() != n ||
      max_iterations < 1 || tolerance <= 0 || droptol < 0 ||
      fillfactor < 1) {
    Rcpp::stop("Invalid Eigen ILUT dimensions or controls");
  }
  Sparse A(n, n);
  A.reserve(values.size());
  for (int column = 0; column < n; ++column) {
    A.startVec(column);
    for (int entry = column_pointers[column];
         entry < column_pointers[column + 1]; ++entry) {
      const int row = row_indices[entry];
      const double value = values[entry] * row_scale[row] *
        column_scale[column];
      if (value != 0.0) A.insertBack(row, column) = value;
    }
  }
  A.makeCompressed();
  Eigen::BiCGSTAB<Sparse, SparseFactor> solver;
  solver.preconditioner().setDroptol(droptol);
  solver.preconditioner().setFillfactor(fillfactor);
  solver.setMaxIterations(max_iterations);
  solver.setTolerance(tolerance);
  solver.compute(A);
  if (solver.info() != Eigen::Success) {
    Rcpp::stop("Eigen ILUT factorization failed");
  }
  Eigen::VectorXd scaled_rhs(n);
  for (int i = 0; i < n; ++i) scaled_rhs[i] = row_scale[i] * rhs[i];
  Eigen::VectorXd scaled_solution = solver.solve(scaled_rhs);
  if (!scaled_solution.allFinite()) {
    Rcpp::stop("Eigen ILUT solve produced non-finite values");
  }
  Eigen::VectorXd scaled_residual = A * scaled_solution - scaled_rhs;
  Eigen::VectorXd true_residual(n);
  for (int i = 0; i < n; ++i) {
    true_residual[i] = scaled_residual[i] / row_scale[i];
  }
  Rcpp::NumericVector result(n);
  for (int i = 0; i < n; ++i) {
    result[i] = column_scale[i] * scaled_solution[i];
  }
  return Rcpp::List::create(
    Rcpp::_["solution"] = result,
    Rcpp::_["converged"] =
      solver.error() <= tolerance,
    Rcpp::_["iterations"] = solver.iterations(),
    Rcpp::_["estimated_residual"] = solver.error(),
    Rcpp::_["true_residual"] = true_residual.norm(),
    Rcpp::_["nnz"] = A.nonZeros()
  );
}
