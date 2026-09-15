qualificationHarnessPath = function() {
  candidates = c(
    file.path("tools", "qualify_phase03_migration.R"),
    testthat::test_path(
      "..", "..", "tools", "qualify_phase03_migration.R"
    )
  )
  hits = candidates[file.exists(candidates)]
  if (!length(hits)) {
    stop("Phase 03 qualification harness is missing", call. = FALSE)
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
