---
phase: 05-portable-native-build-and-ci
plan: 01
subsystem: infra
tags: [Rcpp, native, installed-tests, github-actions, serial, OpenMP]
requires:
  - phase: 04-public-api-and-solver-boundaries
    provides: Explicit backend contracts and installed GEModelR native registration
provides:
  - Structured elimination dispatch through registered installed DLL wrappers
  - Installed structured-solve regression with a sourceCpp tripwire
  - Initial Linux R-release serial CI job on PR, master push, and weekly events
affects: [05-02, 05-03, 05-05, 05-06, 05-07]
actuals:
  tokens: 9594
  tasks: 2
  commits: 5
tech-stack:
  added: [GitHub Actions]
  patterns:
    - Explicit temporary installation library and installed-package path assertions
    - Job-local serial Makevars override verified through installed DLL capability
    - Official actions pinned to full reviewed commit SHAs
key-files:
  created:
    - tests/testthat/test-native-portability.R
    - .github/workflows/native-ci.yaml
  modified:
    - R/sparseElimination.R
    - .planning/phases/05-portable-native-build-and-ci/05-01-PLAN.md
    - .planning/phases/05-portable-native-build-and-ci/05-05-PLAN.md
    - .planning/phases/05-portable-native-build-and-ci/05-VALIDATION.md
key-decisions:
  - Use registered elimination and reconstruction wrappers for the installed structured solve.
  - Assert OpenMP false and max_threads 1L before installed tests in the serial job.
  - Select the test installation with .libPaths and an explicit library load; test_package does not accept lib.loc.
  - Run local install verification from disposable source copies into explicitly created temporary libraries.
patterns-established:
  - Installed native tests run from outside the checkout with runtime compilation trapped.
  - CI uses contents read permission and checkout persist-credentials false without repository secrets.
requirements-completed: [PORT-03, CI-01]
coverage:
  - id: D1
    description: Installed structured elimination uses registered wrappers without runtime compilation.
    requirement: PORT-03
    verification:
      - kind: integration
        ref: tests/testthat/test-native-portability.R#installed structured elimination runs outside the checkout without compiling
        status: pass
    human_judgment: false
  - id: D2
    description: The initial Linux R-release serial workflow installs tests and verifies installed native capabilities.
    requirement: CI-01
    verification:
      - kind: integration
        ref: Disposable serial R CMD INSTALL and testthat::test_package native-portability run, 2026-10-04
        status: pass
      - kind: other
        ref: YAML event, action SHA, permission, and embedded R syntax acceptance checks
        status: pass
    human_judgment: false
duration: 3d 5h 51min including checkpoint and investigation wait
completed: 2026-10-04
status: complete
---

# Phase 05 Plan 01: Installed Native Tracer and Serial Linux CI Summary

**Registered structured-elimination wrappers and an installed sourceCpp tripwire now run in an explicitly serial Linux CI job with immutable action pins.**

## Performance

- **Started:** 2026-10-01T14:42:16.567Z
- **Completed:** 2026-10-04T20:33:00Z
- **Duration:** Approximately 3 days 5 hours 51 minutes, including the tracer checkpoint and investigation wait.
- **Tasks:** 2 of 2
- **Files changed:** 6 implementation and verification files, plus this summary.
- **Actuals basis:** Characters divided by four, rounded up, over the realized unified diffs for implementation, corrected verification documents, and this summary; no harness token count is used.

## Accomplishments

- `sparse_elimination_cpp()` calls `GEModelR_eliminate_blocks()` and `GEModelR_reconstruct_blocks()` through their registered package wrappers. The stale native-symbol lookup and solve-time `sourceCpp` fallback were removed without changing wrapper signatures or numerical result structure.
- The deterministic installed regression changes to an unrelated temporary directory, traps `Rcpp::sourceCpp`, and checks structured reconstruction against the known five-variable solution and full-system true residual at `1e-10`.
- The workflow runs on pull requests, pushes to the locally identified default branch `master`, and weekly Monday at 04:23 UTC. Its Linux R-release job clears `SHLIB_OPENMP_CXXFLAGS`, creates an explicit installation library, installs package tests, asserts serial native capability, and runs the installed regression outside the checkout.
- The workflow grants only `contents: read`, disables persisted checkout credentials, and supplies no repository secrets. Official upstream refs were independently resolved with read-only `git ls-remote`; the pinned definitions were reviewed.

