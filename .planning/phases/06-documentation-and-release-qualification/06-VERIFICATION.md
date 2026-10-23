---
phase: 06-documentation-and-release-qualification
verified: 2026-10-23T09:28:14Z
status: passed
technical_verified: 2026-10-23T09:21:18Z
technical_status: gaps_found
acceptance_basis: maintainer_override
acceptance_record: 06-ACCEPTANCE.md
score: 11/18 must-haves verified
behavior_unverified: 1
overrides_applied: 7
security_review_disposition: waived_for_phase_closure
re_verification:
  previous_status: gaps_found
  previous_score: 11/14
  gaps_closed: []
  gaps_remaining:
    - "Successful exact-archive qualification under the declared Matrix floor."
    - "Matched full-scale benchmark acceptance and independent review."
    - "The live provenance mismatch."
    - "Hosted serialization and Windows provenance results."
    - "Safe preflight reports and reference-file binding."
  regressions:
    - "The scoped code review found two open benchmark-preflight blockers: raw invalid build-record values can enter the report, and the approved reference files are not bound to downstream steps."
decision_coverage:
  honored: 5
  total: 5
  not_honored: []
gaps:
  - truth: "The exact built source archive passes R CMD check without blocking warnings, errors, or unexplained significant notes."
    status: failed
    reason: "Installed Matrix is 1.6.3, below DESCRIPTION's Matrix >= 1.6-5 floor. Plan 06-22 correctly did not build or check an archive."
    artifacts:
      - path: "DESCRIPTION"
        issue: "The declared Matrix floor is 1.6-5; the current runtime does not meet it."
      - path: ".planning/phases/06-documentation-and-release-qualification/06-22-SUMMARY.md"
        issue: "Archive build, scan, and check are recorded as not run."
    missing:
      - "An exact archive built and checked under Matrix >= 1.6-5, with passing scan and check evidence."
  - truth: "A current matched full-scale R/C++ benchmark passes the unchanged gate and has an unsigned, redacted summary."
    status: failed
    reason: "All nine configured GTAP path variables are absent. Preflight was blocked before any solver, candidate, comparison, or independent review. This does not establish that user-reported artifacts do not exist elsewhere."
    artifacts:
      - path: "benchmarks/preflight_gtap12a_reference.R"
        issue: "This attempt produced no eligible reference set."
      - path: "benchmarks/GTAP12A_CPP_RESULTS.md"
        issue: "No current matched result was added."
    missing:
      - "Explicit local evidence paths, eligible preflight, C++ candidate accepted by the unchanged gate, and independent review bound to those artifacts."
  - truth: "The live release-gate assertion accepts the intentional blocked state without an unexpected provenance mismatch."
    status: failed
    reason: "The latest recorded live assertion returned repository_state=invalid with PROVENANCE_KEY_MISMATCH and a failed provenance parse. Plans 06-20 and 06-22 keep this hold open; no later passing result is recorded."
    artifacts:
      - path: "tools/check_release_gates.R"
        issue: "The current repository provenance has not passed the live assertion."
      - path: "docs/provenance/PROVENANCE.csv"
        issue: "The disputed source-key mismatch remains unresolved."
    missing:
      - "A passing live assertion after independently supported provenance evidence resolves the mismatch."
  - truth: "Both focused provenance regressions pass on the hosted Windows release/current/serial job for the authorized revision."
    status: failed
    reason: "Workflow steps are wired, but hosted dispatch was rejected under the local-only instruction. No Windows result exists; POSIX results do not satisfy this condition."
    artifacts:
      - path: ".github/workflows/native-ci.yaml"
        issue: "Manual dispatch and focused Windows steps exist, but no hosted run evidence is available."
      - path: ".planning/phases/06-documentation-and-release-qualification/06-19-SUMMARY.md"
        issue: "Both hosted test statuses are recorded as not run."
    missing:
      - "An explicitly authorized hosted Windows result for both focused cases on one recorded revision."
  - truth: "A blocked benchmark preflight never emits private or malformed build-record values in its DCF report."
    status: failed
    reason: "The validator adds a blocking reason for invalid package-version, commit, archive-digest, and signature fields, but result construction still copies their original values through preflight_text(). The DCF is written even for a blocked result, so a path-like invalid field can enter it."
    artifacts:
      - path: "benchmarks/preflight_gtap12a_reference.R"
        issue: "Lines 873-902 copy source values into the report; lines 904-915 serialize them even when blocked."
      - path: "docs/release/BENCHMARK-EVIDENCE.md"
        issue: "The procedure promises that private paths and filenames are omitted."
      - path: "tests/testthat/test-gtap12a-reference-preflight.R"
        issue: "The report test checks the fixture root and basedata.har, but not malformed path-like DCF fields."
    missing:
      - "Field-specific report allowlists and a regression proving malformed path-like values are absent from the DCF."
  - truth: "An eligible preflight remains bound to the exact reference files used by candidate, comparison, and review."
    status: failed
    reason: "The preflight validates CSV/RDS files but does not record a deterministic digest of the accepted set or recheck it after scanning. Later candidate/comparison commands do not consume a manifest or verify that the reference set stayed unchanged."
    artifacts:
      - path: "benchmarks/preflight_gtap12a_reference.R"
        issue: "Reference collection records counts, but no accepted-file manifest or final mutation check."
      - path: "docs/release/BENCHMARK-EVIDENCE.md"
        issue: "Later commands do not verify the preflight-approved set."
      - path: "tests/testthat/test-gtap12a-reference-preflight.R"
        issue: "The before/after hash assertion only checks that preflight itself did not mutate inputs; there is no post-eligibility mutation case."
    missing:
      - "A deterministic CSV/RDS manifest digest bound through candidate, comparison, and review, rejecting add/remove/change mutations."
