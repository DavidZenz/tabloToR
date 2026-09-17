phase02_original_source_root = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  available = file.exists(file.path(root, "DESCRIPTION")) &&
    file.exists(file.path(root, "inst", "tools",
                          "refresh_phase02_baselines.R"))
  testthat::skip_if_not(
    available,
    "Phase 02 original-artifact gate requires the source tree"
  )
  root
}

load_phase02_original_tool = function(root = phase02_original_source_root()) {
  environment = new.env(parent = globalenv())
  sys.source(
    file.path(root, "inst", "tools", "refresh_phase02_baselines.R"),
    envir = environment
  )
  environment
}

test_that("original artifact gate is immutable and independent of generation", {
  root = phase02_original_source_root()
  refresh = load_phase02_original_tool(root)
  canonical = refresh$phase02_canonical_dir(root)
  registry = file.path(root, "inst", "migration", "historical-evidence.dcf")
  original_hashes = vapply(
    c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md"),
    function(name) refresh$phase02_hash_file(file.path(canonical, name)),
    character(1)
  )

  refresh$phase02_generate_proposal = function(...) {
    stop("proposal generation must not be called", call. = FALSE)
  }

  result = refresh$phase02_check_original_artifacts(
    root = root, canonical_dir = canonical, registry_path = registry
  )
  expect_true(result$clean)
  expect_identical(result$accepted_canonical_hash,
                   "f6f2297a6ab257c9737a64354c82d7f1")
  expect_identical(result$original_artifacts_verified, 4L)
  expect_true(isTRUE(result$original_acceptance_verified))
  expect_identical(
    original_hashes,
    vapply(
      c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md"),
      function(name) refresh$phase02_hash_file(file.path(canonical, name)),
      character(1)
    )
  )
})

test_that("original CLI has an exact independent output contract", {
  root = phase02_original_source_root()
  script = file.path(root, "tools", "refresh_phase02_baselines.R")
  output = system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script), "--check-original-artifacts"),
    stdout = TRUE, stderr = TRUE
  )

  expect_null(attr(output, "status"))
  expect_identical(
    output,
    c(
      "Phase 02 original artifact gate: PASS",
      "Accepted-canonical-hash: f6f2297a6ab257c9737a64354c82d7f1",
      "Original-artifacts-verified: 4",
      "Original-acceptance-verified: true"
    )
  )
})

test_that("qualification routes original and migration through distinct flags", {
  root = phase02_original_source_root()
  environment = new.env(parent = globalenv())
  sys.source(
    file.path(root, "tools", "qualify_phase03_migration.R"),
    envir = environment
  )

  original = environment$qualification_phase02_original_arguments(root)
  migration = environment$qualification_phase02_migration_arguments(root)

  expect_identical(tail(original, 1L), "--check-original-artifacts")
  expect_identical(tail(migration, 1L), "--check-migration-source")
  expect_false("--check-migration-source" %in% original)
  expect_false("--check-original-artifacts" %in% migration)
  expect_false(identical(original, migration))
})
