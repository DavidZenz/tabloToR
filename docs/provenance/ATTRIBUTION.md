# Attribution contract

## Configuration

Attribution-Schema-Version: 1
Inventory-Path: docs/provenance/PROVENANCE.csv
Inventory-Row-Count: 347
Inventory-Snapshot-MD5: e4de5022276057924e4892c833f240a1
Inventory-Review-Path: docs/provenance/INVENTORY-REVIEW.csv
Inventory-Review-MD5: 10c6eaa53add45966cc8dbfb74140703
Upstream-Repository: https://github.com/mivanic/tabloToR
Upstream-Commit: 7e063c65a19713857ed13023f8b77dad45b15c90
Reviewer: David Zenz
Review-Date: 2026-09-09

The inventory snapshot binds these role decisions to the reviewed Phase 01 ledger,
the accepted Phase 02 expansion, and the reviewed 291-to-324 current-source transition in INVENTORY-REVIEW.csv. The MD5
values are deterministic change detectors, not proof of authorship or ownership.
A changed inventory requires a fresh attribution review.

## Reviewed role assignments

| person/entity | role | evidence_keys | rights_basis | destination | reviewer | review_date | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| David Zenz | aut | R/sparseCompiler.R::sparse_compile_spec; R/sparseSolver.R::sparse_solve_model; src/sparse-schur.cpp::GEModelR_schur_accumulate_global | Reviewed independent post-baseline authorship; package license GPL-3.0-or-later with completed dependency compatibility audit | DESCRIPTION; CONTRIBUTORS.md; NEWS.md; inst/CITATION | David Zenz | 2026-08-25 | reviewed |
| David Zenz | cph | R/sparseCompiler.R::sparse_compile_spec; R/sparseSolver.R::sparse_solve_model; src/sparse-schur.cpp::GEModelR_schur_accumulate_global | Reviewed copyright holder for the cited independent post-baseline expression; dependency compatibility audit completed separately | DESCRIPTION; CONTRIBUTORS.md; inst/CITATION | David Zenz | 2026-08-25 | reviewed |
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

There are no remaining blocking attribution facts. On 2026-10-27 the maintainer
confirmed that Git author `mivanicERS` and GitHub account `MarosIvanic-USDA`
identify Maros Ivanic. GitHub maps upstream commit
[`78d3fc16759aa3102d566aa2bae68178498a2113`](https://github.com/mivanic/tabloToR/commit/78d3fc16759aa3102d566aa2bae68178498a2113)
to account ID `67010332`. This is an explicit reviewed alias disposition, not a
new person or an additional package role. Existing Maros Ivanic authorship is
retained and aliases are normalized only in current credit fields. Raw Git
history and earlier inventory-review rows remain unchanged.

The package license remains GPL-3.0-or-later. The runtime/native dependency audit
is recorded in `inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md`. Earlier source
ledger license labels remain in historical review rows; current ledger bases
reflect the maintainer-selected package license and accepted upstream CC0 scope.

## Destination contract

Every public destination must retain the reviewed names, roles, evidence keys,
and scope above:

- `DESCRIPTION` carries only reviewed `Authors@R` roles, uses the approved
  successor name `GEModelR`, and records the selected GPL-3.0-or-later license.
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
These facts support attribution. The selected GPL-3.0-or-later package license
is recorded separately; repository reservation and publication need their own authority.

## Privacy boundary

Only reviewed public repository paths, symbols, commits, URLs, names, and
governance facts are used. Private correspondence, credentials, proprietary
model inputs, unapproved contacts, and full solver results are excluded.

## Current-source technical review

The 2026-10-27 maintainer-requested automated review binds the 347-entry current
ledger and its 23 added symbols, 28 changed expression hashes, and license/alias
dispositions. `INVENTORY-REVIEW.csv` appends an explicit 324-to-347 transition and
retains every earlier transition. Source changes retain their reviewed lineage;
the changed inherited sumToMap expression is now correctly inherited-modified.
New technical row reviews identify Codex as reviewer; they do not impersonate a
new human review. The original maintainer role decisions above remain intact.
This evidence does not authorize a push, tag, hosted release or deployment.
