phase02_tool_path = function(name) {
  normalizePath(
    testthat::test_path("..", "..", "tools", name),
    mustWork = TRUE
  )
}

load_phase02_tool = function(name) {
  environment = new.env(parent = globalenv())
  sys.source(phase02_tool_path(name), envir = environment)
  environment
}

copy_phase02_canonical = function(refresh, destination) {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  files = refresh$phase02_stable_artifact_names()
  copied = file.copy(
    file.path(refresh$phase02_canonical_dir(), files),
    file.path(destination, files)
  )
  stopifnot(all(copied))
  invisible(destination)
}

test_that("proposal generation is explicit compact and deterministic", {
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

  expectations = read.csv(
    file.path(first, "expectations.csv"), stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_identical(
    expectations$value[expectations$key == "solution.names"],
    'q["north"]|q["south"]|q["east"]'
  )
  expect_equal(
    as.numeric(expectations$value[expectations$kind == "value"]),
    c(1, 3, -2), tolerance = 1e-12
  )
})

test_that("stable fingerprints and volatile run metadata are separated", {
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
})

test_that("proposal and check modes cannot mutate canonical artifacts", {
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  canonical = refresh$phase02_canonical_dir()
  before = refresh$phase02_artifact_hash(canonical)
  proposal = tempfile("phase02-proposal-immutable-")

  refresh$phase02_generate_proposal(proposal)
  clean = refresh$phase02_check_baselines()

  expect_true(clean$clean)
  expect_identical(before, refresh$phase02_artifact_hash(canonical))
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
  refresh = load_phase02_tool("refresh_phase02_baselines.R")
  canonical = tempfile("phase02-canonical-copy-")
  copy_phase02_canonical(refresh, canonical)

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
    "Old-Canonical-Hash:", "New-Canonical-Hash:"
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

test_that("acceptance CLI documents the exact reviewed boundary", {
  script = phase02_tool_path("accept_phase02_baselines.R")
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
