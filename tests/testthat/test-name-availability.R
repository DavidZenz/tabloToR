nameCheckProjectRoot = function() {
  candidates = c(".", "../..", "../../..")
  hit = candidates[file.exists(file.path(
    candidates, "tools", "check_name_availability.R"
  ))]
  if (length(hit)) return(normalizePath(hit[[1L]], mustWork = TRUE))
  normalizePath(".", mustWork = TRUE)
}

nameCheckScript = file.path(
  nameCheckProjectRoot(), "tools", "check_name_availability.R"
)
nameCheckEnvironment = new.env(parent = globalenv())
if (file.exists(nameCheckScript)) {
  sys.source(nameCheckScript, envir = nameCheckEnvironment)
}

if (!file.exists(nameCheckScript)) {
  test_that = function(desc, code) {
    testthat::test_that(desc, testthat::skip(
      "name checker tooling is excluded from the built package"
    ))
  }
}

nameCheckTool = function() {
  required = c(
    "name_check_validate_name", "name_check_exact_matches",
    "name_check_evaluate_fixture", "name_check_write_report",
    "name_check_verify_report", "name_check_verify_identity",
    "name_check_parse_count", "name_check_validate_page_set",
    "name_check_collect_pages"
  )
  missing = required[!vapply(
    required, exists, logical(1), envir = nameCheckEnvironment,
    inherits = FALSE
  )]
  if (length(missing)) {
    stop("name availability checker is not implemented", call. = FALSE)
  }
  nameCheckEnvironment
}

nameCheckSourceIds = c(
  "cran-current", "cran-archive", "bioconductor-current",
  "bioconductor-history", "r-universe", "github"
)

nameCheckPayloads = function(name = "AnotherPackage") {
  list(
    `cran-current` = charToRaw(paste0(
      "Package: ", name, "\nVersion: 1.0.0\n"
    )),
    `cran-archive` = charToRaw(paste0(
      "<html><a href=\"", name, "/\">", name, "</a></html>"
    )),
    `bioconductor-current` = charToRaw(paste0(
      "Package: ", name, "\nVersion: 1.0.0\n"
    )),
    `bioconductor-history` = charToRaw(paste0(
      "Bioconductor-Version: 3.22\nPackage: ", name,
      "\nVersion: 1.0.0\n"
    )),
    `r-universe` = charToRaw(paste0(
      '{"results":[{"Package":"', name,
      '"}],"query":{"_nocasepkg":"gemodelr"},',
      '"skip":0,"limit":100,"total":1}'
    )),
    github = charToRaw(paste0(
      '{"total_count":1,"incomplete_results":false,',
      '"items":[{"full_name":"owner/',
      name, '"}]}'
    ))
  )
}

nameCheckFixture = function(payloads = nameCheckPayloads(),
                             available = stats::setNames(
                               rep(TRUE, length(nameCheckSourceIds)),
                               nameCheckSourceIds
                             )) {
  queries = stats::setNames(
    paste0("https://fixture.invalid/", nameCheckSourceIds),
    nameCheckSourceIds
  )
  lapply(nameCheckSourceIds, function(id) {
    list(
      id = id,
      query = queries[[id]],
      available = isTRUE(available[[id]]),
      raw = payloads[[id]]
    )
  })
}

test_that("package-name syntax fails closed with one exact reason", {
  tool = nameCheckTool()
  invalid = list(NULL, "", "G", "GEModelR.", "GE-ModelR", "GЕModelR")
  for (value in invalid) {
    expect_error(
      tool$name_check_validate_name(value),
      "NAME_SYNTAX_INVALID",
      fixed = TRUE
    )
  }
  expect_identical(tool$name_check_validate_name("GEModelR"), "GEModelR")
  expect_identical(tool$name_check_validate_name("A.b2"), "A.b2")
})

