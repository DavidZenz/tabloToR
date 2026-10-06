# Phase 06-04 provenance repair candidate

This is a proposal-only snapshot. It does not change the canonical provenance ledger, expected keys, or attribution contract.

## Inventory comparison

- Canonical expected keys and ledger rows: 291 / 291
- Fresh source rows: 324; duplicate keys after alias handling: 0; explicit reference aliases: 2
- Candidate source identities after explicit `_reference` alias mapping: 324
- Existing expected keys missing from candidate: 0
- Additional candidate identities: 33
- Existing expression hashes requiring review: 32
- Total review-delta rows: 65

## Candidate boundaries

- `reference-alias-map.csv` maps only a function body that is copied to an explicit `<name>_reference` binding before a later redefinition. The source body is keyed by its runtime alias; the later body retains the original symbol. The `.sparse_accept_candidate_reference` row is flagged as a possible continuation of a previously reviewed identity, which still needs reviewer confirmation.
- New candidate rows remain `unknown` and `unreviewed`; contributor, copyright holder, license basis, reviewer, and review date are blank. Git-derived names are shown only in the delta as audit leads, not as ownership evidence.
- Existing rows whose source expression changed retain prior reviewed fields but receive `hash-changed-review-required` in this candidate.
- Candidate attribution changes only the row count and snapshot MD5. The canonical attribution file is untouched.
- The production collector now emits the explicit runtime alias keys shown in `reference-alias-map.csv`; the canonical expected-key, ledger, and attribution files remain untouched. Review the identity convention and candidate evidence before applying canonical rows.

## Candidate file MD5 values

- candidate-source-inventory.csv: `72ec4148e049d4fed75ba08da58cb921`
- candidate-EXPECTED-KEYS.csv: `e28b5b0ab4a24e9e44304c7f56f81af8`
- candidate-PROVENANCE.csv: `f987c297c786a85dfe25744dbe2c1a58`
- candidate-review-delta.csv: `befc9f68d4e30cfb7511142b5ec2d9b0`
- reference-alias-map.csv: `6cd545a7f731bce335c02046074dca3c`
- candidate-ATTRIBUTION.md: `66d1757698a620dd06e816ed88c5db18`

SHA-256 values for the canonical baseline, candidate outputs, and this generator are recorded in `REPAIR-CHECKSUMS.sha256`.

## Review checkpoint

Review `candidate-review-delta.csv`, the alias convention, and the candidate ledger before any canonical provenance files are changed. No candidate row has been approved for authorship, ownership, or licensing by this preparation.
