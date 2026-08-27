provenance_script_path <- function() {
  candidates <- c(
    file.path("tools", "provenance_inventory.R"),
    file.path("..", "..", "tools", "provenance_inventory.R"),
    file.path("..", "..", "..", "tools", "provenance_inventory.R")
  )
  hit <- candidates[file.exists(candidates)]
  if (!length(hit)) stop("Could not locate tools/provenance_inventory.R")
  normalizePath(hit[[1L]], mustWork = TRUE)
}

provenanceToolAvailable = any(file.exists(c(
  file.path("tools", "provenance_inventory.R"),
  file.path("..", "..", "tools", "provenance_inventory.R"),
  file.path("..", "..", "..", "tools", "provenance_inventory.R")
)))
if (!provenanceToolAvailable) {
  test_that = function(desc, code) {
    testthat::test_that(desc, testthat::skip(
      "provenance tooling is excluded from the built package"
    ))
  }
}

provenance_load_tool <- function() {
  environment <- new.env(parent = baseenv())
  sys.source(provenance_script_path(), envir = environment)
  environment
}

provenance_fixture <- function() {
  root <- tempfile("tabloToR-provenance-")
  dir.create(file.path(root, "R"), recursive = TRUE)
  dir.create(file.path(root, "src"), recursive = TRUE)
  dir.create(file.path(root, "tests", "hidden"), recursive = TRUE)
  writeLines(c(
    "alpha <- function(x) {",
    "  nested <- function(y) y + 1",
    "  nested(x)",
    "}",
    "beta = function(value = \"{not code}\") value",
    "GEModel <- methods::setRefClass(",
    "  \"GEModel\",",
    "  methods = list(",
    "    loadTablo = function(path) path,",
    "    solveModel = function() { TRUE }",
    "  )",
    ")"
  ), file.path(root, "R", "model.R"))
  writeLines("ignored <- function() FALSE",
             file.path(root, "tests", "hidden", "ignored.R"))
  writeLines(c(
    "// [[Rcpp::export]]",
    "int add_one(int value) { return value + 1; }",
    "int declaration_only(int value);",
    "static inline int helper(const int value) { return value; }",
    "template <typename T>",
    "T scale_value(T value) {",
    "  return value * 2;",
    "}",
    "#define GENERATED_MACRO(value) ((value) + 1)",
    "void controls(bool ready) {",
    "  if (ready) { return; }",
    "  auto lambda = [](int x) { return x; };",
    "}"
  ), file.path(root, "src", "kernel.cpp"))
  writeLines(c("#pragma once", "int header_declaration(int value);"),
             file.path(root, "src", "empty.hpp"))
  writeLines("# generated fixture", file.path(root, "R", "RcppExports.R"))
  writeLines("// generated fixture", file.path(root, "src", "RcppExports.cpp"))
  root
}

provenance_keys <- function(frame) paste(frame$path, frame$symbol, sep = "::")

provenance_native_fixture_rows <- function(tool, lines, line_ending = "\n") {
  path <- tempfile(fileext = ".cpp")
  on.exit(unlink(path), add = TRUE)
  text <- paste(lines, collapse = line_ending)
  connection <- file(path, open = "wb")
  writeBin(charToRaw(enc2utf8(text)), connection)
  close(connection)
  tool$provenance_native_rows(path, "src/fixture.cpp")
}

provenance_reviewed_ledger <- function(tool, inventory) {
  ledger <- tool$provenance_build_ledger(inventory)
  ledger$classification <- "new-independent"
  ledger$copyright_holder <- "Fixture Author"
  ledger$license_basis <- "fixture-license"
  ledger$evidence <- "fixture review"
  ledger$reviewer <- "Fixture Reviewer"
  ledger$review_date <- "2026-08-25"
  ledger$status <- "reviewed-provisional"
  ledger
}
provenance_repository_path <- function(...) {
  file.path(dirname(dirname(provenance_script_path())), ...)
}

