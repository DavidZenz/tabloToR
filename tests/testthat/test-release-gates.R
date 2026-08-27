releaseGateProjectRoot <- function() {
  candidates <- c(".", "../..", "../../..")
  hit <- candidates[file.exists(file.path(
    candidates, "tools", "check_release_gates.R"
  ))]
  if (length(hit)) return(normalizePath(hit[[1L]], mustWork = TRUE))
  normalizePath(".", mustWork = TRUE)
}

releaseGateScript <- file.path(
  releaseGateProjectRoot(), "tools", "check_release_gates.R"
)
releaseGateEnvironment <- new.env(parent = globalenv())
if (file.exists(releaseGateScript)) {
  sys.source(releaseGateScript, envir = releaseGateEnvironment)
}

if (!file.exists(releaseGateScript)) {
  test_that = function(desc, code) {
    testthat::test_that(desc, testthat::skip(
      "release gate tooling is excluded from the built package"
    ))
  }
}

evaluateReleaseGate <- function(root) {
  if (!exists("release_gate_evaluate", envir = releaseGateEnvironment,
              inherits = FALSE)) {
    stop("release gate checker is not implemented", call. = FALSE)
  }
  releaseGateEnvironment$release_gate_evaluate(root)
}

evaluateRightsGate <- function(root) {
  releaseGateEnvironment$release_gate_evaluate_rights(root)
}

runRightsGate <- function(root) {
  result <- evaluateRightsGate(root)
  output <- capture.output(
    releaseGateEnvironment$release_gate_print_result(result)
  )
  list(
    status = if (isTRUE(result$release_ready)) 0L else 1L,
    output = output
  )
}

runReleaseGate <- function(args) {
  output <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    shQuote(c("--vanilla", releaseGateScript, args)),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(output, "status")
  list(
    status = if (is.null(status)) 0L else as.integer(status),
    output = output
  )
}

expectReleaseGateFailure <- function(command, reason) {
  expect_identical(command$status, 1L)
  expect_true(any(command$output == paste0("reason_codes=", reason)))
  expect_false(any(grepl(
    "mivanic|fixture-reviewer|upstream-fixture",
    command$output,
    ignore.case = TRUE
  )))
}

releaseRequestAsks <- c(
  "explicit-open-source-license",
  "modification-and-public-redistribution",
  "attributed-GEModelR-name"
)

releaseGateMarker <- function(lines, field) {
  pattern <- paste0("^", field, ":[[:space:]]*(.*)$")
  sub(pattern, "\\1", grep(pattern, lines, value = TRUE))
}

writeReleaseRequestFixture <- function(root, asks = releaseRequestAsks) {
  path <- file.path(root, "docs", "provenance", "UPSTREAM-REQUEST.md")
  writeLines(c(
    "# Upstream rights request fixture",
    "Request-Document-Version: 1",
    "Upstream-Repository: https://github.com/mivanic/tabloToR",
    "Upstream-Commit: upstream-fixture-commit",
    paste0("Request-Ask: ", asks)
  ), path, useBytes = TRUE)
  unname(tools::md5sum(path)[[1L]])
}

writeReleaseGateFixture <- function(root, rightsStatus = "blocked",
                                    releaseStatus = rightsStatus,
                                    includeStatus = TRUE,
                                    duplicateStatus = FALSE,
                                    includeScope = FALSE,
                                    requestStatus = if (
                                      identical(rightsStatus, "blocked")
                                    ) "draft" else "resolved",
                                    requestAsks = releaseRequestAsks,
                                    requestHash = NULL,
                                    requestUrl = if (
                                      requestStatus %in% c(
                                        "draft", "reviewed-unposted"
                                      )
                                    ) "not-posted" else
                                      "https://example.invalid/public-request",
                                    requestDate = if (
                                      requestStatus %in% c(
                                        "draft", "reviewed-unposted"
                                      )
                                    ) "not-posted" else
                                      "2026-08-25T00:00:00Z",
                                    intentionalBlockers = if (
                                      identical(rightsStatus, "blocked")
                                    ) paste(c(
                                      "RIGHTS_BLOCKED",
                                      if (requestStatus %in% c(
                                        "draft", "reviewed-unposted"
                                      )) "REQUEST_NOT_POSTED" else
                                        "REQUEST_NOT_A_GRANT"
                                    ), collapse = ",") else "NONE") {
  dir.create(file.path(root, "docs", "provenance"), recursive = TRUE)
  dir.create(file.path(root, "docs", "release"), recursive = TRUE)
  actualRequestHash <- writeReleaseRequestFixture(root, requestAsks)
  if (is.null(requestHash)) requestHash <- actualRequestHash
  statusLines <- if (includeStatus) {
    rep(paste0("Rights-Status: ", rightsStatus),
        if (duplicateStatus) 2L else 1L)
  } else {
    character()
  }
  rightsLines <- c(
    "# Rights Fixture",
    statusLines,
    "Upstream-Repository: https://github.com/mivanic/tabloToR",
    "Upstream-Commit: upstream-fixture-commit",
    paste0("Request-Status: ", requestStatus),
    paste0("Request-URL: ", requestUrl),
    paste0("Request-Date-UTC: ", requestDate),
    paste0("Request-Content-Hash: ", requestHash),
    "Evidence-Hash: 0123456789abcdef0123456789abcdef",
    "Reviewer: fixture-reviewer",
    "Review-Date-UTC: 2026-08-25"
  )
  if (includeScope) {
    rightsLines <- c(
      rightsLines,
      "Covered-Upstream-Commit: upstream-fixture-commit",
      "Covered-Components: inherited-source"
    )
  }
  writeLines(rightsLines, file.path(root, "docs", "provenance", "RIGHTS.md"))
  writeLines(c(
    "# Release Gate Fixture",
    paste0("Rights-Gate-Status: ", releaseStatus),
    paste0("Intentional-Blockers: ", intentionalBlockers)
  ), file.path(root, "docs", "release", "RELEASE-GATES.md"))
}

