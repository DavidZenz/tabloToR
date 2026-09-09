#!/usr/bin/env Rscript

phase02_stable_artifact_names = function() {
  c("expectations.csv", "tolerances.csv", "fingerprints.dcf")
}

phase02_max_artifact_bytes = function() 262144

phase02_script_path = local({
  source_files = vapply(sys.frames(), function(frame) {
    value = frame$ofile
    if (is.null(value) || !length(value)) "" else as.character(value[[1L]])
  }, character(1))
  source_files = source_files[nzchar(source_files)]
  file_argument = grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(source_files)) {
    normalizePath(tail(source_files, 1L), mustWork = TRUE)
  } else if (length(file_argument)) {
    normalizePath(sub("^--file=", "", file_argument[[1L]]), mustWork = TRUE)
  } else NA_character_
})

phase02_repository_root = function() {
  working = normalizePath(getwd(), mustWork = TRUE)
  ancestors = working
  while (!identical(tail(ancestors, 1L), dirname(tail(ancestors, 1L)))) {
    ancestors = c(ancestors, dirname(tail(ancestors, 1L)))
  }
  candidates = c(
    if (!is.na(phase02_script_path)) {
      dirname(dirname(phase02_script_path))
    } else character(),
    ancestors
  )
  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        dir.exists(file.path(candidate, "tests", "testthat"))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  stop("Could not locate the package repository root", call. = FALSE)
}

phase02_canonical_dir = function(root = phase02_repository_root()) {
  normalizePath(
    file.path(root, "tests", "testthat", "baselines", "phase02"),
    mustWork = TRUE
  )
}

phase02_path_key = function(path) {
  value = normalizePath(path, winslash = "/", mustWork = FALSE)
  value = sub("/+$", "", value)
  if (identical(.Platform$OS.type, "windows")) value = tolower(value)
  value
}

phase02_path_contains = function(parent, child) {
  parent = phase02_path_key(parent)
  child = phase02_path_key(child)
  identical(parent, child) || startsWith(child, paste0(parent, "/"))
}

phase02_normalize_proposal_dir = function(output,
                                           canonical_dir = phase02_canonical_dir()) {
  if (is.null(output) || length(output) != 1L || is.na(output) ||
      !nzchar(trimws(output))) {
    stop("An explicit proposal directory is required", call. = FALSE)
  }
  output = path.expand(output)
  parent = dirname(output)
  if (!dir.exists(parent)) {
    stop("The proposal directory parent must already exist", call. = FALSE)
  }
  parent = normalizePath(parent, mustWork = TRUE)
  output = file.path(parent, basename(output))
  if (dir.exists(output)) output = normalizePath(output, mustWork = TRUE)
  canonical_dir = normalizePath(canonical_dir, mustWork = TRUE)
  if (phase02_path_contains(canonical_dir, output)) {
    stop("Proposal output cannot target the canonical baseline directory",
         call. = FALSE)
  }
  if (phase02_path_contains(output, canonical_dir)) {
    stop("Proposal output overlaps the canonical baseline directory",
         call. = FALSE)
  }
  if (dir.exists(output) && nzchar(Sys.readlink(output))) {
    stop("Proposal output cannot be a symbolic link", call. = FALSE)
  }
  output
}

phase02_hash_file = function(path) {
  if (!file.exists(path) || dir.exists(path)) return(NA_character_)
  unname(tools::md5sum(normalizePath(path, mustWork = TRUE))[[1L]])
}

phase02_signature = function(value) {
  path = tempfile("phase02-signature-")
  on.exit(unlink(path), add = TRUE)
  lines = capture.output(dput(value, control = c("keepNA", "keepInteger")))
  writeLines(lines, path, useBytes = TRUE)
  phase02_hash_file(path)
}

phase02_artifact_hash = function(directory) {
  files = phase02_stable_artifact_names()
  hashes = vapply(files, function(name) {
    path = file.path(directory, name)
    hash = phase02_hash_file(path)
    if (is.na(hash)) "<missing>" else hash
  }, character(1))
  phase02_signature(as.list(stats::setNames(hashes, files)))
}

