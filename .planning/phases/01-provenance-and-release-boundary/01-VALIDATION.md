---
phase: 1
slug: provenance-and-release-boundary
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-24
revised: 2026-08-25
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for the eleven-plan, eight-wave graph, including five gap-closure plans.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat plus standalone base-R evidence checkers |
| **Bootstrap** | Plan 01-01 creates the release-gate tracer and tests before all dependent work |
| **Quick repository assertion** | `rtk Rscript --vanilla tools/check_release_gates.R --assert-blocked` |
| **Release-readiness command** | `rtk Rscript --vanilla tools/check_release_gates.R --offline` (expected nonzero while real rights remain blocked) |
| **Synthetic eligible proof** | `rtk Rscript --vanilla tools/check_release_gates.R --self-test` |
| **Final package command** | `rtk R CMD check .` |
| **Offline latency target** | Less than 60 seconds per focused task command |

## Sampling Rate

- After each Wave 1/2 task: run that task's focused test plus `rtk Rscript --vanilla tools/check_release_gates.R --assert-blocked` once Plan 01-01 exists.

- After Wave 2: run provenance, name, and blocked-state assertions.
- After Wave 3: run attribution and provenance parity assertions.
- After Wave 4: run every focused test, both inventory/name validators, synthetic release self-test, blocked-state assertion, `rtk R CMD check .`, and `rtk git diff --check`.
- After Wave 5: run the hardened name and provenance suites, validate COVERAGE.md, and stop at both explicit maintainer review checkpoints before signatures or canonical provenance fields are applied.
- After Wave 6: run the complete integrated release-gate fixture matrix and exact real-root blocked assertion.
- After Wave 7: run the executable clean-room fixture matrix and reconfirm canonical rights/provenance evidence was not activated by synthetic fixtures.
- After Wave 8: record all historical-deviation decisions, rerun every focused checker, run `rtk R CMD check .`, and run `rtk git diff --check`. Any nonzero package check remains blocking.
- Bare release-readiness failure is never evidence: exact fields, statuses, and reason codes must be asserted by fixtures.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure behavior | Automated command | Dependency |
|---------|------|------|-------------|------------|-----------------|-------------------|------------|
| 01-01-01 | 01 | 1 | PROV-01 | T-01-001,T-01-002 | Complete real evidence is positively recognized as intentionally blocked; malformed evidence is a distinct failure | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", stop_on_failure = TRUE)'` | Creates checker/tests |
| 01-01-02 | 01 | 1 | PROV-01 | T-01-002,T-01-004 | Synthetic eligible and malformed/sensitive roots assert exact outcomes | `rtk Rscript --vanilla tools/check_release_gates.R --self-test` | 01-01-01 |
| 01-02-01 | 02 | 2 | PROV-01 | T-01-006,T-01-007 | Draft/silence/ambiguous response cannot clear rights | `rtk Rscript --vanilla tools/check_release_gates.R --assert-blocked` | 01-01 |
| 01-02-02 | 02 | 2 | PROV-01 | T-01-009,T-01-010 | Clean-room roles, eligibility, evidence, and coverage are separated | `rtk Rscript --vanilla tools/check_release_gates.R --self-test` | 01-02-01 |
| 01-02-03 | 02 | 2 | PROV-01 | T-01-008 | Confirmed exact posting is the only completion path; defer/cancel remains unresolved and URL/hash evidence is recorded | `rtk Rscript --vanilla tools/check_release_gates.R --assert-blocked` | Human action |
| 01-03-01 | 03 | 2 | PROV-02 | T-01-011,T-01-012 | Independent expected-key oracle catches extractor omissions/drift | `rtk Rscript --vanilla tools/provenance_inventory.R --check --expected docs/provenance/EXPECTED-KEYS.csv` | 01-01 |
| 01-05-01 | 05 | 3 | PROV-02 | T-01-013,T-01-015 | Roles/credits require reviewed evidence keys | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-attribution-contract.R", stop_on_failure = TRUE)'` | 01-03-01 |
| 01-05-02 | 05 | 3 | PROV-02 | T-01-014 | Every D-08/D-09 destination has direct schema/link/parity assertions | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-attribution-contract.R", stop_on_failure = TRUE)'` | 01-05-01 |
| 01-04-01 | 04 | 2 | PROV-03 | T-01-016,T-01-017 | Six-source exact-name check fails on collision/outage/malformed input | `rtk Rscript --vanilla tools/check_name_availability.R --self-test` | 01-01 |
| 01-04-02 | 04 | 2 | PROV-04 | T-01-018,T-01-019 | Unapproved identity and external action stay blocked | `rtk Rscript --vanilla tools/check_name_availability.R --verify-identity GOVERNANCE.md docs/release/REPOSITORY.md --expect unapproved` | 01-04-01 |
| 01-04-03 | 04 | 2 | PROV-03,PROV-04 | T-01-020 | Contact/slug/URLs/security/reviewer are positively human-approved | `rtk Rscript --vanilla tools/check_name_availability.R --verify-identity GOVERNANCE.md docs/release/REPOSITORY.md --expect approved` | Human verification |
| 01-06-01 | 06 | 4 | PROV-01..04 | T-01-021,T-01-022 | All evidence parsers have exact positive/negative fixtures and one integrated result | `rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", stop_on_failure = TRUE)'` | 01-02,01-04,01-05 |
| 01-06-02 | 06 | 4 | PROV-01..04 | T-01-023,T-01-024,T-01-025,T-01-026 | Approved metadata, synthetic readiness, real blocked state, and package integrity all agree | `rtk R CMD check .` | 01-06-01 |
| 01-07-01 | 07 | 6 | PROV-01,PROV-02 | T-01-038,T-01-039 | Supported integrated evidence version and freshly extracted source are mandatory before eligibility | set -e; rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", stop_on_failure = TRUE)'; rtk Rscript --vanilla tools/check_release_gates.R --assert-blocked | 01-08,01-09 |
| 01-07-02 | 07 | 6 | PROV-02,PROV-03,PROV-04 | T-01-040,T-01-041,T-01-043 | Six attribution destinations, strict name evidence, and reviewed license evidence fail closed | Full fail-fast Task 01-07-02 automated block | 01-07-01 |
| 01-07-03 | 07 | 6 | PROV-01..04 | T-01-042,T-01-044 | Complete synthetic evidence is eligible; each isolated mutation has an exact non-eligible reason | Full fail-fast Task 01-07-03 automated block | 01-07-02 |
| 01-08-01 | 08 | 5 | PROV-03,PROV-04 | T-01-027,T-01-028,T-01-030 | Bounded APIs prove complete pagination/counts and indexed sources reject malformed or empty payloads | set -e; focused name tests; name checker self-test | 01-06 |
| 01-08-02 | 08 | 5 | PROV-03,PROV-04 | T-01-028,T-01-029 | All advertised current/historical Bioconductor repositories and every COVERAGE.md INTEGRATE row are represented | Full fail-fast Task 01-08-02 block including api-coverage.verify-pre | 01-08-01 |
| 01-08-03 | 08 | 5 | PROV-03 | T-01-027,T-01-031 | Regenerated exhaustive report remains unsigned until explicit maintainer acceptance | rtk Rscript --vanilla tools/check_name_availability.R --verify-report docs/release/NAME-CHECK.md | Blocking maintainer decision |
| 01-09-01 | 09 | 5 | PROV-02 | T-01-033,T-01-035,T-01-036 | Native literals/directives affect hashes and malformed review evidence fails closed | rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-provenance-inventory.R", stop_on_failure = TRUE)' | 01-06 |
| 01-09-02 | 09 | 5 | PROV-02 | T-01-033,T-01-034 | Complete old/new hash proposal is deterministic, unsigned, and leaves canonical evidence unchanged | Full fail-fast Task 01-09-02 block including git diff --exit-code on canonical evidence | 01-09-01 |
| 01-09-03 | 09 | 5 | PROV-02 | T-01-034,T-01-035,T-01-036 | Canonical hashes, reviewer/date, statuses, holders, and license evidence apply only after explicit maintainer acceptance | Focused provenance tests, inventory CLI, and attribution contract test | Blocking maintainer decision |
| 01-10-01 | 10 | 7 | PROV-01,PROV-02 | T-01-045,T-01-046,T-01-050 | Root-confined real source/test/fixture/standard/result artifacts and hashes are mandatory | set -e; focused release-gate tests; release checker self-test | 01-07 |
| 01-10-02 | 10 | 7 | PROV-01,PROV-02 | T-01-046,T-01-047,T-01-048,T-01-049 | Fixed Rscript behavior test, independent result, exact coverage, and role separation are enforced | Full fail-fast Task 01-10-02 automated block | 01-10-01 |
| 01-11-01 | 11 | 8 | PROV-01,PROV-02 | T-01-052,T-01-054 | Pending record is exact while VERIFICATION remains unchanged with zero override state and no entries | Full fail-fast Task 01-11-01 block including overrides_applied: 0 and git diff --exit-code | 01-08,01-09,01-10 |
| 01-11-02 | 11 | 8 | PROV-01,PROV-02 | T-01-051,T-01-052,T-01-053,T-01-054 | Every historical deviation has an explicit outcome; rejected items remain failed; final package check is unsuppressed | set -e; override tuple/count assertion; rtk R CMD check . | Blocking maintainer decision |

