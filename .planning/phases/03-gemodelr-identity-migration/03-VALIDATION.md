---
phase: 03
slug: gemodelr-identity-migration
status: planned
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-09
revised: 2026-09-10
---

# Phase 03 — Validation Strategy

> Per-task sampling contract synchronized to the finalized twelve-plan execution chain.

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | testthat 3.3.2, edition 3 |
| Config | DESCRIPTION and tests/testthat.R |
| Quick gate | Focused identity-migration, model-serialization, and public-solver-contract tests |
| Continuous baseline gate | Identity-aware read-only Phase 2 migration-source checker; existing predecessor --check mode is used until Wave 0 creates the adapted mode |
| Full suite | Complete testthat suite in a clean process |
| Final package gate | rtk Rscript --vanilla tools/qualify_phase03_migration.R --execute; no working-tree test_local substitute |
| Expected latency | Focused sampling targets 60 seconds; archive/check/install qualification may take longer |

## Sampling Rate

- After every task: run its focused gate and, once available, the identity-aware read-only Phase 2 numerical/digest gate.
- After the predecessor fixture task: reproduce the fixture from the reviewed source and assert source, fixture, and canonical evidence digests.
- At the human bridge checkpoint: fail closed unless an already-authorized immutable source is user-reachable and the exact installation/conversion commands are approved; do not publish or mutate remotes.
- After the atomic load-critical task: parse the non-generating static assertion for the exact eleven routine names/arities, R_init_GEModelR, GEModelR DLL identity, and dynamicLookup FALSE after the single generation step; perform no package-loading check before that switch is coherent.
- After every wave: run the full suite when loadable, plus continuous MIGR-02 and immutable-evidence checks.
- At the final wave: first self-test the deterministic harness, then invoke that harness once to qualify the recorded clean HEAD through hashed git export, extracted source, exact built archive, check/install linkage, isolated fresh workflow/DLL state, complete tests, identity audits, and Phase 2 gates.
- R CMD check acceptance is zero ERROR and zero WARNING; NOTES must be documented and reviewed.

## Per-Task Verification Map

| Task ID | Wave | Requirements | Planned verification gate | Status |
|---------|------|--------------|---------------------------|--------|
| 03-01-01 | 1 | MIGR-01, MIGR-02 | Adapt and exercise the non-circular identity-aware read-only baseline checker | pending Wave 0/execution |
| 03-01-02 | 1 | MIGR-01, MIGR-02 | Freeze and continuously compare canonical Phase 2 bytes, digests, and protected numerical invariants | pending Wave 0/execution |
| 03-02-01 | 2 | MIGR-01, MIGR-02 | Exercise mandatory tagged package lineage while Package remains tabloToR | pending Wave 0/execution |
| 03-02-02 | 2 | MIGR-01, MIGR-02 | Reproduce the genuine public-save predecessor fixture and exact reviewed fingerprints | pending Wave 0/execution |
| 03-03-01 | 3 | COMP-04, MIGR-01, MIGR-02 | Read-only reachability/reproduction gate plus blocking human approval of exact commands | pending manual checkpoint |
| 03-04-01 | 4 | COMP-04, MIGR-01, MIGR-02 | Run compileAttributes once in action; then use the static non-generating R assertion for all eleven exact names/arities, R_init_GEModelR, GEModelR DLL identity, and dynamicLookup FALSE | pending execution |
| 03-05-01 | 5 | COMP-04, MIGR-01, MIGR-02 | Audit current package/docs identity while retaining historical attribution | pending Wave 0/execution |
| 03-06-01 | 6 | COMP-04, MIGR-01, MIGR-02 | Exercise every old public option at its operation-local guard before mutation | pending Wave 0/execution |
| 03-06-02 | 6 | COMP-04, MIGR-01, MIGR-02 | Test direct private-hook, attribute, diagnostic, sparse, and public-contract identity | pending execution |
| 03-07-01 | 7 | COMP-04, MIGR-01, MIGR-02 | Run lineage and round-trip matrix; compare approved predecessor registry/fixture digests before and after | pending Wave 0/execution |
| 03-08-01 | 8 | MIGR-01, MIGR-02 | Run source-mode locator/parity tests, then build and R CMD check a temporary archive so installed-first lookup finds all four packaged benchmark drivers; repeat numerical/digest gates | pending execution/resources |
| 03-09-01 | 9 | COMP-04, MIGR-01, MIGR-02 | Run helper, sparse LU/Schur, compiled-backend, serialization, and compatibility tests | pending execution |
| 03-10-01 | 10 | COMP-04, MIGR-01, MIGR-02 | Exhaustively classify every case-insensitive tracked old-identity hit; fail closed outside the exact allowlist | pending Wave 0/execution |
| 03-10-02 | 10 | COMP-04, MIGR-01, MIGR-02 | Test provenance inventory and verify historical-map/evidence digests | pending execution |
| 03-11-01 | 11 | COMP-04, MIGR-01, MIGR-02 | Repeat exhaustive tracked-source audit after remaining non-load-critical cleanup | pending Wave 0/execution |
| 03-12-01 | 12 | COMP-04, MIGR-01, MIGR-02 | Author/test tools/qualify_phase03_migration.R; run its focused test and --self-test fail-closed contract | pending Wave 0/execution |
| 03-12-02 | 12 | COMP-04, MIGR-01, MIGR-02 | Invoke only rtk Rscript --vanilla tools/qualify_phase03_migration.R --execute and record its HEAD/export/archive/install/log digest chain in the summary | pending Wave 0/execution |

