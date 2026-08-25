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

Diagnostics report field names and stable reason codes only. Evidence contents
are not printed.