test_that("ASCII case folding detects exact names only", {
  tool = nameCheckTool()
  candidates = c(
    "GEModelR", "gemodelr", "GEMODELR", "GEModelRtools",
    "myGEModelR", "GЕModelR"
  )
  expect_identical(
    tool$name_check_exact_matches("GEModelR", candidates),
    c("GEModelR", "gemodelr", "GEMODELR")
  )
})

test_that("required-source failures have stable source-specific reasons", {
  tool = nameCheckTool()

  missing = nameCheckFixture()
  missing = missing[-1L]
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", missing),
    "NAME_SOURCE_MISSING_CRAN_CURRENT",
    fixed = TRUE
  )

  available = stats::setNames(
    rep(TRUE, length(nameCheckSourceIds)), nameCheckSourceIds
  )
  available[["cran-archive"]] = FALSE
  expect_error(
    tool$name_check_evaluate_fixture(
      "GEModelR", nameCheckFixture(available = available)
    ),
    "NAME_SOURCE_UNAVAILABLE_CRAN_ARCHIVE",
    fixed = TRUE
  )

  malformedPayloads = nameCheckPayloads()
  malformedPayloads[["bioconductor-current"]] = charToRaw(
    "not a PACKAGES index"
  )
  expect_error(
    tool$name_check_evaluate_fixture(
      "GEModelR", nameCheckFixture(malformedPayloads)
    ),
    "NAME_SOURCE_MALFORMED_BIOCONDUCTOR_CURRENT",
    fixed = TRUE
  )

  unhashablePayloads = nameCheckPayloads()
  unhashablePayloads[["bioconductor-history"]] = environment()
  expect_error(
    tool$name_check_evaluate_fixture(
      "GEModelR", nameCheckFixture(unhashablePayloads)
    ),
    "NAME_SOURCE_UNHASHABLE_BIOCONDUCTOR_HISTORY",
    fixed = TRUE
  )
})

test_that("R-universe zero-result responses are valid evidence", {
  tool = nameCheckTool()
  payloads = nameCheckPayloads()
  payloads[["r-universe"]] = charToRaw(
    paste0(
      "{\"results\":[],\"query\":{\"_nocasepkg\":\"gemodelr\"},",
      "\"skip\":0,\"limit\":100,\"total\":0}"
    )
  )
  result = tool$name_check_evaluate_fixture(
    "GEModelR", nameCheckFixture(payloads)
  )
  expect_identical(
    result$sources$exact_matches[result$sources$source_id == "r-universe"],
    "NONE"
  )
})

test_that("a clean six-source fixture is ordered, hashed, and reportable", {
  tool = nameCheckTool()
  checkedAt = "2026-08-25T11:00:00Z"
  result = tool$name_check_evaluate_fixture(
    "GEModelR", nameCheckFixture(), check_kind = "initial",
    checked_at = checkedAt
  )
  expect_identical(result$name, "GEModelR")
  expect_identical(result$check_kind, "initial")
  expect_identical(result$checked_at_utc, checkedAt)
  expect_identical(result$overall_result, "NAME_AVAILABLE_NO_EXACT_COLLISION")
  expect_identical(result$sources$source_id, nameCheckSourceIds)
  expect_true(all(result$sources$available == "yes"))
  expect_true(all(result$sources$exact_matches == "NONE"))
  expect_true(all(grepl("^[0-9a-f]{32}$", result$sources$raw_md5)))

  report = tempfile("GEModelR-name-check-", fileext = ".md")
  on.exit(unlink(report), add = TRUE)
  tool$name_check_write_report(result, report)
  expect_true(tool$name_check_verify_report(report, require_review = FALSE))
  lines = readLines(report, warn = FALSE, encoding = "UTF-8")
  expect_true(any(lines == "Name: GEModelR"))
  expect_true(any(lines == "Check-Kind: initial"))
  expect_true(any(lines == paste0("Checked-At-UTC: ", checkedAt)))
  expect_true(any(lines == paste0(
    "Overall-Result: NAME_AVAILABLE_NO_EXACT_COLLISION"
  )))
  expect_true(any(lines == "Reviewer: awaiting-human-approval"))
  expect_true(any(lines == "Review-Date-UTC: awaiting-human-approval"))
  expect_true(any(grepl("not trademark clearance", lines, fixed = TRUE)))
  expect_true(any(grepl("not a reservation", lines, fixed = TRUE)))
})

