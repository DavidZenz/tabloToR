---
phase: 02-compatibility-and-numerical-baseline
plan: 05
subsystem: serialization
tags: [R, RDS, reference-classes, safe-deserialization, testthat]

requires:
  - phase: 02-compatibility-and-numerical-baseline
    plan: 04
    provides: Transactionally accepted model state and explicit retry semantics
provides:
  - Versioned gemodel-logical-state schema with portable logical model state
  - Fail-closed envelope and reconstructed-model validation before receiver mutation
  - Fresh-process sparse and legacy restoration with empty derived runtime caches
  - Compatibility-only policy and smoke coverage for raw reference-object RDS
affects: [02-06, compatibility, serialization, solver-reliability, public-api]

actuals:
  tokens: 14115
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - Two-stage safe restoration validates the plain-list envelope and an isolated reconstructed model before installation
    - Source bytes plus logical loaded data and fingerprints rebuild engine runtime without persisting functions, environments, pointers, or caches
    - Fresh-process tests support both source-tree and installed-package execution contexts

key-files:
  created:
    - R/modelSerialization.R
    - tests/testthat/helper-serialization.R
    - tests/testthat/test-model-serialization.R
    - inst/compatibility/SERIALIZATION.md
  modified:
    - R/GEModel.R
    - inst/compatibility/GEModel-contract.csv

key-decisions:
  - "Treat gemodel-logical-state schema version 1L as the only supported portable format; raw GEModel RDS remains same-version compatibility-only."
  - "Validate both the decoded envelope and its source-reconstructed model in isolation before mutating the receiving GEModel."
  - "Rebuild sparse and legacy runtime structures from source while restoring logical values and leaving sparse/native caches empty."

patterns-established:
  - "Fail-closed restore: size/decode/schema/source/shape checks precede receiver installation."
  - "Logical-state persistence: runtime functions, environments, external pointers, factors, workspaces, caches, and transient post-simulation progress are excluded."

requirements-completed: [COMP-03]

coverage:
  - id: D1
    description: Accepted sparse logical state round-trips in a fresh R process and solves again with equivalent accepted state and output structure
    requirement: COMP-03
    verification:
      - kind: e2e
        ref: tests/testthat/test-model-serialization.R#accepted logical state round trips through the versioned payload
        status: pass
    human_judgment: false
  - id: D2
    description: Malformed, incompatible, mismatched, and oversized payloads fail closed without mutating an existing model
    requirement: COMP-03
    verification:
      - kind: integration
        ref: tests/testthat/test-model-serialization.R#malformed logical payloads fail closed before receiver mutation
        status: pass
      - kind: e2e
        ref: tests/testthat/test-model-serialization.R#fresh R processes reject incompatible payloads without mutation
        status: pass
    human_judgment: false
  - id: D3
    description: Restored engine runtime is reconstructed while native and sparse derived caches remain excluded and independently rebuildable
    requirement: COMP-03
    verification:
      - kind: integration
        ref: tests/testthat/test-model-serialization.R#restored runtime cache starts empty and can rebuild independently
        status: pass
      - kind: integration
        ref: tests/testthat/test-model-serialization.R#logical state rebuilds the declared legacy runtime
        status: pass
    human_judgment: false
  - id: D4
    description: Raw reference-object serialization remains explicitly same-version compatibility-only and separate from the portable schema
    requirement: COMP-03
    verification:
      - kind: integration
        ref: tests/testthat/test-model-serialization.R#raw reference serialization remains same-version compatibility-only
        status: pass
    human_judgment: false

duration: 53min
completed: 2026-09-07
status: complete
---

# Phase 02 Plan 05: Portable Logical Serialization Summary

**A versioned logical-state RDS contract now reconstructs sparse and legacy models in fresh processes, rejects malformed state before mutation, and keeps runtime caches and raw reference serialization outside the portable format.**

## Performance

- **Duration:** 53 min
- **Started:** 2026-09-07T12:00:26Z
- **Completed:** 2026-09-07T12:53:20Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added public `saveState(file)` and `loadState(file)` methods around the explicit `gemodel-logical-state` schema version `1L`.
- Added strict allowlists, portable-type and attribute checks, finiteness and allocation limits, source fingerprints, reconstructed closure/shock/level/output validation, and receiver immutability on rejection.
- Proved fresh-process restore and re-solve for sparse state, reconstructed legacy runtime re-solve, empty cache restoration, independent native cache rebuilding, and portable empty/singleton/NULL/encoding semantics.
- Documented raw `saveRDS(model)` as trusted-local, same-version compatibility-only behavior rather than a portable contract.

## Task Commits

Both tasks preserve RED-before-GREEN history:

1. **Task 1 RED: Failing logical serialization contract** - `974482c`
2. **Task 1 GREEN: Portable logical model state** - `152e82d`
3. **Task 2 RED: Failing serialization hardening contract** - `76c78ec`
4. **Task 2 GREEN: Hardened logical state restoration** - `15f0939`

## Files Created/Modified

