# Release Gates

## Canonical release boundary

Rights-Gate-Status: blocked
Intentional-Blockers: RIGHTS_BLOCKED

The executable source of truth is `tools/check_release_gates.R`. A release is
eligible only when every applicable gate parses and passes. Missing, duplicate,
unknown, contradictory, or partial evidence fails closed.

| Gate | Evidence | Passing predicate | Offline | Review | Blocking result |
| --- | --- | --- | --- | --- | --- |
| Rights status | `docs/provenance/RIGHTS.md` | Exactly one allowed status with every canonical identity field | Yes | Required for clearance | `RIGHTS_STATUS_CARDINALITY` or an evidence-specific reason |
| Policy parity | This file and `RIGHTS.md` | `Rights-Gate-Status` equals `Rights-Status` | Yes | N/A | `RIGHTS_RELEASE_STATUS_MISMATCH` |
| Written scope | `RIGHTS.md` | A cleared grant covers the exact upstream commit and all inherited source | Yes | Required | `RIGHTS_SCOPE_INCOMPLETE` |
| Written evidence | `RIGHTS.md` | A resolved public request, evidence hash, reviewer, and UTC review date bind the grant | Yes | Required | `RIGHTS_EVIDENCE_INCOMPLETE` |
| Clean-room completion | Synthetic `docs/provenance/CLEANROOM.md` during this plan; canonical protocol in Plan 01-02 | Replacement coverage is complete and independently approved | Yes | Required | `CLEANROOM_REVIEW_INCOMPLETE` |
| Sensitive evidence boundary | Files under `docs/provenance/` and `docs/release/` | No credential, private-correspondence, proprietary-model, or giant-result indicator | Yes | N/A | `SENSITIVE_EVIDENCE_CLASS` |
| Intentional block | Both files | The valid real repository is blocked only by `RIGHTS_BLOCKED` | Yes | N/A | Any other reason makes the assertion fail |

## Command contracts

- `Rscript --vanilla tools/check_release_gates.R --offline` evaluates release
  readiness. It exits nonzero for this repository while rights remain blocked.
- `Rscript --vanilla tools/check_release_gates.R --assert-blocked` asserts the
  complete, intentional private-development state. It exits zero only when all
  available evidence parses, cross-checks, and produces exactly the documented
  blocker set.
- `Rscript --vanilla tools/check_release_gates.R --root PATH ...` evaluates an
  isolated evidence root. Synthetic eligible evidence must never replace this
  checked-in blocked record.
- `Rscript --vanilla tools/check_release_gates.R --self-test` creates only
  temporary blocked, eligible written-grant, eligible clean-room, malformed,
  and sensitive roots. It exits zero only when every exact result is observed.

Synthetic clearance is test evidence only. A temporary eligible fixture cannot
change `docs/provenance/RIGHTS.md`, authorize publication, or establish that the
real repository is cleared.

Diagnostics report field names and stable reason codes only. Evidence contents
are not printed.