## Wave 0 Dependencies

- [ ] Identity tests spanning source, docs, options, native/generated/runtime symbols, archive, installation, DLL loading, and public workflow.
- [ ] Adapted identity-aware read-only Phase 2 checker, canonical-evidence digest manifest, and continuous numerical gate.
- [ ] Tagged schema-1 predecessor fixture, strict fingerprint registry, and read-only reachability/reproduction tool.
- [ ] Human approval evidence for an already-authorized reachable immutable predecessor source and exact commands.
- [ ] Serialization lineage matrix for current, allowlisted predecessor, absent, malformed, duplicate, unknown, stale, and fingerprint-mismatch cases.
- [ ] Strict option map, operation-local public guards, and direct private-hook coverage.
- [ ] Static non-generating validator for hand-authored, generated, runtime-compiled, and R-side symbols, with all eleven exact names/arities, R_init_GEModelR, DLL identity, and dynamicLookup FALSE.
- [ ] Exact five-category old-identity allowlist, historical maps, and exhaustive tracked-hit classifier.
- [ ] Four packaged inst/benchmarks drivers, installed-first/source-fallback locator tests, and exact source/install parity assertions.
- [ ] Reusable source/archive/install identity and DLL audit.
- [ ] tools/qualify_phase03_migration.R plus focused self-tests for clean-state enforcement, stage linkage, exact NOTE allowlisting, isolated-library resolution, and nonzero failure behavior.

Wave 0 is not complete because execution-created tests, fixtures, registries, classifiers, and qualification tools are not yet present in their planned final form. The phase is therefore not Nyquist compliant.

## Manual-Only Verification

| Behavior | Requirements | Reason | Gate |
|----------|--------------|--------|------|
| Pre-rename bridge availability | COMP-04, MIGR-01, MIGR-02 | User reachability and authorization require human review | Before the Package rename, approve the exact immutable locator, fingerprints, installation command, and raw-RDS-to-logical-saveState conversion command; otherwise stop |

## Validation Sign-Off

- [x] All 17 planned XML tasks have one verification-map row.
- [x] The map includes the final clean-source/archive/install and fresh-process qualification gate.
- [ ] Wave 0 dependencies exist and pass.
- [ ] Sampling continuity is demonstrated during execution.
- [ ] The blocking bridge approval is recorded before the rename wave.
- [ ] Final R CMD check has zero ERROR/WARNING and only documented reviewed NOTES.
- [ ] Set wave_0_complete and nyquist_compliant true only after execution evidence satisfies every gate.

**Approval:** pending execution
