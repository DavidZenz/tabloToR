#!/usr/bin/env Rscript

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
proposal_dir <- file.path(
  root, ".planning", "phases", "06-documentation-and-release-qualification",
  "06-04-provenance-repair-proposal"
)
source(file.path(root, "tools", "provenance_inventory.R"))

reviewer <- "David Zenz"
review_date <- "2026-10-06"
license_basis <- "provisional Apache-2.0 pending dependency compatibility audit"
new_identity_notes <- paste(
  "independent post-baseline work; provisional license is not package-license finalization"
)

proposal_lines <- readLines(file.path(proposal_dir, "PROPOSAL.md"), warn = FALSE)
candidate_md5 <- function(name) {
  prefix <- paste0("- ", name, ": `")
  hit <- proposal_lines[startsWith(proposal_lines, prefix)]
  if (length(hit) != 1L) stop(paste("missing candidate digest:", name), call. = FALSE)
  substring(hit, nchar(prefix) + 1L, nchar(hit) - 1L)
}
approved_candidate <- c(
  "candidate-EXPECTED-KEYS.csv" = candidate_md5("candidate-EXPECTED-KEYS.csv"),
  "candidate-PROVENANCE.csv" = candidate_md5("candidate-PROVENANCE.csv"),
  "candidate-review-delta.csv" = candidate_md5("candidate-review-delta.csv"),
  "reference-alias-map.csv" = candidate_md5("reference-alias-map.csv")
)
for (name in names(approved_candidate)) {
  path <- file.path(proposal_dir, name)
  actual <- unname(tools::md5sum(path)[[1L]])
  if (!identical(actual, unname(approved_candidate[[name]]))) {
    stop(paste("approved candidate changed after confirmation:", name), call. = FALSE)
  }
}

inventory <- provenance_collect_sources(root, include_git = TRUE)
keys <- provenance_key_frame(inventory)
if (anyDuplicated(keys)) stop("current source inventory has duplicate keys", call. = FALSE)
expected_before <- provenance_read_csv(
  file.path(root, "docs", "provenance", "EXPECTED-KEYS.csv"), c("path", "symbol")
)
ledger_before <- provenance_read_csv(
  file.path(root, "docs", "provenance", "PROVENANCE.csv"), provenance_columns
)
review_before_path <- file.path(root, "docs", "provenance", "INVENTORY-REVIEW.csv")
review_before <- provenance_read_csv(review_before_path)
expected_before_keys <- provenance_key_frame(expected_before)
ledger_before_keys <- provenance_key_frame(ledger_before)
if (length(expected_before_keys) != 291L || nrow(ledger_before) != 291L ||
    !identical(expected_before_keys, ledger_before_keys)) {
  stop("canonical provenance baseline changed after candidate review", call. = FALSE)
}
if (length(setdiff(expected_before_keys, keys))) {
  stop("the candidate would drop an existing expected key", call. = FALSE)
}

expected <- inventory[, c("path", "symbol"), drop = FALSE]
ledger <- provenance_build_ledger(inventory, ledger_before)
prior_match <- match(keys, ledger_before_keys)
changed <- !is.na(prior_match) &
  ledger$expression_hash != ledger_before$expression_hash[prior_match]
new <- is.na(prior_match)
if (sum(changed) != 32L || sum(new) != 33L || nrow(ledger) != 324L) {
  stop("the approved source delta no longer matches its reviewed scope", call. = FALSE)
}

status_by_classification <- c(
  "inherited-identical" = "reviewed-cleared",
  "inherited-modified" = "reviewed-mixed-provisional",
  "new-independent" = "reviewed-provisional",
  "generated" = "reviewed-generated",
  "third-party" = "reviewed-third-party"
)
make_evidence <- function(id, suffix = "") {
  base <- sprintf(
    "source-lines:%d-%d; first-local-commit:%s; Git history is audit evidence, not ownership proof",
    inventory$line_start[[id]], inventory$line_end[[id]],
    inventory$first_local_commit[[id]]
  )
  if (nzchar(suffix)) paste(base, suffix, sep = "; ") else base
}

changed_ids <- which(changed)
for (id in changed_ids) {
  classification <- ledger$classification[[id]]
  if (!classification %in% names(status_by_classification)) {
    stop(paste("unsupported reviewed classification:", classification), call. = FALSE)
  }
  ledger$reviewer[[id]] <- reviewer
  ledger$review_date[[id]] <- review_date
  ledger$status[[id]] <- unname(status_by_classification[[classification]])
  ledger$evidence[[id]] <- make_evidence(id)
}

