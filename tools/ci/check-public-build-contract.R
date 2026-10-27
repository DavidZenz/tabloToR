checkPublicBuildContract = function(root = getwd(), inspectPrivate = TRUE) {
  root = normalizePath(root, winslash = "/", mustWork = TRUE)
  tool = new.env(parent = globalenv())
  sys.source(file.path(root, "tools", "ci", "verify-matrix-floor-evidence.R"), tool)
  sys.source(file.path(root, "tools", "ci", "check-license-decision.R"), tool)
  directory = file.path(root, "inst", "compatibility")
  path = tool$licenseEvidencePath(root, "inst/compatibility/matrix-support.dcf")
  metadata = tool$matrixEvidenceDcf(path, c("Schema", "Minimum", "Maximum",
    "Evidence-File", "Evidence-MD5", "Evidence-Kind", "Evidence-Run"))
  if (metadata$Schema != "gemodelr-matrix-support-v1" ||
      metadata$`Evidence-Kind` != "recorded-hosted-results" ||
      metadata$`Evidence-File` != "matrix-supported.csv" ||
      !grepl("^[1-9][0-9]+$", metadata$`Evidence-Run`)) {
    stop("Invalid public Matrix support record", call. = FALSE)
  }
  evidence = tool$licenseEvidencePath(root, "inst/compatibility/matrix-supported.csv")
  tool$matrixEvidenceDigest(evidence, metadata$`Evidence-MD5`)
  rows = tool$readMatrixEvidence(evidence)
  floor = metadata$Minimum
  maximum = metadata$Maximum
  expected = expand.grid(alias = c("oldrel-1", "release", "devel"),
    pair = tool$matrixEvidencePairs, candidate = c("minimum", "current"),
    stringsAsFactors = FALSE)
  keys = paste(expected$alias, expected$pair, expected$candidate,
    ifelse(expected$candidate == "minimum", floor, maximum), sep = "/")
  excluded = expand.grid(alias = c("release", "devel"),
    pair = c("macOS/serial", "Windows/serial", "Windows/openmp"), stringsAsFactors = FALSE)
  excludedKeys = paste(excluded$alias, excluded$pair, "minimum", floor, sep = "/")
  if (nrow(rows) != 24L || !all(tool$matrixEvidencePass(rows)) ||
      !setequal(tool$matrixEvidenceKeys(rows), setdiff(keys, excludedKeys)) ||
      any(rows$run_id != metadata$`Evidence-Run`)) {
    stop("Public Matrix support tuples are incomplete or inconsistent", call. = FALSE)
  }
  description = read.dcf(file.path(root, "DESCRIPTION"))
  imports = trimws(strsplit(description[1L, "Imports"], ",", fixed = TRUE)[[1L]])
  matrix = imports[grepl("^Matrix($|[[:space:](])", imports)]
  if (!identical(matrix, paste0("Matrix (>= ", floor, ")")) ||
      !any(grepl(paste0("Matrix support: ", floor, " through ", maximum),
                readLines(file.path(root, "README.md")), fixed = TRUE))) {
    stop("Public Matrix metadata disagrees with DESCRIPTION or README", call. = FALSE)
  }
  private = file.path(root, ".planning", "phases", "05-portable-native-build-and-ci", "MATRIX-FLOOR-EVIDENCE.md")
  if (isTRUE(inspectPrivate) && file.exists(private)) {
    tool$verifyMatrixFinalMetadata(private, file.path(root, "DESCRIPTION"), file.path(root, "README.md"))
  }
  cat("Public Matrix contract: 24 supported tuples; six failed-source exclusions retained.\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) checkPublicBuildContract()
