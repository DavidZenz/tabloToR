# Numeric sparse execution helpers for GEModel.

.sparse_value_structure = function(value) {
  list(
    class = class(value),
    type = typeof(value),
    length = length(value),
    names = names(value),
    dim = dim(value),
    dimnames = dimnames(value),
    missing = as.vector(is.na(value)),
    encoding = if (is.character(value)) {
      unname(Encoding(value))
    } else character()
  )
}

.sparse_matrix_structure = function(coefficient_matrix) {
  list(
    matrix_class = class(coefficient_matrix),
    matrix_dimensions = dim(coefficient_matrix),
    matrix_nonzeros = length(coefficient_matrix@x)
  )
}

.sparse_backend_candidate_record = function(
    solution, coefficient_matrix, rhs, requested_backend, implementation,
    capability_evidence, elapsed_seconds) {
  list(
    backend = requested_backend,
    requested_backend = requested_backend,
    implementation = implementation,
    solution = solution,
    coefficient_matrix = coefficient_matrix,
    rhs = rhs,
    output_structure = .sparse_value_structure(solution),
    structural_metadata = .sparse_matrix_structure(coefficient_matrix),
    finiteness_evidence = list(
      solution = all(is.finite(solution)),
      rhs = all(is.finite(rhs)),
      matrix = all(is.finite(coefficient_matrix@x))
    ),
    residual_evidence_inputs = list(
      rhs_l2_norm = if (length(rhs)) sqrt(sum(rhs * rhs)) else 0,
      rhs_length = length(rhs),
      solution_length = length(solution),
      matrix_dimensions = dim(coefficient_matrix)
    ),
    timing = list(elapsed_seconds = elapsed_seconds),
    capability_evidence = capability_evidence,
    cleanup_status = list(
      status = "complete",
      scope = "solve",
      resources = "none retained"
    )
  )
}

.sparse_backend_unavailable = function(requested_backend, cause,
                                       remediation) {
  message = sprintf(
    "Requested backend '%s' is unavailable: %s. Remediation: %s",
    requested_backend, cause, remediation
  )
  stop(.gemodelr_solve_condition(
    simpleError(message), "sparse", requested_backend,
    primary_class = "GEModelR_capability_error",
    failure_phase = "capability-preflight",
    remediation = list(action = remediation)
  ))
}

.sparse_backend_noop_cleanup = function(...) {
  list(
    status = "complete",
    scope = "solve",
    resources = "none retained"
  )
}

.sparse_backend_registry = new.env(parent = emptyenv())
.sparse_backend_registry$Matrix = list(
  requested_backend = "Matrix",
  implementation = "solve_sparse_system(Matrix)",
  preflight = function(requested_backend = "Matrix", ...) {
    list(
      requested_backend = requested_backend,
      implementation = "solve_sparse_system(Matrix)",
      available = TRUE,
      capability = "base R Matrix package"
    )
  },
  cleanup = .sparse_backend_noop_cleanup,
  solve = function(coefficient_matrix, rhs, reduction,
                   requested_backend = "Matrix",
                   implementation = "solve_sparse_system(Matrix)",
                   capability_evidence, ...) {
    started = proc.time()[[3L]]
    solution = solve_sparse_system(
      coefficient_matrix, rhs, backend = "Matrix", reduction = reduction
    )
    elapsed_seconds = proc.time()[[3L]] - started
    .sparse_backend_candidate_record(
      solution, coefficient_matrix, rhs, requested_backend, implementation,
      capability_evidence, elapsed_seconds
    )
  }
)

.sparse_backend_registry$SparseM = list(
  requested_backend = "SparseM",
  implementation = "solve_sparse_system(SparseM)",
  preflight = function(requested_backend = "SparseM", ...) {
    if (!requireNamespace("SparseM", quietly = TRUE)) {
      .sparse_backend_unavailable(
        requested_backend,
        "the optional SparseM package is not installed",
        "install SparseM and retry this exact backend"
      )
    }
    list(
      requested_backend = requested_backend,
      implementation = "solve_sparse_system(SparseM)",
      available = TRUE,
      capability = "SparseM sparse solver"
    )
  },
  cleanup = .sparse_backend_noop_cleanup,
  solve = function(coefficient_matrix, rhs, reduction,
                   requested_backend = "SparseM",
                   implementation = "solve_sparse_system(SparseM)",
                   capability_evidence, ...) {
    started = proc.time()[[3L]]
    solution = solve_sparse_system(
      coefficient_matrix, rhs, backend = "SparseM", reduction = reduction
    )
    elapsed_seconds = proc.time()[[3L]] - started
    .sparse_backend_candidate_record(
      solution, coefficient_matrix, rhs, requested_backend, implementation,
      capability_evidence, elapsed_seconds
    )
  }
)

.sparse_backend_registry$SuiteSparse = list(
  requested_backend = "SuiteSparse",
  implementation = "solve_sparse_system(SuiteSparse/UMFPACK)",
  preflight = function(requested_backend = "SuiteSparse", ...) {
    if (!exists("sparse_suite_sparse_available", mode = "function",
                inherits = TRUE) ||
        !isTRUE(sparse_suite_sparse_available())) {
      .sparse_backend_unavailable(
        requested_backend,
        "Rcpp or a supported 64-bit SuiteSparse/UMFPACK installation is unavailable",
        paste(
          "install Rcpp and SuiteSparse with umfpack.h and libumfpack,",
          "or select another explicit backend"
        )
      )
    }
    list(
      requested_backend = requested_backend,
      implementation = "solve_sparse_system(SuiteSparse/UMFPACK)",
      available = TRUE,
      capability = "Rcpp and SuiteSparse/UMFPACK"
    )
  },
  cleanup = .sparse_backend_noop_cleanup,
  solve = function(coefficient_matrix, rhs, reduction,
                   requested_backend = "SuiteSparse",
                   implementation = "solve_sparse_system(SuiteSparse/UMFPACK)",
                   capability_evidence, ...) {
    started = proc.time()[[3L]]
    solution = solve_sparse_system(
      coefficient_matrix, rhs, backend = "SuiteSparse", reduction = reduction
    )
    elapsed_seconds = proc.time()[[3L]] - started
    .sparse_backend_candidate_record(
      solution, coefficient_matrix, rhs, requested_backend, implementation,
      capability_evidence, elapsed_seconds
    )
  }
)

.sparse_backend_structured_adapter = function(
    requested_backend, implementation, reduced_solver) {
  list(
    requested_backend = requested_backend,
    implementation = implementation,
    preflight = function(requested_backend = requested_backend, model = NULL,
                         structured_partition = NULL, ...) {
      if (!exists("sparse_exact_structured_solve", mode = "function",
                  inherits = TRUE)) {
        .sparse_backend_unavailable(
          requested_backend,
          "the structured R solver implementation is unavailable",
          "reinstall GEModelR with its structured solver sources"
        )
      }
      if (is.null(structured_partition)) {
        .sparse_backend_unavailable(
          requested_backend,
          "the model has no validated structured elimination partition",
          "load a supported structured model or select Matrix explicitly"
        )
      }
      .identity_guard_old_options("tabloToR.sparse.lu_order")
      lu_order = suppressWarnings(as.integer(getOption(
        "GEModelR.sparse.lu_order", 3L
      ))[1L])
      if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
        stop(sprintf(
          "Requested backend '%s' cannot run: GEModelR.sparse.lu_order must be an integer from 0 to 3. Remediation: set a supported ordering.",
          requested_backend
        ), call. = FALSE)
      }
      list(
        requested_backend = requested_backend,
        implementation = implementation,
        available = TRUE,
      capability = "structured R Schur solver",
        lu_order = lu_order,
        reduced_solver = reduced_solver
      )
    },
    cleanup = .sparse_backend_noop_cleanup,
    solve = function(coefficient_matrix, rhs, reduction,
                     requested_backend = requested_backend,
                     implementation = implementation,
                     capability_evidence, structured_partition = NULL, ...) {
      started = proc.time()[[3L]]
      exact_result = sparse_exact_structured_solve(
        coefficient_matrix, rhs, structured_partition,
        lu_order = capability_evidence$lu_order,
        pivot_tolerance = getOption(
          "GEModelR.sparse.elimination_pivot_tolerance", 1e-12
        ),
        reduced_solver = capability_evidence$reduced_solver
      )
      elapsed_seconds = proc.time()[[3L]] - started
      candidate = .sparse_backend_candidate_record(
        exact_result$solution, coefficient_matrix, rhs,
        requested_backend, implementation, capability_evidence,
        elapsed_seconds
      )
      candidate$solver_diagnostics = exact_result
      candidate
    }
  )
}

.sparse_backend_registry$StructuredSchur =
  .sparse_backend_structured_adapter(
    "StructuredSchur",
    "sparse_exact_structured_solve(R; reduced_solver=btf)",
    "btf"
  )
.sparse_backend_registry$StructuredSchurFGMRES =
  .sparse_backend_structured_adapter(
    "StructuredSchurFGMRES",
    "sparse_exact_structured_solve(R; reduced_solver=schur)",
    "schur"
  )

.sparse_backend_preflight = function(backend, ...) {
  adapter = .sparse_backend_registry[[backend]]
  if (is.null(adapter)) {
    stop(.gemodelr_solve_condition(
      simpleError(sprintf(
        "Requested backend '%s' has no registered adapter",
        backend
      )),
      "sparse", backend,
      primary_class = "GEModelR_capability_error",
      failure_phase = "capability-preflight",
      remediation = list(action = "Choose a registered sparse backend ID")
    ))
  }
  tryCatch({
    if (!is.list(adapter) ||
        !identical(adapter$requested_backend, backend) ||
        !is.character(adapter$implementation) ||
        length(adapter$implementation) != 1L ||
        is.na(adapter$implementation) || !nzchar(adapter$implementation) ||
        !is.function(adapter$preflight) || !is.function(adapter$solve) ||
        !is.function(adapter$cleanup)) {
      stop(sprintf(
        "Requested backend '%s' has an incomplete or inconsistent adapter registration",
        backend
      ), call. = FALSE)
    }
    capability_evidence = adapter$preflight(
      requested_backend = backend, ...
    )
    if (!is.list(capability_evidence) ||
        !identical(capability_evidence$requested_backend, backend) ||
        !identical(capability_evidence$implementation,
                   adapter$implementation) ||
        !identical(capability_evidence$available, TRUE)) {
      stop(sprintf(
        "Requested backend '%s' returned incomplete preflight evidence",
        backend
      ), call. = FALSE)
    }
    list(
      requested_backend = backend,
      adapter = adapter,
      capability_evidence = capability_evidence
    )
  }, error = function(error) {
    stop(.gemodelr_solve_condition(
      error, "sparse", backend,
      primary_class = "GEModelR_capability_error",
      failure_phase = "capability-preflight",
      remediation = list(
        action = "Install the requested backend or repair its capability registration"
      )
    ))
  })
}

.sparse_backend_solve = function(preflight, coefficient_matrix, rhs,
                                 reduction, ...) {
  if (!is.list(preflight) ||
      !is.character(preflight$requested_backend) ||
      length(preflight$requested_backend) != 1L ||
      is.na(preflight$requested_backend) ||
      !nzchar(preflight$requested_backend) ||
      !is.list(preflight$adapter) ||
      !is.list(preflight$capability_evidence)) {
    stop("Sparse backend preflight record is incomplete", call. = FALSE)
  }
  adapter = preflight$adapter
  if (!identical(adapter$requested_backend, preflight$requested_backend) ||
      !is.character(adapter$implementation) ||
      length(adapter$implementation) != 1L ||
      is.na(adapter$implementation) || !nzchar(adapter$implementation) ||
      !is.function(adapter$preflight) || !is.function(adapter$solve) ||
      !is.function(adapter$cleanup)) {
    stop("Sparse backend adapter identity is inconsistent", call. = FALSE)
  }
  capability_evidence = preflight$capability_evidence
  if (!identical(capability_evidence$requested_backend,
                 preflight$requested_backend) ||
      !identical(capability_evidence$implementation,
                 adapter$implementation) ||
      !identical(capability_evidence$available, TRUE)) {
    stop("Sparse backend capability evidence is inconsistent", call. = FALSE)
  }
  solve_outcome = tryCatch(
    list(result = adapter$solve(
      coefficient_matrix = coefficient_matrix,
      rhs = rhs,
      reduction = reduction,
      requested_backend = preflight$requested_backend,
      implementation = adapter$implementation,
      capability_evidence = capability_evidence,
      ...
    )),
    error = function(error) list(error = error)
  )
  cleanup_outcome = tryCatch(
    list(status = adapter$cleanup(
      requested_backend = preflight$requested_backend,
      capability_evidence = capability_evidence,
      result = solve_outcome$result,
      ...
    )),
    error = function(error) list(error = error)
  )
  if (!is.null(cleanup_outcome$error)) {
    if (!is.null(solve_outcome$error)) {
      stop(sprintf(
        "Sparse backend cleanup failed after solve error: %s (original solve error: %s)",
        conditionMessage(cleanup_outcome$error),
        conditionMessage(solve_outcome$error)
      ), call. = FALSE)
    }
    stop(cleanup_outcome$error)
  }
  if (!is.null(solve_outcome$error)) stop(solve_outcome$error)
  result = solve_outcome$result
  result$cleanup_status = cleanup_outcome$status
  required = c(
    "backend", "requested_backend", "implementation", "solution",
    "coefficient_matrix", "rhs", "output_structure",
    "structural_metadata", "finiteness_evidence",
    "residual_evidence_inputs", "timing", "capability_evidence",
    "cleanup_status"
  )
  missing_fields = setdiff(required, names(result))
  if (!is.list(result) || length(missing_fields)) {
    stop(sprintf(
      "Sparse backend result is missing field(s): %s",
      paste(missing_fields, collapse = ", ")
    ), call. = FALSE)
  }
  if (!identical(result$backend, preflight$requested_backend) ||
      !identical(result$requested_backend, preflight$requested_backend) ||
      !identical(result$implementation, adapter$implementation)) {
    stop("Sparse backend result identity is inconsistent", call. = FALSE)
  }
  if (!identical(result$coefficient_matrix, coefficient_matrix) ||
      !identical(result$rhs, rhs)) {
    stop("Sparse backend result does not match the emitted system",
         call. = FALSE)
  }
  if (!inherits(result$coefficient_matrix, "sparseMatrix")) {
    stop("Sparse backend result coefficient matrix must remain sparse",
         call. = FALSE)
  }
  if (!identical(result$output_structure,
                 .sparse_value_structure(result$solution))) {
    stop("Sparse backend output structure metadata is inconsistent",
         call. = FALSE)
  }
  if (!identical(result$structural_metadata,
                 .sparse_matrix_structure(coefficient_matrix))) {
    stop("Sparse backend structural metadata is inconsistent",
         call. = FALSE)
  }
  evidence = result$finiteness_evidence
  if (!is.list(evidence) ||
      !identical(sort(names(evidence)), c("matrix", "rhs", "solution")) ||
      !all(vapply(evidence, function(value) {
        is.logical(value) && length(value) == 1L && !is.na(value)
      }, logical(1)))) {
    stop("Sparse backend finiteness evidence is incomplete", call. = FALSE)
  }
  residual_inputs = result$residual_evidence_inputs
  if (!is.list(residual_inputs) ||
      !all(c("rhs_l2_norm", "rhs_length", "solution_length",
             "matrix_dimensions") %in% names(residual_inputs)) ||
      !is.numeric(residual_inputs$rhs_l2_norm) ||
      length(residual_inputs$rhs_l2_norm) != 1L ||
      !identical(residual_inputs$rhs_length, length(rhs)) ||
      !identical(residual_inputs$solution_length, length(result$solution)) ||
      !identical(residual_inputs$matrix_dimensions,
                 dim(coefficient_matrix))) {
    stop("Sparse backend residual evidence inputs are inconsistent",
         call. = FALSE)
  }
  timing = result$timing
  if (!is.list(timing) ||
      !is.numeric(timing$elapsed_seconds) ||
      length(timing$elapsed_seconds) != 1L ||
      !is.finite(timing$elapsed_seconds) || timing$elapsed_seconds < 0) {
    stop("Sparse backend elapsed timing is invalid", call. = FALSE)
  }
  if (!identical(result$capability_evidence, capability_evidence)) {
    stop("Sparse backend result capability evidence is inconsistent",
         call. = FALSE)
  }
  cleanup = result$cleanup_status
  if (!is.list(cleanup) || !identical(cleanup$status, "complete") ||
      !identical(cleanup$scope, "solve") ||
      !is.character(cleanup$resources) || length(cleanup$resources) != 1L ||
      is.na(cleanup$resources) || !nzchar(cleanup$resources)) {
    stop("Sparse backend cleanup status is incomplete", call. = FALSE)
  }
  result
}