*Status: Plans 01-01 through 01-06 are execution-complete; Plan 01-07 through 01-11 rows are pending gap-closure execution. There is no separate Wave 0: Plan 01-01 is the executable test/checker bootstrap and has no dependent same-wave plan.*

## Final Automated Command Set

`rtk node /home/zenz/.codex/gsd-core/bin/gsd-tools.cjs check api-coverage.verify-pre .planning/phases/01-provenance-and-release-boundary`

`rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-provenance-inventory.R", stop_on_failure = TRUE)'`

`rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-attribution-contract.R", stop_on_failure = TRUE)'`

`rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-name-availability.R", stop_on_failure = TRUE)'`

`rtk Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-release-gates.R", stop_on_failure = TRUE)'`

`rtk Rscript --vanilla tools/provenance_inventory.R --check --expected docs/provenance/EXPECTED-KEYS.csv`

`rtk Rscript --vanilla tools/check_name_availability.R --verify-report docs/release/NAME-CHECK.md`

`rtk Rscript --vanilla tools/check_release_gates.R --self-test`

`rtk Rscript --vanilla tools/check_release_gates.R --assert-blocked`


`rtk R CMD check .`

`rtk git diff --check`

## Human and External Gates

| Gate | Requirement | Blocking evidence/action |
|------|-------------|--------------------------|
| Upstream posting | PROV-01 | User posts the exact reviewed request and returns URL/UTC/hash-verifiable evidence; defer/cancel leaves the checkpoint and Phase 1 unresolved; executor never posts autonomously |
| Rights adequacy | PROV-01 | Human reviews responder authority, grant/license scope, commit/component coverage |
| Clean-room independence | PROV-01 | Human reviews source-access attestations, role separation, behavior tests, and replacement coverage |
| Name report signature | PROV-03 | Human reviews six sources, hashes, exact matches, timestamp, and point-in-time limitation |
| Native hash migration review | PROV-02 | Human reviews the complete unsigned old/new hash proposal and every proposed provenance field before canonical ledger or attribution changes |
| Historical deviation overrides | PROV-01/02 | Human accepts or rejects each of the three immutable deviations independently; zero defaults and no inferred acceptance |
| Identity approval | PROV-04 | Human approves contact, owner slug, canonical URL, issue tracker, security route, reviewer/date |
| Repository reservation | PROV-03/04 | Fresh reservation-kind name check plus separate human-action authorization; not performed in Phase 1 autonomous work |
| Visibility/detachment/branch settings | PROV-04 | Separate human-action authorization after metadata/history inventory; not performed here |
| Public release/publication | PROV-01..04 | Fresh release-kind name check, cleared rights, all gates green, and separate human authorization; prohibited in this phase |