provenance_parse_hash_review <- function(path) {
  if (!file.exists(path)) stop("HASH_REVIEW_MISSING", call. = FALSE)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  header <- function(name) {
    prefix <- paste0(name, ": ")
    hit <- lines[startsWith(lines, prefix)]
    if (length(hit) != 1L) stop("HASH_REVIEW_HEADER_INVALID", call. = FALSE)
    sub(prefix, "", hit[[1L]], fixed = TRUE)
  }
  record_lines <- lines[startsWith(lines, "- key=")]
  expected_fields <- c(
    "key", "old_hash", "proposed_hash", "current_source_identity",
    "current_source_lines", "current_first_local_commit",
    "proposed_classification", "proposed_contributors",
    "proposed_copyright_holder", "proposed_license_basis",
    "proposed_evidence", "proposed_status", "disposition"
  )
  records <- lapply(record_lines, function(line) {
    pieces <- strsplit(sub("^- ", "", line), " | ", fixed = TRUE)[[1L]]
    fields <- sub("=.*$", "", pieces)
    if (!identical(fields, expected_fields)) {
      stop("HASH_REVIEW_RECORD_SCHEMA_INVALID", call. = FALSE)
    }
    values <- sub("^[^=]*=", "", pieces)
    stats::setNames(values, fields)
  })
  rows <- if (length(records)) {
    as.data.frame(do.call(rbind, records), stringsAsFactors = FALSE)
  } else {
    as.data.frame(stats::setNames(
      rep(list(character()), length(expected_fields)), expected_fields
    ), stringsAsFactors = FALSE)
  }
  names <- c(
    "Native-Hash-Schema-Version", "Previous-Schema", "Changed-Row-Count",
    "Stable-Key-Count", "Native-Row-Count", "Canonical-Provenance-MD5",
    "Canonical-Attribution-MD5", "Reviewer", "Review-Date-UTC", "Status"
  )
  list(
    headers = stats::setNames(vapply(names, header, character(1)), c(
      "schema", "previous_schema", "changed_rows", "stable_keys",
      "native_rows", "provenance_md5", "attribution_md5", "reviewer",
      "review_date", "status"
    )),
    rows = rows
  )
}


test_that("empty source roots fail closed with an exact reason", {
  tool <- provenance_load_tool()
  root <- tempfile("tabloToR-empty-provenance-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  expect_error(
    tool$provenance_collect_sources(root, include_git = FALSE),
    "PROVENANCE_SOURCE_EMPTY",
    fixed = TRUE
  )
})

test_that("R, reference-class, and native definitions have stable keys", {
  tool <- provenance_load_tool()
  root <- provenance_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  inventory <- tool$provenance_collect_sources(root, include_git = FALSE)
  expect_identical(provenance_keys(inventory), sort(provenance_keys(inventory)))
  expect_setequal(provenance_keys(inventory), c(
    "R/model.R::alpha",
    "R/model.R::beta",
    "R/model.R::GEModel$loadTablo",
    "R/model.R::GEModel$solveModel",
    "R/RcppExports.R::@generated",
    "src/empty.hpp::@file",
    "src/kernel.cpp::add_one",
    "src/kernel.cpp::controls",
    "src/kernel.cpp::helper",
    "src/kernel.cpp::scale_value",
    "src/RcppExports.cpp::@generated"
  ))
  expect_false(any(grepl("nested|declaration_only|lambda|GENERATED_MACRO",
                         provenance_keys(inventory))))
  alpha_range <- inventory[inventory[["symbol"]] == "alpha",
                           c("line_start", "line_end"), drop = FALSE]
  beta_range <- inventory[inventory[["symbol"]] == "beta",
                          c("line_start", "line_end"), drop = FALSE]
  method_range <- inventory[inventory[["symbol"]] ==
                            paste0("GEModel", intToUtf8(36L), "loadTablo"),
                            c("line_start", "line_end"), drop = FALSE]
  expect_identical(as.integer(alpha_range[1L, ]), c(1L, 4L))
  expect_identical(as.integer(beta_range[1L, ]), c(5L, 5L))
  expect_identical(as.integer(method_range[1L, ]), c(9L, 9L))
  expect_true(all(inventory$line_start >= 1L))
  expect_true(all(inventory$line_end >= inventory$line_start))
  expect_true(all(nzchar(inventory$expression_hash)))

  generated <- inventory[inventory$symbol == "@generated", , drop = FALSE]
  expect_equal(nrow(generated), 2L)
  expect_identical(generated$generated_from,
                   rep("src/kernel.cpp::add_one", 2L))
})

