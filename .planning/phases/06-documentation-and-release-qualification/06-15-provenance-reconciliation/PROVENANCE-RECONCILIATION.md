# Phase 06-15 provenance reconciliation proposal

input_commit=492aa5d733b6d39fdd68278ef9adf16d8e7220c3
source_snapshot_sha256=14b6ae619b494f3c83d676c8371c92fa43b3744777cfd3c886b29761839659a2
source_snapshot_input_file_count=50
generator_sha256=9c9878ef56cad0c7e6cf632755b4a502af8f8d249c580bdc3a86ddb5d7ba0681
candidate_delta_sha256=e250ad497e7795a142624bc39c9d4563b3a9ef51bd944321ec2027df63317541
missing_key_count=0
extra_key_count=23
changed_hash_count=27
canonical_ledger_missing_key_count=0
canonical_ledger_extra_key_count=0
review_delta_row_count=50

## Comparison scope

The detached, clean input tree at `492aa5d733b6d39fdd68278ef9adf16d8e7220c3` was inventoried with its tracked R/C/C++ source files under `R/`, `src/`, and `inst/cpp/`.
The SHA-256 source snapshot fingerprint binds the raw bytes and relative paths of those files,
`tools/provenance_inventory.R`, and the canonical `EXPECTED-KEYS.csv` and `PROVENANCE.csv` inputs.
The input fingerprint excludes proposal outputs and other metadata outside this inventoried input set.

The review delta compares the clean source inventory with the canonical expected keys and ledger from the same input commit.
`before_expression_hash_md5` and `after_expression_hash_md5` are exact expression digests from the existing inventory convention;
the SHA-256 snapshot and proposal digests bind the corresponding input and output bytes.

## Exact delta counts

- Missing source keys present in the canonical expected-key list: 0
- Source keys absent from the canonical expected-key list: 23
- Matching source keys with a changed ledger expression hash: 27
- Expected keys with no canonical ledger row: 0
- Canonical ledger keys absent from the expected-key list: 0
- Total review-delta rows: 50

The CSV gives each row's path, symbol, source line range where present, input commit, source snapshot digest,
and exact before/after expression digests. Source lines and Git history are investigative leads only.
Git-derived first-commit and contributor fields are marked audit-only and do not establish identity, authorship,
copyright, license rights, or attribution. The proposed author, copyright, license-basis, reviewer, and review-date fields are blank.
No canonical provenance, attribution, or release-blocker record was changed.

## Preserved documentation and release decisions

- D-01: retain the pkgdown GitHub Pages site alongside package vignettes.
- D-02: keep user guides, API reference, migration, architecture, and contributor guidance in the site; keep detailed release/provenance evidence repository-only.
- D-03: retain the five focused vignette topics.
- D-04: keep normal builds on small redistributable fixtures; document but do not run the external full-scale benchmark.
- D-05: retain the adopted pre-1.0 and post-1.0 lifecycle/deprecation policy and identify 0.1.0 as development-only.

## Review boundary

This is an unapproved proposal. Review every delta row against evidence that independently establishes the relevant source identity and rights.
A Git author name or commit message alone is insufficient. Do not populate attribution facts by inference.
Canonical files remain unchanged until the exact input commit and delta digest are approved in the separate review step.
The generator and immutable report/delta output digests are listed in `SHA256SUMS`; the report's own digest is also in that manifest.