## Threat Model

| ID | Threat | Severity | Mitigation/verification |
|----|--------|----------|-------------------------|
| T-01-001 | Unsupported rights transition | critical | Exact states and scoped evidence fixtures |
| T-01-002 | Generic failure mistaken for intentional block | high | Complete parser success plus exact blocker set |
| T-01-003 | Spoofed rights evidence | high | Repository/commit/scope/URL/hash/reviewer/date binding |
| T-01-004 | Sensitive evidence disclosure | high | Class rejection without content echo |
| T-01-005 | Package supply-chain substitution | low | No installs; existing base/recommended R and testthat |
| T-01-006 | Draft/silence treated as grant | critical | Exact request state transitions |
| T-01-007 | Spoofed upstream response | high | Public identity/evidence and reviewer checks |
| T-01-008 | Unauthorized external communication | high | Blocking human action |
| T-01-009 | False clean-room independence | high | Distinct roles, attestations, review, provenance links |
| T-01-010 | Source/private data crosses clean-room boundary | high | Admissible-input schema and sensitive-class checks |
| T-01-011 | Inventory omits/re-keys source | high | Independent expected-key oracle |
| T-01-012 | Reviewed fields lost on regeneration | high | Stable-key preservation and changed-hash review |
| T-01-013 | Git metadata grants unsupported role | high | Reviewed evidence required for each role |
| T-01-014 | Attribution destinations drift | high | Direct schema/link/parity test |
| T-01-015 | Contributor evidence leaks private data | high | Public hashes/commits only |
| T-01-016 | Spoofed name source | medium | Fixed endpoints, hashes, timestamps |
| T-01-017 | Stale/partial name report | high | Six rows, signed review, check-kind/freshness |
| T-01-018 | Unapproved contact/security disclosure | high | Blocking approval checkpoint |
| T-01-019 | Documentation triggers repository mutation | high | Not-authorized markers and future human gates |
| T-01-020 | Identity approval repudiated | medium | Exact values, reviewer, UTC date |
| T-01-021 | Evidence parser/cross-link drift | critical | Exact schema/cardinality/reason tests |
| T-01-022 | Integrated false release-ready result | critical | Fail closed and synthetic-only eligible root |
| T-01-023 | Wrong contact/URL reaches DESCRIPTION | high | Exact governance/repository parity |
| T-01-024 | Missing reviewer evidence | medium | Required reviewer/date across records |
| T-01-025 | Integrated diagnostics expose evidence | high | Reason identifiers only |
| T-01-026 | Online outage silently skipped | medium | Explicit unavailable/stale reasons and offline fixtures |
| T-01-027..032 | Partial or spoofed external name-source results and unauthorized GitHub action | high | Plan 01-08 exhaustive pagination, repository discovery, signed review, and read-only scope |
| T-01-033..037 | Native hash tampering, unreviewed provenance migration, and Git evidence overreach | high | Plan 01-09 semantics-preserving tests plus blocking maintainer acceptance before canonical changes |
| T-01-038..044 | Integrated evidence bypass, destination/license drift, and sensitive diagnostics | critical | Plan 01-07 exact version, current-source, destination, license, and complete-fixture gates |
| T-01-045..050 | Clean-room path escape, stale result, role spoofing, subprocess abuse, and disclosure | critical | Plan 01-10 root confinement, exact hashes, fixed Rscript invocation, and independent role checks |
| T-01-051..055 | Override identity spoofing, inferred acceptance, fuzzy scope, and decision-record leakage | critical | Plan 01-11 blocking exact tuple, one-to-one overrides, zero pre-checkpoint state, and no release-blocker overrides |