.sparse_backend_solve_reference = .sparse_backend_solve
.sparse_backend_solve = function(preflight, coefficient_matrix, rhs,
                                 reduction, ...) {
  backend = if (is.list(preflight)) preflight$requested_backend else NULL
  tryCatch(
    .sparse_backend_solve_reference(
      preflight, coefficient_matrix, rhs, reduction, ...
    ),
    error = function(error) {
      stop(.gemodelr_solve_condition(
        error, "sparse", backend,
        primary_class = "GEModelR_numerical_error",
        failure_phase = "candidate-acceptance",
        accepted_numerical_state = FALSE,
        retryable_postsim = FALSE,
        remediation = list(
          action = "Review the backend candidate and its structural evidence"
        )
      ))
    }
  )
}

sparse_state_data = function(state) {
  if (is.environment(state)) state$data else state
}

sparse_make_state = function(data) {
  state = new.env(parent = emptyenv())
  state$data = data
  state
}

.transaction_fault = function(phase, context = list()) {
  hook = getOption("GEModelR.transaction.fault")
  if (!is.function(hook)) return(invisible(NULL))
  tryCatch(
    hook(phase, context),
    error = function(error) {
      attr(error, "transaction_phase") = phase
      stop(error)
    }
  )
  invisible(NULL)
}

.transaction_phase = function(phase, expression) {
  tryCatch(
    force(expression),
    error = function(error) {
      if (is.null(attr(error, "transaction_phase"))) {
        attr(error, "transaction_phase") = phase
      }
      stop(error)
    }
  )
}

.gemodelr_solve_condition = function(
    error, engine, backend, primary_class = NULL, failure_phase = NULL,
    accepted_numerical_state = NULL, retryable_postsim = NULL,
    remediation = NULL) {
  if (!inherits(error, "condition")) {
    error = simpleError(as.character(error)[[1L]])
  }
  error_classes = class(error)
  existing_primary = error_classes[grepl(
    "^GEModelR_.*_error$", error_classes
  )]
  if (is.null(primary_class) && length(existing_primary)) {
    primary_class = existing_primary[[1L]]
  }
  if (is.null(failure_phase)) {
    failure_phase = attr(error, "transaction_phase")
  }
  if (is.null(failure_phase) && !is.null(error$failure_phase)) {
    failure_phase = error$failure_phase
  }
  if (is.null(failure_phase) || !length(failure_phase)) {
    failure_phase = if (identical(primary_class, "GEModelR_validation_error")) {
      "validation"
    } else "setup"
  }
  failure_phase = as.character(failure_phase)[[1L]]
  if (is.null(primary_class)) {
    primary_class = if (identical(failure_phase, "validation")) {
      "GEModelR_validation_error"
    } else if (grepl("^capability", failure_phase)) {
      "GEModelR_capability_error"
    } else if (grepl("^commit-", failure_phase)) {
      "GEModelR_committed_state_error"
    } else if (grepl("^(post|output-)", failure_phase)) {
      if (isTRUE(retryable_postsim)) {
        "GEModelR_retryable_postsim_error"
      } else "GEModelR_postsim_error"
    } else "GEModelR_numerical_error"
  }
  if (is.null(accepted_numerical_state)) {
    accepted_numerical_state = error$accepted_numerical_state
    if (is.null(accepted_numerical_state)) {
      accepted_numerical_state = attr(
        error, "GEModelR.accepted_numerical_state"
      )
    }
    accepted_numerical_state = isTRUE(accepted_numerical_state)
  }
  if (is.null(retryable_postsim)) {
    retryable_postsim = isTRUE(error$retryable_postsim)
  }
  if (is.null(remediation)) remediation = error$remediation
  if (is.null(remediation)) {
    remediation = switch(
      primary_class,
      GEModelR_validation_error = list(
        action = "Correct the solve arguments or load the required model state"
      ),
      GEModelR_capability_error = list(
        action = "Install the requested backend or rebuild its native support"
      ),
      GEModelR_postsim_error = list(
        action = "Correct the postsimulation inputs and retry the solve"
      ),
      GEModelR_retryable_postsim_error = list(
        action = "Correct the postsimulation inputs and call retryPostsim()"
      ),
      GEModelR_committed_state_error = list(
        action = "Inspect the model state and retry the failed commit"
      ),
      list(action = "Review the model inputs and solver evidence before retrying")
    )
  }
  existing_fields = as.list(error)
  existing_fields = existing_fields[setdiff(
    names(existing_fields), c("message", "call")
  )]
  fields = list(
    requested_engine = engine,
    requested_backend = backend,
    failure_phase = failure_phase,
    accepted_numerical_state = isTRUE(accepted_numerical_state),
    retryable_postsim = isTRUE(retryable_postsim),
    remediation = remediation
  )
  existing_fields[names(fields)] = NULL
  result = .gemodelr_condition(
    primary_class, conditionMessage(error), c(existing_fields, fields)
  )
  if (identical(primary_class, "GEModelR_retryable_postsim_error")) {
    class(result) = c(
      "GEModelR_retryable_postsim_error", "GEModelR_postsim_error",
      "error", "condition"
    )
  }
  transaction_phase = attr(error, "transaction_phase")
  if (!is.null(transaction_phase)) {
    attr(result, "transaction_phase") = transaction_phase
  }
  if (isTRUE(accepted_numerical_state)) {
    attr(result, "GEModelR.accepted_numerical_state") = TRUE
  }
  result
}

.transaction_failure_diagnostics = function(engine, error,
                                             retryable_postsim = FALSE) {
  error = .gemodelr_solve_condition(
    error, engine, error$requested_backend,
    accepted_numerical_state = isTRUE(error$accepted_numerical_state),
    retryable_postsim = retryable_postsim
  )
  .gemodelr_diagnostics_envelope(
    engine = error$requested_engine,
    requested_backend = error$requested_backend,
    status = .gemodelr_diagnostics_status(class(error)[[1L]]),
    condition_class = class(error)[[1L]],
    accepted_numerical_state = error$accepted_numerical_state,
    retryable_postsim = error$retryable_postsim,
    failure_phase = error$failure_phase,
    failure_reason = conditionMessage(error)
  )
}

.postsim_failure_diagnostics = function(record, error, diagnostics = FALSE) {
  requested_backend = error$requested_backend
  if (is.null(requested_backend)) {
    requested_backend = record$requested_backend
  }
  error = .gemodelr_solve_condition(
    error, record$engine, requested_backend,
    accepted_numerical_state = TRUE,
    retryable_postsim = TRUE
  )
  details = if (isTRUE(diagnostics)) {
    .gemodelr_diagnostics_details(record$diagnostics)
  } else list()
  if (isTRUE(diagnostics)) details$post_simulation_retained = FALSE
  .gemodelr_diagnostics_envelope(
    engine = record$engine,
    requested_backend = requested_backend,
    implementation = record$diagnostics$implementation,
    status = .gemodelr_diagnostics_status(class(error)[[1L]]),
    condition_class = class(error)[[1L]],
    accepted_numerical_state = TRUE,
    retryable_postsim = TRUE,
    failure_phase = error$failure_phase,
    failure_reason = conditionMessage(error),
    cleanup_status = record$diagnostics$cleanup_status,
    details = details
  )
}