## Task Commits

1. **05-01-T1: Registered structured elimination and installed tripwire regression** — `8dac20c`.
2. **05-01-T2: Initial serial Linux installed-package workflow** — `d9b4baf`.

Additional verification corrections:

- `bbb777c` — Correct isolated installation commands to use `--library=/tmp/ge-modelr-lib`.
- `49a7210` — Correct unsupported `test_package` library arguments in Plans 05-01 and 05-05 and matching validation rows.

The tracer commit was verified before continuation and was not re-executed. The user explicitly approved continuation to Task 2 after the tracer checkpoint and the read-only library investigation. This summary is committed separately before shared tracking updates by the orchestrator.

## Verification

- Task 1 previously reported its installed native-portability regression passing with `DONE` in the corrected temporary installation. No expectation count was recorded for that earlier run.
- Task 2 copied current tracked package source into `/tmp/ge-modelr-05-01-task2/source`, excluding generated native objects and shared libraries. Existing checkout `src/*.o` and `src/*.so` files were untouched.
- Created `/tmp/ge-modelr-05-01-task2/library` before invoking `R CMD INSTALL --preclean --install-tests --library=/tmp/ge-modelr-05-01-task2/library` with the temporary serial Makevars override. Installation ended with `DONE (GEModelR)`.
- The installed native payload reported `openmp = FALSE`, `max_threads = 1L`, `lapack = TRUE`, and `matrix_contract = sparseLU-v1`. Compilation and linking contained no OpenMP flag.
- With the temporary library first in `.libPaths()` and an explicit package-path assertion, `testthat::test_package("GEModelR", filter = "native-portability", reporter = "summary", stop_on_failure = TRUE)` completed successfully from an unrelated temporary working directory. The sourceCpp trace was installed and removed; all five displayed expectations passed.
- YAML acceptance checks passed for the three events, master branch filter, serial Linux release job, read-only permission, full 40-character action pins, disabled persisted credentials, and absence of secret references. Embedded R scripts parsed successfully. `git diff --check` passed.
- All three corrected plan verification commands exactly match their validation rows, parse successfully, and omit `lib.loc` from `test_package`.

Local validation used R 4.3.0, Matrix 1.6.3, SparseM 1.81, Rcpp 1.1.1.1.1, and testthat 3.3.2. Hosted R-release execution has not been triggered; its setup is defined by the workflow.

## Reviewed Action Pins

| Action | Official upstream ref | Full commit SHA |
|--------|-----------------------|-----------------|
| actions/checkout | v4.4.0 | 11d5960a326750d5838078e36cf38b85af677262 |
| r-lib/actions/setup-r | v2, resolved 2026-10-04 | f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05 |
| r-lib/actions/setup-r-dependencies | v2, resolved 2026-10-04 | f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05 |