phase02_write_lines = function(lines, path, root) {
  root = normalizePath(root, mustWork = TRUE)
  target_parent = normalizePath(dirname(path), mustWork = TRUE)
  if (!phase02_path_contains(root, target_parent)) {
    stop("Refusing to write outside the explicit proposal directory",
         call. = FALSE)
  }
  if (file.exists(path) && nzchar(Sys.readlink(path))) {
    stop("Refusing to replace a symbolic-link proposal artifact",
         call. = FALSE)
  }
  writeLines(lines, path, useBytes = TRUE)
  size = file.info(path)$size
  if (!is.finite(size) || size > phase02_max_artifact_bytes()) {
    unlink(path)
    stop("Generated proposal artifact exceeds the size bound", call. = FALSE)
  }
  invisible(path)
}

phase02_write_csv = function(value, path, root) {
  temporary = tempfile("phase02-csv-")
  on.exit(unlink(temporary), add = TRUE)
  write.csv(value, temporary, row.names = FALSE, quote = TRUE,
            na = "", fileEncoding = "UTF-8")
  phase02_write_lines(readLines(temporary, warn = FALSE), path, root)
}

phase02_write_dcf = function(value, path, root) {
  temporary = tempfile("phase02-dcf-")
  on.exit(unlink(temporary), add = TRUE)
  write.dcf(as.data.frame(
    value, stringsAsFactors = FALSE, check.names = FALSE
  ), file = temporary,
            keep.white = names(value), useBytes = TRUE)
  phase02_write_lines(readLines(temporary, warn = FALSE), path, root)
}

phase02_package_version = function(package) {
  if (!requireNamespace(package, quietly = TRUE)) return("unavailable")
  as.character(utils::packageVersion(package))
}

phase02_runtime_environment = function(root) {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("The existing testthat/pkgload development runtime is required",
         call. = FALSE)
  }
  loaded_from_root = FALSE
  if ("tabloToR" %in% loadedNamespaces()) {
    namespace_path = tryCatch(
      getNamespaceInfo(asNamespace("tabloToR"), "path"),
      error = function(error) NA_character_
    )
    checked_source = length(namespace_path) == 1L &&
      !is.na(namespace_path) &&
      identical(basename(namespace_path), basename(root)) &&
      identical(dirname(root), file.path(dirname(namespace_path), "00_pkg_src"))
    loaded_from_root = length(namespace_path) == 1L &&
      !is.na(namespace_path) &&
      (identical(normalizePath(namespace_path, mustWork = TRUE), root) ||
       checked_source)
  }
  if (!loaded_from_root) {
    pkgload::load_all(root, quiet = TRUE, export_all = TRUE, helpers = FALSE)
  }
  environment = new.env(parent = globalenv())
  sys.source(file.path(root, "benchmarks", "benchmark_config.R"),
             envir = environment)
  sys.source(file.path(root, "tests", "testthat", "helper-compatibility.R"),
             envir = environment)
  sys.source(file.path(root, "tests", "testthat", "helper-three-region.R"),
             envir = environment)
  environment
}

phase02_source_files = function(root) {
  fixed = c("DESCRIPTION", "NAMESPACE")
  recursive = c(
    list.files(file.path(root, "R"), pattern = "\\.R$", recursive = TRUE,
               full.names = FALSE),
    file.path("src", list.files(
      file.path(root, "src"), pattern = "\\.(c|cc|cpp|h|hpp)$",
      recursive = TRUE, full.names = FALSE
    )),
    file.path("inst", "compatibility", list.files(
      file.path(root, "inst", "compatibility"),
      recursive = TRUE, full.names = FALSE
    )),
    file.path("tests", "testthat", "fixtures", c(
      "three-region.tab", "PROVENANCE.md"
    )),
    file.path("tests", "testthat", c(
      "helper-compatibility.R", "helper-three-region.R",
      "helper-numerical-baseline.R", "helper-transactional-state.R",
      "helper-serialization.R"
    ))
  )
  relative = unique(c(fixed, recursive))
  relative = relative[order(tolower(relative), relative, method = "radix")]
  relative[file.exists(file.path(root, relative))]
}

