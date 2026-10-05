---
phase: 05-portable-native-build-and-ci
plan: 06
subsystem: infra
tags: [R, Matrix, GitHub-Actions, OpenMP, hosted-evidence]
requires:
  - phase: 05-05
    provides: installed native core runner and platform build contracts
provides:
  - authentic evidence for all 30 provisional tuples, preserving failures
  - 24 passing supported hosted tuples after six proven source exclusions
  - five passing oldrel-1 Matrix 1.6-5 platform/build candidate rows
  - independent representative check reports and immutable artifact manifests
affects: [05-07, CI-01, PORT-01, PORT-02, PORT-03]
tech-stack:
  added: [macOS hosted gettext build headers]
  patterns: [exact-source candidate installs, immutable run-attempt evidence, independent informational package check]
key-files:
  created:
    - tools/ci/record-matrix-candidate.R
    - tools/ci/summarize-r-cmd-check.R
    - .planning/phases/05-portable-native-build-and-ci/matrix-candidate-evidence.csv
    - .planning/phases/05-portable-native-build-and-ci/HOSTED-COMPATIBILITY.md
    - .planning/phases/05-portable-native-build-and-ci/hosted-evidence/
    - .planning/phases/05-portable-native-build-and-ci/deferred-items.md
  modified:
    - .github/workflows/native-ci.yaml
    - .planning/phases/05-portable-native-build-and-ci/05-VALIDATION.md
    - R/sparseSuiteSparse.R
key-decisions:
  - Preserve the full 30-row candidate input, including failed exact-source installs; retain supported-run rows separately.
  - Exclude only six observed Matrix 1.6-5 macOS/Windows release/devel tuples; retain Linux counterparts and every oldrel-1 floor pairing.
  - Keep representative full-check findings informational and label the inherited Phase 04 baseline separately.
  - Leave Matrix floor metadata to Plan 05-07 after its evidence validator.
requirements-completed: [CI-01, PORT-01, PORT-02, PORT-03]
actuals:
  tokens: 128829
  tasks: 3
  commits: 16
duration: 9h58min including hosted checkpoint wait
completed: 2026-10-05
status: complete
---

# Phase 05 Plan 06: Hosted native compatibility and check reporting Summary

**All 30 provisional combinations have authentic retained outcomes; all 24 supported combinations pass exact-source installation and installed solver tests, with separate full-check reports.**

## Performance

- First authoring task commit: 2026-10-04T21:07:23Z.
- Hosted completion and evidence close-out: 2026-10-05T07:05Z, approximately 9h58 including the external authorization/checkpoint wait.
- Tasks: 3/3 complete. Root owns STATE/ROADMAP/shared requirement updates; this summary does not independently complete the phase or Plan 05-07.
- Actual token estimate uses realized diff characters divided by four over the plan/review/evidence boundary since `dd14e1b`, excluding root-owned STATE and handoff changes. The large artifact hash manifests are included; this is not harness token usage.

## Accomplishments and hosted verification

### 05-06-T1: Candidate and supported matrix

- Run `37273713572`, attempt 1, head `98e626aaad0824db07a2012ed1cacfbcaef74a22`, executed all 30 candidate combinations. Twenty-four source installations and installed solver contracts passed; six source installations failed with `OBJECT` undeclared. Their solver result remains `not_run`.
- The six excluded exact tuples are Matrix 1.6-5/minimum on macOS serial and Windows serial/OpenMP for release R 4.6.1 and devel R 4.7.0. Each failure's job ID, exact compiler error, raw artifact ID/digest and extracted-file hashes are retained. Linux release/devel minimum rows passed and remain in the workflow.
- Run `37274723569`, attempt 1, head `c9292607ea74b527e492b7c0b37f5966cee2696c`, passed all **24 supported candidate jobs**. Every authentic row records source-install and installed-solver `success`. All five oldrel-1 / Matrix 1.6-5 pairings passed on R 4.5.3, including macOS serial and Linux/Windows serial/OpenMP.
- `matrix-candidate-evidence.csv` is the full 30-row input from run `37273713572`. Original run `37273389483` (20 pass/10 fail) and final supported 24-row CSV remain separate under `hosted-evidence/`. No synthetic or local row entered the hosted input.
- Artifact collection verified exact nine-column headers, one row per original artifact, run IDs, resolved R versions, the full expected tuple sets, and correspondence to actual source-install/solver step outcomes. SHA-256 hashes of downloaded files and API artifact digests/IDs are retained in each run manifest.
- Earlier invalid-workflow run `37273246073` had zero jobs. Earlier macOS `libintl.h` setup failures are retained and do not justify source-compatibility exclusions. No run was cancelled or rewritten.
- Final workflow uses PR/default-master-push/weekly triggers, read-only permissions, immutable action SHAs, exact Matrix source archives, explicit serial/OpenMP expectations, and the installed core runner. No DESCRIPTION/README floor claim was changed.

### 05-06-T2: Fast reporting contract

The local formatter self-test and hosted named self-test steps pass. They exercise the same report formatter, preserve original check-exit labels and exact inherited counts, and invoke no full check or artifact overwrite.

### 05-06-T3: Representative check

Completed reports from runs `37273389483` and `37273713572` use Linux/release R 4.6.1/current Matrix 1.7.6/serial. Both retain original exit **1**, **1,868 passes, nine failures, 164 skips, two ERRORs, two WARNINGs and one NOTE**. Raw build/check logs, status, source archive and complete check directory were downloaded and remain outside version control.

