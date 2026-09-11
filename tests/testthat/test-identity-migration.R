identity_migration_tool_path = function() {
  candidates = c(
    file.path("tools", "check_identity_migration.R"),
    testthat::test_path("..", "..", "tools", "check_identity_migration.R")
  )
  hit = candidates[file.exists(candidates)]
  if (!length(hit)) {
    testthat::skip("identity migration tooling requires the source tree")
  }
  normalizePath(hit[[1L]], mustWork = TRUE)
}

load_identity_migration_tool = function() {
  environment = new.env(parent = globalenv())
  sys.source(identity_migration_tool_path(), envir = environment)
  environment
}

write_identity_dcf = function(value, path) {
  write.dcf(
    as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE),
    path, keep.white = names(value), useBytes = TRUE
  )
  invisible(path)
}

test_that("historical registry freezes evidence and numerical source", {
  tool = load_identity_migration_tool()
  result = tool$identity_check_historical()

  expect_true(result$clean)
  expect_identical(result$immutable_records, 5L)
  expect_identical(result$protected_source_records, 4L)
  expect_identical(result$protected_region_records, 1L)
  expect_identical(result$historical_occurrences, 1L)

  registry = result$registry
  source = registry[registry$Category == "protected-numerical-source", ,
                    drop = FALSE]
  expect_identical(
    source$`Record-Id`,
    c(
      "protected-gemodel", "protected-sparse-elimination",
      "protected-sparse-solver", "protected-sparse-schur-complement"
    )
  )
  expect_true(all(source$`Identity-Mode` == "exact-map-v1"))
  expect_identical(
    registry$Region[registry$`Record-Id` == "gemodel-warning-region"],
    "lines-228-228"
  )
})

test_that("every historical registry field fails closed when malformed", {
  tool = load_identity_migration_tool()
  root = tool$identity_repository_root()
  registry = tool$identity_read_historical_registry(
    tool$identity_historical_registry_path(root)
  )
  mutations = list(
    Schema = "gemodelr-historical-evidence-v2",
    `Record-Id` = registry$`Record-Id`[[2L]],
    Category = "unreviewed-evidence",
    Path = "../outside",
    Region = "**",
    `Digest-Algorithm` = "md5",
    `Byte-Digest` = paste(rep("0", 64L), collapse = ""),
    `Identity-Mode` = "wildcard",
    `Predecessor-Identity` = "",
    `Review-State` = "pending",
    `Contract-State` = "mutable",
    Rationale = ""
  )

  for (field in names(mutations)) {
    changed = registry
    changed[1L, field] = mutations[[field]]
    path = tempfile("historical-registry-", fileext = ".dcf")
    write_identity_dcf(changed, path)
    expect_error(
      tool$identity_load_historical_registry(path, root),
      "HISTORICAL_",
      info = field
    )
  }
})

test_that("historical old-identity records reject broad or stale entries", {
  tool = load_identity_migration_tool()
  root = tool$identity_repository_root()
  registry = tool$identity_load_historical_registry(root = root)
  allowlist = tool$identity_read_historical_allowlist(
    tool$identity_historical_allowlist_path(root)
  )
  expect_silent(
    tool$identity_validate_historical_allowlist(allowlist, root, registry)
  )

  invalid = list(
    missing = allowlist[FALSE, , drop = FALSE],
    extra = rbind(allowlist, transform(
      allowlist, path = "benchmarks/GTAP12A_CPP_RESULTS.md"
    )),
    duplicate = rbind(allowlist, allowlist),
    category = transform(allowlist, category = "migration-instruction"),
    broad = transform(allowlist, path = "tests/testthat/baselines/phase02/*"),
    escape = transform(allowlist, path = "../fingerprints.dcf"),
    count = transform(allowlist, expected_count = "2"),
    line_digest = transform(
      allowlist,
      literal_or_line_digest = paste(rep("0", 64L), collapse = "")
    ),
    file_digest = transform(
      allowlist, file_digest = paste(rep("0", 64L), collapse = "")
    )
  )
  for (name in names(invalid)) {
    expect_error(
      tool$identity_validate_historical_allowlist(
        invalid[[name]], root, registry
      ),
      "HISTORICAL_ALLOWLIST_",
      info = name
    )
  }
})

test_that("numerical identity contracts and five assumptions stay frozen", {
  tool = load_identity_migration_tool()
  expect_silent(tool$identity_validate_numerical_contracts())

  plan = testthat::test_path(
    "..", "..", ".planning", "phases",
    "03-gemodelr-identity-migration", "03-01-PLAN.md"
  )
  testthat::skip_if_not(file.exists(plan), "plan metadata is source-only")
  lines = readLines(plan, warn = FALSE, encoding = "UTF-8")
  expected = c(
    "COMP-04-unclassified", "MIGR-01-unclassified",
    "MIGR-02-adjacency", "MIGR-02-empty", "MIGR-02-ordering"
  )
  for (id in expected) {
    location = grep(paste0('id: "', id, '"'), lines, fixed = TRUE)
    expect_length(location, 1L, info = id)
    expect_match(lines[[location + 1L]], "status: flagged-unverified",
                 fixed = TRUE, info = id)
  }
})
