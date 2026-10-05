---
phase: 02-compatibility-and-numerical-baseline
plan: 02
subsystem: testing
tags: [R, testthat, GEModel, compatibility, shock-semantics, workflow-fixture]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    plan: 01
    provides: GEModel compatibility manifest and structural comparison helpers
provides:
  - Redistributable three-region TABLO fixture and deterministic public workflow
  - Unified retained-until-replaced shock semantics across public APIs and engines
  - Executable contracts for defaults, selectors, output modes, postsim branches, and legacy smoke
affects: [02-03, 02-04, 02-05, 02-06, numerical-baselines, serialization]

actuals:
  tokens: 8045
  tasks: 3
  commits: 7

tech-stack:
  added: []
  patterns:
    - Stable workflow IDs mapped to executable public-method tests
    - Public shock sources retained until explicitly replaced or cleared
    - Full solves deterministically replace stale compact projections

key-files:
  created:
    - tests/testthat/fixtures/three-region.tab
    - tests/testthat/helper-three-region.R
    - tests/testthat/test-documented-workflow.R
    - inst/compatibility/WORKFLOWS.md
  modified:
    - R/GEModel.R
    - R/sparseSolver.R
    - tests/testthat/fixtures/PROVENANCE.md

key-decisions:
  - "Retain setShocks() and complete variableValues shock sources across solve calls until the caller replaces or clears them; never infer fresh shocks from mutable backend state."
  - "Normalize duplicate indexed labels by runtime identity before legacy application, matching sparse deterministic summation."
  - "Keep legacy as a public-workflow smoke path and default-parity subject, never as a numerical oracle for Matrix or structured backends."
  - "Treat WF-UNCLASSIFIED as visibly FLAGGED-UNVERIFIED until a real documented branch exists."

patterns-established:
  - "Workflow matrix: every documented non-flagged workflow ID names one executable test."
  - "Output replacement: every successful solve replaces solution, data, compactOutput, and diagnostics according to the requested mode."

requirements-completed: [COMP-01, COMP-02, COMP-03, NUM-01]

coverage:
  - id: D1
    description: Public three-region constructor-to-output workflow on newly authored redistributable data
    requirement: COMP-01
    verification:
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#WF-PREFERRED-SPARSE runs the public three-region workflow
        status: pass
    human_judgment: false
  - id: D2
    description: Preferred and direct shock APIs share normalized repeated-solve and clearing semantics
    requirement: COMP-03
    verification:
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#D-03 shock APIs share normalized indexed application semantics
        status: pass
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#WF-REPEATED-SOLVE retains then clears shocks for both APIs
        status: pass
    human_judgment: false
  - id: D3
    description: Omitted and explicit legacy/Matrix defaults plus NULL selectors are behaviorally equivalent
    requirement: COMP-02
    verification:
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#WF-DEFAULT-OMITTED and WF-DEFAULT-EXPLICIT are equivalent
        status: pass
      - kind: unit
        ref: tests/testthat/test-public-solver-contract.R#solver defaults and reference backend remain unchanged
        status: pass
    human_judgment: false
  - id: D4
    description: Full, compact, selected, singleton, empty, and postsim output structures replace stale state
    requirement: COMP-03
    verification:
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#WF-FULL-OUTPUT freezes full and selected structures
        status: pass
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#WF-COMPACT-OUTPUT and WF-POSTSIM-OFF freeze compact structures
        status: pass
    human_judgment: false
  - id: D5
    description: Legacy completes the public fixture only as a finite structural compatibility smoke path
    requirement: NUM-01
    verification:
      - kind: integration
        ref: tests/testthat/test-documented-workflow.R#WF-PREFERRED-LEGACY-SMOKE exercises only public compatibility
        status: pass
    human_judgment: false

duration: 24min
completed: 2026-09-02
status: complete
---

# Phase 02 Plan 02: Public Workflow and Compatibility Baseline Summary

**A redistributable three-region workflow now freezes shock parity, repeated solves, defaults, output structures, and a strictly smoke-only legacy boundary through public GEModel calls.**

## Performance

- **Duration:** 24 min
- **Started:** 2026-09-02T13:21:47Z
- **Completed:** 2026-09-02T13:45:43Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added a newly authored CC0 three-region TABLO fixture, provenance fingerprint, deterministic input builder, and full public workflow tracer.
- Unified preferred `setShocks()` and direct `variableValues` behavior for duplicate, zero, missing, empty, scalar, indexed, repeated, retained, and cleared shock cases.
- Froze omitted/explicit defaults, NULL/empty/single selectors, full/compact outputs, postsim state, missing/zero conventions, invisible returns, and stale-output clearing.
- Kept legacy explicitly constrained to public workflow and structural smoke assertions without using its values as a cross-backend baseline.

## Task Commits

All TDD tasks retain their RED-before-GREEN history:

1. **Task 1 RED: Public three-region workflow contract** - `c90c15a`
2. **Task 1 GREEN: Public three-region workflow tracer** - `59fece4`
3. **Task 2 RED: Shock API and repeated-solve parity contracts** - `b136e69`
4. **Task 2 RED: Legacy normalized-duplicate parity contract** - `1188f68`
5. **Task 2 GREEN: Unified shock application semantics** - `bba2d14`
6. **Task 3 RED: Defaults and output workflow contracts** - `db951fd`
7. **Task 3 GREEN: Frozen output and legacy-smoke contracts** - `347c3b7`