.commit_accepted_state = function(model, record) {
  required = c(
    "state", "index", "solution", "diagnostics", "loaded_engine",
    "postsim_record"
  )
  missing = setdiff(required, names(record))
  if (length(missing)) {
    stop(sprintf(
      "Accepted state record is missing field(s): %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  .transaction_fault(
    "commit-accepted-state", list(engine = record$loaded_engine)
  )
  model$sparseState = record$state
  model$sparseIndex = record$index
  model$solution = record$solution
  model$lastDiagnostics = record$diagnostics
  model$loadedEngine = record$loaded_engine
  model$.postsimRecord = record$postsim_record
  invisible(model)
}

.commit_postsim_state = function(model, record) {
  required = c("state", "data", "compact_output", "diagnostics")
  missing = setdiff(required, names(record))
  if (length(missing)) {
    stop(sprintf(
      "Post-simulation state record is missing field(s): %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  .transaction_fault("commit-postsim-state")
  model$sparseState = record$state
  model$data = record$data
  model$compactOutput = record$compact_output
  model$lastDiagnostics = record$diagnostics
  model$.postsimRecord = list()
  invisible(model)
}

.retry_postsim_from_record = function(model, diagnostics = FALSE) {
  record = model$.postsimRecord
  required = c(
    "engine", "state_data", "index", "solve_index", "spec", "solution",
    "diagnostics", "postsim", "output", "variables", "dimensions"
  )
  if (!is.list(record) || !length(record) ||
      length(setdiff(required, names(record)))) {
    stop("No retryable post-simulation record is available", call. = FALSE)
  }
  state = sparse_make_state(record$state_data)
  if (!is.null(record$structural_cache)) {
    state$.solver_cache = record$structural_cache
  }
  tryCatch({
    .transaction_phase("post-update", {
      .transaction_fault("post-update")
      if (isTRUE(record$postsim)) {
        sparse_apply_updates(
          state, record$index, record$spec,
          updates = record$spec$post_updates
        )
      }
    })
    result = .transaction_phase("output-projection", {
      .transaction_fault("output-projection")
      selected = if (record$output == "compact" ||
                     !is.null(record$variables) ||
                     !is.null(record$dimensions)) {
        sparse_project_outputs(
          state, record$index, record$variables, record$dimensions,
          if (record$output == "compact") record$solution else NULL,
          memory_budget = record$memory_budget, spec = record$spec
        )
      } else NULL
      compact_output = if (!is.null(selected)) selected else list()
      data_result = if (isTRUE(record$postsim)) {
        if (record$output == "full") {
          sparse_materialize_labels(
            state, record$index, equations = TRUE, variables = TRUE
          )
        } else {
          sparse_state_data(state)
        }
      } else {
        list()
      }
      list(data = data_result, compact_output = compact_output)
    })
    complete = record$diagnostics
    complete$status = "succeeded"
    complete$accepted_numerical_state = TRUE
    complete$retryable_postsim = FALSE
    complete$failure_phase = NULL
    complete$failure_reason = NULL
    complete$post_simulation_retained = isTRUE(record$postsim)
    details = if (isTRUE(diagnostics)) {
      .gemodelr_diagnostics_details(complete)
    } else list()
    cleanup = complete$cleanup_status
    if (is.null(cleanup)) {
      cleanup = list(status = "complete", scope = "postsim", resources = "none")
    }
    public_diagnostics = .gemodelr_diagnostics_envelope(
      engine = record$engine,
      requested_backend = record$requested_backend,
      implementation = complete$implementation,
      status = "succeeded",
      accepted_numerical_state = TRUE,
      retryable_postsim = FALSE,
      cleanup_status = cleanup,
      details = details
    )
    .commit_postsim_state(model, list(
      state = state,
      data = result$data,
      compact_output = result$compact_output,
      diagnostics = public_diagnostics
    ))
    invisible(model)
  }, error = function(error) {
    backend = record$requested_backend
    if (is.null(backend)) backend = record$diagnostics$requested_backend
    if (is.null(backend)) backend = record$diagnostics$solver_backend
    error = .gemodelr_solve_condition(
      error, record$engine, backend,
      accepted_numerical_state = TRUE,
      retryable_postsim = TRUE,
      remediation = list(
        action = "Correct the postsimulation failure and call retryPostsim()"
      )
    )
    attr(error, "GEModelR.accepted_numerical_state") = TRUE
    model$lastDiagnostics = .postsim_failure_diagnostics(
      record, error, diagnostics = diagnostics
    )
    stop(error)
  })
}

.commit_legacy_state = function(model, working, diagnostics = FALSE) {
  .transaction_fault("commit-accepted-state", list(engine = "legacy"))
  model$shocks = working$shocks
  model$data = working$data
  model$solution = working$solution
  model$compactOutput = working$compactOutput
  working_diagnostics = working$lastDiagnostics
  details = if (isTRUE(diagnostics)) {
    .gemodelr_diagnostics_details(working_diagnostics)
  } else list()
  cleanup = working_diagnostics$cleanup_status
  if (is.null(cleanup)) {
    cleanup = list(
      status = "complete", scope = "solve",
      resources = "legacy working model"
    )
  }
  model$lastDiagnostics = .gemodelr_diagnostics_envelope(
    engine = "legacy",
    requested_backend = working_diagnostics$requested_backend,
    implementation = "r", status = "succeeded",
    accepted_numerical_state = TRUE,
    retryable_postsim = FALSE,
    cleanup_status = cleanup,
    details = details
  )
  model$loadedEngine = working$loadedEngine
  model$.postsimRecord = list()
  invisible(model)
}
sparse_process_tablo = function(tabloPath) {
  statements = tabloToStatements(tabloPath)
  sparse_spec = sparse_compile_spec(statements)
  # The sparse update evaluator initializes formula targets after indexing.
  # Keeping formulas out of the legacy skeleton avoids materializing large
  # derived arrays through the old vectorized generator.
  skeleton_statements = Filter(function(statement) {
    statement$class %in% c("set", "coefficient", "read") &&
      !grepl("^mapping\\s", statement$parsed$equation,
             ignore.case = TRUE)
  }, statements)
  base_generator = generateSkeleton(skeleton_statements)
  mapping_statements = Filter(function(statement) {
    statement$class == "formula" &&
      grepl("\\$pos", statement$parsed$equation, ignore.case = TRUE)
  }, statements)
  generator = function(input_data) {
    result = base_generator(input_data)
    for (statement in mapping_statements) {
      parsed = tryCatch(correctFormula(statement$parsed$equation),
                        error = function(e) NULL)
      if (is.null(parsed) || length(parsed) < 3L) next
      target = tryCatch(sparse_parse_ref(parsed[[2]]),
                        error = function(e) NULL)
      if (is.null(target) || !is.null(result[[target$name]])) next
      domains = lapply(
        statement$parsed$elements[
          grepl("^\\s*\\(all,", statement$parsed$elements,
               ignore.case = TRUE)
        ], sparse_parse_qualifier
      )
      domains = sparse_order_domains(domains, target$indices)
      dimensions = vapply(domains, function(domain) {
        length(sparse_find_set_values(result, domain$set))
      }, integer(1))
      if (length(dimensions)) {
        dim_names = lapply(domains, function(domain) {
          sparse_find_set_values(result, domain$set)
        })
        result[[target$name]] = array(
          NA_real_, dim = dimensions, dimnames = dim_names
        )
      } else {
        result[[target$name]] = NA_real_
      }
    }
    result
  }
  gem = generateEquationCoefficientMatrix(
    Filter(function(statement) statement$class == "variable", statements),
    Filter(function(statement) statement$class == "equation", statements)
  )
  gec = generateEquationCoefficients(
    Filter(function(statement) statement$class == "equation", statements)
  )
  gev = generateVariables(
    Filter(function(statement) statement$class == "variable", statements)
  )
  geq = generateEquationLevels(
    Filter(function(statement) statement$class == "equation", statements)
  )
  change = vapply(sparse_spec$variables, function(variable) {
    isTRUE(variable$change)
  }, logical(1))
  list(
    skeletonGenerator = generator,
    equationCoefficientMatrixGenerator = gem,
    equationCoefficientGenerator = gec,
    generateVariables = gev,
    generateUpdates = function(data) data,
    generateEquationLevelValues = geq,
    variables = sparse_spec$variable_names,
    changeVariables = sparse_spec$variable_names[change],
    statements = statements,
    sparseSpec = sparse_spec
  )
}

.legacy_label_key = function(labels) {
  gsub("[\\\"'[:space:]]", "", as.character(labels))
}

legacy_resolve_model_labels = function(data, labels, role = "Model") {
  if (!is.list(data) || is.null(data$variables) ||
      !length(data$variables)) {
    stop(sprintf("%s labels cannot be resolved before model data is loaded",
                 role), call. = FALSE)
  }
  labels = as.character(labels)
  references = lapply(labels, sparse_parse_label)
  declared_labels = as.character(data$variables)
  global_positions = match(
    .legacy_label_key(labels), .legacy_label_key(declared_labels)
  )
  if (anyNA(global_positions)) {
    invalid = labels[which(is.na(global_positions))[[1L]]]
    stop(sprintf(
      "%s label does not resolve to a declared variable/index: %s",
      role, invalid
    ), call. = FALSE)
  }
  declared_names = tolower(sub("\\[.*$", "", declared_labels))
  variable_names = vapply(references, `[[`, character(1), "name")
  if (any(variable_names != declared_names[global_positions])) {
    invalid = labels[which(variable_names !=
                             declared_names[global_positions])[[1L]]]
    stop(sprintf(
      "%s label does not resolve to its declared variable: %s",
      role, invalid
    ), call. = FALSE)
  }
  local_positions = integer(length(labels))
  for (i in seq_along(labels)) {
    within_variable = which(declared_names == variable_names[[i]])
    local_positions[[i]] = match(global_positions[[i]], within_variable)
    values = data[[variable_names[[i]]]]
    if (is.na(local_positions[[i]]) ||
        is.null(values) || local_positions[[i]] > length(values)) {
      stop(sprintf("%s label has no matching data position: %s",
                   role, labels[[i]]), call. = FALSE)
    }
  }
  list(
    labels = labels,
    references = references,
    variable_names = variable_names,
    global_positions = as.integer(global_positions),
    local_positions = as.integer(local_positions)
  )
}

legacy_apply_labeled_values = function(data, values) {
  if (!length(values)) return(data)
  labels = names(values)
  if (is.null(labels) && length(dim(values)) == 2L && dim(values)[[2L]] == 1L) {
    labels = rownames(values)
  }
  values = as.numeric(values)
  if (is.null(labels) || length(labels) != length(values)) {
    stop("Model values must have declared TABLO labels", call. = FALSE)
  }
  if (any(!is.finite(values))) {
    stop("Model values contain non-finite entries", call. = FALSE)
  }
  resolved = legacy_resolve_model_labels(data, labels, "Model value")
  for (i in seq_along(values)) {
    variable = resolved$variable_names[[i]]
    array = data[[variable]]
    array[resolved$local_positions[[i]]] = values[[i]]
    data[[variable]] = array
  }
  data
}

legacy_shocks_from_explicit = function(model) {
  explicit = model$explicitShocks
  if (is.null(explicit) || !length(explicit$labels)) return(numeric())
  resolved = legacy_resolve_model_labels(
    model$data, explicit$labels, "Shock"
  )
  inferred = resolved$variable_names
  closure = unique(tolower(c(model$closure, inferred)))
  pieces = list()
  for (variable in closure) {
    values = model$variableValues[[variable]]
    if (is.null(values)) values = model$data[[variable]]
    if (is.null(values)) next
    piece = toVector(values, variable)
    piece[] = 0
    pieces[[length(pieces) + 1L]] = piece
  }
  shocks = if (length(pieces)) do.call(c, pieces) else numeric()
  if (!length(shocks)) {
    shocks = setNames(numeric(), character())
  }
  explicit_keys = .legacy_label_key(explicit$labels)
  unique_keys = unique(explicit_keys)
  explicit_values = vapply(unique_keys, function(value) {
    sum(explicit$values[explicit_keys == value])
  }, numeric(1))
  explicit_labels = explicit$labels[match(unique_keys, explicit_keys)]
  keep = !is.na(explicit_values) & explicit_values != 0
  explicit_values = explicit_values[keep]
  explicit_labels = explicit_labels[keep]
  positions = match(unique_keys[keep], .legacy_label_key(names(shocks)))
  if (anyNA(positions)) {
    stop("Resolved shock labels are absent from legacy closure storage",
         call. = FALSE)
  }
  for (i in seq_along(explicit_labels)) {
    shocks[[positions[[i]]]] = explicit_values[[i]]
  }
  shocks[!is.na(shocks)]
}

sparse_normalize_shocks = function(shocks) {
  if (is.null(shocks)) {
    return(list(labels = character(), values = numeric()))
  }
  if (is.list(shocks) &&
      !is.null(shocks$labels) && !is.null(shocks$values)) {
    labels = as.character(shocks$labels)
    values = as.numeric(shocks$values)
  } else {
    values = as.numeric(shocks)
    labels = names(shocks)
    if (is.null(labels)) {
      stop("Sparse shocks must be a named numeric vector", call. = FALSE)
    }
  }
  keep = !is.na(values) & values != 0 & !is.na(labels) & nzchar(labels)
  labels = labels[keep]
  values = values[keep]
  if (!length(labels)) {
    return(list(labels = character(), values = numeric()))
  }
  unique_labels = unique(labels)
  values = vapply(unique_labels, function(label) {
    sum(values[labels == label])
  }, numeric(1))
  keep = !is.na(values) & values != 0
  list(labels = unique_labels[keep], values = values[keep])
}

sparse_set_closure_state = function(model, exogenous_variables) {
  if (is.null(exogenous_variables)) exogenous_variables = character()
  if (is.list(exogenous_variables) && !is.null(names(exogenous_variables))) {
    exogenous_variables = names(exogenous_variables)
  }
  exogenous_variables = as.character(exogenous_variables)
  exogenous_variables = sub("\\[.*$", "", exogenous_variables)
  exogenous_variables = sub("\\(.*$", "", exogenous_variables)
  exogenous_variables = tolower(unique(exogenous_variables[nzchar(exogenous_variables)]))
  compiled_variables = model$sparseSpec$variable_names
  if (is.null(compiled_variables)) {
    compiled_variables = names(model$sparseIndex$variable_by_name)
  }
  compiled_variables = tolower(as.character(compiled_variables))
  if (length(exogenous_variables) && !length(compiled_variables)) {
    stop("Cannot validate closure without compiled TABLO variables",
         call. = FALSE)
  }
  unknown = setdiff(exogenous_variables, compiled_variables)
  if (length(unknown)) {
    stop(sprintf("Unknown closure variable(s): %s",
                 paste(unknown, collapse = ", ")), call. = FALSE)
  }

  replacement_index = model$sparseIndex
  has_sparse_index = !is.null(replacement_index) && length(replacement_index)
  if (has_sparse_index) {
    replacement_index = sparse_rebuild_columns(
      replacement_index, exogenous_variables
    )
  }

  model$closure = exogenous_variables
  if (has_sparse_index) model$sparseIndex = replacement_index
  invisible(model)
}

sparse_set_shocks_state = function(model, shocks) {
  normalized = sparse_normalize_shocks(shocks)
  model$explicitShocks = normalized
  model$shocks = setNames(normalized$values, normalized$labels)
  invisible(model)
}

sparse_set_memory_budget_state = function(model, bytes) {
  if (is.null(bytes) || !length(bytes) || is.na(bytes)) {
    model$memoryBudget = numeric()
  } else {
    bytes = as.numeric(bytes)[1L]
    if (!is.finite(bytes) || bytes <= 0) {
      stop("Memory budget must be a positive number of bytes", call. = FALSE)
    }
    model$memoryBudget = bytes
  }
  invisible(model)
}

sparse_ref_value = function(expr, state, bindings, index) {
  if (is.name(expr) && !is.null(bindings[[as.character(expr)]])) {
    return(bindings[[as.character(expr)]])
  }
  if (is.character(expr) && length(expr) == 1L &&
      !is.null(bindings[[expr]])) {
    return(bindings[[expr]])
  }
  if (!is.language(expr) && length(expr) == 1L) return(expr)
  sparse_eval_expr(expr, state, bindings, index)
}

sparse_data_linear_index = function(ref, state, bindings, index) {
  data = sparse_state_data(state)
  array = data[[ref$name]]
  if (is.null(array)) {
    stop(sprintf("Data array %s is missing", ref$name), call. = FALSE)
  }
  dims = dim(array)
  if (is.null(dims) || !length(ref$indices)) return(1L)
  if (length(ref$indices) != length(dims)) {
    stop(sprintf("Data array %s expects %s indices, got %s",
                 ref$name, length(dims), length(ref$indices)),
         call. = FALSE)
  }
  positions = integer(length(dims))
  dim_names = dimnames(array)
  for (d in seq_along(dims)) {
    value = sparse_ref_value(ref$indices[[d]], state, bindings, index)
    source_set = if (is.name(ref$indices[[d]])) {
      bindings[[paste0(".set:", as.character(ref$indices[[d]]))]]
    } else NULL
    target_set = if (!is.null(dim_names) &&
                     !is.null(names(dim_names)) &&
                     d <= length(dim_names)) {
      names(dim_names)[[d]]
    } else NULL
    if (is.null(target_set)) {
      data_id = index$variable_by_name[[ref$name]]
      if (!is.null(data_id) && d <= length(index$variables[[data_id]]$sets)) {
        target_set = index$variables[[data_id]]$sets[[d]]
      }
    }
    if (!is.null(source_set) && !is.null(target_set) &&
        !identical(source_set, target_set) &&
        !is.null(index$sets[[source_set]]) &&
        is.numeric(value) && length(value) == 1L && !is.na(value) &&
        value >= 1L && value <= length(index$sets[[source_set]]$values)) {
      value = index$sets[[source_set]]$values[[as.integer(value)]]
    }
    if (is.numeric(value) && length(value) == 1L &&
        !is.na(value) && value == as.integer(value) &&
        value >= 1L && value <= dims[[d]]) {
      positions[[d]] = as.integer(value)
    } else if (!is.null(dim_names) && !is.null(dim_names[[d]])) {
      positions[[d]] = match(as.character(value), dim_names[[d]])
    } else {
      positions[[d]] = sparse_position_for_label(
        as.character(value),
        if (d <= length(index$sets)) names(index$sets)[[d]] else "",
        index
      )
    }
    if (is.na(positions[[d]]) || positions[[d]] < 1L ||
        positions[[d]] > dims[[d]]) {
      stop(sprintf("Cannot resolve data index %s[%s]", ref$name, d),
           call. = FALSE)
    }
  }
  linear = 1L
  stride = 1L
  for (d in seq_along(positions)) {
    linear = linear + (positions[[d]] - 1L) * stride
    stride = stride * dims[[d]]
  }
  as.integer(linear)
}

sparse_global_for_ref = function(ref, state, bindings, index) {
  id = index$variable_by_name[[ref$name]]
  if (is.null(id)) {
    stop(sprintf("Unknown variable in sparse expression: %s", ref$name),
         call. = FALSE)
  }
  variable = index$variables[[id]]
  if (!length(variable$sets)) {
    return(as.integer(variable$global_start))
  }
  if (length(ref$indices) != length(variable$sets)) {
    stop(sprintf("Variable %s expects %s indices, got %s",
                 ref$name, length(variable$sets), length(ref$indices)),
         call. = FALSE)
  }
  positions = integer(length(variable$sets))
  for (d in seq_along(variable$sets)) {
    value = sparse_ref_value(ref$indices[[d]], state, bindings, index)
    set_name = variable$sets[[d]]
    set = index$sets[[set_name]]
    source_set = if (is.name(ref$indices[[d]])) {
      bindings[[paste0(".set:", as.character(ref$indices[[d]]))]]
    } else NULL
    if (!is.null(source_set) && !identical(source_set, set_name) &&
        !is.null(index$sets[[source_set]]) &&
        is.numeric(value) && length(value) == 1L && !is.na(value) &&
        value >= 1L && value <= length(index$sets[[source_set]]$values)) {
      value = index$sets[[source_set]]$values[[as.integer(value)]]
    }
    if (is.numeric(value) && length(value) == 1L &&
        !is.na(value) && value == as.integer(value) &&
        value >= 1L && value <= length(set$values)) {
      positions[[d]] = as.integer(value)
    } else {
      positions[[d]] = sparse_position_for_label(
        as.character(value), set_name, index
      )
    }
    if (is.na(positions[[d]])) {
      stop(sprintf("Cannot resolve index %s of %s",
                   paste(deparse(ref$indices[[d]]), collapse = " "),
                   ref$name), call. = FALSE)
    }
  }
  local = 1L
  stride = 1L
  for (d in seq_along(positions)) {
    local = local + (positions[[d]] - 1L) * stride
    stride = stride * variable$lengths[[d]]
  }
  as.integer(variable$global_start + local - 1L)
}

sparse_set_data_ref = function(ref, state, bindings, index, value) {
  data = sparse_state_data(state)
  linear = sparse_data_linear_index(ref, state, bindings, index)
  array = data[[ref$name]]
  array[[linear]] = as.numeric(value)[1L]
  data[[ref$name]] = array
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_initialize_update_target = function(update, state, index) {
  data = sparse_state_data(state)
  name = update$target$name
  if (!is.null(data[[name]])) return(invisible(NULL))
  domains = update$domains
  if (length(domains)) {
    dimensions = vapply(domains, function(domain) {
      length(index$sets[[domain$set]]$values)
    }, integer(1))
    dim_names = lapply(domains, function(domain) {
      index$sets[[domain$set]]$values
    })
    data[[name]] = array(
      NA_real_, dim = dimensions, dimnames = dim_names
    )
  } else {
    data[[name]] = NA_real_
  }
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_initialize_update_targets = function(state, index, spec,
                                            updates = NULL) {
  if (is.null(spec)) return(invisible(NULL))
  if (is.null(updates)) {
    updates = if (!is.null(spec$simulation_updates)) {
      spec$simulation_updates
    } else spec$updates
  }
  if (!length(updates)) return(invisible(NULL))
  for (update in updates) {
    sparse_initialize_update_target(update, state, index)
  }
  invisible(NULL)
}
sparse_variable_label = function(variable, local, index) {
  if (!length(variable$sets)) return(sprintf("%s[]", variable$name))
  positions = arrayInd(local, .dim = variable$lengths)
  values = vapply(seq_along(variable$sets), function(d) {
    index$sets[[variable$sets[[d]]]]$values[[positions[[d]]]]
  }, character(1))
  sprintf("%s[%s]", variable$name,
          paste(sprintf("\"%s\"", values), collapse = ","))
}

sparse_endogenous_labels = function(index) {
  labels = character(index$endogenous_count)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous)) next
    for (local in seq_len(variable$n)) {
      labels[[variable$endo_start + local - 1L]] =
        sparse_variable_label(variable, local, index)
    }
  }
  labels
}

sparse_shocks_from_variable_values = function(model, state, index) {
  values_list = model$variableValues
  if (is.null(values_list) || !length(values_list)) {
    return(sparse_normalize_shocks(NULL))
  }
  labels = character()
  values = numeric()
  for (variable in index$variables) {
    if (!isTRUE(variable$exogenous)) next
    array = values_list[[variable$name]]
    if (is.null(array)) array = sparse_state_data(state)[[variable$name]]
    if (is.null(array)) next
    flat = as.numeric(array)
    positions = which(!is.na(flat) & flat != 0)
    if (!length(positions)) next
    labels = c(labels, vapply(positions, function(local) {
      sparse_variable_label(variable, local, index)
    }, character(1)))
    values = c(values, flat[positions])
  }
  sparse_normalize_shocks(setNames(values, labels))
}

sparse_resolve_shocks = function(model, state, index) {
  explicit = model$explicitShocks
  if (is.null(explicit) || !length(explicit$labels)) {
    explicit = sparse_shocks_from_variable_values(model, state, index)
  }
  if (!length(explicit$labels)) {
    return(list(positions = integer(), values = numeric(),
                labels = character()))
  }
  positions = integer(length(explicit$labels))
  for (i in seq_along(explicit$labels)) {
    ref = sparse_parse_label(explicit$labels[[i]])
    id = index$variable_by_name[[ref$name]]
    if (is.null(id)) {
      stop(sprintf("Shock references unknown variable %s", ref$name),
           call. = FALSE)
    }
    variable = index$variables[[id]]
    if (!isTRUE(variable$exogenous)) {
      stop(sprintf("Shock variable %s is not in the configured closure",
                   ref$name), call. = FALSE)
    }
    positions[[i]] = sparse_global_for_ref(ref, state, list(), index)
  }
  unique_positions = unique(positions)
  values = vapply(unique_positions, function(position) {
    sum(explicit$values[positions == position])
  }, numeric(1))
  keep = !is.na(values) & values != 0
  list(
    positions = as.integer(unique_positions[keep]),
    values = values[keep],
    labels = explicit$labels[match(unique_positions, positions)][keep]
  )
}

sparse_shock_map = function(shocks) {
  map = new.env(hash = TRUE, parent = emptyenv())
  if (length(shocks$positions)) {
    for (i in seq_along(shocks$positions)) {
      map[[as.character(shocks$positions[[i]])]] = shocks$values[[i]]
    }
  }
  map
}

sparse_shock_lookup = function(map, position) {
  value = map[[as.character(position)]]
  if (is.null(value)) 0 else as.numeric(value)
}

sparse_triplet_capacity = function(index) {
  if (!length(index$equations)) return(0L)
  total = 0
  for (equation in index$equations) {
    if (!length(equation$terms) || equation$n == 0L) next
    for (term in equation$terms) {
      multiplier = if (length(term$sums)) {
        prod(vapply(term$sums, function(sum_spec) {
          length(index$sets[[sum_spec$set]]$values)
        }, numeric(1)))
      } else 1
      total = total + equation$n * multiplier
    }
  }
  as.numeric(total)
}

sparse_aggregate_triplets = function(i, j, x) {
  if (!length(i)) return(list(i = integer(), j = integer(), x = numeric()))
  order_value = order(i, j)
  sorted_i = i[order_value]
  sorted_j = j[order_value]
  sorted_x = x[order_value]
  if (anyNA(sorted_i) || anyNA(sorted_j) || anyNA(sorted_x)) {
    stop("Sparse triplet emission produced missing indices or values", call. = FALSE)
  }
  if (any(!is.finite(sorted_x))) {
    stop("Sparse triplet emission produced non-finite coefficients", call. = FALSE)
  }
  starts = c(TRUE, sorted_i[-1L] != sorted_i[-length(sorted_i)] |
                   sorted_j[-1L] != sorted_j[-length(sorted_j)])
  starts = which(starts)
  ends = c(starts[-1L] - 1L, length(sorted_i))
  groups = cumsum(c(TRUE, sorted_i[-1L] != sorted_i[-length(sorted_i)] |
                            sorted_j[-1L] != sorted_j[-length(sorted_j)]))
  aggregated = as.numeric(rowsum(sorted_x, groups, reorder = FALSE))
  if (any(!is.finite(aggregated))) {
    stop("Sparse triplet aggregation produced non-finite coefficients", call. = FALSE)
  }
  keep = aggregated != 0
  list(
    i = as.integer(sorted_i[starts][keep]),
    j = as.integer(sorted_j[starts][keep]),
    x = aggregated[keep]
  )
}

sparse_emit_system_scalar = function(state, index, shocks) {
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(NULL, index, state)
  }
  capacity = sparse_triplet_capacity(index)
  raw_i = if (capacity) integer(capacity) else integer()
  raw_j = if (capacity) integer(capacity) else integer()
  raw_x = if (capacity) numeric(capacity) else numeric()
  raw_count = 0L
  inverse_order = if (length(index$column_order)) {
    inverse = integer(index$endogenous_count)
    inverse[index$column_order] = seq_along(index$column_order)
    inverse
  } else integer()
  rhs = numeric(index$equation_count)
  shock_map = sparse_shock_map(shocks)
  row = 0L

  append_term = function(row_number, variable_position, value) {
    raw_count <<- raw_count + 1L
    if (raw_count > length(raw_x)) {
      raw_i <<- c(raw_i, integer(max(1024L, length(raw_i))))
      raw_j <<- c(raw_j, integer(max(1024L, length(raw_j))))
      raw_x <<- c(raw_x, numeric(max(1024L, length(raw_x))))
    }
    raw_i[[raw_count]] <<- row_number
    raw_j[[raw_count]] <<- if (length(inverse_order)) {
      inverse_order[[variable_position]]
    } else variable_position
    raw_x[[raw_count]] <<- value
  }

  for (equation in index$equations) {
    sparse_for_each_domain(
      equation$domains, state, index, callback = function(bindings) {
        row <<- row + 1L
        for (term in equation$terms) {
          sparse_for_each_sum(
            term$sums, state, index, bindings,
            callback = function(sum_bindings) {
              guard_ok = TRUE
              if (length(term$guards)) {
                guard_ok = all(vapply(term$guards, function(guard) {
                  isTRUE(as.logical(sparse_eval_expr(
                    guard, state, sum_bindings, index
                  )))
                }, logical(1)))
              }
              value = if (guard_ok) sparse_eval_expr(
                term$coefficient, state, sum_bindings, index
              ) else 0
              if (guard_ok && (length(value) != 1L ||
                               !is.finite(value[[1L]]))) {
                stop(sprintf(
                  "Sparse coefficient for %s -> %s is not a finite scalar",
                  equation$name, term$ref$name
                ), call. = FALSE)
              }
              value = if (guard_ok) as.numeric(value[[1L]]) else 0
              ref_position = sparse_global_for_ref(
                term$ref, state, sum_bindings, index
              )
              variable_id = index$variable_by_name[[term$ref$name]]
              variable = index$variables[[variable_id]]
              if (isTRUE(variable$exogenous)) {
                rhs[[row]] <<- rhs[[row]] -
                  value * sparse_shock_lookup(shock_map, ref_position)
              } else {
                append_term(
                  row, variable$endo_start +
                    ref_position - variable$global_start, value
                )
              }
            }
          )
        }
      }
    )
  }
  if (row != index$equation_count) {
    stop(sprintf("Sparse row layout generated %s rows, expected %s",
                 row, index$equation_count), call. = FALSE)
  }
  if (raw_count) {
    raw_i = raw_i[seq_len(raw_count)]
    raw_j = raw_j[seq_len(raw_count)]
    raw_x = raw_x[seq_len(raw_count)]
  }
  triplets = sparse_aggregate_triplets(raw_i, raw_j, raw_x)
  if (any(!is.finite(rhs))) {
    stop("Sparse emission produced a non-finite right-hand side", call. = FALSE)
  }
  key = sparse_pattern_key(index)
  cached = index$pattern_cache
  if (!is.null(cached) && identical(cached$key, key) &&
      length(cached$i) == length(triplets$i) &&
      identical(cached$i, triplets$i) &&
      identical(cached$j, triplets$j)) {
    triplets$i = cached$i
    triplets$j = cached$j
  } else {
    index$pattern_cache = list(
      key = key, i = triplets$i, j = triplets$j,
      raw_count = raw_count, nnz = length(triplets$x)
    )
  }
  A = Matrix::sparseMatrix(
    i = triplets$i, j = triplets$j, x = triplets$x,
    dims = c(index$equation_count, index$endogenous_count),
    repr = "C"
  )
  list(A = A, rhs = rhs, index = index, nnz = length(triplets$x))
}

sparse_vectorized_expr_supported = function(expr) {
  if (is.null(expr) || is.name(expr) ||
      (!is.language(expr) && length(expr) == 1L)) return(TRUE)
  if (!is.language(expr) || length(expr) == 0L) return(TRUE)
  op = tolower(as.character(expr[[1]]))
  supported = c(
    "[", "(", "sum", "setpos", "isin", "ifelse", "!", "+", "-", "*", "/", "^",
    "==", "!=", "<", ">", "<=", ">=", "&", "|",
    "exp", "loge", "log", "sqrt", "abs"
  )
  if (!(op %in% supported) &&
      (!grepl("^[A-Za-z][A-Za-z0-9_.]*$", op) || length(expr) < 2L)) {
    return(FALSE)
  }
  if (length(expr) <= 1L) return(TRUE)
  all(vapply(as.list(expr)[-1L], sparse_vectorized_expr_supported,
             logical(1)))
}

sparse_vectorized_bindings = function(domains, index) {
  if (!length(domains)) return(list(bindings = list(), n = 1L))
  lengths = vapply(domains, function(domain) {
    length(index$sets[[domain$set]]$values)
  }, integer(1))
  n = as.numeric(prod(lengths))
  bindings = list()
  for (d in seq_along(domains)) {
    before = if (d == 1L) 1 else prod(lengths[seq_len(d - 1L)])
    after = if (d == length(domains)) 1 else
      prod(lengths[(d + 1L):length(domains)])
    values = rep(
      rep(seq_len(lengths[[d]]), each = after),
      times = before
    )
    bindings[[domains[[d]]$index]] = values
    bindings[[paste0(".set:", domains[[d]]$index)]] =
      domains[[d]]$set
  }
  list(bindings = bindings, n = n)
}

sparse_vectorized_index_value = function(expr, bindings, state, index, n) {
  if (is.name(expr) && !is.null(bindings[[as.character(expr)]])) {
    return(rep(bindings[[as.character(expr)]], length.out = n))
  }
  if (is.character(expr) && length(expr) == 1L &&
      !is.null(bindings[[expr]])) {
    return(rep(bindings[[expr]], length.out = n))
  }
  if (!is.language(expr)) return(rep(expr, length.out = n))
  sparse_eval_expr_vectorized(expr, state, bindings, index, n)
}

sparse_vectorized_positions = function(value, dimension, dim_names = NULL,
                                       set_name = NULL, source_set = NULL,
                                       index, n) {
  value = rep(value, length.out = n)
  if (!is.null(source_set) && !is.null(set_name) &&
      !identical(source_set, set_name) &&
      !is.null(index$sets[[source_set]]) &&
      !is.null(index$sets[[set_name]])) {
    source_values = index$sets[[source_set]]$values
    source_numeric = suppressWarnings(as.numeric(value))
    source_positions = suppressWarnings(as.integer(value))
    source_valid = !is.na(source_positions) &
      !is.na(source_numeric) & source_numeric == source_positions &
      source_positions >= 1L & source_positions <= length(source_values)
    if (any(source_valid)) {
      value[source_valid] = source_values[source_positions[source_valid]]
    }
  }
  numeric_value = suppressWarnings(as.numeric(value))
  positions = suppressWarnings(as.integer(value))
  valid = !is.na(positions) & !is.na(numeric_value) &
    numeric_value == positions &
    positions >= 1L & positions <= dimension
  if (any(!valid)) {
    lookup = NULL
    if (!is.null(dim_names)) {
      lookup = dim_names
    } else if (!is.null(set_name) && !is.null(index$sets[[set_name]])) {
      lookup = index$sets[[set_name]]$values
    }
    if (!is.null(lookup)) {
      positions[!valid] = match(as.character(value[!valid]), lookup)
    }
  }
  as.integer(positions)
}

sparse_eval_expr_vectorized = function(expr, state, bindings, index, n = NULL) {
  if (is.null(n)) {
    n = if (length(bindings)) {
      max(vapply(bindings, length, integer(1)))
    } else 1L
  }
  if (is.null(expr)) return(rep(NA_real_, n))
  if (is.name(expr)) {
    name = as.character(expr)
    if (!is.null(bindings[[name]])) {
      return(rep(bindings[[name]], length.out = n))
    }
    data = if (!is.null(state)) sparse_state_data(state)[[tolower(name)]] else NULL
    if (is.null(data)) return(rep(name, n))
    data = sparse_implicit_exogenous_zero(data, name, index)
    return(rep(as.numeric(data), length.out = n))
  }
  if (!is.language(expr)) return(rep(expr, length.out = n))
  if (length(expr) == 0L) return(rep(NA_real_, n))

  op = tolower(as.character(expr[[1]]))
  if (!(op %in% c(
    "[", "(", "sum", "setpos", "isin", "ifelse", "!",
    "+", "-", "*", "/", "^", "==", "!=", "<", ">",
    "<=", ">=", "&", "|", "exp", "loge", "log", "sqrt", "abs"
  )) && !is.null(sparse_state_data(state)[[op]])) {
    ref = as.call(c(
      list(as.name("["), as.name(op)),
      as.list(expr)[-1L]
    ))
    return(sparse_eval_expr_vectorized(ref, state, bindings, index, n))
  }
  if (op == "[") {
    ref = sparse_parse_ref(expr)
    data = sparse_state_data(state)[[ref$name]]
    if (is.null(data)) {
      stop(sprintf("Data array %s is missing", ref$name), call. = FALSE)
    }
    dims = dim(data)
    if (is.null(dims) || !length(ref$indices)) {
      data = sparse_implicit_exogenous_zero(data, ref$name, index)
      return(rep(as.numeric(data), length.out = n))
    }
    if (length(ref$indices) != length(dims)) {
      stop(sprintf("Data array %s expects %s indices, got %s",
                   ref$name, length(dims), length(ref$indices)),
           call. = FALSE)
    }
    data_dim_names = dimnames(data)
    positions = lapply(seq_along(dims), function(d) {
      value = sparse_vectorized_index_value(
        ref$indices[[d]], bindings, state, index, n
      )
      dim_names = if (!is.null(data_dim_names) &&
                     d <= length(data_dim_names)) {
        data_dim_names[[d]]
      } else NULL
      set_name = if (!is.null(data_dim_names) &&
                     !is.null(names(data_dim_names)) &&
                     d <= length(names(data_dim_names))) {
        names(data_dim_names)[[d]]
      } else NULL
      source_set = bindings[[paste0(".set:", as.character(ref$indices[[d]]))]]
      sparse_vectorized_positions(
        value, dims[[d]], dim_names, set_name, source_set, index, n
      )
    })
    linear = rep(1, n)
    stride = 1
    for (d in seq_along(dims)) {
      linear = linear + (positions[[d]] - 1) * stride
      stride = stride * dims[[d]]
    }
    value = as.numeric(data)[linear]
    return(sparse_implicit_exogenous_zero(value, ref$name, index))
  }
  if (op == "(" && length(expr) >= 2L) {
    return(sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    ))
  }


  if (op == "setpos" && length(expr) >= 2L) {
    value = sparse_vectorized_index_value(
      expr[[2]], bindings, state, index, n
    )
    source_name = bindings[[paste0(".set:", as.character(expr[[2]]))]]
    if (is.numeric(value) && !is.null(source_name) &&
        !is.null(index$sets[[source_name]])) {
      source_values = index$sets[[source_name]]$values
      labels = source_values[as.integer(value)]
      result = rep(NA_real_, n)
      candidates = names(index$sets)
      candidates = c(setdiff(candidates, source_name), source_name)
      for (candidate in candidates) {
        positions = match(labels, index$sets[[candidate]]$values)
        take = is.na(result) & !is.na(positions)
        result[take] = positions[take]
      }
      return(result)
    }
    return(as.numeric(value))
  }

  if (op == "isin" && length(expr) >= 3L) {
    value = sparse_vectorized_index_value(
      expr[[2]], bindings, state, index, n
    )
    set_name = tolower(as.character(expr[[3]]))
    set = index$sets[[set_name]]
    if (is.null(set)) {
      stop(sprintf("Unknown membership set %s", set_name), call. = FALSE)
    }
    source_name = bindings[[paste0(".set:", as.character(expr[[2]]))]]
    if (is.numeric(value) && !is.null(source_name) &&
        !is.null(index$sets[[source_name]])) {
      value = index$sets[[source_name]]$values[as.integer(value)]
    }
    return(as.character(value) %in% as.character(set$values))
  }

  if (op == "sum" && length(expr) >= 4L) {
    set_name = tolower(as.character(expr[[3]]))
    set = index$sets[[set_name]]
    if (is.null(set)) {
      stop(sprintf("Unknown sum set %s", set_name), call. = FALSE)
    }
    set_size = length(set$values)
    if (!set_size) return(numeric(n))
    index_name = as.character(expr[[2]])
    expanded_n = as.numeric(n) * set_size
    if (!is.finite(expanded_n) || expanded_n > .Machine$integer.max) {
      stop("Sparse vectorized sum exceeds R vector length limit",
           call. = FALSE)
    }
    vector_limit = getOption("GEModelR.sparse.sum_vectorized_limit", 1e6)
    if (!is.numeric(vector_limit) || length(vector_limit) != 1L ||
        !is.finite(vector_limit) || vector_limit < 1) {
      stop("GEModelR.sparse.sum_vectorized_limit must be positive",
           call. = FALSE)
    }
    if (expanded_n > vector_limit) {
      sum_value = numeric(n)
      for (position in seq_len(set_size)) {
        next_bindings = bindings
        next_bindings[[index_name]] = rep(position, n)
        next_bindings[[paste0(".set:", index_name)]] = set_name
        term_value = sparse_eval_expr_vectorized(
          expr[[4]], state, next_bindings, index, n
        )
        sum_value = sum_value +
          rep(as.numeric(term_value), length.out = n)
      }
      return(sum_value)
    }
    next_bindings = lapply(names(bindings), function(name) {
      value = bindings[[name]]
      if (startsWith(name, ".set:")) value else
        rep(rep(value, length.out = n), times = set_size)
    })
    names(next_bindings) = names(bindings)
    next_bindings[[index_name]] = rep(seq_len(set_size), each = n)
    next_bindings[[paste0(".set:", index_name)]] = set_name
    term_value = sparse_eval_expr_vectorized(
      expr[[4]], state, next_bindings, index, expanded_n
    )
    term_value = rep(as.numeric(term_value), length.out = expanded_n)
    dim(term_value) = c(n, set_size)
    return(rowSums(term_value))
  }

  if (op == "ifelse") {
    condition = sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    )
    yes = sparse_eval_expr_vectorized(expr[[3]], state, bindings, index, n)
    no = if (length(expr) >= 4L) {
      sparse_eval_expr_vectorized(expr[[4]], state, bindings, index, n)
    } else 0
    return(ifelse(condition, yes, no))
  }

  if (op == "!") {
    return(!sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    ))
  }

  if (op %in% c("+", "-", "*", "/", "^", "==", "!=", "<", ">",
                "<=", ">=", "&", "|")) {
    args = lapply(as.list(expr)[-1L], sparse_eval_expr_vectorized,
                  state = state, bindings = bindings, index = index, n = n)
    if (op == "-" && length(args) == 1L) return(-args[[1]])
    if (op == "/" && length(args) == 2L) {
      return(ifelse(args[[2]] == 0, 0, args[[1]] / args[[2]]))
    }
    return(do.call(op, args))
  }

  if (op %in% c("exp", "loge", "log", "sqrt", "abs")) {
    value = sparse_eval_expr_vectorized(
      expr[[2]], state, bindings, index, n
    )
    if (op == "loge") op = "log"
    return(get(op)(value))
  }

  stop(sprintf("Unsupported sparse expression operator: %s", op),
       call. = FALSE)
}