test_that("a case-insensitive exact collision fails with the exact reason", {
  tool = nameCheckTool()
  payloads = nameCheckPayloads()
  payloads[["github"]] = charToRaw(paste0(
    '{"total_count":2,"incomplete_results":false,"items":[',
    '{"full_name":"owner/gemodelr"},',
    '{"full_name":"owner/GEModelRtools"}]}'
  ))
  expect_error(
    tool$name_check_evaluate_fixture(
      "GEModelR", nameCheckFixture(payloads), check_kind = "reservation"
    ),
    "NAME_EXACT_COLLISION",
    fixed = TRUE
  )
})

test_that("check kinds are restricted to the three release transitions", {
  tool = nameCheckTool()
  for (kind in c("initial", "reservation", "release")) {
    result = tool$name_check_evaluate_fixture(
      "GEModelR", nameCheckFixture(), check_kind = kind
    )
    expect_identical(result$check_kind, kind)
  }
  expect_error(
    tool$name_check_evaluate_fixture(
      "GEModelR", nameCheckFixture(), check_kind = "informal"
    ),
    "NAME_CHECK_KIND_INVALID",
    fixed = TRUE
  )
})

nameCheckPage = function(sourceId, page, raw, query = NULL,
                          role = "results") {
  if (is.null(query)) {
    query = if (identical(sourceId, "github")) {
      paste0(
        "https://api.github.com/search/repositories?q=GEModelR%20in%3Aname",
        "&per_page=2&page=", page
      )
    } else {
      paste0(
        "https://r-universe.dev/api/search?q=package%3AGEModelR",
        "&limit=2&skip=", (page - 1L) * 2L
      )
    }
  }
  list(
    page = as.integer(page), query = query, available = TRUE,
    raw = charToRaw(raw), role = role
  )
}

test_that("declared and returned bounded-search counts must agree", {
  tool = nameCheckTool()
  payloads = nameCheckPayloads()
  payloads[["github"]] = charToRaw(paste0(
    '{"total_count":101,"incomplete_results":false,"items":[',
    '{"full_name":"owner/AnotherPackage"}]}'
  ))
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", nameCheckFixture(payloads)),
    "NAME_SOURCE_INCOMPLETE_GITHUB",
    fixed = TRUE
  )

  payloads = nameCheckPayloads()
  payloads[["r-universe"]] = charToRaw(paste0(
    '{"results":[{"Package":"AnotherPackage"}],',
    '"skip":0,"limit":100,"total":2}'
  ))
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", nameCheckFixture(payloads)),
    "NAME_SOURCE_INCOMPLETE_R_UNIVERSE",
    fixed = TRUE
  )
})

