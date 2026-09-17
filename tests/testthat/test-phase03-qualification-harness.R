qualificationHarnessPath = function() {
  candidates = c(
    file.path("tools", "qualify_phase03_migration.R"),
    testthat::test_path(
      "..", "..", "tools", "qualify_phase03_migration.R"
    )
  )
  hits = candidates[file.exists(candidates)]
  if (!length(hits)) {
    testthat::skip("Phase 03 qualification harness requires the source tree")
  }
  normalizePath(hits[[1L]], mustWork = TRUE)
}

loadQualificationHarness = function() {
  environment = new.env(parent = globalenv())
  sys.source(qualificationHarnessPath(), envir = environment)
  environment
}

test_that("qualification stages form the exact digest-linked chain", {
  tool = loadQualificationHarness()
  stages = tool$qualification_example_stages()

  expect_identical(
    stages$stage,
    tool$qualification_required_stages()
  )
  expect_silent(tool$qualification_validate_stage_chain(stages))

  broken = stages
  broken$parent_digest[[4L]] = paste(rep("0", 64L), collapse = "")
  broken$input_digest[[4L]] = broken$parent_digest[[4L]]
  expect_error(
    tool$qualification_validate_stage_chain(broken),
    "QUALIFICATION_STAGE_PARENT_MISMATCH"
  )

  incomplete = stages[-nrow(stages), , drop = FALSE]
  expect_error(
    tool$qualification_validate_stage_chain(incomplete),
    "QUALIFICATION_STAGE_SET_MISMATCH"
  )
})

test_that("relevant tracked dirt fails while protected workspace dirt is ignored", {
  tool = loadQualificationHarness()
  protected = c(
    " M .planning/WINDOWS.md",
    " M .planning/config.json",
    "?? src/GEModelR.so"
  )
  expect_silent(tool$qualification_validate_clean_status(protected))

  expect_error(
    tool$qualification_validate_clean_status(c(protected, " M R/GEModel.R")),
    "QUALIFICATION_RELEVANT_STATE_DIRTY"
  )
  expect_error(
    tool$qualification_validate_clean_status(
      c(protected, "?? tests/testthat/untracked-regression.R")
    ),
    "QUALIFICATION_RELEVANT_STATE_DIRTY"
  )
})

test_that("command failures are never converted into passing stages", {
  tool = loadQualificationHarness()
  root = tempfile("qualification-command-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    tool$qualification_run_command(
      stage = "command-failure",
      command = "/bin/sh",
      arguments = c("-c", shQuote("exit 7")),
      directory = root,
      log_directory = root
    ),
    "QUALIFICATION_COMMAND_FAILED"
  )
})

test_that("qualification failures retain roots outside the R session tempdir", {
  tool = loadQualificationHarness()
  parent = tool$qualification_temporary_parent()

  expect_true(dir.exists(parent))
  expect_equal(unname(file.access(parent, mode = 2L)), 0)
  expect_false(startsWith(parent, paste0(normalizePath(tempdir()), "/")))
})

test_that("failure reporting selects the newest retained qualification root", {
  tool = loadQualificationHarness()
  root = tempfile("qualification-root-order-")
  old = file.path(root, "old")
  current = file.path(root, "current")
  dir.create(old, recursive = TRUE)
  dir.create(current)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  Sys.setFileTime(old, Sys.time() - 60)
  Sys.setFileTime(current, Sys.time())

  expect_identical(tool$qualification_latest_root(c(old, current)), current)
})

test_that("export extraction is independently digest-verified", {
  tool = loadQualificationHarness()
  export = file.path("root", "git-export.tar")
  command = tool$qualification_extract_shell(export, "source", "verification")
  implementation = paste(
    deparse(body(tool$qualification_execute)), collapse = "\n"
  )

  expect_equal(
    length(strsplit(command, shQuote(export), fixed = TRUE)[[1L]]) - 1L,
    2L
  )
  expect_match(command, shQuote("source"), fixed = TRUE)
  expect_match(command, shQuote("verification"), fixed = TRUE)
  expect_match(implementation, '"extracted-tree"', fixed = TRUE)
})