behavior_unverified_items:
  - truth: "Hosted predecessor deserialization and transactional receiver invariants hold under the supported R/Matrix runtime."
    test: "Run the focused installed-package serialization and leaf-validation groups plus the approved bug-fix gate in an authorized Matrix >= 1.6-5 environment."
    expected: "Supported installed-package assertions pass, malformed leaves fail at the intended validator, and rejected payloads leave receiver state unchanged."
    why_human: "The current Matrix is below the declared floor and no supported installed-package or hosted result is available. Source presence and prior source-mode evidence do not establish this runtime invariant."
---

# Phase 06: Documentation and Release Qualification Verification

**Phase Goal:** Produce a publication-quality source package and auditable evidence for users and maintainers.  
**Verified:** 2026-10-23T09:21:18Z  
**Status:** passed by explicit maintainer acceptance; technical evidence remains gaps_found
**Re-verification:** Yes — after Plan 06-22's local qualification attempt.

## Maintainer acceptance

Phase 06 is closed by the maintainer's explicit instruction to pass the phase and end the repeated gap cycle. [06-ACCEPTANCE.md](06-ACCEPTANCE.md) records the scope and retained limitations. The `passed` frontmatter status is the workflow acceptance decision; the technical assessment below remains 11/18, with six failed criteria and one behavior-unverified criterion. No additional checks were run to make this decision. The earlier recommendation to keep the phase open is superseded for workflow routing.

## Goal Achievement (technical assessment retained)

Plan 06-22 completed its fail-closed evidence attempt, but complete technical qualification has not been demonstrated. The current Matrix is 1.6.3, below the declared 1.6-5 floor. All nine configured GTAP path variables are absent. No test suite, serialization test, package build/check, solver, candidate, comparison gate, hosted Windows run, or publication was run in this verification. I checked only configuration-variable presence and the installed Matrix version; I did not inspect path values or search external directories.

