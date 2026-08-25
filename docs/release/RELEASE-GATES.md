# Release Gates

## Canonical release boundary

Rights-Gate-Status: cleared
Intentional-Blockers: PROVENANCE_COVERAGE_INCOMPLETE

The executable source of truth is `tools/check_release_gates.R`. The audited
upstream baseline has an accepted public-domain/CC0 basis, but repository
release readiness remains blocked until the provenance inventory proves a
rights basis for every distributable component. Missing, duplicate, unknown,
contradictory, or partial evidence fails closed.

| Gate | Evidence | Passing predicate | Offline | Review | Blocking result |
| --- | --- | --- | --- | --- | --- |
| Rights status | `docs/provenance/RIGHTS.md` | Exactly one allowed status with every canonical identity field | Yes | Required for clearance | `RIGHTS_STATUS_CARDINALITY` or an evidence-specific reason |
| Policy parity | This file and `RIGHTS.md` | `Rights-Gate-Status` equals `Rights-Status` | Yes | N/A | `RIGHTS_RELEASE_STATUS_MISMATCH` |
| Public-domain response integrity | `UPSTREAM-RESPONSE.md` and `RIGHTS.md` | Exact repository, commit, public URL, response metadata, statement, and whole-document hash agree | Yes | Required | `PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE` or `PUBLIC_DOMAIN_EVIDENCE_HASH_MISMATCH` |
| Public-domain response scope | `RIGHTS.md` | Coverage is limited to upstream-authored inherited source at the audited commit and explicitly excludes unrelated third-party components | Yes | Required | `RIGHTS_SCOPE_INCOMPLETE` |
| Provenance coverage | `RIGHTS.md`, then the Plan 01-03 inventory | Every distributable component has a reviewed rights basis; pending, missing, unknown, or contradictory coverage fails | Yes | Required | `PROVENANCE_COVERAGE_INCOMPLETE` |
| Written grant alternative | `RIGHTS.md` | A resolved public request, exact inherited scope, evidence hash, reviewer, and UTC review date bind a grant | Yes | Required | `RIGHTS_SCOPE_INCOMPLETE` or `RIGHTS_EVIDENCE_INCOMPLETE` |
| Clean-room eligibility | `CLEANROOM.md` and `specs/cleanroom/*.md` | Distinct roles, exact attestations, eligible inputs, and a source-unexposed implementer | Yes | Required | `CLEANROOM_IMPLEMENTER_INELIGIBLE` or `CLEANROOM_EVIDENCE_INCOMPLETE` |
| Clean-room coverage | Inherited keys and component specifications | Every inherited key has exactly one passing `new-independent` record and approved review | Yes | Required | `CLEANROOM_EVIDENCE_INCOMPLETE` or `CLEANROOM_REVIEW_INCOMPLETE` |
| Successor identity boundary | `RIGHTS.md` | GEModelR is independently selected; authoritative availability/governance remains a separate Plan 01-04 gate | Yes | Plan 01-04 | A rights response never substitutes for the name gate |
| Sensitive evidence boundary | Files under `docs/provenance/` and `docs/release/` | No credential, private-correspondence, proprietary-model, or giant-result indicator | Yes | N/A | `SENSITIVE_EVIDENCE_CLASS` |
| Intentional block | Both status files | Accepted scoped public-domain evidence is blocked only by `PROVENANCE_COVERAGE_INCOMPLETE` | Yes | N/A | Any other reason makes the assertion fail |

## Superseded request checkpoint

`docs/provenance/UPSTREAM-REQUEST.md` is retained as hash-bound historical
planning evidence and is marked `superseded-do-not-post`. It is not a release
predicate and no second upstream request is required or authorized. Silence and
ambiguous-response fixtures remain fail-closed tests for request-based evidence
paths, but they do not override the accepted public response.

## Command contracts

- `Rscript --vanilla tools/check_release_gates.R --offline` evaluates release
  readiness. It exits nonzero for this repository while provenance coverage is
  pending.
- `Rscript --vanilla tools/check_release_gates.R --assert-blocked` asserts the
  complete intentional state: public-domain evidence passes, release readiness
  is false, and the sole current blocker is
  `PROVENANCE_COVERAGE_INCOMPLETE`.
- `Rscript --vanilla tools/check_release_gates.R --root PATH ...` evaluates an
  isolated evidence root. Synthetic eligible evidence must never replace the
  checked-in scoped record.
- `Rscript --vanilla tools/check_release_gates.R --self-test` creates only
  temporary blocked, eligible public-domain, eligible written-grant, eligible
  clean-room, malformed, and sensitive roots. It exits zero only when every
  exact result is observed.

Synthetic clearance is test evidence only. A temporary eligible fixture cannot
establish component coverage for the real repository, satisfy Plan 01-04, add a
package license, authorize publication, or establish rights in unrelated
third-party components.

Diagnostics report field names and stable reason codes only. Evidence contents
are not printed.
