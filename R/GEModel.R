# properties:
#   TABLO as a recipe
#   data files as data
#   exogenous variables as a definition
# methods:
#   solve the model (for the given coefficients)
#   update data (execute all updates/formulas always)

.gemodelr_condition = function(primary_class, message, fields = list()) {
  if (!is.character(primary_class) || length(primary_class) != 1L ||
      is.na(primary_class) || !grepl("^GEModelR_", primary_class)) {
    stop("primary_class must be one GEModelR condition class", call. = FALSE)
  }
  if (!is.character(message) || length(message) != 1L || is.na(message)) {
    stop("message must be one non-missing character value", call. = FALSE)
  }
  if (!is.list(fields) || is.object(fields) ||
      (length(fields) && (is.null(names(fields)) ||
                          anyNA(names(fields)) ||
                          any(!nzchar(names(fields))) ||
                          anyDuplicated(names(fields))))) {
    stop("fields must be a uniquely named list", call. = FALSE)
  }
  fields = fields[setdiff(names(fields), c("message", "call"))]
  structure(
    c(list(message = message, call = NULL), fields),
    class = c(primary_class, "error", "condition")
  )
}

.gemodelr_abort_validation = function(
    message, operation, next_method, action, fields = list()) {
  condition_fields = list(
    operation = operation,
    failure_phase = "validation",
    accepted_numerical_state = FALSE,
    retryable_postsim = FALSE,
    remediation = list(next_method = next_method, action = action)
  )
  condition_fields[names(fields)] = NULL
  condition_fields = c(condition_fields, fields)
  stop(.gemodelr_condition(
    "GEModelR_validation_error", message, condition_fields
  ))
}

.gemodelr_match_arg = function(value, choices, operation, argument, action) {
  tryCatch(
    match.arg(value, choices),
    error = function(error) {
      .gemodelr_abort_validation(
        conditionMessage(error), operation, operation, action,
        fields = list(
          argument = argument,
          requested_value = value,
          allowed_values = choices,
          cause = conditionMessage(error)
        )
      )
    }
  )
}

.gemodelr_require_tablo = function(model, operation) {
  if (is.function(model$skeletonGenerator) &&
      is.function(model$generateVariables) &&
      length(model$tabloStatements) && length(model$sparseSpec)) {
    return(invisible(NULL))
  }
  .gemodelr_abort_validation(
    sprintf("%s requires a successfully loaded TABLO model", operation),
    operation, "loadTablo",
    sprintf("Call loadTablo() with a valid TABLO file before %s", operation),
    fields = list(required_method = "loadTablo")
  )
}

.gemodelr_require_runtime = function(model, operation,
                                    requested_engine = NULL) {
  .gemodelr_require_tablo(model, operation)
  loaded_engine = model$loadedEngine
  if (length(loaded_engine) != 1L || is.na(loaded_engine) ||
      !loaded_engine %in% c("legacy", "sparse")) {
    .gemodelr_abort_validation(
      sprintf("%s requires model data to be loaded", operation),
      operation, "loadData",
      sprintf("Call loadData(engine = \"legacy\" or \"sparse\") before %s",
              operation),
      fields = list(required_method = "loadData")
    )
  }
  if (!is.null(requested_engine) &&
      !identical(requested_engine, loaded_engine)) {
    .gemodelr_abort_validation(
      sprintf(
        "%s requested engine '%s', but loadData() initialized '%s'",
        operation, requested_engine, loaded_engine
      ),
      operation, "loadData",
      sprintf("Call loadData(engine = \"%s\") before %s",
              requested_engine, operation),
      fields = list(
        requested_engine = requested_engine,
        loaded_engine = loaded_engine,
        required_method = "loadData"
      )
    )
  }
  invisible(NULL)
}

