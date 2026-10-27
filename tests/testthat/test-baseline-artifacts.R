test_that("path containment distinguishes equal child sibling and ancestor", {

  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  root = tempfile("phase02-path-root-")
  child = file.path(root, "child")
  sibling = paste0(root, "-sibling")
  dir.create(child, recursive = TRUE)
  dir.create(sibling)
  on.exit(unlink(c(root, sibling), recursive = TRUE, force = TRUE), add = TRUE)

  expect_true(refresh$phase02_path_contains(root, root))
  expect_true(refresh$phase02_path_contains(root, child))
  expect_false(refresh$phase02_path_contains(root, sibling))
  expect_false(refresh$phase02_path_contains(child, root))
  expect_false(grepl("\\\\", refresh$phase02_path_key(child)))
  if (identical(.Platform$OS.type, "windows")) {
    expect_true(refresh$phase02_path_contains(toupper(root), tolower(child)))
  }
})

test_that("sourced baseline tools identify their own file rather than the caller", {
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  expect_identical(refresh$phase02_script_path,
                   phase02_tool_path("refresh_phase02_baselines.R"))
})

test_that("sourced acceptance and identity tools resolve their own script paths", {
  phase02_require_source_tree()
  accept = load_phase02_tool("accept_phase02_baselines.R")
  expect_identical(accept$phase02_accept_script_path,
                   phase02_tool_path("accept_phase02_baselines.R"))
  identity_path = phase02_cli_path("check_identity_migration.R")
  identity = new.env(parent = globalenv())
  sys.source(identity_path, envir = identity)
  expect_identical(identity$identity_script_path, identity_path)
})

test_that("proposal generation is explicit compact and deterministic", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  first = tempfile("phase02-proposal-first-")
  second = tempfile("phase02-proposal-second-")

  result_first = refresh$phase02_generate_proposal(first)
  result_second = refresh$phase02_generate_proposal(second)

  expected = c(
    "expectations.csv", "tolerances.csv", "fingerprints.dcf",
    "run-metadata.dcf", "proposal.dcf", "DIFF.md"
  )
  expect_setequal(list.files(first), expected)
  expect_setequal(list.files(second), expected)
  expect_false(any(grepl("\\.rds$", list.files(first), ignore.case = TRUE)))
  expect_true(all(file.info(list.files(first, full.names = TRUE))$size < 262144))
  expect_identical(result_first$proposal_hash, result_second$proposal_hash)
  expect_identical(
    readLines(file.path(first, "DIFF.md"), warn = FALSE),
    readLines(file.path(second, "DIFF.md"), warn = FALSE)
  )
  expect_true(is.function(make_three_region_model))

  expectations = read.csv(
    file.path(first, "expectations.csv"), stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_identical(
    expectations$value[expectations$key == "solution.names"],
    'q["north"]|q["south"]|q["east"]'
  )
  expect_equal(
    as.numeric(expectations$value[
      expectations$fixture == "three-region" & expectations$kind == "value"
    ]),
    c(1, 3, -2), tolerance = 1e-12
  )
})

test_that("stable fingerprints and volatile run metadata are separated", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  proposal = tempfile("phase02-proposal-metadata-")
  refresh$phase02_generate_proposal(proposal)

  fingerprints = as.list(read.dcf(file.path(proposal, "fingerprints.dcf"))[1, ])
  required_stable = c(
    "Schema", "Fixture-Path", "Fixture-MD5", "Fixture-Input-Signature",
    "Source-Scope", "Source-Fingerprint", "Package-Name",
    "Package-Version", "Package-Signature", "Model-Signature",
    "Expectations-MD5", "Tolerances-MD5", "External-Evidence-Path",
    "External-Evidence-MD5", "External-Inputs-Committed"
  )
  expect_true(all(required_stable %in% names(fingerprints)))
  expect_identical(fingerprints[["Fixture-Path"]],
                   "tests/testthat/fixtures/three-region.tab")
  expect_identical(fingerprints[["External-Inputs-Committed"]], "false")
  expect_false(grepl("baselines/phase02", fingerprints[["Source-Scope"]],
                     fixed = TRUE))

  metadata = as.list(read.dcf(file.path(proposal, "run-metadata.dcf"))[1, ])
  required_volatile = c(
    "Generated-UTC", "R-Version", "Matrix-Version", "Rcpp-Version",
    "SparseM-Version", "testthat-Version", "Platform", "CPU",
    "Physical-RAM-Bytes", "BLAS", "Elapsed-Seconds", "Peak-RSS-Bytes",
    "Solver-Backend", "Solver-Reduction", "Solver-Residual-Relative-L2"
  )
  expect_true(all(required_volatile %in% names(metadata)))
  expect_identical(metadata[["Solver-Backend"]], "Matrix")
  expect_true(is.finite(as.numeric(
    metadata[["Solver-Residual-Relative-L2"]]
  )))
  manifest = as.list(read.dcf(file.path(proposal, "proposal.dcf"))[1, ])
  expect_identical(manifest[["Schema"]], "phase02-baseline-proposal-v2")
  expect_identical(
    manifest[["Run-Metadata-MD5"]],
    refresh$phase02_hash_file(file.path(proposal, "run-metadata.dcf"))
  )
})


