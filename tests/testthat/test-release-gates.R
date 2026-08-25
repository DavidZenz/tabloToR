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

evaluateReleaseGate <- function(root) {
  if (!exists("release_gate_evaluate", envir = releaseGateEnvironment,
              inherits = FALSE)) {
    stop("release gate checker is not implemented", call. = FALSE)
  }
  releaseGateEnvironment$release_gate_evaluate(root)
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
    "Name-Availability-Status: pending-plan-01-04"
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
    rep("pass", 8L)
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

    result <- evaluateReleaseGate(root)
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

  result <- evaluateReleaseGate(root)
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

    result <- evaluateReleaseGate(root)
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

    result <- evaluateReleaseGate(root)
    expect_identical(result$repository_state, "invalid")
    expect_false(result$release_ready)
    expect_identical(result$reason_codes, "RIGHTS_STATUS_CARDINALITY")
    expectReleaseGateFailure(
      runReleaseGate(c("--root", root, "--offline")),
      "RIGHTS_STATUS_CARDINALITY"
    )
  }
})

test_that("rights and release policy status must agree", {
  root <- tempfile("release-gate-mismatch-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(root, releaseStatus = "cleared")

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(
    result$reason_codes,
    "RIGHTS_RELEASE_STATUS_MISMATCH"
  )
  expectReleaseGateFailure(
    runReleaseGate(c("--root", root, "--offline")),
    "RIGHTS_RELEASE_STATUS_MISMATCH"
  )
})

test_that("written clearance must cover the inherited commit and components", {
  root <- tempfile("release-gate-scope-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(root, rightsStatus = "cleared")

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "invalid")
  expect_false(result$release_ready)
  expect_identical(result$reason_codes, "RIGHTS_SCOPE_INCOMPLETE")
  expectReleaseGateFailure(
    runReleaseGate(c("--root", root, "--offline")),
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

  result <- evaluateReleaseGate(root)
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

    result <- evaluateReleaseGate(root)
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
    evaluateReleaseGate(duplicateRole)$reason_codes,
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

  result <- evaluateReleaseGate(root)
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

  result <- evaluateReleaseGate(root)
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

  command <- runReleaseGate(c("--root", root, "--offline"))
  expectReleaseGateFailure(command, "SENSITIVE_EVIDENCE_CLASS")
  expect_false(any(grepl(sentinel, command$output, fixed = TRUE)))
  expect_false(any(grepl("fixture.har", command$output, fixed = TRUE)))
})

test_that("complete public-domain evidence proves synthetic readiness", {
  root <- tempfile("release-gate-public-domain-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writePublicDomainFixture(root)

  result <- evaluateReleaseGate(root)
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

  result <- evaluateReleaseGate(root)
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

  result <- evaluateReleaseGate(root)
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

    result <- evaluateReleaseGate(root)
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
    "PROVENANCE_COVERAGE_INCOMPLETE"
  )
  malformed <- tempfile("release-gate-unrelated-error-")
  on.exit(unlink(malformed, recursive = TRUE), add = TRUE)
  writeReleaseGateFixture(malformed)
  rightsPath <- file.path(malformed, "docs", "provenance", "RIGHTS.md")
  write("Evidence-Hash: duplicate", rightsPath, append = TRUE)

  asserted <- runReleaseGate(c("--root", malformed, "--assert-blocked"))
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

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)

  command <- runReleaseGate(c("--root", root, "--offline"))
  expect_identical(command$status, 0L)
  expect_true(any(command$output == "repository_state=eligible"))
  expect_true(any(command$output == "release_ready=true"))
  expect_true(any(command$output == "reason_codes=NONE"))
})

test_that("complete reviewed clean-room evidence proves synthetic readiness", {
  root <- tempfile("release-gate-cleanroom-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(root)

  result <- evaluateReleaseGate(root)
  expect_identical(result$repository_state, "eligible")
  expect_true(result$release_ready)
  expect_length(result$reason_codes, 0L)
  expect_identical(
    runReleaseGate(c("--root", root, "--offline"))$status,
    0L
  )

  incomplete <- tempfile("release-gate-cleanroom-review-")
  on.exit(unlink(incomplete, recursive = TRUE), add = TRUE)
  writeCleanroomFixture(incomplete, reviewStatus = "pending")
  expectReleaseGateFailure(
    runReleaseGate(c("--root", incomplete, "--offline")),
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

    command <- runReleaseGate(c("--root", root, "--offline"))
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
    "docs/provenance/RIGHTS.md",
    "docs/provenance/UPSTREAM-REQUEST.md",
    "docs/provenance/UPSTREAM-RESPONSE.md",
    "docs/provenance/EXPECTED-KEYS.txt",
    "docs/provenance/PROVENANCE.csv",
    "docs/provenance/ATTRIBUTION.md",
    "docs/release/NAME-CHECK.md",
    "docs/release/GOVERNANCE.md",
    "docs/release/REPOSITORY.md",
    "docs/release/RELEASE-GATES.md"
  )
  for (relativePath in paths) {
    destination = file.path(root, relativePath)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(sourceRoot, relativePath), destination, overwrite = TRUE)
  }
}

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
  expect_identical(unname(result$parse_status), rep("pass", 8L))
})

