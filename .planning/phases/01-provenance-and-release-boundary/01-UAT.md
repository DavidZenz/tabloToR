---
status: complete
phase: 01-provenance-and-release-boundary
source:
  - 01-01-SUMMARY.md
  - 01-02-SUMMARY.md
  - 01-03-SUMMARY.md
  - 01-04-SUMMARY.md
  - 01-05-SUMMARY.md
  - 01-06-SUMMARY.md
  - 01-07-SUMMARY.md
  - 01-08-SUMMARY.md
  - 01-09-SUMMARY.md
  - 01-10-SUMMARY.md
  - 01-11-SUMMARY.md
  - 01-VERIFICATION.md
started: 2026-08-31T00:00:00Z
updated: 2026-08-31T09:42:23.242Z
---

## Current Test

[testing complete]

## Tests

### 1. Repository remains fail-closed
expected: Canonical repository evidence resolves to blocked, release_ready=false, and RIGHTS_BLOCKED while --assert-blocked exits zero.
result: pass
source: automated
coverage_id: 01-01-D1

### 2. Synthetic release readiness
expected: Synthetic written-grant and reviewed clean-room roots prove true release readiness without changing real rights evidence.
result: pass
source: automated
coverage_id: 01-01-D2

### 3. Invalid rights evidence fails closed
expected: Malformed, contradictory, incomplete-scope, and sensitive evidence produce exact nonzero reason codes without content disclosure.
result: pass
source: automated
coverage_id: 01-01-D3

### 4. Public-domain response is scope-bound
expected: The accepted public-domain/CC0 response is hash-bound to the audited upstream repository and commit with exact source metadata and scope.
result: pass
source: automated
coverage_id: 01-02-D1

### 5. Clean-room fallback is constrained
expected: The clean-room fallback enforces distinct roles, source-access eligibility, attestations, behavior tests, and exact provenance-key coverage.
result: pass
source: automated
coverage_id: 01-02-D2

### 6. Incomplete provenance still blocks release
expected: Repository release readiness remains blocked on incomplete provenance coverage without requiring a second upstream request or claiming third-party rights.
result: pass
source: automated
coverage_id: 01-02-D3

### 7. Provenance key sets agree
expected: Independent and extracted key sets agree exactly for 250 units across 41 files.
result: pass
source: automated
coverage_id: 01-03-D1

### 8. Provenance extraction is deterministic
expected: R, reference-class, native, generated, empty-file, exclusion, source-range, hash, and Git-evidence contracts are deterministic.
result: pass
source: automated
coverage_id: 01-03-D2

### 9. Provenance review fails closed
expected: Reviewed fields survive regeneration, changed hashes require review, and uncovered or unknown rows fail closed.
result: pass
source: automated
coverage_id: 01-03-D3

### 10. Approved GEModelR name report
expected: The initial GEModelR report records all six authoritative sources, UTC time, raw hashes, zero exact collisions, and the approved reviewer signature.
result: pass

### 11. Approved repository identity
expected: Governance and repository records carry the approved contact, security route, owner slug, canonical URL, issue tracker, reviewer, and review date.
result: pass

### 12. Repository mutations remain unauthorized
expected: Reservation, visibility or detachment, branch-setting, and release or publication actions remain separately not-authorized and release readiness remains blocked.
result: pass
source: automated
coverage_id: 01-04-D3

### 13. Reviewed attribution snapshot
expected: Reviewed people, roles, evidence keys, and blockers are recorded against the immutable 250-row provenance snapshot.
result: pass
source: automated
coverage_id: 01-05-D1

### 14. Attribution destinations agree
expected: DESCRIPTION, README, CITATION, PROVENANCE, CONTRIBUTORS, and NEWS expose one consistent reviewed attribution key set.
result: pass
source: automated
coverage_id: 01-05-D2

### 15. Attribution drift fails closed
expected: Attribution drift and stale evidence fail closed while the public release boundary remains blocked.
result: pass
source: automated
coverage_id: 01-05-D3

### 16. Integrated source is current
expected: Integrated evaluation validates exact contract version and fresh Git-backed current-source provenance.
result: pass
source: automated
coverage_id: 01-07-D1

### 17. Attribution and license decisions are exact
expected: Attribution destinations and pending or reviewed license decisions are exact and fail closed.
result: pass
source: automated
coverage_id: 01-07-D2

### 18. Synthetic release graph is complete
expected: A self-contained synthetic release graph proves eligibility and exact boundary failures without changing production blockers.
result: pass
source: automated
coverage_id: 01-07-D3

### 19. Native semantic hashes are enforced
expected: Native expressions use semantics-preserving hashes and fail-closed review-field validation.
result: pass
source: automated
coverage_id: 01-09-D1

### 20. Approved native hash migration
expected: All 54 changed native hashes have a signed maintainer disposition and match current source under stable keys.
result: pass

### 21. Attribution binds final provenance
expected: ATTRIBUTION.md is rebound to the final validated 250-row provenance snapshot.
result: pass
source: automated
coverage_id: 01-09-D3

### 22. Clean-room artifacts are complete
expected: Clean-room components resolve and hash-verify five real, distinct, root-confined artifacts with exact non-vacuous coverage.
result: pass
source: automated
coverage_id: 01-10-D1

### 23. Clean-room execution is independently bound
expected: A fixed Rscript execution and independent result record prove behavior and bind clean-room evidence into new-independent integrated provenance.
result: pass
source: automated
coverage_id: 01-10-D2

### 24. Approved historical deviations
expected: All three historical deviations have explicit accepted outcomes recorded for David Zenz.
result: pass

### 25. Verification overrides are exact
expected: Exactly three canonical overrides map to the accepted historical deviations without touching implementation findings or release blockers.
result: pass
source: automated
coverage_id: 01-11-D2

### 26. Package integrity check passes
expected: The final package integrity command exits zero without suppressing environment failures.
result: pass
source: automated
coverage_id: 01-11-D3

### 27. Legal-evidence merge or touch is out of scope
expected: No automated legal-evidence merge or touch operation exists or is in scope for Phase 01; if one is introduced later, it must receive a defined fail-closed contract and deterministic enforcement test.
result: pass

## Summary

total: 27
passed: 27
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
