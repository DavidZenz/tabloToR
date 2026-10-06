#!/usr/bin/env Rscript

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
proposal_dir <- file.path(
  root, ".planning", "phases", "06-documentation-and-release-qualification",
  "06-04-provenance-repair-proposal"
)
source(file.path(root, "tools", "provenance_inventory.R"))

proposal_abort <- function(message) stop(message, call. = FALSE)

proposal_alias_inventory <- function(inventory, root) {
  alias_records <- list()
  r_paths <- sort(unique(inventory$path[grepl("\\.R$", inventory$path)]))
  for (relative in r_paths) {
    expressions <- tryCatch(
      parse(file.path(root, relative), keep.source = TRUE),
      error = function(error) proposal_abort(paste("parse failed:", relative))
    )
    references <- attr(expressions, "srcref", exact = TRUE)
    if (is.null(references)) next
    for (expression_id in seq_along(expressions)) {
      expression <- expressions[[expression_id]]
      if (!is.call(expression) || length(expression) < 3L ||
          !as.character(expression[[1L]]) %in% c("<-", "=")) next
      target <- expression[[2L]]
      value <- expression[[3L]]
      if (!is.symbol(target) || !is.symbol(value)) next
      alias <- as.character(target)
      original <- as.character(value)
      if (!grepl("_reference$", alias) ||
          !identical(sub("_reference$", "", alias), original)) next
      alias_range <- provenance_srcref_lines(references[[expression_id]])
      same_symbol <- which(
        inventory$path == relative & inventory$symbol == original
      )
      before <- same_symbol[
        inventory$line_end[same_symbol] < alias_range[[1L]]
      ]
      after <- same_symbol[
        inventory$line_start[same_symbol] > alias_range[[2L]]
      ]
      alias_rows <- which(
        inventory$path == relative & inventory$symbol == alias &
          inventory$line_end < alias_range[[1L]]
      )
      if (!length(after) || (!length(before) && !length(alias_rows))) next
      source_id <- if (length(alias_rows)) {
        alias_rows[which.max(inventory$line_start[alias_rows])]
      } else {
        before[which.max(inventory$line_start[before])]
      }
      if (length(alias_rows) > 1L ||
          any(inventory$path == relative & inventory$symbol == alias &
              seq_len(nrow(inventory)) != source_id)) {
        proposal_abort(paste("ambiguous alias target:", relative, alias))
      }
      alias_records[[length(alias_records) + 1L]] <- data.frame(
        path = relative,
        previous_symbol = original,
        proposed_symbol = alias,
        definition_line_start = inventory$line_start[[source_id]],
        definition_line_end = inventory$line_end[[source_id]],
        alias_line_start = alias_range[[1L]],
        alias_line_end = alias_range[[2L]],
        stringsAsFactors = FALSE
      )
      inventory$symbol[[source_id]] <- alias
    }
  }
  aliases <- if (length(alias_records)) do.call(rbind, alias_records) else data.frame(
    path = character(), previous_symbol = character(),
    proposed_symbol = character(), definition_line_start = integer(),
    definition_line_end = integer(), alias_line_start = integer(),
    alias_line_end = integer(), stringsAsFactors = FALSE
  )
  inventory <- inventory[order(inventory$path, inventory$symbol, method = "radix"),
                         , drop = FALSE]
  rownames(inventory) <- NULL
  if (anyDuplicated(provenance_key_frame(inventory))) {
    proposal_abort("candidate source inventory still has duplicate keys")
  }
  list(inventory = inventory, aliases = aliases)
}

write_csv <- function(value, path) {
  utils::write.csv(value, path, row.names = FALSE, na = "")
}

inventory <- provenance_collect_sources(root, include_git = TRUE)
aliased <- proposal_alias_inventory(inventory, root)
inventory <- aliased$inventory
aliases <- aliased$aliases
keys <- provenance_key_frame(inventory)
duplicate_keys_after_alias_handling <- sum(duplicated(keys))

expected_path <- file.path(root, "docs", "provenance", "EXPECTED-KEYS.csv")
ledger_path <- file.path(root, "docs", "provenance", "PROVENANCE.csv")
attribution_path <- file.path(root, "docs", "provenance", "ATTRIBUTION.md")
expected_before <- provenance_read_csv(expected_path, c("path", "symbol"))
ledger_before <- provenance_read_csv(ledger_path, provenance_columns)
expected_before_keys <- provenance_key_frame(expected_before)
ledger_before_keys <- provenance_key_frame(ledger_before)