test_that("normalized expression hashes ignore comments and layout", {
  tool <- provenance_load_tool()
  first <- provenance_fixture()
  second <- provenance_fixture()
  on.exit(unlink(c(first, second), recursive = TRUE), add = TRUE)

  writeLines(c(
    "alpha = function ( x ) { # layout-only change",
    "nested = function ( y ) y + 1",
    "nested( x )",
    "}",
    "beta <- function(value = \"{not code}\") value",
    "GEModel <- methods::setRefClass(\"GEModel\", methods=list(",
    "loadTablo=function(path) path, solveModel=function(){TRUE}))"
  ), file.path(second, "R", "model.R"))
  writeLines(c(
    "// [[Rcpp::export]]",
    "int add_one ( int value ) { /* same expression */ return value + 1; }",
    "int declaration_only(int value);",
    "static inline int helper(const int value){return value;}",
    "template<typename T> T scale_value(T value){return value*2;}",
    "#define GENERATED_MACRO(value) ((value) + 1)",
    "void controls(bool ready){if(ready){return;} auto lambda=[](int x){return x;};}"
  ), file.path(second, "src", "kernel.cpp"))

  one <- tool$provenance_collect_sources(first, include_git = FALSE)
  two <- tool$provenance_collect_sources(second, include_git = FALSE)
  matched <- merge(one, two, by = c("path", "symbol"), suffixes = c(".one", ".two"))
  expect_identical(matched$expression_hash.one, matched$expression_hash.two)
})

test_that("native hashes preserve behavior-relevant tokens", {
  tool <- provenance_load_tool()
  hash <- function(lines) {
    rows <- provenance_native_fixture_rows(tool, lines)
    expect_equal(nrow(rows), 1L)
    rows$expression_hash[[1L]]
  }
  base <- c(
    "const char *policy(int value) {",
    "#define MODE 1",
    "#if MODE == 1",
    "  const char marker = 'a';",
    "  return value == 1 ? \"allow\" : \"deny\";",
    "#endif",
    "}"
  )
  variants <- list(
    string_literal = sub("allow", "permit", base, fixed = TRUE),
    character_literal = sub("'a'", "'b'", base, fixed = TRUE),
    numeric_token = sub("value == 1", "value == 2", base, fixed = TRUE),
    define_value = sub("#define MODE 1", "#define MODE 2", base, fixed = TRUE),
    if_condition = sub("#if MODE == 1", "#if MODE == 2", base, fixed = TRUE)
  )
  base_hash <- hash(base)
  variant_hashes <- vapply(variants, hash, character(1))
  expect_true(all(variant_hashes != base_hash))
  expect_equal(length(unique(variant_hashes)), length(variant_hashes))
})

test_that("native normalization ignores comments line endings and safe layout", {
  tool <- provenance_load_tool()
  slash <- intToUtf8(92L)
  quote <- intToUtf8(34L)
  literal <- paste0(
    quote, "allow", slash, quote, "quoted", slash, slash,
    "path//literal", quote
  )
  compact <- c(
    "const char *policy(int value){",
    paste0("return value==1?", literal, ":\"deny/*literal*/\";"),
    "}"
  )
  formatted <- c(
    "const char * policy ( int value ) { // layout only",
    paste0("  return value == 1 ? ", literal, " :"),
    "    \"deny/*literal*/\"; /* trailing comment */",
    "}"
  )
  compact_hash <- provenance_native_fixture_rows(tool, compact)$expression_hash
  formatted_hash <- provenance_native_fixture_rows(tool, formatted)$expression_hash
  crlf_hash <- provenance_native_fixture_rows(
    tool, formatted, line_ending = "\r\n"
  )$expression_hash

  expect_identical(formatted_hash, compact_hash)
  expect_identical(crlf_hash, formatted_hash)
  normalized <- tool$provenance_normalize_native(paste(formatted, collapse = "\n"))
  expect_match(normalized, literal, fixed = TRUE)
  expect_match(normalized, "deny/*literal*/", fixed = TRUE)
  expect_match(normalized, "return value", fixed = TRUE)
  separated <- tool$provenance_normalize_native(
    "const char *value = L \"wide\";"
  )
  expect_match(separated, "L \"wide\"", fixed = TRUE)
})

test_that("structural discovery stays independent from native hash semantics", {
  tool <- provenance_load_tool()
  first <- c(
    "const char *policy() { return \"allow\"; }",
    "int amount() { return 1; }"
  )
  second <- c(
    "const char *policy() { return \"deny!\"; }",
    "int amount() { return 2; }"
  )
  one <- provenance_native_fixture_rows(tool, first)
  two <- provenance_native_fixture_rows(tool, second)

  expect_identical(one[c("path", "symbol", "line_start", "line_end")],
                   two[c("path", "symbol", "line_start", "line_end")])
  expect_false(identical(one$expression_hash, two$expression_hash))
})