## Multi-Source Coverage Audit

| Source | ID | Required outcome | Plan | Status |
|--------|----|------------------|------|--------|
| GOAL | — | Unambiguous legal/organizational basis and enforceable public-release boundary | 01-01..06 | COVERED |
| REQ | PROV-01 | Documented modify/redistribute basis or explicit reviewed alternative with block | 01-01,01-02,01-06 | COVERED |
| REQ | PROV-02 | Accurate upstream/contributor/holder attribution in package/source docs | 01-03,01-05,01-06 | COVERED |
| REQ | PROV-03 | Current/historical name checks before reservation/release | 01-04,01-06 | COVERED |
| REQ | PROV-04 | Human maintainer, approved contact, canonical URL, issue tracker | 01-04,01-06 | COVERED |
| CONTEXT | D-01 | Upstream license/redistribution/name request | 01-02 | COVERED |
| CONTEXT | D-02 | Investigate full inherited-expression replacement | 01-02,01-03 | COVERED |
| CONTEXT | D-03 | Provenance/replacement audit parallel with request | 01-02 and 01-03, same Wave 2 | COVERED |
| CONTEXT | D-04 | Strict behavior-only independent clean room | 01-02 | COVERED |
| CONTEXT | D-05 | Public distribution blocked until written coverage or reviewed replacement | 01-01,01-06 | COVERED |
| CONTEXT | D-06 | Evidence-backed aut/ctb/cph/cre | 01-05 | COVERED |
| CONTEXT | D-07 | Function-level inherited/modified provenance; file-level wholly new | 01-03 | COVERED |
| CONTEXT | D-08 | Upstream attribution in all named destinations | 01-05 | COVERED |
| CONTEXT | D-09 | Authors@R/contributor record/NEWS substantive credit | 01-05 | COVERED |
| CONTEXT | D-10 | David Zenz personal GitHub ownership | 01-04 | COVERED |
| CONTEXT | D-11 | Sole v1 maintainer/release authority; PR contributions | 01-04,01-06 | COVERED |
| CONTEXT | D-12 | Protected main/passing CI/self-review policy | 01-04 | COVERED |
| CONTEXT | D-13 | Governance, succession, security responsibility | 01-04 | COVERED |
| CONTEXT | D-14 | Exact GEModelR package/repository target | 01-04 | COVERED |
| CONTEXT | D-15 | Name gate across all required sources/times | 01-04,01-06 | COVERED |
| CONTEXT | D-16 | Private development/fork constraint/standalone path | 01-04 | COVERED |
| CONTEXT | D-17 | Only upstream request public until clearance | 01-01,01-02,01-04,01-06 | COVERED |
| RESEARCH | — | RIGHTS/request/release-gate evidence system | 01-01,01-02 | COVERED |
| RESEARCH | — | Fixed-schema provenance, generated links, clean-room evidence | 01-02,01-03,01-05 | COVERED |
| RESEARCH | — | Attribution applied without unsupported roles/facts | 01-05 | COVERED |
| RESEARCH | — | Six-source name report and repeat-check policy | 01-04 | COVERED |
| RESEARCH | — | Full external name-source capability surface with reasoned opt-outs | 01-08,01-07,COVERAGE.md | COVERED |
| RESEARCH | — | Semantics-preserving native hashes require explicit reviewed migration | 01-09 | COVERED |
| RESEARCH | — | Real hash-bound executable clean-room evidence | 01-10 | COVERED |
| RESEARCH | — | Governance/private repository runbook and external gates | 01-04 | COVERED |
| RESEARCH | — | Integrated fail-closed parsers and public/private evidence boundary | 01-06 | COVERED |

## Validation Sign-Off

- [x] Eleven-plan, eight-wave map matches PLAN frontmatter; Wave 5 contains 01-08/01-09, Wave 6 contains 01-07, Wave 7 contains 01-10, and Wave 8 contains 01-11.
- [x] No contradictory Wave 0 dependency exists.
- [x] Every task has an automated command and every modified test file is in that task's `read_first`.
- [x] Checked-in blocked state has a zero-exit assertion distinct from release readiness.
- [x] Positive/negative fixtures assert exact fields, statuses, and reasons.
- [x] Threat IDs 001-026 cover the original graph; gap-closure threat registers 027-055 are mapped by plan/task above and remain unique.
- [x] Every shell command is prefixed with `rtk`.
- [x] Final Wave 8 verification executes exact command `rtk R CMD check .`; the known Linuxbrew assembler/GLIBC mismatch remains documented but any recurrence is blocking and never coerced to success.
- [x] GOAL, PROV-01..04, RESEARCH constraints, and D-01..D-17 are covered with no deferred-idea leakage.

**Approval:** revised for gap-closure checker feedback; Plans 01-07 through 01-11 and final package-check evidence remain pending execution.