if (anyDuplicated(expected_before_keys) || anyDuplicated(ledger_before_keys)) {
  proposal_abort("canonical provenance evidence unexpectedly has duplicate keys")
}
missing <- setdiff(expected_before_keys, keys)
if (length(missing)) {
  proposal_abort(paste("candidate would drop existing keys:", paste(missing, collapse = ", ")))
}

aliases$prior_ledger_key_candidate <- ifelse(
  aliases$previous_symbol == ".sparse_accept_candidate",
  paste(aliases$path, aliases$previous_symbol, sep = "::"),
  ""
)
aliases$lineage_review <- ifelse(
  nzchar(aliases$prior_ledger_key_candidate),
  "Possible continuation of the previously reviewed function; confirm against the prior accepted hash and review record.",
  "No same-name reviewed ledger key; classify this saved implementation independently."
)

candidate_expected <- inventory[, c("path", "symbol"), drop = FALSE]
candidate_ledger <- provenance_build_ledger(inventory, ledger_before)
new_keys <- setdiff(keys, ledger_before_keys)
new_rows <- match(new_keys, keys)
candidate_ledger$contributors[new_rows] <- ""
candidate_ledger$classification[new_rows] <- "unknown"
candidate_ledger$copyright_holder[new_rows] <- ""
candidate_ledger$license_basis[new_rows] <- ""
candidate_ledger$reviewer[new_rows] <- ""
candidate_ledger$review_date[new_rows] <- ""
candidate_ledger$status[new_rows] <- "unreviewed"

prior_match <- match(keys, ledger_before_keys)
has_prior <- !is.na(prior_match)
hash_changed <- rep(FALSE, length(keys))
hash_changed[has_prior] <- candidate_ledger$expression_hash[has_prior] !=
  ledger_before$expression_hash[prior_match[has_prior]]

delta_rows <- list()
for (id in seq_along(keys)) {
  if (!is.na(prior_match[[id]]) && !hash_changed[[id]]) next
  change <- if (is.na(prior_match[[id]])) {
    if (keys[[id]] %in% paste(aliases$path, aliases$proposed_symbol, sep = "::")) {
      "reference-alias-identity-unreviewed"
    } else {
      "new-source-identity-unreviewed"
    }
  } else {
    "expression-hash-changed-review-required"
  }
  previous_hash <- if (is.na(prior_match[[id]])) "" else
    ledger_before$expression_hash[[prior_match[[id]]]]
  alias_id <- match(keys[[id]], paste(aliases$path, aliases$proposed_symbol, sep = "::"))
  prior_key_candidate <- if (!is.na(alias_id)) {
    aliases$prior_ledger_key_candidate[[alias_id]]
  } else {
    ""
  }
  delta_rows[[length(delta_rows) + 1L]] <- data.frame(
    change = change,
    path = inventory$path[[id]],
    symbol = inventory$symbol[[id]],
    prior_ledger_key_candidate = prior_key_candidate,
    line_start = inventory$line_start[[id]],
    line_end = inventory$line_end[[id]],
    old_expression_hash = previous_hash,
    candidate_expression_hash = inventory$expression_hash[[id]],
    first_local_commit = inventory$first_local_commit[[id]],
    git_contributors_audit_only = inventory$contributors[[id]],
    candidate_status = candidate_ledger$status[[id]],
    stringsAsFactors = FALSE
  )
}
delta <- if (length(delta_rows)) do.call(rbind, delta_rows) else data.frame()

write_csv(inventory, file.path(proposal_dir, "candidate-source-inventory.csv"))
write_csv(candidate_expected, file.path(proposal_dir, "candidate-EXPECTED-KEYS.csv"))
write_csv(candidate_ledger, file.path(proposal_dir, "candidate-PROVENANCE.csv"))
write_csv(delta, file.path(proposal_dir, "candidate-review-delta.csv"))
write_csv(aliases, file.path(proposal_dir, "reference-alias-map.csv"))