writePublicDomainFixture <- function(
    root,
    coverageStatus = "complete",
    coveredComponents = "upstream-authored-inherited-source",
    excludedComponents = "unrelated-third-party-components",
    tamperEvidence = FALSE) {
  blockers <- if (identical(coverageStatus, "complete")) {
    "NONE"
  } else {
    "PROVENANCE_COVERAGE_INCOMPLETE"
  }
  writeReleaseGateFixture(
    root,
    rightsStatus = "cleared",
    requestStatus = "superseded-by-public-response",
    requestUrl = "https://github.com/mivanic/tabloToR/issues/3",
    requestDate = "2026-08-24T13:19:21Z",
    intentionalBlockers = blockers
  )
  responsePath <- file.path(
    root, "docs", "provenance", "UPSTREAM-RESPONSE.md"
  )
  writeLines(c(
    "Response-Document-Version: 1",
    "Upstream-Repository: https://github.com/mivanic/tabloToR",
    "Upstream-Commit: upstream-fixture-commit",
    paste0(
      "Response-URL: ",
      "https://github.com/mivanic/tabloToR/issues/3#issuecomment-5398979852"
    ),
    "Response-Date-UTC: 2026-08-24T17:35:21Z",
    "Response-Author-GitHub: mivanic",
    "Response-Author-Association: OWNER",
    paste0(
      "Response-Statement: ",
      "It is in the public domain (CC0)--I created it as part of my duties ",
      "as an employee of the US federal government, and so I do not retain ",
      "any copyright."
    ),
    "CC0-Reference: https://creativecommons.org/publicdomain/zero/1.0/",
    paste0(
      "US-Government-Works-Reference: ",
      "https://uscode.house.gov/view.xhtml?section105"
    )
  ), responsePath, useBytes = TRUE)
  evidenceHash <- unname(tools::md5sum(responsePath)[[1L]])
  rightsPath <- file.path(root, "docs", "provenance", "RIGHTS.md")
  rightsLines <- readLines(rightsPath, warn = FALSE, encoding = "UTF-8")
  rightsLines[grepl("^Evidence-Hash:", rightsLines)] <- paste0(
    "Evidence-Hash: ", evidenceHash
  )
  rightsLines <- c(
    rightsLines,
    "Rights-Basis: public-domain-cc0",
    "Covered-Upstream-Commit: upstream-fixture-commit",
    paste0("Covered-Components: ", coveredComponents),
    paste0("Excluded-Components: ", excludedComponents),
    paste0("Provenance-Coverage-Status: ", coverageStatus),
    "Evidence-Document: docs/provenance/UPSTREAM-RESPONSE.md",
    paste0(
      "Response-URL: ",
      "https://github.com/mivanic/tabloToR/issues/3#issuecomment-5398979852"
    ),
    "Response-Date-UTC: 2026-08-24T17:35:21Z",
    "Response-Author-GitHub: mivanic",
    "Response-Author-Association: OWNER",
    "Response-Review-Status: accepted-public-domain-cc0",
    "Successor-Name-Basis: independently-selected",
    "Name-Availability-Status: approved-initial-report"
  )
  writeLines(rightsLines, rightsPath, useBytes = TRUE)
  if (tamperEvidence) {
    write("tampered", responsePath, append = TRUE)
  }
}

test_that("the checked-in repository is positively recognized as blocked", {
  root <- releaseGateProjectRoot()
  result <- evaluateReleaseGate(root)

  expect_identical(result$repository_state, "blocked")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    c("DEPENDENCY_COMPATIBILITY_AUDIT_PENDING",
      "ATTRIBUTION_IDENTITY_UNRESOLVED")
  )
  expect_identical(
    unname(result$parse_status),
    rep("pass", 12L)
  )

  command <- runReleaseGate(c("--root", root, "--assert-blocked"))
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "repository_state=blocked"))
  expect_true(any(command$output == "release_ready=false"))
  expect_true(any(command$output == paste0(
    "reason_codes=DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED"
  )))
})

test_that("the superseded D-01 request is historical and hash-bound", {
  root <- releaseGateProjectRoot()
  requestPath <- file.path(
    root, "docs", "provenance", "UPSTREAM-REQUEST.md"
  )
  rightsPath <- file.path(root, "docs", "provenance", "RIGHTS.md")
  expect_true(file.exists(requestPath))

  requestLines <- readLines(requestPath, warn = FALSE, encoding = "UTF-8")
  rightsLines <- readLines(rightsPath, warn = FALSE, encoding = "UTF-8")
  expect_setequal(
    releaseGateMarker(requestLines, "Request-Ask"),
    releaseRequestAsks
  )
  expect_identical(
    releaseGateMarker(requestLines, "Request-Artifact-Status"),
    "superseded-do-not-post"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Request-Status"),
    "superseded-by-public-response"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Request-Content-Hash"),
    unname(tools::md5sum(requestPath)[[1L]])
  )
})

test_that("the public-domain response is accepted with limited scope", {
  root <- releaseGateProjectRoot()
  rightsPath <- file.path(root, "docs", "provenance", "RIGHTS.md")
  responsePath <- file.path(
    root, "docs", "provenance", "UPSTREAM-RESPONSE.md"
  )
  rightsLines <- readLines(rightsPath, warn = FALSE, encoding = "UTF-8")
  responseLines <- readLines(responsePath, warn = FALSE, encoding = "UTF-8")

  expect_identical(
    releaseGateMarker(rightsLines, "Rights-Basis"),
    "public-domain-cc0"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Evidence-Hash"),
    unname(tools::md5sum(responsePath)[[1L]])
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Covered-Components"),
    "upstream-authored-inherited-source"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Excluded-Components"),
    "unrelated-third-party-components"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Provenance-Coverage-Status"),
    "complete"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Response-Review-Status"),
    "accepted-public-domain-cc0"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Successor-Name-Basis"),
    "independently-selected"
  )
  expect_identical(
    releaseGateMarker(rightsLines, "Name-Availability-Status"),
    "approved-initial-report"
  )
  expect_identical(
    releaseGateMarker(responseLines, "Response-Statement"),
    paste(
      "It is in the public domain (CC0)--I created it as part of my duties",
      "as an employee of the US federal government, and so I do not retain",
      "any copyright."
    )
  )
  expect_identical(
    releaseGateMarker(responseLines, "CC0-Reference"),
    "https://creativecommons.org/publicdomain/zero/1.0/"
  )
  expect_true(startsWith(
    releaseGateMarker(responseLines, "US-Government-Works-Reference"),
    "https://uscode.house.gov/"
  ))
})

test_that("omitting any D-01 ask fails with the exact scope reason", {
  for (ask in releaseRequestAsks) {
    root <- tempfile("release-gate-request-scope-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeReleaseGateFixture(
      root,
      requestAsks = setdiff(releaseRequestAsks, ask)
    )

    result <- evaluateRightsGate(root)
    expect_identical(result$repository_state, "invalid")
    expect_false(result$release_ready)
    expect_identical(result$reason_codes, "REQUEST_SCOPE_INCOMPLETE")
  }
})

test_that("a changed request fails with the exact hash reason", {
  root <- tempfile("release-gate-request-hash-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(
    root,
    requestHash = "00000000000000000000000000000000"
  )

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(result$reason_codes, "REQUEST_HASH_MISMATCH")
})

