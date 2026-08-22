#include <Rcpp.h>

#include <algorithm>
#include <chrono>
#include <cstddef>
#include <vector>

#ifdef _OPENMP
#include <omp.h>
#endif

#include "tablo-sparse-lu.h"

struct TabloParallelCounter {
  long long inspected;
  long long skipped;
  long long solved;
  long long columns;
  double extract;
  double triangular;
  double multiply;
  std::size_t peak;
  bool valid;

  TabloParallelCounter()
    : inspected(0), skipped(0), solved(0), columns(0), extract(0),
      triangular(0), multiply(0), peak(0), valid(true) {}
};

static double tablo_parallel_elapsed(
    const std::chrono::steady_clock::time_point &start) {
  return std::chrono::duration<double>(
    std::chrono::steady_clock::now() - start
  ).count();
}

static std::vector<int> tablo_parallel_positions(SEXP value_sexp, int upper,
                                                 const char *name) {
  Rcpp::IntegerVector value(value_sexp);
  std::vector<int> result(value.size());
  std::vector<unsigned char> seen(upper, 0);
  for (R_xlen_t id = 0; id < value.size(); ++id) {
    int position = value[id] - 1;
    if (position < 0 || position >= upper || seen[position]) {
      Rcpp::stop("%s contains invalid or duplicate positions", name);
    }
    seen[position] = 1;
    result[id] = position;
  }
  return result;
}

static std::vector<double> tablo_parallel_slice(
    const TabloCscView &matrix, const std::vector<int> &rows,
    const std::vector<int> &columns) {
  tablo_checked_product(rows.size(), columns.size(), "parallel Schur output");
  std::vector<double> result(rows.size() * columns.size(), 0.0);
  std::vector<int> row_map(matrix.nrow, -1);
  for (std::size_t row = 0; row < rows.size(); ++row) {
    row_map[rows[row]] = static_cast<int>(row);
  }
  for (std::size_t column = 0; column < columns.size(); ++column) {
    int source = columns[column];
    for (int position = matrix.p[source];
         position < matrix.p[source + 1]; ++position) {
      int target = row_map[matrix.i[position]];
      if (target >= 0) {
        result[target + rows.size() * column] = matrix.x[position];
      }
    }
  }
  return result;
}

static bool tablo_parallel_fill(const TabloCscView &right,
                                const std::vector<int> &columns,
                                std::size_t first, int width,
                                std::vector<double> *buffer) {
  std::size_t used = static_cast<std::size_t>(right.nrow) * width;
  if (buffer->size() < used) buffer->resize(used);
  std::fill(buffer->begin(), buffer->begin() + used, 0.0);
  bool nonzero = false;
  for (int target = 0; target < width; ++target) {
    int column = columns[first + target];
    for (int position = right.p[column];
         position < right.p[column + 1]; ++position) {
      double value = right.x[position];
      (*buffer)[right.i[position] +
                static_cast<std::size_t>(right.nrow) * target] = value;
      nonzero = nonzero || value != 0.0;
    }
  }
  return nonzero;
}

static bool tablo_parallel_solve(const TabloSparseLUView &factor,
                                 double *values, int nrhs,
                                 std::vector<double> *workspace) {
  const int n = factor.n;
  workspace->resize(static_cast<std::size_t>(n) * nrhs);
  for (int rhs = 0; rhs < nrhs; ++rhs) {
    for (int row = 0; row < n; ++row) {
      (*workspace)[row + static_cast<std::size_t>(n) * rhs] =
        values[factor.p[row] + static_cast<std::size_t>(n) * rhs];
    }
  }
  for (int column = 0; column < n; ++column) {
    for (int rhs = 0; rhs < nrhs; ++rhs) {
      (*workspace)[column + static_cast<std::size_t>(n) * rhs] /=
        factor.diagonal_l[column];
    }
    for (int position = factor.L.p[column];
         position < factor.L.p[column + 1]; ++position) {
      int row = factor.L.i[position];
      if (row <= column) continue;
      for (int rhs = 0; rhs < nrhs; ++rhs) {
        (*workspace)[row + static_cast<std::size_t>(n) * rhs] -=
          factor.L.x[position] *
          (*workspace)[column + static_cast<std::size_t>(n) * rhs];
      }
    }
  }
  for (int column = n - 1; column >= 0; --column) {
    for (int rhs = 0; rhs < nrhs; ++rhs) {
      (*workspace)[column + static_cast<std::size_t>(n) * rhs] /=
        factor.diagonal_u[column];
    }
    for (int position = factor.U.p[column];
         position < factor.U.p[column + 1]; ++position) {
      int row = factor.U.i[position];
      if (row >= column) continue;
      for (int rhs = 0; rhs < nrhs; ++rhs) {
        (*workspace)[row + static_cast<std::size_t>(n) * rhs] -=
          factor.U.x[position] *
          (*workspace)[column + static_cast<std::size_t>(n) * rhs];
      }
    }
  }
  for (int rhs = 0; rhs < nrhs; ++rhs) {
    for (int row = 0; row < n; ++row) {
      double value = (*workspace)[row + static_cast<std::size_t>(n) * rhs];
      if (!std::isfinite(value)) return false;
      values[factor.q[row] + static_cast<std::size_t>(n) * rhs] = value;
    }
  }
  return true;
}

