---
phase: 01-provenance-and-release-boundary
plan: 01
subsystem: release-governance
tags: [r, testthat, provenance, release-gates, fail-closed]

requires: []
provides:
  - Canonical blocked rights record bound to the inherited upstream baseline
  - Executable offline and correctly-blocked release assertions
  - Isolated written-grant, clean-room, malformed, and sensitive fixtures
affects: [01-02, 01-03, 01-04, 01-05, 01-06, release-qualification]

actuals:
  tokens: 7488
  tasks: 2
  commits: 5

tech-stack:
  added: []
  patterns: [strict single-line markers, fail-closed base-R checker, temporary-root evidence fixtures]

key-files:
  created:
    - docs/provenance/RIGHTS.md
    - docs/release/RELEASE-GATES.md
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
  modified: []

key-decisions:
  - "Treat the checked-in repository as valid only when it is completely and intentionally blocked by RIGHTS_BLOCKED."
  - "Keep all eligible written-grant and clean-room evidence synthetic and isolated from the canonical blocked record."
  - "Reject sensitive evidence by class or filename while emitting stable reason codes only."

patterns-established:
  - "Repository assertion: --assert-blocked succeeds only for a fully parsed exact intentional blocker set."
  - "Release assertion: --offline succeeds only for complete eligible evidence and otherwise fails closed."
  - "Evidence diagnostics: expose status fields and reason codes, never matched evidence contents."

requirements-completed: [PROV-01]

coverage:
  - id: D1
    description: "Canonical repository evidence resolves to blocked, release_ready=false, and RIGHTS_BLOCKED while --assert-blocked exits zero."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#the checked-in repository is positively recognized as blocked"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false
  - id: D2
    description: "Synthetic written-grant and reviewed clean-room roots prove true release readiness without changing real rights evidence."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#synthetic readiness fixtures"
        status: pass
      - kind: e2e
        ref: "Rscript --vanilla tools/check_release_gates.R --self-test"
        status: pass
    human_judgment: false
  - id: D3
    description: "Malformed, contradictory, incomplete-scope, and sensitive evidence produce exact nonzero reason codes without content disclosure."
    requirement: PROV-01
    verification:
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#negative parser, consistency, scope, and sensitive evidence cases"
        status: pass
    human_judgment: false

duration: 17 min
completed: 2026-08-25
status: complete
---

# Phase 1 Plan 1: Provenance and Release Boundary Summary

**Fail-closed rights gating that positively proves the real repository is intentionally blocked while isolated fixtures prove true eligibility.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-08-25T06:53:32Z
- **Completed:** 2026-08-25T07:10:40Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Bound the inherited upstream repository and commit to a canonical `Rights-Status: blocked` record under D-05 and D-17.
- Added separate `--offline`, `--assert-blocked`, and `--self-test` contracts with summary-before-exit diagnostics.
- Proved exact success and failure outcomes for written grants, reviewed clean-room replacement, malformed evidence, policy mismatch, incomplete scope, and sensitive evidence classes.

## Task Commits

Each TDD task was committed in RED then GREEN order:

1. **Task 01-01-01 RED: rights boundary contract** - `d9b0de2` (test)
2. **Task 01-01-01 GREEN: checked-in blocked tracer** - `f8597bf` (feat)
3. **Task 01-01-02 RED: isolated readiness fixtures** - `ed3ff5d` (test)
4. **Task 01-01-02 GREEN: release readiness and privacy gates** - `90bf209` (feat)

## Files Created/Modified

- `docs/provenance/RIGHTS.md` - Canonical blocked rights record and public/private evidence boundary.
- `docs/release/RELEASE-GATES.md` - Human-readable gate predicates, evidence sources, review needs, and blocker codes.
- `tools/check_release_gates.R` - Base-R parser, evaluator, CLI modes, sensitive evidence scan, and temporary-root self-test.
- `tests/testthat/test-release-gates.R` - Exact repository, positive synthetic, malformed, contradiction, scope, clean-room, and sensitive-class contracts.

## Decisions Made

- Used upstream commit `7e063c65a19713857ed13023f8b77dad45b15c90`, the inherited baseline immediately before local sparse-solver development, as the rights scope anchor.
- Reserved zero exit from `--assert-blocked` for complete parser success plus the exact `RIGHTS_BLOCKED` blocker set; generic failure cannot masquerade as intentional blocking.
- Represented no-blocker synthetic evidence with `Intentional-Blockers: NONE`, normalized to an empty blocker set before readiness evaluation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repaired skipped GSD progress calculation**
- **Found during:** Plan close-out
- **Issue:** `state.update-progress` skipped the in-progress phase as “unscoped,” leaving the progress bar and velocity fields stale after `state.advance-plan` succeeded.
- **Fix:** Updated the derived STATE progress and velocity fields to match the on-disk 1/6 summary count while preserving SDK-managed position, metrics, decisions, and session data.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE reports Plan 2 of 6, one completed plan, and 17% progress; ROADMAP reports 1/6 In Progress.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 1 auto-fixed (1 blocking issue)
**Impact on plan:** Close-out metadata now agrees with the committed summary; implementation scope is unchanged.

## Issues Encountered

- The required focused tests, checker self-test, blocked assertion, and diff hygiene all passed.
- A broader `R CMD check` was run as required by `AGENTS.md`; it reached a pre-existing Linuxbrew assembler/GLIBC mismatch and also reported pre-existing ignored build artifacts and hidden benchmark experiments. No Plan 01-01 file caused the failure. Details are recorded in `deferred-items.md` for later portability and release-qualification work.

## Known Stubs

None. The `not-posted`, `not-available`, and pending-review values in `RIGHTS.md` are intentional canonical evidence for the required blocked state, not implementation placeholders.

## User Setup Required

None - no external service configuration or publication action was performed.

## Next Phase Readiness

- Plan 01-02 can extend the established marker and reason-code contract with the human-posted request and strict clean-room protocol.
- Public redistribution remains intentionally blocked until adequate written rights or independently reviewed replacement coverage exists.

## Self-Check: PASSED

---
*Phase: 01-provenance-and-release-boundary*
*Completed: 2026-08-25*