test_that("silence and ambiguous responses are never grants", {
  for (requestStatus in c(
    "posted-pending", "response-received-review-pending"
  )) {
    root <- tempfile("release-gate-request-response-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeReleaseGateFixture(root, requestStatus = requestStatus)

    result <- evaluateRightsGate(root)
    expect_identical(result$repository_state, "blocked")
    expect_false(result$release_ready)
    expect_identical(
      result$reason_codes,
      c("RIGHTS_BLOCKED", "REQUEST_NOT_A_GRANT")
    )
  }
})

test_that("missing or duplicate rights status has an exact parser reason", {
  for (duplicate in c(FALSE, TRUE)) {
    root <- tempfile("release-gate-status-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeReleaseGateFixture(
      root,
      includeStatus = duplicate,
      duplicateStatus = duplicate
    )

    result <- evaluateRightsGate(root)
    expect_identical(result$repository_state, "invalid")
    expect_false(result$release_ready)
    expect_identical(result$reason_codes, "RIGHTS_STATUS_CARDINALITY")
    expectReleaseGateFailure(
      runRightsGate(root),
      "RIGHTS_STATUS_CARDINALITY"
    )
  }
})

test_that("rights and release policy status must agree", {
  root <- tempfile("release-gate-mismatch-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(root, releaseStatus = "cleared")

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "RIGHTS_RELEASE_STATUS_MISMATCH"
  )
  expectReleaseGateFailure(
    runRightsGate(root),
    "RIGHTS_RELEASE_STATUS_MISMATCH"
  )
})

test_that("written clearance must cover the inherited commit and components", {
  root <- tempfile("release-gate-scope-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(root, rightsStatus = "cleared")

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(result$reason_codes, "RIGHTS_SCOPE_INCOMPLETE")
  expectReleaseGateFailure(
    runRightsGate(root),
    "RIGHTS_SCOPE_INCOMPLETE"
  )
})

cleanroomSpecificationFields <- c(
  "component_id", "provenance_key", "inputs", "outputs", "errors",
  "invariants", "compatibility_example", "specification_author",
  "specification_attestation", "implementer", "implementer_eligibility",
  "implementer_source_access", "implementer_attestation", "reviewer",
  "reviewer_attestation", "behavior_test", "behavior_test_status",
  "public_standard", "redistributable_fixture",
  "provenance_classification"
)

writeCleanroomComponentFixture <- function(
    root,
    provenanceKey = "R/example.R::example",
    sourceAccess = "none",
    omitField = NULL,
    specificationAuthor = "fixture-specification-author",
    implementer = "fixture-independent-implementer",
    reviewer = "fixture-independent-reviewer",
    redistributableFixture = "redistributable:synthetic-example") {
  dir.create(file.path(root, "specs", "cleanroom"), recursive = TRUE)
  values <- c(
    component_id = "example-component",
    provenance_key = provenanceKey,
    inputs = "numeric scalar x",
    outputs = "numeric scalar y",
    errors = "non-numeric input is rejected",
    invariants = "output length equals input length",
    compatibility_example = "x=1 produces y=1",
    specification_author = specificationAuthor,
    specification_attestation = "behavior-only-no-inherited-expression",
    implementer = implementer,
    implementer_eligibility = "eligible",
    implementer_source_access = sourceAccess,
    implementer_attestation = "no-inherited-source-access",
    reviewer = reviewer,
    reviewer_attestation = "independent-review-complete",
    behavior_test = "tests/testthat/test-cleanroom-example.R#observable-contract",
    behavior_test_status = "pass",
    public_standard = "public:documented-R-semantics",
    redistributable_fixture = redistributableFixture,
    provenance_classification = "new-independent"
  )
  if (!is.null(omitField)) values <- values[names(values) != omitField]
  writeLines(
    c("# Clean-room component fixture", paste0(names(values), ": ", values)),
    file.path(root, "specs", "cleanroom", "example-component.md")
  )
}

writeCleanroomFixture <- function(
    root,
    reviewStatus = "approved",
    inheritedKeys = "R/example.R::example",
    provenanceKey = inheritedKeys[[1L]],
    sourceAccess = "none",
    omitField = NULL,
    specificationAuthor = "fixture-specification-author",
    implementer = "fixture-independent-implementer",
    reviewer = "fixture-independent-reviewer",
    redistributableFixture = "redistributable:synthetic-example") {
  writeReleaseGateFixture(root, rightsStatus = "clean-room-required")
  writeLines(c(
    "# Clean-room Fixture",
    "Cleanroom-Protocol-Version: 1",
    "Cleanroom-Coverage: complete",
    paste0("Cleanroom-Review-Status: ", reviewStatus),
    paste0("Inherited-Provenance-Key: ", inheritedKeys)
  ), file.path(root, "docs", "provenance", "CLEANROOM.md"))
  writeCleanroomComponentFixture(
    root,
    provenanceKey = provenanceKey,
    sourceAccess = sourceAccess,
    omitField = omitField,
    specificationAuthor = specificationAuthor,
    implementer = implementer,
    reviewer = reviewer,
    redistributableFixture = redistributableFixture
  )
}

test_that("the clean-room protocol and template expose the complete contract", {
  root <- releaseGateProjectRoot()
  protocolPath <- file.path(root, "docs", "provenance", "CLEANROOM.md")
  templatePath <- file.path(root, "specs", "cleanroom", "README.md")
  expect_true(file.exists(protocolPath))
  expect_true(file.exists(templatePath))

  protocol <- readLines(protocolPath, warn = FALSE, encoding = "UTF-8")
  template <- readLines(templatePath, warn = FALSE, encoding = "UTF-8")
  expect_true(any(grepl("distinct", protocol, ignore.case = TRUE)))
  expect_true(any(grepl("source-access", protocol, ignore.case = TRUE)))
  expect_true(any(grepl("inherited source excerpts", template,
                        ignore.case = TRUE)))
  expect_true(any(grepl("proprietary fixtures", template,
                        ignore.case = TRUE)))
  for (field in cleanroomSpecificationFields) {
    expect_true(any(grepl(
      paste0("`", field, "`"), template, fixed = TRUE
    )), info = field)
  }
})

test_that("source-exposed clean-room implementers are ineligible", {
  root <- tempfile("release-gate-cleanroom-source-exposed-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(root, sourceAccess = "inherited-source-exposed")

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "blocked")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "CLEANROOM_IMPLEMENTER_INELIGIBLE"
  )
})

test_that("clean-room role and evidence omissions fail exactly", {
  for (field in c(
    "behavior_test", "reviewer", "specification_attestation",
    "implementer_attestation", "reviewer_attestation", "provenance_key"
  )) {
    root <- tempfile("release-gate-cleanroom-evidence-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeCleanroomFixture(root, omitField = field)

    result <- evaluateRightsGate(root)
    expect_identical(result$repository_state, "blocked", info = field)
    expect_false(result$release_ready, info = field)
    expect_identical(
      result$reason_codes,
      "CLEANROOM_EVIDENCE_INCOMPLETE",
      info = field
    )
  }

  duplicateRole <- tempfile("release-gate-cleanroom-roles-")
  on.exit(unlink(duplicateRole, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(
    duplicateRole,
    implementer = "fixture-specification-author"
  )
  expect_identical(
    evaluateRightsGate(duplicateRole)$reason_codes,
    "CLEANROOM_EVIDENCE_INCOMPLETE"
  )
})

test_that("clean-room coverage must cover every inherited provenance key", {
  root <- tempfile("release-gate-cleanroom-coverage-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(
    root,
    inheritedKeys = c("R/example.R::example", "R/uncovered.R::uncovered")
  )

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "blocked")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "CLEANROOM_EVIDENCE_INCOMPLETE"
  )
})

test_that("clean-room fixtures must be explicitly redistributable", {
  root <- tempfile("release-gate-cleanroom-proprietary-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(root, redistributableFixture = "proprietary:private")

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "blocked")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "CLEANROOM_EVIDENCE_INCOMPLETE"
  )
})

test_that("the clean-room tree rejects sensitive fixture classes", {
  root <- tempfile("release-gate-cleanroom-sensitive-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(root)
  sentinel <- "do-not-disclose-cleanroom-fixture"
  writeLines(sentinel, file.path(root, "specs", "cleanroom", "fixture.har"))

  command <- runRightsGate(root)
  expectReleaseGateFailure(command, "SENSITIVE_EVIDENCE_CLASS")
  expect_false(any(grepl(sentinel, command$output, fixed = TRUE)))
  expect_false(any(grepl("fixture.har", command$output, fixed = TRUE)))
})

test_that("complete public-domain evidence proves synthetic readiness", {
  root <- tempfile("release-gate-public-domain-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writePublicDomainFixture(root)

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)
  expect_identical(
    unname(result$parse_status),
    c("pass", "pass", "pass", "pass")
  )
})

test_that("public-domain evidence remains blocked until provenance is complete", {
  root <- tempfile("release-gate-public-domain-coverage-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writePublicDomainFixture(root, coverageStatus = "pending-audit")

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "blocked")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "PROVENANCE_COVERAGE_INCOMPLETE"
  )
})

test_that("changed public-domain evidence fails its hash binding", {
  root <- tempfile("release-gate-public-domain-hash-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writePublicDomainFixture(root, tamperEvidence = TRUE)

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "PUBLIC_DOMAIN_EVIDENCE_HASH_MISMATCH"
  )
})

test_that("public-domain scope never covers unrelated third-party code", {
  cases <- list(
    covered = c("all-inherited-source", "unrelated-third-party-components"),
    excluded = c("upstream-authored-inherited-source", "none")
  )
  for (name in names(cases)) {
    root <- tempfile("release-gate-public-domain-scope-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    values <- cases[[name]]
    writePublicDomainFixture(
      root,
      coveredComponents = values[[1L]],
      excludedComponents = values[[2L]]
    )

    result <- evaluateRightsGate(root)
    expect_identical(
      result$reason_codes, "RIGHTS_SCOPE_INCOMPLETE", info = name
    )
    expect_false(result$release_ready, info = name)
  }
})

test_that("offline readiness stays distinct from an intentional block", {
  root <- releaseGateProjectRoot()
  offline <- runReleaseGate(c("--root", root, "--offline"))
  expectReleaseGateFailure(
    offline,
    "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED"
  )
  malformed <- tempfile("release-gate-unrelated-error-")
  on.exit(unlink(malformed, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(malformed)
  rightsPath <- file.path(malformed, "docs", "provenance", "RIGHTS.md")
  write("Evidence-Hash: duplicate", rightsPath, append = TRUE)

  asserted <- runRightsGate(malformed)
  expectReleaseGateFailure(asserted, "RIGHTS_FIELD_CARDINALITY")
})

test_that("complete written grant evidence proves synthetic readiness", {
  root <- tempfile("release-gate-cleared-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(
    root,
    rightsStatus = "cleared",
    includeScope = TRUE
  )

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)

  command <- runRightsGate(root)
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "repository_state=eligible"))
  expect_true(any(command$output == "release_ready=true"))
  expect_true(any(command$output == "reason_codes=NONE"))
})

test_that("complete reviewed clean-room evidence proves synthetic readiness", {
  root <- tempfile("release-gate-cleanroom-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(root)

  result <- evaluateRightsGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)
  expect_identical(
    runRightsGate(root)$status,
    0L
  )

  incomplete <- tempfile("release-gate-cleanroom-review-")
  on.exit(unlink(incomplete, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(incomplete, reviewStatus = "pending")
  expectReleaseGateFailure(
    runRightsGate(incomplete),
    "CLEANROOM_REVIEW_INCOMPLETE"
  )
})

test_that("sensitive evidence classes fail without disclosing matches", {
  indicators <- c(
    "credential.txt", "private-correspondence.txt", "fixture.har",
    "giant-result.rds"
  )
  for (indicator in indicators) {
    root <- tempfile("release-gate-sensitive-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    writeReleaseGateFixture(root)
    sentinel <- paste0("do-not-disclose-", basename(indicator))
    writeLines(
      sentinel,
      file.path(root, "docs", "provenance", indicator)
    )

    command <- runRightsGate(root)
    expectReleaseGateFailure(command, "SENSITIVE_EVIDENCE_CLASS")
    expect_false(any(grepl(sentinel, command$output, fixed = TRUE)))
    expect_false(any(grepl(indicator, command$output, fixed = TRUE)))
  }
})

test_that("the built-in isolated self-test proves both result directions", {
  command <- runReleaseGate("--self-test")
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "self_test=pass"))
})


copyIntegratedReleaseEvidence = function(root) {
  sourceRoot = releaseGateProjectRoot()
  paths = c(
    "DESCRIPTION",
    "README.md",
    "inst/CITATION",
    "CONTRIBUTORS.md",
    "NEWS.md",
    "docs/provenance/RIGHTS.md",
    "docs/provenance/UPSTREAM-REQUEST.md",
    "docs/provenance/UPSTREAM-RESPONSE.md",
    "docs/provenance/EXPECTED-KEYS.csv",
    "docs/provenance/PROVENANCE.csv",
    "docs/provenance/ATTRIBUTION.md",
    "docs/release/NAME-CHECK.md",
    "tools/check_name_availability.R",
    "GOVERNANCE.md",
    "docs/release/REPOSITORY.md",
    "docs/release/RELEASE-GATES.md"
  )
  for (relativePath in paths) {
    destination = file.path(root, relativePath)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(sourceRoot, relativePath), destination, overwrite = TRUE)
  }
  writePendingLicenseDecisionFixture(root)
  writeIntegratedSourceEvidence(root)
}

writePendingLicenseDecisionFixture = function(root) {
  path = file.path(root, "docs", "provenance", "LICENSE-DECISION.md")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(
    "# Package license decision",
    "",
    "License-Decision-Version: 1",
    "Decision-Status: pending",
    "Description-License: What license is it under?",
    "Dependency-Audit-Artifact: pending",
    "Dependency-Audit-MD5: pending",
    "Reviewer: pending",
    "Review-Date-UTC: pending"
  ), path, useBytes = TRUE)
  invisible(path)
}

