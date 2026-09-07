---
phase: 02-compatibility-and-numerical-baseline
reviewed: 2026-09-07T15:39:54Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - R/GEModel.R
  - R/sparseSolver.R
  - R/zzzSparseSchurCpp.R
  - R/modelSerialization.R
  - tools/refresh_phase02_baselines.R
  - tools/accept_phase02_baselines.R
  - inst/tools/refresh_phase02_baselines.R
  - inst/tools/accept_phase02_baselines.R
  - inst/compatibility/GEModel-contract.csv
  - inst/compatibility/WORKFLOWS.md
  - inst/compatibility/FAILURE-SEMANTICS.md
  - inst/compatibility/SERIALIZATION.md
  - inst/compatibility/BASELINE-PROCESS.md
  - tests/testthat/helper-compatibility.R
  - tests/testthat/helper-three-region.R
  - tests/testthat/helper-numerical-baseline.R
  - tests/testthat/helper-transactional-state.R
  - tests/testthat/helper-serialization.R
  - tests/testthat/test-compatibility-manifest.R
  - tests/testthat/test-compatibility-helpers.R
  - tests/testthat/test-documented-workflow.R
  - tests/testthat/test-numerical-baseline.R
  - tests/testthat/test-transactional-state.R
  - tests/testthat/test-model-serialization.R
  - tests/testthat/test-baseline-artifacts.R
  - tests/testthat/fixtures/three-region.tab
  - tests/testthat/fixtures/PROVENANCE.md
  - tests/testthat/baselines/phase02/expectations.csv
  - tests/testthat/baselines/phase02/tolerances.csv
  - tests/testthat/baselines/phase02/fingerprints.dcf
  - tests/testthat/baselines/phase02/ACCEPTANCE.md
findings:
  critical: 5
  warning: 3
  info: 0
  total: 8
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-09-07T15:39:54Z  
**Depth:** standard  
**Files Reviewed:** 31  
**Status:** issues_found

## Summary

The Phase 02 compatibility, numerical, transactional, serialization, and baseline artifacts were reviewed against all six PLAN/SUMMARY pairs. Five release-blocking correctness or integrity defects and three robustness defects were found. Targeted reproductions confirmed that the C++ backend mutates live cache state before acceptance, malformed public output survives logical-state restoration, C++ post failures report the wrong backend, and the acceptance tool approves a self-consistent proposal carrying a forged source fingerprint.

The focused Phase 02 test matrix passed, and `tools/refresh_phase02_baselines.R --check` reported no stable drift. `R CMD check .` reached 1,328 passes and six explicit skips, then failed on the 10 known Phase 1 provenance/release-gate mismatches. The existing GEModel reference-class warning was observed but is not counted here, as requested.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01 — BLOCKER: Native cache writes escape the sparse solve transaction

**File:** `/home/zenz/R/tabloToR/R/zzzSparseSchurCpp.R:141-205` (live-state selection at lines 590-592)

**Issue:** The C++ wrapper stores `model$sparseState` in the process-global runtime before the transactional solver creates its private working state. `.sparse_cpp_pattern_entry()` then writes the new structural cache through that live environment. A residual failure therefore leaves `model$sparseState$.solver_cache` changed even though no candidate was accepted, contradicting `FAILURE-SEMANTICS.md`. A targeted residual-failure probe changed the cache from empty to `StructuredSchurFGMRESCpp`. The transactional snapshot helper also serializes only `sparse_state_data(model$sparseState)`, so the current failure matrix cannot see this leak.

**Fix:** Bind the C++ runtime cache owner to the `state` argument received by the overridden one-step function, not to `model$sparseState`, and restore the prior runtime binding on exit. Extend transactional snapshots and C++ failure tests to include `.solver_cache`.

```r
sparse_solve_one_step = function(state, model, index, shocks, backend,
                                 reduction, measure = FALSE,
                                 structured_partition = NULL) {
  old_state = .sparse_schur_cpp_runtime$state
  if (isTRUE(.sparse_schur_cpp_runtime$active)) {
    .sparse_schur_cpp_runtime$state = state
    on.exit(.sparse_schur_cpp_runtime$state = old_state, add = TRUE)
  }
  # Build and accept the candidate against the private state.
  # ...
}
```

#### CR-02 — BLOCKER: Restore silently installs malformed accepted output

**File:** `/home/zenz/R/tabloToR/R/modelSerialization.R:564-575` (installation at lines 615-618)

**Issue:** Accepted data fields are validated only when their dimensions already match the corresponding level. A dimension mismatch takes the false branch and performs no validation at all; restoration then assigns the unvalidated `payload$accepted$data` to the model. A targeted probe replaced the three-element `stock` array with scalar character value `"CORRUPTED"`; `loadState()` succeeded and exposed that value through `model$data$stock`. Compact outputs receive similarly incomplete validation. This violates the fail-closed type/dimension contract and permits internally inconsistent restored state.

**Fix:** Reject every structure mismatch instead of skipping it, validate every accepted data/compact-output field against a reconstructed template, and require `compact_output$solution` to be structurally and numerically identical to the accepted solution. Add malformed accepted-data and compact-output cases to `test-model-serialization.R`.

```r
for (field in intersect(names(payload$accepted$data), level_fields)) {
  .serialization_validate_structure(
    payload$accepted$data[[field]],
    payload$levels[[field]],
    paste0("accepted data$", field)
  )
}
```

#### CR-03 — BLOCKER: Canonical acceptance is not bound to the current source or reviewed run evidence

**File:** `/home/zenz/R/tabloToR/inst/tools/accept_phase02_baselines.R:62-115`

