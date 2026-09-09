---
phase: 03
slug: gemodelr-identity-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-09
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2, edition 3 |
| **Config file** | `DESCRIPTION`; launcher `tests/testthat.R` |
| **Quick run command** | `rtk R --vanilla -q -e 'testthat::test_local(filter = "identity-migration|model-serialization|public-solver-contract", reporter = "summary")'` |
| **Baseline command** | `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check` |
| **Full suite command** | `rtk R --vanilla -q -e 'testthat::test_local(reporter = "summary")'` |
| **Package gate** | Clean temporary source copy: `R CMD build`, `R CMD check`, isolated `R CMD INSTALL`, then fresh-process workflow and DLL inspection |
| **Estimated runtime** | Under 60 seconds focused; full package gate varies by host |

## Sampling Rate

- **After every task commit:** Run the focused identity/serialization/solver-contract filter and the read-only Phase 2 baseline check.
- **After native regeneration tasks:** Also inspect registered routines and run an isolated fresh-process native smoke test.
- **After every plan wave:** Run the complete testthat suite.
- **Before `$gsd-verify-work`:** Run the clean build/check/install gate, identity audit, complete tests, and Phase 2 baseline check.
- **Max feedback latency:** 60 seconds for focused tests; longer package checks run only at wave and phase gates.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 03-01 | 1 | MIGR-01, MIGR-02 | T-03-01, T-03-02 | Predecessor lineage is explicit and accepted evidence remains immutable | serialization/artifact | `rtk R --vanilla -q -e 'testthat::test_local(filter="identity-migration|model-serialization", reporter="summary")'` | ❌ W0 | ⬜ pending |
| 03-01-02 | 03-01 | 1 | MIGR-02 | T-03-03 | Phase 2 baseline digests and behavior are frozen before rename | differential regression | `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check` | Partial | ⬜ pending |
| 03-02-01 | 03-02 | 2 | COMP-04, MIGR-01 | T-03-04 | Package and documentation identity migrate without unsupported predecessor references | contract | `rtk R --vanilla -q -e 'testthat::test_local(filter="identity-migration", reporter="summary")'` | ❌ W0 | ⬜ pending |
| 03-02-02 | 03-02 | 2 | COMP-04, MIGR-01 | T-03-05 | Every old public option fails before mutation with exact replacement guidance | option matrix | `rtk R --vanilla -q -e 'testthat::test_local(filter="identity-migration|transactional-state", reporter="summary")'` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03-03 | 3 | MIGR-01, MIGR-02 | T-03-01, T-03-02 | Current and reviewed predecessor logical states validate in isolation; malformed lineage never mutates the receiver | serialization integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="model-serialization|identity-migration", reporter="summary")'` | ❌ W0 | ⬜ pending |
| 03-04-01 | 03-04 | 4 | MIGR-01, MIGR-02 | T-03-06 | Only GEModelR DLL and registered native routines load; dynamic lookup stays disabled | native/installed integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="identity-migration|public-cpp-backend|sparse-lu-cpp|sparse-schur-cpp", reporter="summary")'` | ❌ W0 | ⬜ pending |
| 03-05-01 | 03-05 | 5 | MIGR-01, MIGR-02 | T-03-03, T-03-07 | Historical records retain predecessor bytes while active producers report GEModelR | artifact audit | `rtk Rscript --vanilla tools/check_identity_migration.R` | ❌ W0 | ⬜ pending |
| 03-06-01 | 03-06 | 6 | COMP-04, MIGR-01, MIGR-02 | T-03-01–T-03-07 | Clean source, archive, installation, workflow, serialization, diagnostics, and numerical baseline all satisfy the migration contract | package/integration | `rtk R --vanilla -q -e 'testthat::test_local(reporter="summary")'` plus clean build/check/install gate | ❌ W0 | ⬜ pending |

## Wave 0 Requirements

- [ ] `tests/testthat/test-identity-migration.R` — source, documentation, options, native, archive, and installed-package identity contracts.
- [ ] Bridge-produced schema-1 predecessor logical-state fixture with explicit package lineage.
- [ ] Serialization lineage matrix covering current, allowlisted predecessor, missing, malformed, unknown, and content-fingerprint mismatch cases.
- [ ] `tools/check_identity_migration.R` — reusable tracked-source/archive/install/DLL/registration audit.
- [ ] Immutable digest snapshot for accepted Phase 2 historical artifacts.
- [ ] Machine-readable old/new option mapping and intentional-predecessor occurrence allowlist.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pre-rename serialization bridge availability | MIGR-01 | Users need a stable predecessor commit/ref before the package identity changes, and Phase 3 does not publish a release | Before rename, review and approve the exact predecessor commit/ref plus the documented installation/save command; verify a user can create the lineage-tagged schema-1 state from that ref |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Focused feedback latency remains below 60 seconds.
- [ ] Bridge fixture/ref and old baseline digests are frozen before the rename wave.
- [ ] `nyquist_compliant: true` is set in frontmatter after validation.

**Approval:** pending
