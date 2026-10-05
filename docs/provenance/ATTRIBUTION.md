# Attribution contract

## Configuration

Attribution-Schema-Version: 1
Inventory-Path: docs/provenance/PROVENANCE.csv
Inventory-Row-Count: 291
Inventory-Snapshot-MD5: ee9daa3ead2b1b30181d64dc1697b525
Inventory-Review-Path: docs/provenance/INVENTORY-REVIEW.csv
Inventory-Review-MD5: f19029655d4e6d366901296ee771e2c3
Upstream-Repository: https://github.com/mivanic/tabloToR
Upstream-Commit: 7e063c65a19713857ed13023f8b77dad45b15c90
Reviewer: David Zenz
Review-Date: 2026-09-09

The inventory snapshot binds these role decisions to the reviewed Phase 01 ledger
and the accepted Phase 02 source expansion in INVENTORY-REVIEW.csv. The MD5
values are deterministic change detectors, not proof of authorship or ownership.
A changed inventory requires a fresh attribution review.

## Reviewed role assignments

| person/entity | role | evidence_keys | rights_basis | destination | reviewer | review_date | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| David Zenz | aut | R/sparseCompiler.R::sparse_compile_spec; R/sparseSolver.R::sparse_solve_model; src/sparse-schur.cpp::GEModelR_schur_accumulate_global | Reviewed independent post-baseline authorship; original-code licensing remains provisional pending the dependency compatibility audit | DESCRIPTION; CONTRIBUTORS.md; NEWS.md; inst/CITATION | David Zenz | 2026-08-25 | reviewed |
| David Zenz | cph | R/sparseCompiler.R::sparse_compile_spec; R/sparseSolver.R::sparse_solve_model; src/sparse-schur.cpp::GEModelR_schur_accumulate_global | Reviewed copyright holder for the cited independent post-baseline expression; this does not finalize the package license | DESCRIPTION; CONTRIBUTORS.md; inst/CITATION | David Zenz | 2026-08-25 | reviewed |
| David Zenz | cre | R/sparseSolver.R::sparse_solve_model | Reviewed substantive contribution plus the approved maintainer identity in GOVERNANCE.md | DESCRIPTION; CONTRIBUTORS.md; inst/CITATION | David Zenz | 2026-08-25 | reviewed |
| Maros Ivanic | aut | R/GEModel.R::GEModel$loadTablo; R/GEModel.R::GEModel$solveModel; R/processTablo.R::processTablo | Reviewed upstream authorship under the accepted public-domain/CC0 response for the audited baseline | DESCRIPTION; README.md; inst/CITATION; docs/provenance/PROVENANCE.csv; CONTRIBUTORS.md; NEWS.md | David Zenz | 2026-08-25 | reviewed |

`aut` records substantive authorship, `cre` records the approved maintainer role,
and `cph` records reviewed ownership of cited post-baseline expression. No `ctb`
role is currently assigned: Git history contains no additional reviewed person
whose identity and contribution threshold support promotion to a package role.
Commit counts and author strings are audit leads only.

## Blocking facts

| fact | evidence_key | destination | reason | reviewer | review_date | status |
| --- | --- | --- | --- | --- | --- | --- |
| PACKAGE_LICENSE_UNFINALIZED | R/sparseSolver.R::sparse_solve_model | DESCRIPTION License; public release metadata | DEPENDENCY_COMPATIBILITY_AUDIT_PENDING | David Zenz | 2026-08-25 | blocking |
| GIT_IDENTITY_ALIAS_UNRESOLVED | R/GEModel.R::GEModel$solveModel | DESCRIPTION; CONTRIBUTORS.md; NEWS.md; inst/CITATION | ATTRIBUTION_IDENTITY_UNRESOLVED | David Zenz | 2026-08-25 | blocking |

`mivanicERS` appears in Git-derived contributor evidence, but no reviewed public
record establishes it as a separate person or package role. It is therefore not
published as a person and is not silently merged with Maros Ivanic. The package
license likewise remains unresolved until the dependency compatibility audit;
the provisional Apache-2.0 basis for original GEModelR code is not a finalized
`DESCRIPTION` license.

## Destination contract

Every public destination must retain the reviewed names, roles, evidence keys,
and scope above:

- `DESCRIPTION` carries only reviewed `Authors@R` roles and keeps the package
  name `tabloToR` and unresolved license unchanged in this plan.
- `README.md` identifies the upstream repository and audited commit, states the
  current redistribution boundary, and links this contract and `RIGHTS.md`.
- `inst/CITATION` derives common package fields from `DESCRIPTION` and records
  the predecessor and provenance references without inventing missing facts.
- `docs/provenance/PROVENANCE.csv`, `CONTRIBUTORS.md`, and `NEWS.md` retain the
  stable evidence keys used for upstream and current-work credit.

A missing or unknown key is `ATTRIBUTION_EVIDENCE_MISSING`; a role without a
reviewed assignment is `ATTRIBUTION_ROLE_UNREVIEWED`; destination drift is
`ATTRIBUTION_DESTINATION_MISMATCH`.

## Result

Maros Ivanic is credited accurately for the upstream `tabloToR` baseline even
though the accepted public-domain/CC0 basis does not require attribution. David
Zenz is credited for reviewed post-baseline work and as the approved maintainer.
These facts support attribution, not package renaming, final license selection,
repository reservation, or publication.

## Privacy boundary

Only reviewed public repository paths, symbols, commits, URLs, names, and
governance facts are used. Private correspondence, credentials, proprietary
model inputs, unapproved contacts, and full solver results are excluded.
