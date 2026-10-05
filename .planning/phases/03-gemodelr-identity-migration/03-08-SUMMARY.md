---
phase: 03-gemodelr-identity-migration
plan: 08
subsystem: benchmarks
tags: [R, GEModelR, benchmarks, installed-resources, migration, numerical-baseline]

requires:
  - phase: 03-gemodelr-identity-migration
    plan: 07
    provides: Strict current GEModelR lineage and approved predecessor migration
provides:
  - GEModelR identity across all active benchmark and numerical-baseline producers
  - Installed-first benchmark driver lookup with exact source/resource parity
  - Four packaged benchmark drivers available from the installed GEModelR package
  - Current-identity Phase 2 migration checking with immutable predecessor evidence
affects: [03-09, 03-10, 03-12, benchmarks, testing, identity-migration]

actuals:
  tokens: 9622
  tasks: 1
  commits: 2

tech-stack:
  added: []
  patterns:
    - Resolve installed benchmark resources first and use source paths only as compatibility fallback
    - Keep source and inst benchmark drivers byte-identical under executable parity tests
    - Emit package, option, and native identity as explicit stable benchmark metadata

key-files:
  created:
    - inst/benchmarks/benchmark_config.R
    - inst/benchmarks/run_gtap12a_sweep.R
    - inst/benchmarks/run_gtap12a_scaling.R
    - inst/benchmarks/check_benchmark_gate.R
    - .planning/phases/03-gemodelr-identity-migration/03-08-SUMMARY.md
  modified:
    - benchmarks/benchmark_config.R
    - benchmarks/benchmark_gtap12a.R
    - benchmarks/benchmark_gtap12a_run.R
    - benchmarks/benchmark_schur_cpp.R
    - benchmarks/benchmark_sparse_lu_cpp.R
    - tests/testthat/test-benchmark-harness.R
    - tests/testthat/helper-numerical-baseline.R
    - tests/testthat/test-numerical-baseline.R
    - inst/tools/refresh_phase02_baselines.R

key-decisions:
  - "Use system.file(\"benchmarks\", name, package = \"GEModelR\") as the first benchmark driver candidate and consult the source tree only when that resource is absent."
  - "Include package_name, option_prefix, and native_routine_prefix in stable GTAP model/run metadata while preserving all non-identity signature inputs."
  - "Require GEModelR for the active Phase 2 checker while retaining predecessor literals only in the exact reviewed identity-map validation."
  - "Do not pre-empt Plan 03-09 files to repair unrelated full installed-suite failures; prove the installed benchmark slice independently and record the remaining check failure."

requirements-completed: [MIGR-01, MIGR-02]

coverage:
  - id: D1
    description: "All active benchmark and numerical-baseline producers use GEModelR package, option, namespace, temporary-prefix, and native-routine identity."
    requirement: MIGR-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-benchmark-harness.R#active benchmark producers use exact GEModelR identity"
        status: pass
      - kind: integration
        ref: "tests/testthat/test-numerical-baseline.R#GEModelR namespace and native accumulation coverage"
        status: pass
    human_judgment: false
  - id: D2
    description: "Four installed benchmark drivers resolve before the source fallback and remain byte-identical to source counterparts."
    requirement: MIGR-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-benchmark-harness.R#benchmark driver lookup is installed-first with source fallback"
        status: pass
      - kind: integration
        ref: "tests/testthat/test-benchmark-harness.R#packaged benchmark drivers are exact source mirrors"
        status: pass
    human_judgment: false
  - id: D3
    description: "Numerical contracts and immutable Phase 2/private benchmark evidence remain unchanged while the active checker accepts current identity."
    requirement: MIGR-02
    verification:
      - kind: integration
        ref: "focused benchmark-harness and numerical-baseline testthat command"
        status: pass
      - kind: other
        ref: "tools/refresh_phase02_baselines.R --check-migration-source"
        status: pass
      - kind: other
        ref: "tools/check_identity_migration.R --historical-only"
        status: pass
    human_judgment: false

duration: 19min
completed: 2026-09-15
status: complete
---

# Phase 03 Plan 08: Benchmark Identity and Installed Resources Summary

**GEModelR benchmark identity with installed-first driver lookup, four byte-identical packaged resources, and unchanged numerical and historical evidence gates.**

## Performance

- **Duration:** 19min
- **Started:** 2026-09-15T08:00:02Z
- **Completed:** 2026-09-15T08:19:07Z
- **Tasks:** 1
- **Files modified:** 13

## Accomplishments

- Migrated the five active benchmark files plus numerical-baseline helpers/tests from predecessor package, option, temporary-prefix, namespace, and native-routine identity to GEModelR.
- Added explicit package_name, option_prefix, and native_routine_prefix fields to stable GTAP benchmark metadata without changing model inputs, solver settings, ordering, residuals, or tolerances.
- Installed four benchmark driver resources under inst/benchmarks/, with source-mode and installed-mode locator coverage plus byte-exact parity assertions.
- Kept accepted Phase 2 baselines, hidden experimental benchmarks, and recorded GTAP results byte-identical while making the active migration checker require GEModelR.

## Verification Results

