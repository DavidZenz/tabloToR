---
phase: 06-documentation-and-release-qualification
plan: 07
subsystem: release-qualification
tags: [license-gates, provenance, pkgdown, archive-safety, release-docs]
requires:
  - phase: 06-documentation-and-release-qualification
    provides: Release records, public-content scanner, package documentation, and lifecycle policy
provides:
  - Paired provenance and release license records validated against shared facts and current blockers
  - Fail-closed scanning for encoded repository-only paths and repaired pkgdown links
  - Archive-safe package text aligned with GPL-3.0-or-later and the 0.1.0 development lifecycle
affects: [release-qualification, package-documentation, source-archive]
actuals:
  tokens: 6245
  tasks: 3
  commits: 6
tech-stack:
  added: []
  patterns:
    - Fail-closed validation across paired release authority records
    - Encoded path-separator rejection in shared public-content scans
key-files:
  created: []
  modified:
    - docs/release/RELEASE-GATES.md
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
    - tools/ci/check-public-content.cjs
    - tools/ci/check-public-content.test.cjs
    - vignettes/diagnostics-memory-budgeting.Rmd
    - vignettes/legacy-to-sparse.Rmd
    - vignettes/backend-selection.Rmd
    - NEWS.md
    - README.md
    - inst/CITATION
key-decisions:
  - "Require both license decision records and compare their shared facts and blockers while allowing their distinct lifecycle statuses."
  - "Reject ambiguous encoded separators in repository-only path candidates and keep package-facing references inside the source archive."
  - "Retain the 0.1.0 development status, selected GPL-3.0-or-later license, and current release blockers."
patterns-established:
  - "Decision records must agree on authoritative facts and the live blocker set before release status is reported."
  - "Public-content scans fail closed when encoded path separators could conceal excluded repository evidence."
requirements-completed: [DOCS-02, REL-01, DATA-01]
coverage:
  - id: D1
    description: "The release gate requires and cross-validates the provenance and release license decision records."
    requirement: REL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#paired decision-record fixtures"
        status: pass
      - kind: unit
        ref: "testthat::test_file('tests/testthat/test-release-gates.R') — nine canonical-state assertions fail on PROVENANCE_KEY_MISMATCH"
        status: fail
    human_judgment: true
    rationale: "The paired-record fixtures pass, but the full focused file remains affected by the known canonical provenance mismatch; release qualification still needs that source-integrity issue resolved."
  - id: D2
    description: "Encoded repository-only paths are rejected, and the three repaired vignette links resolve in the generated site."
    requirement: DOCS-02
    verification:
      - kind: unit
        ref: "rtk node --test tools/ci/check-public-content.test.cjs"
        status: pass
      - kind: integration
        ref: "pkgdown::build_site() and rendered-link resolution assertion"
        status: pass
    human_judgment: false
  - id: D3
    description: "NEWS and package-facing citation text reflect the selected license and adopted version lifecycle."
    requirement: REL-01
    verification:
      - kind: other
        ref: "Task 3 NEWS/archive-boundary Rscript assertion"
        status: pass
    human_judgment: false
  - id: D4
    description: "README, NEWS, and CITATION contain no relative links into excluded planning or evidence directories."
    requirement: DATA-01
    verification:
      - kind: other
        ref: "Task 3 NEWS/archive-boundary Rscript assertion"
        status: pass
    human_judgment: false
duration: 20min
completed: 2026-10-20
status: complete
---

# Phase 06 Plan 07: Paired Release Gates and Archive-Safe Docs Summary

**The release gate now checks both license authority records, public scans reject encoded repository-only paths, and package text reflects the selected license and release boundary.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-10-20T06:30:46Z
- **Completed:** 2026-10-20T06:51:05Z
- **Tasks:** 3
- **Files modified:** 11

## Accomplishments

- Added validation for the release license decision record and its shared fields, blocker set, reviewer, and date alongside the provenance decision record.
- Extended public-content scanning to reject literal, numeric, named, and percent-encoded separators that could conceal repository-only release or provenance paths; repaired the diagnostics and migration article links.
- Updated NEWS, README, and CITATION for GPL-3.0-or-later, the 0.1.0 development status, the adopted pre-1.0/post-1.0 policy, and archive-safe references.

## Task Commits

1. **Task 1 RED: paired license decision tests** - `c1b3dd1` (`test`)
2. **Task 1 GREEN: validate paired license records** - `cb548d3` (`feat`)
3. **Task 2 RED: encoded path regression** - `6c92853` (`test`)
4. **Task 2 GREEN: scanner and link repairs** - `b4d438f` (`feat`)
5. **Task 3: package-facing release text** - `7f6ff90` (`docs`)

The plan summary and tracking metadata are committed separately after self-check.

## Verification

- Task 1 focused release-gate file: **498 passed, 9 failed**. The clean committed snapshot reproduced the same nine failures, all caused by the pre-existing `PROVENANCE_KEY_MISMATCH`: six assertions in “the checked-in repository is positively recognized as blocked,” one offline-readiness reason-code assertion, and two synthetic clean-room canonical-state/reason-code assertions. The new paired-record mutation fixtures passed. The same mismatch is recorded in the Phase 06 Plan 06 verification; no Matrix-floor failure occurred.
- Task 2 public-content tests: **12/12 passed**. The pkgdown site built successfully, and the exact migration and diagnostics rendered-link assertions passed.
- Task 3 exact NEWS/archive-boundary assertion and `git diff --check`: passed.
- The generated `.pkgdown-site` directory and temporary clean test snapshot were removed after verification.

## Decisions Made

- Require both license decision records and compare their shared facts and current blockers while allowing their distinct lifecycle statuses.
- Fail closed when encoded separators make a repository-only path ambiguous.
- Preserve the development release boundary and both blockers; this plan does not authorize publication or change the Matrix floor.

## Deviations from Plan

None. The existing canonical provenance mismatch remains out of scope and is documented under Verification and Issues Encountered.

## Issues Encountered

The focused release-gate file cannot pass its canonical-state assertions while the source inventory reports `PROVENANCE_KEY_MISMATCH`. The mismatch reproduces in a clean snapshot of the committed plan and was already present in Phase 06 Plan 06; all paired-record-specific fixtures pass. The issue was not changed because it is outside this plan's files and the shared working tree contains unrelated solver edits that must be preserved.

## User Setup Required

None.

## Next Phase Readiness

The documentation and release-gate gaps addressed by this plan are complete. Exact source-archive qualification remains an environmental gate for CI-02. NUM-03 still lacks a matched R/C++ baseline, and hosted serialization qualification remains open. Dependency compatibility and attribution identity remain release blockers.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-20*

## Self-Check: PASSED

The summary file exists, and all five task commits listed above are present in git history.
