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

nameCheckTool = function() {
  required = c(
    "name_check_validate_name", "name_check_exact_matches",
    "name_check_evaluate_fixture", "name_check_write_report",
    "name_check_verify_report", "name_check_verify_identity"
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
      '"}],"total":1,"limit":100}'
    )),
    github = charToRaw(paste0(
      '{"total_count":1,"items":[{"full_name":"owner/',
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
    "{\"results\":[],\"query\":{\"_nocasepkg\":\"gemodelr\"},\"limit\":100}"
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
    '{"total_count":2,"items":[',
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

test_that("checked-in identity records are explicitly unapproved", {
  tool = nameCheckTool()
  root = nameCheckProjectRoot()
  expect_true(tool$name_check_verify_identity(
    file.path(root, "GOVERNANCE.md"),
    file.path(root, "docs", "release", "REPOSITORY.md"),
    expect = "unapproved"
  ))
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