new_ids <- which(new)
if (any(inventory$contributors[new_ids] != reviewer)) {
  stop("new source identities do not match the confirmed contributor decision", call. = FALSE)
}
for (id in new_ids) {
  symbol <- inventory$symbol[[id]]
  is_reference <- grepl("_reference$", symbol)
  previous_key <- ""
  previous_hash <- ""
  if (identical(symbol, ".sparse_accept_candidate_reference")) {
    previous_key <- "R/sparseSolver.R::.sparse_accept_candidate"
    previous_id <- match(previous_key, ledger_before_keys)
    if (is.na(previous_id)) stop("approved predecessor key is missing", call. = FALSE)
    previous_hash <- ledger_before$expression_hash[[previous_id]]
    copy_fields <- c(
      "classification", "upstream_repository", "upstream_commit", "upstream_path",
      "contributors", "copyright_holder", "license_basis", "notes"
    )
    for (field in copy_fields) ledger[[field]][[id]] <- ledger_before[[field]][[previous_id]]
  } else {
    ledger$classification[[id]] <- "new-independent"
    ledger$upstream_repository[[id]] <- ""
    ledger$upstream_commit[[id]] <- ""
    ledger$upstream_path[[id]] <- ""
    ledger$contributors[[id]] <- reviewer
    ledger$copyright_holder[[id]] <- reviewer
    ledger$license_basis[[id]] <- license_basis
    ledger$notes[[id]] <- new_identity_notes
  }
  if (!ledger$classification[[id]] %in% names(status_by_classification)) {
    stop(paste("unsupported new identity classification:", symbol), call. = FALSE)
  }
  alias_note <- if (is_reference) {
    paste0("runtime reference alias for ", sub("_reference$", "", symbol))
  } else {
    ""
  }
  lineage_note <- if (nzchar(previous_key)) {
    paste0("prior-reviewed-key:", previous_key, "; prior-hash:", previous_hash)
  } else {
    ""
  }
  suffix <- paste(c(alias_note, lineage_note), collapse = "; ")
  suffix <- sub("^;+|;+$", "", suffix)
  ledger$evidence[[id]] <- make_evidence(id, suffix)
  ledger$reviewer[[id]] <- reviewer
  ledger$review_date[[id]] <- review_date
  ledger$status[[id]] <- unname(status_by_classification[[ledger$classification[[id]]]])
}

order_id <- order(ledger$path, ledger$symbol, method = "radix")
expected <- expected[order_id, , drop = FALSE]
ledger <- ledger[order_id, , drop = FALSE]
rownames(expected) <- NULL
rownames(ledger) <- NULL
invisible(provenance_validate_ledger(ledger, expected, inventory))

candidate_delta <- provenance_read_csv(
  file.path(proposal_dir, "candidate-review-delta.csv")
)
candidate_delta_key <- paste(candidate_delta$path, candidate_delta$symbol, sep = "::")
if (!setequal(candidate_delta_key, c(keys[changed], keys[new]))) {
  stop("the approval delta does not bind the current changed/new keys", call. = FALSE)
}
aliases <- provenance_read_csv(file.path(proposal_dir, "reference-alias-map.csv"))
alias_keys <- paste(aliases$path, aliases$proposed_symbol, sep = "::")

review_rows <- vector("list", sum(changed) + sum(new))
review_keys <- c(keys[changed], keys[new])
review_ids <- match(review_keys, keys)
for (row_id in seq_along(review_ids)) {
  id <- review_ids[[row_id]]
  key <- keys[[id]]
  prior_id <- match(key, ledger_before_keys)
  is_new <- is.na(prior_id)
  alias_id <- match(key, alias_keys)
  change <- if (!is_new) {
    "expression-hash-changed"
  } else if (!is.na(alias_id)) {
    "reference-alias-added"
  } else {
    "added"
  }
  old_hash <- if (!is_new) ledger_before$expression_hash[[prior_id]] else ""
  evidence_suffix <- ""
  if (!is.na(alias_id)) {
    previous_key <- aliases$prior_ledger_key_candidate[[alias_id]]
    evidence_suffix <- paste0("runtime-alias:", aliases$proposed_symbol[[alias_id]])
    if (nzchar(previous_key)) {
      previous_id <- match(previous_key, ledger_before_keys)
      if (is.na(previous_id)) stop("alias lineage predecessor is missing", call. = FALSE)
      old_hash <- ledger_before$expression_hash[[previous_id]]
      evidence_suffix <- paste0(
        evidence_suffix, "; previous-key:", previous_key,
        "; previous-accepted-hash:", old_hash
      )
    }
  }
  evidence <- ledger$evidence[[id]]
  if (nzchar(evidence_suffix) && !grepl(evidence_suffix, evidence, fixed = TRUE)) {
    evidence <- paste(evidence, evidence_suffix, sep = "; ")
  }
  review_rows[[row_id]] <- data.frame(
    previous_key_count = "291",
    current_key_count = "324",
    key = key,
    change = change,
    old_hash = old_hash,
    accepted_hash = ledger$expression_hash[[id]],
    source_lines = sprintf("%d-%d", inventory$line_start[[id]], inventory$line_end[[id]]),
    first_local_commit = ledger$first_local_commit[[id]],
    classification = ledger$classification[[id]],
    contributors = ledger$contributors[[id]],
    copyright_holder = ledger$copyright_holder[[id]],
    license_basis = ledger$license_basis[[id]],
    evidence = evidence,
    status = ledger$status[[id]],
    reviewer = reviewer,
    review_date = review_date,
    disposition = "accepted",
    stringsAsFactors = FALSE
  )
}
review_delta <- do.call(rbind, review_rows)
review_delta <- review_delta[order(review_delta$key, method = "radix"), , drop = FALSE]
if (!identical(names(review_delta), names(review_before))) {
  stop("inventory-review transition does not match its canonical schema", call. = FALSE)
}