sparse_vectorized_ref_positions = function(ref, bindings, state, index, n) {
  id = index$variable_by_name[[ref$name]]
  if (is.null(id)) {
    stop(sprintf("Unknown variable in sparse expression: %s", ref$name),
         call. = FALSE)
  }
  variable = index$variables[[id]]
  if (!length(variable$sets)) return(rep(variable$global_start, n))
  if (length(ref$indices) != length(variable$sets)) {
    stop(sprintf("Variable %s expects %s indices, got %s",
                 ref$name, length(variable$sets), length(ref$indices)),
         call. = FALSE)
  }
  positions = lapply(seq_along(variable$sets), function(d) {
    value = sparse_vectorized_index_value(
      ref$indices[[d]], bindings, state, index, n
    )
    sparse_vectorized_positions(
      value, variable$lengths[[d]], set_name = variable$sets[[d]],
      source_set = bindings[[paste0(".set:",
                                      as.character(ref$indices[[d]]))]],
      index = index, n = n
    )
  })
  linear = rep(1, n)
  stride = 1
  for (d in seq_along(positions)) {
    linear = linear + (positions[[d]] - 1) * stride
    stride = stride * variable$lengths[[d]]
  }
  as.numeric(variable$global_start) + linear - 1
}

sparse_emit_system_vectorized = function(state, index, shocks) {
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(NULL, index, state)
  }
  supported = all(vapply(index$equations, function(equation) {
    all(vapply(equation$domains, function(domain) {
      is.null(domain$predicate)
    }, logical(1))) &&
      all(vapply(equation$terms, function(term) {
        sparse_vectorized_expr_supported(term$coefficient) &&
          all(vapply(term$guards, sparse_vectorized_expr_supported,
                     logical(1)))
      }, logical(1)))
  }, logical(1)))
  if (!supported) return(sparse_emit_system_scalar(state, index, shocks))

  capacity = sparse_triplet_capacity(index)
  raw_i = if (capacity) integer(capacity) else integer()
  raw_j = if (capacity) integer(capacity) else integer()
  raw_x = if (capacity) numeric(capacity) else numeric()
  raw_count = 0L
  inverse_order = if (length(index$column_order)) {
    inverse = integer(index$endogenous_count)
    inverse[index$column_order] = seq_along(index$column_order)
    inverse
  } else integer()
  rhs = numeric(index$equation_count)
  shock_positions = shocks$positions
  shock_values = shocks$values

  append_term = function(row_number, variable_position, value) {
    count = length(value)
    if (!count) return(invisible(NULL))
    start = raw_count + 1
    end = raw_count + count
    if (end > length(raw_i)) {
      growth = max(1024, end - length(raw_i), length(raw_i))
      raw_i <<- c(raw_i, integer(growth))
      raw_j <<- c(raw_j, integer(growth))
      raw_x <<- c(raw_x, numeric(growth))
    }
    raw_i[start:end] <<- as.integer(row_number)
    raw_j[start:end] <<- if (length(inverse_order)) {
      inverse_order[as.integer(variable_position)]
    } else as.integer(variable_position)
    raw_x[start:end] <<- as.numeric(value)
    raw_count <<- end
    invisible(NULL)
  }

  for (equation in index$equations) {
    for (term in equation$terms) {
      all_domains = c(
        equation$domains,
        lapply(term$sums, function(sum_spec) {
          list(index = sum_spec$index, set = sum_spec$set,
               predicate = NULL)
        })
      )
      vectorized = sparse_vectorized_bindings(all_domains, index)
      bindings = vectorized$bindings
      n = vectorized$n
      rows = if (length(term$sums)) {
        sum_multiplier = prod(vapply(term$sums, function(sum_spec) {
          length(index$sets[[sum_spec$set]]$values)
        }, numeric(1)))
        rep(seq.int(equation$row_start, equation$row_end),
            each = sum_multiplier)
      } else {
        seq.int(equation$row_start, equation$row_end)
      }
      value = sparse_eval_expr_vectorized(
        term$coefficient, state, bindings, index, n
      )
      value = rep(value, length.out = n)
      guard_ok = rep(TRUE, n)
      if (length(term$guards)) {
        for (guard in term$guards) {
          valid = as.logical(sparse_eval_expr_vectorized(
            guard, state, bindings, index, n
          ))
          valid = rep(valid, length.out = n)
          valid[is.na(valid)] = FALSE
          guard_ok = guard_ok & valid
        }
        value[!guard_ok] = 0
      }
      invalid = guard_ok & !is.finite(value)
      if (any(invalid)) {
        position = which(invalid)[[1L]]
        stop(sprintf(
          "Sparse coefficient for %s -> %s is not finite at position %s",
          equation$name, term$ref$name, position
        ), call. = FALSE)
      }
      value[!guard_ok] = 0
      ref_position = sparse_vectorized_ref_positions(
        term$ref, bindings, state, index, n
      )
      if (anyNA(rows) || any(guard_ok & is.na(ref_position))) {
        missing = which(is.na(rows) |
                        (guard_ok & is.na(ref_position)))[1L]
        stop(sprintf(
          "Sparse vectorized index failure in %s -> %s at position %s",
          equation$name, term$ref$name, missing
        ), call. = FALSE)
      }
      variable = index$variables[[index$variable_by_name[[term$ref$name]]]]
      if (isTRUE(variable$exogenous)) {
        hit = match(ref_position, shock_positions, nomatch = 0L)
        active = guard_ok & !is.na(hit) & hit > 0L
        if (any(active)) {
          contribution = sparse_aggregate_triplets(
            rows[active], rows[active],
            value[active] * shock_values[hit[active]]
          )
          rhs[contribution$i] <- rhs[contribution$i] -
            contribution$x
        }
      } else {
        append_term(
          rows[guard_ok],
          variable$endo_start + ref_position[guard_ok] -
            variable$global_start,
          value[guard_ok]
        )
      }
    }
  }
  if (raw_count) {
    raw_i = raw_i[seq_len(raw_count)]
    raw_j = raw_j[seq_len(raw_count)]
    raw_x = raw_x[seq_len(raw_count)]
  }
  triplets = sparse_aggregate_triplets(raw_i, raw_j, raw_x)
  if (any(!is.finite(rhs))) {
    stop("Sparse emission produced a non-finite right-hand side", call. = FALSE)
  }
  key = sparse_pattern_key(index)
  cached = index$pattern_cache
  if (!is.null(cached) && identical(cached$key, key) &&
      length(cached$i) == length(triplets$i) &&
      identical(cached$i, triplets$i) &&
      identical(cached$j, triplets$j)) {
    triplets$i = cached$i
    triplets$j = cached$j
  } else {
    index$pattern_cache = list(
      key = key, i = triplets$i, j = triplets$j,
      raw_count = raw_count, nnz = length(triplets$x)
    )
  }
  A = Matrix::sparseMatrix(
    i = triplets$i, j = triplets$j, x = triplets$x,
    dims = c(index$equation_count, index$endogenous_count),
    repr = "C"
  )
  list(A = A, rhs = rhs, index = index, nnz = length(triplets$x))
}

