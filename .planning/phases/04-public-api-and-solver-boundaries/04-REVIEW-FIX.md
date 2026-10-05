---
phase: 04-public-api-and-solver-boundaries
fixed_at: 2026-10-01T07:44:41Z
review_path: .planning/phases/04-public-api-and-solver-boundaries/04-REVIEW.md
iteration: 2
findings_in_scope: 8
fixed: 7
skipped: 1
status: partial
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-10-01T07:44:41Z

**Source review:** `.planning/phases/04-public-api-and-solver-boundaries/04-REVIEW.md`  
**Iteration:** 2

**Summary:**
- Findings in scope: 8
- Fixed: 7
- Skipped: 1

## Fixed Issues

### CR-01: Shock labels can execute arbitrary R code in the legacy solver

**Files modified:** `R/GEModel.R`, `tests/testthat/test-public-solver-contract.R`  
**Commit:** `c0cbc84`  
**Applied fix:** Removed `eval(parse())` shock assignment. Shock labels are parsed and resolved against declared model references before state changes. The focused malicious-label regression test passed.

### CR-02: Overflow in the residual norm can let an incorrect sparse solution pass

**Files modified:** `R/sparseSolver.R`, `tests/testthat/test-public-solver-contract.R`  
**Commit:** `e16942d`  
**Applied fix:** Residual norms now use scaled calculations; non-finite products, residuals, and metrics are rejected before candidate acceptance. The focused large-magnitude and overflow regression tests passed.

### CR-03: Duplicate Euler step counts produce a committed non-finite solution

**Files modified:** `R/GEModel.R`, `R/sparseSolver.R`, `tests/testthat/test-public-solver-contract.R`  
**Commit:** `85a5d0e`  
**Applied fix:** Both engines validate one to three distinct positive integer step counts. Extrapolated and accumulated candidates must remain finite before acceptance or commit. The focused tests for both engines and non-finite candidates passed.

### CR-04: A failed `saveState()` write can destroy the previous checkpoint

**Files modified:** `R/GEModel.R`, `R/modelSerialization.R`, `tests/testthat/test-model-serialization.R`  
**Commit:** `88fcc12`  
**Applied fix:** State is saved to a temporary file in the target directory and replaces the existing file only after a successful write. The new failed-replacement test confirmed that the prior checkpoint bytes and payload remain intact and that temporary files are removed. This test passed; the same test file still has the separate Phase 02 identity-map failure recorded under verification below.

### CR-05: Invalid closure input partially mutates the model

**Files modified:** `R/sparseSolver.R`, `tests/testthat/test-lifecycle-contract.R`

**Commit:** `6bfbb97`

**Status:** fixed: requires human verification

**Applied fix:** Closure names are validated against the compiled TABLO variables for sparse and legacy models. Sparse columns are rebuilt in a local replacement index before either model field is changed, so rejected closures preserve the full prior state. Regression coverage snapshots both engines after solving, including sparse retry state, and verifies a valid closure update still rebuilds the sparse index.

### WR-01: Compact-output selectors are silently ignored by legacy solves

**Files modified:** `R/GEModel.R`, `R/apiDocumentation.R`, `man/GEModelR-package.Rd`, `tests/testthat/test-public-solver-contract.R`, `tests/testthat/test-api-documentation.R`  
**Commit:** `6049a2e`  
**Applied fix:** Legacy solves now raise a structured validation error for compact output and variable/dimension selectors. Generated help explains that these options require the sparse engine. Focused solver-contract and API-documentation tests passed.

### WR-02: `solveModel()` silently coerces invalid `postsim` and `diagnostics` values to false

**Files modified:** `R/GEModel.R`, `tests/testthat/test-public-solver-contract.R`  
**Commit:** `d7b4b77`  
**Applied fix:** The public solve boundary now requires each flag to be one non-missing logical value before dispatch. Tests for numeric, missing, character, and vector values passed for both engines.

## Regression Follow-ups

### Phase 04 dimension-name regression

**Files modified:** `R/sparseSolver.R`  
**Commit:** `9e9966a`  
**Applied fix:** Restored names on output dimensions that the Phase 04 implementation had dropped. The focused `compatibility-helpers` tests passed. The mismatch was attributable to Phase 04 because that implementation removed the dimension names; the regression fix restores them.

### Sparse-core lifecycle fixtures

**Files modified:** `tests/testthat/test-sparse-core.R`  
**Commit:** `4d3718a`  
**Applied fix:** Sparse-core fixtures that failed lifecycle preconditions now build/load models through the public load workflow. Focused `sparse-core` tests passed.

## Skipped Issues

### WR-03: DESCRIPTION still contains a placeholder license declaration

**File:** `DESCRIPTION:18`  
**Reason:** Deferred under `docs/provenance/LICENSE-DECISION.md`. Its canonical status is pending; `Description-License` must remain exactly `What license is it under?` to match `DESCRIPTION`. A license transition is blocked until the dependency compatibility audit artifact and checksum, reviewer, review date, and reviewed transition predicates are complete. No license was selected or changed.  
**Original issue:** `License: What license is it under?` is a placeholder that produces a package-check warning and leaves distribution terms unclear.

## Verification

Iteration 2 focused verification ran in the isolated review-fix worktree. The combined `lifecycle-contract`, `documented-workflow`, `public-solver-contract`, and `sparse-core` groups passed with 746 assertions and no test failures, warnings, or skips. R parsing for both modified files and `git diff --check` also passed. A post-fix code review covered 20 files and reported zero findings; CR-01–CR-05 and WR-01–WR-02 are closed.

The post-fix full source suite completed but exited nonzero on the separate Phase 02 identity-map drift: `package-mixed-case=416/328` (`package-upper-case=2/2`). Phase 02 CLI warnings and the existing `GEModel$generateSolution()` ReferenceClass field-assignment warning also appeared. No Phase 04 test failure was reported.

The post-fix `R CMD check .` passed package installation, namespace, R-code, and documentation checks. Its test phase reported 19 failures, 2,364 passes, and 65 skips. Failures were in benchmark-correctness gates (4), installed benchmark execution (2; source-tree availability), provenance inventory (4), and release gates (9; stale or duplicate provenance keys). The check ended with 1 ERROR, 4 WARNINGs, and 4 NOTEs. Warnings covered generated object files/executables, nested check directories, and nonportable paths; notes included hidden files, the pending license declaration, LazyData without a data directory, and compiled-code findings.

An earlier focused run covered `compatibility-helpers`, `sparse-core`, `public-solver-contract`, `model-serialization`, `transactional-state`, and `api-documentation`. It hit this known Phase 02 migration-source gate:

`tests/testthat/test-model-serialization.R:147` — `Identity mapping row is stale or count drifted: package-mixed-case=416/328,package-upper-case=2/2`.

The Phase 02 provenance/identity map was left untouched. No license metadata was changed; its decision remains pending under `docs/provenance/LICENSE-DECISION.md`.

---

_Fixed: 2026-10-01T07:44:41Z_

_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 2_