## Files Created/Modified

- `tests/testthat/fixtures/three-region.tab` - Small transparent indexed model with update and post-simulation paths.
- `tests/testthat/fixtures/PROVENANCE.md` - Authorship, CC0 basis, prohibited-source relationship, and fixture fingerprint.
- `tests/testthat/helper-three-region.R` - Deterministic model, data, shock API, solve, and state helpers.
- `tests/testthat/test-documented-workflow.R` - End-to-end, shock, default, output, postsim, missing/zero, and legacy-smoke contracts.
- `inst/compatibility/WORKFLOWS.md` - Stable workflow matrix plus D-03/D-04/D-17 state rules.
- `R/GEModel.R` - Numeric empty-shock handling and zero-valued legacy closure templates.
- `R/sparseSolver.R` - Normalized legacy aggregation, no sparse-state shock fallback, and deterministic compact-output clearing.

## Decisions Made

- Shock sources are retained public input, not backend state: a later solve reuses the source until the caller clears it through the same API.
- Duplicate quote/whitespace variants that resolve to one indexed element sum deterministically in both sparse and legacy paths.
- Explicit `NULL` selectors equal omission; explicit empty selectors project no variables.
- Legacy assertions cover completion, state, finiteness, and structure only. Matrix remains the generic sparse numerical authority.
- `WF-UNCLASSIFIED` remains flagged rather than inventing a workflow branch absent from the source documentation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented cleared sparse shocks from reappearing through mutable state**
- **Found during:** Task 2
- **Issue:** An empty `variableValues` source fell back to current sparse-state levels, reapplying old exogenous values after a clear.
- **Fix:** Empty direct input now resolves to an empty normalized shock set without state fallback.
- **Files modified:** `R/sparseSolver.R`
- **Verification:** Preferred and direct three-solve retain/clear matrix passes for sparse and legacy.
- **Committed in:** `bba2d14`

**2. [Rule 1 - Bug] Aggregated normalized legacy duplicate labels**
- **Found during:** Task 2
- **Issue:** Quote/whitespace variants resolving to one legacy element overwrote each other instead of summing.
- **Fix:** Legacy explicit shocks now aggregate by normalized runtime key before application and drop zero totals.
- **Files modified:** `R/sparseSolver.R`
- **Verification:** Mixed quoted/unquoted duplicate case resolves to the same result as sparse and direct APIs.
- **Committed in:** `bba2d14`

**3. [Rule 1 - Bug] Preserved numeric zero closure structure for cleared legacy shocks**
- **Found during:** Task 2
- **Issue:** Clearing legacy shocks produced an empty logical vector and then a non-square system without named zero closure columns.
- **Fix:** Coerced direct shock input to named numeric values and generated zero closure labels from stable compiled variable metadata.
- **Files modified:** `R/GEModel.R`
- **Verification:** Legacy preferred and direct APIs both retain and clear across consecutive solves.
- **Committed in:** `bba2d14`

**4. [Rule 1 - Bug] Cleared stale compact output after full solves**
- **Found during:** Task 3
- **Issue:** A full unselected solve left `compactOutput` from an earlier compact/selected solve.
- **Fix:** Every sparse solve now replaces `compactOutput`, using an empty list when no projection is requested.
- **Files modified:** `R/sparseSolver.R`
- **Verification:** Compact-to-full transition test and all output/default filters pass.
- **Committed in:** `347c3b7`

---

**Total deviations:** 4 auto-fixed bugs
**Impact on plan:** All fixes are confined to planned shock/output compatibility seams; no defaults, equations, solver algorithms, tolerances, exports, or methodology changed.

## Issues Encountered

- The environment's patch helper cannot create its `bwrap` namespace. After both absolute and repository-relative attempts failed, scoped unified patches were applied through `git apply` and every diff was checked before commit.
- The pre-existing GEModel reference-class warning about local assignment to `data$eqcoeff` remains unchanged and out of scope.

## Verification

- `testthat::test_local(filter = "documented-workflow|sparse-core|public-solver-contract|compatibility-manifest", reporter = "summary")` — PASS.
- Prior tracer verification — PASS (25 expectations at the approved checkpoint).
- No task commit deletes tracked files.
- Stub scan — clean.
- Threat-surface scan — no unplanned endpoint, auth, file-access, or schema boundary introduced.

## TDD Gate Compliance

- Task 1: `c90c15a` RED precedes `59fece4` GREEN.
- Task 2: `b136e69` and `1188f68` RED precede `bba2d14` GREEN.
- Task 3: `db951fd` RED precedes `347c3b7` GREEN.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Later numerical plans can reuse the public three-region workflow without proprietary fixtures.
- Shock source ownership and output replacement semantics are stable for transactional-state and serialization work.
- Structured R/C++ numerical equivalence remains governed by subsequent Phase 02 plans; legacy remains smoke-only.

---
*Phase: 02-compatibility-and-numerical-baseline*
*Completed: 2026-09-02*

## Self-Check: PASSED

All seven key artifacts and all seven task commits were verified on disk.