sparse_emit_system = function(state, index, shocks) {
  if (isTRUE(getOption("GEModelR.sparse.vectorized", TRUE))) {
    return(sparse_emit_system_vectorized(state, index, shocks))
  }
  sparse_emit_system_scalar(state, index, shocks)
}
sparse_lhs_column_order = function(index, state) {
  n = as.integer(index$endogenous_count)
  if (!n || index$equation_count != n ||
      !isTRUE(index$row_layout_ready)) {
    return(NULL)
  }
  if (!is.null(index$column_order) &&
      length(index$column_order) == n &&
      !anyNA(index$column_order)) {
    return(as.integer(index$column_order))
  }

  # TABLO often orders equations by economic identity rather than by the
  # variable columns.  Use left-hand-side variables as cheap structural pivots
  # before SuperLU chooses its fill-reducing ordering.  Composite left sides
  # and repeated identities are handled as a partial matching; the remaining
  # rows receive the remaining columns so this is always a permutation.
  column_order = rep(NA_integer_, n)
  used = rep(FALSE, n)
  for (equation in index$equations) {
    if (any(vapply(equation$domains, function(domain) {
      !is.null(domain$predicate)
    }, logical(1)))) {
      return(NULL)
    }
    rows = seq.int(equation$row_start, equation$row_end)
    candidates = equation$lhs_terms
    if (is.null(candidates) || !length(candidates)) {
      candidates = if (length(equation$terms)) {
        equation$terms[1L]
      } else list()
    }
    if (!length(candidates)) next
    vectorized = sparse_vectorized_bindings(equation$domains, index)
    mapped = lapply(candidates, function(term) {
      id = index$variable_by_name[[term$ref$name]]
      if (is.null(id)) return(rep(NA_integer_, length(rows)))
      variable = index$variables[[id]]
      if (isTRUE(variable$exogenous)) {
        return(rep(NA_integer_, length(rows)))
      }
      global = sparse_vectorized_ref_positions(
        term$ref, vectorized$bindings, state, index, vectorized$n
      )
      local = global - variable$global_start + 1
      result = rep(NA_integer_, length(global))
      valid = !is.na(local) &
        local == as.integer(local) &
        local >= 1 & local <= variable$n
      result[valid] = as.integer(variable$endo_start + local[valid] - 1L)
      result
    })
    scores = vapply(mapped, function(candidate) {
      valid = !is.na(candidate) & candidate >= 1L & candidate <= n
      if (!any(valid)) return(0L)
      unique_candidate = candidate[valid][!duplicated(candidate[valid])]
      as.integer(sum(!used[unique_candidate]))
    }, integer(1))
    if (!length(scores) || max(scores) == 0L) next
    candidate = mapped[[which.max(scores)]]
    valid = !is.na(candidate) & candidate >= 1L & candidate <= n
    take = rep(FALSE, length(candidate))
    if (any(valid)) {
      valid_rows = which(valid)
      take[valid_rows] = !duplicated(candidate[valid_rows]) &
        !used[candidate[valid_rows]]
    }
    if (any(take)) {
      column_order[rows[take]] = candidate[take]
      used[candidate[take]] = TRUE
    }
  }
  unmatched_rows = which(is.na(column_order))
  remaining_columns = which(!used)
  if (length(unmatched_rows) != length(remaining_columns)) return(NULL)
  column_order[unmatched_rows] = remaining_columns
  if (anyNA(column_order) || anyDuplicated(column_order)) return(NULL)
  as.integer(column_order)
}
sparse_as_sparsem_csr = function(A) {
  if (!requireNamespace("SparseM", quietly = TRUE)) {
    stop("backend='SparseM' requires the SparseM package", call. = FALSE)
  }
  entries = Matrix::summary(A)
  keep = !is.na(entries$x) & entries$x != 0
  entries$i = as.integer(entries$i[keep])
  entries$j = as.integer(entries$j[keep])
  entries$x = as.numeric(entries$x[keep])
  counts = tabulate(entries$i, nbins = nrow(A))
  methods::new(
    "matrix.csr",
    ra = entries$x,
    ja = entries$j,
    ia = as.integer(c(1L, 1L + cumsum(counts))),
    dimension = as.integer(dim(A))
  )
}
solve_sparse_system = function(A, rhs, backend = "Matrix",
                               reduction = c("auto", "off", "on")) {
  backend = match.arg(backend, c("Matrix", "SuiteSparse", "SparseM"))
  reduction = match.arg(reduction)
  if (!inherits(A, "sparseMatrix")) {
    stop("Sparse solver received a non-sparse coefficient matrix", call. = FALSE)
  }
  if (nrow(A) != ncol(A)) {
    stop(sprintf("Sparse system is not square: %s x %s", nrow(A), ncol(A)),
         call. = FALSE)
  }
  rhs = as.numeric(rhs)
  if (length(rhs) != nrow(A) || anyNA(rhs) || any(!is.finite(rhs))) {
    stop("Sparse system received an invalid right-hand side", call. = FALSE)
  }
  if (backend == "Matrix") {
    .identity_guard_old_options("tabloToR.sparse.lu_order")
  }
  if (!any(rhs != 0)) return(numeric(ncol(A)))
  if (backend == "Matrix") {
    lu_order = getOption("GEModelR.sparse.lu_order", 3L)
    lu_order = suppressWarnings(as.integer(lu_order)[1L])
    if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
      stop("GEModelR.sparse.lu_order must be an integer from 0 to 3",
           call. = FALSE)
    }
  }
  reduced = if (reduction == "off") {
    list(A = A, rhs = rhs, stages = list())
  } else {
    sparse_reduce_system(A, rhs)
  }
  if (!nrow(reduced$A)) {
    reduced_solution = numeric()
  } else if (backend == "Matrix") {
    factor = tryCatch(
      Matrix::lu(Matrix::drop0(reduced$A), order = lu_order),
      error = function(error) {
        stop(sprintf(
          paste(
            "Sparse LU factorization failed (ordering %s): %s.",
            "Try a different fill-reducing ordering with",
            "options(GEModelR.sparse.lu_order = 1L/2L/3L),",
            "or reduce the model before factorization."
          ),
          lu_order, conditionMessage(error)
        ), call. = FALSE)
      }
    )
    reduced_solution = as.numeric(Matrix::solve(factor, reduced$rhs))
  } else if (backend == "SuiteSparse") {
    reduced_solution = sparse_suite_sparse_solver(
      reduced$A, reduced$rhs
    )
  } else {
    csr = sparse_as_sparsem_csr(reduced$A)
    reduced_solution = as.numeric(SparseM::solve(csr, reduced$rhs))
  }
  if (length(reduced$stages)) {
    for (stage in rev(reduced$stages)) {
      stage_solution = numeric(length(stage$keep) +
                                 length(stage$eliminated$columns))
      if (length(stage$keep)) {
        stage_solution[stage$keep] = reduced_solution
      }
      if (length(stage$eliminated$columns)) {
        matrix = stage$eliminated$matrix
        contribution = if (!is.null(matrix) && nrow(matrix) &&
                            ncol(matrix)) {
          as.numeric(matrix %*% reduced_solution)
        } else numeric(length(stage$eliminated$columns))
        stage_solution[stage$eliminated$columns] = (
          stage$eliminated$rhs - contribution
        ) / stage$eliminated$pivots
      }
      reduced_solution = stage_solution
    }
  }
  reduced_solution
}
sparse_true_residual = function(A, solution, rhs) {
  if (!inherits(A, "sparseMatrix")) {
    stop("Residual check received a non-sparse coefficient matrix", call. = FALSE)
  }
  solution = as.numeric(solution)
  rhs = as.numeric(rhs)
  if (length(solution) != ncol(A) || length(rhs) != nrow(A)) {
    stop("Residual check received vectors with incompatible dimensions",
         call. = FALSE)
  }
  if (any(!is.finite(solution)) || any(!is.finite(rhs))) {
    stop("Residual check received non-finite values", call. = FALSE)
  }
  lhs = as.numeric(A %*% solution)
  if (any(!is.finite(lhs))) {
    stop("Residual check produced non-finite A %*% solution values",
         call. = FALSE)
  }
  residual = lhs - rhs
  if (any(!is.finite(residual))) {
    stop("Residual check produced non-finite residual values", call. = FALSE)
  }
  scaled_l2 = function(values) {
    if (!length(values)) return(0)
    scale = max(abs(values))
    if (scale == 0) return(0)
    scale * sqrt(sum((values / scale) * (values / scale)))
  }
  residual_norm = scaled_l2(residual)
  rhs_norm = scaled_l2(rhs)
  result = list(
    infinity_norm = if (length(residual)) max(abs(residual)) else 0,
    l2_norm = residual_norm,
    relative_l2 = residual_norm / max(1, rhs_norm)
  )
  rm(lhs, residual)
  result
}

.sparse_accept_candidate = function(
    candidate,
    expected_structure = NULL,
    reference = NULL,
    solution_atol = 0,
    solution_rtol = 0,
    residual_tolerance = 2e-7,
    diagnostics = FALSE) {
  required = c("backend", "solution", "coefficient_matrix", "rhs")
  missing_fields = setdiff(required, names(candidate))
  if (!is.list(candidate) || length(missing_fields)) {
    stop(sprintf(
      "Sparse candidate is missing field(s): %s",
      paste(missing_fields, collapse = ", ")
    ), call. = FALSE)
  }
  coefficient_matrix = candidate$coefficient_matrix
  if (!inherits(coefficient_matrix, "sparseMatrix")) {
    stop("Sparse candidate coefficient matrix must remain sparse",
         call. = FALSE)
  }
  solution_structure = .sparse_value_structure(candidate$solution)
  if (!is.null(candidate$output_structure) &&
      !identical(candidate$output_structure, solution_structure)) {
    stop("Sparse candidate output structure metadata is inconsistent",
         call. = FALSE)
  }
  if (!is.null(expected_structure) &&
      !identical(solution_structure, expected_structure)) {
    stop("Sparse candidate output structure does not match the contract",
         call. = FALSE)
  }
  finite = all(is.finite(candidate$solution)) &&
    all(is.finite(candidate$rhs)) &&
    all(is.finite(coefficient_matrix@x))
  if (!finite) {
    stop("Sparse candidate contains non-finite values; the solution was not applied.",
         call. = FALSE)
  }
  tolerance_values = c(solution_atol, solution_rtol, residual_tolerance)
  if (length(tolerance_values) != 3L ||
      any(!is.finite(tolerance_values)) || any(tolerance_values < 0)) {
    stop("Sparse candidate tolerances must be finite non-negative scalars",
         call. = FALSE)
  }
  if (!is.null(reference)) {
    reference_structure = .sparse_value_structure(reference)
    if (!identical(solution_structure, reference_structure)) {
      stop("Sparse candidate and authority structures differ",
           call. = FALSE)
    }
    if (any(!is.finite(reference))) {
      stop("Sparse candidate authority contains non-finite values",
           call. = FALSE)
    }
    difference = abs(candidate$solution - reference)
    limit = solution_atol + solution_rtol *
      pmax(abs(reference), abs(candidate$solution))
    if (any(difference > limit)) {
      stop("Sparse candidate differs from its numerical authority",
           call. = FALSE)
    }
  }
  true_residual = sparse_true_residual(
    coefficient_matrix, candidate$solution, candidate$rhs
  )
  residual_metrics = unlist(true_residual, use.names = FALSE)
  if (length(residual_metrics) != 3L ||
      any(!is.finite(residual_metrics))) {
    stop(paste(
      "Sparse candidate true residual metrics are non-finite;",
      "the solution was not applied."
    ), call. = FALSE)
  }
  if (true_residual$relative_l2 > residual_tolerance) {
    stop(sprintf(
      paste(
        "Sparse candidate true residual %.3e exceeds tolerance %.3e;",
        "the solution was not applied."
      ),
      true_residual$relative_l2, residual_tolerance
    ), call. = FALSE)
  }
  candidate$output_structure = solution_structure
  candidate$finite = finite
  candidate$true_residual = true_residual
  candidate$accepted = TRUE
  candidate$retained_diagnostics = if (isTRUE(diagnostics)) {
    list(
      backend = candidate$backend,
      finite = finite,
      output_structure = solution_structure,
      true_residual = true_residual
    )
  } else NULL
  candidate
}