test_that("proposal and check modes cannot mutate accepted canonical artifacts", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  root = refresh$phase02_repository_root()
  canonical = refresh$phase02_canonical_dir()
  tracked = c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md")
  before = vapply(
    tracked,
    function(name) refresh$phase02_hash_file(file.path(canonical, name)),
    character(1)
  )
  proposal = tempfile("phase02-proposal-immutable-")

  refresh$phase02_generate_proposal(proposal)
  clean = refresh$phase02_check_baselines(canonical_dir = canonical)

  expect_false(clean$clean)
  changed = refresh$phase02_diff_frame(canonical, proposal)
  changed = changed[changed$status != "unchanged", , drop = FALSE]
  expect_equal(nrow(changed), 4L)
  expect_identical(sort(unique(changed$artifact)), "fingerprints.dcf")
  expect_setequal(
    changed$key,
    c("Source-Fingerprint", "Source-File-Count", "Package-Name", "Package-Signature")
  )
  expect_true(all(changed$status == "changed"))

  original = refresh$phase02_check_original_artifacts(
    root = root, canonical_dir = canonical,
    registry_path = file.path(root, "inst", "migration",
                               "historical-evidence.dcf")
  )
  expect_true(original$clean)
  expect_true(original$original_acceptance_verified)
  expect_silent(refresh$phase02_check_migration_source(
    root = root, canonical_dir = canonical,
    map_path = file.path(root, "inst", "migration",
                         "benchmark-identity-map.dcf")
  ))
  expect_identical(
    before,
    vapply(
      tracked,
      function(name) refresh$phase02_hash_file(file.path(canonical, name)),
      character(1)
    )
  )

  expect_error(
    refresh$phase02_generate_proposal(canonical),
    "canonical baseline"
  )
  expect_error(
    refresh$phase02_generate_proposal(dirname(canonical)),
    "overlaps the canonical baseline"
  )
  expect_error(refresh$phase02_generate_proposal(NULL),
               "explicit proposal directory")
})

test_that("read-only check reports missing stale and corrupt keys", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  canonical = tempfile("phase02-canonical-copy-")
  proposal = tempfile("phase02-proposal-clean-copy-")
  refresh$phase02_generate_proposal(proposal)
  copy_phase02_artifacts(refresh, proposal, canonical)

  clean = refresh$phase02_check_baselines(canonical_dir = canonical)
  expect_true(clean$clean)

  expectations = read.csv(
    file.path(canonical, "expectations.csv"), stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expectations$value[expectations$key == 'q["north"]'] = "999"
  write.csv(expectations, file.path(canonical, "expectations.csv"),
            row.names = FALSE, quote = TRUE)
  stale = refresh$phase02_check_baselines(canonical_dir = canonical)
  expect_false(stale$clean)
  expect_match(stale$diff, 'q["north"]', fixed = TRUE)
  expect_match(stale$diff, "999", fixed = TRUE)

  unlink(file.path(canonical, "fingerprints.dcf"))
  missing = refresh$phase02_check_baselines(canonical_dir = canonical)
  expect_false(missing$clean)
  expect_match(missing$diff, "fingerprints.dcf")
  expect_match(missing$diff, "missing")

  writeLines("not: valid\nbroken", file.path(canonical, "fingerprints.dcf"))
  corrupt = refresh$phase02_check_baselines(canonical_dir = canonical)
  expect_false(corrupt$clean)
  expect_match(corrupt$diff, "corrupt")
})

