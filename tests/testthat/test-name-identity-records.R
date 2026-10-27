# Development identity authority is checked separately from portable registry parsing.
test_that("checked-in identity records match exact human-approved values", {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  testthat::skip_if_not(file.exists(file.path(root, "docs/release/REPOSITORY.md")),
    "private identity records require the development source checkout")
  tool = new.env(parent = globalenv())
  sys.source(file.path(root, "tools/check_name_availability.R"), tool)
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
    "Name-Evidence-Version: 2",
    "Reviewer: Codex automated technical review (maintainer-requested)",
    "Authorized-Repository: DavidZenz/GEModelR",
    "Reserved-Repository-Count: 1",
    "Overall-Result: NAME_AVAILABLE_WITH_AUTHORIZED_RESERVATION"
  ) %in% report))
  expect_true(tool$name_check_verify_report(
    file.path(root, "docs", "release", "NAME-CHECK.md"),
    require_review = FALSE, authorized_repository = "DavidZenz/GEModelR"
  ))
  expect_true(tool$name_check_verify_report(
    file.path(root, "docs", "release", "NAME-CHECK.md"),
    require_review = TRUE, authorized_repository = "DavidZenz/GEModelR"
  ))
})

