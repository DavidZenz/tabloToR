workflowIdentityPolicyToolPath = function() {
  candidates = c(
    file.path("tools", "check_workflow_identity_policy.R"),
    testthat::test_path(
      "..", "..", "tools", "check_workflow_identity_policy.R"
    )
  )
  hits = candidates[file.exists(candidates)]
  if (!length(hits)) {
    stop("workflow identity policy tooling is unavailable", call. = FALSE)
  }
  normalizePath(hits[[1L]], mustWork = TRUE)
}

workflowIdentitySourceTreeAvailable = function() {
  root = normalizePath(testthat::test_path("..", ".."), mustWork = TRUE)
  required = c(
    "DESCRIPTION",
    "tools/check_workflow_identity_policy.R",
    "tools/check_identity_migration.R",
    "inst/migration/predecessor-fingerprints.dcf",
    "inst/migration/workflow-evidence-policy.csv",
    "inst/migration/workflow-evidence-policy-review.dcf",
    ".planning/STATE.md",
    ".planning/ROADMAP.md",
    ".planning/phases/03-gemodelr-identity-migration/03-VALIDATION.md",
    ".planning/phases/03-gemodelr-identity-migration/03-REVIEW.md"
  )
  all(file.exists(file.path(root, required)))
}

skipUnlessWorkflowIdentitySourceTree = function() {
  testthat::skip_if_not(
    workflowIdentitySourceTreeAvailable(),
    "workflow identity policy tests require the package source tree"
  )
}

loadWorkflowIdentityPolicyTool = function() {
  environment = new.env(parent = globalenv())
  sys.source(workflowIdentityPolicyToolPath(), envir = environment)
  environment
}

workflowPolicyWrite = function(value, path) {
  write.csv(
    value, path, row.names = FALSE, quote = TRUE, na = "",
    fileEncoding = "UTF-8"
  )
  path
}

workflowPolicyTree = function(tool) {
  root = tempfile("workflow-identity-policy-")
  dir.create(root, recursive = TRUE)
  dir.create(file.path(root, ".planning", "phases", 
                       "03-gemodelr-identity-migration"), recursive = TRUE)
  dir.create(file.path(root, "inst", "migration"), recursive = TRUE)
  dir.create(file.path(root, "tools"), recursive = TRUE)
  dir.create(file.path(root, "docs", "migration"), recursive = TRUE)

  registry_path = file.path(
    tool$workflow_identity_repository_root(),
    "inst", "migration", "predecessor-fingerprints.dcf"
  )
  file.copy(
    registry_path,
    file.path(root, "inst", "migration", "predecessor-fingerprints.dcf"),
    overwrite = TRUE
  )

  predecessor_package = tool$workflow_identity_old_token(root)
  metadata_line = paste0("Predecessor-package: ", predecessor_package)

  paths = c(
    ".planning/STATE.md",
    ".planning/ROADMAP.md",
    ".planning/phases/03-gemodelr-identity-migration/03-VALIDATION.md",
    ".planning/phases/03-gemodelr-identity-migration/03-REVIEW.md",
    file.path(
      ".planning/phases/03-gemodelr-identity-migration",
      paste0(sprintf("03-%02d", 13:20), "-SUMMARY.md")
    )
  )
  contents = c(
    metadata_line,
    "Reviewed migration evidence",
    metadata_line,
    "Reviewed verifier evidence",
    rep("", 8L)
  )
  for (index in seq_len(4L)) {
    path = file.path(root, paths[[index]])
    writeLines(contents[[index]], path, useBytes = TRUE)
  }

  policy = data.frame(
    path = paths,
    category = rep("migration-instruction", length(paths)),
    allowed_line_sha256 = c(
      tool$workflow_identity_hash_line(contents[[1L]]),
      tool$workflow_identity_hash_line(contents[[2L]]),
      tool$workflow_identity_hash_line(contents[[3L]]),
      tool$workflow_identity_hash_line(contents[[4L]]),
      rep(tool$workflow_identity_hash_line(metadata_line), 8L)
    ),
    max_count = rep("1", length(paths)),
    owner = c("orchestrator", "orchestrator", "verifier", "verifier",
              rep("orchestrator", 8L)),
    stringsAsFactors = FALSE
  )
  policy_path = file.path(root, "workflow-evidence-policy.csv")
  workflowPolicyWrite(policy, policy_path)
  list(root = root, policy = policy_path, paths = paths, policy_value = policy)
}

test_that("checked-in workflow policy is an approved exact-line contract", {
  skipUnlessWorkflowIdentitySourceTree()
  tool = loadWorkflowIdentityPolicyTool()

  expect_silent(tool$workflow_identity_validate_policy())
  result = tool$workflow_identity_check_lines()
  expect_true(result$clean)
  expect_identical(result$policy$ReviewState, "approved")
  expect_identical(result$policy$Reviewer, "David Zenz")
  expect_identical(result$policy$ReviewedUTC, "2026-09-18T09:59:34Z")
  expect_match(result$policy$PolicySHA256, "^[0-9a-f]{64}$")
  expect_identical(
    result$policy$PathCount,
    length(tool$workflow_identity_allowed_paths())
  )
  expect_identical(
    result$policy$PredecessorPackage,
    tool$workflow_identity_old_token()
  )

  dcf = tool$workflow_identity_read_review()
  expect_identical(dcf$`Schema`, "gemodelr-workflow-identity-policy-review-v1")
  expect_identical(dcf$`Review-State`, "approved")
  expect_identical(dcf$Reviewer, "David Zenz")
  expect_identical(dcf$`Reviewed-UTC`, "2026-09-18T09:59:34Z")
  expect_identical(dcf$`Policy-SHA256`, result$policy$PolicySHA256)
})

