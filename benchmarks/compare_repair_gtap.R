# Compare aggregate evidence from before-N/after-N benchmark_gtap12a_run.R
# artifacts. Inputs and solutions stay private; the output contains no values
# from either solution. Package signatures intentionally differ across builds.
compare_repair_gtap = function(input_dir, output, pairs = 3L) {
  if (length(pairs) != 1L || !is.finite(pairs) || pairs < 1 ||
      pairs != as.integer(pairs)) stop("pairs must be a positive integer")
  leaf_difference = function(before, after) {
    if (!is.numeric(before) || !is.numeric(after) ||
        !identical(typeof(before), typeof(after)) ||
        !identical(attributes(before), attributes(after)) ||
        length(before) != length(after) ||
        any(!is.finite(before)) || any(!is.finite(after))) {
      stop("Solution/output types, attributes, sizes or finite values disagree")
    }
    difference = abs(before - after)
    if (any(!is.finite(difference))) stop("Non-finite solution difference")
    max(c(0, difference))
  }
  tree_difference = function(before, after) {
    if (is.list(before) || is.list(after)) {
      if (!is.list(before) || !is.list(after) ||
          !identical(attributes(before), attributes(after)) ||
          length(before) != length(after)) stop("Output structures disagree")
      return(max(c(0, vapply(seq_along(before), function(i) {
        tree_difference(before[[i]], after[[i]])
      }, numeric(1)))))
    }
    leaf_difference(before, after)
  }
  read_run = function(label, repetition) {
    id = paste(label, repetition, sep = "-")
    metrics = read.csv(file.path(input_dir, paste0(id, ".csv")),
                       stringsAsFactors = FALSE)
    value = readRDS(file.path(input_dir, paste0(id, ".rds")))
    required = c("run_id", "run_signature", "pair_signature", "model_signature",
                 "backend", "threads", "repetition", "warmup")
    columns = c(required, "status", "iter", "steps", "postsim", "platform",
                "r_version", "matrix_version")
    if (length(setdiff(columns, names(metrics))) ||
        length(setdiff(required, names(value)))) stop("Missing run metadata")
    for (field in required) {
      observed = unique(as.character(metrics[[field]]))
      if (length(observed) != 1L ||
          !identical(observed, as.character(value[[field]]))) {
        stop(paste("CSV/artifact metadata disagree:", id, field))
      }
    }
    if (any(metrics$status != "completed") || value$run_id != id ||
        isTRUE(value$warmup)) stop("Expected a completed measured run")
    list(value = value, metrics = metrics)
  }
  result = vector("list", pairs)
  for (repetition in seq_len(pairs)) {
    before = read_run("before", repetition)
    after = read_run("after", repetition)
    for (field in c("backend", "threads", "repetition", "warmup")) {
      if (!identical(before$value[[field]], after$value[[field]])) {
        stop(paste("Before/after settings disagree:", field))
      }
    }
    for (field in c("iter", "steps", "postsim", "platform",
                    "r_version", "matrix_version")) {
      if (!identical(unique(before$metrics[[field]]),
                     unique(after$metrics[[field]]))) {
        stop(paste("Before/after workload/runtime settings disagree:", field))
      }
    }
    result[[repetition]] = data.frame(
      repetition = repetition,
      solution_values = length(before$value$solution),
      max_solution_abs_difference = leaf_difference(
        before$value$solution, after$value$solution),
      max_output_abs_difference = tree_difference(
        before$value$selected_outputs, after$value$selected_outputs),
      solution_attributes_identical = TRUE,
      output_structure_identical = TRUE,
      all_values_finite = TRUE
    )
    rm(before, after)
    gc(FALSE)
  }
  result = do.call(rbind, result)
  write.csv(result, output, row.names = FALSE)
  result
}

if (sys.nframe() == 0L) {
  args = commandArgs(trailingOnly = TRUE)
  if (!length(args) %in% 2:3) {
    stop("Usage: Rscript compare_repair_gtap.R INPUT_DIR OUTPUT_CSV [PAIRS]")
  }
  print(compare_repair_gtap(args[[1L]], args[[2L]],
                          if (length(args) == 3L) as.numeric(args[[3L]]) else 3L))
}