// [[Rcpp::export(name = ".tabloToR_schur_accumulate_batch_parallel")]]
Rcpp::List tabloToR_schur_accumulate_batch_parallel(
    Rcpp::List factors, Rcpp::List left_blocks, Rcpp::List right_blocks,
    SEXP direct_external_sexp, Rcpp::List regional_positions_sexp,
    Rcpp::IntegerVector global_positions_sexp,
    Rcpp::IntegerVector batch_regions_sexp, int panel_size, int threads) {
#ifndef _OPENMP
  Rcpp::stop("Parallel Schur accumulation is unavailable in this build");
#endif
  if (panel_size < 1 || threads < 2) {
    Rcpp::stop("Parallel Schur accumulation requires positive panels and at least two threads");
  }
  TabloCscView direct = tablo_csc_view(
    direct_external_sexp, "direct external block"
  );
  if (direct.nrow != direct.ncol) {
    Rcpp::stop("Direct external block must be square");
  }
  if (factors.size() < 1 || factors.size() != left_blocks.size() ||
      factors.size() != right_blocks.size()) {
    Rcpp::stop("Schur factor and coupling lists must match");
  }
  std::vector<TabloSparseLUView> factor_views;
  std::vector<TabloCscView> left_views;
  std::vector<TabloCscView> right_views;
  factor_views.reserve(factors.size());
  left_views.reserve(factors.size());
  right_views.reserve(factors.size());
  for (R_xlen_t id = 0; id < factors.size(); ++id) {
    factor_views.push_back(tablo_sparse_lu_view(factors[id], "factor"));
    int local = factor_views[id].n;
    left_views.push_back(tablo_csc_view(
      left_blocks[id], "left block", direct.nrow, local
    ));
    right_views.push_back(tablo_csc_view(
      right_blocks[id], "right block", local, direct.nrow
    ));
  }
  std::vector<std::vector<int> > regions(regional_positions_sexp.size());
  std::vector<int> row_group(direct.nrow, -2);
  std::vector<int> row_local(direct.nrow, -1);
  for (R_xlen_t region = 0; region < regional_positions_sexp.size(); ++region) {
    regions[region] = tablo_parallel_positions(
      regional_positions_sexp[region], direct.nrow, "regional positions"
    );
    for (std::size_t local = 0; local < regions[region].size(); ++local) {
      int row = regions[region][local];
      if (row_group[row] != -2) Rcpp::stop("Regional positions overlap");
      row_group[row] = static_cast<int>(region);
      row_local[row] = static_cast<int>(local);
    }
  }
  std::vector<int> global = tablo_parallel_positions(
    global_positions_sexp, direct.nrow, "global positions"
  );
  for (std::size_t local = 0; local < global.size(); ++local) {
    int row = global[local];
    if (row_group[row] != -2) Rcpp::stop("Global positions overlap regions");
    row_group[row] = -1;
    row_local[row] = static_cast<int>(local);
  }
  std::vector<int> batch(batch_regions_sexp.size());
  std::vector<unsigned char> seen(regions.size(), 0);
  for (R_xlen_t id = 0; id < batch_regions_sexp.size(); ++id) {
    int region = batch_regions_sexp[id] - 1;
    if (region < 0 || region >= static_cast<int>(regions.size()) ||
        seen[region]) {
      Rcpp::stop("batch_regions contains invalid or duplicate ids");
    }
    seen[region] = 1;
    batch[id] = region;
  }
  std::vector<std::vector<double> > regional(batch.size());
  std::vector<std::vector<double> > global_region(batch.size());
  for (std::size_t id = 0; id < batch.size(); ++id) {
    regional[id] = tablo_parallel_slice(
      direct, regions[batch[id]], regions[batch[id]]
    );
    global_region[id] = tablo_parallel_slice(
      direct, global, regions[batch[id]]
    );
  }
  std::vector<TabloParallelCounter> counters(batch.size());
  int effective = std::min<int>(threads, std::max<std::size_t>(1, batch.size()));
#ifdef _OPENMP
#pragma omp parallel for schedule(static) num_threads(effective)
#endif
  for (int batch_id = 0; batch_id < static_cast<int>(batch.size()); ++batch_id) {
    const int region = batch[batch_id];
    std::vector<double> panel;
    std::vector<double> workspace;
    TabloParallelCounter &counter = counters[batch_id];
    for (std::size_t block = 0; block < factor_views.size(); ++block) {
      const TabloSparseLUView &factor = factor_views[block];
      const TabloCscView &left = left_views[block];
      const TabloCscView &right = right_views[block];
      for (std::size_t first = 0; first < regions[region].size();
           first += panel_size) {
        int width = static_cast<int>(std::min<std::size_t>(
          panel_size, regions[region].size() - first
        ));
        ++counter.inspected;
        std::chrono::steady_clock::time_point started =
          std::chrono::steady_clock::now();
        bool nonzero = tablo_parallel_fill(
          right, regions[region], first, width, &panel
        );
        counter.extract += tablo_parallel_elapsed(started);
        counter.peak = std::max(
          counter.peak,
          static_cast<std::size_t>(factor.n) * width * sizeof(double) * 2
        );
        if (!nonzero) {
          ++counter.skipped;
          continue;
        }
        ++counter.solved;
        counter.columns += width;
        started = std::chrono::steady_clock::now();
        if (!tablo_parallel_solve(factor, panel.data(), width, &workspace)) {
          counter.valid = false;
          continue;
        }
        counter.triangular += tablo_parallel_elapsed(started);
        started = std::chrono::steady_clock::now();
        for (int local_column = 0; local_column < left.ncol; ++local_column) {
          for (int position = left.p[local_column];
               position < left.p[local_column + 1]; ++position) {
            int external_row = left.i[position];
            int group = row_group[external_row];
            if (group != region && group != -1) continue;
            int target_row = row_local[external_row];
            double coefficient = left.x[position];
            for (int column = 0; column < width; ++column) {
              double correction = coefficient * panel[
                local_column + static_cast<std::size_t>(factor.n) * column
              ];
              std::size_t output_column = first + column;
              if (group == region) {
                regional[batch_id][target_row +
                  regions[region].size() * output_column] -= correction;
              } else {
                global_region[batch_id][target_row +
                  global.size() * output_column] -= correction;
              }
            }
          }
        }
        counter.multiply += tablo_parallel_elapsed(started);
      }
    }
  }
  for (std::size_t id = 0; id < counters.size(); ++id) {
    if (!counters[id].valid) {
      Rcpp::stop("Parallel sparse triangular solve produced non-finite values");
    }
  }
  long long inspected = 0, skipped = 0, solved = 0, columns = 0;
  double extract = 0, triangular = 0, multiply = 0;
  std::size_t peak = 0;
  for (std::size_t id = 0; id < counters.size(); ++id) {
    inspected += counters[id].inspected;
    skipped += counters[id].skipped;
    solved += counters[id].solved;
    columns += counters[id].columns;
    extract += counters[id].extract;
    triangular += counters[id].triangular;
    multiply += counters[id].multiply;
    peak = std::max(peak, counters[id].peak);
  }
  Rcpp::List regional_output(batch.size());
  Rcpp::List global_output(batch.size());
  for (std::size_t id = 0; id < batch.size(); ++id) {
    int region = batch[id];
    Rcpp::NumericMatrix local(regions[region].size(), regions[region].size());
    std::copy(regional[id].begin(), regional[id].end(), local.begin());
    regional_output[id] = local;
    Rcpp::NumericMatrix global_block(global.size(), regions[region].size());
    std::copy(global_region[id].begin(), global_region[id].end(),
              global_block.begin());
    global_output[id] = global_block;
  }
  Rcpp::List diagnostics = Rcpp::List::create(
    Rcpp::Named("calls") = 1,
    Rcpp::Named("panels_inspected") = inspected,
    Rcpp::Named("zero_panels_skipped") = skipped,
    Rcpp::Named("panels_solved") = solved,
    Rcpp::Named("columns_solved") = columns,
    Rcpp::Named("panel_extract_seconds") = extract,
    Rcpp::Named("sparse_triangular_solve_seconds") = triangular,
    Rcpp::Named("multiply_accumulate_seconds") = multiply,
    Rcpp::Named("peak_panel_buffer_bytes") =
      static_cast<double>(peak) * effective,
    Rcpp::Named("threads_effective") = effective
  );
  return Rcpp::List::create(
    Rcpp::Named("regional") = regional_output,
    Rcpp::Named("global_region") = global_output,
    Rcpp::Named("diagnostics") = diagnostics
  );
}
