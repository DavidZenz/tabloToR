#!/usr/bin/env Rscript

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
proposal_dir <- file.path(
  root, ".planning", "phases", "06-documentation-and-release-qualification",
  "06-04-provenance-repair-proposal"
)
source(file.path(root, "tools", "provenance_inventory.R"))

expected <- provenance_read_csv(
  file.path(proposal_dir, "final-EXPECTED-KEYS.csv"), c("path", "symbol")
)
ledger <- provenance_read_csv(
  file.path(proposal_dir, "final-PROVENANCE.csv"), provenance_columns
)
inventory <- provenance_collect_sources(root, include_git = TRUE)
stopifnot(
  nrow(expected) == 324L,
  nrow(ledger) == 324L,
  !anyDuplicated(provenance_key_frame(expected)),
  !anyDuplicated(provenance_key_frame(ledger)),
  !anyDuplicated(provenance_key_frame(inventory))
)
invisible(provenance_validate_ledger(ledger, expected, inventory))

review_path <- file.path(proposal_dir, "final-INVENTORY-REVIEW.csv")
review <- provenance_read_csv(review_path)
review_before <- provenance_read_csv(
  file.path(root, "docs", "provenance", "INVENTORY-REVIEW.csv")
)
review_before_lines <- readLines(
  file.path(root, "docs", "provenance", "INVENTORY-REVIEW.csv"), warn = FALSE
)
review_lines <- readLines(review_path, warn = FALSE)
appended <- review[(nrow(review_before) + 1L):nrow(review), , drop = FALSE]
stopifnot(
  nrow(review) == nrow(review_before) + 65L,
  identical(review_before_lines, review_lines[seq_along(review_before_lines)]),
  all(appended$previous_key_count == "291"),
  all(appended$current_key_count == "324"),
  all(appended$reviewer == "David Zenz"),
  all(appended$review_date == "2026-10-06"),
  all(appended$disposition == "accepted"),
  all(appended$status != "unreviewed")
)

attribution_path <- file.path(proposal_dir, "final-ATTRIBUTION.md")
attribution <- readLines(attribution_path, warn = FALSE)
stopifnot(
  any(attribution == "Inventory-Row-Count: 324"),
  any(attribution == paste0(
    "Inventory-Snapshot-MD5: ",
    unname(tools::md5sum(file.path(proposal_dir, "final-PROVENANCE.csv"))[[1L]])
  )),
  any(attribution == paste0(
    "Inventory-Review-MD5: ",
    unname(tools::md5sum(review_path)[[1L]])
  ))
)

approval <- read.dcf(file.path(proposal_dir, "REVIEW-APPROVAL.dcf"))
stopifnot(
  nrow(approval) == 1L,
  identical(unname(approval[1L, "Approved-By"]), "David Zenz"),
  identical(unname(approval[1L, "Review-Date-UTC"]), "2026-10-06"),
  identical(unname(approval[1L, "Accepted-Hash-Changes"]), "32"),
  identical(unname(approval[1L, "Accepted-New-Identities"]), "33"),
  identical(unname(approval[1L, "Finalization-Checksums"]), "FINALIZATION-CHECKSUMS.sha256")
)

cat(sprintf(
  "finalization=pass expected_keys=%d provenance_rows=%d appended_reviews=%d hash_changes=%d added_identities=%d\n",
  nrow(expected), nrow(ledger), nrow(appended),
  sum(appended$change == "expression-hash-changed"),
  sum(appended$change %in% c("added", "reference-alias-added"))
))
