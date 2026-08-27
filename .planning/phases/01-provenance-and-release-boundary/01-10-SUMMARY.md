---
phase: 01-provenance-and-release-boundary
plan: 10
subsystem: release-governance
tags: [r, clean-room, provenance, release-gates, tdd]

requires:
  - phase: 01-07
    provides: integrated release graph and current-source provenance validation
provides:
  - root-confined hash verification for five clean-room evidence artifacts
  - fixed-command behavior-test execution with bounded timeout and captured output
  - strict independently produced DCF result binding and role separation
  - exact clean-room key coverage mapped to new-independent provenance rows
affects: [release-qualification, provenance-audit, phase-03]

actuals:
  tokens: 16597
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - root-confined real-path resolution before evidence access
    - hash-bound artifact and independent-result validation
    - fixed executable and argument-vector subprocess gates

key-files:
  created: []
  modified:
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
    - docs/provenance/CLEANROOM.md
    - specs/cleanroom/README.md

key-decisions:
  - "Cleanroom protocol v2 requires five distinct, non-empty, under-root artifacts with exact lowercase MD5 bindings."
  - "Runnable evidence uses the fixed rscript-cleanroom-v1 command contract and an exact one-row DCF result schema."
  - "Clean-room coverage can clear inherited expression only when every declared key maps to a new-independent provenance row in the integrated graph."
  - "The checked-in rights basis and provenance remain unchanged, preserving the two intentional release blockers."

patterns-established:
  - "Evidence confinement: resolve symlinks and reject any artifact whose real path leaves the evaluated root."
  - "Independent execution proof: bind component, key, four input hashes, roles, timestamp, command, exit status, and review status before rerunning the behavior test."

requirements-completed: [PROV-01, PROV-02]

coverage:
  - id: D1
    description: "Clean-room components resolve and hash-verify five real, distinct, root-confined artifacts with exact non-vacuous coverage."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#clean-room artifact completeness, confinement, hash, type, and cardinality contracts"
        status: pass
    human_judgment: false
  - id: D2
    description: "A fixed Rscript execution and independent result record prove behavior and bind clean-room evidence into new-independent integrated provenance."
    requirement: PROV-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#clean-room execution, result, role, freshness, and integrated coverage contracts"
        status: pass
      - kind: integration
        ref: "tools/check_release_gates.R --self-test"
        status: pass
      - kind: integration
        ref: "tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false

duration: 32min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 10: Enforceable Clean-room Evidence Summary

**Protocol-v2 clean-room evidence now requires five root-confined hash-bound artifacts, a freshly rerun behavior test, an independently bound result, and exact new-independent provenance coverage.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-08-27T10:24:13Z
- **Completed:** 2026-08-27T10:56:17Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Replaced string-only clean-room claims with real replacement source, behavior test, redistributable fixture, public-standard evidence, and independent result artifacts.
- Added fail-closed path confinement, regular/non-empty file checks, exact MD5 validation, duplicate-artifact rejection, and non-vacuous exact key coverage.
- Added fixed `Rscript` execution with bounded timeout plus strict result schema, freshness, role, key, command, status, and hash parity.
- Integrated clean-room evidence with current provenance so readiness requires exact keys classified as `new-independent` and no inherited expression rows.
- Preserved the canonical blockers `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED`.

## Task Commits

Each task was committed atomically with TDD RED and GREEN gates:

1. **Task 1: Trace one real replacement source and fixture into verified clean-room evidence**
   - `6797432` — test(01-10): add failing clean-room artifact contracts
   - `ce1ed82` — feat(01-10): verify clean-room artifact evidence
2. **Task 2: Require runnable behavior tests and independently bound results**
   - `cb4510d` — test(01-10): add failing clean-room execution contracts
   - `3eb9964` — feat(01-10): enforce clean-room execution and results

## Files Created/Modified

- `tools/check_release_gates.R` — evidence path/hash verification, fixed behavior-test runner, result parser/freshness validation, and integrated clean-room provenance gate.
- `tests/testthat/test-release-gates.R` — complete executable clean-room fixtures and adversarial artifact, execution, result, role, freshness, and coverage matrix.
- `docs/provenance/CLEANROOM.md` — protocol-v2 evidence workflow, fixed test command, result contract, and unchanged rights-basis boundary.
- `specs/cleanroom/README.md` — required component fields, five artifact bindings, role separation, exact coverage, and DCF schema.

## Decisions Made

- Artifact declarations are evidence only after real-path confinement, regular/non-empty checks, and exact lowercase MD5 parity.
- The checker invokes only its own R installation's `Rscript` with fixed named source/fixture arguments; component metadata cannot supply a command string.
- Result producers are independent from specification authors, implementers, and reviewers, and the result must postdate all four tested inputs.
- Synthetic fixtures prove the alternative route without copying clean-room claims into canonical RIGHTS or PROVENANCE records.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected malformed-result fixture rehashing**
- **Found during:** Task 2 GREEN verification
- **Issue:** The new missing-field DCF regression initially called a helper whose hash map intentionally covered only the four input artifacts.
- **Fix:** Updated the test to write the independent-result MD5 directly into the component record.
- **Files modified:** `tests/testthat/test-release-gates.R`
- **Verification:** The complete release-gate suite passed 465 assertions with 0 failures, warnings, or skips.
- **Committed in:** `3eb9964`

**2. [Rule 3 - Blocking] Reconciled skipped derived state progress**
- **Found during:** Final state update
- **Issue:** The SDK advanced the authoritative plan count to 10/11 but skipped human-readable progress and velocity fields because the active phase is unscoped.
- **Fix:** Reconciled the progress bar, plan count, duration totals, recent trend, and last-activity narrative to the authoritative summary count.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE frontmatter and prose report ten completed plans and ROADMAP reports 10/11.
- **Committed in:** Final plan metadata commit

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Test-fixture and planning-metadata correctness only; production scope and release-state semantics are unchanged.

## Verification

- Release-gate suite: **465 passed**, 0 failed, 0 warnings, 0 skipped.
- Isolated checker self-test: **pass**.
- Provenance drift check: **250 reviewed rows / 250 expected keys**.
- `--assert-blocked`: **pass**, with all integrated parsers passing and exactly the two intentional blockers.
- Commit-range whitespace check: **pass**.
- Canonical `docs/provenance/RIGHTS.md` and `docs/provenance/PROVENANCE.csv`: **unchanged**.

## TDD Gate Compliance

Both tasks have a failing `test(01-10)` RED commit followed by a `feat(01-10)` GREEN commit. The tracer's complete suite and isolated self-test passed before Task 2 expansion.

## Known Stubs

None in files created or modified by this plan.

## Issues Encountered

- The environment's patch helper and some RTK read paths could not create an unprivileged namespace; narrow noninteractive `rtk proxy` fallbacks were used as authorized.
- `R CMD check .` reached package installation but failed on the known host mismatch: Linuxbrew binutils require GLIBC symbols unavailable on Debian 10. The generated ignored `..Rcheck` directory was removed; focused plan verification passed.

## User Setup Required

None - no external service configuration, human checkpoint, repository mutation outside the plan, or publication action was required.

## Next Phase Readiness

- CR-08 is closed with automated coverage for real artifacts, execution, independent results, and integrated provenance.
- Release remains intentionally blocked only by `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED`.
- Either blocker may be cleared only through its explicit reviewed evidence transition; no human checkpoint was inferred or autoapproved.

## Self-Check: PASSED

All five claimed files exist and all four TDD task commits are present in Git history.

---
*Phase: 01-provenance-and-release-boundary*
*Completed: 2026-08-27*