- Focused benchmark-harness|numerical-baseline suite — PASS: 53 benchmark assertions and 78 numerical assertions.
- Source/resource parity gate — PASS for all four drivers; source, inst/benchmarks, and the checked installation have identical bytes.
- Installed archive slice — PASS: R CMD build --no-manual built GEModelR, R CMD check --no-manual installed it, and all benchmark-harness tests passed with no missing-driver failures.
- Full archive check — NONZERO from 16 unrelated installed-suite failures already assigned to Plan 03-09 and later source-path qualification; result was 1 ERROR, 1 WARNING, 4 NOTEs, with 783 assertions passing and no benchmark-harness failure.
- Phase 02 migration-source gate — PASS; normalized fingerprint aee225f16707f20978a4f4318bffb4fe, raw fingerprint f183603b643e74a48e1a81723211df6d, accepted canonical hash f6f2297a6ab257c9737a64354c82d7f1.
- Historical-only identity audit — PASS: 5 immutable records, 4 protected numerical sources, 1 protected region, and 1 immutable historical predecessor occurrence.
- Historical/private no-diff gate — PASS for all hidden benchmarks/.* files, GTAP12A_CPP_RESULTS.md, and accepted Phase 2 baseline evidence.

## Task Commits

1. **Task 1 RED: Add failing benchmark identity contracts** — a7981ef
2. **Task 1 GREEN: Migrate benchmark identity and resources** — 348b26a

## TDD Gate Compliance

- RED commit a7981ef failed on all four missing packaged resources and each active predecessor benchmark identity before production changes.
- GREEN commit 348b26a passes the focused benchmark/numerical suite, source/install parity, migration-source, and historical gates.
- No refactor commit was needed; the implementation is a mechanical identity/resource migration around existing benchmark algorithms.

## Files Created/Modified

- benchmarks/benchmark_config.R — GEModelR identity-bearing hash/signature temporary prefixes.
- benchmarks/benchmark_gtap12a.R — Current package requirement and public model namespace.
- benchmarks/benchmark_gtap12a_run.R — Current package lookup, options, model namespace, and explicit stable identity metadata.
- benchmarks/benchmark_schur_cpp.R and benchmarks/benchmark_sparse_lu_cpp.R — Current namespace and native routine labels with algorithms unchanged.
- inst/benchmarks/ — Exact installed mirrors of configuration, sweep, scaling, and comparison-gate drivers.
- tests/testthat/test-benchmark-harness.R — Installed-first locator, source fallback, exact parity, active identity, and metadata assertions.
- tests/testthat/helper-numerical-baseline.R and tests/testthat/test-numerical-baseline.R — Current namespace and native routine test identity.
- inst/tools/refresh_phase02_baselines.R — Active checker requires GEModelR while exact predecessor mapping remains reviewed and read-only.

## Decisions Made

- Installed resources take precedence even when a source checkout is available; source lookup is only a compatibility fallback.
- Stable benchmark signatures gain only explicit identity inputs, preserving all model, solver, tuning, runtime, and numerical inputs.
- Source/resource parity is enforced on raw bytes so packaging drift cannot be normalized away.
- The immutable predecessor identity map remains the only old-package logic in the active checker.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the approved file-scoped Git patch fallback**
- **Found during:** Task 1 RED and GREEN edits
- **Issue:** The required patch helper could not initialize because the host kernel disallows unprivileged user namespaces.
- **Fix:** Applied only task-owned unified patches through the approved rtk/git-apply fallback.
- **Files modified:** Task tests, benchmark producers, installed resources, and active baseline checker.
- **Verification:** git diff --check, focused tests, exact parity, and migration/historical gates.
- **Committed in:** a7981ef, 348b26a

**2. [Rule 1 - Bug] Made parity coverage valid in both source and installed checks**
- **Found during:** Task 1 installed archive verification
- **Issue:** The first parity assertion required the top-level source tree even after installation, where only packaged resources are guaranteed.
- **Fix:** Compare source and packaged bytes whenever source counterparts exist, require all installed resources otherwise, and independently assert installed-first selection.
- **Files modified:** tests/testthat/test-benchmark-harness.R
- **Verification:** Source-focused suite passes; rebuilt installed check has no benchmark-harness failures.
- **Committed in:** 348b26a

---

**Total deviations:** 2 auto-fixed issues (1 blocking tooling issue, 1 test bug).
**Impact on plan:** Both fixes preserve exact benchmark algorithms and numerical evidence; no hidden/private benchmark or accepted historical artifact changed.

## Issues Encountered

- The exact full archive-check command remains nonzero on 16 failures outside Plan 03-08: source-only baseline/documentation/bridge lookup, stale native tests, and transactional source reads. These are recorded in deferred-items.md and remain owned by Plan 03-09 and later qualification.
- Pre-existing package warnings/notes remain for documentation, hidden files, non-portable dirty planning paths, license metadata, and installed size.
- The existing ReferenceClass local-assignment warning for data$eqcoeff remains unchanged.

## Known Stubs

None.

## User Setup Required

None - no external service, credentials, or manual migration action is required.

## Next Phase Readiness

- Plan 03-09 can migrate the remaining active helpers and public/native/solver test family against installed GEModelR.
- Plan 03-10 can classify the retained predecessor occurrence in the exact historical allowlist.
- Release blockers for dependency compatibility and attribution identity remain unchanged.

## Self-Check: PASSED

- The summary and all four installed benchmark resources exist.
- RED commit a7981ef and GREEN commit 348b26a exist in repository history in the required order.
- Focused tests, source/install parity, migration-source, historical digest, and historical/private no-diff gates pass.
- No stubs, skipped task tests, unintended deletions, or new security-relevant surfaces were introduced.

---
*Phase: 03-gemodelr-identity-migration*
*Completed: 2026-09-15*

