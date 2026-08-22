#include <Rcpp.h>

#include <algorithm>
#include <chrono>
#include <cstddef>
#include <vector>

#include "tablo-sparse-lu.h"

struct TabloSchurCounters {
  long long panels_inspected;
  long long zero_panels_skipped;
  long long panels_solved;
  long long columns_solved;
  double extract_seconds;
  double solve_seconds;
  double multiply_seconds;
  std::size_t peak_buffer_bytes;

  TabloSchurCounters()
    : panels_inspected(0), zero_panels_skipped(0), panels_solved(0),
      columns_solved(0), extract_seconds(0), solve_seconds(0),
      multiply_seconds(0), peak_buffer_bytes(0) {}
};

static double tablo_elapsed(
    const std::chrono::steady_clock::time_point &start) {
  return std::chrono::duration<double>(
    std::chrono::steady_clock::now() - start
  ).count();
}

static std::vector<int> tablo_positions(SEXP value_sexp, int upper,
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

static std::vector<std::vector<int> > tablo_region_positions(
    Rcpp::List positions, int upper, std::vector<int> *row_group,
    std::vector<int> *row_local) {
  std::vector<std::vector<int> > result(positions.size());
  row_group->assign(upper, -2);
  row_local->assign(upper, -1);
  for (R_xlen_t region = 0; region < positions.size(); ++region) {
    result[region] = tablo_positions(
      positions[region], upper, "regional positions"
    );
    for (std::size_t local = 0; local < result[region].size(); ++local) {
      int row = result[region][local];
      if ((*row_group)[row] != -2) {
        Rcpp::stop("Regional positions overlap");
      }
      (*row_group)[row] = static_cast<int>(region);
      (*row_local)[row] = static_cast<int>(local);
    }
  }
  return result;
}

static std::vector<double> tablo_dense_slice(
    const TabloCscView &matrix, const std::vector<int> &rows,
    const std::vector<int> &columns) {
  tablo_checked_product(rows.size(), columns.size(), "dense Schur block");
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

static bool tablo_fill_panel(const TabloCscView &right,
                             const std::vector<int> &columns,
                             std::size_t first, int width,
                             std::vector<double> *buffer) {
  const std::size_t used = static_cast<std::size_t>(right.nrow) * width;
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

static Rcpp::List tablo_counter_list(const TabloSchurCounters &counter,
                                     int calls, int threads) {
  return Rcpp::List::create(
    Rcpp::Named("calls") = calls,
    Rcpp::Named("panels_inspected") = counter.panels_inspected,
    Rcpp::Named("zero_panels_skipped") = counter.zero_panels_skipped,
    Rcpp::Named("panels_solved") = counter.panels_solved,
    Rcpp::Named("columns_solved") = counter.columns_solved,
    Rcpp::Named("panel_extract_seconds") = counter.extract_seconds,
    Rcpp::Named("sparse_triangular_solve_seconds") = counter.solve_seconds,
    Rcpp::Named("multiply_accumulate_seconds") = counter.multiply_seconds,
    Rcpp::Named("peak_panel_buffer_bytes") =
      static_cast<double>(counter.peak_buffer_bytes),
    Rcpp::Named("threads_effective") = threads
  );
}

static void tablo_validate_schur_inputs(
    Rcpp::List factors, Rcpp::List left_blocks, Rcpp::List right_blocks,
    int external_dimension, std::vector<TabloSparseLUView> *factor_views,
    std::vector<TabloCscView> *left_views,
    std::vector<TabloCscView> *right_views) {
  if (factors.size() < 1 || factors.size() != left_blocks.size() ||
      factors.size() != right_blocks.size()) {
    Rcpp::stop("Schur factor and coupling lists must have equal nonzero length");
  }
  factor_views->reserve(factors.size());
  left_views->reserve(factors.size());
  right_views->reserve(factors.size());
  for (R_xlen_t id = 0; id < factors.size(); ++id) {
    factor_views->push_back(tablo_sparse_lu_view(factors[id], "factor"));
    int local = (*factor_views)[id].n;
    left_views->push_back(tablo_csc_view(
      left_blocks[id], "left block", external_dimension, local
    ));
    right_views->push_back(tablo_csc_view(
      right_blocks[id], "right block", local, external_dimension
    ));
  }
}

// [[Rcpp::export(name = ".tabloToR_schur_accumulate_global")]]
Rcpp::List tabloToR_schur_accumulate_global(
    Rcpp::List factors, Rcpp::List left_blocks, Rcpp::List right_blocks,
    SEXP direct_external_sexp, Rcpp::List regional_positions_sexp,
    Rcpp::IntegerVector global_positions_sexp, int panel_size) {
  if (panel_size < 1) Rcpp::stop("panel_size must be positive");
  TabloCscView direct = tablo_csc_view(
    direct_external_sexp, "direct external block"
  );
  if (direct.nrow != direct.ncol) {
    Rcpp::stop("Direct external block must be square");
  }
  std::vector<TabloSparseLUView> factor_views;
  std::vector<TabloCscView> left_views;
  std::vector<TabloCscView> right_views;
  tablo_validate_schur_inputs(
    factors, left_blocks, right_blocks, direct.nrow,
    &factor_views, &left_views, &right_views
  );

  std::vector<int> row_group, row_local;
  std::vector<std::vector<int> > regions = tablo_region_positions(
    regional_positions_sexp, direct.nrow, &row_group, &row_local
  );
  std::vector<int> global = tablo_positions(
    global_positions_sexp, direct.nrow, "global positions"
  );
  for (std::size_t local = 0; local < global.size(); ++local) {
    int row = global[local];
    if (row_group[row] != -2) Rcpp::stop("Global positions overlap regions");
    row_group[row] = -1;
    row_local[row] = static_cast<int>(local);
  }

  std::vector<std::vector<double> > region_global(regions.size());
  for (std::size_t region = 0; region < regions.size(); ++region) {
    region_global[region] = tablo_dense_slice(direct, regions[region], global);
  }
  std::vector<double> global_global = tablo_dense_slice(direct, global, global);

  TabloSchurCounters counter;
  std::vector<double> panel, workspace;
  for (std::size_t block = 0; block < factor_views.size(); ++block) {
    const TabloSparseLUView &factor = factor_views[block];
    const TabloCscView &left = left_views[block];
    const TabloCscView &right = right_views[block];
    for (std::size_t first = 0; first < global.size(); first += panel_size) {
      int width = static_cast<int>(std::min<std::size_t>(
        panel_size, global.size() - first
      ));
      ++counter.panels_inspected;
      std::chrono::steady_clock::time_point started =
        std::chrono::steady_clock::now();
      bool nonzero = tablo_fill_panel(right, global, first, width, &panel);
      counter.extract_seconds += tablo_elapsed(started);
      counter.peak_buffer_bytes = std::max(
        counter.peak_buffer_bytes,
        static_cast<std::size_t>(factor.n) * width * sizeof(double) * 2
      );
      if (!nonzero) {
        ++counter.zero_panels_skipped;
        continue;
      }
      ++counter.panels_solved;
      counter.columns_solved += width;
      started = std::chrono::steady_clock::now();
      tablo_sparse_lu_solve_inplace(factor, panel.data(), width, workspace);
      counter.solve_seconds += tablo_elapsed(started);
      started = std::chrono::steady_clock::now();
      for (int local_column = 0; local_column < left.ncol; ++local_column) {
        for (int position = left.p[local_column];
             position < left.p[local_column + 1]; ++position) {
          int external_row = left.i[position];
          int group = row_group[external_row];
          int target_row = row_local[external_row];
          if (target_row < 0) continue;
          double coefficient = left.x[position];
          for (int column = 0; column < width; ++column) {
            double correction = coefficient * panel[
              local_column + static_cast<std::size_t>(factor.n) * column
            ];
            std::size_t output_column = first + column;
            if (group >= 0) {
              region_global[group][target_row +
                regions[group].size() * output_column] -= correction;
            } else if (group == -1) {
              global_global[target_row + global.size() * output_column] -=
                correction;
            }
          }
        }
      }
      counter.multiply_seconds += tablo_elapsed(started);
    }
  }

  Rcpp::List region_output(regions.size());
  for (std::size_t region = 0; region < regions.size(); ++region) {
    Rcpp::NumericMatrix block(regions[region].size(), global.size());
    std::copy(region_global[region].begin(), region_global[region].end(),
              block.begin());
    region_output[region] = block;
  }
  Rcpp::NumericMatrix global_output(global.size(), global.size());
  std::copy(global_global.begin(), global_global.end(), global_output.begin());
  return Rcpp::List::create(
    Rcpp::Named("region_global") = region_output,
    Rcpp::Named("global_global") = global_output,
    Rcpp::Named("diagnostics") = tablo_counter_list(counter, 1, 1)
  );
}

// [[Rcpp::export(name = ".tabloToR_schur_accumulate_batch")]]
Rcpp::List tabloToR_schur_accumulate_batch(
    Rcpp::List factors, Rcpp::List left_blocks, Rcpp::List right_blocks,
    SEXP direct_external_sexp, Rcpp::List regional_positions_sexp,
    Rcpp::IntegerVector global_positions_sexp,
    Rcpp::IntegerVector batch_regions_sexp, int panel_size, int threads) {
  if (panel_size < 1 || threads < 1) {
    Rcpp::stop("panel_size and threads must be positive");
  }
  TabloCscView direct = tablo_csc_view(
    direct_external_sexp, "direct external block"
  );
  if (direct.nrow != direct.ncol) {
    Rcpp::stop("Direct external block must be square");
  }
  std::vector<TabloSparseLUView> factor_views;
  std::vector<TabloCscView> left_views;
  std::vector<TabloCscView> right_views;
  tablo_validate_schur_inputs(
    factors, left_blocks, right_blocks, direct.nrow,
    &factor_views, &left_views, &right_views
  );
  std::vector<int> row_group, row_local;
  std::vector<std::vector<int> > regions = tablo_region_positions(
    regional_positions_sexp, direct.nrow, &row_group, &row_local
  );
  std::vector<int> global = tablo_positions(
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
  TabloSchurCounters counter;
  for (std::size_t batch_id = 0; batch_id < batch.size(); ++batch_id) {
    const int region = batch[batch_id];
    regional[batch_id] = tablo_dense_slice(
      direct, regions[region], regions[region]
    );
    global_region[batch_id] = tablo_dense_slice(
      direct, global, regions[region]
    );
    std::vector<double> panel, workspace;
    for (std::size_t block = 0; block < factor_views.size(); ++block) {
      const TabloSparseLUView &factor = factor_views[block];
      const TabloCscView &left = left_views[block];
      const TabloCscView &right = right_views[block];
      for (std::size_t first = 0; first < regions[region].size();
           first += panel_size) {
        int width = static_cast<int>(std::min<std::size_t>(
          panel_size, regions[region].size() - first
        ));
        ++counter.panels_inspected;
        std::chrono::steady_clock::time_point started =
          std::chrono::steady_clock::now();
        bool nonzero = tablo_fill_panel(
          right, regions[region], first, width, &panel
        );
        counter.extract_seconds += tablo_elapsed(started);
        counter.peak_buffer_bytes = std::max(
          counter.peak_buffer_bytes,
          static_cast<std::size_t>(factor.n) * width * sizeof(double) * 2
        );
        if (!nonzero) {
          ++counter.zero_panels_skipped;
          continue;
        }
        ++counter.panels_solved;
        counter.columns_solved += width;
        started = std::chrono::steady_clock::now();
        tablo_sparse_lu_solve_inplace(factor, panel.data(), width, workspace);
        counter.solve_seconds += tablo_elapsed(started);
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
        counter.multiply_seconds += tablo_elapsed(started);
      }
    }
  }

  Rcpp::List regional_output(batch.size());
  Rcpp::List global_region_output(batch.size());
  for (std::size_t batch_id = 0; batch_id < batch.size(); ++batch_id) {
    int region = batch[batch_id];
    Rcpp::NumericMatrix local_block(regions[region].size(),
                                    regions[region].size());
    std::copy(regional[batch_id].begin(), regional[batch_id].end(),
              local_block.begin());
    regional_output[batch_id] = local_block;
    Rcpp::NumericMatrix global_block(global.size(), regions[region].size());
    std::copy(global_region[batch_id].begin(), global_region[batch_id].end(),
              global_block.begin());
    global_region_output[batch_id] = global_block;
  }
  return Rcpp::List::create(
    Rcpp::Named("regional") = regional_output,
    Rcpp::Named("global_region") = global_region_output,
    Rcpp::Named("diagnostics") = tablo_counter_list(counter, 1, 1)
  );
}