phase02_source_fingerprint = function(root) {
  relative = phase02_source_files(root)
  paths = file.path(root, relative)
  sizes = file.info(paths)$size
  if (any(!is.finite(sizes)) || any(sizes > 5 * 1024^2)) {
    stop("Source fingerprint input exceeds the per-file size bound",
         call. = FALSE)
  }
  hashes = unname(tools::md5sum(paths))
  phase02_signature(as.list(stats::setNames(hashes, relative)))
}

phase02_tolerances = function() {
  data.frame(
    fixture = c("three-region", "full-gtap-external", "tiny-structured"),
    conditioning = c("ordinary", "ill-conditioned", "ordinary"),
    tier = c("strict", "external", "strict"),
    solution_atol = c(1e-10, 1e-10, 1e-10),
    solution_rtol = c(1e-8, 2e-7, 1e-8),
    residual_rtol = c(1e-10, 2e-7, 1e-10),
    rationale = c(
      paste(
        "Transparent synthetic diagonal system with exact integer",
        "coefficients and no conditioning exception"
      ),
      paste(
        "Existing fingerprinted full-scale evidence; external only and",
        "never a backend-specific exception"
      ),
      paste(
        "Deterministic seven-position structured system with exact",
        "identity blocks and no conditioning exception"
      )
    ),
    reviewer = c(
      "Phase 02 Plan 03", "Phase 02 reviewed benchmark evidence",
      "Phase 02 Plan 03"
    ),
    stringsAsFactors = FALSE
  )
}

phase02_solve_fixture = function(root) {
  runtime = phase02_runtime_environment(root)
  started = proc.time()[["elapsed"]]
  model = runtime$make_three_region_model()
  runtime$set_three_region_shocks(model, "preferred", c(1, 2, -1))
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    diagnostics = TRUE, output = "full", backend = "Matrix",
    reduction = "off"
  )
  elapsed = proc.time()[["elapsed"]] - started
  solution = model$solution
  if (length(solution) != 3L || any(!is.finite(solution))) {
    stop("The complete three-region solution is not finite and length three",
         call. = FALSE)
  }
  residual = model$lastDiagnostics$max_full_relative_residual
  if (!length(residual) && length(model$lastDiagnostics$true_residual_history)) {
    residual = max(vapply(
      model$lastDiagnostics$true_residual_history,
      function(value) value$metrics$relative_l2,
      numeric(1)
    ))
  }
  if (!length(residual) || !is.finite(residual)) {
    stop("The three-region solve did not retain a finite true residual",
         call. = FALSE)
  }
  list(
    runtime = runtime, model = model, solution = solution,
    elapsed = elapsed, residual = residual
  )
}

phase02_expectations = function(solution) {
  stable_solution = signif(unname(solution), 15L)
  data.frame(
    fixture = c(rep("three-region", 6L), rep("tiny-structured", 2L)),
    authority = c(rep("Matrix", 6L), rep("StructuredSchurFGMRES", 2L)),
    kind = c("structure", "structure", "structure", rep("value", 3L),
             "structure", "value"),
    key = c(
      "solution.class", "solution.type", "solution.names",
      names(solution), "solution.length", "solution.sequence"
    ),
    value = c(
      class(solution)[[1L]], typeof(solution),
      paste(names(solution), collapse = "|"),
      format(stable_solution, digits = 17L, scientific = FALSE,
             trim = TRUE),
      "7", "1|2|3|4|5|6|7"
    ),
    rationale = c(
      "Exact public output structure", "Exact public output storage type",
      "Exact public output order", rep(
        "Selected transparent canonical value", 3L
      ),
      "Existing deterministic structured fixture dimension",
      "Compact deterministic authority values"
    ),
    stringsAsFactors = FALSE
  )
}