test_that("acceptance validates proposals and supports dry-run and safe commit", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  accept = load_phase02_tool("accept_phase02_baselines.R")
  proposal = tempfile("phase02-proposal-accept-")
  canonical = tempfile("phase02-canonical-accept-")
  refresh$phase02_generate_proposal(proposal)
  copy_phase02_canonical(refresh, canonical)
  before = refresh$phase02_artifact_hash(canonical)

  dry = accept$phase02_accept_proposal(
    proposal, reviewer = "Baseline Reviewer",
    reason = "Reviewed deterministic Phase 02 evidence",
    canonical_dir = canonical, dry_run = TRUE
  )
  expect_true(dry$dry_run)
  expect_identical(before, refresh$phase02_artifact_hash(canonical))
  expect_false(file.exists(file.path(canonical, "ACCEPTANCE.md")))

  committed = accept$phase02_accept_proposal(
    proposal, reviewer = "Baseline Reviewer",
    reason = "Reviewed deterministic Phase 02 evidence",
    canonical_dir = canonical
  )
  record = readLines(file.path(canonical, "ACCEPTANCE.md"), warn = FALSE)
  expect_false(committed$dry_run)
  for (field in c(
    "Reviewer:", "Reason:", "Accepted-UTC:", "Proposal-Hash:",
    "Run-Metadata-MD5:", "Old-Canonical-Hash:", "New-Canonical-Hash:"
  )) {
    expect_true(any(startsWith(record, paste0("- **", field))))
  }
  expect_identical(committed$new_canonical_hash,
                   refresh$phase02_artifact_hash(canonical))


  expect_error(
    accept$phase02_accept_proposal(
      proposal, reviewer = "", reason = "valid reason",
      canonical_dir = canonical
    ),
    "reviewer"
  )
  expect_error(
    accept$phase02_accept_proposal(
      proposal, reviewer = "Reviewer", reason = "",
      canonical_dir = canonical
    ),
    "reason"
  )
  writeLines("Proposal-Hash: tampered", file.path(proposal, "proposal.dcf"))
  expect_error(
    accept$phase02_accept_proposal(
      proposal, reviewer = "Reviewer", reason = "valid reason",
      canonical_dir = canonical
    ),
    "proposal"
  )
})

test_that("acceptance is bound to current source and reviewed run evidence", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  accept = load_phase02_tool("accept_phase02_baselines.R")
  canonical = tempfile("phase02-canonical-source-bound-")
  copy_phase02_canonical(refresh, canonical)

  metadata_tampered = tempfile("phase02-proposal-metadata-tampered-")
  refresh$phase02_generate_proposal(metadata_tampered)
  cat(
    "Tampered: yes\n",
    file = file.path(metadata_tampered, "run-metadata.dcf"),
    append = TRUE
  )
  expect_error(
    accept$phase02_accept_proposal(
      metadata_tampered, reviewer = "Reviewer",
      reason = "Reviewed evidence", canonical_dir = canonical,
      dry_run = TRUE
    ),
    "run-metadata evidence hash"
  )

  forged = tempfile("phase02-proposal-forged-source-")
  refresh$phase02_generate_proposal(forged)
  fingerprints = as.list(read.dcf(
    file.path(forged, "fingerprints.dcf")
  )[1, ])
  fingerprints[["Source-Fingerprint"]] = paste(rep("0", 32L), collapse = "")
  refresh$phase02_write_dcf(
    fingerprints, file.path(forged, "fingerprints.dcf"), forged
  )
  manifest = as.list(read.dcf(file.path(forged, "proposal.dcf"))[1, ])
  manifest[["Proposal-Hash"]] = refresh$phase02_artifact_hash(forged)
  manifest[["Artifact-fingerprints-dcf-MD5"]] =
    refresh$phase02_hash_file(file.path(forged, "fingerprints.dcf"))
  refresh$phase02_write_dcf(
    manifest, file.path(forged, "proposal.dcf"), forged
  )
  refresh$phase02_write_lines(
    refresh$phase02_render_diff(
      refresh$phase02_diff_frame(canonical, forged)
    ),
    file.path(forged, "DIFF.md"), forged
  )


  expect_error(
    accept$phase02_accept_proposal(
      forged, reviewer = "Reviewer",
      reason = "Reviewed evidence", canonical_dir = canonical,
      dry_run = TRUE
    ),
    "no longer matches the current source and model"
  )
})