UAT #48 and #54 remain user-confirmed passes. They are not fresh technical evidence: #54 has no configured local inventory or eligible preflight, and #48 has no retained raw URL check log or current hosted URL result in the later qualification record. No conclusion is made about artifacts that may exist elsewhere.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | The exact built archive passes package checks without blocking warnings or errors. | FAILED | Matrix 1.6.3 is below DESCRIPTION's >= 1.6-5 floor; 06-22 records archive build, scan, and check as not run. |
| 2 | Five required vignettes cover first simulation, sparse migration, backend choice, diagnostics/memory budgeting, and external benchmarking using small redistributable examples where executed. | VERIFIED | Five article sources and the shared fixture exist; earlier archive build evidence is recorded. Plan 06-22 changed no vignette files. |
| 3 | Pkgdown exposes guides, API reference, and migration instructions as a static artifact without Pages deployment. | VERIFIED | _pkgdown.yml lists articles and migration; the workflow is read-only, scans site/staged content, and uploads an artifact without deployment. |
| 4 | Architecture and contributor guides cover subsystem ownership, numerical acceptance, native development, and proprietary-data boundaries. | VERIFIED | Both guide sources remain present; earlier build/readability evidence is recorded. |
| 5 | Release/provenance evidence remains outside public site/archive, with public artifacts scanned before upload. | VERIFIED | .Rbuildignore excludes docs/release and docs/provenance; relevant workflows scan before upload. Prior scan evidence was not rerun. |
| 6 | NEWS, citation, lifecycle, and checklist agree with the selected GPL license, development status, and open blockers. | VERIFIED | DESCRIPTION says GPL (>= 3); package-facing and release documents preserve GPL-3.0-or-later, 0.1.0 development status, and blockers. |
| 7 | The approved pre-1.0 lifecycle policy is recorded. | VERIFIED | VERSION-LIFECYCLE.md records the adopted 0.x and post-1.0 policy. |
| 8 | A current matched benchmark passes the independent gate and has an unsigned evidence summary. | FAILED | GTAP configuration is absent; preflight blocked, candidate/gate not run, and no current result was added. |
| 9 | The benchmark procedure documents external inputs, required evidence, redaction, and unsigned fingerprints. | VERIFIED | BENCHMARK-EVIDENCE.md documents these policies. Its report-redaction promise is contradicted by the implementation defect in Truth 17. |
| 10 | The archive workflow checks the same scanned archive and preserves failure status. | VERIFIED | Workflow requires Status: OK, zero errors/warnings, and no unexplained significant notes. No actual check ran. |
| 11 | Hosted predecessor serialization and transactional receiver behavior pass under supported R/Matrix. | PRESENT_BEHAVIOR_UNVERIFIED | Tests exist, but the runtime is below floor and no supported installed-package or hosted result exists. |
| 12 | The public-content gate rejects repository-only material across archives, site trees, and staged uploads. | VERIFIED | Current scanner decodes named/numeric references and encoded separators; workflows scan before upload. Prior 14/14 test evidence is recorded but was not rerun. |
| 13 | GPL selection is authoritative and matches package metadata without implying publication approval. | VERIFIED | Release decision binds GPL-3.0-or-later to GPL (>= 3), while release documents preserve the blockers. |
| 14 | The integrated release gate checks both license records and rejects inconsistent blocker evidence. | VERIFIED | The validator reads both canonical records and compares the release blocker set to live blockers; focused fixture results are recorded. This does not override the separate live provenance failure. |
| 15 | The live release-gate assertion accepts only the intentional blocked state, without a provenance mismatch. | FAILED | The latest recorded live result was PROVENANCE_KEY_MISMATCH; no later passing assertion or canonical provenance repair is recorded. |
| 16 | Both focused provenance checks pass in the hosted Windows release/current/serial job. | FAILED | Steps are wired, but dispatch was rejected and no hosted result exists. |
| 17 | Invalid build-record values are sanitized from a blocked preflight report. | FAILED | The result builder copies source commit, archive digest, signatures, and package version using preflight_text(), then writes the DCF even when blocked. |
| 18 | The accepted reference set is unchanged from preflight through candidate, comparison, and review. | FAILED | No accepted CSV/RDS manifest digest or downstream manifest verification exists. |

**Score:** 11/18 truths verified; 6 failed and 1 is present but behavior-unverified.

### Required Artifacts and Key Links

