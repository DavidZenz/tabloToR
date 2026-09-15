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

test_that("approved serialization evidence starts with exact digests", {
  expectApprovedSerializationEvidence()
})

test_that("historical registry freezes evidence and numerical source", {
  tool = load_identity_migration_tool()
  result = tool$identity_check_historical()

  expect_true(result$clean)
  expect_identical(result$immutable_records, 5L)
  expect_identical(result$protected_source_records, 4L)
  expect_identical(result$protected_region_records, 1L)
  expect_gt(result$historical_occurrences, 1L)

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
  expected = tool$identity_expected_historical_allowlist()
  expect_identical(allowlist, expected)
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
      "UNEXPECTED_OLD_IDENTITY_",
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
    expect_length(location, 1L)
    expect_match(lines[[location + 1L]], "status: flagged-unverified",
                 fixed = TRUE, info = id)
  }
})

predecessorBridgeToolPath = function() {
  candidates = c(
    file.path("tools", "check_predecessor_bridge.R"),
    testthat::test_path("..", "..", "tools", "check_predecessor_bridge.R")
  )
  hits = candidates[file.exists(candidates)]
  if (!length(hits)) {
    testthat::skip("predecessor bridge tool requires the source tree")
  }
  normalizePath(hits[[1L]], mustWork = TRUE)
}

loadPredecessorBridgeTool = function() {
  environment = new.env(parent = globalenv())
  sys.source(predecessorBridgeToolPath(), envir = environment)
  environment
}

test_that("predecessor bridge reproduces exact installed-source evidence", {
  tool = loadPredecessorBridgeTool()
  result = tool$bridge_verify_local()

  expect_true(result$clean)
  expect_identical(result$package_name, "tabloToR")
  expect_identical(result$package_version, "0.1.0")
  expect_match(result$source_fingerprint, "^[0-9a-f]{32}$")
  expect_match(result$fixture_digest, "^[0-9a-f]{64}$")
  expect_identical(result$reproduced_digest, result$fixture_digest)
  expect_true(result$bytes_identical)
  expect_true(result$content_identical)
  expect_true(result$commands_exact)
})
identityDocumentationPath = function(...) {
  relative = file.path(...)
  candidates = c(relative, testthat::test_path("..", "..", relative))
  hit = candidates[file.exists(candidates)]
  if (!length(hit)) {
    stop("Missing identity documentation artifact: ", relative)
  }
  normalizePath(hit[[1L]], mustWork = TRUE)
}

identityDocumentationText = function(...) {
  paste(
    readLines(identityDocumentationPath(...), warn = FALSE,
              encoding = "UTF-8"),
    collapse = "\n"
  )
}

test_that("current documentation and compatibility surfaces use GEModelR", {
  readme = identityDocumentationText("README.md")
  migration = identityDocumentationText("MIGRATION.md")
  main = identityDocumentationText("R", "main.R")
  citation = identityDocumentationText("inst", "CITATION")
  manifest = identityDocumentationText(
    "inst", "compatibility", "MANIFEST.md"
  )
  contract = utils::read.csv(
    identityDocumentationPath(
      "inst", "compatibility", "GEModel-contract.csv"
    ),
    check.names = FALSE, stringsAsFactors = FALSE
  )

  expect_match(readme, "^# GEModelR")
  expect_match(readme, "\\[Migrate from `tabloToR`\\]\\(MIGRATION.md\\)")
  expect_match(readme, "GEModelR::GEModel\\$new\\(\\)")
  expect_match(main, "GEModelR = function", fixed = TRUE)
  expect_false(grepl("tabloToR = function", main, fixed = TRUE))
  expect_match(citation, "To cite GEModelR", fixed = TRUE)
  expect_match(citation, "tabloToR upstream source baseline", fixed = TRUE)
  expect_match(manifest, "Current package identity: `GEModelR`", fixed = TRUE)

  expect_identical(nrow(contract), 234L)
  expect_identical(sum(contract$kind == "export"), 171L)
  expect_true(all(c(
    "GEModelR_eliminate_blocks", "GEModelR_reconstruct_blocks"
  ) %in% contract$name))
  expect_false(any(c(
    "tabloToR_eliminate_blocks", "tabloToR_reconstruct_blocks"
  ) %in% contract$name))

  methods = contract[contract$kind == "method", c("name", "signature")]
  expect_identical(methods$name, c(
    "estimateMemory", "generateSolution", "loadData", "loadTablo",
    "setClosure", "setMemoryBudget", "setShocks", "solveModel",
    "retryPostsim", "saveState", "loadState"
  ))
  expect_identical(
    methods$signature[methods$name == "solveModel"],
    paste0(
      "iter,steps,engine,postsim,diagnostics,output,variables,dimensions,",
      "backend,reduction,memory_budget"
    )
  )
})

