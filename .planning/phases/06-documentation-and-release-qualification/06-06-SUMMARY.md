---
phase: 06-documentation-and-release-qualification
plan: 06
subsystem: release-qualification
tags: [GPL-3.0-or-later, source-archive, citation, CI-02, DATA-01]

requires:
  - phase: 06-04
    provides: Release boundaries and retained legal blockers
  - phase: 06-05
    provides: Benchmark evidence policy and local-only release context
provides:
  - Maintainer-selected GPL-3.0-or-later metadata and decision evidence
  - A fail-closed license preflight for the source-archive workflow
  - A selected-license state that preserves the dependency compatibility blocker
  - Source-archive exclusions for repository-only tools and generated scratch
affects: [CI-02, DATA-01, release qualification]

actuals:
  tokens: 1800
  tasks: 2
  commits: 0

tech-stack:
  added: []
  patterns:
    - A selected license is distinct from completed dependency-compatibility clearance
    - R's standard license database validates the exact DESCRIPTION expression

key-files:
  created:
    - docs/release/LICENSE-DECISION.md
    - tools/ci/check-license-decision.R
  modified:
    - .Rbuildignore
    - DESCRIPTION
    - README.md
    - docs/provenance/ATTRIBUTION.md
    - docs/provenance/LICENSE-DECISION.md
    - docs/release/RELEASE-GATES.md
    - inst/CITATION
    - tests/testthat/test-release-gates.R
    - tools/check_release_gates.R

key-decisions:
  - "Use GPL-3.0-or-later, represented in R metadata as GPL (>= 3)."
  - "Retain DEPENDENCY_COMPATIBILITY_AUDIT_PENDING and ATTRIBUTION_IDENTITY_UNRESOLVED; the license choice does not authorize publication."
  - "Treat citation and commercial-use disclosure as package requests, not extra GPL conditions."
  - "Keep repository-only release tooling and generated repair evidence out of the built source archive."

patterns-established:
  - "License decision lifecycle: selected with matching valid metadata, then reviewed only after the dependency audit is hash-bound and its blocker is cleared."

requirements-completed: [DATA-01]

coverage:
  - id: D1
    description: "The package license decision matches DESCRIPTION and the approved maintainer authority."
    verification:
      - kind: other
        ref: "Rscript tools/ci/check-license-decision.R plus a mismatched-DESCRIPTION rejection probe"
        status: pass
    human_judgment: false
  - id: D2
    description: "The built source archive excludes repository-only/private content and passes the public-content gate."
    requirement: DATA-01
    verification:
      - kind: integration
        ref: "R CMD build in /tmp followed by node tools/ci/check-public-content.cjs --archive; 209 archive entries scanned"
        status: pass
      - kind: unit
        ref: "node --test tools/ci/check-public-content.test.cjs; 12 tests passed"
        status: pass
    human_judgment: false
  - id: D3
    description: "The exact built archive passes the required full R CMD check."
    requirement: CI-02
    verification:
      - kind: integration
        ref: "R CMD check --as-cran on /tmp/geomodelr-phase6-verified.Sf4Y1E/GEModelR_0.1.0.tar.gz"
        status: fail
    human_judgment: true
    rationale: "The check stops because local Matrix 1.6-3 is below the package minimum 1.6-5; it also reports 404 responses for the unpublished canonical repository and documentation site."

duration: not-recorded
completed: 2026-10-19
status: halted
---

# Phase 06 Plan 06: License Decision and Source-Archive Qualification

**GPL-3.0-or-later is recorded and the built archive passes its privacy gate; full qualification remains halted by local dependency and source-integrity failures.**

## Performance

- **Duration:** Not recorded.
- **Tasks:** 2 of 3 completed; final qualification is incomplete.
- **Files modified:** 11, plus this summary and the state handoff.

## Accomplishments

- Recorded the user's GPL-3.0-or-later decision as `GPL (>= 3)` in DESCRIPTION and added maintainer authority, citation, and scope details.
- Added a license preflight that verifies the approved decision, package metadata, governance authority, citation file, and R's canonical license analysis.
- Updated the integrated release gate to accept an authorized `selected` license while keeping dependency compatibility and attribution identity as active blockers.
- Excluded repository-only developer tools, release-gate tests, the obsolete migration allowlist, and generated repair artifacts from source archives.
- Built the exact archive under `/tmp` and passed the content scanner; the archive contained 209 entries.

## Verification

- License decision preflight: passed. A temporary mismatched DESCRIPTION was rejected.
- Public-content gate tests: 12 passed.
- Source-mode serialization leaf tests: 101 assertions passed in a clean R process.
- Release-gate self-test: passed. The new selected-license fixtures passed during the focused release-gate run.
- `R CMD build`: passed; vignette creation succeeded.
- `R CMD check --as-cran` on the exact archive: stopped with one error because local Matrix 1.6-3 is below the declared 1.6-5 minimum. It also reported 404 responses for the future repository/site URLs.
- The broader serialization/release-gate runs still report a source/provenance identity mismatch (`PROVENANCE_KEY_MISMATCH`; the migration test reports package-mixed-case 422/328). This is outside the license changes and remains unresolved.

## Issues Encountered

The current R 4.3.0 environment cannot perform the package check against the declared Matrix floor. The canonical repository and pkgdown URLs also return 404 while external publication remains unauthorized. The existing source/provenance identity mismatch prevents the integrated release gate from returning the intended two-blocker state.

## Next Phase Readiness

Plan 06 remains halted. Resume qualification in an R environment with Matrix 1.6-5 or newer, resolve the existing provenance-key mismatch, and rerun the exact archive check. The Phase 1 dependency and attribution blockers remain active; no repository or publication action is authorized by this decision.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-19 (halted)*
