---
phase: 04-public-api-and-solver-boundaries
reviewed: 2026-09-30T20:41:09Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - DESCRIPTION
  - NAMESPACE
  - R/GEModel.R
  - R/apiDocumentation.R
  - R/modelSerialization.R
  - R/sparseSolver.R
  - R/zzzSparseSchurCpp.R
  - R/zzzzzSchurDiagnostics.R
  - man/GEModel.Rd
  - man/GEModelR-package.Rd
  - tests/testthat/test-api-documentation.R
  - tests/testthat/test-compatibility-manifest.R
  - tests/testthat/test-documented-workflow.R
  - tests/testthat/test-lifecycle-contract.R
  - tests/testthat/test-model-serialization.R
  - tests/testthat/test-public-cpp-backend.R
  - tests/testthat/test-public-solver-contract.R
  - tests/testthat/test-transactional-state.R
findings:
  critical: 4
  warning: 3
  info: 0
  total: 7
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-09-30T20:41:09Z  
**Depth:** standard  
**Files Reviewed:** 18  
**Status:** issues_found

## Summary

The public API, lifecycle and serialization boundaries, sparse backend adapters, diagnostics, generated help, and scoped tests were reviewed. Four blockers affect process safety, numerical acceptance, or saved-state integrity. Three warnings concern silently ignored or insufficiently validated public inputs and package metadata.

## Critical Issues

### CR-01: Shock labels can execute arbitrary R code in the legacy solver

**Severity:** BLOCKER  
**File:** `R/GEModel.R:810-812` (`setShocks()` also accepts labels in `R/sparseSolver.R:964-990`)

**Issue:** `sparse_normalize_shocks()` accepts any non-empty shock label, and the legacy solver interpolates each label into a string passed to `eval(parse())`. A caller can supply a label containing additional R statements through the public `setShocks()` method; those statements execute when `solveModel(engine = "legacy")` applies the shocks. This is an R code injection path.

**Fix:** Remove `eval(parse())` from shock application. Parse each shock label with the model's label parser, verify it names a declared variable/index, and update the resolved data position directly. Reject labels that do not resolve to a model reference before changing state.

### CR-02: Overflow in the residual norm can let an incorrect sparse solution pass

**Severity:** BLOCKER  
**File:** `R/sparseSolver.R:2156-2165, 2234-2238`

**Issue:** `sparse_true_residual()` computes Euclidean norms by squaring values and summing them. Finite values around `1e200` overflow when squared, so both the residual norm and right-hand-side norm can become `Inf`; their ratio is then `NaN`. The acceptance check rejects only when `relative_l2 > residual_tolerance`, and comparisons with `NaN` are false, so a candidate with a large true residual can be marked accepted.

**Fix:** Compute the relative norm with scaling to avoid overflow and explicitly reject non-finite residual metrics before comparing them with the tolerance. Also reject a non-finite `A %*% solution` or residual.

### CR-03: Duplicate Euler step counts produce a committed non-finite solution

**Severity:** BLOCKER  
**File:** `R/sparseSolver.R:2621-2624, 3239-3242` (`R/GEModel.R:851-855` has the same legacy extrapolation)

**Issue:** The sparse argument check accepts duplicate positive step counts. With `steps = c(1, 1)`, `sparse_extrapolate_steps()` divides by zero; the resulting `NaN` is not checked after extrapolation and is carried into the accepted model state. The legacy path has the same zero denominator and lacks the sparse path's positive-integer validation.

**Fix:** Validate `iter` and `steps` before dispatch for both engines. Require a supported number of positive integer step counts and distinct counts for the values used as the extrapolation denominator. Check the extrapolated and accumulated solution for finiteness before applying or committing it.

### CR-04: A failed `saveState()` write can destroy the previous checkpoint

**Severity:** BLOCKER  
**File:** `R/GEModel.R:479-486`

**Issue:** `saveState()` writes directly to the destination with `saveRDS()`. When that path already contains a valid state file, an I/O error or interruption after the file is opened can leave it truncated or partially written, losing the previous checkpoint.

**Fix:** Write the complete payload to a temporary file in the destination directory, close it successfully, and then atomically replace the destination. Remove the temporary file on every failure path and leave the existing destination intact unless replacement succeeds.

## Warnings

### WR-01: Compact-output selectors are silently ignored by legacy solves

**Severity:** WARNING  
**File:** `R/GEModel.R:619-627, 628-689`; public output-mode description in `R/apiDocumentation.R:68-73`

**Issue:** `solveModel()` dispatches `output`, `variables`, and `dimensions` only on the sparse branch. A legacy call with `output = "compact"` or selectors proceeds through the legacy solve without validation or projection, leaving full `data` and no compact projection even though the public help describes compact output as a `solveModel()` mode.

**Fix:** Either implement the documented projection for legacy solves or reject compact/selective output for that engine with a validation condition and document the engine restriction.

### WR-02: `solveModel()` silently coerces invalid `postsim` and `diagnostics` values to false

**Severity:** WARNING  
**File:** `R/GEModel.R:595-618`; sparse use at `R/sparseSolver.R:3458-3487, 3554-3582`

**Issue:** Unlike `estimateMemory()` and `retryPostsim()`, `solveModel()` does not require these flags to be one non-missing logical value. Values such as `1`, `NA`, or a character string reach `isTRUE()` checks and silently disable postsimulation or detailed diagnostics instead of reporting an invalid argument.

**Fix:** Validate both flags at the public `solveModel()` boundary before engine dispatch, and return the same structured validation condition used by the other public methods.

### WR-03: DESCRIPTION still contains a placeholder license declaration

**Severity:** WARNING  
**File:** `DESCRIPTION:18`

**Issue:** `License: What license is it under?` is not a usable package license declaration and produces a package-check warning. Users and downstream distributors cannot determine the terms under which the package is provided.

**Fix:** Replace the placeholder with the project's actual approved license identifier and include the corresponding license file or required license metadata.

---

_Reviewed: 2026-09-30T20:41:09Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