phase02_fingerprints = function(root, output, solved) {
  description = read.dcf(file.path(root, "DESCRIPTION"))[1L, ]
  fixture = file.path(root, "tests", "testthat", "fixtures",
                      "three-region.tab")
  provenance = file.path(root, "tests", "testthat", "fixtures",
                         "PROVENANCE.md")
  external = file.path(root, "benchmarks", "GTAP12A_CPP_RESULTS.md")
  source_fingerprint = phase02_source_fingerprint(root)
  input_signature = solved$runtime$benchmark_signature(
    solved$runtime$three_region_input_data()
  )
  model_signature = phase02_signature(list(
    fixture = phase02_hash_file(fixture),
    input = input_signature,
    closure = "tax",
    shocks = stats::setNames(
      c(1, 2, -1),
      c('tax["north"]', 'tax["south"]', 'tax["east"]')
    ),
    engine = "sparse", backend = "Matrix", reduction = "off",
    iter = 1L, steps = 1L, postsim = FALSE
  ))
  list(
    Schema = "phase02-baseline-fingerprints-v1",
    `Fixture-Path` = "tests/testthat/fixtures/three-region.tab",
    `Fixture-MD5` = phase02_hash_file(fixture),
    `Fixture-Provenance-Path` = "tests/testthat/fixtures/PROVENANCE.md",
    `Fixture-Provenance-MD5` = phase02_hash_file(provenance),
    `Fixture-Input-Signature` = input_signature,
    `Source-Scope` = paste(
      "DESCRIPTION; NAMESPACE; R/*.R; src/*.{c,cc,cpp,h,hpp};",
      "inst/compatibility/*; approved Phase 02 fixture/helper files;",
      "generated baselines and proposals excluded"
    ),
    `Source-File-Count` = as.character(length(phase02_source_files(root))),
    `Source-Fingerprint` = source_fingerprint,
    `Package-Name` = unname(description[["Package"]]),
    `Package-Version` = unname(description[["Version"]]),
    `Package-Signature` = phase02_signature(list(
      package = unname(description[["Package"]]),
      version = unname(description[["Version"]]),
      source = source_fingerprint
    )),
    `Model-Signature` = model_signature,
    `Expectations-MD5` = phase02_hash_file(
      file.path(output, "expectations.csv")
    ),
    `Tolerances-MD5` = phase02_hash_file(
      file.path(output, "tolerances.csv")
    ),
    `External-Evidence-Path` = "benchmarks/GTAP12A_CPP_RESULTS.md",
    `External-Evidence-MD5` = phase02_hash_file(external),
    `External-Inputs-Committed` = "false"
  )
}

phase02_run_metadata = function(solved) {
  runtime = solved$runtime
  list(
    Schema = "phase02-baseline-run-metadata-v1",
    `Generated-UTC` = format(Sys.time(), tz = "UTC", usetz = TRUE),
    `R-Version` = R.version.string,
    `Matrix-Version` = phase02_package_version("Matrix"),
    `Rcpp-Version` = phase02_package_version("Rcpp"),
    `SparseM-Version` = phase02_package_version("SparseM"),
    `testthat-Version` = phase02_package_version("testthat"),
    Platform = R.version$platform,
    CPU = as.character(runtime$benchmark_cpu()),
    `Physical-RAM-Bytes` = format(
      runtime$benchmark_physical_ram(), scientific = FALSE, trim = TRUE
    ),
    BLAS = runtime$benchmark_blas(),
    `Elapsed-Seconds` = format(solved$elapsed, digits = 17L),
    `Peak-RSS-Bytes` = format(
      runtime$benchmark_peak_rss(), scientific = FALSE, trim = TRUE
    ),
    `Solver-Backend` = "Matrix",
    `Solver-Engine` = "sparse",
    `Solver-Reduction` = "off",
    `Solver-Residual-Relative-L2` = format(
      solved$residual, digits = 17L, scientific = TRUE
    )
  )
}