candidate_attribution <- readLines(attribution_path, warn = FALSE, encoding = "UTF-8")
candidate_md5 <- unname(tools::md5sum(
  file.path(proposal_dir, "candidate-PROVENANCE.csv")
)[[1L]])
candidate_attribution <- sub(
  "^Inventory-Row-Count:.*$",
  paste0("Inventory-Row-Count: ", nrow(candidate_ledger)),
  candidate_attribution
)
candidate_attribution <- sub(
  "^Inventory-Snapshot-MD5:.*$",
  paste0("Inventory-Snapshot-MD5: ", candidate_md5),
  candidate_attribution
)

writeLines(candidate_attribution, file.path(proposal_dir, "candidate-ATTRIBUTION.md"),
           useBytes = TRUE)

expected_sha <- length(setdiff(expected_before_keys, keys))
extra_keys <- length(setdiff(keys, expected_before_keys))
hash_changes <- sum(hash_changed)
md5s <- tools::md5sum(c(
  file.path(proposal_dir, "candidate-source-inventory.csv"),
  file.path(proposal_dir, "candidate-EXPECTED-KEYS.csv"),
  file.path(proposal_dir, "candidate-PROVENANCE.csv"),
  file.path(proposal_dir, "candidate-review-delta.csv"),
  file.path(proposal_dir, "reference-alias-map.csv"),
  file.path(proposal_dir, "candidate-ATTRIBUTION.md")
))
names(md5s) <- basename(names(md5s))
manifest <- c(
  "# Phase 06-04 provenance repair candidate",
  "",
  "This is a proposal-only snapshot. It does not change the canonical provenance ledger, expected keys, or attribution contract.",
  "",
  "## Inventory comparison",
  "",
  sprintf("- Canonical expected keys and ledger rows: %d / %d", length(expected_before_keys), nrow(ledger_before)),
  sprintf("- Fresh source rows: %d; duplicate keys after alias handling: %d; explicit reference aliases: %d", nrow(inventory), duplicate_keys_after_alias_handling, nrow(aliases)),
  sprintf("- Candidate source identities after explicit `_reference` alias mapping: %d", nrow(inventory)),
  sprintf("- Existing expected keys missing from candidate: %d", expected_sha),
  sprintf("- Additional candidate identities: %d", extra_keys),
  sprintf("- Existing expression hashes requiring review: %d", hash_changes),
  sprintf("- Total review-delta rows: %d", nrow(delta)),
  "",
  "## Candidate boundaries",
  "",
  "- `reference-alias-map.csv` maps only a function body that is copied to an explicit `<name>_reference` binding before a later redefinition. The source body is keyed by its runtime alias; the later body retains the original symbol. The `.sparse_accept_candidate_reference` row is flagged as a possible continuation of a previously reviewed identity, which still needs reviewer confirmation.",
  "- New candidate rows remain `unknown` and `unreviewed`; contributor, copyright holder, license basis, reviewer, and review date are blank. Git-derived names are shown only in the delta as audit leads, not as ownership evidence.",
  "- Existing rows whose source expression changed retain prior reviewed fields but receive `hash-changed-review-required` in this candidate.",
  "- Candidate attribution changes only the row count and snapshot MD5. The canonical attribution file is untouched.",
  "- The production collector now emits the explicit runtime alias keys shown in `reference-alias-map.csv`; the canonical expected-key, ledger, and attribution files remain untouched. Review the identity convention and candidate evidence before applying canonical rows.",
  "",
  "## Candidate file MD5 values",
  "",
  paste0("- ", names(md5s), ": `", unname(md5s), "`"),
  "",
  "SHA-256 values for the canonical baseline, candidate outputs, and this generator are recorded in `REPAIR-CHECKSUMS.sha256`.",
  "",
  "## Review checkpoint",
  "",
  "Review `candidate-review-delta.csv`, the alias convention, and the candidate ledger before any canonical provenance files are changed. No candidate row has been approved for authorship, ownership, or licensing by this preparation."
)
writeLines(manifest, file.path(proposal_dir, "PROPOSAL.md"), useBytes = TRUE)

cat(sprintf(
  "proposal_rows=%d candidate_keys=%d additional_keys=%d hash_changes=%d delta_rows=%d",
  nrow(inventory), length(keys), extra_keys, hash_changes, nrow(delta)
), "\n", sep = "")
