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

# Tamper only disposable copies; trusted normalized metadata and raw artifacts
# are checked independently from the user-submitted merged rows.
probeDirectory = file.path(temporary, "provenance")
dir.create(probeDirectory)
file.copy(inputPath, file.path(probeDirectory, basename(inputPath)))
file.copy(file.path(directory, "hosted-evidence"), probeDirectory, recursive = TRUE)
probeInput = file.path(probeDirectory, basename(inputPath))
probeSupported = file.path(probeDirectory, "hosted-evidence", basename(supportedPath))
run = unique(input$run_id)
manifest = file.path(probeDirectory, "hosted-evidence", paste0("hosted-run-", run, "-1.json"))
originalManifest = readBin(manifest, "raw", n = file.info(manifest)$size)
for (mutation in c("invalid JSON", "run", "attempt", "outcome", "artifact digest")) {
  text = rawToChar(originalManifest)
  if (mutation == "invalid JSON") text = "invalid JSON; no metadata"
  if (mutation == "run") text = sub(run, "99999999999", text, fixed = TRUE)
  if (mutation == "attempt") text = sub('"run_attempt": 1', '"run_attempt": 2', text, fixed = TRUE)
  if (mutation == "outcome") text = sub('"conclusion": "success"', '"conclusion": "failure"', text, fixed = TRUE)
  if (mutation == "artifact digest") text = sub("sha256:", "sha000:", text, fixed = TRUE)
  writeBin(charToRaw(text), manifest)
  reject(matrixFloorRecord(probeInput, probeSupported))
}
writeBin(originalManifest, manifest)
normalizedPath = file.path(probeDirectory, "hosted-evidence", paste0("hosted-provenance-", run, "-1.csv"))
dcfPath = sub("[.]csv$", ".dcf", normalizedPath)
originalRows = readBin(normalizedPath, "raw", n = file.info(normalizedPath)$size)
originalDcf = readBin(dcfPath, "raw", n = file.info(dcfPath)$size)
for (mutation in c("run_attempt", "source_step", "solver_step", "job_conclusion",
                    "payload_sha256", "failure_reason")) {
  bad = read.csv(normalizedPath, colClasses = "character", check.names = FALSE)
  index = if (mutation == "failure_reason") which(bad$source_step == "failure")[[1L]] else 1L
  bad[index, mutation] = switch(mutation, run_attempt = "2", source_step = "failure",
    solver_step = "failure", job_conclusion = "failure", payload_sha256 = "",
    failure_reason = "invented compiler error")
  write.csv(bad, normalizedPath, row.names = FALSE)
  # First reject the broken normalization digest. Then reseal only its table
  # hash to exercise the independent semantic and retained-payload checks.
  reject(matrixFloorRecord(probeInput, probeSupported))
  metadata = read.dcf(dcfPath)
  metadata[1L, "RowsMD5"] = unname(tools::md5sum(normalizedPath))
  write.dcf(metadata, dcfPath)
  reject(matrixFloorRecord(probeInput, probeSupported))
  writeBin(originalRows, normalizedPath)
  writeBin(originalDcf, dcfPath)
}
bad = read.csv(normalizedPath, colClasses = "character", check.names = FALSE)
payloadPath = file.path(probeDirectory, "hosted-evidence", bad$payload_file[[1L]])
payload = readBin(payloadPath, "raw", n = file.info(payloadPath)$size)
writeBin(charToRaw("altered artifact CSV"), payloadPath)
reject(matrixFloorRecord(probeInput, probeSupported))
writeBin(payload, payloadPath)
unlink(payloadPath)
reject(matrixFloorRecord(probeInput, probeSupported))
writeBin(payload, payloadPath)
failurePath = file.path(probeDirectory, "hosted-evidence",
  bad$failure_log_file[which(bad$source_step == "failure")[[1L]]])
writeLines("error: forged compiler reason", failurePath)
reject(matrixFloorRecord(probeInput, probeSupported))
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