writeReviewedLicenseDecisionFixture = function(
    root, license = "Apache License (>= 2.0)",
    auditRelative = "docs/provenance/DEPENDENCY-AUDIT.md",
    auditHash = NULL, createAudit = TRUE,
    reviewer = "Fixture Reviewer",
    reviewDate = "2026-08-27T00:00:00Z") {
  auditPath = file.path(root, auditRelative)
  if (isTRUE(createAudit)) {
    dir.create(dirname(auditPath), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(
      "# Dependency compatibility audit",
      "",
      "Result: compatible"
    ), auditPath, useBytes = TRUE)
  }
  if (is.null(auditHash)) {
    auditHash = if (file.exists(auditPath)) {
      unname(tools::md5sum(auditPath)[[1L]])
    } else {
      "00000000000000000000000000000000"
    }
  }
  path = file.path(root, "docs", "provenance", "LICENSE-DECISION.md")
  writeLines(c(
    "# Package license decision",
    "",
    "License-Decision-Version: 1",
    "Decision-Status: reviewed",
    paste0("Description-License: ", license),
    paste0("Dependency-Audit-Artifact: ", auditRelative),
    paste0("Dependency-Audit-MD5: ", auditHash),
    paste0("Reviewer: ", reviewer),
    paste0("Review-Date-UTC: ", reviewDate)
  ), path, useBytes = TRUE)
  descriptionPath = file.path(root, "DESCRIPTION")
  description = readLines(
    descriptionPath, warn = FALSE, encoding = "UTF-8"
  )
  description[grepl("^License:", description)] = paste0(
    "License: ", license
  )
  writeLines(description, descriptionPath, useBytes = TRUE)
  invisible(path)
}

