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


test_that("original gate rejects missing malformed and self-consistent forgeries", {
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
  check = function(artifact_dir, registry_path = registry) {
    refresh$phase02_check_original_artifacts(
      root = root, canonical_dir = artifact_dir,
      registry_path = registry_path
    )
  }

  for (name in stable) {
    missing = copy_artifacts(tempfile(paste0("phase02-original-missing-", name, "-")))
    unlink(file.path(missing, name))
    expect_error(
      check(missing), "PHASE02_ORIGINAL_ARTIFACT_GATE", info = name
    )
  }

  malformed_fingerprint = copy_artifacts(
    tempfile("phase02-original-malformed-fingerprint-")
  )
  writeLines(c("not: valid", "broken"),
             file.path(malformed_fingerprint, "fingerprints.dcf"),
             useBytes = TRUE)
  expect_error(
    check(malformed_fingerprint), "PHASE02_ORIGINAL_ARTIFACT_GATE"
  )

  malformed_acceptance = copy_artifacts(
    tempfile("phase02-original-malformed-acceptance-")
  )
  writeLines(c("not: valid", "broken"),
             file.path(malformed_acceptance, "ACCEPTANCE.md"),
             useBytes = TRUE)
  expect_error(
    check(malformed_acceptance), "PHASE02_ORIGINAL_ARTIFACT_GATE"
  )

  altered = copy_artifacts(tempfile("phase02-original-self-consistent-"))
  expectations = file.path(altered, "expectations.csv")
  writeBin(
    c(readBin(expectations, "raw", n = file.info(expectations)$size),
      as.raw(0L)),
    expectations
  )
  new_canonical_hash = refresh$phase02_artifact_hash(altered)
  acceptance = file.path(altered, "ACCEPTANCE.md")
  acceptance_lines = readLines(acceptance, warn = FALSE)
  acceptance_index = grep(
    "- **New-Canonical-Hash:**", acceptance_lines, fixed = TRUE
  )
  stopifnot(length(acceptance_index) == 1L)
  acceptance_lines[[acceptance_index]] = paste0(
    "- **New-Canonical-Hash:** ", intToUtf8(96L),
    new_canonical_hash, intToUtf8(96L)
  )
  writeLines(acceptance_lines, acceptance, useBytes = TRUE)
  new_expectations_digest = refresh$phase02_original_sha256_file(expectations)
  new_acceptance_digest = refresh$phase02_original_sha256_file(acceptance)

  registry_record = as.data.frame(read.dcf(registry), stringsAsFactors = FALSE, check.names = FALSE)
  old_expectations_digest = registry_record[
    registry_record[["Record-Id"]] == "phase02-expectations", "Byte-Digest"
  ]
  old_acceptance_digest = registry_record[
    registry_record[["Record-Id"]] == "phase02-acceptance", "Byte-Digest"
  ]
  forged_registry = tempfile("phase02-original-self-consistent-registry-")
  registry_lines = readLines(registry, warn = FALSE)
  replace_once = function(lines, old, new) {
    index = grep(old, lines, fixed = TRUE)
    stopifnot(length(index) == 1L)
    lines[[index]] = sub(old, new, lines[[index]], fixed = TRUE)
    lines
  }
  registry_lines = replace_once(
    registry_lines, old_expectations_digest, new_expectations_digest
  )
  registry_lines = replace_once(
    registry_lines, old_acceptance_digest, new_acceptance_digest
  )
  writeLines(registry_lines, forged_registry, useBytes = TRUE)
  expect_error(
    check(altered, forged_registry),
    "PHASE02_ORIGINAL_ARTIFACT_GATE"
  )
})


test_that("protected source drift fails migration while original bytes still pass", {
  root = phase02_original_source_root()
  refresh = load_phase02_original_tool(root)
  canonical = refresh$phase02_canonical_dir(root)
  registry = file.path(root, "inst", "migration", "historical-evidence.dcf")
  map = refresh$phase02_load_identity_map(root = root)

  copy_tree = function(destination, relative) {
    for (path in relative) {
      target = file.path(destination, path)
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      expect_true(file.copy(file.path(root, path), target))
    }
    destination
  }
  source = tempfile("phase02-original-source-copy-")
  relative = unique(c(
    refresh$phase02_identity_source_files(root),
    file.path("tests", "testthat", "fixtures",
              c("three-region.tab", "PROVENANCE.md")),
    file.path("benchmarks", "GTAP12A_CPP_RESULTS.md")
  ))
  copy_tree(source, relative)
  canonical_copy = tempfile("phase02-original-canonical-copy-")
  dir.create(canonical_copy)
  stable = c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md")
  expect_true(all(file.copy(
    file.path(canonical, stable), file.path(canonical_copy, stable)
  )))
  registry_copy = tempfile("phase02-original-registry-copy-")
  expect_true(file.copy(registry, registry_copy))


  solver = file.path(source, "R", "sparseSolver.R")
  solver_text = rawToChar(
    readBin(solver, "raw", n = file.info(solver)$size)
  )
  old = "residual_norm / max(1, rhs_norm)"
  new = "residual_norm / max(2, rhs_norm)"
  stopifnot(grepl(old, solver_text, fixed = TRUE))
  solver_text = sub(old, new, solver_text, fixed = TRUE)
  connection = file(solver, open = "wb")
  writeBin(charToRaw(solver_text), connection)
  close(connection)
  expect_error(
    refresh$phase02_validate_identity_source(source, map),
    "source fingerprint|mapping row"
  )
  expect_silent(refresh$phase02_check_original_artifacts(
    root = source, canonical_dir = canonical_copy,
    registry_path = registry_copy
  ))
})