test_that("the independent expected-key oracle catches drift in both directions", {
  tool <- provenance_load_tool()
  root <- provenance_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  inventory <- tool$provenance_collect_sources(root, include_git = FALSE)
  expected <- inventory[c("path", "symbol")]

  expect_true(tool$provenance_validate_keys(inventory, expected))
  expect_error(
    tool$provenance_validate_keys(inventory[-1L, ], expected),
    "PROVENANCE_KEY_MISMATCH.*missing=1"
  )
  expect_error(
    tool$provenance_validate_keys(inventory, expected[-1L, ]),
    "PROVENANCE_KEY_MISMATCH.*extra=1"
  )
  rekeyed <- expected
  rekeyed$symbol[[1L]] <- paste0(rekeyed$symbol[[1L]], "_renamed")
  expect_error(
    tool$provenance_validate_keys(inventory, rekeyed),
    "PROVENANCE_KEY_MISMATCH.*rekeyed=TRUE"
  )
  duplicated <- rbind(expected, expected[1L, , drop = FALSE])
  expect_error(
    tool$provenance_validate_keys(inventory, duplicated),
    "PROVENANCE_DUPLICATE_KEY"
  )
})

test_that("regeneration preserves review evidence and flags changed hashes", {
  tool <- provenance_load_tool()
  root <- provenance_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  inventory <- tool$provenance_collect_sources(root, include_git = FALSE)
  existing <- tool$provenance_build_ledger(inventory)
  existing$classification <- "new-independent"
  existing$copyright_holder <- "Fixture Author"
  existing$license_basis <- "fixture-license"
  existing$evidence <- "reviewed fixture evidence"
  existing$reviewer <- "Fixture Reviewer"
  existing$review_date <- "2026-08-25"
  existing$status <- "reviewed-provisional"
  existing$notes <- "review-owned note"

  changed <- inventory
  changed$expression_hash[[1L]] <- paste0("changed-", changed$expression_hash[[1L]])
  regenerated <- tool$provenance_build_ledger(changed, existing)
  expect_identical(regenerated$reviewer, existing$reviewer)
  expect_identical(regenerated$review_date, existing$review_date)
  expect_identical(regenerated$classification, existing$classification)
  expect_identical(regenerated$evidence, existing$evidence)
  expect_identical(regenerated$notes, existing$notes)
  expect_identical(regenerated$status[[1L]], "hash-changed-review-required")
  expect_true(all(regenerated$status[-1L] == "reviewed-provisional"))
})


test_that("check mode validates without rewriting the independent oracle", {
  tool <- provenance_load_tool()
  root <- provenance_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  run_git <- function(arguments) {
    suppressWarnings(system2(
      "/usr/bin/git", c("-C", shQuote(root), arguments),
      stdout = FALSE, stderr = FALSE
    ))
  }
  expect_identical(as.integer(run_git(c("init", "-q"))), 0L)
  expect_identical(as.integer(run_git(
    c("config", "user.name", "Fixture Reviewer")
  )), 0L)
  expect_identical(as.integer(run_git(
    c("config", "user.email", "fixture.invalid")
  )), 0L)
  expect_identical(as.integer(run_git(c("add", "R", "src"))), 0L)
  expect_identical(as.integer(run_git(
    c("commit", "-q", "-m", "fixture")
  )), 0L)

  collector <- get("provenance_collect_sources", envir = tool)
  build_ledger <- get("provenance_build_ledger", envir = tool)
  inventory <- collector(root, include_git = TRUE)
  expected <- inventory[c("path", "symbol")]
  ledger <- build_ledger(inventory)
  generated_symbol <- paste0(intToUtf8(64L), "generated")
  ledger[["classification"]] <- ifelse(
    ledger[["symbol"]] == generated_symbol, "generated", "new-independent"
  )
  ledger[["copyright_holder"]] <- "Fixture Author"
  ledger[["license_basis"]] <- "fixture-license"
  ledger[["evidence"]] <- "fixture review"
  ledger[["reviewer"]] <- "Fixture Reviewer"
  ledger[["review_date"]] <- "2026-08-25"
  ledger[["status"]] <- ifelse(
    ledger[["classification"]] == "generated",
    "reviewed-generated", "reviewed-provisional"
  )
  directory <- file.path(root, "docs", "provenance")
  dir.create(directory, recursive = TRUE)
  expected_path <- file.path(directory, "EXPECTED-KEYS.csv")
  ledger_path <- file.path(directory, "PROVENANCE.csv")
  write.csv(expected, expected_path, row.names = FALSE)
  write.csv(ledger, ledger_path, row.names = FALSE)
  before <- unname(tools::md5sum(expected_path)[[1L]])

  main <- get("provenance_main", envir = tool)
  expect_message(
    main(c("--check", paste0("--root=", root))),
    "provenance_status=reviewed"
  )
  after <- unname(tools::md5sum(expected_path)[[1L]])
  expect_identical(after, before)
})

