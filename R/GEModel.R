# properties:
#   TABLO as a recipe
#   data files as data
#   exogenous variables as a definition
# methods:
#   solve the model (for the given coefficients)
#   update data (execute all updates/formulas always)

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
    compactOutput = 'list'
  ),
  methods = list(
    # Loads a tablo without any data (only produces generic functions to genrate coefficients/equation coefficients etc.)
    loadTablo = function(tabloPath) {
      legacy_results = tryCatch(processTablo(tabloPath),
                                error = function(e) NULL)
      sparse_results = tryCatch(sparse_process_tablo(tabloPath),
                                error = function(e) NULL)
      results = if (!is.null(legacy_results)) legacy_results else sparse_results
      if (is.null(results)) {
        stop(sprintf("Unable to process TABLO file: %s", tabloPath),
             call. = FALSE)
      }
      skeletonGenerator <<- results$skeletonGenerator
      sparseSkeletonGenerator <<- if (!is.null(sparse_results)) {
        sparse_results$skeletonGenerator
      } else results$skeletonGenerator

      equationCoefficientMatrixGenerator <<-
        results$equationCoefficientMatrixGenerator
      equationCoefficientGenerator <<- results$equationCoefficientGenerator
      generateVariables <<- results$generateVariables
      generateUpdates <<- results$generateUpdates
      if(!is.null(results$changeVariables)){
      basicChangeVariables <<- results$changeVariables
      }
      variables <<- results$variables
      tabloStatements <<- results$statements
      sparseSpec <<- if (!is.null(sparse_results) &&
                          !is.null(sparse_results$sparseSpec)) {
        sparse_results$sparseSpec
      } else if (!is.null(results$sparseSpec)) {
        results$sparseSpec
      } else sparse_compile_spec(tabloStatements)
      loadedEngine <<- character()
    },
    loadData = function(inputData, engine = c("legacy", "sparse")) {
      #browser()
      engine = match.arg(engine)
      generator = if (engine == "sparse" &&
                      is.function(sparseSkeletonGenerator)) {
        sparseSkeletonGenerator
      } else skeletonGenerator
      data <<- generator(inputData)
      if (engine == "sparse") {
        data <<- generateVariables(data)
        variableValues <<- list()
        changeVariables <<- basicChangeVariables
        sparseState <<- sparse_make_state(data)
        sparseIndex <<- sparse_build_index(sparseSpec, data)
        sparseIndex <<- sparse_rebuild_columns(sparseIndex, closure)
        sparseIndex <<- sparse_build_row_layout(sparseSpec, sparseIndex, sparseState)
        sparse_initialize_update_targets(
          sparseState, sparseIndex, sparseSpec,
          updates = sparseSpec$simulation_updates
        )
        sparse_apply_updates(
          sparseState, sparseIndex, sparseSpec,
          updates = sparseSpec$formula_initialization_updates
        )
        sourceData <<- list()
        loadedEngine <<- "sparse"
        return(invisible(.self))
      }
      data <<- equationCoefficientMatrixGenerator(data)
      data <<- generateVariables(data)
      variableValues <<- data[variables]
      changeVariables <<- data$variables[substr(data$variables,1,regexpr('\\[',data$variables)-1) %in% basicChangeVariables]
      loadedEngine <<- "legacy"
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
      engine = match.arg(engine)
      if (engine == "sparse") {
        if (!length(sparseIndex)) {
          stop("Sparse engine is not loaded; call loadData(engine='sparse')",
               call. = FALSE)
        }
        idx = sparse_rebuild_columns(sparseIndex, closure)
        if (!isTRUE(idx$row_layout_ready) && is.environment(sparseState)) {
          idx = sparse_build_row_layout(sparseSpec, idx, sparseState)
        }
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
      engine = match.arg(engine)
      if (engine == "sparse") {
        return(sparse_solve_model(
          .self, iter = iter, steps = steps, postsim = postsim,
          diagnostics = diagnostics, output = output,
          variables = variables, dimensions = dimensions,
          backend = backend, reduction = reduction,
          memory_budget = memory_budget
        ))
      }

      # Create a shock variable

      #browser()

      if (!is.null(explicitShocks) && length(explicitShocks$labels)) {
        shocks <<- legacy_shocks_from_explicit(.self)
      } else {
        shocks <<- do.call(c,unname(Map(function(f){
          toVector(variableValues[[f]],f)
        }, names(variableValues))))
        shocks <<- shocks[!is.na(shocks)]
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
            subStepSolution[[currentStep]] = generateSolution(stepShocks)

            # Update the variables
            data <<- within(data,{
              eval(parse(text=sprintf("%s=%s;", names(subStepSolution[[currentStep]]), subStepSolution[[currentStep]][names(subStepSolution[[currentStep]])])))
            })

            # Update the shocked variables
            data <<- within(data,{
              eval(parse(text=sprintf("%s=%s;", names(stepShocks), stepShocks[names(stepShocks)])))
            })

            # Update the data
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