test_that("GitHub page sets are unique contiguous stable and exhaustive", {
  tool = nameCheckTool()
  pages = list(
    nameCheckPage(
      "github", 1L,
      paste0(
        '{"total_count":3,"incomplete_results":false,"items":[',
        '{"full_name":"owner/First"},',
        '{"full_name":"owner/gemodelr"}]}'
      )
    ),
    nameCheckPage(
      "github", 2L,
      paste0(
        '{"total_count":3,"incomplete_results":false,"items":[',
        '{"full_name":"owner/GEModelR"}]}'
      )
    )
  )
  validated = tool$name_check_validate_page_set("github", pages)
  expect_identical(
    validated$candidates,
    c("First", "gemodelr", "GEModelR")
  )
  expect_identical(validated$details$page, c(1L, 2L))
  expect_identical(validated$details$declared_count, c(3L, 3L))
  expect_identical(validated$details$returned_count, c(2L, 1L))

  duplicate = pages
  duplicate[[2L]]$page = 1L
  expect_error(
    tool$name_check_validate_page_set("github", duplicate),
    "NAME_SOURCE_INCOMPLETE_GITHUB",
    fixed = TRUE
  )

  missing = pages
  missing[[2L]]$page = 3L
  missing[[2L]]$query = sub("page=2", "page=3", missing[[2L]]$query)
  expect_error(
    tool$name_check_validate_page_set("github", missing),
    "NAME_SOURCE_INCOMPLETE_GITHUB",
    fixed = TRUE
  )

  changing = pages
  changing[[2L]]$raw = charToRaw(paste0(
    '{"total_count":4,"incomplete_results":false,"items":[',
    '{"full_name":"owner/GEModelR"}]}'
  ))
  expect_error(
    tool$name_check_validate_page_set("github", changing),
    "NAME_SOURCE_INCOMPLETE_GITHUB",
    fixed = TRUE
  )
})

test_that("bounded searches reject overflow truncation and empty mismatches", {
  tool = nameCheckTool()
  overflow = list(nameCheckPage(
    "github", 1L,
    '{"total_count":1001,"incomplete_results":false,"items":[]}'
  ))
  expect_error(
    tool$name_check_validate_page_set("github", overflow),
    "NAME_SOURCE_INCOMPLETE_GITHUB",
    fixed = TRUE
  )

  truncated = list(nameCheckPage(
    "github", 1L,
    paste0(
      '{"total_count":1,"incomplete_results":true,"items":[',
      '{"full_name":"owner/AnotherPackage"}]}'
    )
  ))
  expect_error(
    tool$name_check_validate_page_set("github", truncated),
    "NAME_SOURCE_INCOMPLETE_GITHUB",
    fixed = TRUE
  )

  nonzeroEmpty = list(nameCheckPage(
    "r-universe", 1L,
    '{"results":[],"skip":0,"limit":2,"total":1}'
  ))
  expect_error(
    tool$name_check_validate_page_set("r-universe", nonzeroEmpty),
    "NAME_SOURCE_INCOMPLETE_R_UNIVERSE",
    fixed = TRUE
  )

  missingCount = list(nameCheckPage(
    "github", 1L,
    '{"incomplete_results":false,"items":[]}'
  ))
  expect_error(
    tool$name_check_validate_page_set("github", missingCount),
    "NAME_SOURCE_MALFORMED_GITHUB",
    fixed = TRUE
  )

  zeroGithub = list(nameCheckPage(
    "github", 1L,
    '{"total_count":0,"incomplete_results":false,"items":[]}'
  ))
  zeroRuniverse = list(nameCheckPage(
    "r-universe", 1L,
    '{"results":[],"skip":0,"limit":2,"total":0}'
  ))
  expect_identical(
    tool$name_check_validate_page_set("github", zeroGithub)$candidates,
    character()
  )
  expect_identical(
    tool$name_check_validate_page_set(
      "r-universe", zeroRuniverse
    )$candidates,
    character()
  )
})

test_that("indexed payloads and encodings fail closed", {
  tool = nameCheckTool()
  payloads = nameCheckPayloads()
  payloads[["cran-archive"]] = charToRaw("<html><body></body></html>")
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", nameCheckFixture(payloads)),
    "NAME_SOURCE_MALFORMED_CRAN_ARCHIVE",
    fixed = TRUE
  )

  payloads = nameCheckPayloads()
  payloads[["cran-current"]] = charToRaw(
    "Version: 1.0.0\nRepository: CRAN\n"
  )
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", nameCheckFixture(payloads)),
    "NAME_SOURCE_MALFORMED_CRAN_CURRENT",
    fixed = TRUE
  )

  payloads = nameCheckPayloads()
  payloads[["cran-current"]] = as.raw(c(
    charToRaw("Package: GEModelR"), 255L, charToRaw("\nVersion: 1\n")
  ))
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", nameCheckFixture(payloads)),
    "NAME_SOURCE_MALFORMED_CRAN_CURRENT",
    fixed = TRUE
  )

  payloads = nameCheckPayloads()
  payloads[["cran-current"]] = charToRaw(
    "Package: GЕModelR\nVersion: 1\n"
  )
  expect_error(
    tool$name_check_evaluate_fixture("GEModelR", nameCheckFixture(payloads)),
    "NAME_SOURCE_MALFORMED_CRAN_CURRENT",
    fixed = TRUE
  )
})