test_that("acceptance CLI documents the exact reviewed boundary", {
  script = phase02_cli_path("accept_phase02_baselines.R")
  output = system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script), "--help"),
    stdout = TRUE, stderr = TRUE
  )

  expect_null(attr(output, "status"))
  expect_match(
    paste(output, collapse = "\n"),
    paste0(
      "accept_phase02_baselines.R --proposal=<proposal-dir> ",
      "--reviewer=<name> --reason=<text>"
    ),
    fixed = TRUE
  )
  expect_match(paste(output, collapse = "\n"), "--dry-run", fixed = TRUE)
})

test_that("canonical acceptance is complete and bound to accepted artifacts", {
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  canonical = normalizePath(
    testthat::test_path("baselines", "phase02"), mustWork = TRUE
  )
  record = readLines(file.path(canonical, "ACCEPTANCE.md"), warn = FALSE)
  text = paste(record, collapse = "\n")
  fingerprints = as.list(read.dcf(
    file.path(canonical, "fingerprints.dcf")
  )[1, ])


  for (field in c(
    "Reviewer", "Reason", "Accepted-UTC", "Proposal-Hash",
    "Old-Canonical-Hash", "New-Canonical-Hash", "Fixture-MD5",
    "Source-Fingerprint", "Tolerance-Tier"
  )) {
    expect_match(text, paste0("- **", field, ":**"), fixed = TRUE)
  }
  expect_match(
    text,
    paste0("- **New-Canonical-Hash:** `",
           refresh$phase02_artifact_hash(canonical), "`"),
    fixed = TRUE
  )
  expect_match(
    text,
    paste0("- **Fixture-MD5:** `", fingerprints[["Fixture-MD5"]], "`"),
    fixed = TRUE
  )
  expect_match(
    text,
    paste0("- **Source-Fingerprint:** `",
           fingerprints[["Source-Fingerprint"]], "`"),
    fixed = TRUE
  )
  expect_match(text, "strict (solution atol 1e-10, rtol 1e-08; ",
               fixed = TRUE)
  expect_match(text, "residual rtol 1e-10)", fixed = TRUE)
  expect_match(
    text,
    "- **Old-Canonical-Hash:** `453a6986e600df6cf426c11d794f2b1d`",
    fixed = TRUE
  )
})


test_that("source fingerprint ordering is locale independent", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  root = refresh$phase02_repository_root()

  independent_source_files = function(root) {
    fixed = c("DESCRIPTION", "NAMESPACE")
    recursive = c(
      list.files(file.path(root, "R"), pattern = "\\.R$",
                 recursive = TRUE, full.names = FALSE),
      file.path("src", list.files(
        file.path(root, "src"), pattern = "\\.(c|cc|cpp|h|hpp)$",
        recursive = TRUE, full.names = FALSE
      )),
      file.path("inst", "compatibility", list.files(
        file.path(root, "inst", "compatibility"),
        recursive = TRUE, full.names = FALSE
      )),
      file.path("tests", "testthat", "fixtures",
                c("three-region.tab", "PROVENANCE.md")),
      file.path("tests", "testthat", c(
        "helper-compatibility.R", "helper-three-region.R",
        "helper-numerical-baseline.R", "helper-transactional-state.R",
        "helper-serialization.R"
      ))
    )
    relative = unique(c(fixed, recursive))
    relative = chartr("\\", "/", relative)
    relative = setdiff(relative, "inst/compatibility/MANIFEST.md")
    relative = unique(relative)
    relative = relative[file.exists(file.path(root, relative))]
    relative[order(tolower(relative), relative, method = "radix")]
  }

  expected = independent_source_files(root)
  observed = refresh$phase02_source_files(root)
  expect_identical(observed, expected)

  paths = file.path(root, expected)
  hashes = unname(tools::md5sum(paths))
  frame = as.list(stats::setNames(hashes, expected))
  raw = capture.output(dput(frame, control = c("keepNA", "keepInteger")))
  digest_path = tempfile("phase02-independent-fingerprint-")
  writeLines(raw, digest_path, useBytes = TRUE)
  expected_fingerprint = unname(tools::md5sum(digest_path))
  expect_identical(
    refresh$phase02_source_fingerprint(root),
    expected_fingerprint
  )
})