review_before_lines <- readLines(review_before_path, warn = FALSE, encoding = "UTF-8")
review_temp <- tempfile("provenance-review-append-")
on.exit(unlink(review_temp), add = TRUE)
utils::write.table(
  review_delta, review_temp, sep = ",", quote = TRUE,
  row.names = FALSE, col.names = FALSE, na = "", qmethod = "double"
)
review_delta_lines <- readLines(review_temp, warn = FALSE, encoding = "UTF-8")
review_final_lines <- c(review_before_lines, review_delta_lines)

write_csv <- function(value, name) {
  utils::write.csv(value, file.path(proposal_dir, name), row.names = FALSE, na = "")
}
write_csv(expected, "final-EXPECTED-KEYS.csv")
write_csv(ledger, "final-PROVENANCE.csv")
writeLines(review_final_lines, file.path(proposal_dir, "final-INVENTORY-REVIEW.csv"),
           useBytes = TRUE)

attribution <- readLines(
  file.path(root, "docs", "provenance", "ATTRIBUTION.md"),
  warn = FALSE, encoding = "UTF-8"
)
review_final_path <- file.path(proposal_dir, "final-INVENTORY-REVIEW.csv")
inventory_md5 <- unname(tools::md5sum(file.path(proposal_dir, "final-PROVENANCE.csv"))[[1L]])
review_md5 <- unname(tools::md5sum(review_final_path)[[1L]])
attribution <- sub("^Inventory-Row-Count:.*$", "Inventory-Row-Count: 324", attribution)
attribution <- sub(
  "^Inventory-Snapshot-MD5:.*$",
  paste0("Inventory-Snapshot-MD5: ", inventory_md5), attribution
)
attribution <- sub(
  "^Inventory-Review-MD5:.*$",
  paste0("Inventory-Review-MD5: ", review_md5), attribution
)
attribution <- sub(
  "^The inventory snapshot binds these role decisions to the reviewed Phase 01 ledger$",
  "The inventory snapshot binds these role decisions to the reviewed Phase 01 ledger,",
  attribution
)
attribution <- sub(
  "^and the accepted Phase 02 source expansion in INVENTORY-REVIEW.csv\\. The MD5$",
  "the accepted Phase 02 expansion, and the reviewed 291-to-324 current-source transition in INVENTORY-REVIEW.csv. The MD5",
  attribution
)
writeLines(attribution, file.path(proposal_dir, "final-ATTRIBUTION.md"), useBytes = TRUE)

approval <- data.frame(
  `Approval-Version` = "1",
  `Approval-Basis` = "Explicit user confirmation after review of the Phase 06-04 provenance repair proposal",
  `Approved-By` = reviewer,
  `Review-Date-UTC` = review_date,
  `Candidate-Expected-MD5` = unname(approved_candidate[["candidate-EXPECTED-KEYS.csv"]]),
  `Candidate-Provenance-MD5` = unname(approved_candidate[["candidate-PROVENANCE.csv"]]),
  `Candidate-Review-Delta-MD5` = unname(approved_candidate[["candidate-review-delta.csv"]]),
  `Reference-Alias-Map-MD5` = unname(approved_candidate[["reference-alias-map.csv"]]),
  `Accepted-Hash-Changes` = as.character(sum(changed)),
  `Accepted-New-Identities` = as.character(sum(new)),
  `New-Identity-Decision` = "new-independent; David Zenz; provisional Apache-2.0 pending dependency compatibility audit",
  `Release-Blockers` = "DEPENDENCY_COMPATIBILITY_AUDIT_PENDING, ATTRIBUTION_IDENTITY_UNRESOLVED remain unresolved",
  `Finalization-Checksums` = "FINALIZATION-CHECKSUMS.sha256",
  `Finalization-Status` = "review-fields-finalized; canonical-apply-pending-validation",
  check.names = FALSE,
  stringsAsFactors = FALSE
)
write.dcf(approval, file.path(proposal_dir, "REVIEW-APPROVAL.dcf"))

cat(sprintf(
  "final_expected=%d final_ledger=%d final_review_rows=%d changed_hashes=%d added_identities=%d reviewer=%s date=%s\n",
  nrow(expected), nrow(ledger), nrow(review_delta), sum(changed), sum(new),
  reviewer, review_date
))
