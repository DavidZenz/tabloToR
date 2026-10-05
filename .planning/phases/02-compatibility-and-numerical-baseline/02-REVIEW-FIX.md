---
phase: 02-compatibility-and-numerical-baseline
fixed_at: 2026-09-09T09:56:51+02:00
review_path: .planning/phases/02-compatibility-and-numerical-baseline/02-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-09-09T09:56:51+02:00
**Source review:** .planning/phases/02-compatibility-and-numerical-baseline/02-REVIEW.md
**Iteration:** 1

**Summary:**

- Findings in scope: 8
- Fixed: 8
- Skipped: 0
- Cross-phase regression repaired: Phase 1 provenance inventory/release gate
- Verification location: current main checkout (worktrees explicitly disabled)

## Fixed Issues

### CR-01: Native cache writes escape the sparse solve transaction

**Status:** Fixed — requires human verification
**Files modified:** `R/zzzSparseSchurCpp.R`, `tests/testthat/helper-transactional-state.R`, `tests/testthat/test-transactional-state.R`
**Commit:** 16f11b2
**Applied fix:** Bound native cache ownership to the private transaction state, restored the runtime binding on exit, and included solver caches in failure snapshots and C++ residual-rejection coverage.

### CR-02: Restore silently installs malformed accepted output

**Status:** Fixed — requires human verification
**Files modified:** `R/modelSerialization.R`, `tests/testthat/test-model-serialization.R`
**Commit:** 1210dfe
**Applied fix:** Validated every accepted data and compact-output field against reconstructed templates and required compact solutions to be identical to the accepted solution.

### CR-03: Canonical acceptance is not bound to current source or reviewed run evidence

**Status:** Fixed — requires human verification
**Files modified:** `inst/tools/refresh_phase02_baselines.R`, `inst/tools/accept_phase02_baselines.R`, `inst/compatibility/BASELINE-PROCESS.md`, `tests/testthat/test-baseline-artifacts.R`
**Commit:** d17eebf
**Applied fix:** Added proposal schema v2, separately hashed run metadata, artifact schema checks, and acceptance-time regeneration against current source/model identities.

### CR-04: Valid case-insensitive shock labels cannot round-trip

**Status:** Fixed — requires human verification
**Files modified:** `R/modelSerialization.R`, `tests/testthat/test-model-serialization.R`
**Commit:** 136ff5d
**Applied fix:** Canonicalized restored shock labels with the solver parser and covered uppercase, whitespace, and quote variants.

### CR-05: C++ post failures and retries record the wrong backend

**Status:** Fixed — requires human verification
**Files modified:** `R/sparseSolver.R`, `tests/testthat/test-transactional-state.R`
**Commit:** 0bd0ca6
**Applied fix:** Recorded requested backend and implementation before accepted-state commit, preserving native provenance across post failures and retries.

### WR-01: Serialization size limit runs after unbounded RDS expansion

**Status:** Fixed
**Files modified:** `inst/compatibility/SERIALIZATION.md`, `tests/testthat/test-model-serialization.R`
**Commit:** a54ce95
**Applied fix:** Documented the trusted-local compressed-input boundary and post-decode logical/object limits, with a highly compressible RDS expansion regression that proves fail-closed receiver behavior.

### WR-02: Path containment checks are not portable to Windows

**Status:** Fixed — requires human verification
**Files modified:** `inst/tools/refresh_phase02_baselines.R`, `tests/testthat/test-baseline-artifacts.R`
**Commit:** b216bb7
**Applied fix:** Normalized separators with `winslash = "/"`, folded case on Windows, and tested equal, child, sibling, and ancestor relationships.

### WR-03: Canonical replacement is rollback-assisted but not atomic or locked

**Status:** Fixed — requires human verification
**Files modified:** `inst/tools/accept_phase02_baselines.R`, `inst/compatibility/BASELINE-PROCESS.md`, `tests/testthat/test-baseline-artifacts.R`
**Commit:** 9058521
**Applied fix:** Added an exclusive sibling lock, complete staged directory publication, recoverable backup swap, post-swap verification, rollback, and injected lock/mid-publication tests.

## Cross-Phase Regression Repair

### Phase 1 provenance inventory and release gate

**Files modified:** `docs/provenance/EXPECTED-KEYS.csv`, `docs/provenance/PROVENANCE.csv`, `docs/provenance/INVENTORY-REVIEW.csv`, `docs/provenance/ATTRIBUTION.md`, `tests/testthat/test-provenance-inventory.R`
**Commit:** 3f286a8
**Applied fix:** Rebuilt the exact reviewed inventory at 280 entries, preserved prior decisions, explicitly reviewed 30 additions and 9 changed expression hashes, rebound attribution to the new ledger MD5, and retained exact-key/hash fail-closed checks.

## Verification

Focused tests passed for every finding:

- CR-01: transactional-state C++ cache rejection coverage.
- CR-02: complete model-serialization filter.
- CR-03: source-bound acceptance, safe commit/dry-run, and stable/volatile fingerprint separation.
- CR-04: case-insensitive shock-label round trip.
- CR-05: native backend provenance across post failure and retry.
- WR-01: compressed RDS expansion rejection.
- WR-02: portable path-containment matrix.
- WR-03: concurrent lock, injected rollback, and normal safe publication.
- Provenance repair: inventory checker, historical native hash review, and Phase 02 inventory-review regression.

The complete Phase 02 integrated filter ran in the main checkout. All behavioral suites passed; three baseline-artifact assertions failed only because the legitimate source fingerprint changed from `4b42d701c21b8b40ac9c22329400ce84` to `f57c39e0bdd3020b48a602773c580a8d`, which also changes the package signature.

The prior Phase 1 filter `release-gates|provenance-inventory|name-availability|attribution-contract` passed completely. The read-only baseline check failed only on the same two fingerprint keys.

## Required Human Checkpoint

Canonical baselines were not changed or self-accepted. A review-gated proposal was generated at:

`.planning/phases/02-compatibility-and-numerical-baseline/02-review-fix-baseline-proposal`

**Proposal hash:** `f6f2297a6ab257c9737a64354c82d7f1`

A human reviewer must inspect all six proposal artifacts and accept them with the documented `tools/accept_phase02_baselines.R` workflow. After acceptance, rerun the complete Phase 02 integrated filter and read-only baseline check.

## Skipped Issues

None.

---

_Fixed: 2026-09-09T09:56:51+02:00_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