test_that("ASCII equal candidates preserve source order", {
  tool = nameCheckTool()
  expect_identical(
    tool$name_check_exact_matches(
      "GEModelR", c("gemodelr", "Other", "GEMODELR", "GEModelR")
    ),
    c("gemodelr", "GEMODELR", "GEModelR")
  )
  expect_error(
    tool$name_check_exact_matches("GEModelR", c("GЕModelR")),
    "NAME_CANDIDATES_INVALID",
    fixed = TRUE
  )
})

nameCheckWriteIdentity = function(root, approved = FALSE,
                                   owner = "approved-owner",
                                   reviewer = "Release reviewer",
                                   reviewDate = "2026-08-25T12:00:00Z") {
  dir.create(
    file.path(root, "docs", "release"), recursive = TRUE,
    showWarnings = FALSE
  )
  pending = "awaiting-human-approval"
  approval = if (approved) "approved" else "unapproved"
  contact = if (approved) "maintainer@example.org" else pending
  security = if (approved) "security@example.org" else pending
  ownerValue = if (approved) owner else pending
  canonical = if (approved) {
    paste0("https://github.com/", owner, "/GEModelR")
  } else {
    pending
  }
  reviewerValue = if (approved) reviewer else pending
  dateValue = if (approved) reviewDate else pending
  governance = c(
    "# Governance fixture", "",
    "Maintainer: David Zenz",
    paste0("Approved-Contact: ", contact),
    "Release-Authority: David Zenz",
    paste0("Security-Route: ", security),
    paste0("Identity-Approval: ", approval),
    paste0("Reviewer: ", reviewerValue),
    paste0("Review-Date-UTC: ", dateValue)
  )
  repository = c(
    "# Repository fixture", "",
    paste0("Owner-Slug: ", ownerValue),
    "Repository-Name: GEModelR",
    paste0("Canonical-URL: ", canonical),
    paste0(
      "Issue-Tracker: ",
      if (approved) paste0(canonical, "/issues") else pending
    ),
    "Visibility-Boundary: private-development",
    paste0("Identity-Approval: ", approval),
    paste0("Reviewer: ", reviewerValue),
    paste0("Review-Date-UTC: ", dateValue),
    "Reservation-Authorization: not-authorized",
    "Visibility-Detachment-Authorization: not-authorized",
    "Branch-Settings-Authorization: not-authorized",
    "Release-Authorization: not-authorized"
  )
  governancePath = file.path(root, "GOVERNANCE.md")
  repositoryPath = file.path(root, "docs", "release", "REPOSITORY.md")
  writeLines(governance, governancePath, useBytes = TRUE)
  writeLines(repository, repositoryPath, useBytes = TRUE)
  c(governance = governancePath, repository = repositoryPath)
}

