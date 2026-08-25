# Release Gates

## Canonical release boundary

Rights-Gate-Status: cleared
Intentional-Blockers: DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED

The executable source of truth is `tools/check_release_gates.R`. It evaluates
rights, accepted public-domain evidence, complete symbol-level provenance,
reviewed attribution, point-in-time name evidence, approved governance, and the
canonical repository boundary as one fail-closed decision.

The checked-in repository is intentionally blocked by exactly two reviewed
facts. The package license remains unresolved until the LinkingTo, vendored, and
native dependency compatibility audit is complete. A Git identity alias remains
unresolved and cannot be silently merged into a public attribution identity.
Neither blocker authorizes an external repository or publication action.

| Gate | Evidence | Passing predicate | Blocking result |
| --- | --- | --- | --- |
| Rights and policy parity | `RIGHTS.md`, this file | Cleared scoped basis, exact upstream identity, complete provenance marker, and identical intentional blockers | `RIGHTS_RELEASE_STATUS_MISMATCH` or `INTENTIONAL_BLOCKERS_MISMATCH` |
| Public-domain response | `UPSTREAM-RESPONSE.md`, `RIGHTS.md` | Exact URL, owner association, statement, scope, and whole-document hash | `PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE` or `PUBLIC_DOMAIN_EVIDENCE_HASH_MISMATCH` |
| Provenance inventory | `EXPECTED-KEYS.csv`, `PROVENANCE.csv` | Exact 17-column schema, one reviewed row per expected symbol, no missing or duplicate keys | `PROVENANCE_COLUMNS_MISSING`, `PROVENANCE_KEY_MISMATCH`, `PROVENANCE_DUPLICATE_KEY`, or `PROVENANCE_ROW_BLOCKING` |
| Attribution contract | `ATTRIBUTION.md`, provenance inventory | Snapshot hash and row count match, roles are reviewed, evidence keys exist, and blocking facts are explicit | `ATTRIBUTION_EVIDENCE_MISSING`, `ATTRIBUTION_ROLE_UNREVIEWED`, or `ATTRIBUTION_DESTINATION_MISMATCH` |
| Successor name | `NAME-CHECK.md` | Six approved public sources are available with no exact collision; release readiness additionally needs a fresh release-kind report | `NAME_SOURCE_MISSING`, `NAME_SOURCE_UNAVAILABLE`, `NAME_EXACT_COLLISION`, `NAME_REPORT_UNSIGNED`, or `NAME_REPORT_STALE` |
| Governance identity | `GOVERNANCE.md` | Exact approved maintainer, contact, release authority, security route, reviewer, and date | `GOVERNANCE_IDENTITY_UNAPPROVED` or `GOVERNANCE_SECURITY_ROUTE_MISSING` |
| Repository boundary | `REPOSITORY.md` | Exact owner/name/URL/issues pair, private-development boundary, and every external action remains not authorized | `REPOSITORY_URL_MISMATCH`, `REPOSITORY_ISSUES_MISMATCH`, or `REPOSITORY_BOUNDARY_INVALID` |
| Package metadata | `DESCRIPTION`, governance/repository evidence | Package name stays `tabloToR`; approved maintainer, canonical URL, and issues match; unresolved License is allowed only with the dependency blocker | `DESCRIPTION_IDENTITY_MISMATCH`, `DESCRIPTION_URL_MISMATCH`, `DESCRIPTION_ISSUES_MISMATCH`, or a license reason |
| Sensitive evidence | Release and provenance evidence trees | No credential, private-correspondence, proprietary-model, or giant-result indicator | `SENSITIVE_EVIDENCE_CLASS` |

## Superseded request checkpoint

`docs/provenance/UPSTREAM-REQUEST.md` is retained as hash-bound historical
planning evidence and is marked `superseded-do-not-post`. It is not a release
predicate and no second upstream request is required or authorized. The accepted
public response is scoped to the audited upstream-authored baseline.

## Command contracts

- `Rscript --vanilla tools/check_release_gates.R --offline` evaluates the full
  local evidence graph and exits nonzero while any blocker remains.
- `Rscript --vanilla tools/check_release_gates.R --assert-blocked` exits zero
  only when the repository is blocked, every evidence parser passes, and the
  reason codes exactly equal the intentional blocker list.
- `Rscript --vanilla tools/check_release_gates.R --root PATH ...` evaluates an
  isolated evidence root. A synthetic root can prove that all predicates are
  reachable without changing the checked-in release state.
- `Rscript --vanilla tools/check_release_gates.R --self-test` checks the legacy
  rights alternatives and malformed/sensitive fixtures without network access.

A fresh release-kind name report is required before a blocker-free root can be
release-ready. Even a technically ready result does not create, reserve, change,
or publish a repository: every such action requires its separate human
authorization.

Diagnostics report stable field names and reason codes only. Evidence contents,
credentials, private correspondence, and proprietary model data are never
printed.