test_that("check NOTE drift fails outside the exact reviewed allowlist", {
  tool = loadQualificationHarness()
  allowlist = tool$qualification_reviewed_note_allowlist()
  expect_identical(
    allowlist,
    c(
      paste(
        "* checking DESCRIPTION meta-information ... NOTE",
        "Nicht-Standard Lizenzspezifikation:",
        "  What license is it under?",
        "Zu standardisieren: FALSE",
        sep = "\n"
      ),
      paste(
        "* checking installed package size ... NOTE",
        "  installed size is  8.9Mb",
        "  sub-directories of 1Mb or more:",
        "    libs   7.9Mb",
        sep = "\n"
      )
    )
  )
  expect_silent(tool$qualification_validate_notes(allowlist, allowlist))

  expect_error(
    tool$qualification_validate_notes(
      c(allowlist, "checking unreviewed behavior ... NOTE\nunreviewed drift"),
      allowlist
    ),
    "QUALIFICATION_CHECK_NOTE_DRIFT"
  )
})

test_that("isolated library and exact digest assertions fail closed", {
  tool = loadQualificationHarness()
  root = tempfile("qualification-library-")
  library = file.path(root, "library")
  package = file.path(library, "GEModelR")
  wrong = file.path(root, "ambient", "GEModelR")
  dir.create(package, recursive = TRUE)
  dir.create(wrong, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_silent(tool$qualification_validate_package_path(package, library))
  expect_error(
    tool$qualification_validate_package_path(wrong, library),
    "QUALIFICATION_AMBIENT_LIBRARY"
  )

  digest = tool$qualification_hash_raw(charToRaw("exact bytes"))
  expect_silent(tool$qualification_require_digest(digest, digest, "archive"))
  expect_error(
    tool$qualification_require_digest(
      digest, paste(rep("f", 64L), collapse = ""), "archive"
    ),
    "QUALIFICATION_DIGEST_MISMATCH"
  )
})

test_that("native registration contract remains exact", {
  tool = loadQualificationHarness()
  expected = c(
    "_GEModelR_GEModelR_dense_lu_factor" = 1L,
    "_GEModelR_GEModelR_dense_lu_solve" = 2L,
    "_GEModelR_GEModelR_dense_lu_release" = 1L,
    "_GEModelR_GEModelR_eliminate_blocks" = 6L,
    "_GEModelR_GEModelR_reconstruct_blocks" = 7L,
    "_GEModelR_GEModelR_schur_cpp_capabilities" = 0L,
    "_GEModelR_GEModelR_sparse_lu_solve" = 2L,
    "_GEModelR_GEModelR_sparse_pattern_hash" = 1L,
    "_GEModelR_GEModelR_schur_accumulate_batch_parallel" = 9L,
    "_GEModelR_GEModelR_schur_accumulate_global" = 7L,
    "_GEModelR_GEModelR_schur_accumulate_batch" = 9L
  )
  expect_identical(tool$qualification_native_contract(), expected)
})

test_that("fresh workflow compares scalar installed namespace identity", {
  tool = loadQualificationHarness()
  script = tempfile("qualification-fresh-", fileext = ".R")
  on.exit(unlink(script, force = TRUE), add = TRUE)
  tool$qualification_write_fresh_script(script)
  lines = readLines(script, warn = FALSE)

  expect_silent(parse(file = script))
  arity_line = lines[startsWith(lines, "expected_arities = ")]
  arity_environment = new.env(parent = baseenv())
  eval(parse(text = arity_line), envir = arity_environment)
  expect_identical(
    arity_environment$expected_arities,
    unname(tool$qualification_native_contract())
  )
  expect_type(arity_environment$expected_arities, "integer")
  expect_true(any(grepl(
    "identical(unname(getNamespaceName(asNamespace('GEModelR'))), 'GEModelR')",
    lines,
    fixed = TRUE
  )))
})

test_that("full-suite expression uses parse-safe ASCII string delimiters", {
  tool = loadQualificationHarness()
  old_options = options(useFancyQuotes = TRUE)
  on.exit(options(old_options), add = TRUE)
  library = file.path("/tmp", "qualification library \"quoted\"")
  tests = file.path("/tmp", "qualification check", "tests", "testthat")

  expression = tool$qualification_suite_expression(library, tests)

  expect_silent(parse(text = expression))
  expect_match(
    expression,
    paste0("lib.loc=", encodeString(library, quote = "\"")),
    fixed = TRUE
  )
  expect_match(
    expression,
    encodeString(tests, quote = "\""),
    fixed = TRUE
  )
  expect_false(grepl(
    "dQuote",
    paste(deparse(body(tool$qualification_suite_expression)), collapse = "\n"),
    fixed = TRUE
  ))
  implementation = paste(
    deparse(body(tool$qualification_execute)), collapse = "\n"
  )
  expect_match(
    implementation,
    'file.path(check_root, "tests", "testthat")',
    fixed = TRUE
  )
  expect_match(
    implementation,
    "qualification_suite_expression\\(library,\\s*check_tests\\)"
  )
  expect_match(implementation, "directory = check_root", fixed = TRUE)
})

test_that("Phase 2 qualification accepts only reviewed identity migration", {
  tool = loadQualificationHarness()
  source = dirname(dirname(qualificationHarnessPath()))
  refresh = new.env(parent = globalenv())
  sys.source(
    file.path(source, "inst", "tools", "refresh_phase02_baselines.R"),
    envir = refresh
  )
  map = refresh$phase02_load_identity_map(root = source)
  source_state = refresh$phase02_validate_identity_source(source, map)
  canonical = refresh$phase02_canonical_dir(source)

  arguments = tool$qualification_phase02_migration_arguments(source)
  expect_identical(tail(arguments, 1L), "--check-migration-source")
  expect_false("--check" %in% arguments)

  set_fingerprint_field = function(lines, field, value) {
    prefix = paste0(field, ": ")
    index = which(startsWith(lines, prefix))
    stopifnot(length(index) == 1L)
    lines[[index]] = paste0(prefix, value)
    lines
  }
  canonical_fingerprints = read.dcf(
    file.path(canonical, "fingerprints.dcf")
  )
  make_observed = function() {
    observed = tempfile("phase03-phase02-migration-")
    dir.create(observed)
    stable = refresh$phase02_stable_artifact_names()
    stopifnot(all(file.copy(
      file.path(canonical, stable), file.path(observed, stable)
    )))
    fingerprint_path = file.path(observed, "fingerprints.dcf")
    lines = readLines(fingerprint_path, warn = FALSE)
    lines = set_fingerprint_field(lines, "Package-Name", "GEModelR")
    lines = set_fingerprint_field(
      lines, "Source-Fingerprint", source_state$raw_fingerprint
    )
    lines = set_fingerprint_field(
      lines, "Package-Signature", refresh$phase02_signature(list(
        package = "GEModelR",
        version = unname(canonical_fingerprints[1L, "Package-Version"]),
        source = source_state$raw_fingerprint
      ))
    )
    writeLines(lines, fingerprint_path, useBytes = TRUE)
    observed
  }

  observed = make_observed()
  on.exit(unlink(observed, recursive = TRUE, force = TRUE), add = TRUE)
  expect_silent(refresh$phase02_compare_migration_artifacts(
    canonical, observed, map, source_state = source_state
  ))

  expectations = read.csv(
    file.path(observed, "expectations.csv"), stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expectations$value[[1L]] = "numerical drift"
  write.csv(
    expectations, file.path(observed, "expectations.csv"),
    row.names = FALSE, quote = TRUE
  )
  expect_error(
    refresh$phase02_compare_migration_artifacts(
      canonical, observed, map, source_state = source_state
    ),
    "Canonical numerical artifact drifted"
  )

  unlink(observed, recursive = TRUE, force = TRUE)
  observed = make_observed()
  fingerprint_path = file.path(observed, "fingerprints.dcf")
  lines = readLines(fingerprint_path, warn = FALSE)
  drift = paste(rep("0", 32L), collapse = "")
  lines = set_fingerprint_field(lines, "Source-Fingerprint", drift)
  lines = set_fingerprint_field(
    lines, "Package-Signature", refresh$phase02_signature(list(
      package = "GEModelR",
      version = unname(canonical_fingerprints[1L, "Package-Version"]),
      source = drift
    ))
  )
  writeLines(lines, fingerprint_path, useBytes = TRUE)
  expect_error(
    refresh$phase02_compare_migration_artifacts(
      canonical, observed, map, source_state = source_state
    ),
    "Observed source fingerprint does not match the checked source"
  )
})


test_that("stage runners enforce their own failures and output contracts", {
  tool = loadQualificationHarness()
  root = tempfile("qualification-stage-contract-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  for (stage in c("phase02-original", "phase02-migration")) {
    expect_error(
      tool$qualification_run_command(
        stage = stage, command = "/bin/sh",
        arguments = c("-c", shQuote("exit 17")),
        directory = root, log_directory = root
      ),
      paste0("QUALIFICATION_COMMAND_FAILED.*", stage)
    )
  }

  original_output = c(
    "Phase 02 original artifact gate: PASS",
    "Accepted-canonical-hash: f6f2297a6ab257c9737a64354c82d7f1",
    "Original-artifacts-verified: 4",
    "Original-acceptance-verified: true"
  )
  migration_output = c(
    "Phase 02 migration source gate: PASS",
    "Identity-normalized-source-fingerprint:",
    "Accepted-canonical-hash:"
  )
  expect_silent(tool$qualification_assert_output(
    original_output, original_output[-1L], "phase02-original"
  ))
  expect_silent(tool$qualification_assert_output(
    migration_output, migration_output[-1L], "phase02-migration"
  ))
  expect_error(
    tool$qualification_assert_output(
      migration_output, original_output[-1L], "phase02-original"
    ),
    "QUALIFICATION_STAGE_OUTPUT_MISMATCH"
  )
  expect_error(
    tool$qualification_assert_output(
      original_output, migration_output[-1L], "phase02-migration"
    ),
    "QUALIFICATION_STAGE_OUTPUT_MISMATCH"
  )
})

test_that("serialization bugfix stage is digest-linked and distinct", {
  tool = loadQualificationHarness()
  stages = tool$qualification_required_stages()
  parents = tool$qualification_stage_parents()

  expect_length(stages, 18L)
  expect_identical(parents[["serialization-bugfix"]], "source-identity")
  expect_true(
    match("serialization-bugfix", stages) >
      match("phase02-original", stages)
  )

  implementation = paste(
    deparse(body(tool$qualification_execute)), collapse = "\n"
  )
  expect_match(implementation, "check_serialization_bugfix.R", fixed = TRUE)
  expect_match(implementation, "--verify-approved", fixed = TRUE)

  expect_silent(tool$qualification_assert_output(
    c(
      "Serialization BUGFIX gate: PASS",
      "Change-Kind: BUGFIX",
      "Before-SHA256: before",
      "After-SHA256: after"
    ),
    c("Serialization BUGFIX gate: PASS", "Change-Kind: BUGFIX",
      "Before-SHA256:", "After-SHA256:"),
    "serialization-bugfix"
  ))
  expect_error(
    tool$qualification_assert_output(
      c("Serialization BUGFIX gate: PASS", "Change-Kind: PASS"),
      c("Serialization BUGFIX gate: PASS", "Change-Kind: BUGFIX"),
      "serialization-bugfix"
    ),
    "QUALIFICATION_STAGE_OUTPUT_MISMATCH"
  )
})

test_that("qualification suite propagates the isolated gap-test library", {
  tool = loadQualificationHarness()
  library = tempfile("qualification-gap-library-")
  dir.create(library)
  on.exit(unlink(library, recursive = TRUE, force = TRUE), add = TRUE)

  environment = tool$qualification_isolated_environment(library)
  gap = environment[startsWith(environment, "GEModelR_GAP_TEST_LIBRARY=")]
  expect_length(gap, 1L)
  expect_identical(
    gap,
    paste0("GEModelR_GAP_TEST_LIBRARY=",
           normalizePath(library, winslash = "/", mustWork = TRUE))
  )
  expect_identical(
    tool$qualification_required_full_suite_tests(),
    file.path(
      "tests", "testthat",
      c(
        "test-installed-benchmark-execution.R",
        "test-benchmark-correctness-gate.R",
        "test-serialization-leaf-types.R"
      )
    )
  )
  implementation = paste(
    deparse(body(tool$qualification_execute)), collapse = "\n"
  )
  expect_match(implementation, "qualification_required_full_suite_tests",
               fixed = TRUE)
})


test_that("serialization stage dispatch accepts only the BUGFIX fixture contract", {
  tool = loadQualificationHarness()
  root = tempfile("qualification-serialization-fixture-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  script = file.path(root, "check_serialization_bugfix.R")
  writeLines(
    c(
      "cat(\"Serialization BUGFIX gate: PASS\")",
      "cat(\"Change-Kind: BUGFIX\")",
      "cat(\"Before-SHA256: before\")",
      "cat(\"After-SHA256: after\")"
    ),
    script, useBytes = TRUE
  )
  result = tool$qualification_run_command(
    "serialization-bugfix", file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script)), log_directory = root
  )
  expect_identical(result$status, 0L)
  expect_silent(tool$qualification_assert_output(
    result$output,
    c(
      "Serialization BUGFIX gate: PASS",
      "Change-Kind: BUGFIX",
      "Before-SHA256:",
      "After-SHA256:"
    ),
    "serialization-bugfix"
  ))
})
