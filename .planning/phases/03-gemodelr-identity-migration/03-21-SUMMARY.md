---
phase: 03-gemodelr-identity-migration
plan: 21
subsystem: provenance
tags: [provenance, identity-migration, gap-closure, reseal]
requires:
  - phase: 03-gemodelr-identity-migration
    provides: approved identity policy, predecessor evidence, and the retained 03-20 blocker
provides:
  - reviewed provenance inventory at 291 rows
  - hash-bound incremental identity reseal after the provenance-row insertion
  - clean handoff evidence for the later 03-20 qualification
affects: [03-20 qualification, Phase 03 verification]
actuals:
  tasks: 3
  commits: 1
requirements-completed: [COMP-04, MIGR-01, MIGR-02]
completed: 2026-09-25
status: complete
---

# Phase 03 Plan 21: Provenance Gap-Closure Summary

## Outcome

The retained 03-20 qualification stop is repaired. The exact missing key was
`R/modelSerialization.R::.serialization_promote_reconstructed_fields` with
expression hash `95d17ff091860cb03f8d0bc832b5ca0c`, source lines 417-430,
reviewed as `new-independent` by David Zenz on 2026-09-25. The reviewed
expected-key and provenance ledgers now contain 291 rows, and the final row is
`reviewed-provisional`.

Before-state evidence remains bound to expected-key SHA-256
`7eb3e13da7cde3cdaecc31af0aafeef1a18f5aaa173b0cf3fe706c91b66c8310`, ledger
SHA-256 `c21547070e857d97c07760a24f258fa89d916e51be65a53d27dfc6feec2fd863`,
and ledger MD5 `f05d6c33a370088911ace211c9de20a4`. Final applied evidence is:

- `EXPECTED-KEYS.csv`: SHA-256 `7db15ff6d81f07109b4e5be6b7c34890e66a54f83f288a32397b9e8c727c6d8d`
- `PROVENANCE.csv`: SHA-256 `a13facb7df2072dcd61f45645f0e1424cb66449d1e5d7e63bbc55bb7542a3218`, MD5 `ee9daa3ead2b1b30181d64dc1697b525`
- `ATTRIBUTION.md`: SHA-256 `fba2bb62e4962a2f9b390d564b259647b45acafa14ff1a0a97efa5eceb241e5a`

## Verification

The workflow-policy, provenance, tracked-source identity, historical identity,
predecessor, migration-source, original-artifact, serialization-BUGFIX, and
read-only final-tree gates all passed. The outside-root final manifest validator
also passed: five declared/protected paths changed, final bytes match the
reviewed bundle, and the ledger validates at 291/291. The pre-dispatch resolver
passed for both opaque predecessor aliases. Focused provenance, attribution,
serialization, and identity-reseal tests pass; the existing R reference-class
`data$eqcoeff` warning remains non-fatal.

## Approved deviation and reseal

Inserting the 291st provenance row changed the line-number digest for exactly
one existing `docs/provenance/PROVENANCE.csv` occurrence. The user authorized a
narrow occurrence-count-preserving allowlist reseal from SHA-256
`514417bba0b7845a91fdf426c007ebace80f62da6b5054af6b8376978192cb27` to
`1bf1d3117bce193ef4ca6018ac6dec2fc55e2605f9fb89939d894cba82ae60ac`.
The current identity review DCF was correspondingly rebound from SHA-256
`ec0ef9eed8728cadf7d49d4dcb9a68a2fcc9fc15f5469a8de4a4c4c86c8624ff` to
`8114457463acf8096405eefdaf10b9ef7afc7ce8764b1d0f3b3b465df6fb19a6`.
The historical 03-19 summary and protected historical approval evidence remain
unchanged. The task-local predecessor resolver was updated outside the
repository to recognize this explicit chained reseal.

Five current-row-count assertions in `test-provenance-inventory.R` were also
updated from 290 to 291; they test the current ledger and fresh inventory, not
the immutable Phase 02 review counts. No solver, package source, policy,
baseline, original fixture, or historical evidence was changed.

## Handoff

03-20 was not executed. Its dispatch remains blocked until this summary is
committed and the tracked technical-input barrier is clean. No release or
publication decision is implied; the independent compatibility and attribution
blockers remain in force.
