---
phase: 04-public-api-and-solver-boundaries
reviewed: 2026-10-01T07:33:22Z
depth: standard
files_reviewed: 20
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
  - tests/testthat/test-compatibility-helpers.R
  - tests/testthat/test-compatibility-manifest.R
  - tests/testthat/test-documented-workflow.R
  - tests/testthat/test-lifecycle-contract.R
  - tests/testthat/test-model-serialization.R
  - tests/testthat/test-public-cpp-backend.R
  - tests/testthat/test-public-solver-contract.R
  - tests/testthat/test-sparse-core.R
  - tests/testthat/test-transactional-state.R
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-10-01T07:33:22Z
**Depth:** standard
**Files Reviewed:** 20
**Status:** issues_found

## Narrative Findings (AI reviewer)

The previous shock-label injection, residual-overflow acceptance, duplicate-step extrapolation, checkpoint replacement, legacy output-selector, and solve-flag findings were rechecked in the live code. Their reported paths now fail closed or preserve the prior checkpoint. `DESCRIPTION` retains the pending license placeholder required by `docs/provenance/LICENSE-DECISION.md`; it is not reported as a new finding. The sparse-core fixture changes exercise the public load lifecycle.

### Critical Issues

#### CR-05: Invalid closure input partially mutates the model

**Severity:** BLOCKER  
**File:** `R/sparseSolver.R:1080-1084` (called by `R/GEModel.R:461-466`)

**Issue:** `sparse_set_closure_state()` assigns the normalized input to `model$closure` before calling `sparse_rebuild_columns()`. The latter rejects closure names absent from the compiled index. When a caller supplies an unknown variable, the setter errors after changing `closure`; `GEModel$setClosure()` therefore never reaches the lines that clear `solution`, `compactOutput`, retry state, and diagnostics. The model is left with a new invalid closure, the old index, and stale accepted output.

**Fix:** Validate closure names against the compiled TABLO variables and build the replacement index in local variables before mutating model fields. Publish the closure and index only after validation and rebuilding succeed, so a rejected call preserves the entire prior model state. Apply the same name validation when the legacy engine has no sparse index.

---

_Reviewed: 2026-10-01T07:33:22Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
