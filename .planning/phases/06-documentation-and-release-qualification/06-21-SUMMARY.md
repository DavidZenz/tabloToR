---
phase: 06-documentation-and-release-qualification
plan: 21
subsystem: benchmarking
tags: [GTAP12a, reference-preflight, provenance, NUM-03]
requires:
  - phase: 06-05
    provides: external full-scale benchmark procedure and historical C++ measurements
provides:
  - Read-only reference preflight for matched GTAP 12a benchmark evidence
  - Exact prerequisite blockers for the current NUM-03 attempt
affects: [NUM-03, release-evidence]
actuals:
  tokens: 16344
  tasks: 1
  commits: 3
tech-stack:
  added: []
  patterns: [fail-closed benchmark preflight, external-only benchmark reports]
key-files:
  created:
    - benchmarks/preflight_gtap12a_reference.R
    - tests/testthat/test-gtap12a-reference-preflight.R
  modified:
    - docs/release/BENCHMARK-EVIDENCE.md
key-decisions:
  - "A missing reference preflight blocks the candidate and leaves NUM-03 open."
patterns-established:
  - "Inspect retained benchmark evidence read-only before any solver execution."
requirements-completed: []
coverage:
  - id: D1
    description: "Synthetic reference evidence is accepted only when artifacts, signatures, and retained build records match; missing or stale evidence fails closed."
    requirement: NUM-03
    verification:
      - kind: unit
        ref: "tests/testthat/test-gtap12a-reference-preflight.R"
        status: pass
      - kind: other
        ref: "preflight CLI with unavailable external input configuration"
        status: pass
    human_judgment: false
  - id: D2
    description: "Matched full-scale benchmark evidence remains unqualified until external reference artifacts, a C++ candidate gate, and independent review are available."
    requirement: NUM-03
    verification: []
    human_judgment: true
    rationale: "The authorized GTAP inputs, raw reference artifacts, retained build records, candidate result, and independent review are not available in this execution."
duration: "10 min from first recorded task commit"
completed: 2026-10-21
status: halted
---

# Phase 6 Plan 21: Preflight Existing References Summary

**Read-only GTAP 12a reference preflight and synthetic coverage are implemented; the local evidence gate is blocked before any solver runs.**

## Performance

- **Duration:** About 10 minutes from the first recorded task commit; preflight work began earlier in this executor context.
- **Started:** 2026-10-21T16:18:22+02:00 (first recorded task commit)
- **Completed:** 2026-10-21T16:28:08+02:00
- **Tasks:** 1 of 3 completed; Tasks 2 and 3 were not applicable after the blocked preflight.
- **Files modified:** 6 including plan summary and state metadata.

## Accomplishments

- Added a read-only preflight CLI that checks raw reference CSV/RDS evidence, matched metadata and signatures, local input fingerprints, current installed-package identity, and both retained build records before a candidate is eligible.
- Added synthetic eligible, missing-artifact, missing-metadata, mismatched-input, and stale-runtime cases. The focused test file passed with 18 expectations.
- Documented the preflight-first sequence and the conditional C++-only runner flow. The R baseline and `run_gtap12a_ab.R` remain prohibited for this gap closure.
- Ran the preflight with an external report destination. It exited blocked with zero inventoried artifacts and zero repetitions; no candidate, solver backend, or checker ran.

## Preflight Status

These machine-readable values are the result of the current attempt:

```text
reference_preflight_status=blocked
reference_csv_count=0
reference_solution_count=0
measured_repetitions=0
warmup_count=0
candidate_backend=StructuredSchurFGMRESCpp
candidate_status=not_run
benchmark_gate_status=not_run
independent_review_status=not_run
num_03_status=open
task2_status=not_applicable_preflight_blocked
task3_status=not_applicable_preflight_blocked
reference_preflight_reason_codes=input_configuration_unavailable,missing_candidate_build_record,missing_closure_file,missing_data_dir,missing_reference_build_record,missing_reference_dir,missing_tablo
reference_source_commit=not_available
reference_source_archive_sha256=not_available
candidate_source_commit=not_available
candidate_source_archive_sha256=not_available
```

The data directory, TABLO file, closure file, reference directory, reference build record, and candidate build record were not supplied through the configured CLI/environment inputs. No external location search was made. The report therefore cannot establish whether compatible raw reference artifacts exist elsewhere. Historical benchmark prose is not raw matched-run evidence.

Tasks 2 and 3 were skipped as not applicable under their plan gates: Task 2 requires `reference_preflight_status=eligible`, and Task 3 can be reached only after both an eligible preflight and a passing unchanged checker. No candidate command or independent-review checkpoint was issued. NUM-03 remains open; no speedup or current full-scale result is claimed.

## Task Commits

1. **Task 1: Add synthetic preflight regressions (TDD red gate)** — `96d118a` (`test(06-21): cover benchmark reference preflight`)
2. **Task 1: Implement reference preflight and procedure** — `a1a472a` (`feat(06-21): add matched benchmark reference preflight`)
3. **Plan metadata:** Summary, STATE, and ROADMAP updates are recorded in the executor completion commit.

## Files Created/Modified

- `benchmarks/preflight_gtap12a_reference.R` — fail-closed, read-only external reference inspection and report.
- `tests/testthat/test-gtap12a-reference-preflight.R` — deterministic synthetic checks without GTAP data or solver execution.
- `docs/release/BENCHMARK-EVIDENCE.md` — build-record schema, preflight command, and conditional C++-only workflow.

## Decisions Made

- A blocked preflight ends this attempt before candidate execution; NUM-03 stays open until matched evidence and independent acceptance exist.
- `independent_review_status=not_run` because the plan's review gate was not reached.

## Deviations from Plan

None. The plan's designed blocked branch was followed: Tasks 2 and 3 were not applicable because Task 1 did not record an eligible reference set.

## Issues Encountered

- The configured external GTAP inputs and both retained build records were absent. The CLI reported the exact missing configuration categories and exited with status 1 as intended.

## User Setup Required

Provide the authorized data directory, TABLO file, closure RDS, existing reference artifact directory, both retained DCF build records, and an external preflight report path before rerunning this plan. The R baseline must not be rerun.

## Next Phase Readiness

The preflight code and procedure are ready. NUM-03 remains blocked pending authorized inputs, eligible pre-existing matched reference evidence, the conditional C++-only run and unchanged gate, and a later independent review.

## Self-Check: PASSED

- Task implementation commit `a1a472a` and TDD red commit `96d118a` exist.
- The focused synthetic test passed after the final code change.
- The live preflight returned `blocked`, exit status 1, with only the reported safe reason codes and zero artifact counts.
- No baseline, solver backend, candidate, or benchmark checker was run.