test_that("migration identity map has a strict reviewed schema", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  map = refresh$phase02_load_identity_map()

  expect_identical(names(map), refresh$phase02_identity_map_fields())
  expect_identical(
    map$`Rule-Id`, c("package-mixed-case", "package-upper-case")
  )
  expect_true(all(map$`Review-State` == "reviewed"))
  expect_silent(refresh$phase02_validate_identity_map(map))

  invalid_maps = list(
    missing = map[, -1L, drop = FALSE],
    extra = cbind(map, Extra = "forbidden"),
    duplicate = rbind(map, map[1L, , drop = FALSE]),
    malformed = {
      value = map
      value[1L, "Expected-Occurrences"] = "many"
      value
    },
    unreviewed = {
      value = map
      value[1L, "Review-State"] = "pending"
      value
    },
    stale = {
      value = map
      value[1L, "Expected-Occurrences"] = "999999"
      value
    },
    digest = {
      value = map
      value[1L, "Normalized-Source-Fingerprint"] =
        "00000000000000000000000000000000"
      value
    }
  )
  for (name in names(invalid_maps)) {
    path = tempfile(paste0("phase02-identity-map-", name, "-"),
                    fileext = ".dcf")
    write_phase02_identity_map(invalid_maps[[name]], path)
    expect_error(
      refresh$phase02_load_identity_map(path),
      regexp = "identity map|Identity map|mapping row|source fingerprint",
      info = name
    )
  }
})

test_that("current source identity review binds the exact refreshed evidence", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  root = refresh$phase02_repository_root()
  record = read.dcf(file.path(root, "inst", "migration",
                              "source-identity-review.dcf"))[1L, ]
  expect_identical(unname(record[["Schema"]]),
                   "gemodelr-source-identity-review-v1")
  expect_identical(unname(record[["Review-Type"]]),
                   "automated technical review; maintainer-authorized update")
  files = c(
    "Map-SHA256" = "benchmark-identity-map.dcf",
    "Registry-SHA256" = "historical-evidence.dcf",
    "Allowlist-SHA256" = "old-identity-allowlist.csv"
  )
  for (field in names(files)) {
    expect_identical(unname(record[[field]]),
      refresh$phase02_original_sha256_file(
        file.path(root, "inst", "migration", files[[field]])
      ), info = field)
  }
  map = refresh$phase02_load_identity_map(root = root)
  expect_identical(unname(record[["Normalized-Source-Fingerprint"]]),
                   unique(map$`Normalized-Source-Fingerprint`))
  expect_identical(unname(record[["Mixed-Case-Occurrences"]]),
                   map$`Expected-Occurrences`[[1L]])
  expect_identical(unname(record[["Upper-Case-Occurrences"]]),
                   map$`Expected-Occurrences`[[2L]])
  expect_identical(unname(record[["Immutable-Evidence-Changed"]]), "false")
  expect_true(refresh$phase02_check_original_artifacts(root = root)$clean)
})

test_that("migration source gate accepts identity-only substitutions", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  map = refresh$phase02_load_identity_map()
  source = tempfile("phase02-identity-source-")
  copy_phase02_source_scope(refresh, source)

  expect_silent(refresh$phase02_validate_identity_source(source, map))
  replace_phase02_source_identity(refresh, source, map)
  expect_silent(refresh$phase02_validate_identity_source(source, map))

  text = paste(
    vapply(
      file.path(source, refresh$phase02_identity_source_files(source)),
      read_phase02_source_text, character(1)
    ),
    collapse = "\n"
  )
  expect_false(grepl("tabloToR", text, fixed = TRUE))
  expect_false(grepl("TABLOTOR", text, fixed = TRUE))
})

