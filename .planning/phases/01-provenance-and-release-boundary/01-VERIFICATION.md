---
phase: 01-provenance-and-release-boundary
verified: 2026-08-25T13:13:40Z
status: gaps_found
score: 13/22 must-haves verified
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  automated_honored: 17
  total: 17
  independently_not_honored:
    - D-03
gaps:
  - truth: "Release-readiness evaluation is fail-closed and the integrated checker validates the complete evidence graph before reporting eligibility."
    status: failed
    reason: "Independent temporary-root checks reached release_ready=TRUE with a missing integration marker, no package source tree, no README/CITATION/CONTRIBUTORS/NEWS destinations, and an invalid license string."
    artifacts:
      - path: "tools/check_release_gates.R"
        issue: "Unsupported or absent Integrated-Evidence-Version falls back to a legacy eligible result; provenance is compared only to mutable CSV evidence; attribution destinations are not read; any non-placeholder license is accepted."
      - path: "tests/testthat/test-release-gates.R"
        issue: "The synthetic-ready fixture omits source and destination artifacts and asserts that hollow state as success."
    missing:
      - "Fail closed unless Integrated-Evidence-Version has exactly one supported value."
      - "Re-extract and validate the actual source tree during integrated evaluation."
      - "Require and validate every attribution destination in production gate code."
      - "Bind DESCRIPTION License to reviewed dependency/license evidence and validate the expression."
      - "Add negative tests for each bypass."
  - truth: "The GEModelR name check is authoritative across complete current and historical CRAN, Bioconductor, R-universe, and GitHub results."
    status: failed
    reason: "The checker ignores pagination/result-count completeness and checks only Bioconductor's software repository. A GitHub payload declaring 101 results but returning one non-match was accepted as collision-free."
    artifacts:
      - path: "tools/check_name_availability.R"
        issue: "GitHub/R-universe parsers do not prove exhaustive results; Bioconductor collection omits annotation, experiment, workflow, and other package repositories."
      - path: "docs/release/NAME-CHECK.md"
        issue: "The signed no-collision conclusion was produced by the incomplete source/query contract."
    missing:
      - "Exhaustive pagination/count validation for bounded result APIs."
      - "Complete current and historical Bioconductor repository coverage."
      - "Negative tests for truncated and semantically empty responses."
  - truth: "Provenance hashes and validation bind reviewed rows to all behavior-relevant current source expression."
    status: failed
    reason: "Native expression hashes erase string/character literals and preprocessor directives. Independent fixtures changing allow to deny and #define MODE 1 to MODE 2 produced identical hashes."
    artifacts:
      - path: "tools/provenance_inventory.R"
        issue: "provenance_mask_native() is reused for hashing, so behavior-relevant tokens are discarded."
      - path: "tests/testthat/test-provenance-inventory.R"
        issue: "No regression test requires literal or preprocessor changes to alter the expression hash."
    missing:
      - "Use masking only for structural parsing and a semantics-preserving normalizer for hashing."
      - "Add string, character, and preprocessor hash-change tests."
  - truth: "The clean-room alternative is independently enforceable and complete replacement evidence, not self-declared Markdown."
    status: failed
    reason: "A clean-room fixture with no replacement source and a nonexistent behavior-test reference returned release_ready=TRUE."
    artifacts:
      - path: "tools/check_release_gates.R"
        issue: "The clean-room evaluator trusts non-empty public:/redistributable: strings and behavior_test_status: pass without resolving files, hashes, implementation, fixtures, or independently generated results."
      - path: "tests/testthat/test-release-gates.R"
        issue: "The built-in positive clean-room fixture proves readiness using nonexistent implementation and test evidence."
    missing:
      - "Require hash-bound replacement source, fixtures, test paths, and independent result evidence under the evaluated root."
      - "Fail with CLEANROOM_EVIDENCE_INCOMPLETE when any referenced evidence is missing or unverifiable."
  - truth: "Plan 01-02 and Plan 01-03 execute concurrently in Wave 2 as required by D-03."
    status: failed
    reason: "Git commit chronology shows Plan 01-03 started after Plan 01-02 completed: e3b7267 at 12:19:30+02:00 precedes Plan 01-03 RED cebcb5a at 12:34:13+02:00."
    artifacts:
      - path: ".planning/phases/01-provenance-and-release-boundary/01-CONTEXT.md"
        issue: "D-03 requires parallel audit work, but repository history shows sequential execution."
    missing:
      - "An explicit accepted override acknowledging that the historical concurrency decision was not followed and explaining why the resulting evidence remains acceptable."
  - truth: "Superseded Phase 1 must-haves have explicit accepted verification overrides."
    status: failed
    reason: "The canonical rights state changed from blocked to cleared and the mandatory request-posting checkpoint was replaced by an existing public response, but no VERIFICATION.md override exists for either intentional deviation."
    artifacts:
      - path: "docs/provenance/RIGHTS.md"
        issue: "Rights-Status is cleared, contradicting Plan 01-01's required Rights-Status: blocked marker."
      - path: "docs/provenance/UPSTREAM-REQUEST.md"
        issue: "The request is superseded/do-not-post, contradicting Plan 01-02's only-completion-path must-have."
    missing:
      - "Maintainer-accepted overrides for the superseded blocked-rights marker and request-posting checkpoint, or revised governing plans/decisions that remove those must-haves."
