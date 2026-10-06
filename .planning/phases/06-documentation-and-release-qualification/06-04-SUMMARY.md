---
phase: 06-documentation-and-release-qualification
plan: 04
subsystem: release-documentation
tags: [R, provenance, release-gates, versioning]

requires:
  - phase: 05-portable-native-build-and-ci
    provides: Portable package build and CI conventions
  - phase: 04-public-api-and-solver-boundaries
    provides: Supported public API and solver behavior
provides:
  - Adopted 0.x compatibility and deprecation policy
  - Repository-only evidence-linked release checklist
  - Reviewed 324-row source provenance inventory and fail-closed release assertion
affects: [phase-06-release-qualification, phase-07-publication]

actuals:
  tokens: 26000
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - Package DESCRIPTION may list only the approved repository URL and configured pkgdown URL.
    - Release checklist records the intentional blocked-state assertion separately from release authorization.

key-files:
  created:
    - docs/release/RELEASE-CHECKLIST.md
    - .planning/phases/06-documentation-and-release-qualification/06-04-provenance-repair-proposal/CANONICAL-APPLY-RECEIPT.dcf
  modified:
    - docs/release/VERSION-LIFECYCLE.md
    - docs/release/RELEASE-GATES.md
    - docs/provenance/EXPECTED-KEYS.csv
    - docs/provenance/PROVENANCE.csv
    - docs/provenance/INVENTORY-REVIEW.csv
    - docs/provenance/ATTRIBUTION.md
    - tools/provenance_inventory.R
    - tools/check_release_gates.R
    - NEWS.md
    - inst/CITATION

key-decisions:
  - "Adopted the documented 0.x policy: minor releases may contain documented breaking changes, patch releases carry compatible fixes, and post-1.0 uses SemVer meanings."
  - "Kept version 0.1.0 labeled as development and not a public release."
  - "Preserved DEPENDENCY_COMPATIBILITY_AUDIT_PENDING and ATTRIBUTION_IDENTITY_UNRESOLVED as the exact release blockers."

requirements-completed: [REL-01]

coverage:
  - id: D1
    description: "Maintainer-approved version lifecycle and deprecation policy"
    requirement: REL-01
    verification:
      - kind: integration
        ref: "Rscript --vanilla -e lifecycle policy assertion"
        status: pass
    human_judgment: true
    rationale: "The compatibility promise is maintainer-owned; the user selected the documented proposal on 2026-10-06."
  - id: D2
    description: "Repository-only release checklist with current blocked-state evidence and future release commands"
    requirement: REL-01
    verification:
      - kind: integration
        ref: "Rscript --vanilla tools/check_release_gates.R --assert-blocked"
        status: pass
      - kind: other
        ref: "rg checklist content and command references"
        status: pass
    human_judgment: false
  - id: D3
    description: "Reviewed source provenance ledger and attribution snapshot updated to 324 identities"
    verification:
      - kind: integration
        ref: "Rscript --vanilla tools/provenance_inventory.R --check --root=."
        status: pass
    human_judgment: false

duration: multi-turn
completed: 2026-10-06
status: complete
---

# Phase 06 Plan 04: Release Checklist and Lifecycle Policy

**Release guidance now records the approved 0.x compatibility promise, the exact blocked-state check, and reviewed source provenance.**

## Performance

- **Duration:** Multi-turn execution including the owner decision checkpoint
- **Started:** 2026-10-06
- **Completed:** 2026-10-06
- **Tasks:** 3
- **Files modified:** 30

## Accomplishments

- Recorded the maintainer-approved version lifecycle policy while preserving version `0.1.0` as development-only.
- Added a repository-only release checklist with the current blocked-state result and explicit archive, benchmark, identity, and authorization steps.
- Repaired the provenance source inventory and applied the reviewed 291-to-324 identity transition; all current rows validate.
- Corrected URL validation to accept the approved canonical repository URL plus the URL configured in `_pkgdown.yml`.

## Task Commits

1. **Task 1: Publish lifecycle policy and synchronize NEWS and citation boundaries** - `86960fe`
2. **Task 2: Add repository-only release checklist backed by executable gates** - `93f3a2e`
3. **Task 3: Resolve the maintainer-owned pre-1.0 lifecycle policy** - `5e52590`

The approved provenance repair was committed separately in `0d2b7c8` as a prerequisite for the release gate.

## Files Created/Modified

- `docs/release/VERSION-LIFECYCLE.md` - Adopted pre-1.0, post-1.0, and deprecation policy.
- `docs/release/RELEASE-CHECKLIST.md` - Evidence-linked repository-only release preparation steps.
- `docs/release/RELEASE-GATES.md`, `tools/check_release_gates.R` - Exact canonical repository and configured pkgdown URL contract.
- `docs/provenance/EXPECTED-KEYS.csv`, `PROVENANCE.csv`, `INVENTORY-REVIEW.csv`, `ATTRIBUTION.md` - Applied reviewed 324-row source inventory.
- `tools/provenance_inventory.R` - Preserves saved duplicate function bodies under explicit `_reference` identities.
- `.planning/phases/06-documentation-and-release-qualification/06-04-provenance-repair-proposal/` - Candidate, approval, finalization, application receipt, and checksum evidence.

## Decisions Made

- The user adopted the pre-1.0 policy on 2026-10-06.
- Package publication remains blocked by the dependency compatibility audit and unresolved attribution identity.
- The pkgdown URL is accepted only when it exactly matches the configured site URL.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Repaired provenance inventory drift before asserting release state**
- **Found during:** Task 2 (release checklist verification)
- **Issue:** The source inventory had 324 identities while the canonical expected-key and provenance ledgers had 291; two saved function bodies also shared symbols with later definitions.
- **Fix:** Reviewed and approved a 65-row transition, added explicit `_reference` aliases, applied matching canonical files, and recorded a checksum-bound application receipt.
- **Verification:** Provenance inventory passed at 324/324 rows; release gate provenance and attribution parsers passed.
- **Committed in:** `0d2b7c8`

**2. [Rule 1 - Bug] Accepted the configured pkgdown URL in DESCRIPTION validation**
- **Found during:** Task 2 (release checklist verification)
- **Issue:** The release gate rejected the package's configured documentation URL despite the approved repository URL also being present.
- **Fix:** Require the canonical repository URL and permit the exact `_pkgdown.yml` URL as the only configured secondary URL.
- **Verification:** `tools/check_release_gates.R --assert-blocked` passed with the exact two intentional blockers.
- **Committed in:** `93f3a2e`

**Total deviations:** 2 auto-fixed (one missing critical provenance transition, one release-gate URL predicate)
**Impact on plan:** Both repairs were necessary to make the planned release assertion reflect the reviewed source and documentation metadata.

## Issues Encountered

The first blocked-state assertion reported `DESCRIPTION_URL_MISMATCH`; the gate now validates the canonical repository URL and configured pkgdown URL as an exact ordered pair.

## User Setup Required

None for this plan. Full-scale benchmark inputs and authenticated signer identity remain prerequisites for Plan 06-05.

## Next Phase Readiness

Plans 06-02 and 06-03 can add the remaining vignette and maintainer documentation. Plans 06-05 and 06-06 retain their external benchmark and license-authority checkpoints.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-06*
