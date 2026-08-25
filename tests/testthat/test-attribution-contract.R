attributionProjectRoot = function() {
  candidates = c(".", "../..", "../../..")
  hit = candidates[file.exists(file.path(
    candidates, "docs", "provenance", "PROVENANCE.csv"
  ))]
  if (!length(hit)) stop("Could not locate provenance ledger", call. = FALSE)
  normalizePath(hit[[1L]], mustWork = TRUE)
}

attributionPath = function(...) {
  file.path(attributionProjectRoot(), ...)
}

attributionMarker = function(lines, field, required = TRUE) {
  pattern = paste0("^", field, ":[[:space:]]*(.*)$")
  values = sub(pattern, "\\1", grep(pattern, lines, value = TRUE))
  if (required && length(values) != 1L) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  values
}

attributionTable = function(lines, heading) {
  start = which(lines == heading)
  if (length(start) != 1L) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  candidates = seq.int(start + 1L, length(lines))
  candidates = candidates[nzchar(trimws(lines[candidates]))]
  if (length(candidates) < 3L) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  first = candidates[[1L]]
  tableLines = lines[first:length(lines)]
  tableLines = tableLines[startsWith(trimws(tableLines), "|")]
  if (length(tableLines) < 3L) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  splitRow = function(line) {
    trimws(strsplit(sub("^\\||\\|$", "", trimws(line)), "|", fixed = TRUE)[[1L]])
  }
  header = splitRow(tableLines[[1L]])
  separator = splitRow(tableLines[[2L]])
  if (length(separator) != length(header) ||
      !all(grepl("^:?-{3,}:?$", separator))) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  rows = lapply(tableLines[-c(1L, 2L)], splitRow)
  rows = rows[vapply(rows, length, integer(1)) == length(header)]
  if (!length(rows)) stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  frame = as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE,
                        check.names = FALSE)
  names(frame) = header
  frame
}

attributionSplit = function(values) {
  unique(trimws(unlist(strsplit(values, ";", fixed = TRUE))))
}

attributionEvidenceLines = function(path) {
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  values = attributionMarker(lines, "Evidence-Key", required = FALSE)
  sort(unique(values[nzchar(values)]))
}

attributionValidateRows = function(rows, provenanceKeys) {
  required = c(
    "person/entity", "role", "evidence_keys", "rights_basis",
    "destination", "reviewer", "review_date", "status"
  )
  if (!identical(names(rows), required) || !nrow(rows) ||
      any(!nzchar(as.matrix(rows)))) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  if (any(!rows[["role"]] %in% c("aut", "ctb", "cph", "cre")) ||
      any(rows[["status"]] != "reviewed")) {
    stop("ATTRIBUTION_ROLE_UNREVIEWED", call. = FALSE)
  }
  evidence = attributionSplit(rows[["evidence_keys"]])
  if (!length(evidence) || any(!evidence %in% provenanceKeys)) {
    stop("ATTRIBUTION_EVIDENCE_MISSING", call. = FALSE)
  }
  TRUE
}

attributionReadContract = function(root = attributionProjectRoot()) {
  paths = list(
    attribution = file.path(root, "docs", "provenance", "ATTRIBUTION.md"),
    provenance = file.path(root, "docs", "provenance", "PROVENANCE.csv"),
    contributors = file.path(root, "CONTRIBUTORS.md"),
    news = file.path(root, "NEWS.md")
  )
  if (!all(file.exists(unlist(paths)))) {
    stop("ATTRIBUTION_DESTINATION_MISMATCH", call. = FALSE)
  }
  provenance = read.csv(
    paths$provenance, stringsAsFactors = FALSE, colClasses = "character",
    check.names = FALSE, na.strings = NULL
  )
  provenanceKeys = paste(provenance$path, provenance$symbol, sep = "::")
  lines = readLines(paths$attribution, warn = FALSE, encoding = "UTF-8")
  if (attributionMarker(lines, "Attribution-Schema-Version") != "1" ||
      attributionMarker(lines, "Inventory-Path") !=
        "docs/provenance/PROVENANCE.csv" ||
      attributionMarker(lines, "Inventory-Row-Count") !=
        as.character(nrow(provenance)) ||
      attributionMarker(lines, "Inventory-Snapshot-MD5") !=
        unname(tools::md5sum(paths$provenance)[[1L]])) {
    stop("ATTRIBUTION_EVIDENCE_MISSING", call. = FALSE)
  }
  rows = attributionTable(lines, "## Reviewed role assignments")
  attributionValidateRows(rows, provenanceKeys)
  blockers = attributionTable(lines, "## Blocking facts")
  expectedBlockerColumns = c(
    "fact", "evidence_key", "destination", "reason", "reviewer",
    "review_date", "status"
  )
  if (!identical(names(blockers), expectedBlockerColumns) ||
      any(!nzchar(as.matrix(blockers))) ||
      any(blockers$status != "blocking") ||
      any(!blockers$evidence_key %in% provenanceKeys)) {
    stop("ATTRIBUTION_SCHEMA_INVALID", call. = FALSE)
  }
  list(
    rows = rows,
    blockers = blockers,
    evidence = sort(unique(attributionSplit(rows$evidence_keys))),
    paths = paths
  )
}