---

# Phase 1: Provenance and Release Boundary Verification Report

**Phase Goal:** Establish an unambiguous legal and organizational basis for GEModelR and define what may be publicly released.
**Verified:** 2026-08-25T13:13:40Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

The legal/governance records are substantive and the checked-in repository currently reports the intended blocked state. The phase goal is nevertheless not achieved because the mechanism defining what may be publicly released can be driven to a false-ready result, and the name evidence is not authoritative over its claimed source scope. The critical findings in `01-REVIEW.md` therefore prevent phase completion; they were independently reproduced rather than accepted from the review narrative.

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Maintainers can point to written permission/license evidence covering inherited source, or an approved alternative. | ✓ VERIFIED | `UPSTREAM-RESPONSE.md` binds the upstream owner statement to repository/commit/scope; `RIGHTS.md` records the reviewed public-domain/CC0 decision. |
| 2 | A reviewed inventory maps inherited and new code to contributors and copyright holders. | ✓ VERIFIED | `PROVENANCE.csv` has 250 unique keys: 27 inherited-identical, 13 inherited-modified, 208 new-independent, and 2 generated; required contributor/holder/license/reviewer fields are populated and the standalone source check passes. |
| 3 | An authoritative check reports no current or historical CRAN/Bioconductor collision for GEModelR. | ✗ FAILED | The checker accepts truncated GitHub results and queries only Bioconductor `bioc/src/contrib/PACKAGES`; the signed report cannot support the claimed exhaustive conclusion. |
| 4 | Canonical maintainer, repository, issue tracker, package-license, citation, and attribution decisions are recorded. | ✓ VERIFIED | `GOVERNANCE.md`, `REPOSITORY.md`, `DESCRIPTION`, `ATTRIBUTION.md`, and `inst/CITATION` contain exact approved identity values and explicitly record the unresolved package-license blocker. |
| 5 | The checked-in repository is valid only as the Plan 01-01 blocked private-development state. | ✗ FAILED | The repository is currently release-blocked, but `RIGHTS.md` now says `Rights-Status: cleared`; the Plan 01-01 artifact contract was superseded without an accepted override. |
| 6 | `--assert-blocked` distinguishes the canonical intentional blocker set from readiness and ordinary parser failure. | ✓ VERIFIED | Canonical command exits 0 with exactly `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED`; `--offline` exits 1 with the same reasons. |
| 7 | Release readiness is fail-closed and a complete synthetic eligible fixture proves the success path. | ✗ FAILED | Missing integration version, missing source/destinations, and invalid license fixtures all returned `eligible`, `release_ready=TRUE`. |
| 8 | The retained upstream request contains all three D-01 asks and is hash-linked to rights evidence. | ✓ VERIFIED | `UPSTREAM-REQUEST.md` contains the license, modification/redistribution, and GEModelR-name asks; the request status/hash markers are present in `RIGHTS.md`. |
| 9 | The clean-room path enforces behavior-only specification, independent implementation, and independent review using real evidence. | ✗ FAILED | Role strings are checked, but nonexistent source/test evidence is accepted as complete and release-ready. |
| 10 | Rights/clean-room work and provenance audit ran concurrently in Wave 2 per D-03. | ✗ FAILED | Commit chronology is sequential: final Plan 01-02 implementation `e3b7267` predates Plan 01-03 RED `cebcb5a`. |
| 11 | Posting the reviewed request is the only completion path unless an accepted override changes the contract. | ✗ FAILED | The request was not posted; the plan was completed through an existing public response, with no verification override. |
| 12 | Every qualifying R/native definition has a stable key and every in-scope source file is accounted for. | ✓ VERIFIED | Standalone `provenance_inventory.R --check` re-extracts the current source and reports 250 reviewed rows matching 250 expected keys. |
| 13 | The independent expected-key manifest detects missing, duplicate, extra, and re-keyed units. | ✓ VERIFIED | Exact key/cardinality checks are implemented; focused provenance tests pass 41 assertions and the checked-in oracle command passes. |
| 14 | Native expression hashes preserve behavior-relevant literal and preprocessor changes. | ✗ FAILED | Independent fixtures changing a returned string or `#define` value produced the same MD5 expression hash. |
| 15 | David Zenz is the approved sole initial maintainer/release authority and governance records contribution, CI, review, succession, and security duties. | ✓ VERIFIED | `GOVERNANCE.md` contains all named policies and exact approved markers; identity verification exits 0. |
| 16 | Contact, owner slug, canonical URL, issue tracker, security route, and reviewer identity are explicit and not inferred from Git metadata. | ✓ VERIFIED | Approved markers are present in `GOVERNANCE.md` and `REPOSITORY.md`; exact parity validation exits 0. |
| 17 | Private development remains active while reservation, mutation/settings, and publication remain separately gated. | ✓ VERIFIED | Four external-action markers remain `not-authorized`; the repository runbook requires fresh checks and human authorization. |
| 18 | Evidence-backed upstream attribution and contributor credit appear in every required destination. | ✓ VERIFIED | DESCRIPTION, README, CITATION, PROVENANCE, CONTRIBUTORS, and NEWS contain the reviewed people/keys; attribution tests pass 43 assertions. |
| 19 | Attribution roles and destination content resolve to stable reviewed keys without inventing unresolved facts. | ✓ VERIFIED | Attribution snapshot/hash/key tests pass; the unresolved Git alias and package license remain explicit blockers. |
| 20 | The integrated checker strictly parses and cross-links every Phase 1 evidence stream. | ✗ FAILED | Integration can be bypassed by removing its version marker; source and public attribution destinations are not part of the production validation graph. |
| 21 | Positive and negative fixtures prove every parser and only complete synthetic evidence can become ready. | ✗ FAILED | All focused tests pass, but key negative cases are absent and the positive integrated fixture encodes missing source/destinations as success. |
| 22 | Approved contact/URL/issues are applied to DESCRIPTION without renaming the package or inventing a license. | ✓ VERIFIED | DESCRIPTION remains `Package: tabloToR`, has the approved Maintainer/URL/BugReports, and retains the explicit unresolved License placeholder. |