test_that("a real evidence lifecycle permits movement but rejects new identity", {
  skipUnlessWorkflowIdentitySourceTree()
  tool = loadWorkflowIdentityPolicyTool()
  tree = workflowPolicyTree(tool)
  predecessor_package = tool$workflow_identity_old_token(tree$root)
  metadata_line = paste0("Predecessor-package: ", predecessor_package)
  on.exit(unlink(tree$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_silent(tool$workflow_identity_check_lines(tree$root, tree$policy))

  state = file.path(tree$root, ".planning", "STATE.md")
  writeLines(
    c("Non-token executor evidence", readLines(state, encoding = "UTF-8")),
    state, useBytes = TRUE
  )
  expect_silent(tool$workflow_identity_check_lines(tree$root, tree$policy))

  writeLines(
    c(readLines(state, encoding = "UTF-8"), paste0("Unreviewed ", predecessor_package, " evidence")),
    state, useBytes = TRUE
  )
  expect_error(
    tool$workflow_identity_check_lines(tree$root, tree$policy),
    "UNKNOWN|UNAPPROVED|LINE"
  )

  summary = file.path(
    tree$root, ".planning", "phases", "03-gemodelr-identity-migration",
    "03-13-SUMMARY.md"
  )
  writeLines(metadata_line, summary, useBytes = TRUE)
  unlink(state)
  writeLines(metadata_line, state, useBytes = TRUE)
  expect_silent(tool$workflow_identity_check_lines(tree$root, tree$policy))

  writeLines(
    c(readLines(summary, encoding = "UTF-8"),
      metadata_line),
    summary, useBytes = TRUE
  )
  expect_error(
    tool$workflow_identity_check_lines(tree$root, tree$policy),
    "COUNT|BOUND|OVER"
  )
})

test_that("policy rejects source, arbitrary planning, and symlink paths", {
  skipUnlessWorkflowIdentitySourceTree()
  tool = loadWorkflowIdentityPolicyTool()
  tree = workflowPolicyTree(tool)
  predecessor_package = tool$workflow_identity_old_token(tree$root)
  metadata_line = paste0("Predecessor-package: ", predecessor_package)
  on.exit(unlink(tree$root, recursive = TRUE, force = TRUE), add = TRUE)

  mutate_policy = function(path) {
    changed = read.csv(tree$policy, stringsAsFactors = FALSE,
                       check.names = FALSE)
    changed$path[[1L]] = path
    candidate = tempfile("workflow-policy-mutated-", fileext = ".csv")
    workflowPolicyWrite(changed, candidate)
    candidate
  }

  source_policy = mutate_policy("R/modelSerialization.R")
  on.exit(unlink(source_policy), add = TRUE)
  expect_error(
    tool$workflow_identity_check_lines(tree$root, source_policy),
    "PATH|SCOPE|ELIGIBLE"
  )

  planning_policy = mutate_policy(".planning/arbitrary.md")
  on.exit(unlink(planning_policy), add = TRUE)
  expect_error(
    tool$workflow_identity_check_lines(tree$root, planning_policy),
    "PATH|SCOPE|ELIGIBLE"
  )

  outside = tempfile("workflow-policy-outside-")
  writeLines(metadata_line, outside, useBytes = TRUE)
  state = file.path(tree$root, ".planning", "STATE.md")
  unlink(state)
  expect_true(file.symlink(outside, state))
  expect_error(
    tool$workflow_identity_check_lines(tree$root, tree$policy),
    "ESCAPE|SYMLINK|PATH"
  )
  unlink(outside)
})

test_that("fenced executable evidence cannot use a metadata allowance", {
  skipUnlessWorkflowIdentitySourceTree()
  tool = loadWorkflowIdentityPolicyTool()
  tree = workflowPolicyTree(tool)
  predecessor_package = tool$workflow_identity_old_token(tree$root)
  metadata_line = paste0("Predecessor-package: ", predecessor_package)
  on.exit(unlink(tree$root, recursive = TRUE, force = TRUE), add = TRUE)

  state = file.path(tree$root, ".planning", "STATE.md")
  writeLines(c(
    "```",
    metadata_line,
    "```"
  ), state, useBytes = TRUE)
  expect_error(
    tool$workflow_identity_check_lines(tree$root, tree$policy),
    "FENCE|CODE|EXECUTABLE"
  )
})

test_that("the proposal does not alter the five-category tracked-source gate", {
  skipUnlessWorkflowIdentitySourceTree()
  tool = loadWorkflowIdentityPolicyTool()
  identity_path = file.path(
    tool$workflow_identity_repository_root(), "tools", 
    "check_identity_migration.R"
  )
  before = readBin(identity_path, "raw", file.info(identity_path)$size)
  identity_tool = new.env(parent = globalenv())
  sys.source(identity_path, envir = identity_tool)
  expect_identical(
    identity_tool$identity_occurrence_categories(),
    c(
      "upstream-attribution", "migration-instruction",
      "immutable-historical-evidence", "old-option-replacement",
      "reviewed-serialization-fingerprint"
    )
  )
  tool$workflow_identity_validate_policy()
  after = readBin(identity_path, "raw", file.info(identity_path)$size)
  expect_identical(after, before)
})