**Issue:** Acceptance checks only a proposal's self-declared aggregate hash and a diff derived from the same proposal. It never recomputes `Source-Fingerprint`, fixture/model signatures, or stable expectations from the current repository, and `run-metadata.dcf` is not included in any accepted hash. A stale or edited proposal can therefore be made self-consistent and accepted after source changes. A targeted dry-run changed `Source-Fingerprint` to 32 zeroes, updated the proposal's own hash and diff, and `phase02_accept_proposal()` accepted it and generated an acceptance record containing the forged fingerprint. This defeats the review gate's source/provenance binding.

**Fix:** During acceptance, regenerate a fresh proposal from the current repository into a temporary directory and require its stable artifact hash and source/model/fixture identities to match the reviewed proposal. Validate each artifact with the same schema loaders used by tests. Hash `run-metadata.dcf` separately in `proposal.dcf` and record that evidence hash in `ACCEPTANCE.md` without adding volatile data to the canonical stable hash.

```r
current = tempfile("phase02-current-")
on.exit(unlink(current, recursive = TRUE, force = TRUE), add = TRUE)
regenerated = phase02_generate_proposal(current, canonical_dir)
if (!identical(regenerated$proposal_hash, validated$hash)) {
  stop("Proposal no longer matches the current source and model", call. = FALSE)
}
```

#### CR-04 — BLOCKER: Valid case-insensitive shock labels cannot round-trip

**File:** `/home/zenz/R/tabloToR/R/modelSerialization.R:513-518`

**Issue:** Runtime shock parsing lowercases the variable name, so `TAX[north]` is a valid shock for closure `tax` and solves successfully. Restore validation instead extracts the raw prefix with `sub()` and compares it case-sensitively to the normalized closure. A targeted accepted-state round trip saved successfully but `loadState()` rejected it as outside the closure. The supported serializer therefore fails on state accepted by the public shock API.

**Fix:** Parse shock labels with the same canonical parser used by the solver and compare canonical names. Add round-trip coverage for uppercase and whitespace/quote variants.

```r
shock_variables = vapply(
  payload$shocks$labels,
  function(label) sparse_parse_label(label)$name,
  character(1)
)
```

#### CR-05 — BLOCKER: C++ post failures and retries record the wrong backend

**File:** `/home/zenz/R/tabloToR/R/zzzSparseSchurCpp.R:601-618`

**Issue:** The wrapper invokes the inner solver as `StructuredSchurFGMRES` and rewrites diagnostics to `StructuredSchurFGMRESCpp` only after the entire call returns. If numerical acceptance succeeds but post-simulation fails, the inner call throws before the rewrite. Both `lastDiagnostics$solver_backend` and the retry record then claim the R backend performed the accepted solve. A targeted `post-update` failure reproduced both values as `StructuredSchurFGMRES`, corrupting numerical provenance across the retry boundary.

**Fix:** Carry a distinct requested/implementation backend into `.sparse_solve_model_impl()` and populate diagnostics and the retry record before `.commit_accepted_state()`. Do not defer provenance rewriting until after post-simulation. Add C++ post-update/output-projection failure and retry assertions.

```r
diagnostics_result$solver_backend = requested_backend
diagnostics_result$solver_backend_impl = if (
  identical(requested_backend, "StructuredSchurFGMRESCpp")
) "cpp" else "r"
```

### Warnings

#### WR-01 — WARNING: The serialization size limit runs after unbounded RDS expansion

**File:** `/home/zenz/R/tabloToR/R/GEModel.R:177-190` (post-decode check at `/home/zenz/R/tabloToR/R/modelSerialization.R:399-403`)

**Issue:** `loadState()` limits only the compressed file size before `readRDS()`. A highly compressible or corrupt RDS can allocate far more than `tabloToR.serialization.max_bytes` during decoding, before element and in-memory byte checks execute. The trusted-local warning narrows the threat boundary, but the implementation still does not provide the documented pre-allocation protection against oversized/corrupt local artifacts.

**Fix:** Treat RDS decoding as unbounded and perform it in a resource-limited child process, or adopt a format with a small validated header and streamable bounded fields. At minimum, document that the option limits compressed input only and add a compressed-expansion regression/resource test.

#### WR-02 — WARNING: Path containment checks are not portable to Windows

**File:** `/home/zenz/R/tabloToR/inst/tools/refresh_phase02_baselines.R:51-55`

**Issue:** `phase02_path_contains()` appends a literal `/`, while `normalizePath()` uses backslashes by default on Windows. Ancestor/descendant checks therefore fail there unless paths are exactly equal, allowing proposal and acceptance directories inside or above the canonical baseline despite the documented overlap prohibition.

**Fix:** Normalize separators explicitly and account for case-insensitive Windows paths before comparing path-component prefixes; add platform-independent unit cases for equal, child, sibling, and ancestor paths.

```r
normalize_key = function(path) {
  value = normalizePath(path, winslash = "/", mustWork = FALSE)
  if (.Platform$OS.type == "windows") tolower(value) else value
}
```

#### WR-03 — WARNING: Canonical replacement is rollback-assisted but not atomic or locked

**File:** `/home/zenz/R/tabloToR/inst/tools/accept_phase02_baselines.R:196-233`

**Issue:** The three canonical artifacts are overwritten sequentially and `ACCEPTANCE.md` is renamed afterward. `on.exit()` can recover from ordinary R errors, but process termination between copies leaves a mixed canonical set; concurrent acceptance processes can also race and restore over one another. This makes the sole canonical mutator less robust than its staged design suggests.

**Fix:** Acquire an exclusive lock beside the canonical directory and publish a fully verified staged directory with a same-filesystem directory rename/swap. Keep the old directory under a recoverable backup name until the new directory and acceptance record are verified. Add injected mid-publication failure and concurrent-lock tests.

---

_Reviewed: 2026-09-07T15:39:54Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