| Artifact or link | Status | Evidence |
|---|---|---|
| Five user articles, shared fixture, two maintainer guides, pkgdown configuration | VERIFIED | Sources/configuration exist; earlier build/navigation evidence is recorded. |
| Static pkgdown and exact-archive qualification workflows | VERIFIED | Read-only artifact upload, content scans, and fail-closed archive status gate are wired. |
| Preflight-approved reference set to candidate/comparison | FAILED | No stable accepted-file manifest or downstream verification connects the preflight result to later runs. |
| Build-record fields to DCF report | FAILED | DCF serialization is wired, but invalid raw values can reach the report after a blocked validation. |
| License decision records to integrated gate | VERIFIED | Both records are read; blocker equality is checked. Live provenance remains a separate gap. |
| Windows test steps to hosted result | PARTIAL | Steps are scoped in the workflow; the authorized hosted run/result is absent. |

### Requirements Coverage

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| NUM-03 | BLOCKED | No eligible preflight, matched candidate/gate result, independent review, or current summary; CR-06 and CR-07 also invalidate trust in the preflight path. |
| CI-02 | BLOCKED | Matrix 1.6.3 is below the floor; no installed serialization run or exact archive check occurred. |
| DOCS-02 | SATISFIED on recorded evidence | Required articles and deterministic helper exist; prior build evidence is retained, not rerun. |
| DOCS-03 | SATISFIED on recorded evidence | Architecture/contributor guides remain present and cover planned topics. |
| REL-01 | SATISFIED for documentation deliverables; release remains blocked | License, citation, lifecycle, NEWS, and checklist align. The live provenance mismatch and Phase 1 dependency/attribution holds do not authorize release. |
| DATA-01 | SATISFIED for public artifact boundary on recorded evidence | Archive/site/upload scanning is wired; prior scan evidence is recorded. CR-06 is a narrower external-report privacy defect; no report was produced in this attempt. |

All six requirement IDs in the 22 plans are present in REQUIREMENTS.md. Phase 7 is explicitly downstream of Phase 6 and cleared Phase 1 gates; its criteria do not perform the missing Phase 06 checks, so no gap is deferred.

### Review and Test Quality

The scoped Phase 06 review reports two blockers, confirmed by source inspection:

- CR-06: build-record fields are format-checked, but result construction still emits raw values through preflight_text(); a path-like invalid value can enter a blocked DCF report.
- CR-07: no digest binds the accepted CSV/RDS files to later candidate, comparison, and review steps.

The preflight test file covers complete synthetic evidence, missing solutions, missing CSV metadata, stale runtime metadata, and changed local-input fingerprints. It does not cover malformed path-like DCF fields or reference-file mutation after eligibility. Fixture signatures are generated with the preflight's own benchmark_signature helper, so signature acceptance is not checked against an independent oracle. These tests were inspected, not executed.

No package test suite, focused serialization test, R CMD check, build, install, scanner test, live release gate, benchmark, or hosted workflow was run in this verification. Plan 06-22's regression-gate fallback was true; it is not a package-test pass. Prior test results are explicitly treated as recorded evidence only.

### Human Verification Required

No new manual documentation flow is requested. The serialization invariant still needs a supported installed-package run and hosted result before closure. User-confirmed UAT #48 and #54 remain separate from these technical gates.

### Deferred Items

None. Phase 7 depends on Phase 6 and the cleared Phase 1 release gate; its criteria do not resolve the current archive, benchmark, provenance, or Windows gaps.

### Gaps Summary

The documentation and static qualification workflows are present, but release qualification is incomplete. The Matrix floor blocks installed serialization and exact-archive checks. No configured GTAP paths allow preflight, and two verified defects prevent trusting a future eligible attempt: malformed private build-record data can enter the report, and approved reference files are not bound to later candidate/comparison work. The last recorded live provenance assertion also fails, and Windows evidence is unavailable under the local-only instruction. These limitations remain recorded under the maintainer acceptance; Phase 06 is closed for workflow purposes.

---

_Verified: 2026-10-23T09:21:18Z_  
_Verifier: the agent (gsd-verifier)_
