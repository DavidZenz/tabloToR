#!/usr/bin/env Rscript

# Bounded rejection probes use copies of authentic rows, never publish them.
source("tools/ci/verify-matrix-floor-evidence.R")
directory = ".planning/phases/05-portable-native-build-and-ci"
inputPath = file.path(directory, "matrix-candidate-evidence.csv")
supportedPath = file.path(directory,
  "hosted-evidence/matrix-candidate-evidence-37274723569-1.csv")
input = readMatrixEvidence(inputPath)
supported = readMatrixEvidence(supportedPath)
checks = 0L
pass = function(condition) {
  stopifnot(isTRUE(condition))
  checks <<- checks + 1L
}
reject = function(expression) {
  result = tryCatch({ force(expression); FALSE }, error = function(error) TRUE)
  pass(result)
}
result = validateMatrixEvidence(input, supported)
pass(identical(result$selected$version, "1.6-5"))
pass(identical(result$current, "1.7-6"))
pass(nrow(result$selected$rows) == 5L)
pass(nrow(result$excluded) == 6L)
pass(nrow(result$supported) == 24L)
pass(!length(result$selected$rejected))
floorIndex = which(input$setup_r_alias == "oldrel-1" & input$candidate_label == "minimum")
reject(validateMatrixEvidence(input[-floorIndex[[1L]], ], supported))
for (field in c("source_install_result", "solver_test_result")) {
  bad = input
  bad[floorIndex[[1L]], field] = "failure"
  reject(validateMatrixEvidence(bad, supported))
}
bad = supported
bad$solver_test_result[[1L]] = "failure"
reject(validateMatrixEvidence(input, bad))
bad = supported
bad$matrix_version[bad$candidate_label == "minimum"] = "1.6-4"
reject(validateMatrixEvidence(input, bad))
bad = supported
bad$resolved_r_version[bad$setup_r_alias == "oldrel-1"] = "4.5.2"
reject(validateMatrixEvidence(input, bad))
reject(validateMatrixEvidence(input, rbind(supported, supported[1L, ])))
reject(validateMatrixEvidence(input, supported[-which(supported$candidate_label == "current")[[1L]], ]))
reject(validateMatrixEvidence(input[input$source_install_result == "success", ], supported))
reject(validateMatrixEvidence(input[-which(input$candidate_label == "current")[[1L]], ], supported))
bad = input
bad$matrix_version[bad$candidate_label == "minimum"] = "1.6-6"
reject(selectMatrixFloor(bad))
successor = input[input$candidate_label == "minimum", ]
successor$matrix_version = "1.6-6"
successor$candidate_label = "fallback"
earlier = input
earlier$solver_test_result[floorIndex[[1L]]] = "failure"
reject(selectMatrixFloor(rbind(earlier, successor)))
history = data.frame(matrix_version = c("1.6-5", "1.6-6"),
  source_url = paste0("https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_",
    c("1.6-5", "1.6-6"), ".tar.gz"), requires_r = c("3.5", "3.5"),
  eligible = c("true", "true"), release_order = c("1", "2"))
pass(identical(selectMatrixFloor(rbind(earlier, successor), history)$rejected, "1.6-5"))
history$requires_r[[2L]] = "9.0"
reject(selectMatrixFloor(rbind(earlier, successor), history))
temporary = tempfile("matrix-evidence-probe-")
dir.create(temporary)
for (mutation in c("column", "run", "r", "duplicate", "version")) {
  bad = input
  if (mutation == "column") names(bad)[[1L]] = "wrong"
  if (mutation == "run") bad$run_id[[1L]] = "local"
  if (mutation == "r") bad$resolved_r_version[[1L]] = "4.7.1"
  if (mutation == "duplicate") bad = rbind(bad, bad[1L, ])
  if (mutation == "version") bad$matrix_version[[1L]] = "latest"
  path = file.path(temporary, paste0(mutation, ".csv"))
  write.csv(bad, path, row.names = FALSE)
  reject(readMatrixEvidence(path))
}
record = matrixFloorRecord(inputPath, supportedPath)
evidence = file.path(directory, "MATRIX-FLOOR-EVIDENCE.md")
pass(identical(readLines(evidence), record))
description = file.path(temporary, "DESCRIPTION")
readme = file.path(temporary, "README.md")
writeLines(c("Package: GEModelR", "Imports: Matrix (>= 1.6-5), Rcpp"), description)
writeLines("Matrix support: 1.6-5 through 1.7-6", readme)
pass(verifyMatrixFinalMetadata(evidence, description, readme))
writeLines("Matrix support: 1.6-4 through 1.7-6", readme)
reject(verifyMatrixFinalMetadata(evidence, description, readme))
writeLines("Matrix support: 1.6-5 through 1.7-6", readme)
writeLines(c("Package: GEModelR", "Imports: Matrix (>= 1.6-4), Rcpp"), description)
reject(verifyMatrixFinalMetadata(evidence, description, readme))
if ("--expect-final-metadata" %in% commandArgs(trailingOnly = TRUE)) {
  pass(verifyMatrixFinalMetadata(evidence))
} else {
  reject(verifyMatrixFinalMetadata(evidence))
}
unlink(temporary, recursive = TRUE)
cat("Matrix floor evidence checks passed:", checks, "\n")
