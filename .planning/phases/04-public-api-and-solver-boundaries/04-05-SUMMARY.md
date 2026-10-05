---
phase: 04-public-api-and-solver-boundaries
plan: 05
subsystem: api
tags: [R, GEModelR, testthat, diagnostics, Matrix, Rcpp, serialization]

requires:
  - phase: 04-03
    provides: Public lifecycle validation classes and solve-boundary contracts
  - phase: 04-04
    provides: Validated sparse output selection and projection flow
provides:
  - Stable solve outcome classes and a version-1 diagnostic envelope for each attempt
  - Opt-in R and C++ capability, residual, timing, allocation, memory, and cleanup evidence
  - Logical-state round trips that preserve the exact small diagnostic envelope
affects: [04-06, solver-diagnostics, native-cleanup, logical-state-serialization]

actuals:
  tokens: 19107.75
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - Keep stable diagnostic fields small and attach solver telemetry only when diagnostics are enabled.
    - Preserve requested backend identity separately from the selected implementation.
    - Reconstruct generated numeric update fields from serialized levels when optional diagnostic detail is absent.

key-files:
  created:
    - .planning/phases/04-public-api-and-solver-boundaries/04-05-SUMMARY.md
  modified:
    - R/GEModel.R
    - R/sparseSolver.R
    - R/zzzSparseSchurCpp.R
    - R/zzzzzSchurDiagnostics.R
    - R/modelSerialization.R
    - tests/testthat/test-public-solver-contract.R
    - tests/testthat/test-transactional-state.R
    - tests/testthat/test-public-cpp-backend.R
    - tests/testthat/test-model-serialization.R
    - tests/testthat/test-lifecycle-contract.R
    - .planning/phases/04-public-api-and-solver-boundaries/deferred-items.md

key-decisions:
  - "Store a fixed version-1 envelope on every solve attempt and keep detailed telemetry opt-in."
  - "Keep StructuredSchurFGMRESCpp as the requested backend ID and cpp as the implementation identity."
  - "Preserve the logical-state payload schema and infer generated numeric update fields from serialized levels when small diagnostics omit postsimulation detail."

patterns-established:
  - "Solve boundaries replace stale diagnostics with a running envelope, then persist the terminal status on success or ordinary failure."
  - "Native solve cleanup and capability outcomes are visible without changing the R orchestration or retaining numeric workspaces."

requirements-completed: [API-02]

coverage:
  - id: D1
    description: "Solve attempts expose stable typed outcomes and replace stale diagnostic state on validation, numerical, postsimulation, and committed-state failures."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-solver-contract.R and tests/testthat/test-transactional-state.R"
        status: pass
      - kind: integration
        ref: "tests/testthat/test-lifecycle-contract.R#solve engine must match the loaded runtime until data is reloaded"
        status: pass
    human_judgment: false
  - id: D2
    description: "Native diagnostics report requested and actual backend identity, capability evidence, effective thread count, and cleanup while disabled diagnostics retain only the small envelope."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-public-cpp-backend.R#public native backend is opt-in and numerically equivalent"
        status: pass
    human_judgment: false
  - id: D3
    description: "The exact small solve envelope survives saveState and loadState without changing the logical-state payload schema."
    requirement: API-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-model-serialization.R#small versioned solve envelope round trips without extra state"
        status: pass
    human_judgment: false

duration: 50min
completed: 2026-09-30
status: complete
---

# Phase 04 Plan 05: Typed Solve Outcomes and Diagnostics Summary

**Solve attempts now retain stable typed outcomes, a small versioned envelope, and opt-in native and solver telemetry.**

## Performance

- **Duration:** About 50 minutes.
- **Started:** 2026-09-30T19:02:36Z.
- **Completed:** 2026-09-30T19:54:11Z.
- **Tasks:** 3.
- **Files modified:** 11 implementation, test, and phase-validation files.

## Accomplishments

