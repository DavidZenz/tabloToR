compatibilityManifestPath = function() {
  installed = system.file(
    "compatibility", "GEModel-contract.csv",
    package = "tabloToR"
  )
  source = testthat::test_path(
    "..", "..", "inst", "compatibility", "GEModel-contract.csv"
  )
  candidates = c(installed, source)
  candidates = candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(candidates)) {
    stop("Compatibility manifest is missing", call. = FALSE)
  }
  normalizePath(candidates[[1]], mustWork = TRUE)
}

loadCompatibilityManifest = function(path = compatibilityManifestPath()) {
  manifest = read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = character()
  )
  required = c(
    "kind", "name", "tier", "type", "signature", "defaults",
    "output", "serialization", "COMP_01", "COMP_02", "COMP_03", "notes"
  )
  missing_columns = setdiff(required, names(manifest))
  if (length(missing_columns)) {
    stop(sprintf(
      "Compatibility manifest is missing column(s): %s",
      paste(missing_columns, collapse = ", ")
    ), call. = FALSE)
  }

  keys = paste(manifest$kind, manifest$name, sep = ":")
  allowed_tiers = c("supported", "compatibility-only", "internal")
  trace_columns = c("COMP_01", "COMP_02", "COMP_03")
  if (any(!nzchar(manifest$kind)) || any(!nzchar(manifest$name)) ||
      any(!nzchar(manifest$type))) {
    stop("Compatibility manifest contains an empty identity field", call. = FALSE)
  }
  if (anyDuplicated(keys)) {
    stop("Compatibility manifest contains duplicate kind/name rows", call. = FALSE)
  }
  if (any(!manifest$tier %in% allowed_tiers)) {
    stop("Compatibility manifest contains an invalid tier", call. = FALSE)
  }
  if (!all(vapply(manifest[trace_columns], is.logical, logical(1)))) {
    stop("Compatibility traceability columns must be logical", call. = FALSE)
  }
  if (any(rowSums(manifest[trace_columns]) == 0L)) {
    stop("Every compatibility row must trace to a COMP requirement", call. = FALSE)
  }
  manifest
}

observedCompatibilitySurface = function() {
  exports = grep(
    "^[[:alpha:]]",
    getNamespaceExports("tabloToR"),
    value = TRUE
  )
  inherited = methods::getRefClass("envRefClass")$methods()
  list(
    exports = sort(exports),
    fields = sort(names(GEModel$fields())),
    methods = sort(setdiff(GEModel$methods(), inherited)),
    backends = sort(c(
      "Matrix", "SuiteSparse", "SparseM", "StructuredSchur",
      "StructuredSchurFGMRES", "StructuredSchurFGMRESCpp"
    ))
  )
}

compatibilityFormalText = function(value) {
  text = paste(deparse(value, width.cutoff = 500L), collapse = "")
  if (!nzchar(text)) "<required>" else text
}

compatibilityMethodContract = function() {
  methods = observedCompatibilitySurface()$methods
  rows = lapply(methods, function(method) {
    method_formals = formals(GEModel$methods(method))
    defaults = vapply(seq_along(method_formals), function(index) {
      compatibilityFormalText(method_formals[[index]])
    }, character(1))
    data.frame(
      name = method,
      signature = paste(names(method_formals), collapse = ","),
      defaults = paste(
        paste0(names(method_formals), "=", defaults),
        collapse = ";"
      ),
      stringsAsFactors = FALSE
    )
  })
  contract = do.call(rbind, rows)
  rownames(contract) = NULL
  contract
}

describeCompatibilityStructure = function(value) {
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

compatibilityValuesEqual = function(actual, expected,
                                     check_encoding = TRUE) {
  if (!identical(actual, expected)) return(FALSE)
  if (!isTRUE(check_encoding)) return(TRUE)
  if (!is.character(actual) && !is.character(expected)) return(TRUE)
  if (!is.character(actual) || !is.character(expected)) return(FALSE)
  identical(unname(Encoding(actual)), unname(Encoding(expected)))
}

compatibilityDefaultEquivalent = function(method, argument, explicit) {
  if (!method %in% observedCompatibilitySurface()$methods) {
    stop(sprintf("Unknown GEModel method: %s", method), call. = FALSE)
  }
  method_formals = formals(GEModel$methods(method))
  if (!argument %in% names(method_formals)) {
    stop(sprintf("Unknown %s argument: %s", method, argument),
         call. = FALSE)
  }
  default_expression = method_formals[[argument]]
  if (identical(compatibilityFormalText(default_expression), "<required>")) {
    stop(sprintf("%s has no default for %s", method, argument),
         call. = FALSE)
  }
  default = eval(default_expression, envir = baseenv())
  if (argument %in% c("engine", "output", "reduction") &&
      length(default) > 1L) {
    default = default[[1L]]
  }
  compatibilityValuesEqual(default, explicit)
}