test_that("migration source gate rejects every non-identity contract drift", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  map = refresh$phase02_load_identity_map()
  mutations = list(
    algorithm = c(
      "R/sparseSolver.R", "sparse_relative_l2(residual, rhs)",
      "sparse_relative_l2(residual, rhs, absolute_floor = 2)"
    ),
    signature = c(
      "R/GEModel.R", "solveModel = function(iter = 3",
      "solveModel = function(iter = 4"
    ),
    default = c(
      "R/GEModel.R", "backend = \"Matrix\"", "backend = \"SparseM\""
    ),
    tolerance = c(
      "R/sparseSolver.R", "residual_tolerance = 2e-7",
      "residual_tolerance = 3e-7"
    ),
    ordering = c(
      "R/sparseSolver.R", "order_value = order(i, j)",
      "order_value = order(j, i)"
    ),
    residual = c(
      "R/sparseSolver.R", "relative_l2 = sparse_relative_l2(residual, rhs)",
      "relative_l2 = 0"
    ),
    unmapped_identity = c(
      "DESCRIPTION", "Package: GEModelR", "Package: GemodelR"
    )
  )

  for (name in names(mutations)) {
    source = tempfile(paste0("phase02-source-drift-", name, "-"))
    copy_phase02_source_scope(refresh, source)
    replace_phase02_source_identity(refresh, source, map)
    mutation = mutations[[name]]
    mutate_phase02_source(source, mutation[[1L]], mutation[[2L]],
                          mutation[[3L]])
    expect_error(
      refresh$phase02_validate_identity_source(source, map),
      "source fingerprint|mapping row",
      info = name
    )
  }
})

test_that("migration comparison rejects schema and canonical evidence drift", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  map = refresh$phase02_load_identity_map()
  canonical = tempfile("phase02-migration-canonical-")
  observed = tempfile("phase02-migration-observed-")
  copy_phase02_canonical(refresh, canonical)
  copy_phase02_canonical(refresh, observed)
  stopifnot(file.copy(
    file.path(refresh$phase02_canonical_dir(), "ACCEPTANCE.md"),
    file.path(canonical, "ACCEPTANCE.md")
  ))

  expect_silent(
    refresh$phase02_compare_migration_artifacts(canonical, observed, map)
  )

  fingerprints = read.dcf(file.path(observed, "fingerprints.dcf"))
  fingerprints[1L, "Schema"] = "phase02-baseline-fingerprints-v2"
  write.dcf(fingerprints, file.path(observed, "fingerprints.dcf"),
            useBytes = TRUE)
  expect_error(
    refresh$phase02_compare_migration_artifacts(canonical, observed, map),
    "non-identity baseline field"
  )

  unlink(observed, recursive = TRUE, force = TRUE)
  copy_phase02_canonical(refresh, observed)
  expectations = read.csv(
    file.path(observed, "expectations.csv"), stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expectations$value[1L] = "canonical drift"
  write.csv(expectations, file.path(observed, "expectations.csv"),
            row.names = FALSE, quote = TRUE)
  expect_error(
    refresh$phase02_compare_migration_artifacts(canonical, observed, map),
    "Canonical numerical artifact"
  )
})

test_that("migration check is read-only and independent of acceptance", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  canonical = refresh$phase02_canonical_dir()
  before = vapply(
    c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md"),
    function(name) refresh$phase02_hash_file(file.path(canonical, name)),
    character(1)
  )

  expect_silent(refresh$phase02_check_migration_source())
  after = vapply(
    c(refresh$phase02_stable_artifact_names(), "ACCEPTANCE.md"),
    function(name) refresh$phase02_hash_file(file.path(canonical, name)),
    character(1)
  )
  expect_identical(after, before)
  expect_false(exists("phase02_accept_proposal", envir = refresh,
                      inherits = FALSE))
})
test_that("accepted Phase 2 bytes have independent SHA-256 evidence", {
  phase02_require_source_tree()
  tool_path = phase02_cli_path("check_identity_migration.R")
  tool = new.env(parent = globalenv())
  sys.source(tool_path, envir = tool)
  root = tool$identity_repository_root()
  registry = tool$identity_load_historical_registry(root = root)
  immutable = registry[startsWith(registry$Category, "immutable-"), ,
                       drop = FALSE]

  expect_identical(
    immutable$`Record-Id`,
    c(
      "phase02-expectations", "phase02-tolerances",
      "phase02-fingerprints", "phase02-acceptance",
      "gtap12a-cpp-results"
    )
  )
  expect_identical(
    immutable$`Byte-Digest`,
    c(
      "0efdc7e3093be07e89dc5f5335b7732e8a21ca0dcf0b41ca030161ff9855fa2c",
      "b8aad6ea259d8b4629e296205902b9b280a5702286bbbf06a798c55cd0fc6c16",
      "49ed115d2cfac35b11b04e86421c236686e132abcb5d8f40d58aafd69ce9b2b0",
      "4e8ab0c70d662abe8a1328a5c66f76938a3d610b630de400a057af14153f7113",
      "a4eb96dd86ad2ee4ead588fe7b275e7f5916f5de6bd1d59ba0587f9cec3b48ca"
    )
  )
  expect_true(all(vapply(seq_len(nrow(immutable)), function(index) {
    identical(
      tool$identity_hash_file(file.path(root, immutable$Path[[index]])),
      immutable$`Byte-Digest`[[index]]
    )
  }, logical(1))))
})