.sparse_accept_candidate_reference = .sparse_accept_candidate
.sparse_accept_candidate = function(
    candidate,
    expected_structure = NULL,
    reference = NULL,
    solution_atol = 0,
    solution_rtol = 0,
    residual_tolerance = 2e-7,
    diagnostics = FALSE) {
  tryCatch(
    .sparse_accept_candidate_reference(
      candidate, expected_structure, reference, solution_atol,
      solution_rtol, residual_tolerance, diagnostics
    ),
    error = function(error) {
      requested_backend = if (is.list(candidate)) {
        candidate$requested_backend
      } else NULL
      if (is.null(requested_backend) && is.list(candidate)) {
        requested_backend = candidate$backend
      }
      stop(.gemodelr_solve_condition(
        error, "sparse", requested_backend,
        primary_class = "GEModelR_numerical_error",
        failure_phase = "candidate-acceptance",
        accepted_numerical_state = FALSE,
        retryable_postsim = FALSE,
        remediation = list(
          action = "Review the candidate solution and its residual evidence"
        )
      ))
    }
  )
}


sparse_reduce_system = function(A, rhs) {
  if (length(A@x) && any(!is.finite(A@x) | A@x == 0)) {
    A = Matrix::drop0(A)
  }
  stages = list()
  current_A = A
  current_rhs = as.numeric(rhs)
  A = NULL

  repeat {
    # A row singleton directly solves its only variable.  Substitute that
    # value into the other rows before removing the row and column.
    row_count = tabulate(current_A@i + 1L, nbins = nrow(current_A))
    singleton_entries = which(row_count[current_A@i + 1L] == 1L)
    if (length(singleton_entries)) {
      singleton_columns = findInterval(singleton_entries - 1L, current_A@p)
      singleton_column_count = tabulate(
        singleton_columns, nbins = ncol(current_A)
      )
      take = singleton_column_count[singleton_columns] == 1L &
        is.finite(current_A@x[singleton_entries]) &
        current_A@x[singleton_entries] != 0
      if (any(take)) {
        eliminate_entries = singleton_entries[take]
        eliminate_rows = as.integer(current_A@i[eliminate_entries] + 1L)
        eliminate_columns = as.integer(singleton_columns[take])
        pivots = as.numeric(current_A@x[eliminate_entries])
        keep_rows = setdiff(seq_len(nrow(current_A)), eliminate_rows)
        keep_columns = setdiff(seq_len(ncol(current_A)), eliminate_columns)
        eliminated_values = current_rhs[eliminate_rows] / pivots
        next_rhs = current_rhs[keep_rows]
        cross = current_A[
          keep_rows, eliminate_columns, drop = FALSE
        ] %*% eliminated_values
        next_rhs = next_rhs - as.numeric(cross)
        stages[[length(stages) + 1L]] = list(
          keep = keep_columns,
          eliminated = list(
            columns = eliminate_columns,
            pivots = pivots,
            rhs = current_rhs[eliminate_rows],
            matrix = NULL
          )
        )
        current_A = current_A[keep_rows, keep_columns, drop = FALSE]
        current_rhs = next_rhs
        next
      }
    }

    column_count = diff(current_A@p)
    candidate_columns = which(column_count == 1L)
    if (!length(candidate_columns)) break

    # A column singleton can be solved from its only row.  It is safe to
    # remove that row and column only when the row has no second singleton;
    # otherwise removing the row would strand the other singleton column.
    entry = current_A@p[candidate_columns] + 1L
    candidate_rows = current_A@i[entry] + 1L
    singleton_count = tabulate(
      candidate_rows, nbins = nrow(current_A)
    )
    take = singleton_count[candidate_rows] == 1L &
      is.finite(current_A@x[entry]) & current_A@x[entry] != 0
    if (!any(take)) break

    eliminate_columns = as.integer(candidate_columns[take])
    eliminate_rows = as.integer(candidate_rows[take])
    pivots = as.numeric(current_A@x[entry[take]])
    keep_rows = setdiff(seq_len(nrow(current_A)), eliminate_rows)
    keep_columns = setdiff(seq_len(ncol(current_A)), eliminate_columns)

    # Keep the non-pivot coefficients needed to reconstruct each eliminated
    # variable after the reduced solve.  Both matrices remain sparse.
    reconstruction = current_A[
      eliminate_rows, keep_columns, drop = FALSE
    ]
    stages[[length(stages) + 1L]] = list(
      keep = keep_columns,
      eliminated = list(
        columns = eliminate_columns,
        pivots = pivots,
        rhs = current_rhs[eliminate_rows],
        matrix = reconstruction
      )
    )

    current_A = current_A[keep_rows, keep_columns, drop = FALSE]
    current_rhs = current_rhs[keep_rows]
  }

  list(A = current_A, rhs = current_rhs, stages = stages)
}

sparse_apply_solution = function(state, index, solution) {
  data = sparse_state_data(state)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous)) next
    values = solution[seq.int(variable$endo_start,
                              length.out = variable$n)]
    array = data[[variable$name]]
    if (is.null(array)) next
    if (length(array) == length(values)) {
      array[] = values
      data[[variable$name]] = array
    }
  }
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_set_global_value = function(state, index, global_position, value) {
  for (variable in index$variables) {
    if (global_position < variable$global_start ||
        global_position > variable$global_end) next
    local = global_position - variable$global_start + 1L
    data = sparse_state_data(state)
    array = data[[variable$name]]
    if (!is.null(array)) {
      array[[local]] = value
      data[[variable$name]] = array
      if (is.environment(state)) state$data = data
    }
    return(invisible(NULL))
  }
  stop(sprintf("Unknown global variable position %s", global_position),
       call. = FALSE)
}

sparse_apply_shocks = function(state, index, shocks) {
  if (length(shocks$positions)) {
    for (i in seq_along(shocks$positions)) {
      sparse_set_global_value(
        state, index, shocks$positions[[i]], shocks$values[[i]]
      )
    }
  }
  invisible(NULL)
}

sparse_apply_updates = function(state, index, spec, updates = NULL) {
  if (is.null(spec)) return(invisible(NULL))
  if (is.null(updates)) updates = spec$updates
  if (!length(updates)) return(invisible(NULL))
  for (update_id in seq_along(updates)) {
    update = updates[[update_id]]
    sparse_initialize_update_target(update, state, index)
    vectorized = tryCatch(
      sparse_apply_update_vectorized(update, state, index),
      error = function(error) FALSE
    )
    result = if (isTRUE(vectorized)) {
      NULL
    } else tryCatch({
      sparse_for_each_domain(
        update$domains, state, index, callback = function(bindings) {
          value = sparse_eval_expr(
            update$expression, state, bindings, index
          )
          sparse_set_data_ref(
            update$target, state, bindings, index, value
          )
        }
      )
      NULL
    }, error = function(error) error)
    if (inherits(result, "error")) {
      stop(sprintf(
        "Sparse update %s (%s) failed: %s",
        update_id, update$target$name, conditionMessage(result)
      ), call. = FALSE)
    }
  }
  invisible(NULL)
}

sparse_checkpoint_state = function(state, index, spec) {
  updates = if (!is.null(spec$simulation_updates)) {
    spec$simulation_updates
  } else spec$updates
  names_to_save = unique(c(
    vapply(index$variables, function(x) x$name, character(1)),
    vapply(updates, function(x) x$target$name, character(1))
  ))
  names_to_save = intersect(names_to_save, names(sparse_state_data(state)))
  list(
    names = names_to_save,
    values = lapply(names_to_save, function(name) sparse_state_data(state)[[name]])
  )
}

sparse_restore_checkpoint = function(state, checkpoint) {
  data = sparse_state_data(state)
  for (i in seq_along(checkpoint$names)) {
    data[[checkpoint$names[[i]]]] = checkpoint$values[[i]]
  }
  if (is.environment(state)) state$data = data
  invisible(NULL)
}

sparse_apply_update_vectorized = function(update, state, index) {
  domains = update$domains
  if (!sparse_vectorized_expr_supported(update$expression)) return(FALSE)
  if (any(vapply(domains, function(domain) {
    !is.null(domain$predicate) &&
      !sparse_vectorized_expr_supported(domain$predicate)
  }, logical(1)))) {
    return(FALSE)
  }

  lengths = if (length(domains)) {
    vapply(domains, function(domain) {
      length(index$sets[[domain$set]]$values)
    }, integer(1))
  } else integer()
  n = if (length(lengths)) as.numeric(prod(lengths)) else 1
  vectorized = sparse_vectorized_bindings(domains, index)
  value = sparse_eval_expr_vectorized(
    update$expression, state, vectorized$bindings, index, n
  )
  value = rep(as.numeric(value), length.out = n)
  active = rep(TRUE, n)
  for (domain in domains) {
    if (!is.null(domain$predicate)) {
      predicate = sparse_eval_expr_vectorized(
        domain$predicate, state, vectorized$bindings, index, n
      )
      predicate = rep(as.logical(predicate), length.out = n)
      predicate[is.na(predicate)] = FALSE
      active = active & predicate
    }
  }

  data = sparse_state_data(state)
  array = data[[update$target$name]]
  if (is.null(array)) return(FALSE)
  dimensions = dim(array)
  target_indices = update$target$indices
  if (!length(target_indices)) {
    if (length(array) != 1L) return(FALSE)
    if (active[[1L]]) data[[update$target$name]] = value[[1L]]
  } else {
    if (is.null(dimensions) ||
        length(dimensions) != length(target_indices)) return(FALSE)
    array_dim_names = dimnames(array)
    positions = lapply(seq_along(target_indices), function(d) {
      item = target_indices[[d]]
      source_set = if (is.name(item)) {
        vectorized$bindings[[paste0(".set:", as.character(item))]]
      } else NULL
      set_name = if (!is.null(array_dim_names) &&
                     !is.null(names(array_dim_names)) &&
                     d <= length(names(array_dim_names))) {
        names(array_dim_names)[[d]]
      } else NULL
      sparse_vectorized_positions(
        sparse_vectorized_index_value(
          item, vectorized$bindings, state, index, n
        ),
        dimensions[[d]],
        if (!is.null(array_dim_names)) array_dim_names[[d]] else NULL,
        set_name,
        source_set,
        index,
        n
      )
    })
    if (any(vapply(positions, anyNA, logical(1)))) return(FALSE)
    target_linear = rep(1, n)
    target_stride = 1
    for (d in seq_along(positions)) {
      target_linear = target_linear +
        (positions[[d]] - 1) * target_stride
      target_stride = target_stride * dimensions[[d]]
    }
    array[as.integer(target_linear[active])] = value[active]
    data[[update$target$name]] = array
  }
  if (is.environment(state)) state$data = data
  TRUE
}

sparse_change_mask = function(index) {
  mask = logical(index$endogenous_count)
  for (variable in index$variables) {
    if (isTRUE(variable$exogenous) || !isTRUE(variable$change)) next
    mask[seq.int(variable$endo_start, length.out = variable$n)] = TRUE
  }
  mask
}

sparse_add_solution = function(accumulator, current, change_mask) {
  if (any(!is.finite(current))) {
    stop("Sparse step solution contains non-finite values", call. = FALSE)
  }
  if (is.null(accumulator)) return(current)
  changed = change_mask
  regular = !change_mask
  if (any(changed)) accumulator[changed] =
    accumulator[changed] + current[changed]
  if (any(regular)) accumulator[regular] =
    ((1 + accumulator[regular] / 100) *
       (1 + current[regular] / 100) - 1) * 100
  if (any(!is.finite(accumulator))) {
    stop("Sparse accumulated solution contains non-finite values",
         call. = FALSE)
  }
  accumulator
}

sparse_substep_shocks = function(total, applied, denominator) {
  if (!length(total$values)) return(total)
  if (is.list(applied)) applied = applied$values
  remaining = ((1 + total$values / 100) /
                (1 + applied / 100) - 1) * 100
  list(
    positions = total$positions,
    values = remaining / denominator,
    labels = total$labels
  )
}

sparse_advance_applied_shocks = function(applied, substep) {
  if (!length(applied$values)) return(applied)
  applied$values = ((1 + applied$values / 100) *
                    (1 + substep$values / 100) - 1) * 100
  applied
}

sparse_extrapolate_steps = function(step_results, steps) {
  if (!length(step_results) || length(step_results) > 3L) {
    stop("Sparse solver supports one, two, or three Euler step counts",
         call. = FALSE)
  }
  if (any(vapply(step_results, function(result) {
    any(!is.finite(result))
  }, logical(1)))) {
    stop("Sparse Euler step result contains non-finite values", call. = FALSE)
  }
  result = if (length(step_results) == 1L) {
    step_results[[1L]]
  } else if (length(step_results) == 2L) {
    (step_results[[1L]] * steps[[1L]] -
       step_results[[2L]] * steps[[2L]]) /
      (steps[[1L]] - steps[[2L]])
  } else {
    (step_results[[2L]] * steps[[2L]] -
       step_results[[3L]] * steps[[3L]]) /
      (steps[[2L]] - steps[[3L]])
  }
  if (any(!is.finite(result))) {
    stop("Sparse extrapolation produced a non-finite candidate solution",
         call. = FALSE)
  }
  result
}

sparse_output_selector_error = function(argument, selector, cause, action) {
  selector_text = paste(deparse(selector), collapse = "")
  .gemodelr_abort_validation(
    sprintf(
      "Invalid %s selector %s: %s. Remediation: %s",
      argument, selector_text, cause, action
    ),
    "solveModel", "solveModel", action,
    fields = list(
      argument = argument,
      requested_selector = selector,
      cause = cause
    )
  )
}

