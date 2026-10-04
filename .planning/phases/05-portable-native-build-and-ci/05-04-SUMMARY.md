---
phase: 05-portable-native-build-and-ci
plan: 04
subsystem: testing
tags: [R, Matrix, source-installation, CI, compatibility]
requires:
  - phase: 05-03
    provides: Explicit installed OpenMP expectations and isolated native test conventions
provides:
  - Exact installed Matrix endpoint checks and conditional declared minimum assertions
  - Clean official CRAN source archive installation with exact loaded version verification
affects: [05-05, 05-06, 05-07]
tech-stack:
  added: []
  patterns: [Installed package metadata checks, Exact source archive installation]
key-files:
  created:
    - tests/testthat/test-matrix-compatibility.R
    - tools/ci/install-matrix-source.R
  modified: []
key-decisions:
  - Normalize CRAN hyphen version spelling with package_version before exact endpoint comparisons.
  - Accept only exact HTTPS cran.r-project.org Matrix source archive URLs and reject populated or symlink target libraries.
  - Leave Matrix minimum metadata and support claims for evidence-consuming plan 05-07.
requirements-completed: [PORT-01, CI-01]
coverage:
  - id: D1
    description: Installed endpoint and conditional minimum assertions
    requirement: PORT-01
    verification:
      - kind: integration
        ref: Installed test_package filter matrix-compatibility with sentinel, exact 1.6-3 and source-installed 1.6-5; mismatch and declared-minimum failure controls
        status: pass
    human_judgment: false
  - id: D2
    description: Clean exact CRAN Matrix source installer with offline dry run
    requirement: CI-01
    verification:
      - kind: integration
        ref: install-matrix-source.R exact Matrix_1.6-5.tar.gz install into final-matrix-library; loaded version 1.6.5; clean exit 0
        status: pass
      - kind: unit
        ref: /tmp/gemodelr-05-04-lm6cbytu/verify-installer.R offline and rejection controls plus CLI exit checks
        status: pass
    human_judgment: false
actuals:
  tokens: 4057
  tasks: 2
  commits: 3
duration: 7min
completed: 2026-10-04
status: complete
---

# Phase 05 Plan 04: Matrix Candidate Validation Summary

**Installed exact Matrix endpoint and conditional minimum checks, with an isolated installer for verified CRAN source archives.**

## Performance

- Started: 2026-10-04T20:47:36Z
- Completed: 2026-10-04T20:54:00Z
- Tasks: 2
- Implementation files created: 2
- Actual tokens use chars/4 over the realized implementation and summary diff.

## Accomplishments

- Endpoint tests compare the requested version exactly after R version spelling normalization. The `installed` sentinel permits ordinary installed dependency lanes.
- Minimum checks use installed GEModelR Imports metadata. A package without a declared minimum can collect provisional endpoint evidence; a declared minimum is enforced.
- The CLI validates exact official archive URLs and matching version inputs, rejects nonempty libraries including hidden files, and refuses symbolic link or file targets.
- Source archive contents and Package/Version metadata are checked before active-R source installation. Binary archives, alternate versions, ambient loaded namespaces, and incorrect installed versions fail.
- Dry run validates without creating the target, downloading, or installing. Successful installation retains the isolated library for later GEModelR jobs and prints install output and exact loaded version/path evidence.

## Task Commits

1. Task 05-04-T1: Candidate-aware installed Matrix assertions — `3ea67f5`.
2. Task 05-04-T2: Clean exact-source archive installer — `9f47bc7`.

## Verification

- Focused installed test suite: 12 assertions pass for `installed`, exact local `1.6-3`, and source-installed `1.6-5`; runs occur outside the checkout with explicit `.libPaths()` selection and `GEModelR_EXPECT_OPENMP=required`.
- Endpoint failure control: requesting `1.6-5` against local Matrix `1.6.3` returns exit 1 with exact expected/actual mismatch.
- Installed metadata controls: a disposable declared minimum `1.6-3` passes; `99.0-0` fails. Original disposable metadata was restored afterward.
- Required dry run passes for `https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_1.6-5.tar.gz`, `1.6-5`, and `/tmp/ge-modelr-matrix-floor`.
- Traced download and install functions prove dry run performs neither operation; the requested fresh target is absent afterward.
- Offline negative controls pass for missing arguments, blank library, malformed version, URL/version disagreement, HTTP/foreign/query/binary URLs, hidden target contents, symbolic links, file targets, mismatched source metadata, binary archive contents, wrong installed versions, and ambient namespace substitution. CLI failures return exit 1.
- Final unchanged installer downloads and source-installs Matrix `1.6-5` under R 4.3.0; exits 0 after loading verified Matrix `1.6.5` from `/tmp/gemodelr-05-04-lm6cbytu/final-matrix-library`.
- End-to-end compatibility test using that final source installation passes all 12 assertions.
- Syntax and whitespace checks pass. Stub scan finds none. No additional threat surface exists beyond the plan's archive/library and endpoint-input boundaries.

## Decisions Made

CRAN archive version `1.6-5` and R package version `1.6.5` identify the same release. Exact equality therefore uses canonical R version spelling while URL/version input matching retains the exact archive spelling.

## Deviations from Plan

**[Rule 3 - Verification isolation]** Replaced `test_local()` with the equivalent installed `test_package()` filter because source loading can compile checkout sources. GEModelR was installed from a disposable source copy into an explicit `/tmp` library, with tests run outside the checkout. Checkout binaries and user libraries were preserved.

The orchestrator owns STATE, ROADMAP, REQUIREMENTS, WINDOWS, and configuration updates. Full package check is scheduled in plan 05-06; this plan supplies focused local evidence.

## Issues Encountered

The initial live source installation and version verification succeeded, but editing the installer during its execution caused a trailing R parser error. The final unchanged script was rerun in a second fresh library and exited successfully. No package substitution or user-library mutation occurred.

Sandbox namespace initialization failed for one command; authorized scoped commands continued with escalation.

## Next Phase Readiness

The installer and endpoint checks are ready for the installed runner and hosted candidate matrix. This local R 4.3.0/Linux result establishes no cross-platform minimum promise. DESCRIPTION and README floor claims await the oldrel-1 platform/build evidence evaluated in 05-07.

## Self-Check: PASSED

Both implementation files and this summary exist. Task commits `3ea67f5` and `9f47bc7` exist. Neither task commit deletes tracked files.
