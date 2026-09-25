identityResealToolPath = function() {
  candidates = c(
    file.path("tools", "seal_phase03_identity.R"),
    testthat::test_path("..", "..", "tools", "seal_phase03_identity.R")
  )
  hits = candidates[file.exists(candidates)]
  if (!length(hits)) {
    stop("identity reseal tooling is unavailable", call. = FALSE)
  }
  normalizePath(hits[[1L]], mustWork = TRUE)
}

identityResealSourceTreeAvailable = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  required = c(
    "DESCRIPTION",
    "tools/seal_phase03_identity.R",
    "tools/check_identity_migration.R",
    "inst/migration/predecessor-fingerprints.dcf",
    "inst/migration/workflow-evidence-policy.csv",
    "inst/migration/workflow-evidence-policy-review.dcf",
    "inst/migration/identity-reseal-review.dcf",
    ".planning/STATE.md",
    ".planning/ROADMAP.md",
    ".planning/phases/03-gemodelr-identity-migration/03-VALIDATION.md",
    ".planning/phases/03-gemodelr-identity-migration/03-REVIEW.md"
  )
  all(file.exists(file.path(root, required)))
}

skipUnlessIdentityResealSourceTree = function() {
  testthat::skip_if_not(
    identityResealSourceTreeAvailable(),
    "identity reseal tests require the package source tree"
  )
}

loadIdentityResealTool = function() {
  environment = new.env(parent = globalenv())
  sys.source(identityResealToolPath(), envir = environment)
  environment
}

resealHashFile = function(path) {
  tool = loadIdentityResealTool()
  tool$seal_hash_file(path)
}

resealWriteDcf = function(value, path) {
  write.dcf(
    as.data.frame(value, stringsAsFactors = FALSE, check.names = FALSE),
    path, keep.white = names(value), useBytes = TRUE
  )
  invisible(path)
}

test_that("approved workflow policy is pinned and active", {
  skipUnlessIdentityResealSourceTree()
  tool = loadIdentityResealTool()
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)

  expect_identical(
    tool$seal_approved_workflow_policy_sha256,
    "882f3f92a8afe84fdd50b4565ed189af5242afd8cfc2bfd72a22db4553f2ce1e"
  )
  result = tool$seal_validate_approved_workflow_policy(root)
  expect_true(result$clean)
  expect_identical(result$policy$PolicySHA256,
                   tool$seal_approved_workflow_policy_sha256)
  expect_identical(result$policy$ReviewState, "approved")
  expect_length(result$policy_paths, 12L)
})

