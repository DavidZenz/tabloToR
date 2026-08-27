# Release Gates

## Canonical release boundary

Rights-Gate-Status: cleared
Intentional-Blockers: DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED

The executable source of truth is `tools/check_release_gates.R`. It evaluates
the exact integrated evidence version before any legacy result, then validates
rights, accepted public-domain evidence, freshly extracted source and Git
provenance, every public attribution destination, strict name evidence, the
reviewed package-license decision, approved governance, and the canonical
repository boundary as one fail-closed decision.

The checked-in repository is intentionally blocked by exactly two reviewed
facts. The package license remains unresolved until the LinkingTo, vendored, and
native dependency compatibility audit is complete. A Git identity alias remains
unresolved and cannot be silently merged into a public attribution identity.
Neither blocker authorizes an external repository or publication action.

| Gate | Evidence | Passing predicate | Blocking result |
| --- | --- | --- | --- |
| Integrated contract | `RIGHTS.md` | Exactly one `Integrated-Evidence-Version: 1` before any base eligibility is consulted | `INTEGRATED_EVIDENCE_VERSION_INVALID` |
| Rights and policy parity | `RIGHTS.md`, this file | Cleared scoped basis, exact upstream identity, complete provenance marker, and identical intentional blockers | `RIGHTS_RELEASE_STATUS_MISMATCH` or `INTENTIONAL_BLOCKERS_MISMATCH` |
| Public-domain response | `UPSTREAM-RESPONSE.md`, `RIGHTS.md` | Exact URL, owner association, statement, scope, and whole-document hash | `PUBLIC_DOMAIN_EVIDENCE_INCOMPLETE` or `PUBLIC_DOMAIN_EVIDENCE_HASH_MISMATCH` |
| Current-source provenance | `tools/provenance_inventory.R`, `EXPECTED-KEYS.csv`, `PROVENANCE.csv`, evaluated `R/` and `src/` | Named helpers load in isolation; fresh nonempty source extraction has Git evidence; exact keys, expression hashes, classifications, review fields, and third-party bases pass the shared validator | A named `PROVENANCE_*` source, key, hash, tool, or row reason |
| Attribution contract | `ATTRIBUTION.md`, provenance inventory | Snapshot hash and row count match; roles are limited to `aut`/`ctb`/`cph`/`cre`; every role and blocker key has reviewed provenance evidence | `ATTRIBUTION_EVIDENCE_MISSING`, `ATTRIBUTION_ROLE_UNREVIEWED`, or `ATTRIBUTION_BLOCKER_INVALID` |
| Attribution destinations | `DESCRIPTION`, `README.md`, `inst/CITATION`, `PROVENANCE.csv`, `CONTRIBUTORS.md`, `NEWS.md` | All six files exist and retain the exact reviewed people, roles, and evidence-key set | `ATTRIBUTION_DESTINATION_MISSING` or `ATTRIBUTION_DESTINATION_MISMATCH` |
| Successor name | `NAME-CHECK.md`, `tools/check_name_availability.R` | The strict shared report verifier accepts version, timestamp, raw hashes, detail completeness, query identity, parent signatures, and review; release readiness additionally needs a fresh release-kind report | `NAME_TOOL_LOAD_FAILED`, `NAME_REPORT_INVALID`, or `NAME_REPORT_STALE` |
| Governance identity | `GOVERNANCE.md` | Exact approved maintainer, contact, release authority, security route, reviewer, and date | `GOVERNANCE_IDENTITY_UNAPPROVED` or `GOVERNANCE_SECURITY_ROUTE_MISSING` |
| Repository boundary | `REPOSITORY.md` | Exact owner/name/URL/issues pair, private-development boundary, and every external action remains not authorized | `REPOSITORY_URL_MISMATCH`, `REPOSITORY_ISSUES_MISMATCH`, or `REPOSITORY_BOUNDARY_INVALID` |
| Package metadata | `DESCRIPTION`, governance/repository evidence | Package name stays `tabloToR`; approved maintainer, canonical URL, and issues match | `DESCRIPTION_IDENTITY_MISMATCH`, `DESCRIPTION_URL_MISMATCH`, or `DESCRIPTION_ISSUES_MISMATCH` |
| Package license | `LICENSE-DECISION.md`, `DESCRIPTION`, reviewed dependency audit | Pending markers exactly match the unresolved field and dependency blocker; a reviewed transition has a safe under-root audit path, exact MD5, reviewer/date, exact DESCRIPTION equality, and an R-valid license expression | A named `LICENSE_*` or `DESCRIPTION_LICENSE_MISMATCH` reason |
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

The integrated regression contract constructs a complete temporary R source
tree, initializes and commits its local Git history, then derives expected keys,
expression hashes, provenance rows, attribution destinations, strict
release-kind name evidence, governance, repository, and reviewed license
evidence from that fixture. It does not import checked-in mutable ledgers.
Table-driven mutations assert the exact failing parser and reason code for every
integration boundary, while temporary roots are removed after each assertion.

A fresh release-kind name report is required before a blocker-free root can be
release-ready. Even a technically ready result does not create, reserve, change,
or publish a repository: every such action requires its separate human
authorization.

Diagnostics report stable field names and reason codes only. Evidence contents,
credentials, private correspondence, and proprietary model data are never
printed.