test_that("reviewed attribution has a fixed schema and inventory snapshot", {
  contract = attributionReadContract()
  expect_identical(
    sort(unique(contract$rows[["person/entity"]])),
    c("David Zenz", "Maros Ivanic")
  )
  expect_setequal(contract$rows$role, c("aut", "cph", "cre"))
  expect_true(all(grepl("^2026-[0-9]{2}-[0-9]{2}$", contract$rows$review_date)))
  expect_true(all(contract$rows$reviewer == "David Zenz"))
})

test_that("unknown evidence and unsupported role promotion fail exactly", {
  keys = c("R/example.R::example")
  valid = data.frame(
    "person/entity" = "Example Person",
    role = "ctb",
    evidence_keys = keys,
    rights_basis = "reviewed fixture",
    destination = "CONTRIBUTORS.md",
    reviewer = "Fixture Reviewer",
    review_date = "2026-08-25",
    status = "reviewed",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_true(attributionValidateRows(valid, keys))

  unknown = valid
  unknown$evidence_keys = "R/missing.R::missing"
  expect_error(
    attributionValidateRows(unknown, keys),
    "ATTRIBUTION_EVIDENCE_MISSING", fixed = TRUE
  )

  promoted = valid
  promoted$role = "fnd"
  expect_error(
    attributionValidateRows(promoted, keys),
    "ATTRIBUTION_ROLE_UNREVIEWED", fixed = TRUE
  )

  pending = valid
  pending$status = "pending"
  expect_error(
    attributionValidateRows(pending, keys),
    "ATTRIBUTION_ROLE_UNREVIEWED", fixed = TRUE
  )
})

test_that("contributors and NEWS use the reviewed evidence key set", {
  contract = attributionReadContract()
  expect_identical(
    attributionEvidenceLines(contract$paths$contributors), contract$evidence
  )
  expect_identical(
    attributionEvidenceLines(contract$paths$news), contract$evidence
  )
  contributorLines = readLines(
    contract$paths$contributors, warn = FALSE, encoding = "UTF-8"
  )
  newsLines = readLines(contract$paths$news, warn = FALSE, encoding = "UTF-8")
  for (person in unique(contract$rows[["person/entity"]])) {
    expect_true(any(grepl(person, contributorLines, fixed = TRUE)))
    expect_true(any(grepl(person, newsLines, fixed = TRUE)))
  }
})

test_that("unresolved facts remain blockers rather than people or roles", {
  contract = attributionReadContract()
  expect_true("PACKAGE_LICENSE_UNFINALIZED" %in% contract$blockers$fact)
  expect_true("GIT_IDENTITY_ALIAS_UNRESOLVED" %in% contract$blockers$fact)
  expect_false(any(grepl(
    "mivanicERS", contract$rows[["person/entity"]], fixed = TRUE
  )))
  expect_false(any(contract$rows$rights_basis ==
                     "Apache License (>= 2.0)"))
})


attributionDestinationContent = function(root, contract) {
  paths = c(
    DESCRIPTION = file.path(root, "DESCRIPTION"),
    README = file.path(root, "README.md"),
    CITATION = file.path(root, "inst", "CITATION"),
    CONTRIBUTORS = file.path(root, "CONTRIBUTORS.md"),
    PROVENANCE = file.path(root, "docs", "provenance", "PROVENANCE.csv"),
    NEWS = file.path(root, "NEWS.md")
  )
  if (!all(file.exists(paths))) {
    stop("ATTRIBUTION_DESTINATION_MISMATCH", call. = FALSE)
  }
  content = vapply(paths, function(path) {
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }, character(1))
  provenance = read.csv(
    paths[["PROVENANCE"]], stringsAsFactors = FALSE,
    colClasses = "character", check.names = FALSE, na.strings = NULL
  )
  content[["PROVENANCE"]] = paste(
    paste(provenance$path, provenance$symbol, sep = "::"),
    provenance$contributors, provenance$copyright_holder,
    provenance$license_basis, collapse = "\n"
  )
  people = unique(contract$rows[["person/entity"]])
  valid = vapply(content, function(value) {
    all(vapply(contract$evidence, grepl, logical(1), x = value, fixed = TRUE)) &&
      all(vapply(people, grepl, logical(1), x = value, fixed = TRUE))
  }, logical(1))
  if (!all(valid)) {
    stop("ATTRIBUTION_DESTINATION_MISMATCH", call. = FALSE)
  }
  content
}

attributionCitationRecords = function(path, meta) {
  environment = new.env(parent = baseenv())
  environment$meta = meta
  environment$records = list()
  environment$citHeader = function(...) invisible(NULL)
  environment$citFooter = function(...) invisible(NULL)
  environment$person = utils::person
  environment$as.person = utils::as.person
  environment$bibentry = function(...) {
    environment$records[[length(environment$records) + 1L]] = list(...)
    invisible(NULL)
  }
  sys.source(path, envir = environment)
  environment$records
}

test_that("DESCRIPTION applies only reviewed roles without renaming or licensing", {
  description = read.dcf(attributionPath("DESCRIPTION"))
  expect_identical(unname(description[[1L, "Package"]]), "tabloToR")
  expect_identical(
    unname(description[[1L, "License"]]), "What license is it under?"
  )
  expect_true("Authors@R" %in% colnames(description))
  expect_identical(
    unname(description[[1L, "Author"]]),
    "David Zenz [aut, cre, cph], Maros Ivanic [aut]"
  )
  authorEnvironment = list2env(
    list(person = utils::person), parent = baseenv()
  )
  authors = eval(
    parse(text = unname(description[[1L, "Authors@R"]])),
    envir = authorEnvironment
  )
  expect_identical(
    vapply(seq_along(authors), function(index) {
      paste(authors$given[[index]], authors$family[[index]])
    }, character(1)),
    c("David Zenz", "Maros Ivanic")
  )
  expect_setequal(authors$role[[1L]], c("aut", "cre", "cph"))
  expect_identical(authors$role[[2L]], "aut")
  expect_identical(authors$email[[1L]], "zenz@wiiw.ac.at")
  expect_null(authors$email[[2L]])
})

test_that("README records the reviewed predecessor and blocked boundary", {
  lines = readLines(attributionPath("README.md"), warn = FALSE,
                    encoding = "UTF-8")
  text = paste(lines, collapse = "\n")
  expect_true(grepl("https://github.com/mivanic/tabloToR", text, fixed = TRUE))
  expect_true(grepl(
    "7e063c65a19713857ed13023f8b77dad45b15c90", text, fixed = TRUE
  ))
  expect_true(grepl("docs/provenance/ATTRIBUTION.md", text, fixed = TRUE))
  expect_true(grepl("docs/provenance/RIGHTS.md", text, fixed = TRUE))
  expect_true(grepl("public redistribution remains blocked", text,
                    fixed = TRUE))
})

test_that("CITATION derives package fields and retains predecessor evidence", {
  citationPath = attributionPath("inst", "CITATION")
  records = attributionCitationRecords(citationPath, list(
    Title = "Fixture title",
    Version = "9.9.9",
    Author = "David Zenz and Maros Ivanic"
  ))
  expect_length(records, 2L)
  expect_identical(records[[1L]]$title, "Fixture title")
  expect_identical(records[[1L]]$author,
                   utils::as.person("David Zenz and Maros Ivanic"))
  expect_true(grepl("9.9.9", records[[1L]]$note, fixed = TRUE))
  expect_true(grepl("Maros Ivanic", format(records[[2L]]$author),
                    fixed = TRUE))
  expect_true(grepl(
    "7e063c65a19713857ed13023f8b77dad45b15c90",
    records[[2L]]$url, fixed = TRUE
  ))
})

test_that("all six attribution destinations have exact key parity", {
  root = attributionProjectRoot()
  contract = attributionReadContract(root)
  content = attributionDestinationContent(root, contract)
  expect_identical(
    names(content),
    c("DESCRIPTION", "README", "CITATION", "CONTRIBUTORS", "PROVENANCE", "NEWS")
  )

  stale = contract
  stale$evidence = c(contract$evidence, "R/missing.R::missing")
  expect_error(
    attributionDestinationContent(root, stale),
    "ATTRIBUTION_DESTINATION_MISMATCH", fixed = TRUE
  )
})