test_that("migration guide gives exact immediate-replacement instructions", {
  migration = identityDocumentationText("MIGRATION.md")

  replacements = c(
    "library(tabloToR)" = "library(GEModelR)",
    "require(tabloToR)" = "require(GEModelR)",
    "tabloToR::" = "GEModelR::",
    "Imports: tabloToR" = "Imports: GEModelR",
    "Depends: tabloToR" = "Depends: GEModelR",
    "Suggests: tabloToR" = "Suggests: GEModelR",
    "Enhances: tabloToR" = "Enhances: GEModelR"
  )
  for (old in names(replacements)) {
    expect_match(migration, old, fixed = TRUE, info = old)
    expect_match(migration, replacements[[old]], fixed = TRUE, info = old)
  }

  expect_match(migration, "R CMD INSTALL .", fixed = TRUE)
  expect_match(
    migration,
    "ssh://git@ssh.github.com:443/DavidZenz/tabloToR.git",
    fixed = TRUE
  )
  expect_match(
    migration,
    "ea71afd98b4f165525b9bc0b853e25d4e8998cd8",
    fixed = TRUE
  )
  expect_match(
    migration,
    paste0(
      "R CMD INSTALL --library=\"$TABLOTOR_BRIDGE_LIB\" ",
      "\"$TABLOTOR_BRIDGE_SOURCE\""
    ),
    fixed = TRUE
  )
  expect_match(
    migration,
    paste0(
      "library(tabloToR, ",
      "lib.loc = Sys.getenv(\"TABLOTOR_BRIDGE_LIB\")); ",
      "model = readRDS(Sys.getenv(\"TABLOTOR_RAW_RDS\")); ",
      "model$saveState(Sys.getenv(\"TABLOTOR_LOGICAL_STATE\"))"
    ),
    fixed = TRUE
  )

  reinstall = regexpr("renv::install\\(\"\\.\"\\)", migration)[[1L]]
  snapshot = regexpr("renv::snapshot\\(\\)", migration)[[1L]]
  expect_gt(reinstall, 0L)
  expect_gt(snapshot, reinstall)
  expect_match(migration, "Do not edit `renv.lock` manually", fixed = TRUE)
  expect_match(migration, "raw `saveRDS(model)` ReferenceClass", fixed = TRUE)
  expect_match(migration, "before upgrading", fixed = TRUE)
  expect_match(migration, "does not provide a `tabloToR` shim", fixed = TRUE)
  expect_match(migration, "does not scan options at startup", fixed = TRUE)
})

test_that("all twelve public option replacements are documented exactly", {
  migration = identityDocumentationText("MIGRATION.md")
  suffixes = c(
    "sparse.lu_order",
    "sparse.suite_sparse_ordering",
    "sparse.structured_residual_tolerance",
    "sparse.schur_tolerance",
    "sparse.schur_region_batch_size",
    "sparse.schur_panel_size",
    "sparse.schur_restart",
    "sparse.schur_max_iterations",
    "sparse.schur_refinement_iterations",
    "sparse.schur_cpp_threads",
    "serialization.max_bytes",
    "serialization.max_elements"
  )

  for (suffix in suffixes) {
    expect_match(
      migration, paste0("tabloToR.", suffix), fixed = TRUE, info = suffix
    )
    expect_match(
      migration, paste0("GEModelR.", suffix), fixed = TRUE, info = suffix
    )
  }
})