Each job summary separately states the exact inherited Phase 04 baseline: **2,364 passes, 19 failures, 65 skips, one ERROR, four WARNINGs and four NOTEs**. The reports make no claim that Phase 05 resolved those historical findings. The representative job has no dependency edge to the supported matrix, and its full-check step preserves a nonzero outcome with `continue-on-error: true`.

The duplicate representative job `111649136092` in run `37274723569` remained active at final artifact capture. It was left running. This summary relies on the two completed representative reports and does not invent the duplicate result or require another full-check run.

Local verification, retained from the earlier execution, includes 57 focused installed assertions, formatter tests, scoped SuiteSparse repair verification, and serial full checks. The final ordinary local serial check passed 1,889 assertions with zero failures, 164 skips, zero ERRORs/WARNINGs and three NOTEs on R 4.3.0 / Matrix 1.6.3; its context differs from hosted R release/current Matrix. Actionlint, `git diff --check`, exact supported-row/floor-pair assertions and hosted artifact checks pass.

## Task commits and continuation history

| Commit | Work |
| --- | --- |
| `5d57dc8` | T1 provisional 30-row matrix and row recorder |
| `9abcc6a` | T2 fast formatter self-test |
| `679d2b5` | T3 independent informational check and validation map |
| `d04e1f0` | Restore SuiteSparse obsolete-option migration preflight |
| `2465604` | Record local integration repair verification |
| `7c2dc6a` | Preparatory source review |
| `4b9dbbe` | CR-01 ordinary serial test expectations |
| `2ab0c28` | WR-01 same-version CRAN Archive recovery |
| `2ed32f0` | Review fixes and local check report |
| `d244738` | Hosted checkpoint handoff |
| `99faa57` | Fresh official Matrix endpoint query |
| `1dd2c06` | Runner paths initialized in valid step context |
| `98e626a` | macOS gettext source-build headers/library flags |
| `c929260` | Preserve candidate evidence and exclude only six proven invalid tuples |
| `5dd9fdd` | Validate all supported hosted outcomes and retain deferred reports |

The summary is committed separately before root tracking updates. No tracked file deletion or unrelated dirty-file staging occurred.

## Deviations from plan

1. **[Rule 2 - Missing critical functionality] Dedicated row recorder.** `tools/ci/record-matrix-candidate.R` was added to preserve observed success/failure outcomes and matching job summaries without translating skipped work to success.
2. **[Rule 1 - Bug] SuiteSparse migration-message regression.** The fail-closed preflight masked the existing obsolete-option error. Commit `d04e1f0` restores that guard before unavailable-capability rejection without evaluating lazy matrix/RHS inputs, emitting matrices, compiling or substituting a backend; focused installed verification passed.
3. **[Rule 1 - Bug] Pre-hosted review repairs.** Ordinary local serial tests now permit unset expectations outside CI while retaining strict required/forbidden CI checks. The Matrix installer retries only the same official Archive version after an HTTP 404 for its current source URL. Details and positive/negative checks are in `05-REVIEW-FIX.md`.
4. **[Rule 1 - Bug] Job-level runner context rejected.** Hosted validation rejected `runner.temp` in job environment expressions before any job ran. `1dd2c06` moves paths to step environment and propagates them through `GITHUB_ENV`; actionlint and subsequent hosted jobs pass.
5. **[Rule 3 - Blocking issue] macOS header setup.** Official gettext toolchain headers/library flags were supplied in the hosted temporary Makevars after exact source logs showed missing `libintl.h`. This repairs runner setup without editing Matrix sources or substituting a dependency.

Six source incompatibility exclusions follow the plan's explicit evidence-based exclusion rule and are not a changed floor or a silent version/build substitution. No architectural or numerical changes were introduced. Documentation for the runner toolchain was checked against official r-lib Actions and Homebrew gettext sources; Context7/ctx7 were unavailable.

## Deferred issues and skips

The hosted representative suite has nine failures in unchanged predecessor serialization/leaf tests. PDF generation reports `pdflatex is not available`; the existing provisional DESCRIPTION license produces a warning. Exact paths and preserved raw evidence are in `deferred-items.md`. No immutable predecessor fixture or broader release code was modified.

The representative check's 164 skips include packaged-context source-only provenance/release/migration contracts and the explicit parallel-only serial skip. Required OpenMP core rows run capability and two-thread parity checks without accepting a skip as passing capability. Broader release qualification remains outside this plan. Root will preserve/report these entries in the cross-phase ledger without discarding existing WINDOWS edits.

No unresolved placeholder prevents this plan's candidate matrix or reporting goals. SuiteSparse remains intentionally unavailable by the approved installed backend contract; no supported path invokes its runtime compiler. No new public network endpoint or authentication path was added.

## Next plan readiness

Plan 05-07's authentic evidence precondition is met: the full candidate input exists and the provisional floor has five passing oldrel-1 pairings. Only its validator may select the Matrix floor and finalize DESCRIPTION/README. Final phase review, regression gates, verifier and shared requirement completion remain for the orchestrator.

## Self-Check: PASSED

- Expected workflow/tools, primary 30-row input, three retained run manifests, both completed representative report copies, deferred issue report and this summary exist.
- All listed prior commits resolve, full candidate CSV exactly matches the retained merge, and all 24 supported artifact rows match completed source-install/solver outcomes.
- Full native artifacts/check directories stay under `/tmp`; user library, native checkout outputs and unrelated dirty config/WINDOWS files are untouched.
