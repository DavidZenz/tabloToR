---
phase: 01-provenance-and-release-boundary
plan: 06
subsystem: release-governance
tags: [release-gates, provenance, attribution, identity, fail-closed]
dependency_graph:
  requires:
    - 01-01 rights and public-domain evidence
    - 01-02 clean-room protocol
    - 01-03 provenance inventory
    - 01-04 name governance and repository identity
    - 01-05 attribution propagation
  provides:
    - integrated release evidence decision
    - exact approved package identity metadata
    - synthetic release-ready proof and real blocked-state assertion
  affects:
    - Phase 02 dependency compatibility audit
    - repository reservation and publication workflows
tech_stack:
  added: []
  patterns:
    - fail-closed cross-document parsers
    - exact intentional-blocker parity
    - repository-only evidence tests skipped in built source packages
key_files:
  created:
    - .planning/phases/01-provenance-and-release-boundary/01-06-SUMMARY.md
  modified:
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
    - DESCRIPTION
    - tests/testthat/test-attribution-contract.R
    - docs/provenance/RIGHTS.md
    - docs/release/RELEASE-GATES.md
    - tests/testthat/test-provenance-inventory.R
    - tests/testthat/test-name-availability.R
decisions:
  - Release blockers must match RIGHTS.md, ATTRIBUTION.md, and RELEASE-GATES.md exactly.
  - A blocker-free release decision requires a fresh release-kind six-source name report.
  - The unresolved DESCRIPTION License is valid only while the dependency compatibility blocker is present.
  - Technical release readiness never authorizes repository creation, settings changes, or publication.
metrics:
  duration: 25m
  completed: 2026-08-25
status: complete
actuals:
  tokens: 11934
  tasks: 2
  commits: 4
---

# Phase 1 Plan 6: Integrated Release Boundary Summary

A nine-stream fail-closed release checker with exact approved GEModelR identity metadata, a proven synthetic ready path, and the real repository blocked only by two reviewed unresolved facts.

## Accomplishments

- Integrated rights, public-domain response, provenance/oracle, attribution, name, governance, repository, and DESCRIPTION evidence into one deterministic result.
- Replaced temporary Phase 01-03/01-04 markers with complete provenance/name status and exact blocker parity across all canonical records.
- Applied David Zenz <zenz@wiiw.ac.at>, the canonical GEModelR URL, and its issue tracker to DESCRIPTION without renaming tabloToR or inventing a package license.
- Proved both directions: the checked-in repository is intentionally blocked, while an isolated complete fixture with a fresh release-kind name report is eligible.
- Kept every external repository and publication action explicitly not-authorized.

## Task Commits

| Task | Commit | Description |
| --- | --- | --- |
| 01-06-01 RED | 61d3cb4 | Added failing integrated release evidence contracts |
| 01-06-01 GREEN | 4dfbc18 | Integrated the release evidence decision and canonical blockers |
| 01-06-02 RED | 9014ee5 | Added failing approved package identity assertions |
| 01-06-02 GREEN | fd3a19e | Applied approved identity and package-check-safe repository tests |

## Release Decision

The checked-in root evaluates to:

- repository_state=blocked
- release_ready=false
- reason_codes=DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED
- nine parser statuses equal pass

--assert-blocked exits zero only because the parser graph is fully valid and its reason codes exactly equal the intentional blocker list. --offline exits one with the same reasons. No blocker was forced, hidden, or converted into readiness.

## Verification

- Provenance focused tests: 41 assertions passed.
- Attribution focused tests: 43 assertions passed.
- Name focused tests: 46 assertions passed.
- Integrated release focused tests: 196 assertions passed.
- Independent provenance check: reviewed rows=250 expected_keys=250.
- Approved name report verification: report_status=approved.
- Release checker self-test: passed.
- Real blocked-state assertion: passed with nine passing parsers.
- Required R CMD check .: reached compilation and reproduced the known Linuxbrew assembler/GLIBC mismatch in as; this is an environment failure, not a package compile diagnostic.
- Sanitized source-tarball check using the system toolchain: exit zero; package compiled, installed, loaded, and package tests passed. It retained 1 pre-existing documentation warning and 3 notes for hidden development files, installed size, and the intentionally unresolved License.
- git diff --check: passed.

## Decisions Made

- The reviewed blocker set is derived independently from attribution facts and must match both the rights record and release policy in order and content.
- The approved initial name report can validate the currently blocked repository, but a blocker-free result requires a release-kind report no more than 24 hours old.
- DESCRIPTION parity includes package name, maintainer contact, Authors@R creator identity, canonical URL, issue tracker, and conditional License handling.
- Repository-only evidence suites run directly in the source repository and skip when their excluded tooling/evidence is absent from a built package.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Replaced stale temporary rights and policy markers**
- **Found during:** Task 01-06-01
- **Issue:** RIGHTS.md and RELEASE-GATES.md still named incomplete provenance as the sole blocker after the provenance and name evidence had been approved.
- **Fix:** Marked provenance complete, recorded the approved initial name report, and made the two reviewed attribution facts the exact canonical blocker set.
- **Files modified:** docs/provenance/RIGHTS.md, docs/release/RELEASE-GATES.md
- **Commit:** 4dfbc18

**2. [Rule 3 - Blocking issue] Kept repository-only evidence tests out of built-package failures**
- **Found during:** Task 01-06-02 package verification
- **Issue:** Source tarballs intentionally exclude release tooling and planning evidence, so package tests attempted to load files that cannot exist after build.
- **Fix:** Repository-focused evidence suites now skip only when their tooling/evidence is absent from a built package; direct source-repository execution remains mandatory and fully green.
- **Files modified:** tests/testthat/test-release-gates.R, tests/testthat/test-provenance-inventory.R, tests/testthat/test-name-availability.R, tests/testthat/test-attribution-contract.R
- **Commit:** fd3a19e

**3. [Rule 3 - Blocking issue] Repaired stale derived phase progress**
- **Found during:** State update
- **Issue:** state.update-progress skipped the unscoped verifying phase and left the narrative progress, velocity, activity, and blockers at Plan 01-05 values.
- **Fix:** Reconciled STATE.md with six completed summaries, 100% plan progress, current metrics, and the two actual release blockers.
- **Files modified:** .planning/STATE.md, .planning/ROADMAP.md
- **Commit:** Final metadata commit

## Authentication Gates

None.

## Known Stubs

| File | Line | Stub | Reason |
| --- | ---: | --- | --- |
| DESCRIPTION | 18 | License: What license is it under? | Intentional fail-closed placeholder until the LinkingTo, vendored, and native dependency compatibility audit establishes a compatible package license. |

The License stub does not prevent this plan goal: the required outcome is an internally consistent, correctly blocked release boundary. It is recorded as open in .planning/WINDOWS.md.

## Deferred Issues

- Resolve the dependency compatibility audit before replacing the package License or removing DEPENDENCY_COMPATIBILITY_AUDIT_PENDING.
- Resolve the Git identity alias through reviewed public evidence or an explicit attribution decision before removing ATTRIBUTION_IDENTITY_UNRESOLVED.
- Address pre-existing package documentation and source-build hygiene warnings in the release-qualification work.

## Self-Check: PASSED

Summary file and all four task commits were verified on disk.