GEModel = setRefClass(
  "GEModel",
  fields = list(
    shocks = "numeric",
    skeletonGenerator = 'function',
    sparseSkeletonGenerator = 'function',
    equationCoefficientMatrixGenerator = 'function',
    equationCoefficientGenerator = 'function',
    generateVariables = 'function',
    generateUpdates = 'function',
    data = 'list',
    solution = 'numeric',
    changeVariables = 'character',
    variables = 'character',
    basicChangeVariables = 'character',
    variableValues = 'list',
    tabloStatements = 'list',
    sparseSpec = 'list',
    sparseIndex = 'list',
    sparseState = 'environment',
    loadedEngine = 'character',
    closure = 'character',
    explicitShocks = 'list',
    sourceData = 'list',
    memoryBudget = 'numeric',
    lastDiagnostics = 'list',
    compactOutput = 'list',
    .postsimRecord = 'list'
  ),
  methods = list(
    # Loads a tablo without any data (only produces generic functions to genrate coefficients/equation coefficients etc.)
    loadTablo = function(tabloPath) {
      if (!is.character(tabloPath) || length(tabloPath) != 1L ||
          is.na(tabloPath) || !nzchar(tabloPath) ||
          !file.exists(tabloPath) || dir.exists(tabloPath)) {
        .gemodelr_abort_validation(
          "tabloPath must identify one existing TABLO file",
          "loadTablo", "loadTablo",
          "Call loadTablo() with a readable, valid TABLO file",
          fields = list(argument = "tabloPath", requested_path = tabloPath)
        )
      }
      prepared = tryCatch({
        legacy_results = tryCatch(processTablo(tabloPath),
                                  error = function(error) NULL)
        sparse_results = tryCatch(sparse_process_tablo(tabloPath),
                                  error = function(error) NULL)
        results = if (!is.null(legacy_results)) {
          legacy_results
        } else {
          sparse_results
        }
        if (is.null(results)) {
          stop("TABLO parsing did not produce a usable model", call. = FALSE)
        }
        sparse_generator = if (!is.null(sparse_results)) {
          sparse_results$skeletonGenerator
        } else {
          results$skeletonGenerator
        }
        sparse_spec = if (!is.null(sparse_results) &&
                          !is.null(sparse_results$sparseSpec)) {
          sparse_results$sparseSpec
        } else if (!is.null(results$sparseSpec)) {
          results$sparseSpec
        } else {
          sparse_compile_spec(results$statements)
        }
        basic_change_variables = if (is.null(results$changeVariables)) {
          character()
        } else {
          as.character(results$changeVariables)
        }
        source_record = .serialization_capture_tablo(tabloPath)
        required_functions = c(
          "skeletonGenerator", "equationCoefficientMatrixGenerator",
          "equationCoefficientGenerator", "generateVariables",
          "generateUpdates"
        )
        functions = list(
          skeletonGenerator = results$skeletonGenerator,
          equationCoefficientMatrixGenerator =
            results$equationCoefficientMatrixGenerator,
          equationCoefficientGenerator =
            results$equationCoefficientGenerator,
          generateVariables = results$generateVariables,
          generateUpdates = results$generateUpdates,
          sparseSkeletonGenerator = sparse_generator
        )
        if (!all(vapply(functions[required_functions], is.function,
                        logical(1))) ||
            !is.function(functions$sparseSkeletonGenerator) ||
            !is.character(results$variables) ||
            !is.list(results$statements) || !is.list(sparse_spec) ||
            !is.list(source_record)) {
          stop("TABLO setup produced an invalid model structure",
               call. = FALSE)
        }
        list(
          functions = functions,
          basic_change_variables = basic_change_variables,
          variables = results$variables,
          statements = results$statements,
          sparse_spec = sparse_spec,
          source_data = source_record
        )
      }, error = function(error) {
        if (inherits(error, "GEModelR_validation_error")) stop(error)
        .gemodelr_abort_validation(
          sprintf("Unable to process TABLO file: %s", conditionMessage(error)),
          "loadTablo", "loadTablo",
          "Retry loadTablo() with a readable, valid TABLO file",
          fields = list(
            argument = "tabloPath",
            requested_path = tabloPath,
            cause = conditionMessage(error),
            failure_phase = "loadTablo"
          )
        )
      })

      skeletonGenerator <<- prepared$functions$skeletonGenerator
      sparseSkeletonGenerator <<- prepared$functions$sparseSkeletonGenerator
      equationCoefficientMatrixGenerator <<-
        prepared$functions$equationCoefficientMatrixGenerator
      equationCoefficientGenerator <<-
        prepared$functions$equationCoefficientGenerator
      generateVariables <<- prepared$functions$generateVariables
      generateUpdates <<- prepared$functions$generateUpdates
      basicChangeVariables <<- prepared$basic_change_variables
      variables <<- prepared$variables
      tabloStatements <<- prepared$statements
      sparseSpec <<- prepared$sparse_spec
      sourceData <<- prepared$source_data
      data <<- list()
      solution <<- numeric()
      changeVariables <<- character()
      variableValues <<- list()
      sparseIndex <<- list()
      sparseState <<- sparse_make_state(list())
      loadedEngine <<- character()
      lastDiagnostics <<- list()
      compactOutput <<- list()
      .postsimRecord <<- list()
      invisible(.self)
    },
    loadData = function(inputData, engine = c("legacy", "sparse")) {
      engine = .gemodelr_match_arg(
        engine, c("legacy", "sparse"), "loadData", "engine",
        "Call loadData() with engine = 'legacy' or engine = 'sparse'"
      )
      .gemodelr_require_tablo(.self, "loadData")
      prepared = tryCatch({
        source_record = sourceData
        source_record$loaded_data = inputData
        source_record$data_fingerprint =
          .serialization_object_fingerprint(inputData)
        if (engine == "sparse" && length(sparseSpec$compile_errors)) {
          errors = unique(as.character(sparseSpec$compile_errors))
          stop(sprintf(
            "Sparse TABLO compilation failed for %s equation(s): %s",
            length(errors), paste(errors, collapse = "; ")
          ), call. = FALSE)
        }
        generator = if (engine == "sparse" &&
                        is.function(sparseSkeletonGenerator)) {
          sparseSkeletonGenerator
        } else {
          skeletonGenerator
        }
        if (!is.function(generator) || !is.function(generateVariables)) {
          stop("TABLO generators are unavailable", call. = FALSE)
        }
        generated_data = generator(inputData)
        if (engine == "sparse") {
          generated_data = generateVariables(generated_data)
          sparse_state = sparse_make_state(generated_data)
          sparse_index = sparse_build_index(sparseSpec, generated_data)
          sparse_index = sparse_rebuild_columns(sparse_index, closure)
          sparse_index = sparse_build_row_layout(
            sparseSpec, sparse_index, sparse_state
          )
          sparse_initialize_update_targets(
            sparse_state, sparse_index, sparseSpec,
            updates = sparseSpec$simulation_updates
          )
          sparse_apply_updates(
            sparse_state, sparse_index, sparseSpec,
            updates = sparseSpec$formula_initialization_updates
          )
          list(
            data = generated_data,
            variable_values = list(),
            change_variables = basicChangeVariables,
            sparse_state = sparse_state,
            sparse_index = sparse_index,
            source_data = source_record,
            loaded_engine = "sparse"
          )
        } else {
          generated_data = equationCoefficientMatrixGenerator(generated_data)
          generated_data = generateVariables(generated_data)
          variable_values = generated_data[variables]
          change_variables = generated_data$variables[
            substr(
              generated_data$variables, 1,
              regexpr("\\[", generated_data$variables) - 1
            ) %in% basicChangeVariables
          ]
          list(
            data = generated_data,
            variable_values = variable_values,
            change_variables = change_variables,
            sparse_state = sparse_make_state(list()),
            sparse_index = list(),
            source_data = source_record,
            loaded_engine = "legacy"
          )
        }
      }, error = function(error) {
        if (inherits(error, "GEModelR_validation_error")) stop(error)
        remediation = if (grepl("Sparse TABLO compilation failed",
                                conditionMessage(error), fixed = TRUE)) {
          list(
            next_method = "loadTablo",
            action = "Correct the TABLO compilation issue and reload it with loadTablo()"
          )
        } else {
          list(
            next_method = "loadData",
            action = "Retry loadData() with valid model data for the selected engine"
          )
        }
        .gemodelr_abort_validation(
          sprintf("Unable to initialize the %s runtime: %s", engine,
                  conditionMessage(error)),
          "loadData", remediation$next_method, remediation$action,
          fields = list(
            argument = "inputData",
            requested_engine = engine,
            cause = conditionMessage(error),
            failure_phase = "loadData"
          )
        )
      })

      data <<- prepared$data
      variableValues <<- prepared$variable_values
      changeVariables <<- prepared$change_variables
      sparseState <<- prepared$sparse_state
      sparseIndex <<- prepared$sparse_index
      sourceData <<- prepared$source_data
      loadedEngine <<- prepared$loaded_engine
      solution <<- numeric()
      lastDiagnostics <<- list()
      compactOutput <<- list()
      .postsimRecord <<- list()
      invisible(.self)
    },
    setShocks = function(shocks) {
      shocks <<- shocks
      explicitShocks <<- sparse_normalize_shocks(shocks)
    },
    setClosure = function(exogenous_variables) {
      sparse_set_closure_state(.self, exogenous_variables)
    },
    setMemoryBudget = function(bytes) {
      sparse_set_memory_budget_state(.self, bytes)
    },
    estimateMemory = function(engine = c("legacy", "sparse"),
                              postsim = TRUE) {
      engine = .gemodelr_match_arg(
        engine, c("legacy", "sparse"), "estimateMemory", "engine",
        "Call estimateMemory() with engine = 'legacy' or engine = 'sparse'"
      )
      .gemodelr_require_runtime(.self, "estimateMemory", engine)
      if (!is.logical(postsim) || length(postsim) != 1L || is.na(postsim)) {
        .gemodelr_abort_validation(
          "postsim must be one non-missing logical value",
          "estimateMemory", "estimateMemory",
          "Call estimateMemory() with postsim = TRUE or postsim = FALSE",
          fields = list(argument = "postsim", requested_value = postsim)
        )
      }
      if (engine == "sparse") {
        if (!length(sparseIndex)) {
          .gemodelr_abort_validation(
            "Sparse runtime structures are unavailable",
            "estimateMemory", "loadData",
            "Call loadData(engine = 'sparse') before estimateMemory()",
            fields = list(requested_engine = engine,
                          loaded_engine = loadedEngine)
          )
        }
        idx = sparse_rebuild_columns(sparseIndex, closure)
        if (!isTRUE(idx$row_layout_ready) && is.environment(sparseState)) {
          idx = sparse_build_row_layout(sparseSpec, idx, sparseState)
        }
        idx = sparse_select_simulation_index(
          idx, sparseSpec, sparseState, postsim = postsim
        )
        return(sparse_estimate_memory(
          .self, idx, engine = engine, budget = memoryBudget,
          postsim = postsim, state = sparseState
        ))
      }
      list(
        engine = "legacy",
        har_input_bytes = as.numeric(object.size(data)),
        dense_fallback = TRUE,
        post_simulation_retained = isTRUE(postsim)
      )
    },
    retryPostsim = function(diagnostics = FALSE) {
      if (!is.logical(diagnostics) || length(diagnostics) != 1L ||
          is.na(diagnostics)) {
        .gemodelr_abort_validation(
          "diagnostics must be one non-missing logical value",
          "retryPostsim", "retryPostsim",
          "Call retryPostsim() with diagnostics = TRUE or FALSE",
          fields = list(argument = "diagnostics",
                        requested_value = diagnostics)
        )
      }
      .gemodelr_require_runtime(.self, "retryPostsim")
      if (!length(.postsimRecord)) {
        next_method = if (identical(loadedEngine, "sparse")) {
          "solveModel"
        } else {
          "loadData"
        }
        action = if (identical(loadedEngine, "sparse")) {
          "Run a sparse solve with postsim = TRUE; retry after a retryable postsimulation failure"
        } else {
          "Call loadData(engine = 'sparse') before requesting a retryable postsimulation solve"
        }
        .gemodelr_abort_validation(
          "No retryable post-simulation record is available",
          "retryPostsim", next_method, action,
          fields = list(required_method = next_method,
                        loaded_engine = loadedEngine)
        )
      }
      .retry_postsim_from_record(.self, diagnostics = diagnostics)
    },
    saveState = function(file) {
      if ({ .serialization_guard_old_options(); !is.character(file) } ||
          length(file) != 1L || is.na(file) || !nzchar(file)) {
        stop("file must be one non-empty path", call. = FALSE)
      }
      payload = .build_logical_state_payload(.self)
      saveRDS(payload, file, version = 3L)
      invisible(.self)
    },
    loadState = function(file) {
      if ({ .serialization_guard_old_options(); !is.character(file) } ||
          length(file) != 1L || is.na(file) || !nzchar(file) ||
          !file.exists(file) || !file_test("-f", file)) {
        stop("file must identify one existing logical-state payload",
             call. = FALSE)
      }
      size = file.info(file)$size
      if (is.na(size) || size < 1 ||
          size > .serialization_max_bytes()) {
        stop("Logical-state file is empty or exceeds the configured size limit",
             call. = FALSE)
      }
      payload = tryCatch(
        readRDS(file),
        error = function(error) {
          .serialization_stop(sprintf(
            "RDS decoding failed: %s", conditionMessage(error)
          ))
        }
      )
      restored = .restore_logical_state_payload(payload)
      .install_restored_logical_state(.self, restored)
    },
    generateSolution = function(subShocks){
      #browser()
      iNames = unlist(Map(function(i)
        i$equation, data$equationMatrixList))
      iNumbers = data$equationNumbers[iNames]
      jNames = unlist(Map(function(i)
        i$variable, data$equationMatrixList))
      jNumbers = data$variableNumbers[jNames]

      invisible(NULL)
      xValues = unlist(Map(
        function(i)
          i$expression,
        data$equationMatrixList
      ))

      names(xValues) = unlist(Map(
        function(i)
          i$variable,
        data$equationMatrixList
      ))

      #pctChanges = setdiff(names(xValues),changeVariables)
      #toChange = which(names(xValues) %in% relChangeVariables)

      #browser()

      #xValues[pctChanges] = xValues[pctChanges] * 0.01
      #xValues2[relChangeVariables] = xValues2[relChangeVariables] * 0.01

      invisible(NULL)

      #browser()

      data$eqcoeff = Matrix::sparseMatrix(
        i = iNumbers,
        j = jNumbers,
        x = xValues,
        dims = c(length(data$equations), length(data$variables)),
        dimnames = list(
          equations = data$equations,
          variables = data$variables
        )
      )


      bigMatrix = data$eqcoeff[, setdiff(colnames(data$eqcoeff), names(shocks)), drop = FALSE]

      #browser()

      smallMatrix = data$eqcoeff[, names(shocks), drop  = FALSE]

      # ### Do backsolving first
      # bigMatrix2 = as(bigMatrix, 'TsparseMatrix')
      # tt=table(bigMatrix2@j)
      # removeJ=bigMatrix2@j[which(bigMatrix2@j %in% as.numeric(names(tt)[tt==1]))]
      # removeI=bigMatrix2@i[which(bigMatrix2@j %in% as.numeric(names(tt)[tt==1]))]
      #
      # keepI=setdiff(1:dim(bigMatrix)[1] ,removeI+1)
      # keepJ=setdiff(1:dim(bigMatrix)[1] ,removeJ+1)
      #
      # backSolveMatrixLeft = bigMatrix[removeI+1,keepJ, drop = FALSE]
      # backSolveMatrixRight = bigMatrix[removeI+1,removeJ+1, drop = FALSE]
      # bigMatrixReduced=bigMatrix[keepI,keepJ, drop = FALSE]

      exoVector=-smallMatrix %*% subShocks

      # exoVectorReduced = exoVector[keepI,,drop=FALSE]
      #
      # tictoc::tic()
      # solutionReduced = SparseM::solve(bigMatrixReduced,exoVectorReduced,sparse=T,tol=1e-40)
      # tictoc::toc()
      #
      # #browser()
      #
      # solutionExtra = SparseM::solve(backSolveMatrixRight,-backSolveMatrixLeft%*%solutionReduced,sparse=T,tol=1e-40)
      #
      # iterationSolution =c(solutionExtra,solutionReduced) [colnames(bigMatrix)]

      iterationSolution=SparseM::solve(bigMatrix,exoVector,sparse=T,tol=1e-40)

      return(iterationSolution)
    },
    solveModel = function(iter = 3, steps = c(1,3),
                          engine = c("legacy", "sparse"),
                          postsim = TRUE, diagnostics = FALSE,
                          output = c("full", "compact"),
                          variables = NULL, dimensions = NULL,
                          backend = "Matrix",
                          reduction = c("auto", "off", "on"),
                          memory_budget = NULL) {
      engine = .gemodelr_match_arg(
        engine, c("legacy", "sparse"), "solveModel", "engine",
        "Call solveModel() with engine = 'legacy' or engine = 'sparse'"
      )
      .gemodelr_require_runtime(.self, "solveModel", engine)
      if (engine == "sparse") {
        return(sparse_solve_model(
          .self, iter = iter, steps = steps, postsim = postsim,
          diagnostics = diagnostics, output = output,
          variables = variables, dimensions = dimensions,
          backend = backend, reduction = reduction,
          memory_budget = memory_budget
        ))
      }

      if (!isTRUE(getOption("GEModelR.legacy.transaction.working"))) {
        old_transaction_option = getOption(
          "GEModelR.legacy.transaction.working"
        )
        options(GEModelR.legacy.transaction.working = TRUE)
        on.exit(options(
          GEModelR.legacy.transaction.working = old_transaction_option
        ), add = TRUE)
        tryCatch({
          working = .self$copy(shallow = FALSE)
          working$solveModel(
            iter = iter,
            steps = steps,
            engine = "legacy",
            postsim = postsim,
            diagnostics = diagnostics,
            output = output,
            variables = variables,
            dimensions = dimensions,
            backend = backend,
            reduction = reduction,
            memory_budget = memory_budget
          )
          .commit_legacy_state(
            .self, working, diagnostics = diagnostics
          )
        }, error = function(error) {
          lastDiagnostics <<- .transaction_failure_diagnostics(
            "legacy", error
          )
          stop(error)
        })
        return(invisible(NULL))
      }

      .transaction_fault("compilation")

      # Create a shock variable

      #browser()

      if (!is.null(explicitShocks) && length(explicitShocks$labels)) {
        shocks <<- legacy_shocks_from_explicit(.self)
      } else {
        shockPieces = unname(Map(function(f){
          toVector(variableValues[[f]],f)
        }, names(variableValues)))
        resolvedShocks = if (length(shockPieces)) {
          do.call(c, shockPieces)
        } else {
          setNames(numeric(), character())
        }
        keepShocks = !is.na(resolvedShocks)
        resolvedShocks = setNames(
          as.numeric(resolvedShocks[keepShocks]), names(resolvedShocks)[keepShocks]
        )
        if (!length(resolvedShocks)) {
          variableLabels = as.character(data$variables)
          variableNames = tolower(sub("\\[.*$", "", variableLabels))
          closureLabels = variableLabels[variableNames %in% closure]
          resolvedShocks = setNames(
            numeric(length(closureLabels)), closureLabels
          )
        }
        shocks <<- resolvedShocks
      }

      #browser()

      # shocks for change variables are not compounded
      #subShocks = shocks/iter

      # # list of relevant change variables in shocks
      # pctChangeShocks = setdiff(names(subShocks), changeVariables)
      #
      # # shocks need to be split for each subinterval
      # subShocks[pctChangeShocks] = (exp(log(1+shocks[pctChangeShocks]/100)/iter)-1)*100


      #names(subShocks)=names(shocks)

      solution <<- as.numeric(c())

      iterationSolution = list()

      appliedShocks = shocks
      appliedShocks[] = 0

      # Go through each iteration (subinterval)
      for (it in 1:iter) {
        message(sprintf('Iteration %s/%s', it, iter))

        remainingShocks = ((1+shocks/100)/(1+appliedShocks/100)-1)*100
        subShocks = remainingShocks/(iter-it+1)

        appliedShocks = ((1+ appliedShocks/100) * (1+subShocks/100)-1)*100

        # Within each iteration (subinterval) do steps

        # Save the state of the model
        originalData = data

        stepSolution = list()

        for(step in 1:length(steps)){

          message(sprintf('Step set %s/%s', step,length(steps)))

          # In each step set start from the original state of data
          data <<- originalData

          # Except for change variables...
          # stepShocks = subShocks/steps[step]

          # .... step shocks are compunded
          #stepShocks[pctChangeShocks] =  (exp(log(1+subShocks[pctChangeShocks]/100)/steps[step])-1)*100

          subStepSolution=list()

          appliedSubShocks = subShocks
          appliedSubShocks[] = 0


          for(currentStep in 1:steps[step]){

            remainingSubShocks = ((1+subShocks/100)/(1+appliedSubShocks/100)-1)*100

            stepShocks = remainingSubShocks/(steps[step]-currentStep+1)

            appliedSubShocks = ((1+ appliedSubShocks/100) * (1+stepShocks/100)-1)*100


            data <<- equationCoefficientGenerator(data)
            message(sprintf('Step %s/%s', currentStep,steps[step]))
            #browser()
            # Solve the model for this shock
            .transaction_fault("factorization")
            subStepSolution[[currentStep]] = generateSolution(stepShocks)
            .transaction_fault("convergence")
            .transaction_fault("finiteness")
            if (any(!is.finite(subStepSolution[[currentStep]]))) {
              stop(
                "Legacy solve produced a non-finite candidate solution",
                call. = FALSE
              )
            }
            .transaction_fault("residual")

            # Update the variables
            data <<- within(data,{
              eval(parse(text=sprintf("%s=%s;", names(subStepSolution[[currentStep]]), subStepSolution[[currentStep]][names(subStepSolution[[currentStep]])])))
            })

            # Update the shocked variables
            data <<- within(data,{
              eval(parse(text=sprintf("%s=%s;", names(stepShocks), stepShocks[names(stepShocks)])))
            })

            # Update the data
            .transaction_fault("simulation-update")
            data <<- generateUpdates(data)

          }
          #browser()


          subStepMatrix = do.call(cbind, lapply(
            subStepSolution, as.numeric
          ))
          row_names = rownames(subStepSolution[[1]])
          if (is.null(row_names)) row_names = names(subStepSolution[[1]])
          if (!is.null(row_names)) rownames(subStepMatrix) = row_names
          stepSolution[[step]] = rowSums(subStepMatrix)

          solutionPctChangeVariables = setdiff(names(stepSolution[[step]]), changeVariables)

          stepSolution[[step]][solutionPctChangeVariables] = ((apply(
            subStepMatrix / 100 + 1, MARGIN = 1, FUN = prod
          ) - 1) * 100)[solutionPctChangeVariables]
          #browser()
          # If any step <-100 we have to treat it as a change variable (like GEMPACK)
          # sols = apply(do.call(cbind,subStepSolution)<=-100,MARGIN = 1, any)
          #
          # solutionPctChangeVariables=setdiff(solutionPctChangeVariables, names(sols[sols]))

          #stepSolution[[step]][solutionPctChangeVariables] = (exp(rowSums(log(1+do.call(cbind,subStepSolution)[solutionPctChangeVariables,, drop = FALSE]/100)))-1)*100
        }

        #browser()

        if(length(steps)==1){

          # We only have one set of steps--this is the solution
          iterationSolution[[it]] = stepSolution[[1]]

        } else if(length(steps)==2) {

          # We have two sets of steps and so we can extrapolate
          #browser()
          iterationSolution[[it]] = colSums(t(do.call(cbind,stepSolution)) * (steps[c(1,2)] * c(1,-1))) / (steps[1]-steps[2])



        } else if(length(steps)==3) {

          # We have three sets of steps and so we can extrapolate and provide accuracy
          iterationSolution[[it]] = colSums(t(do.call(cbind,stepSolution)) * (steps[c(2,3)] * c(1,-1))) / (steps[2]-steps[3])

        }

        # tictoc::tic()
        # data <<- equationCoefficientGenerator(data)
        # tictoc::toc()
        #
        # iterationSolution = generateSolution(subShocks)
        #
        # if (length(solution)==0) {
        #   solution <<- c(iterationSolution, shocks)
        # } else{
        #
        #   namesToUse = names(solution)
        #   intermediateSolution = ifelse(names(c(iterationSolution, shocks)) %in% changeVariables, solution + c(iterationSolution, shocks), ((1 + solution / 100) * (1 + c(iterationSolution, shocks) / 100) - 1) * 100)
        #   names(intermediateSolution)=namesToUse
        #   solution<<-intermediateSolution
        # }

        #browser()

        data <<-originalData

        invisible(NULL)
        data <<- within(data,{
          eval(parse(text=sprintf("%s=%s;", names(iterationSolution[[it]]), iterationSolution[[it]][names(iterationSolution[[it]])])))
        })
        invisible(NULL)


        invisible(NULL)
        data <<- within(data,{
          eval(parse(text=sprintf("%s=%s;", names(shocks), subShocks[names(shocks)])))
        })
        invisible(NULL)

        #browser()
        .transaction_fault("simulation-update")
        data <<- generateUpdates(data)
      }

      #browser()

      if(length(iterationSolution)==1){
        solution <<- iterationSolution[[1]]
      } else {
        iterationMatrix = do.call(cbind, lapply(
          iterationSolution, as.numeric
        ))
        row_names = rownames(iterationSolution[[1]])
        if (is.null(row_names)) row_names = names(iterationSolution[[1]])
        if (!is.null(row_names)) rownames(iterationMatrix) = row_names
        solution <<- rowSums(iterationMatrix)
        solutionPctChangeVariables = setdiff(names(solution), changeVariables)
        solution[solutionPctChangeVariables] <<- ((apply(
          1 + iterationMatrix / 100, MARGIN = 1, FUN = prod
        ) - 1) * 100)[solutionPctChangeVariables]
      }

      #solution[solutionPctChangeVariables]<<- (exp(rowSums(log(1+do.call(cbind,iterationSolution)[solutionPctChangeVariables,, drop = FALSE]/100)))-1)*100

      invisible(NULL)
      data <<- within(data,{
        eval(parse(text=sprintf("%s=%s;", names(solution), solution[names(solution)])))
      })
      invisible(NULL)

      invisible(NULL)
      data <<- within(data,{
        eval(parse(text=sprintf("%s=%s;", names(shocks), shocks[names(shocks)])))
      })

      invisible(NULL)

    }
  )
)