- `R/modelSerialization.R` - Payload writer, portable validators, isolated source reconstruction, reconstructed-model validation, and safe state installation.
- `R/GEModel.R` - Public save/load methods with regular-file, compressed-size, decode, and invisible-self behavior.
- `inst/compatibility/GEModel-contract.csv` - Supported method rows and internal writer/validator/reconstruction helper rows.
- `inst/compatibility/SERIALIZATION.md` - Normative schema, trust boundary, excluded runtime state, raw compatibility policy, and validation limits.
- `tests/testthat/helper-serialization.R` - Payload/state snapshots plus source-tree and installed-package fresh-process runners.
- `tests/testthat/test-model-serialization.R` - Round-trip, rejection, limits, cache rebuild, portable edge, raw smoke, and legacy reconstruction coverage.

## Decisions Made

- The portable payload is exactly `gemodel-logical-state` schema version `1L`; arbitrary or raw reference-object RDS is not accepted as that contract.
- Validation is staged: the plain-list envelope is validated first, then source is rebuilt into an isolated model and logical state is checked against that model before the receiver changes.
- Sparse state is recreated from logical levels with an empty solver cache; legacy state keeps compiler-generated runtime functions and variable metadata while logical values are restored.
- Source fingerprints detect identity mismatch and accidental corruption, while documentation retains the trusted-local warning because RDS decoding itself is not a security boundary for hostile artifacts.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the scoped Git patch engine after the patch helper failed**
- **Found during:** Plan continuation and Task 2 implementation
- **Issue:** The required patch helper could not create its `bwrap` namespace on this host and failed before reliably applying edits.
- **Fix:** Applied equivalent file-scoped unified patches through `rtk proxy git apply`, reviewed every resulting diff, and ran `git diff --check`.
- **Files modified:** All Plan 02-05 implementation, test, contract, and documentation files.
- **Verification:** Focused and integrated test filters pass; commits contain only the six declared plan files.
- **Committed in:** `974482c`, `152e82d`, `76c78ec`, `15f0939`

**2. [Rule 2 - Missing Critical] Preserved reconstructed legacy runtime required for a subsequent solve**
- **Found during:** Task 2 GREEN legacy engine coverage
- **Issue:** Installing only portable levels discarded compiler-generated legacy functions and variable metadata, so a restored legacy model could not solve again.
- **Fix:** Validated declared mutable legacy fields against the rebuilt model, merged logical values into rebuilt runtime data, and retained reconstructed `variableValues`.
- **Files modified:** `R/modelSerialization.R`, `tests/testthat/test-model-serialization.R`
- **Verification:** The restored legacy fixture matches accepted logical state and completes another finite legacy solve.
- **Committed in:** `15f0939`

**3. [Rule 1 - Bug] Made fresh-process tests work under installed-package checks**
- **Found during:** Task 2 package verification
- **Issue:** Fresh-child helpers assumed `tests/testthat` was running beneath a source tree; `R CMD check` runs copied tests against an installed package.
- **Fix:** Added an installed-namespace bootstrap when source files are absent and resolved policy documentation through `system.file()`.
- **Files modified:** `tests/testthat/helper-serialization.R`, `tests/testthat/test-model-serialization.R`
- **Verification:** The package check improved from 15 failures with five serialization harness failures to the known 10 unrelated provenance/release-gate failures with 1,310 passing expectations.
- **Committed in:** `15f0939`

---

**Total deviations:** 3 auto-fixed (1 blocking tooling issue, 1 missing critical runtime requirement, 1 test-harness bug)
**Impact on plan:** All fixes were required to execute and verify the planned safe restoration contract. No package default, public object name, solver methodology, equation, or numerical tolerance changed.

## Issues Encountered

- `R CMD check --no-manual .` completed with 1 error, 5 warnings, and 4 notes from pre-existing repository state. The test error is the known provenance inventory/release-gate mismatch: 10 failures remain in `test-provenance-inventory.R` and `test-release-gates.R`, while all serialization tests pass and 1,310 expectations pass overall.
- Existing warnings/notes cover generated native objects, check/hidden directories, non-portable benchmark paths, broad undocumented exports, placeholder license metadata, and compiled-code inspection.
- The pre-existing reference-class warning about local assignment to `data$eqcoeff` remains unchanged.

## Verification

- `testthat::test_local(filter = "model-serialization|compatibility-manifest|sparse-cpp-cache", reporter = "summary")` - PASS.
- `testthat::test_local(filter = "documented-workflow|public-solver-contract|transactional-state|compatibility-values", reporter = "summary")` - PASS.
- Manual restored-legacy re-solve probe - PASS with finite solution.
- `R CMD check --no-manual .` - EXECUTED; all Plan 02-05 serialization tests pass, while the documented unrelated provenance/release-gate baseline leaves the package-wide check non-zero.

## TDD Gate Compliance

- Task 1: `974482c` RED precedes `152e82d` GREEN.
- Task 2: `76c78ec` RED precedes `15f0939` GREEN.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02-06 can exercise the versioned state format in the integrated compatibility and numerical release gate.
- Fresh-process behavior is covered in both source-tree and installed-package test contexts.
- No new release blocker was introduced; the pre-existing provenance, package-structure, documentation, and licensing blockers remain unchanged.

---
*Phase: 02-compatibility-and-numerical-baseline*
*Completed: 2026-09-07*

## Self-Check: PASSED

All seven key artifacts and all four task commits were verified on disk.