phase02_read_csv_entries = function(path, identity_columns) {
  value = read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                   na.strings = character())
  if (!all(identity_columns %in% names(value))) {
    stop("required identity columns are missing")
  }
  row_key = apply(value[identity_columns], 1L, paste, collapse = "|")
  columns = setdiff(names(value), identity_columns)
  entries = lapply(columns, function(column) {
    data.frame(
      key = paste(row_key, column, sep = "|"),
      value = as.character(value[[column]]), stringsAsFactors = FALSE
    )
  })
  do.call(rbind, entries)
}

phase02_artifact_entries = function(directory) {
  readers = list(
    expectations.csv = function(path) phase02_read_csv_entries(
      path, c("fixture", "authority", "kind", "key")
    ),
    tolerances.csv = function(path) phase02_read_csv_entries(
      path, c("fixture", "conditioning")
    ),
    fingerprints.dcf = function(path) {
      value = read.dcf(path)
      if (nrow(value) != 1L) stop("expected exactly one DCF record")
      data.frame(
        key = names(value[1L, ]), value = as.character(value[1L, ]),
        stringsAsFactors = FALSE
      )
    }
  )
  entries = list()
  for (artifact in names(readers)) {
    path = file.path(directory, artifact)
    if (!file.exists(path)) {
      value = data.frame(key = "<artifact>", value = "<missing>")
    } else {
      value = tryCatch(
        readers[[artifact]](path),
        error = function(error) data.frame(
          key = "<artifact>",
          value = paste0("<corrupt: ", conditionMessage(error), ">"),
          stringsAsFactors = FALSE
        )
      )
    }
    value$artifact = artifact
    entries[[artifact]] = value[, c("artifact", "key", "value")]
  }
  do.call(rbind, entries)
}

phase02_diff_frame = function(old_dir, new_dir) {
  old = phase02_artifact_entries(old_dir)
  names(old)[names(old) == "value"] = "old"
  new = phase02_artifact_entries(new_dir)
  names(new)[names(new) == "value"] = "new"
  comparison = merge(old, new, by = c("artifact", "key"), all = TRUE,
                     sort = TRUE)
  comparison$old[is.na(comparison$old)] = "<missing>"
  comparison$new[is.na(comparison$new)] = "<missing>"
  comparison$status = ifelse(
    comparison$old == comparison$new, "unchanged",
    ifelse(comparison$old == "<missing>", "added",
           ifelse(comparison$new == "<missing>", "removed", "changed"))
  )
  comparison
}

phase02_markdown_value = function(value) {
  value = gsub("|", "\\\\|", as.character(value), fixed = TRUE)
  gsub("[\r\n]+", " ", value)
}

phase02_render_diff = function(comparison) {
  changed = comparison[comparison$status != "unchanged", , drop = FALSE]
  lines = c(
    "# Phase 02 Baseline Proposal Diff", "",
    "Stable artifacts only; volatile run metadata is reviewed separately.", ""
  )
  if (!nrow(changed)) {
    return(c(lines, "No stable baseline changes."))
  }
  rows = vapply(seq_len(nrow(changed)), function(index) {
    row = changed[index, ]
    paste0(
      "| ", phase02_markdown_value(row$artifact), " | ",
      phase02_markdown_value(row$key), " | ",
      phase02_markdown_value(row$old), " | ",
      phase02_markdown_value(row$new), " | ", row$status, " |"
    )
  }, character(1))
  c(lines, "| Artifact | Key | Old | New | Status |",
    "|---|---|---|---|---|", rows)
}