test_that("workflow-owned rows are excluded only after exact policy validation", {
  skipUnlessIdentityResealSourceTree()
  tool = loadIdentityResealTool()
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  expect_silent(tool$seal_validate_approved_workflow_policy(root))

  candidate = tool$identity_build_occurrence_allowlist(root)
  policy_paths = tool$seal_workflow_policy_paths(root)
  expect_false(any(candidate$path %in% policy_paths))
  expect_true(any(candidate$path ==
                  ".planning/phases/03-gemodelr-identity-migration/03-12-SUMMARY.md"))

  policy = utils::read.csv(
    file.path(root, "inst", "migration", "workflow-evidence-policy.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  policy$path[[1L]] = "R/GEModel.R"
  path = tempfile("reseal-policy-")
  on.exit(unlink(path, force = TRUE), add = TRUE)
  utils::write.csv(policy, path, row.names = FALSE, quote = TRUE,
                   na = "", fileEncoding = "UTF-8")
  expect_error(
    tool$seal_validate_approved_workflow_policy(
      root, policy_path = path,
      review_path = file.path(root, "inst", "migration",
                              "workflow-evidence-policy-review.dcf")
    ),
    "PATH|SCOPE|ELIGIBLE"
  )
})

test_that("qualification transcript validation is exact and fail-closed", {
  skipUnlessIdentityResealSourceTree()
  tool = loadIdentityResealTool()
  transcript = tempfile("qualification-transcript-", fileext = ".log")
  on.exit(unlink(transcript, force = TRUE), add = TRUE)
  stages = tool$seal_example_qualification_manifest()
  manifest = tool$seal_manifest_frame_for_test(stages)
  manifest_path = tempfile("qualification-manifest-", fileext = ".dcf")
  on.exit(unlink(manifest_path, force = TRUE), add = TRUE)
  write.dcf(manifest, manifest_path, keep.white = names(manifest), useBytes = TRUE)
  manifest_digest = tool$seal_hash_file(manifest_path)
  manifest_text = readLines(manifest_path, warn = FALSE, encoding = "UTF-8")
  writeLines(c(
    "prefix diagnostics",
    "QUALIFICATION_MANIFEST_BEGIN",
    manifest_text,
    "QUALIFICATION_MANIFEST_END",
    paste0("Qualification-Manifest-SHA256: ", manifest_digest),
    paste0("Qualification-HEAD: ", stages$HEAD[[1L]])
  ), transcript, useBytes = TRUE)

  result = tool$seal_verify_qualification_transcript(transcript)
  expect_true(result$clean)
  expect_identical(result$head, stages$HEAD[[1L]])
  expect_identical(result$manifest_digest, manifest_digest)

  tampered = readLines(transcript, warn = FALSE, encoding = "UTF-8")
  tampered[grep("Status:", tampered)[[1L]]] =
    sub("Status: 0", "Status: 7", tampered[grep("Status:", tampered)[[1L]]],
        fixed = TRUE)
  writeLines(tampered, transcript, useBytes = TRUE)
  expect_error(
    tool$seal_verify_qualification_transcript(transcript),
    "STATUS|DIGEST|MANIFEST"
  )
})

test_that("final-tree check is read-only across an actual tracked Git lifecycle", {
  skipUnlessIdentityResealSourceTree()
  tool = loadIdentityResealTool()
  source_root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  root = tempfile("identity-reseal-tree-")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  git = if (file.exists("/usr/bin/git")) "/usr/bin/git" else Sys.which("git")
  expect_true(nzchar(git))
  expect_equal(system2(git, c("clone", "--no-local", source_root, root)), 0L)
  expect_true(file.copy(
    file.path(source_root, "tools", "check_identity_migration.R"),
    file.path(root, "tools", "check_identity_migration.R"), overwrite = TRUE
  ))
  expect_true(file.copy(
    file.path(source_root, "tools", "seal_phase03_identity.R"),
    file.path(root, "tools", "seal_phase03_identity.R"), overwrite = TRUE
  ))
  system2(git, c("-C", root, "config", "user.email", "reseal@example.invalid"))
  system2(git, c("-C", root, "config", "user.name", "Identity Reseal"))

  candidate = tool$identity_build_occurrence_allowlist(root)
  allowlist_path = file.path(root, "inst", "migration",
                             "old-identity-allowlist.csv")
  utils::write.csv(candidate, allowlist_path, row.names = FALSE, quote = TRUE,
                   na = "", fileEncoding = "UTF-8")
  candidate_digest = tool$seal_hash_file(allowlist_path)
  before_digest = resealHashFile(allowlist_path)
  policy_digest = tool$seal_approved_workflow_policy_sha256
  review = data.frame(
    Schema = "gemodelr-identity-reseal-review-v1",
    `Before-Allowlist-SHA256` = before_digest,
    `Approved-Allowlist-SHA256` = candidate_digest,
    `Policy-SHA256` = policy_digest,
    Scope = "Exact reviewed non-workflow occurrence rows only",
    Reviewer = "Identity Reseal Test",
    `Reviewed-UTC` = "2026-09-18T00:00:00Z",
    `Review-State` = "approved",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  review_path = file.path(root, "inst", "migration",
                          "identity-reseal-review.dcf")
  resealWriteDcf(review, review_path)

  expect_equal(system2(git, c("-C", root, "add", "-A")), 0L)
  expect_equal(system2(git, c("-C", root, "commit", "-q", "-m",
                                 "fixture")), 0L)
  before_head = tool$seal_git_head(root)
  before_status = tool$seal_git_status(root)
  before_tree = tool$seal_tracked_tree_digest(root)

  result = tool$seal_check_final_tree(root)
  expect_true(result$clean)
  expect_identical(result$head, before_head)
  expect_identical(result$tracked_tree_sha256, before_tree)
  expect_identical(tool$seal_git_head(root), before_head)
  expect_identical(tool$seal_git_status(root), before_status)
  expect_identical(tool$seal_tracked_tree_digest(root), before_tree)

  state = file.path(root, ".planning", "STATE.md")
  if (file.exists(state)) {
    writeLines(c("Approved evidence-only write", readLines(state,
               warn = FALSE, encoding = "UTF-8")), state, useBytes = TRUE)
    system2(git, c("-C", root, "add", state))
    system2(git, c("-C", root, "commit", "-q", "-m", "evidence"))
    expect_true(tool$seal_check_final_tree(root)$clean)
  }
})

test_that("source and novel workflow changes fail without mutating the tree", {
  skipUnlessIdentityResealSourceTree()
  tool = loadIdentityResealTool()
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  before_head = tool$seal_git_head(root)
  before_status = tool$seal_git_status(root)
  before_tree = tool$seal_tracked_tree_digest(root)

  expect_error(
    tool$seal_verify_source_candidate(root, "R/GEModel.R",
                                      "unapproved tabloToR literal"),
    "UNEXPECTED|SOURCE|POLICY"
  )
  expect_identical(tool$seal_git_head(root), before_head)
  expect_identical(tool$seal_git_status(root), before_status)
  expect_identical(tool$seal_tracked_tree_digest(root), before_tree)
})
