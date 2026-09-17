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


test_that("original artifact gate rejects canonical and registry tampering", {
  root = phase02_original_source_root()
  refresh = load_phase02_original_tool(root)
  canonical = refresh$phase02_canonical_dir(root)
  registry = file.path(root, "inst", "migration", "historical-evidence.dcf")
  stable = c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md")

  copy_artifacts = function(destination) {
    dir.create(destination, recursive = TRUE, showWarnings = FALSE)
    expect_true(all(file.copy(
      file.path(canonical, stable), file.path(destination, stable)
    )))
    destination
  }
  copy_registry = function(destination) {
    stopifnot(file.copy(registry, destination))
    destination
  }
  check = function(artifact_dir, registry_path = registry) {
    refresh$phase02_check_original_artifacts(
      root = root, canonical_dir = artifact_dir,
      registry_path = registry_path
    )
  }

  for (name in stable) {
    tampered = tempfile(paste0("phase02-original-tampered-", name, "-"))
    copy_artifacts(tampered)
    path = file.path(tampered, name)
    writeBin(
      c(readBin(path, "raw", n = file.info(path)$size), as.raw(0L)),
      path
    )
    expect_error(check(tampered), "PHASE02_ORIGINAL_ARTIFACT_GATE", info = name)
  }

  duplicate_registry = tempfile("phase02-original-duplicate-registry-")
  duplicate_lines = readLines(registry, warn = FALSE)
  writeLines(c(duplicate_lines, duplicate_lines[seq_len(8L)]),
             duplicate_registry, useBytes = TRUE)
  tampered = copy_artifacts(tempfile("phase02-original-duplicate-"))
  expect_error(
    check(tampered, duplicate_registry),
    "PHASE02_ORIGINAL_ARTIFACT_GATE"
  )

  forged_registry = tempfile("phase02-original-forged-registry-")
  forged_lines = readLines(registry, warn = FALSE)
  forged_lines[grep("^Byte-Digest:", forged_lines)[1L]] =
    paste0("Byte-Digest: ", paste(rep("0", 64L), collapse = ""))
  writeLines(forged_lines, forged_registry, useBytes = TRUE)
  tampered = copy_artifacts(tempfile("phase02-original-forged-"))
  expect_error(
    check(tampered, forged_registry),
    "PHASE02_ORIGINAL_ARTIFACT_GATE"
  )
})

test_that("original gate ignores source identity and rejects combined CLI modes", {
  root = phase02_original_source_root()
  refresh = load_phase02_original_tool(root)
  canonical = refresh$phase02_canonical_dir(root)
  registry = file.path(root, "inst", "migration", "historical-evidence.dcf")

  refresh$phase02_source_fingerprint = function(...) {
    stop("original gate must not read current source fingerprint", call. = FALSE)
  }
  refresh$phase02_generate_proposal = function(...) {
    stop("original gate must not generate a proposal", call. = FALSE)
  }
  expect_silent(refresh$phase02_check_original_artifacts(
    root = root, canonical_dir = canonical, registry_path = registry
  ))

  script = file.path(root, "tools", "refresh_phase02_baselines.R")
  cases = list(
    duplicate = c("--check-original-artifacts", "--check-original-artifacts"),
    combined = c("--check-original-artifacts", "--check-migration-source"),
    unknown = "--check-original-artefacts"
  )
  for (name in names(cases)) {
    output = system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", shQuote(script), cases[[name]]),
      stdout = TRUE, stderr = TRUE
    )
    expect_true(!is.null(attr(output, "status")), info = name)
  }
})
