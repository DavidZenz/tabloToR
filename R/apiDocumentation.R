#' GEModelR package
#'
#' GEModelR interprets GEMPACK-style TABLO models in R. The supported public
#' facade is the \code{GEModel} reference-class generator. It preserves the
#' established load, configure, solve, and inspect workflow while offering a
#' legacy in-memory engine and an opt-in sparse engine.
#'
#' @section Supported workflow:
#' Create an instance with \code{GEModel$new()}, load a TABLO file with
#' \code{loadTablo()}, and load its input data with \code{loadData()}. The
#' \code{engine} selected by \code{loadData()} initializes the model runtime;
#' \code{solveModel()} must use the same engine. To change engines, load the
#' data again. Configure model closure and shocks with \code{setClosure()} and
#' \code{setShocks()}, then solve and inspect the instance's solution,
#' \code{variableValues}, compact output, and \code{lastDiagnostics} fields.
#'
#' \preformatted{
#' model <- GEModel$new()
#' model$loadTablo("model.tab")
#' model$loadData(input_data, engine = "sparse")
#' model$setShocks(shocks)
#' model$solveModel(engine = "sparse", backend = "Matrix")
#' }
#'
#' @section Supported methods:
#' The supported reference-class methods are:
#' \describe{
#'   \item{\code{loadTablo(tabloPath)}}{Parse and compile a TABLO model.}
#'   \item{\code{loadData(inputData, engine = c("legacy", "sparse"))}}{Load
#'     input data and initialize the selected runtime.}
#'   \item{\code{setShocks(shocks)}}{Set explicit model shocks.}
#'   \item{\code{setClosure(exogenous_variables)}}{Set the exogenous-variable
#'     closure and invalidate dependent solve state.}
#'   \item{\code{setMemoryBudget(bytes)}}{Set this instance's sparse memory
#'     budget in bytes.}
#'   \item{\code{estimateMemory(engine = c("legacy", "sparse"), postsim = TRUE)}}{Estimate
#'     memory requirements for the selected runtime.}
#'   \item{\code{solveModel(iter = 3, steps = c(1, 3), engine = c("legacy", "sparse"), postsim = TRUE, diagnostics = FALSE, output = c("full", "compact"), variables = NULL, dimensions = NULL, backend = "Matrix", reduction = c("auto", "off", "on"), memory_budget = NULL)}}{Solve
#'     with an explicit engine and, for the sparse engine, an independent
#'     requested backend.}
#'   \item{\code{retryPostsim(diagnostics = FALSE)}}{Retry postsimulation from
#'     accepted numerical state without solving again.}
#'   \item{\code{saveState(file)} and \code{loadState(file)}}{Save or restore a
#'     validated version-1 logical model state.}
#' }
#' Use these methods for supported model changes. Compiler, source-data,
#' index, and cache fields are implementation state and are not supported
#' mutation inputs.
#'
#' @section Runtime engines and sparse backends:
#' The \code{engine} argument chooses the model runtime: \code{legacy} uses the
#' established in-memory solver and \code{sparse} uses sparse execution. The
#' sparse \code{backend} argument independently chooses a solver implementation
#' and defaults to \code{"Matrix"}. The recognized backend identifiers and
#' tiers are:
#' \describe{
#'   \item{\code{Matrix}}{Supported general sparse backend and default.}
#'   \item{\code{StructuredSchur} and
#'     \code{StructuredSchurFGMRES}}{Supported structured R backends.}
#'   \item{\code{SparseM} and
#'     \code{StructuredSchurFGMRESCpp}}{Compatibility-only backend requests.}
#'   \item{\code{SuiteSparse}}{Recognized but unavailable in supported installed
#'     builds pending portable support. Explicitly select \code{backend="Matrix"}
#'     for a supported sparse solve. An explicit SuiteSparse request fails
#'     capability preflight before matrix emission or runtime compilation.}
#' }
#' Optional backends can fail capability preflight when their requirements are
#' unavailable. A requested backend is not silently replaced by another
#' backend. The legacy engine is a separate runtime choice, not a sparse
#' backend.
#'
#' @section Output modes:
#' \code{solveModel(output = "full")} materializes the compatibility output
#' structure. Compact output and variable/dimension selectors are supported
#' only by the sparse engine; the legacy engine accepts full output and no
#' selectors. \code{output = "compact"} returns a compact projection; use
#' \code{variables} and \code{dimensions} to select the requested values and
#' labels. The defaults are \code{output = c("full", "compact")},
#' \code{variables = NULL}, and \code{dimensions = NULL}.
#'
#' @section Solve diagnostics and conditions:
#' Every solve attempt stores a version-1 envelope in
#' \code{model$lastDiagnostics}. Its stable fields are:
#' \describe{
#'   \item{\code{schema_version}}{Envelope schema version, currently 1.}
#'   \item{\code{engine}, \code{requested_backend},
#'     \code{implementation}}{Requested runtime/backend and the implementation
#'     that handled the request.}
#'   \item{\code{status}, \code{condition_class}}{Stable outcome status and
#'     primary condition class, when one applies.}
#'   \item{\code{accepted_numerical_state},
#'     \code{retryable_postsim}}{Whether a numerical state was accepted and
#'     whether postsimulation can be retried without another solve.}
#'   \item{\code{failure_phase}, \code{failure_reason}}{Failure location and
#'     reason for failed attempts.}
#'   \item{\code{cleanup_status}}{Solve-scoped cleanup outcome.}
#' }
#' Stable statuses are \code{running}, \code{succeeded},
#' \code{validation_failed}, \code{capability_failed},
#' \code{numerical_failed}, \code{postsim_failed}, and
#' \code{committed_state_failed}. Each attempt replaces the previous envelope
#' before validation or dispatch and stores its final success or ordinary
#' error outcome before returning or rethrowing, so an error does not leave a
#' stale success record. A postsimulation failure can report that its accepted
#' numerical state is retained and retryable through \code{retryPostsim()}.
#'
#' Stable primary condition classes are
#' \code{GEModelR_validation_error}, \code{GEModelR_capability_error},
#' \code{GEModelR_numerical_error}, \code{GEModelR_postsim_error},
#' \code{GEModelR_retryable_postsim_error}, and
#' \code{GEModelR_committed_state_error}. The retryable postsimulation class
#' also inherits from \code{GEModelR_postsim_error}. Set
#' \code{diagnostics = TRUE} in \code{solveModel()} or
#' \code{retryPostsim()} to add residual history, timings, allocation and
#' capability evidence, detailed cleanup, and memory estimates.
#'
#' @section Supported high-level options:
#' These options are read by the solver or logical-state serializer. They do
#' not change numerical defaults when unset.
#' \describe{
#'   \item{\code{GEModelR.sparse.lu_order}}{Integer from 0 through 3;
#'     default \code{3}. Controls sparse LU ordering where the selected sparse
#'     solve path uses LU factorization.}
#'   \item{\code{GEModelR.sparse.suite_sparse_ordering}}{Reserved SuiteSparse ordering;
#'     SuiteSparse is unavailable in supported installed builds, so this option
#'     does not enable that backend;
#'     default \code{"amd"}. Accepted values are \code{"cholmod"},
#'     \code{"amd"}, \code{"metis"}, \code{"best"}, \code{"natural"}, and
#'     \code{"none"}. \code{"given"} is rejected.}
#'   \item{\code{GEModelR.sparse.structured_residual_tolerance}}{Sparse
#'     candidate true-residual tolerance; default \code{2e-7}.}
#'   \item{\code{GEModelR.sparse.elimination_pivot_tolerance}}{Pivot
#'     tolerance for structured elimination; default \code{1e-12}.}
#'   \item{\code{GEModelR.sparse.schur_region_batch_size}}{Structured Schur
#'     region batch size; default \code{8}.}
#'   \item{\code{GEModelR.sparse.schur_panel_size}}{Structured Schur panel
#'     size; default \code{64}.}
#'   \item{\code{GEModelR.sparse.schur_restart}}{Structured Schur iterative
#'     solver restart size; default \code{80}.}
#'   \item{\code{GEModelR.sparse.schur_max_iterations}}{Structured Schur
#'     iterative solver iteration limit; default \code{500}.}
#'   \item{\code{GEModelR.sparse.schur_tolerance}}{Structured Schur iterative
#'     solver tolerance; default \code{2e-7}.}
#'   \item{\code{GEModelR.sparse.schur_cpp_threads}}{Requested thread count for
#'     the explicit C++ backend; default \code{1}.}
#'   \item{\code{GEModelR.serialization.max_bytes}}{Maximum logical-state
#'     payload size in bytes; default \code{268435456}.}
#'   \item{\code{GEModelR.serialization.max_elements}}{Maximum logical-state
#'     payload element count; default \code{50000000}.}
#' }
#' The existing \code{memory_budget} argument to \code{solveModel()} overrides
#' the per-instance budget for a solve, while \code{setMemoryBudget(bytes)}
#' sets that instance's budget. No global solver-memory option is defined.
#' Transaction/fault controls and structural or numerical caches are private
#' implementation details.
#'
#' @name GEModelR-package
#' @aliases GEModelR
#' @docType package
#' @keywords package
#' @useDynLib GEModelR, .registration = TRUE
#' @importFrom Rcpp evalCpp
#' @importFrom methods new
#' @importFrom stats setNames
#' @importFrom utils object.size
"_PACKAGE"