sparse_validate_output_selectors = function(index, variables = NULL,
                                            dimensions = NULL,
                                            memory_budget = NULL,
                                            state = NULL) {
  indexed_variables = vapply(
    index$variables, function(variable) variable$name, character(1)
  )
  data = if (is.null(state)) list() else sparse_state_data(state)
  data_variables = names(data)[vapply(data, function(value) {
    is.atomic(value) && !is.object(value) &&
      (is.numeric(value) || is.logical(value))
  }, logical(1))]
  available_variables = unique(c(indexed_variables, data_variables))
  if (is.null(variables)) variables = character()
  if (!is.character(variables) || is.object(variables) || anyNA(variables) ||
      any(!nzchar(variables))) {
    sparse_output_selector_error(
      "variables", variables,
      "expected a character vector of variable names",
      "supply variable names such as variables = c(\"stock\") or use character() for an explicit empty projection"
    )
  }
  variables = unique(tolower(variables))
  unknown_variables = setdiff(variables, available_variables)
  if (length(unknown_variables)) {
    sparse_output_selector_error(
      "variables", variables,
      sprintf("unknown variable name(s): %s",
              paste(shQuote(unknown_variables), collapse = ", ")),
      sprintf("choose names from: %s",
              paste(shQuote(available_variables), collapse = ", "))
    )
  }

  if (is.null(dimensions)) dimensions = list()
  if (!is.list(dimensions) || is.object(dimensions)) {
    sparse_output_selector_error(
      "dimensions", dimensions,
      "expected a named list of character label selections",
      "supply dimensions as a named list such as list(reg = \"south\"), or use list() for no dimension filtering"
    )
  }
  if (length(dimensions)) {
    dimension_names = names(dimensions)
    if (is.null(dimension_names) || length(dimension_names) !=
        length(dimensions) || anyNA(dimension_names) ||
        any(!nzchar(dimension_names)) || anyDuplicated(dimension_names)) {
      sparse_output_selector_error(
        "dimensions", dimensions,
        "dimension selectors must have unique, non-empty names",
        "name each selector with its model dimension, for example list(reg = \"south\")"
      )
    }
    unknown_dimensions = setdiff(dimension_names, names(index$sets))
    if (length(unknown_dimensions)) {
      sparse_output_selector_error(
        "dimensions", dimensions,
        sprintf("unknown dimension name(s): %s",
                paste(shQuote(unknown_dimensions), collapse = ", ")),
        sprintf("choose dimension names from: %s",
                paste(shQuote(names(index$sets)), collapse = ", "))
      )
    }
    for (dimension in dimension_names) {
      selector = dimensions[[dimension]]
      if (!is.character(selector) || is.object(selector) || anyNA(selector) ||
          any(!nzchar(selector))) {
        sparse_output_selector_error(
          "dimensions", dimensions,
          sprintf("selector for dimension '%s' must be a character vector of labels",
                  dimension),
          sprintf("select labels with list(%s = c(\"label\"))",
                  dimension)
        )
      }
      available_labels = index$sets[[dimension]]$values
      unknown_labels = setdiff(selector, available_labels)
      if (length(unknown_labels)) {
        sparse_output_selector_error(
          "dimensions", dimensions,
          sprintf("dimension '%s' has unknown label(s): %s", dimension,
                  paste(shQuote(unknown_labels), collapse = ", ")),
          sprintf("choose labels from: %s", paste(
            shQuote(available_labels), collapse = ", "
          ))
        )
      }
    }
  }

  estimated_bytes = 0
  if (length(variables)) {
    for (name in variables) {
      variable_id = index$variable_by_name[[name]]
      variable = if (is.null(variable_id)) NULL else {
        index$variables[[variable_id]]
      }
      array = data[[name]]
      array_dimensions = dim(array)
      if (is.null(array_dimensions)) array_dimensions = integer()
      selected_lengths = as.numeric(array_dimensions)
      if (!length(selected_lengths) && !is.null(variable)) {
        selected_lengths = as.numeric(variable$lengths)
      }
      array_dimnames = dimnames(array)
      set_names = if (!is.null(array_dimnames) &&
                      !is.null(names(array_dimnames))) {
        names(array_dimnames)
      } else if (!is.null(variable)) {
        variable$sets
      } else character()
      selected_dimnames_bytes = 0
      for (dimension_id in seq_along(set_names)) {
        dimension = set_names[[dimension_id]]
        if (!is.null(dimensions[[dimension]])) {
          labels = dimensions[[dimension]]
        } else if (!is.null(array_dimnames) &&
                   dimension_id <= length(array_dimnames)) {
          labels = array_dimnames[[dimension_id]]
        } else {
          labels = index$sets[[dimension]]$values
        }
        if (dimension_id <= length(selected_lengths)) {
          selected_lengths[[dimension_id]] = length(labels)
        }
        selected_dimnames_bytes = selected_dimnames_bytes +
          8 * length(labels) + sum(nchar(labels, type = "bytes"))
      }
      selected_count = if (any(selected_lengths == 0)) {
        0
      } else if (length(selected_lengths)) {
        prod(selected_lengths)
      } else {
        1
      }
      estimated_bytes = estimated_bytes + 128 + 8 * selected_count +
        selected_dimnames_bytes
    }
  }

  if (is.numeric(memory_budget) && length(memory_budget) == 1L &&
      !is.na(memory_budget) && is.finite(memory_budget) &&
      estimated_bytes > memory_budget) {
    selector = list(variables = variables, dimensions = dimensions)
    action = paste(
      "increase memory_budget or setMemoryBudget(),",
      "or request fewer variables and dimension labels"
    )
    sparse_output_selector_error(
      "output projection", selector,
      sprintf(
        "estimated output allocation of %.0f bytes exceeds the configured memory budget of %.0f bytes",
        estimated_bytes, memory_budget
      ),
      action
    )
  }

  list(
    variables = variables,
    dimensions = dimensions,
    estimated_bytes = estimated_bytes
  )
}

sparse_output_set_names = function(name, array, index, spec = NULL) {
  variable_id = index$variable_by_name[[name]]
  if (!is.null(variable_id)) return(index$variables[[variable_id]]$sets)
  dim_names = dimnames(array)
  if (!is.null(dim_names) && !is.null(names(dim_names))) {
    return(names(dim_names))
  }
  updates = if (is.null(spec)) list() else Filter(
    function(update) identical(update$target$name, name), spec$updates
  )
  if (length(updates)) {
    return(vapply(updates[[1L]]$domains, function(domain) {
      domain$set
    }, character(1)))
  }
  character()
}

sparse_subset_output = function(array, dimensions, set_names = NULL,
                                index = NULL) {
  if (is.null(dimensions) || !length(dimensions) || is.null(dim(array))) {
    return(array)
  }
  dim_names = dimnames(array)
  array_dimensions = dim(array)
  selectors = vector("list", length(array_dimensions))
  output_dimnames = vector("list", length(array_dimensions))
  for (d in seq_along(selectors)) {
    set_name = if (!is.null(dim_names) && !is.null(names(dim_names))) {
      names(dim_names)[[d]]
    } else if (!is.null(set_names) && d <= length(set_names)) {
      set_names[[d]]
    } else NULL
    selector = if (is.null(set_name)) NULL else dimensions[[set_name]]
    source_labels = if (!is.null(dim_names) &&
                        d <= length(dim_names) &&
                        !is.null(dim_names[[d]])) {
      dim_names[[d]]
    } else if (!is.null(index) && !is.null(set_name) &&
               !is.null(index$sets[[set_name]])) {
      index$sets[[set_name]]$values
    } else NULL
    if (is.null(selector)) {
      selectors[[d]] = TRUE
      output_dimnames[d] = list(source_labels)
    } else if (!is.null(source_labels)) {
      positions = match(selector, source_labels)
      if (anyNA(positions)) {
        sparse_output_selector_error(
          "dimensions", dimensions,
          sprintf("labels for dimension '%s' are unavailable on the selected output array",
                  set_name),
          sprintf("choose labels from the selected array's '%s' dimension",
                  set_name)
        )
      }
      selectors[[d]] = positions
      output_dimnames[d] = list(selector)
    } else {
      sparse_output_selector_error(
        "dimensions", dimensions,
        sprintf("dimension '%s' cannot be mapped to the selected output array",
                set_name),
        sprintf("select a named dimension present on the output array, such as list(%s = \"label\")",
                set_name)
      )
    }
  }
  projected = do.call("[", c(list(array), selectors, list(drop = FALSE)))
  if (any(vapply(output_dimnames, Negate(is.null), logical(1)))) {
    output_names = set_names
    if (is.null(output_names) && !is.null(dim_names)) {
      output_names = names(dim_names)
    }
    if (!is.null(output_names) &&
        length(output_names) == length(output_dimnames)) {
      names(output_dimnames) = output_names
    }
    dimnames(projected) = output_dimnames
  }
  projected
}

sparse_project_outputs = function(state, index, variables = NULL,
                                  dimensions = NULL, solution = NULL,
                                  memory_budget = NULL, spec = NULL) {
  validated = sparse_validate_output_selectors(
    index, variables, dimensions, memory_budget, state
  )
  variables = validated$variables
  dimensions = validated$dimensions
  data = sparse_state_data(state)
  result = list()
  for (name in variables) {
    variable_sets = sparse_output_set_names(
      name, data[[name]], index, spec
    )
    result[[name]] = sparse_subset_output(
      data[[name]], dimensions, set_names = variable_sets, index = index
    )
  }
  if (!is.null(solution)) result$solution = solution
  result
}

sparse_gc_bytes = function() {
  info = gc()
  as.numeric(sum(info[, "used"])) * 8
}

sparse_restrict_index = function(index, equation_ids, state) {
  active = index
  active$equations = index$equations[equation_ids]
  references = unique(unlist(lapply(active$equations, function(equation) {
    vapply(equation$terms, function(term) term$ref$name, character(1))
  }), use.names = FALSE))
  references = union(references, index$closure_names)
  variable_ids = which(vapply(index$variables, function(variable) {
    variable$name %in% references
  }, logical(1)))
  active$variables = index$variables[variable_ids]
  active$variable_by_name = setNames(
    as.list(seq_along(active$variables)),
    vapply(active$variables, function(variable) variable$name, character(1))
  )

  global_start = 1L
  endo_start = 1L
  for (id in seq_along(active$variables)) {
    variable = active$variables[[id]]
    variable$global_start = as.integer(global_start)
    variable$global_end = as.integer(global_start + variable$n - 1L)
    variable$exogenous = variable$name %in% index$closure_names
    if (variable$exogenous) {
      variable$endo_start = NA_integer_
    } else {
      variable$endo_start = as.integer(endo_start)
      endo_start = endo_start + variable$n
    }
    active$variables[[id]] = variable
    global_start = global_start + variable$n
  }

  active$variable_count = as.integer(global_start - 1L)
  active$endogenous_count = as.integer(endo_start - 1L)
  active$equation_ids = as.integer(equation_ids)
  active$full_equation_count = index$equation_count
  active$full_endogenous_count = index$endogenous_count
  active$row_layout_ready = FALSE
  active$pattern_cache = NULL
  active$column_order = NULL
  sparse_build_row_layout(NULL, active, state)
}

sparse_select_simulation_index = function(index, spec, state,
                                          postsim = TRUE) {
  # Post-simulation formulas are evaluated lazily after the numerical solve.
  # They must not expand the solve to include reporting equations.
  if (is.null(spec) || !length(spec$simulation_equation_candidates)) {
    return(index)
  }
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(spec, index, state)
  }
  for (cut in spec$simulation_equation_candidates) {
    candidate = sparse_restrict_index(
      index, seq_len(as.integer(cut)), state
    )
    if (candidate$equation_count == candidate$endogenous_count &&
        candidate$equation_count > 0L) {
      candidate$simulation_boundary = as.integer(cut)
      return(candidate)
    }
  }
  index
}

sparse_estimate_memory = function(model, index, engine = "sparse",
                                  budget = NULL, postsim = TRUE,
                                  state = NULL) {
  if (is.null(state)) state = model$sparseState
  data = if (!is.null(state)) sparse_state_data(state) else model$data
  input_bytes = as.numeric(object.size(data))
  variable_bytes = sum(vapply(index$variables, function(variable) {
    8 * variable$n
  }, numeric(1)))
  equation_positions = as.numeric(index$equation_count)
  triplets = sparse_triplet_capacity(index)
  triplet_bytes = triplets * (8 + 4 + 4)
  matrix_bytes = triplet_bytes + equation_positions * 8
  factor_bytes = triplet_bytes * 2
  rhs_bytes = equation_positions * 8
  metadata_bytes = as.numeric(object.size(index))
  peak = input_bytes + variable_bytes + triplet_bytes + matrix_bytes +
    factor_bytes + rhs_bytes + metadata_bytes
  list(
    engine = engine,
    har_input_bytes = input_bytes,
    model_variable_bytes = variable_bytes,
    equation_positions = equation_positions,
    variable_positions = as.numeric(index$variable_count),
    endogenous_positions = as.numeric(index$endogenous_count),
    estimated_sparse_triplets = triplets,
    estimated_triplet_bytes = triplet_bytes,
    estimated_sparse_matrix_bytes = matrix_bytes,
    estimated_factor_workspace_bytes = factor_bytes,
    estimated_rhs_bytes = rhs_bytes,
    estimated_metadata_bytes = metadata_bytes,
    estimated_peak_bytes = peak,
    post_simulation_retained = isTRUE(postsim),
    dense_fallback = FALSE,
    budget_bytes = budget
  )
}

sparse_check_budget = function(estimate, budget) {
  if (is.null(budget) || !length(budget) || is.na(budget)) return(invisible(NULL))
  if (estimate$estimated_peak_bytes > budget) {
    stop(sprintf(
      paste(
        "Sparse preflight estimates %.2f GB peak allocation,",
        "above the configured %.2f GB budget.",
        "Increase setMemoryBudget(), reduce retained outputs,",
        "or use a smaller closure/data slice."
      ),
      estimate$estimated_peak_bytes / 1024^3, budget / 1024^3
    ), call. = FALSE)
  }
  invisible(NULL)
}

.sparse_solve_one_step_impl = function(state, model, index, shocks, backend,
                                 reduction, measure = FALSE,
                                 structured_partition = NULL,
                                 candidate_transform = NULL) {
  backend_preflight = .sparse_backend_preflight(
    backend, model = model, structured_partition = structured_partition
  )
  .identity_guard_old_options(
    "tabloToR.sparse.structured_residual_tolerance"
  )
  residual_tolerance = getOption(
    "GEModelR.sparse.structured_residual_tolerance", 2e-7
  )
  if (isTRUE(measure)) {
    before_bytes = sparse_gc_bytes()
    matrix_start = proc.time()[[3L]]
  }
  .transaction_fault("compilation")
  column_order = sparse_lhs_column_order(index, state)
  index$column_order = column_order
  emitted = sparse_emit_system(state, index, shocks)
  index = emitted$index
  coefficient_matrix = emitted$A
  if (isTRUE(measure)) {
    matrix_end = proc.time()[[3L]]
    matrix_bytes = sparse_gc_bytes()
    solve_start = proc.time()[[3L]]
  }
  .transaction_fault("factorization")
  solver_diagnostics = NULL
  candidate = NULL
  if (!is.null(backend_preflight$adapter)) {
    candidate = .sparse_backend_solve(
      backend_preflight,
      coefficient_matrix = coefficient_matrix,
      rhs = emitted$rhs,
      reduction = reduction,
      model = model,
      structured_partition = structured_partition
    )
    solution = candidate$solution
    solver_diagnostics = candidate$solver_diagnostics
  } else {
    solution = solve_sparse_system(
      coefficient_matrix, emitted$rhs, backend = backend,
      reduction = reduction
    )
  }
  .transaction_fault("convergence")
  expected_structure = list(
    class = "numeric",
    type = "double",
    length = ncol(coefficient_matrix),
    names = NULL,
    dim = NULL,
    dimnames = NULL,
    missing = rep(FALSE, ncol(coefficient_matrix)),
    encoding = character()
  )
  if (is.null(candidate)) {
    candidate = list(
      backend = backend,
      solution = solution,
      coefficient_matrix = coefficient_matrix,
      rhs = emitted$rhs,
      output_structure = list(
        class = class(solution),
        type = typeof(solution),
        length = length(solution),
        names = names(solution),
        dim = dim(solution),
        dimnames = dimnames(solution),
        missing = as.vector(is.na(solution)),
        encoding = if (is.character(solution)) {
          unname(Encoding(solution))
        } else character()
      )
    )
  }
  if (!is.null(candidate_transform)) {
    if (!is.function(candidate_transform)) {
      stop("candidate_transform must be a function", call. = FALSE)
    }
    candidate = candidate_transform(candidate)
  }
  .transaction_fault("finiteness")
  .transaction_fault("residual")
  accepted = tryCatch(
    .sparse_accept_candidate(
      candidate,
      expected_structure = expected_structure,
      residual_tolerance = residual_tolerance,
      diagnostics = measure
    ),
    error = function(error) {
      error$diagnostic_evidence = list(
        capability_evidence = candidate$capability_evidence,
        cleanup_status = candidate$cleanup_status,
        solver_backend = candidate$requested_backend,
        solver_backend_impl = candidate$implementation
      )
      stop(error)
    }
  )
  solution = accepted$solution
  true_residual = accepted$true_residual
  acceptance_diagnostics = accepted$retained_diagnostics
  accepted$coefficient_matrix = NULL
  candidate$coefficient_matrix = NULL
  if (length(column_order)) {
    original_solution = numeric(length(solution))
    original_solution[column_order] = solution
    solution = original_solution
  }
  coefficient_matrix = NULL
  if (isTRUE(measure)) {
    solve_end = proc.time()[[3L]]
    solve_bytes = sparse_gc_bytes()
    update_start = proc.time()[[3L]]
  }
  sparse_apply_solution(state, index, solution)
  .transaction_fault("simulation-update")
  sparse_apply_shocks(state, index, shocks)
  sparse_apply_updates(
    state, index, model$sparseSpec,
    updates = model$sparseSpec$simulation_updates
  )
  if (isTRUE(measure)) {
    update_end = proc.time()[[3L]]
    update_bytes = sparse_gc_bytes()
    phase = list(
      matrix_seconds = matrix_end - matrix_start,
      factor_solve_seconds = solve_end - solve_start,
      update_seconds = update_end - update_start,
      matrix_alloc_bytes = max(0, matrix_bytes - before_bytes),
      factor_solve_alloc_bytes = max(0, solve_bytes - matrix_bytes),
      update_alloc_bytes = max(0, update_bytes - solve_bytes)
    )
  } else {
    phase = NULL
  }
  capability_evidence = candidate$capability_evidence
  if (is.null(capability_evidence)) {
    capability_evidence = backend_preflight$capability_evidence
  }
  implementation = candidate$implementation
  if (is.null(implementation) && !is.null(backend_preflight$adapter)) {
    implementation = backend_preflight$adapter$implementation
  }
  cleanup_status = candidate$cleanup_status
  if (is.null(cleanup_status)) {
    cleanup_status = list(
      status = "complete", scope = "solve", resources = "none retained"
    )
  }
  list(
    solution = solution,
    nnz = emitted$nnz,
    true_residual = true_residual,
    solver_diagnostics = solver_diagnostics,
    acceptance_diagnostics = acceptance_diagnostics,
    capability_evidence = capability_evidence,
    implementation = implementation,
    cleanup_status = cleanup_status,
    column_permuted = length(column_order) > 0L,
    phase = phase,
    index = index
  )
}