test_that("acceptance publication is locked and rolls back atomically", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  accept = load_phase02_tool("accept_phase02_baselines.R")
  proposal = tempfile("phase02-proposal-atomic-")
  canonical = tempfile("phase02-canonical-atomic-")
  refresh$phase02_generate_proposal(proposal)
  copy_phase02_canonical(refresh, canonical)
  old_record = c("# Previous acceptance", "", "reviewed")
  writeLines(old_record, file.path(canonical, "ACCEPTANCE.md"))
  before = refresh$phase02_artifact_hash(canonical)
  lock = paste0(normalizePath(canonical, winslash = "/"), ".accept-lock")
  backup = paste0(normalizePath(canonical, winslash = "/"), ".accept-backup")

  dir.create(lock)
  expect_error(
    accept$phase02_accept_proposal(
      proposal, reviewer = "Reviewer", reason = "Reviewed evidence",
      canonical_dir = canonical
    ),
    "locked by another process"
  )
  unlink(lock, recursive = TRUE, force = TRUE)

  withr::local_options(
    GEModelR.phase02.acceptance.fault = function(phase) {
      if (identical(phase, "after-canonical-backup")) {
        stop("injected publication failure", call. = FALSE)
      }
    }
  )
  expect_error(
    accept$phase02_accept_proposal(
      proposal, reviewer = "Reviewer", reason = "Reviewed evidence",
      canonical_dir = canonical
    ),
    "injected publication failure"
  )
  expect_true(dir.exists(canonical))
  expect_identical(refresh$phase02_artifact_hash(canonical), before)
  expect_identical(
    readLines(file.path(canonical, "ACCEPTANCE.md"), warn = FALSE), old_record
  )
  expect_false(dir.exists(lock))
  expect_false(dir.exists(backup))
})


test_that("metadata count changes require the exact reviewed source transition", {
  phase02_require_source_tree()
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  root = refresh$phase02_repository_root()
  map = refresh$phase02_load_identity_map(root = root)
  canonical = refresh$phase02_canonical_dir(root)
  observed = tempfile("metadata-count-")
  on.exit(unlink(observed, recursive = TRUE), add = TRUE)
  copy_phase02_artifacts(refresh, canonical, observed)
  path = file.path(observed, "fingerprints.dcf")
  original = as.data.frame(read.dcf(path), stringsAsFactors = FALSE, check.names = FALSE)
  state = refresh$phase02_identity_source_state(root, map)
  changed = original
  changed$`Source-File-Count` = "26"
  write.dcf(changed, path, keep.white = names(changed))
  expect_error(refresh$phase02_compare_migration_artifacts(canonical, observed, map, state),
    "non-identity baseline field drifted: Source-File-Count")
  changed$`Source-File-Count` = "25"
  write.dcf(changed, path, keep.white = names(changed))
  expect_error(refresh$phase02_compare_migration_artifacts(canonical, observed, map),
    "non-identity baseline field drifted: Source-File-Count")
  state$normalized_fingerprint = paste(rep("0", 32), collapse = "")
  expect_error(refresh$phase02_compare_migration_artifacts(canonical, observed, map, state),
    "non-identity baseline field drifted: Source-File-Count")
})
