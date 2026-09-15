# GEModelR compatibility identity manifest

Current package identity: `GEModelR`

This manifest records the documentation and compatibility boundary established
by the immediate identity replacement. The namespace remains broad with 171
alphabetic exports. `GEModel` remains the supported entry point, and all 11
recorded method names and signatures in `GEModel-contract.csv` remain unchanged.

The predecessor occurrences retained by this plan are inputs to the exact
occurrence-level audit in Plan 03-10. Counts are fixed after the owned files are
finalized; categories use only the reviewed audit vocabulary.

| Path | Categories | Expected occurrences | Rationale |
|---|---|---:|---|
| `README.md` | upstream-attribution, migration-instruction | 4 | Exact upstream repository, audited commit, and migration route |
| `MIGRATION.md` | upstream-attribution, migration-instruction, old-option-replacement | 41 | Exact mechanical replacements and approved immutable saved-state bridge |
| `inst/CITATION` | upstream-attribution | 3 | Truthful separately cited predecessor source |
| `tests/testthat/test-identity-migration.R` | migration-instruction, old-option-replacement | 23 | Regression assertions for exact predecessor-to-current replacements |

`R/main.R` and `inst/compatibility/GEModel-contract.csv` contain current GEModelR
identity only. Immutable Phase 2 baselines, benchmark results, the predecessor
registry, and its schema-1 fixture remain outside this plan and retain their
reviewed historical bytes.