removeIntegratedBlocker = function(root, blocker) {
  attributionPath = file.path(
    root, "docs", "provenance", "ATTRIBUTION.md"
  )
  attribution = readLines(
    attributionPath, warn = FALSE, encoding = "UTF-8"
  )
  attribution = attribution[!grepl(blocker, attribution, fixed = TRUE)]
  writeLines(attribution, attributionPath, useBytes = TRUE)

  rightsPath = file.path(root, "docs", "provenance", "RIGHTS.md")
  rights = readLines(rightsPath, warn = FALSE, encoding = "UTF-8")
  rights = rights[!grepl(
    paste0("^Unresolved-Release-Blocker: ", blocker), rights
  )]
  writeLines(rights, rightsPath, useBytes = TRUE)

  releasePath = file.path(root, "docs", "release", "RELEASE-GATES.md")
  release = readLines(releasePath, warn = FALSE, encoding = "UTF-8")
  marker = releaseGateMarker(release, "Intentional-Blockers")
  values = trimws(strsplit(marker, ",", fixed = TRUE)[[1L]])
  values = values[values != blocker]
  release[grepl("^Intentional-Blockers:", release)] = paste0(
    "Intentional-Blockers: ",
    if (length(values)) paste(values, collapse = ",") else "NONE"
  )
  writeLines(release, releasePath, useBytes = TRUE)
  invisible(TRUE)
}

initializeIntegratedFixtureGit = function(root) {
  gitCandidates = unique(c("/usr/bin/git", unname(Sys.which("git"))))
  gitCandidates = gitCandidates[nzchar(gitCandidates) & file.exists(gitCandidates)]
  git = if (length(gitCandidates)) gitCandidates[[1L]] else ""
  if (!nzchar(git)) stop("git is required for release-gate fixtures")
  run = function(arguments) {
    status = suppressWarnings(system2(
      git, c("-C", shQuote(root), arguments),
      stdout = FALSE, stderr = FALSE
    ))
    if (!identical(as.integer(status), 0L)) {
      stop("could not initialize release-gate fixture Git evidence")
    }
  }
  run(c("init", "--quiet"))
  run(c("config", "user.name", "Fixture Author"))
  run(c("config", "user.email", "fixture@example.invalid"))
  run(c("add", "."))
  run(c("commit", "--quiet", "-m", shQuote("fixture evidence")))
}

loadProvenanceFixtureTool = function(path) {
  environment = new.env(parent = baseenv())
  sys.source(path, envir = environment)
  environment
}

writeIntegratedSourceEvidence = function(root) {
  sourceRoot = releaseGateProjectRoot()
  sourceLines = list(
    "R/sparseCompiler.R" = c(
      "sparse_compile_spec = function(value) {",
      "  value",
      "}"
    ),
    "R/sparseSolver.R" = c(
      "sparse_solve_model = function(value) {",
      "  value",
      "}"
    ),
    "R/GEModel.R" = c(
      "GEModel = setRefClass(\"GEModel\", methods = list(",
      "  loadTablo = function(value) value,",
      "  solveModel = function(value) value",
      "))"
    ),
    "R/processTablo.R" = c(
      "processTablo = function(value) {",
      "  value",
      "}"
    ),
    "src/sparse-schur.cpp" = c(
      "int tabloToR_schur_accumulate_global(int value) {",
      "  return value;",
      "}"
    )
  )
  for (relativePath in names(sourceLines)) {
    path = file.path(root, relativePath)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(sourceLines[[relativePath]], path, useBytes = TRUE)
  }
  toolPath = file.path(root, "tools", "provenance_inventory.R")
  dir.create(dirname(toolPath), recursive = TRUE, showWarnings = FALSE)
  file.copy(
    file.path(sourceRoot, "tools", "provenance_inventory.R"),
    toolPath,
    overwrite = TRUE
  )
  initializeIntegratedFixtureGit(root)

  tool = loadProvenanceFixtureTool(toolPath)
  inventory = tool$provenance_collect_sources(root, include_git = TRUE)
  expected = inventory[c("path", "symbol")]
  ledger = tool$provenance_build_ledger(inventory)
  ledger$classification = "new-independent"
  ledger$contributors = "David Zenz"
  ledger$copyright_holder = "David Zenz"
  ledger$license_basis = "fixture-original-code-license"
  ledger$evidence = "synthetic reviewed fixture"
  ledger$reviewer = "Fixture Reviewer"
  ledger$review_date = "2026-08-25"
  ledger$status = "reviewed-provisional"

  inheritedKeys = c(
    "R/GEModel.R::GEModel$loadTablo",
    "R/GEModel.R::GEModel$solveModel",
    "R/processTablo.R::processTablo"
  )
  keys = paste(ledger$path, ledger$symbol, sep = "::")
  inherited = keys %in% inheritedKeys
  ledger$classification[inherited] = "inherited-identical"
  ledger$upstream_repository[inherited] =
    "https://github.com/mivanic/tabloToR"
  ledger$upstream_commit[inherited] =
    "7e063c65a19713857ed13023f8b77dad45b15c90"
  ledger$upstream_path[inherited] = ledger$path[inherited]
  ledger$copyright_holder[inherited] = "Maros Ivanic"
  ledger$contributors[inherited] = "Maros Ivanic"
  ledger$license_basis[inherited] = "public-domain-cc0"
  ledger$status[inherited] = "reviewed-cleared"

  expectedPath = file.path(
    root, "docs", "provenance", "EXPECTED-KEYS.csv"
  )
  ledgerPath = file.path(root, "docs", "provenance", "PROVENANCE.csv")
  write.csv(expected, expectedPath, row.names = FALSE, na = "")
  write.csv(ledger, ledgerPath, row.names = FALSE, na = "")

  attributionPath = file.path(
    root, "docs", "provenance", "ATTRIBUTION.md"
  )
  attribution = readLines(
    attributionPath, warn = FALSE, encoding = "UTF-8"
  )
  attribution[grepl("^Inventory-Row-Count:", attribution)] = paste0(
    "Inventory-Row-Count: ", nrow(ledger)
  )
  attribution[grepl("^Inventory-Snapshot-MD5:", attribution)] = paste0(
    "Inventory-Snapshot-MD5: ",
    unname(tools::md5sum(ledgerPath)[[1L]])
  )
  writeLines(attribution, attributionPath, useBytes = TRUE)
  invisible(list(inventory = inventory, expected = expected, ledger = ledger))
}