test_that("retained predecessor identity is categorized for the exact audit", {
  manifest = readLines(
    identityDocumentationPath("inst", "compatibility", "MANIFEST.md"),
    warn = FALSE, encoding = "UTF-8"
  )
  rows = grep("^\\| `[^`]+` \\|", manifest, value = TRUE)
  expect_length(rows, 4L)

  owned = c(
    "README.md", "MIGRATION.md", "inst/CITATION",
    "tests/testthat/test-identity-migration.R"
  )
  for (path in owned) {
    expect_true(any(grepl(paste0("| `", path, "` |"), rows, fixed = TRUE)))
  }
  token = paste0("tablo", "ToR")
  for (path in owned) {
    row = rows[grepl(paste0("| `", path, "` |"), rows, fixed = TRUE)]
    fields = trimws(strsplit(row, "|", fixed = TRUE)[[1L]])
    expected = as.integer(fields[[4L]])
    components = strsplit(path, "/", fixed = TRUE)[[1L]]
    text = do.call(identityDocumentationText, as.list(components))
    hits = gregexpr(token, text, ignore.case = TRUE, perl = TRUE)[[1L]]
    observed = if (identical(hits, -1L)) 0L else length(hits)
    expect_identical(observed, expected, info = path)
  }


  expect_true(any(grepl("upstream-attribution", rows, fixed = TRUE)))
  expect_true(any(grepl("migration-instruction", rows, fixed = TRUE)))
  expect_true(any(grepl("old-option-replacement", rows, fixed = TRUE)))

  expect_false(file.exists(identityDocumentationPath("R", "main.R")) &&
               grepl("tabloToR", identityDocumentationText("R", "main.R"),
                     fixed = TRUE))
})
test_that("tracked identity inventory uses the exact five-category contract", {
  tool = load_identity_migration_tool()
  categories = c(
    "upstream-attribution",
    "migration-instruction",
    "immutable-historical-evidence",
    "old-option-replacement",
    "reviewed-serialization-fingerprint"
  )

  expect_identical(tool$identity_occurrence_categories(), categories)
  allowlist = tool$identity_read_historical_allowlist(
    tool$identity_historical_allowlist_path()
  )
  expect_true(all(allowlist$category %in% categories))
  expect_true(all(categories %in% allowlist$category))

  result = tool$identity_check_occurrences(mode = "tracked-source")
  expect_true(result$clean)
  expect_identical(result$unexpected_occurrences, 0L)
  expect_gt(result$allowlisted_occurrences, 0L)
  expect_gt(result$active_occurrences, 0L)
})

test_that("occurrence allowlist rejects active, broad, duplicate, and stale rows", {
  tool = load_identity_migration_tool()
  root = tool$identity_repository_root()
  allowlist = tool$identity_read_historical_allowlist(
    tool$identity_historical_allowlist_path(root)
  )

  expect_silent(tool$identity_validate_occurrence_allowlist(
    allowlist, root = root, mode = "tracked-source"
  ))

  invalid = list(
    duplicate = rbind(allowlist, allowlist[1L, , drop = FALSE]),
    broad = transform(
      allowlist, path = replace(path, 1L, "benchmarks/*")
    ),
    category = transform(
      allowlist, category = replace(category, 1L, "active-package")
    ),
    count = transform(
      allowlist, expected_count = replace(expected_count, 1L, "999")
    ),
    line_digest = transform(
      allowlist,
      literal_or_line_digest = replace(
        literal_or_line_digest, 1L, paste(rep("0", 64L), collapse = "")
      )
    ),
    stale = transform(
      allowlist, path = replace(path, 1L, "DESCRIPTION")
    )
  )
  for (name in names(invalid)) {
    expect_error(
      tool$identity_validate_occurrence_allowlist(
        invalid[[name]], root = root, mode = "tracked-source"
      ),
      "UNEXPECTED_OLD_IDENTITY_",
      info = name
    )
  }
})