Ref evidence comes from the official [checkout repository](https://github.com/actions/checkout/releases/tag/v4.4.0) and [r-lib/actions repository](https://github.com/r-lib/actions/tree/f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05). Reviewed pinned R setup inputs include R release selection; dependency setup disables caching, Pandoc, and Quarto for this initial cell.

## Decisions Made

- Keep the initial workflow scoped to the requested Linux serial tracer. Later plans add supported platforms, OpenMP expectations, Matrix endpoints, core tests, and representative package-check reporting.
- Use the job-local user Makevars override instead of changing package makefiles. Runtime capability assertions prove that the installed artifact is serial.
- Use `.libPaths()` plus `library(..., lib.loc = ...)` and package-path assertions to select installed tests. Confirm installed tests exist before running them, so a missing installed test directory cannot yield an empty successful run.
- Keep local build and installation outputs entirely in disposable `/tmp` directories after the earlier accidental default-library install.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected isolated install library syntax and prepared temporary libraries.**

- **Found during:** Task 1 verification and subsequent investigation.
- **Issue:** Incorrect installation argument handling led to an accidental installation into the default user library instead of the intended temporary target.
- **Fix:** Use `--library=<existing-temporary-library>` with the destination created first. Local Task 2 verification additionally copies sources into `/tmp` before `--preclean`, protecting checkout native artifacts.
- **Files modified:** Phase 05 plan verification commands and validation map; committed in `bbb777c` before this continuation.
- **Verification:** Task 2's install target and loaded package path were explicitly verified inside `/tmp/ge-modelr-05-01-task2/library`.

**2. [Rule 1 - Bug] Corrected unsupported `test_package(lib.loc=...)` calls.**

- **Found during:** Task 2 installed verification.
- **Issue:** The plan's `lib.loc` argument is forwarded through `test_package` to test-file filtering, where it causes an unused-argument error in `grepl`.
- **Fix:** Put the intended library first in `.libPaths()`, load GEModelR with an explicit `lib.loc`, assert its installed path, and call `test_package` without `lib.loc`. Applied the same correction to Plans 05-01 and 05-05 and their matching validation rows.
- **Files modified:** `.github/workflows/native-ci.yaml`, `05-01-PLAN.md`, `05-05-PLAN.md`, `05-VALIDATION.md`.
- **Commits:** `d9b4baf`, `49a7210`.
- **Verification:** Corrected installed regression passed; all repaired task/map commands match and parse.

## Issues Encountered

### Accidental user-library installation

The investigation established that `/home/zenz/R/x86_64-pc-linux-gnu-library/4.3/GEModelR` is the default `find.package` result and contains GEModelR 0.1.0 built with R 4.3.0 for x86_64-pc-linux-gnu at **2026-10-01 14:45:34 UTC** (**16:45:34 Vienna**). The corrected `/tmp/ge-modelr-lib-05-01` installation was built at **14:46:18 UTC**. Both installed `sparse_elimination_cpp()` bodies call the direct registered elimination/reconstruction wrappers, and those wrappers resolve.

The previous existence and version of the user installation could not be determined. Investigation was read-only; no removal or rollback was performed. The user approved Task 2 continuation after receiving these findings. Task 2 installed only into its explicitly created temporary library.

The serial install emitted the already documented ReferenceClass assignment warning in `generateSolution`. This warning was not caused by the workflow change and remains outside this plan. Full `R CMD check` baseline reporting is scheduled for Plan 05-06; this plan does not resolve the inherited Phase 04 package-check findings.

The default command sandbox intermittently failed to create its namespace. Approved escalated execution allowed the required local and read-only upstream checks to complete; no external repository mutation occurred.

## Known Stubs

None. Scanned the changed implementation, regression test, and workflow for TODO, FIXME, placeholder, coming-soon, and unavailable placeholder text. All planned deliverables are wired to installed native code and real regression data.

## User Setup Required

None for this initial workflow cell.

## Next Phase Readiness

The registered native tracer and serial Linux workflow are ready for later Phase 05 expansion. This plan establishes its PORT-03 and CI-01 slices; full SuiteSparse rejection, supported platform/R/Matrix coverage, and full requirement qualification remain assigned to the remaining phase plans. Hosted runner success is still to be observed after an authorized repository event.

Shared STATE.md, ROADMAP.md, REQUIREMENTS.md, WINDOWS.md, and config updates remain owned by the orchestrator. No new endpoints, authentication paths, trust-boundary schemas, or unmodeled native access patterns were introduced beyond the plan's reviewed native and CI boundaries.

## Self-Check: PASSED

All six implementation/verification files and this summary exist. Task commits 8dac20c and d9b4baf and verification correction commits bbb777c and 49a7210 resolve. The final workflow and installed regression passed their recorded checks.