rewriteIntegratedLedger = function(root, ledger) {
  path = file.path(root, "docs", "provenance", "PROVENANCE.csv")
  write.csv(ledger, path, row.names = FALSE, na = "")
  attributionPath = file.path(
    root, "docs", "provenance", "ATTRIBUTION.md"
  )
  attribution = readLines(
    attributionPath, warn = FALSE, encoding = "UTF-8"
  )
  attribution[grepl("^Inventory-Row-Count:", attribution)] = paste0(
    "Inventory-Row-Count: ", nrow(ledger)
  )
  attribution[grepl("^Inventory-Snapshot-MD5:", attribution)] = paste0(
    "Inventory-Snapshot-MD5: ", unname(tools::md5sum(path)[[1L]])
  )
  writeLines(attribution, attributionPath, useBytes = TRUE)
}

test_that("integrated evidence version is mandatory and exact", {
  cases = list(
    missing = character(),
    duplicated = c(
      "Integrated-Evidence-Version: 1",
      "Integrated-Evidence-Version: 1"
    ),
    empty = "Integrated-Evidence-Version: ",
    unsupported = "Integrated-Evidence-Version: 2"
  )
  for (name in names(cases)) {
    root = tempfile("release-gate-integrated-version-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    copyIntegratedReleaseEvidence(root)
    path = file.path(root, "docs", "provenance", "RIGHTS.md")
    lines = readLines(path, warn = FALSE, encoding = "UTF-8")
    lines = lines[!grepl("^Integrated-Evidence-Version:", lines)]
    writeLines(c(lines, cases[[name]]), path, useBytes = TRUE)

    result = evaluateReleaseGate(root)
    expect_identical(
      result$reason_codes,
      "INTEGRATED_EVIDENCE_VERSION_INVALID",
      info = name
    )
    expect_false(result$release_ready, info = name)
    expect_identical(result$parse_status[["integrated"]], "fail", info = name)
  }
})

test_that("integrated provenance is bound to current source and Git evidence", {
  cases = list(
    source_missing = list(
      reason = "PROVENANCE_SOURCE_MISSING",
      mutate = function(root) unlink(file.path(root, c("R", "src")),
                                    recursive = TRUE)
    ),
    tool_missing = list(
      reason = "PROVENANCE_TOOL_MISSING",
      mutate = function(root) unlink(file.path(
        root, "tools", "provenance_inventory.R"
      ))
    ),
    tool_invalid = list(
      reason = "PROVENANCE_TOOL_LOAD_FAILED",
      mutate = function(root) writeLines("broken =", file.path(
        root, "tools", "provenance_inventory.R"
      ))
    ),
    git_missing = list(
      reason = "PROVENANCE_GIT_EVIDENCE_MISSING",
      mutate = function(root) unlink(file.path(root, ".git"), recursive = TRUE)
    ),
    source_added = list(
      reason = "PROVENANCE_KEY_MISMATCH",
      mutate = function(root) writeLines(
        "addedDefinition = function() TRUE",
        file.path(root, "R", "addedDefinition.R")
      )
    ),
    source_deleted = list(
      reason = "PROVENANCE_KEY_MISMATCH",
      mutate = function(root) unlink(file.path(root, "R", "processTablo.R"))
    ),
    source_rekeyed = list(
      reason = "PROVENANCE_KEY_MISMATCH",
      mutate = function(root) writeLines(
        "renamedProcessTablo = function(value) value",
        file.path(root, "R", "processTablo.R")
      )
    ),
    source_hash_changed = list(
      reason = "PROVENANCE_KEY_MISMATCH",
      mutate = function(root) writeLines(c(
        "processTablo = function(value) {",
        "  value + 1",
        "}"
      ), file.path(root, "R", "processTablo.R"))
    ),
    source_invalid = list(
      reason = "PROVENANCE_SOURCE_EXTRACTION_FAILED",
      mutate = function(root) writeLines(
        "processTablo = function(",
        file.path(root, "R", "processTablo.R")
      )
    )
  )
  for (name in names(cases)) {
    root = tempfile("release-gate-integrated-source-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    copyIntegratedReleaseEvidence(root)
    cases[[name]]$mutate(root)

    result = evaluateReleaseGate(root)
    expect_identical(result$reason_codes, cases[[name]]$reason, info = name)
    expect_false(result$release_ready, info = name)
    expect_identical(result$parse_status[["provenance"]], "fail", info = name)
  }
})

test_that("shared provenance validation accepts only complete third-party evidence", {
  root = tempfile("release-gate-integrated-third-party-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)
  path = file.path(root, "docs", "provenance", "PROVENANCE.csv")
  ledger = read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    colClasses = "character", na.strings = NULL
  )
  ledger$classification[[1L]] = "third-party"
  ledger$upstream_repository[[1L]] = "https://example.invalid/vendor"
  ledger$upstream_commit[[1L]] = "vendor-1"
  ledger$upstream_path[[1L]] = ledger$path[[1L]]
  ledger$copyright_holder[[1L]] = "Fixture Vendor"
  ledger$license_basis[[1L]] = "fixture-vendor-license"
  ledger$status[[1L]] = "reviewed-third-party"
  rewriteIntegratedLedger(root, ledger)

  validator = releaseGateEnvironment$release_gate_validate_current_source
  complete = validator(root, c(integrated = "pass"))
  expect_null(complete$error)
  expect_identical(complete$parse_status[["provenance"]], "pass")

  ledger$license_basis[[1L]] = ""
  rewriteIntegratedLedger(root, ledger)
  incomplete = validator(root, c(integrated = "pass"))
  expect_identical(
    incomplete$error$reason_codes,
    "PROVENANCE_ROW_BLOCKING"
  )
  expect_identical(incomplete$error$parse_status[["provenance"]], "fail")
})

test_that("integrated provenance coverage fails closed on a missing key", {
  root = tempfile("release-gate-integrated-provenance-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)

  provenancePath = file.path(root, "docs", "provenance", "PROVENANCE.csv")
  provenance = read.csv(
    provenancePath,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  write.csv(provenance[-1L, ], provenancePath, row.names = FALSE, na = "")

  result = evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(result$reason_codes, "PROVENANCE_KEY_MISMATCH")
})

test_that("integrated release evidence can prove a synthetic ready state", {
  root = tempfile("release-gate-integrated-ready-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)

  namePath = file.path(root, "docs", "release", "NAME-CHECK.md")
  nameLines = readLines(namePath, warn = FALSE, encoding = "UTF-8")
  nameLines[grepl("^Check-Kind:", nameLines)] = "Check-Kind: release"
  nameLines[grepl("^Checked-At-UTC:", nameLines)] = paste0(
    "Checked-At-UTC: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  writeLines(nameLines, namePath, useBytes = TRUE)

  writeReviewedLicenseDecisionFixture(root)
  attributionPath = file.path(root, "docs", "provenance", "ATTRIBUTION.md")
  attribution = readLines(attributionPath, warn = FALSE, encoding = "UTF-8")
  attribution = attribution[!grepl(
    "PACKAGE_LICENSE_UNFINALIZED|GIT_IDENTITY_ALIAS_UNRESOLVED",
    attribution
  )]
  writeLines(attribution, attributionPath, useBytes = TRUE)

  releasePath = file.path(root, "docs", "release", "RELEASE-GATES.md")
  release = readLines(releasePath, warn = FALSE, encoding = "UTF-8")
  release[grepl("^Intentional-Blockers:", release)] =
    "Intentional-Blockers: NONE"
  writeLines(release, releasePath, useBytes = TRUE)

  rightsPath = file.path(root, "docs", "provenance", "RIGHTS.md")
  rights = readLines(rightsPath, warn = FALSE, encoding = "UTF-8")
  rights = rights[!grepl("^Unresolved-Release-Blocker:", rights)]
  writeLines(rights, rightsPath, useBytes = TRUE)

  result = evaluateReleaseGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)
  expect_identical(unname(result$parse_status), rep("pass", 12L))
})



test_that("integrated name evidence fails on a missing source", {
  root = tempfile("release-gate-integrated-name-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)
  path = file.path(root, "docs", "release", "NAME-CHECK.md")
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  lines = lines[!grepl("^Source-Row: github\\|", lines)]
  writeLines(lines, path, useBytes = TRUE)

  result = evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_identical(result$reason_codes, "NAME_REPORT_INVALID")
})

test_that("integrated governance evidence requires the security route", {
  root = tempfile("release-gate-integrated-governance-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)
  path = file.path(root, "GOVERNANCE.md")
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  lines[grepl("^Security-Route:", lines)] = "Security-Route: missing"
  writeLines(lines, path, useBytes = TRUE)

  result = evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_identical(
    result$reason_codes, "GOVERNANCE_SECURITY_ROUTE_MISSING"
  )
})

test_that("integrated repository evidence rejects URL drift", {
  root = tempfile("release-gate-integrated-repository-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)
  path = file.path(root, "docs", "release", "REPOSITORY.md")
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  lines[grepl("^Canonical-URL:", lines)] =
    "Canonical-URL: https://github.com/DavidZenz/wrong"
  writeLines(lines, path, useBytes = TRUE)

  result = evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_identical(result$reason_codes, "REPOSITORY_URL_MISMATCH")
})

test_that("integrated package metadata rejects canonical URL drift", {
  root = tempfile("release-gate-integrated-description-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)
  path = file.path(root, "DESCRIPTION")
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  lines[grepl("^URL:", lines)] =
    "URL: https://github.com/DavidZenz/wrong"
  writeLines(lines, path, useBytes = TRUE)

  result = evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_identical(result$reason_codes, "DESCRIPTION_URL_MISMATCH")
})


test_that("all six attribution destinations are mandatory", {
  destinations = c(
    "DESCRIPTION", "README.md", "inst/CITATION", "CONTRIBUTORS.md",
    "docs/provenance/PROVENANCE.csv", "NEWS.md"
  )
  for (destination in destinations) {
    root = tempfile("release-gate-attribution-missing-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    copyIntegratedReleaseEvidence(root)
    unlink(file.path(root, destination))

    result = evaluateReleaseGate(root)
    expect_identical(
      result$reason_codes, "ATTRIBUTION_DESTINATION_MISSING",
      info = destination
    )
    expect_false(result$release_ready, info = destination)
  }
})

test_that("all six attribution destinations retain exact reviewed evidence", {
  mutations = list(
    DESCRIPTION = function(root) {
      path = file.path(root, "DESCRIPTION")
      lines = readLines(path, warn = FALSE, encoding = "UTF-8")
      lines = sub(
        "R/GEModel.R::GEModel\\$loadTablo",
        "R/missing.R::missing", lines
      )
      writeLines(lines, path, useBytes = TRUE)
    },
    README = function(root) {
      path = file.path(root, "README.md")
      lines = readLines(path, warn = FALSE, encoding = "UTF-8")
      lines = lines[!grepl(
        "R/GEModel.R::GEModel\\$loadTablo", lines
      )]
      writeLines(lines, path, useBytes = TRUE)
    },
    CITATION = function(root) {
      path = file.path(root, "inst", "CITATION")
      lines = readLines(path, warn = FALSE, encoding = "UTF-8")
      lines = lines[!grepl(
        "R/GEModel.R::GEModel\\$loadTablo", lines
      )]
      writeLines(lines, path, useBytes = TRUE)
    },
    CONTRIBUTORS = function(root) {
      path = file.path(root, "CONTRIBUTORS.md")
      lines = readLines(path, warn = FALSE, encoding = "UTF-8")
      lines = lines[!grepl(
        "^Evidence-Key: R/GEModel.R::GEModel\\$loadTablo", lines
      )]
      writeLines(lines, path, useBytes = TRUE)
    },
    PROVENANCE = function(root) {
      path = file.path(root, "docs", "provenance", "PROVENANCE.csv")
      ledger = read.csv(
        path, stringsAsFactors = FALSE, check.names = FALSE,
        colClasses = "character", na.strings = NULL
      )
      key = paste(ledger$path, ledger$symbol, sep = "::")
      ledger$contributors[key == "R/GEModel.R::GEModel$loadTablo"] =
        "Unreviewed Person"
      ledger$copyright_holder[
        key == "R/GEModel.R::GEModel$loadTablo"] = "Unreviewed Person"
      rewriteIntegratedLedger(root, ledger)
    },
    NEWS = function(root) {
      path = file.path(root, "NEWS.md")
      lines = readLines(path, warn = FALSE, encoding = "UTF-8")
      lines = lines[!grepl(
        "^Evidence-Key: R/GEModel.R::GEModel\\$loadTablo", lines
      )]
      writeLines(lines, path, useBytes = TRUE)
    }
  )
  for (destination in names(mutations)) {
    root = tempfile("release-gate-attribution-drift-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    copyIntegratedReleaseEvidence(root)
    mutations[[destination]](root)

    result = evaluateReleaseGate(root)
    expect_identical(
      result$reason_codes, "ATTRIBUTION_DESTINATION_MISMATCH",
      info = destination
    )
    expect_false(result$release_ready, info = destination)
  }
})

test_that("unreviewed attribution roles and blocker keys fail closed", {
  roleRoot = tempfile("release-gate-attribution-role-")
  on.exit(unlink(roleRoot, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(roleRoot)
  path = file.path(roleRoot, "docs", "provenance", "ATTRIBUTION.md")
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  lines = sub("| aut |", "| fnd |", lines, fixed = TRUE)
  writeLines(lines, path, useBytes = TRUE)
  roleResult = evaluateReleaseGate(roleRoot)
  expect_identical(
    roleResult$reason_codes, "ATTRIBUTION_ROLE_UNREVIEWED"
  )

  blockerRoot = tempfile("release-gate-attribution-blocker-")
  on.exit(unlink(blockerRoot, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(blockerRoot)
  path = file.path(
    blockerRoot, "docs", "provenance", "ATTRIBUTION.md"
  )
  lines = readLines(path, warn = FALSE, encoding = "UTF-8")
  blockerRow = grepl("^\\| PACKAGE_LICENSE_UNFINALIZED", lines)
  lines[blockerRow] = sub(
    "R/sparseSolver.R::sparse_solve_model",
    "R/missing.R::missing", lines[blockerRow], fixed = TRUE
  )
  writeLines(lines, path, useBytes = TRUE)
  blockerResult = evaluateReleaseGate(blockerRoot)
  expect_identical(
    blockerResult$reason_codes, "ATTRIBUTION_EVIDENCE_MISSING"
  )
})

test_that("strict name report metadata is enforced on blocked roots", {
  mutations = list(
    timestamp = function(lines) sub(
      "^Checked-At-UTC:.*$", "Checked-At-UTC: invalid", lines
    ),
    raw_md5 = function(lines) sub(
      "raw-md5=[0-9a-f]{32}", "raw-md5=invalid", lines
    ),
    version = function(lines) sub(
      "^Name-Evidence-Version:.*$", "Name-Evidence-Version: 2", lines
    ),
    source_detail = function(lines) {
      hit = which(grepl("^Source-Detail:", lines))[[1L]]
      lines[-hit]
    },
    query_identity = function(lines) sub(
      "query=https://", "query=http://", lines
    ),
    signature = function(lines) sub(
      "^Reviewer:.*$", "Reviewer: awaiting-human-approval", lines
    ),
    completeness = function(lines) sub(
      "completeness=complete", "completeness=unknown", lines
    )
  )
  for (name in names(mutations)) {
    root = tempfile("release-gate-name-strict-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    copyIntegratedReleaseEvidence(root)
    path = file.path(root, "docs", "release", "NAME-CHECK.md")
    lines = readLines(path, warn = FALSE, encoding = "UTF-8")
    writeLines(mutations[[name]](lines), path, useBytes = TRUE)

    result = evaluateReleaseGate(root)
    expect_identical(result$reason_codes, "NAME_REPORT_INVALID", info = name)
    expect_false(result$release_ready, info = name)
  }
})

test_that("pending license evidence requires the dependency blocker", {
  root = tempfile("release-gate-license-pending-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(root)
  removeIntegratedBlocker(root, "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING")

  result = evaluateReleaseGate(root)
  expect_identical(result$reason_codes, "LICENSE_DECISION_PENDING")
  expect_false(result$release_ready)
})

test_that("reviewed license evidence is exact, hash-bound, and R-valid", {
  validRoot = tempfile("release-gate-license-reviewed-")
  on.exit(unlink(validRoot, recursive = TRUE), add = TRUE)
  copyIntegratedReleaseEvidence(validRoot)
  removeIntegratedBlocker(
    validRoot, "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING"
  )
  writeReviewedLicenseDecisionFixture(validRoot)
  valid = evaluateReleaseGate(validRoot)
  expect_identical(valid$repository_state, "blocked")
  expect_identical(valid$reason_codes, "ATTRIBUTION_IDENTITY_UNRESOLVED")
  expect_identical(valid$parse_status[["license"]], "pass")

  cases = list(
    missing_decision = list(
      reason = "LICENSE_DECISION_MISSING",
      mutate = function(root) unlink(file.path(
        root, "docs", "provenance", "LICENSE-DECISION.md"
      ))
    ),
    missing_audit = list(
      reason = "LICENSE_DEPENDENCY_AUDIT_MISSING",
      mutate = function(root) unlink(file.path(
        root, "docs", "provenance", "DEPENDENCY-AUDIT.md"
      ))
    ),
    hash_mismatch = list(
      reason = "LICENSE_DEPENDENCY_AUDIT_HASH_MISMATCH",
      mutate = function(root) {
        path = file.path(
          root, "docs", "provenance", "LICENSE-DECISION.md"
        )
        lines = readLines(path, warn = FALSE, encoding = "UTF-8")
        lines[grepl("^Dependency-Audit-MD5:", lines)] =
          "Dependency-Audit-MD5: 00000000000000000000000000000000"
        writeLines(lines, path, useBytes = TRUE)
      }
    ),
    description_mismatch = list(
      reason = "DESCRIPTION_LICENSE_MISMATCH",
      mutate = function(root) {
        path = file.path(root, "DESCRIPTION")
        lines = readLines(path, warn = FALSE, encoding = "UTF-8")
        lines[grepl("^License:", lines)] = "License: GPL-3"
        writeLines(lines, path, useBytes = TRUE)
      }
    ),
    invalid_expression = list(
      reason = "LICENSE_EXPRESSION_INVALID",
      mutate = function(root) writeReviewedLicenseDecisionFixture(
        root, license = "definitely-not-a-valid-license"
      )
    ),
    unreviewed = list(
      reason = "LICENSE_DECISION_UNREVIEWED",
      mutate = function(root) writeReviewedLicenseDecisionFixture(
        root, reviewer = "pending", reviewDate = "pending"
      )
    )
  )
  for (name in names(cases)) {
    root = tempfile("release-gate-license-invalid-")
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    copyIntegratedReleaseEvidence(root)
    removeIntegratedBlocker(
      root, "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING"
    )
    writeReviewedLicenseDecisionFixture(root)
    cases[[name]]$mutate(root)

    result = evaluateReleaseGate(root)
    expect_identical(result$reason_codes, cases[[name]]$reason, info = name)
    expect_false(result$release_ready, info = name)
    expect_identical(result$parse_status[["license"]], "fail", info = name)
  }
})