test_that("checked-in identity records match exact human-approved values", {
  tool = nameCheckTool()
  root = nameCheckProjectRoot()
  governance = readLines(file.path(root, "GOVERNANCE.md"), warn = FALSE)
  repository = readLines(
    file.path(root, "docs", "release", "REPOSITORY.md"), warn = FALSE
  )
  report = readLines(
    file.path(root, "docs", "release", "NAME-CHECK.md"), warn = FALSE
  )
  expect_true(tool$name_check_verify_identity(
    file.path(root, "GOVERNANCE.md"),
    file.path(root, "docs", "release", "REPOSITORY.md"),
    expect = "approved"
  ))
  expect_true(all(c(
    "Approved-Contact: zenz@wiiw.ac.at",
    "Security-Route: mailto:zenz@wiiw.ac.at",
    "Identity-Approval: approved",
    "Reviewer: David Zenz",
    "Review-Date-UTC: 2026-08-25"
  ) %in% governance))
  expect_true(all(c(
    "Owner-Slug: DavidZenz",
    "Canonical-URL: https://github.com/DavidZenz/GEModelR",
    "Issue-Tracker: https://github.com/DavidZenz/GEModelR/issues",
    "Identity-Approval: approved",
    "Reviewer: David Zenz",
    "Review-Date-UTC: 2026-08-25",
    "Reservation-Authorization: not-authorized",
    "Visibility-Detachment-Authorization: not-authorized",
    "Branch-Settings-Authorization: not-authorized",
    "Release-Authorization: not-authorized"
  ) %in% repository))
  expect_true(all(c(
    "Initial-Name-Report: approved",
    "Reviewer: David Zenz",
    "Review-Date-UTC: 2026-08-25"
  ) %in% report))
})

test_that("unapproved identity requires exact pending and authorization markers", {
  tool = nameCheckTool()
  root = tempfile("GEModelR-unapproved-identity-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  paths = nameCheckWriteIdentity(root)
  expect_true(tool$name_check_verify_identity(
    paths[["governance"]], paths[["repository"]], expect = "unapproved"
  ))

  lines = readLines(paths[["governance"]], warn = FALSE)
  lines[lines == "Approved-Contact: awaiting-human-approval"] =
    "Approved-Contact: inferred@example.org"
  writeLines(lines, paths[["governance"]], useBytes = TRUE)
  expect_error(
    tool$name_check_verify_identity(
      paths[["governance"]], paths[["repository"]], expect = "unapproved"
    ),
    "NAME_IDENTITY_UNAPPROVED_INVALID",
    fixed = TRUE
  )

  paths = nameCheckWriteIdentity(root)
  lines = readLines(paths[["repository"]], warn = FALSE)
  lines[lines == "Branch-Settings-Authorization: not-authorized"] =
    "Branch-Settings-Authorization: authorized"
  writeLines(lines, paths[["repository"]], useBytes = TRUE)
  expect_error(
    tool$name_check_verify_identity(
      paths[["governance"]], paths[["repository"]], expect = "unapproved"
    ),
    "NAME_IDENTITY_EXTERNAL_ACTION_AUTHORIZED",
    fixed = TRUE
  )
})

test_that("approved identity enforces derived URLs and signature parity", {
  tool = nameCheckTool()
  root = tempfile("GEModelR-approved-identity-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  paths = nameCheckWriteIdentity(root, approved = TRUE)
  expect_true(tool$name_check_verify_identity(
    paths[["governance"]], paths[["repository"]], expect = "approved"
  ))

  lines = readLines(paths[["repository"]], warn = FALSE)
  lines[startsWith(lines, "Canonical-URL:")] =
    "Canonical-URL: https://github.com/wrong/GEModelR"
  writeLines(lines, paths[["repository"]], useBytes = TRUE)
  expect_error(
    tool$name_check_verify_identity(
      paths[["governance"]], paths[["repository"]], expect = "approved"
    ),
    "NAME_IDENTITY_URL_MISMATCH",
    fixed = TRUE
  )

  paths = nameCheckWriteIdentity(root, approved = TRUE)
  lines = readLines(paths[["repository"]], warn = FALSE)
  lines[startsWith(lines, "Reviewer:")] = "Reviewer: Different reviewer"
  writeLines(lines, paths[["repository"]], useBytes = TRUE)
  expect_error(
    tool$name_check_verify_identity(
      paths[["governance"]], paths[["repository"]], expect = "approved"
    ),
    "NAME_IDENTITY_SIGNATURE_MISMATCH",
    fixed = TRUE
  )
})