test_that("repository extraction records stable Git evidence", {
  tool <- provenance_load_tool()
  root <- dirname(dirname(provenance_script_path()))
  collector <- get("provenance_collect_sources", envir = tool)
  inventory <- collector(root, include_git = TRUE)

  expect_true(all(nchar(inventory[["first_local_commit"]]) == 40L &
                  grepl("^[0-9a-f]+", inventory[["first_local_commit"]])))
  expect_true(all(nzchar(inventory[["contributors"]])))
  expect_false(any(inventory[["contributors"]] %in%
                   c("not-evaluated", "uncommitted")))
})

test_that("ledger validation is fixed-schema, exact-key, and fail-closed", {
  tool <- provenance_load_tool()
  root <- provenance_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  inventory <- tool$provenance_collect_sources(root, include_git = FALSE)
  expected <- inventory[c("path", "symbol")]
  ledger <- tool$provenance_build_ledger(inventory)
  ledger$classification <- "new-independent"
  ledger$copyright_holder <- "Fixture Author"
  ledger$license_basis <- "fixture-license"
  ledger$evidence <- "fixture review"
  ledger$reviewer <- "Fixture Reviewer"
  ledger$review_date <- "2026-08-25"
  ledger$status <- "reviewed-provisional"

  expect_true(tool$provenance_validate_ledger(ledger, expected, inventory))
  expect_error(
    tool$provenance_validate_ledger(ledger[, -1L], expected, inventory),
    "PROVENANCE_COLUMNS_MISSING"
  )
  expect_error(
    tool$provenance_validate_ledger(rbind(ledger, ledger[1L, ]), expected, inventory),
    "PROVENANCE_DUPLICATE_KEY"
  )
  third_party <- ledger
  third_party[["classification"]][[1L]] <- "third-party"
  third_party[["upstream_repository"]][[1L]] <- "https://example.invalid/vendor"
  third_party[["upstream_commit"]][[1L]] <- "vendor-1"
  third_party[["upstream_path"]][[1L]] <- third_party[["path"]][[1L]]
  third_party[["copyright_holder"]][[1L]] <- "Fixture Vendor"
  third_party[["license_basis"]][[1L]] <- "fixture-vendor-license"
  third_party[["status"]][[1L]] <- "reviewed-third-party"
  validator <- get("provenance_validate_ledger", envir = tool)
  expect_true(validator(third_party, expected, inventory))
  uncovered <- third_party
  uncovered[["license_basis"]][[1L]] <- ""
  expect_error(
    validator(uncovered, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )

  blocking <- ledger
  blocking$classification[[1L]] <- "unknown"
  expect_error(
    tool$provenance_validate_ledger(blocking, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )
})


test_that("review fields reject arbitrary states impossible dates and mismatches", {
  tool <- provenance_load_tool()
  root <- provenance_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  inventory <- tool$provenance_collect_sources(root, include_git = FALSE)
  expected <- inventory[c("path", "symbol")]
  ledger <- provenance_reviewed_ledger(tool, inventory)

  expect_true(tool$provenance_validate_review_fields(ledger))
  invalid_status <- ledger
  invalid_status$status[[1L]] <- "approved-by-unknown-process"
  expect_error(
    tool$provenance_validate_ledger(invalid_status, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )
  invalid_date <- ledger
  invalid_date$review_date[[1L]] <- "2026-02-30"
  expect_error(
    tool$provenance_validate_ledger(invalid_date, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )
  loose_date <- ledger
  loose_date$review_date[[1L]] <- "2026-8-5"
  expect_error(
    tool$provenance_validate_ledger(loose_date, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )
  mismatched <- ledger
  mismatched$status[[1L]] <- "reviewed-cleared"
  expect_error(
    tool$provenance_validate_ledger(mismatched, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )
})

test_that("accepted native hash migration matches canonical fresh rows", {
  tool <- provenance_load_tool()
  root <- dirname(dirname(provenance_script_path()))
  expected <- tool$provenance_read_csv(
    file.path(root, "docs", "provenance", "EXPECTED-KEYS.csv"),
    c("path", "symbol")
  )
  ledger <- tool$provenance_read_csv(
    file.path(root, "docs", "provenance", "PROVENANCE.csv"),
    tool$provenance_columns
  )
  fresh <- tool$provenance_collect_sources(root, include_git = TRUE)
  ledger_keys <- provenance_keys(ledger)
  proposal <- provenance_parse_hash_review(file.path(
    root, "docs", "provenance", "HASH-REVIEW.md"
  ))

  expect_identical(nrow(expected), 250L)
  expect_identical(nrow(ledger), 250L)
  expect_identical(nrow(fresh), 250L)
  expect_identical(sum(ledger$language == "C/C++"), 55L)
  expect_identical(nrow(proposal$rows), 54L)
  expect_identical(proposal$rows$key, sort(proposal$rows$key))
  expect_false(anyDuplicated(proposal$rows$key) > 0L)

  ledger_id <- match(proposal$rows$key, ledger_keys)
  proposal_fresh_id <- match(proposal$rows$key, provenance_keys(fresh))
  expect_false(anyNA(ledger_id))
  expect_false(anyNA(proposal_fresh_id))
  expect_identical(
    proposal$rows$proposed_hash, fresh$expression_hash[proposal_fresh_id]
  )
  expect_identical(
    proposal$rows$proposed_hash, ledger$expression_hash[ledger_id]
  )
  expect_true(all(proposal$rows$old_hash !=
                  ledger$expression_hash[ledger_id]))
  expect_identical(
    proposal$rows$current_source_identity,
    provenance_keys(fresh)[proposal_fresh_id]
  )
  expect_identical(
    proposal$rows$current_source_lines,
    sprintf("%d-%d", fresh$line_start[proposal_fresh_id],
            fresh$line_end[proposal_fresh_id])
  )
  expect_identical(
    proposal$rows$current_first_local_commit,
    fresh$first_local_commit[proposal_fresh_id]
  )
  expect_identical(
    proposal$rows$proposed_classification, ledger$classification[ledger_id]
  )
  expect_identical(
    proposal$rows$proposed_contributors, ledger$contributors[ledger_id]
  )
  expect_identical(
    proposal$rows$proposed_copyright_holder,
    ledger$copyright_holder[ledger_id]
  )
  expect_identical(
    proposal$rows$proposed_license_basis, ledger$license_basis[ledger_id]
  )
  expect_identical(
    proposal$rows$proposed_evidence, ledger$evidence[ledger_id]
  )
  expect_identical(
    proposal$rows$proposed_status, ledger$status[ledger_id]
  )
  expect_identical(ledger$reviewer[ledger_id], rep("David Zenz", 54L))
  expect_identical(ledger$review_date[ledger_id], rep("2026-08-27", 54L))
  expect_true(all(proposal$rows$disposition == "accepted"))

  expect_identical(proposal$headers[["schema"]], "2")
  expect_identical(proposal$headers[["previous_schema"]],
                   "native-structural-mask-v1")
  expect_identical(proposal$headers[["changed_rows"]], "54")
  expect_identical(proposal$headers[["stable_keys"]], "250")
  expect_identical(proposal$headers[["native_rows"]], "55")
  expect_identical(proposal$headers[["reviewer"]], "David Zenz")
  expect_identical(proposal$headers[["review_date"]], "2026-08-27")
  expect_identical(proposal$headers[["status"]], "accepted")

  provenance_path <- file.path(root, "docs", "provenance", "PROVENANCE.csv")
  attribution_path <- file.path(root, "docs", "provenance", "ATTRIBUTION.md")
  expect_identical(unname(tools::md5sum(provenance_path)[[1L]]),
                   "5f845308997b398cdf404eb1a555ff8f")
  expect_identical(proposal$headers[["provenance_md5"]],
                   "90940fa1b5bdc223b6829255f5e87e71")
  expect_identical(proposal$headers[["attribution_md5"]],
                   "b0812a83fc6022ab54972c65392df309")
  attribution_lines <- readLines(attribution_path, warn = FALSE)
  expect_true(any(attribution_lines == paste0(
    "Inventory-Snapshot-MD5: ",
    unname(tools::md5sum(provenance_path)[[1L]])
  )))
})