phase02_generate_proposal = function(output,
                                      canonical_dir = phase02_canonical_dir()) {
  root = phase02_repository_root()
  canonical_dir = normalizePath(canonical_dir, mustWork = TRUE)
  output = phase02_normalize_proposal_dir(output, canonical_dir)
  if (!dir.exists(output) &&
      !dir.create(output, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create the explicit proposal directory", call. = FALSE)
  }
  output = normalizePath(output, mustWork = TRUE)

  solved = phase02_solve_fixture(root)
  phase02_write_csv(
    phase02_expectations(solved$solution),
    file.path(output, "expectations.csv"), output
  )
  phase02_write_csv(
    phase02_tolerances(), file.path(output, "tolerances.csv"), output
  )
  phase02_write_dcf(
    phase02_fingerprints(root, output, solved),
    file.path(output, "fingerprints.dcf"), output
  )
  phase02_write_dcf(
    phase02_run_metadata(solved), file.path(output, "run-metadata.dcf"),
    output
  )
  proposal_hash = phase02_artifact_hash(output)
  stable_hashes = vapply(
    phase02_stable_artifact_names(),
    function(name) phase02_hash_file(file.path(output, name)), character(1)
  )
  run_metadata_hash = phase02_hash_file(
    file.path(output, "run-metadata.dcf")
  )
  phase02_write_dcf(
    c(
      list(
        Schema = "phase02-baseline-proposal-v2",
        `Proposal-Hash` = proposal_hash,
        `Run-Metadata-MD5` = run_metadata_hash
      ),
      as.list(stats::setNames(
        stable_hashes,
        paste0("Artifact-", gsub("[^A-Za-z0-9]", "-",
                                 names(stable_hashes)), "-MD5")
      ))
    ),
    file.path(output, "proposal.dcf"), output
  )
  comparison = phase02_diff_frame(canonical_dir, output)
  diff_lines = phase02_render_diff(comparison)
  phase02_write_lines(diff_lines, file.path(output, "DIFF.md"), output)
  list(
    output = output, proposal_hash = proposal_hash,
    clean = all(comparison$status == "unchanged"),
    diff = paste(diff_lines, collapse = "\n")
  )
}

phase02_check_baselines = function(canonical_dir = phase02_canonical_dir()) {
  canonical_dir = normalizePath(canonical_dir, mustWork = TRUE)
  proposal = tempfile("phase02-baseline-check-")
  on.exit(unlink(proposal, recursive = TRUE, force = TRUE), add = TRUE)
  generated = phase02_generate_proposal(
    proposal, canonical_dir = canonical_dir
  )
  list(clean = generated$clean, diff = generated$diff,
       proposal_hash = generated$proposal_hash)
}

phase02_refresh_usage = function() {
  paste(
    "Usage:",
    "  rtk Rscript --vanilla tools/refresh_phase02_baselines.R",
    "--output=<proposal-dir>",
    "  rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check",
    sep = "\n"
  )
}

phase02_cli_value = function(arguments, name) {
  prefix = paste0(name, "=")
  matches = arguments[startsWith(arguments, prefix)]
  if (!length(matches)) return(NULL)
  if (length(matches) != 1L) {
    stop(sprintf("%s may be supplied only once", name), call. = FALSE)
  }
  sub(prefix, "", matches[[1L]], fixed = TRUE)
}

phase02_refresh_main = function(arguments = commandArgs(trailingOnly = TRUE)) {
  if ("--help" %in% arguments) {
    cat(phase02_refresh_usage(), "\n")
    return(invisible(0L))
  }
  allowed = startsWith(arguments, "--output=") | arguments == "--check"
  if (any(!allowed)) stop("Unknown refresh argument", call. = FALSE)
  check = "--check" %in% arguments
  output = phase02_cli_value(arguments, "--output")
  if (check && !is.null(output)) {
    stop("--check cannot be combined with --output", call. = FALSE)
  }
  if (check) {
    result = phase02_check_baselines()
    cat(result$diff, "\n")
    if (!isTRUE(result$clean)) {
      stop("Canonical Phase 02 baselines are stale or corrupt",
           call. = FALSE)
    }
  } else {
    result = phase02_generate_proposal(output)
    cat(sprintf("Proposal: %s\n", result$output))
    cat(sprintf("Proposal-Hash: %s\n", result$proposal_hash))
    cat(result$diff, "\n")
  }
  invisible(0L)
}

if (sys.nframe() == 0L) phase02_refresh_main()