sparse_solve_one_step = function(state, model, index, shocks, backend,
                                 reduction, measure = FALSE,
                                 structured_partition = NULL) {
  .sparse_solve_one_step_impl(
    state, model, index, shocks, backend, reduction, measure,
    structured_partition
  )
}

.sparse_solve_model_impl = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix",
                              reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  if (!is.numeric(iter) || length(iter) != 1L || iter < 1 ||
      is.na(iter) || !is.finite(iter) || iter != as.integer(iter)) {
    .gemodelr_abort_validation(
      "iter must be a positive integer", "solveModel", "solveModel",
      "Set iter to a positive integer",
      fields = list(
        argument = "iter", requested_value = iter,
        requested_engine = "sparse", requested_backend = backend
      )
    )
  }
  if (!is.numeric(steps) || !length(steps) || anyNA(steps) ||
      any(!is.finite(steps)) || any(steps < 1) ||
      any(steps != as.integer(steps))) {
    .gemodelr_abort_validation(
      "steps must contain positive integers", "solveModel", "solveModel",
      "Set steps to one or more positive integers",
      fields = list(
        argument = "steps", requested_value = steps,
        requested_engine = "sparse", requested_backend = backend
      )
    )
  }
  output = .gemodelr_match_arg(
    output, c("full", "compact"), "solveModel", "output",
    "Set output to 'full' or 'compact'"
  )
  reduction = .gemodelr_match_arg(
    reduction, c("auto", "off", "on"), "solveModel", "reduction",
    "Set reduction to 'auto', 'off', or 'on'"
  )
  backend = .gemodelr_match_arg(
    backend, c(
      "Matrix", "SuiteSparse", "SparseM", "StructuredSchur",
      "StructuredSchurFGMRES", "StructuredSchurFGMRESCpp"
    ), "solveModel", "backend", "Choose a registered sparse backend ID"
  )
  if (identical(backend, "Matrix")) {
    .identity_guard_old_options("tabloToR.sparse.lu_order")
    lu_order = suppressWarnings(as.integer(
      getOption("GEModelR.sparse.lu_order", 3L)
    )[1L])
    if (is.na(lu_order) || lu_order < 0L || lu_order > 3L) {
      .gemodelr_abort_validation(
        "GEModelR.sparse.lu_order must be an integer from 0 to 3",
        "solveModel", "solveModel",
        "Set GEModelR.sparse.lu_order to an integer from 0 to 3",
        fields = list(
          argument = "GEModelR.sparse.lu_order",
          requested_value = getOption("GEModelR.sparse.lu_order", 3L),
          requested_engine = "sparse", requested_backend = backend
        )
      )
    }
  }
  native_requested = exists(
    ".sparse_schur_cpp_runtime", mode = "environment", inherits = TRUE
  ) && isTRUE(.sparse_schur_cpp_runtime$active) &&
    identical(backend, "StructuredSchurFGMRES")
  requested_backend = if (native_requested) {
    "StructuredSchurFGMRESCpp"
  } else backend
  backend_impl = if (native_requested) "cpp" else "r"
  model$lastDiagnostics = .gemodelr_diagnostics_envelope(
    engine = "sparse", requested_backend = requested_backend,
    implementation = backend_impl
  )
  index = model$sparseIndex
  committed_state = model$sparseState
  if (is.null(committed_state) || !is.environment(committed_state)) {
    state = sparse_make_state(model$data)
  } else state = sparse_make_state(sparse_state_data(committed_state))
  closure = model$closure
  if (is.null(closure)) closure = character()
  index_is_invalid = is.null(index) || !length(index) ||
    !setequal(index$closure_names, closure)
  if (index_is_invalid && identical(model$loadedEngine, "sparse") &&
      is.environment(committed_state) && length(model$sparseSpec)) {
    index = sparse_build_index(model$sparseSpec, sparse_state_data(state))
  }
  if (is.null(index) || !length(index)) {
    stop("Sparse engine is not loaded; call loadTablo() and loadData() first",
         call. = FALSE)
  }
  index = sparse_rebuild_columns(index, closure)
  if (!isTRUE(index$row_layout_ready)) {
    index = sparse_build_row_layout(model$sparseSpec, index, state)
  }
  full_index = index
  budget = memory_budget
  if (is.null(budget) || !length(budget)) budget = model$memoryBudget
  if (!is.null(budget) && length(budget) &&
      (!is.numeric(budget) || length(budget) != 1L ||
       is.na(budget) || !is.finite(budget) || budget <= 0)) {
    .gemodelr_abort_validation(
      "Memory budget must be a positive finite number of bytes",
      "solveModel", "solveModel",
      "Set memory_budget to a positive finite number of bytes",
      fields = list(
        argument = "memory_budget", requested_value = budget,
        requested_engine = "sparse", requested_backend = requested_backend
      )
    )
  }
  project_outputs = output == "compact" || !is.null(variables) ||
    !is.null(dimensions)
  if (project_outputs) {
    validated = sparse_validate_output_selectors(
      full_index, variables, dimensions, memory_budget = budget,
      state = state
    )
    variables = validated$variables
    dimensions = validated$dimensions
  }
  index = sparse_select_simulation_index(
    index, model$sparseSpec, state, postsim = postsim
  )
  if (index$equation_count != index$endogenous_count) {
    stop(sprintf(
      "Sparse system is not square: %s equations, %s endogenous variables.",
      index$equation_count, index$endogenous_count
    ), call. = FALSE)
  }
  structured_partition = NULL
  if (backend %in% c("StructuredSchur", "StructuredSchurFGMRES")) {
    if (!exists("sparse_gtap_elimination_partition", mode = "function")) {
      stop("Structured sparse elimination helpers are unavailable",
           call. = FALSE)
    }
    index$column_order = sparse_lhs_column_order(index, state)
    if (is.null(index$column_order)) {
      stop("StructuredSchur backend could not construct a column order",
           call. = FALSE)
    }
    structured_partition = sparse_gtap_elimination_partition(index, state)
  }
  estimate = sparse_estimate_memory(
    model, index, budget = budget, postsim = postsim, state = state
  )
  sparse_check_budget(estimate, budget)
  phase_metrics = list(
    matrix_seconds = 0,
    factor_solve_seconds = 0,
    update_seconds = 0,
    matrix_alloc_bytes = 0,
    factor_solve_alloc_bytes = 0,
    update_alloc_bytes = 0
  )
  start_time = proc.time()[[3L]]
  shocks = sparse_resolve_shocks(model, state, index)
  change_mask = sparse_change_mask(index)
  final_solution = NULL
  applied_shocks = list(
    positions = shocks$positions,
    values = numeric(length(shocks$values)),
    labels = shocks$labels
  )
  max_nnz = 0
  residual_history = list()
  solver_diagnostics_history = list()
  capability_history = list()
  cleanup_history = list()
  for (iteration in seq_len(iter)) {
    outer_checkpoint = sparse_checkpoint_state(
      state, index, model$sparseSpec
    )
    remaining = sparse_substep_shocks(
      shocks, applied_shocks, iter - iteration + 1L
    )
    applied_shocks = sparse_advance_applied_shocks(
      applied_shocks, remaining
    )
    step_results = vector("list", length(steps))
    for (step_id in seq_along(steps)) {
      sparse_restore_checkpoint(state, outer_checkpoint)
      step_count = as.integer(steps[[step_id]])
      applied_subshocks = list(
        positions = shocks$positions,
        values = numeric(length(shocks$values)),
        labels = shocks$labels
      )
      step_result = numeric(index$endogenous_count)
      for (current_step in seq_len(step_count)) {
        substep = sparse_substep_shocks(
          remaining, applied_subshocks, step_count - current_step + 1L
        )
        applied_subshocks = sparse_advance_applied_shocks(
          applied_subshocks, substep
        )
        solved = sparse_solve_one_step(
          state, model, index, substep, backend, reduction,
          measure = diagnostics,
          structured_partition = structured_partition
        )
        index = solved$index
        if (!is.null(solved$solver_diagnostics)) {
          solver_diagnostics_history[[
            length(solver_diagnostics_history) + 1L
          ]] = solved$solver_diagnostics
        }
        if (!is.null(solved$capability_evidence)) {
          capability_history[[length(capability_history) + 1L]] =
            solved$capability_evidence
        }
        if (!is.null(solved$cleanup_status)) {
          cleanup_history[[length(cleanup_history) + 1L]] =
            solved$cleanup_status
        }
        if (!is.null(solved$phase)) {
          for (metric in names(phase_metrics)) {
            if (grepl("_seconds$", metric)) {
              phase_metrics[[metric]] = phase_metrics[[metric]] +
                solved$phase[[metric]]
            } else {
              phase_metrics[[metric]] = max(
                phase_metrics[[metric]], solved$phase[[metric]]
              )
            }
          }
        }
        max_nnz = max(max_nnz, solved$nnz)
        if (!is.null(solved$true_residual)) {
          residual_history[[length(residual_history) + 1L]] = list(
            iteration = iteration, step = step_id, substep = current_step,
            metrics = solved$true_residual
          )
        }
        cleanup = if (length(cleanup_history)) {
          cleanup_history[[length(cleanup_history)]]
        } else list(status = "not-run")
        progress_details = if (isTRUE(diagnostics)) {
          list(
            iterations = iteration,
            steps = steps,
            elapsed_seconds = proc.time()[[3L]] - start_time,
            estimated_memory = estimate,
            max_sparse_nonzeros = max_nnz,
            true_residual_history = residual_history,
            capability_evidence = if (length(capability_history)) {
              capability_history[[length(capability_history)]]
            } else list(),
            capability_history = capability_history,
            cleanup_history = cleanup_history,
            solver_diagnostics = if (length(solver_diagnostics_history)) {
              solver_diagnostics_history[[length(solver_diagnostics_history)]]
            } else NULL,
            phase_allocations = phase_metrics,
            phase_seconds = phase_metrics[c(
              "matrix_seconds", "factor_solve_seconds", "update_seconds"
            )],
            dense_fallback = FALSE,
            peak_gc_bytes = sparse_gc_bytes()
          )
        } else list()
        model$lastDiagnostics = .gemodelr_diagnostics_envelope(
          engine = "sparse",
          requested_backend = requested_backend,
          implementation = backend_impl,
          cleanup_status = cleanup,
          details = progress_details
        )
        .transaction_fault("after-substep", list(
          iteration = iteration, step = step_id,
          substep = current_step
        ))
        step_result = sparse_add_solution(
          step_result, solved$solution, change_mask
        )
      }
      step_results[[step_id]] = step_result
    }
    iteration_solution = sparse_extrapolate_steps(step_results, steps)
    sparse_restore_checkpoint(state, outer_checkpoint)
    sparse_apply_solution(state, index, iteration_solution)
    sparse_apply_shocks(state, index, remaining)
    .transaction_fault("simulation-update", list(iteration = iteration))
    sparse_apply_updates(
      state, index, model$sparseSpec,
      updates = model$sparseSpec$simulation_updates
    )
    final_solution = sparse_add_solution(
      final_solution, iteration_solution, change_mask
    )
  }
  if (is.null(final_solution)) final_solution = numeric(index$endogenous_count)
  sparse_apply_solution(state, index, final_solution)
  sparse_apply_shocks(state, index, shocks)
  solution = final_solution
  if (output == "full") names(solution) = sparse_endogenous_labels(index)
  diagnostics_result = list(
    engine = "sparse",
    implementation = backend_impl,
    requested_backend = requested_backend,
    accepted_numerical_state = TRUE,
    retryable_postsim = TRUE,
    failure_phase = NULL,
    failure_reason = NULL,
    iterations = iter,
    steps = steps,
    elapsed_seconds = proc.time()[[3L]] - start_time,
    estimated_memory = estimate,
    max_sparse_nonzeros = max_nnz,
    true_residual_history = residual_history,
    solver_backend = requested_backend,
    solver_backend_impl = backend_impl,
    capability_evidence = if (length(capability_history)) {
      capability_history[[length(capability_history)]]
    } else list(
      requested_backend = requested_backend,
      implementation = backend_impl,
      available = TRUE
    ),
    capability_history = capability_history,
    cleanup_status = if (length(cleanup_history)) {
      cleanup_history[[length(cleanup_history)]]
    } else list(
      status = "complete", scope = "solve", resources = "none retained"
    ),
    cleanup_history = cleanup_history,
    solver_diagnostics = if (length(solver_diagnostics_history)) {
      solver_diagnostics_history[[length(solver_diagnostics_history)]]
    } else NULL,
    phase_allocations = phase_metrics,
    phase_seconds = phase_metrics[c("matrix_seconds",
                                    "factor_solve_seconds", "update_seconds")],
    dense_fallback = FALSE,
    post_simulation_retained = isTRUE(postsim),
    peak_gc_bytes = if (isTRUE(diagnostics)) sparse_gc_bytes() else NA_real_
  )
  postsim_record = list(
    engine = "sparse",
    requested_backend = requested_backend,
    state_data = sparse_state_data(state),
    structural_cache = if (is.environment(state)) {
      state$.solver_cache
    } else NULL,
    index = full_index,
    solve_index = index,
    spec = model$sparseSpec,
    solution = solution,
    diagnostics = diagnostics_result,
    postsim = isTRUE(postsim),
    output = output,
    variables = variables,
    dimensions = dimensions,
    memory_budget = budget
  )
  diagnostics_record = .gemodelr_diagnostics_envelope(
    engine = "sparse",
    requested_backend = requested_backend,
    implementation = backend_impl,
    accepted_numerical_state = TRUE,
    retryable_postsim = TRUE,
    cleanup_status = diagnostics_result$cleanup_status,
    details = if (isTRUE(diagnostics)) diagnostics_result else list()
  )
  model$lastDiagnostics = diagnostics_record
  .commit_accepted_state(model, list(
    state = state,
    index = full_index,
    solution = solution,
    diagnostics = diagnostics_record,
    loaded_engine = "sparse",
    postsim_record = postsim_record
  ))
  .retry_postsim_from_record(model, diagnostics = diagnostics)
}

sparse_solve_model = function(model, iter = 3, steps = c(1, 3),
                              postsim = TRUE, diagnostics = FALSE,
                              output = c("full", "compact"),
                              variables = NULL, dimensions = NULL,
                              backend = "Matrix",
                              reduction = c("auto", "off", "on"),
                              memory_budget = NULL) {
  diagnostics_enabled = isTRUE(diagnostics)
  tryCatch(
    .sparse_solve_model_impl(
      model,
      iter = iter,
      steps = steps,
      postsim = postsim,
      diagnostics = diagnostics,
      output = output,
      variables = variables,
      dimensions = dimensions,
      backend = backend,
      reduction = reduction,
      memory_budget = memory_budget
    ),
    error = function(error) {
      accepted_numerical_state = isTRUE(
        attr(error, "GEModelR.accepted_numerical_state")
      )
      retryable_postsim = accepted_numerical_state ||
        length(model$.postsimRecord) > 0L
      error = .gemodelr_solve_condition(
        error, "sparse", backend,
        accepted_numerical_state = accepted_numerical_state,
        retryable_postsim = retryable_postsim
      )
      if (accepted_numerical_state) {
        diagnostics = model$lastDiagnostics
        if (!is.list(diagnostics) || !length(diagnostics)) {
          diagnostics = .postsim_failure_diagnostics(
            model$.postsimRecord, error,
            diagnostics = diagnostics_enabled
          )
        }
        diagnostics$condition_class = class(error)[[1L]]
        diagnostics$requested_backend = backend
        model$lastDiagnostics = diagnostics
        stop(error)
      }
      prior = model$lastDiagnostics
      failure = .transaction_failure_diagnostics(
        "sparse", error, retryable_postsim = retryable_postsim
      )
      cleanup = prior$cleanup_status
      if (is.null(cleanup)) cleanup = failure$cleanup_status
      details = if (diagnostics_enabled) {
        .gemodelr_diagnostics_details(prior)
      } else list()
      model$lastDiagnostics = .gemodelr_diagnostics_envelope(
        engine = failure$engine,
        requested_backend = failure$requested_backend,
        implementation = prior$implementation,
        status = failure$status,
        condition_class = failure$condition_class,
        accepted_numerical_state = failure$accepted_numerical_state,
        retryable_postsim = failure$retryable_postsim,
        failure_phase = failure$failure_phase,
        failure_reason = failure$failure_reason,
        cleanup_status = cleanup,
        details = details
      )
      stop(error)
    }
  )
}