**Score:** 13/22 truths verified (0 present, behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `docs/provenance/RIGHTS.md` | Canonical rights status/evidence | ⚠️ CONTRACT DRIFT | Substantive and cross-linked, but final `cleared` status contradicts Plan 01-01's required blocked marker without an override. |
| `docs/release/RELEASE-GATES.md` | Human-readable executable boundary | ⚠️ PARTIAL | Documents strict predicates that production code does not enforce. |
| `tools/check_release_gates.R` | Fail-closed integrated release decision | ✗ FAILED | Substantive and invoked, but independently reproduced false-ready paths defeat its purpose. |
| `tests/testthat/test-release-gates.R` | Exact positive/negative contracts | ⚠️ INSUFFICIENT | 196 assertions pass; missing bypass tests and a hollow positive fixture make the evidence misleading. |
| `docs/provenance/UPSTREAM-REQUEST.md` | Hashable reviewed request | ✓ VERIFIED | Contains all D-01 asks and explicit superseded/do-not-post status. |
| `docs/provenance/CLEANROOM.md` | Clean-room process contract | ✓ VERIFIED | Substantive role/input/attestation protocol; production enforcement remains incomplete. |
| `specs/cleanroom/README.md` | Behavior-only component schema | ✓ VERIFIED | Substantive required-field and forbidden-input template. |
| `tools/provenance_inventory.R` | Source extraction and ledger validation | ⚠️ PARTIAL | Current key coverage passes, but native hashing discards behavior-relevant tokens and review status/date parsing is permissive. |
| `docs/provenance/EXPECTED-KEYS.csv` | Independent coverage oracle | ✓ VERIFIED | 250 unique path/symbol keys; read-only to the production utility. |
| `docs/provenance/PROVENANCE.csv` | Reviewed source ledger | ⚠️ PARTIAL | Complete 250-row schema, but native expression hashes are not semantics-preserving. |
| `tools/check_name_availability.R` | Exhaustive exact-name checker | ✗ FAILED | Substantive and runnable, but source coverage and completeness checks are incomplete. |
| `docs/release/NAME-CHECK.md` | Signed point-in-time name evidence | ✗ FAILED | Signed and well-formed, but generated from a non-authoritative query contract. |
| `GOVERNANCE.md` | Maintainer/governance authority | ✓ VERIFIED | Exact approved identity, contribution, CI, review, succession, and security policies. |
| `docs/release/REPOSITORY.md` | Canonical identity/private boundary | ✓ VERIFIED | Exact approved target identity and four separate not-authorized external gates. |
| `docs/provenance/ATTRIBUTION.md` | Evidence-to-role/destination contract | ✓ VERIFIED | Fixed schema, snapshot binding, reviewed roles, explicit blockers. |
| `tests/testthat/test-attribution-contract.R` | Destination parity tests | ✓ VERIFIED | 43 active assertions pass; no skips in the source repository. |
| `CONTRIBUTORS.md` | Evidence-linked contributor record | ✓ VERIFIED | Reviewed people, roles, keys, and unresolved alias are explicit. |
| `inst/CITATION` | Metadata-derived citation | ✓ VERIFIED | Uses DESCRIPTION metadata and records predecessor/provenance references. |
| `DESCRIPTION` | Approved package identity fields | ✓ VERIFIED | Maintainer, URL, BugReports, and reviewed Authors@R match approved records; package/license remain intentionally unresolved for release. |

**Artifacts:** 11/19 fully verified; 8 are failed or incomplete for their claimed contract.

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| release checker | RIGHTS | strict marker parsing | ✗ NOT WIRED FAIL-CLOSED | Missing/unknown integration version returns the legacy result instead of a parse failure. |
| release checker | RELEASE-GATES | blocker parity | ⚠️ PARTIAL | Canonical parity works; unsupported integration state bypasses it. |
| UPSTREAM-REQUEST | RIGHTS | status/hash linkage | ✓ WIRED | Request metadata and hash are recorded. |
| CLEANROOM | clean-room specs | provenance/role contract | ⚠️ PARTIAL | Markdown fields link, but referenced implementation/tests/fixtures are not resolved. |
| EXPECTED-KEYS | PROVENANCE | exact set/cardinality check | ✓ WIRED | Standalone source check passes despite the generic key-link grep false negative. |
| name checker | NAME-CHECK | report generation/verification | ⚠️ PARTIAL | Report is generated and signed, but source completeness is not enforced. |
| REPOSITORY | GOVERNANCE | approved identity parity | ✓ WIRED | Exact marker verification exits 0. |
| ATTRIBUTION | PROVENANCE | snapshot and evidence keys | ✓ WIRED | Snapshot/hash/key checks pass. |
| DESCRIPTION | ATTRIBUTION | reviewed roles | ⚠️ PARTIAL | Test-only parity exists; production release gate does not validate role parity. |
| CITATION | DESCRIPTION | `meta[[...]]` fields | ✓ WIRED | Citation derives common package fields. |
| README | RIGHTS | release/provenance notice | ✓ WIRED | Current blocked notice and evidence links are present. |
| release checker | PROVENANCE | integrated validation | ⚠️ HOLLOW | Compares two mutable CSVs but does not re-extract current source. |
| release checker | NAME-CHECK | source rows/signature/freshness | ⚠️ PARTIAL | Integrated parser omits strict timestamp/hash/query validation. |
| release checker | GOVERNANCE | approved identity/security | ✓ WIRED | Exact canonical values are checked. |
| release checker | REPOSITORY | URL/issues/private boundary | ✓ WIRED | Exact canonical values and authorization markers are checked. |
| DESCRIPTION | REPOSITORY | URL/BugReports parity | ✓ WIRED | Production checker compares exact values. |

**Wiring:** 9/16 fully verified; 7 critical links are partial, hollow, or fail-open.

## Data-Flow Trace (Level 4)

| Artifact | Data/evidence variable | Source | Produces trustworthy data | Status |
| --- | --- | --- | --- | --- |
| Integrated release decision | provenance rows/hashes | EXPECTED-KEYS + PROVENANCE only | No — current source is absent from the integrated path | ✗ DISCONNECTED |
| Integrated release decision | attribution destination parity | ATTRIBUTION tables only | No — README/CITATION/CONTRIBUTORS/NEWS are not opened | ✗ DISCONNECTED |
| Name report | registry/repository candidates | bounded public responses | No — result completeness and full Bioconductor scope are not established | ⚠️ PARTIAL |
| Clean-room decision | implementation/test/fixture evidence | self-declared spec strings | No — referenced files/results need not exist | ⚠️ STATIC/SELF-DECLARED |
| Canonical blocked result | rights/governance/repository markers | checked-in reviewed documents | Yes for the current exact root | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused release contracts | `test_file(test-release-gates.R)` | 196 pass, 0 fail/skip | ✓ PASS, insufficient scope |
| Focused provenance contracts | `test_file(test-provenance-inventory.R)` | 41 pass, 0 fail/skip | ✓ PASS, missing semantic-token cases |
| Focused name contracts | `test_file(test-name-availability.R)` | 46 pass, 0 fail/skip | ✓ PASS, missing truncation/full-scope cases |
| Focused attribution contracts | `test_file(test-attribution-contract.R)` | 43 pass, 0 fail/skip | ✓ PASS |
| Canonical blocked state | `Rscript tools/check_release_gates.R --assert-blocked` | blocked, exact two reasons, nine parser statuses pass, exit 0 | ✓ PASS |
| Canonical release-readiness | `Rscript tools/check_release_gates.R --offline` | blocked, same two reasons, exit 1 | ✓ PASS |
| Standalone current-source inventory | `Rscript tools/provenance_inventory.R --check --expected ...` | 250 reviewed rows = 250 expected keys, exit 0 | ✓ PASS |
| Missing integration marker must fail closed | independent temporary-root fixture | `eligible`, `release_ready=TRUE` | ✗ FAIL |
| Missing source/destinations must fail closed | independent temporary-root fixture | no `R/`; all four destinations absent; still ready | ✗ FAIL |
| Invalid license must fail closed | independent temporary-root fixture | `definitely-not-a-valid-license` accepted as ready | ✗ FAIL |
| Native behavior change must alter hash | independent C++ fixtures | literal and preprocessor changes produced identical hashes | ✗ FAIL |
| Truncated GitHub result must be rejected | `total_count=101`, one non-match returned | source row `pass`, overall no collision | ✗ FAIL |
| Clean-room evidence must resolve real files | fixture with nonexistent source/test | `eligible`, `release_ready=TRUE` | ✗ FAIL |

`R CMD check .` was not rerun during this goal-focused verification: the phase deliverables are governance/checker artifacts, the four directly linked focused suites and CLIs were exercised, and package compilation does not resolve the observed release-integrity failures.

## Probe Execution

No phase probe scripts were declared or discovered. Step 7c is not applicable.

## Requirements Coverage

Every requirement ID declared in PLAN frontmatter appears in `.planning/REQUIREMENTS.md`, and every Phase 1 requirement is claimed by at least one plan. There are no orphaned Phase 1 requirement IDs.

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PROV-01 | 01-01, 01-02, 01-06 | Documented legal basis for inherited-source modification and redistribution | ✓ SATISFIED | Reviewed public-domain/CC0 response is bound to upstream repository, commit, scope, and reviewer; current source inventory is complete. The broader release boundary still fails separate must-haves. |
| PROV-02 | 01-03, 01-05, 01-06 | Accurate authorship/provenance and attribution records | ✓ SATISFIED | 250 reviewed rows and six public destinations are populated and direct attribution tests pass. Native hash and integrated-enforcement defects remain phase blockers. |
| PROV-03 | 01-04, 01-06 | Current/historical name collision check before reservation/release | ✗ BLOCKED | The checker does not establish exhaustive GitHub/R-universe results or complete Bioconductor package-repository coverage. |
| PROV-04 | 01-04, 01-06 | Named maintainer, contact, canonical URL, and issue tracker | ✓ SATISFIED | Approved exact values are recorded in governance/repository/package metadata and machine parity checks pass. |

**Coverage:** 3/4 requirements satisfied; all 4 IDs accounted for.

## Decision Coverage

The automated fuzzy decision-coverage gate reported: “All trackable CONTEXT.md decisions are honored by shipped artifacts” (17/17). Independent chronology contradicts that heuristic for D-03: Plan 01-03 began only after Plan 01-02's final implementation commit. This is non-blocking under the decision gate itself, but it is a failed PLAN must-have and requires an explicit disposition.

## Test Quality Audit

| Test File | Linked Req | Active assertions | Skipped | Circular | Strongest level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `test-release-gates.R` | PROV-01..04 | 196 | 0 | No | Behavioral | ✗ INSUFFICIENT — positive fixture affirms hollow source/destination evidence; critical bypass negatives absent. |
| `test-provenance-inventory.R` | PROV-02 | 41 | 0 | No | Value/behavioral | ⚠️ INSUFFICIENT — no literal/preprocessor hash-change assertions. |
| `test-name-availability.R` | PROV-03/04 | 46 | 0 | No | Value/behavioral | ⚠️ INSUFFICIENT — no pagination/count-completeness or complete Bioconductor-scope assertions. |
| `test-attribution-contract.R` | PROV-02/04 | 43 | 0 | No | Behavioral | ✓ ADEQUATE for direct destination parity; production release wiring remains incomplete. |

**Disabled tests on requirements:** 0. **Circular patterns:** 0. **Insufficient suites:** 3.

## Review Findings Independently Assessed

All eight critical findings in `01-REVIEW.md` are confirmed by code inspection; CR-01, CR-02/CR-04, CR-03, CR-05, CR-06, and CR-08 were also reproduced with isolated commands. CR-07 is directly visible in the fixed URLs: only Bioconductor's `bioc` software manifests are collected. These findings prevent the phase goal because they allow an invalid public-release decision and invalidate the claimed authoritative name check.

The five review warnings are also supported:

- third-party rows are accepted by the standalone ledger validator but rejected by the integrated classification list;
- integrated name parsing does not validate timestamp semantics, raw MD5 syntax, or exact query identity;
- standalone review statuses/dates accept arbitrary non-empty strings;
- the synthetic-ready test encodes missing source/destinations as success; and
- README's installation command installs the upstream repository while the surrounding documentation describes this implementation. The installation-documentation issue clearly belongs to Phase 3's installation/migration criterion and is not counted as a Phase 1 blocker.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `tools/check_release_gates.R` | 1027-1035 | fail-open integration-version fallback | 🛑 BLOCKER | Integrated evidence can be bypassed. |
| `tools/check_release_gates.R` | 705-849 | mutable-document-only provenance/attribution validation | 🛑 BLOCKER | Missing source and destinations can become ready. |
| `tools/check_release_gates.R` | 1151-1165 | non-placeholder license accepted | 🛑 BLOCKER | Invalid license text can authorize readiness. |
| `tools/provenance_inventory.R` | 183-233, 307-317 | semantics-erasing hash normalization | 🛑 BLOCKER | Behavior changes can retain reviewed hashes. |
| `tools/check_name_availability.R` | 122-149, 590-660 | incomplete result/source coverage | 🛑 BLOCKER | Exact name collisions can be missed. |
| `tools/check_release_gates.R` | 108-193 | self-declared clean-room evidence | 🛑 BLOCKER | No implementation/test is needed for readiness. |
| `tests/testthat/test-release-gates.R` | 786-869 | hollow positive fixture | ⚠️ WARNING | Passing suite confirms the bypass rather than preventing it. |
| `README.md` | 37-42 | installs upstream code | ⚠️ WARNING | Users receive different code than documented. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in phase-modified files. The DESCRIPTION license placeholder is explicit canonical blocker evidence, not an untracked debt marker.

## Human Verification Required

None — this is a governance/tooling foundation phase with no user-facing flow, and every blocking issue above is deterministically observable. Legal and identity judgments already carry the named maintainer's recorded approval; verification does not substitute a new legal opinion.

## Gaps Summary

### Critical Gaps

1. **Integrated release decision is fail-open.** Fix version handling, bind the current source tree, validate public attribution destinations, and bind/validate the selected license. Add fail-first negative tests for each route.
2. **Name evidence is not authoritative.** Make every bounded API exhaustive and include all relevant current/historical Bioconductor repositories before signing a fresh report.
3. **Native provenance hashes are not behavior-sensitive.** Separate structural masking from semantics-preserving hash normalization and re-review affected native rows.
4. **Clean-room readiness is hollow.** Require real hash-bound replacement source, redistributable fixtures, runnable tests, and independently produced results.
5. **Historical/intentional plan deviations are unaccepted in verification metadata.** D-03 was not followed, and the blocked-rights/request-posting contracts were superseded. Record explicit maintainer overrides or revise the governing contracts before re-verification.

### Override Suggestions for Intentional Deviations

The rights-status and request-posting deviations appear intentional and may be accepted without reverting the current evidence model. Add maintainer-approved `overrides:` entries to this report's frontmatter for the exact affected must-haves, with specific reasons and ISO timestamps. D-03 also needs an explicit acceptance decision because concurrency cannot be repaired retroactively. No override is appropriate for the release, provenance, clean-room, or name-check implementation defects.

## Recommended Fix Plans

### 01-07-PLAN.md: Fail-Closed Integrated Release Evidence

1. Reject missing/duplicate/unsupported integration versions and bind integrated provenance to freshly extracted current source.
2. Move attribution-destination and reviewed-license validation into production release-gate code.
3. Replace the hollow ready fixture with a complete minimal source/evidence tree and add independent negative cases.

### 01-08-PLAN.md: Name, Provenance, and Clean-Room Evidence Hardening

1. Implement exhaustive result handling and complete Bioconductor repository coverage; regenerate and review name evidence.
2. Preserve literals/preprocessor tokens in native hashes and re-review changed rows.
3. Require resolvable hash-bound clean-room implementation, fixture, test, and independent-result artifacts.

### Maintainer Decision

Accept or reject explicit overrides for the superseded rights/request contracts and D-03 sequencing. This is an Escalation Gate decision; it cannot be inferred from SUMMARY.md claims.

---

_Verified: 2026-08-25T13:13:40Z_
_Verifier: the agent (gsd-verifier)_