- Added stable validation, capability, numerical, postsimulation, retryable-postsimulation, and committed-state condition classes with structured failure fields.
- Made public solve attempts initialize and finalize a schema-version-1 envelope for success and ordinary failure, while keeping detailed evidence opt-in.
- Connected native capability, effective-thread, residual, timing, allocation, memory, and cleanup records to the C++ solve envelope; confirmed numerical factors are released and model-scoped structure remains separate.
- Verified the exact small envelope round-trips through logical-state save/load without changing the payload schema or size contract.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add stable condition classes for solve outcomes** - `1835886` (`feat(04-05): classify solve failure conditions`).
2. **Task 2: Store the small envelope for legacy and R solver paths** - `35c6bf9` (`feat(04-05): add versioned solve diagnostics envelope`).
3. **Task 3: Add native capabilities and cleanup to the detailed envelope** - `dae9966` (`feat(04-05): expose native diagnostics and cleanup`).

## Files Created/Modified

- `R/GEModel.R` - Starts and finalizes public solve envelopes across validation and dispatch.
- `R/sparseSolver.R` - Stores stable transaction statuses and classed failure records for R solver paths.
- `R/zzzSparseSchurCpp.R` - Adds C++ capability, implementation, effective-thread, and cleanup evidence.
- `R/zzzzzSchurDiagnostics.R` - Defines stable envelope fields, status mapping, and optional detail enrichment.
- `R/modelSerialization.R` - Reconstructs generated numeric update fields when the small envelope omits detailed postsimulation evidence.
- Solver, lifecycle, transactional, native, and serialization tests cover failure classes, fresh envelopes, diagnostic levels, native cleanup, and round trips.
- `.planning/phases/04-public-api-and-solver-boundaries/deferred-items.md` - Updates the known Phase 02 source-count gate drift.

## Decisions Made

- Preserve requested C++ backend identity as `StructuredSchurFGMRESCpp` separately from implementation identity `cpp`.
- Keep the stable envelope fixed and small; attach residual and runtime evidence only when diagnostics are requested.
- Preserve the logical-state schema while deriving reconstruction type promotion from serialized values when optional diagnostic detail is absent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserve small-envelope logical-state round trips**
- **Found during:** Task 3 (native capabilities and cleanup evidence).
- **Issue:** Source reconstruction relied on `diagnostics$post_simulation_retained`, which is intentionally absent from the exact small envelope; a generated `reported` field was reconstructed as logical while the serialized value was double.
- **Fix:** For known reconstructed update targets, promote fields whose serialized values are double when detailed postsimulation evidence is absent. The payload field set, schema, and size validation contract remain unchanged.
- **Files modified:** `R/modelSerialization.R`, `tests/testthat/test-model-serialization.R`.
- **Verification:** The small-envelope round-trip test passes in the focused serialization and combined regression runs.
- **Committed in:** `dae9966`.

**2. [Rule 3 - Blocking test contract] Align lifecycle assertions with required solve diagnostics**
- **Found during:** Overall focused regression run.
- **Issue:** Existing engine-mismatch lifecycle assertions required every model field, including `lastDiagnostics`, to remain unchanged, conflicting with this plan's requirement that each attempted solve records its validation outcome.
- **Fix:** Assert all non-diagnostic model state remains unchanged and verify the new validation-failed envelope, requested engine, and primary class.
- **Files modified:** `tests/testthat/test-lifecycle-contract.R`.
- **Verification:** Lifecycle-contract tests pass in the final focused regression run.
- **Committed in:** `dae9966`.

---

**Total deviations:** 2 auto-fixed (one correctness fix and one blocking integration-test contract update).
**Impact on plan:** Both changes were required to preserve the planned serialization and per-attempt diagnostic contracts; no logical-state payload or solver algorithm changes were introduced.

## Issues Encountered

- The planned focused regression command still reports the documented Phase 02 identity-source gate: 391 mixed-case occurrences versus 328 mapped, with the uppercase count unchanged at 2/2. The drift predates Plan 04-03; the reviewed identity map was left unchanged and the deferred item now records the current count.
- The existing `ReferenceClass` assignment warning at `R/GEModel.R:532` remains unchanged.
- The final combined focused run passed lifecycle, native, public-solver, transactional, and serialization behavior except for the identity-source gate above. The command exits nonzero solely for that known gate.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 04-06 can proceed with the versioned solve outcome and diagnostics contract in place. The Phase 02 identity map still needs reconciliation through a separately reviewed baseline change.

## Self-Check: PASSED

- Summary file exists at the planned path.
- All three task commits are present in repository history.
- No tracked files were deleted by the Task 3 commit.

---
*Phase: 04-public-api-and-solver-boundaries*
*Completed: 2026-09-30*
