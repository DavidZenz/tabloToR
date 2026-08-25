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
  existing$status <- "reviewed"
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
  expect_true(all(regenerated$status[-1L] == "reviewed"))
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
  ledger$status <- "reviewed"

  expect_true(tool$provenance_validate_ledger(ledger, expected, inventory))
  expect_error(
    tool$provenance_validate_ledger(ledger[, -1L], expected, inventory),
    "PROVENANCE_COLUMNS_MISSING"
  )
  expect_error(
    tool$provenance_validate_ledger(rbind(ledger, ledger[1L, ]), expected, inventory),
    "PROVENANCE_DUPLICATE_KEY"
  )
  blocking <- ledger
  blocking$classification[[1L]] <- "unknown"
  expect_error(
    tool$provenance_validate_ledger(blocking, expected, inventory),
    "PROVENANCE_ROW_BLOCKING"
  )
})
