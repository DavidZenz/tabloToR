---
phase: 03-gemodelr-identity-migration
plan: 14
subsystem: testing
tags: [R, testthat, benchmark-gate, solution-evidence, migration]

# Dependency graph
requires:
  - phase: 03-gemodelr-identity-migration
    provides: Installed benchmark child, schema-2 solution artifacts, and Phase 02 numerical tolerance authority from Plan 03-13
provides:
  - Fail-closed A/B correctness gate requiring complete measured CSV/RDS evidence
  - Radix-keyed pair comparison with recursive shape, name, type, dimname, and finiteness validation
  - Deterministic malformed-artifact, warmup, ordering, duplicate-key, and inclusive-boundary regression coverage
affects: [03-20 final qualification, benchmark verification, MIGR-01, MIGR-02]

# Actuals (#2632)
actuals:
  tokens: 23929
  tasks: 2
  commits: 5

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Guarded sourceable R benchmark CLIs expose validation helpers without consuming test command arguments.
    - Measured CSV rows and schema-2 RDS artifacts are cross-bound by backend/run identity before radix-keyed comparison.
    - Warmup metadata is validated when present but excluded from measured solution-set requirements and pair comparison.
    - Source and installed benchmark resources remain byte-identical.
key-files:
  created:
    - tests/testthat/test-benchmark-correctness-gate.R
  modified:
    - benchmarks/check_benchmark_gate.R
    - inst/benchmarks/check_benchmark_gate.R

key-decisions:
  - "Require exactly one validated solution RDS for every measured backend/run_id while allowing warmup-only CSV evidence to remain outside measured comparison."
  - "Pair reference and candidate artifacts only by the exact pair_signature/repetition tuple, radix-sort the keys, and reject duplicate tuples rather than resolving them by order."
  - "Treat recursive selected_outputs and solution leaves as numerical evidence with exact type, class, names, dimensions, dimnames, and finite-difference checks."
  - "Keep Phase 02 strict tolerance rows independent from benchmark CLI maximum-difference thresholds."

patterns-established:
  - "Correctness gates fail closed before writing a passing summary whenever evidence is missing, duplicated, malformed, nonfinite, or misbound."
  - "Installed subprocess regressions use temporary evidence only and verify the packaged resource path separately from source-tree parity."

requirements-completed: [COMP-04, MIGR-01, MIGR-02]

coverage:
  - id: D1
    description: "Installed A/B correctness gate proves a matched CSV/RDS pair and rejects metrics-only CSV evidence."
    requirement: MIGR-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-benchmark-correctness-gate.R#installed benchmark gate requires a matched solution pair"
        status: pass
      - kind: other
        ref: "rtk R --vanilla -q -e testthat::test_local(filter=benchmark-correctness-gate, reporter=summary, stop_on_failure=TRUE)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Malformed and incomplete CSV/RDS evidence is rejected before comparison, including metadata, signature, shape, type, dimname, NULL/empty, nonfinite, and overflow cases."
    requirement: MIGR-02
    verification:
      - kind: unit
        ref: "tests/testthat/test-benchmark-correctness-gate.R#benchmark correctness gate rejects malformed and incomplete evidence"
        status: pass
    human_judgment: false
  - id: D3
    description: "Warmup exclusion, radix-keyed ordering, duplicate-key rejection, zero/0.5/0.75 boundary behavior, exact source/installed parity, and Phase 02 tolerance independence are deterministic."
    requirement: COMP-04
    verification:
      - kind: unit
        ref: "tests/testthat/test-benchmark-correctness-gate.R#benchmark correctness gate handles warmups, ordering, and boundaries"
        status: pass
      - kind: unit
        ref: "tests/testthat/test-benchmark-correctness-gate.R#benchmark correctness evidence preserves Phase 02 authority and mirrors"
        status: pass
    human_judgment: false

# Metrics
duration: 1h 26m
completed: 2026-09-18
status: complete
---

# Phase 03 Plan 14: Benchmark Correctness Evidence Summary

**Fail-closed GEModelR A/B benchmark comparison with schema-bound solution evidence, stable tuple pairing, and deterministic CR-05/MIGR-02 edge coverage**

## Performance

- **Duration:** 1h 26m
- **Started:** 2026-09-18T12:15:42+02:00
- **Completed:** 2026-09-18T13:42:12+02:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced the metrics-only benchmark gate with a guarded, sourceable validation pipeline that requires schema-2 solution RDS evidence for every measured backend/run and writes only finite successful summaries.
- Added exact CSV/RDS identity checks, radix-ordered pair_signature/repetition pairing, duplicate-key rejection, recursive selected-output comparison, and strict numeric leaf shape/type/finiteness validation.
- Added deterministic regression coverage for malformed artifacts, signature and metadata mismatches, warmups, reordered two-repetition inputs, duplicate comparison keys, zero/at-threshold/above-threshold differences, and independent Phase 02 tolerance authority.
- Preserved exact byte parity between benchmarks/check_benchmark_gate.R and inst/benchmarks/check_benchmark_gate.R.

## Task Commits

Each task was committed atomically:

1. **Task 1: Prove one CSV/RDS pair through the installed A/B CLI**
   - 9e838bc (test)
   - f13789e (feat)
2. **Task 2: Expand pairing, shape, finiteness and boundary regressions**
   - a97f7f8 (test)
   - 77b4eb6 (fix)

**Plan metadata:** final documentation commit is created with this summary.

## Files Created/Modified

- benchmarks/check_benchmark_gate.R - Guarded CLI and fail-closed CSV/RDS validation, pairing, recursive comparison, and finite summary gate.
- inst/benchmarks/check_benchmark_gate.R - Exact installed-resource mirror of the source gate.
- tests/testthat/test-benchmark-correctness-gate.R - Installed valid-pair/CSV-only proof plus malformed, warmup, ordering, duplicate-key, boundary, parity, and tolerance regressions.

## Decisions Made

- Measured solution evidence is mandatory and uniquely keyed; warmup CSV metadata is validated, but warmup artifacts never create measured comparison pairs.
- Backend run signatures may differ; pair and model signatures must agree at the matched tuple.
- Inclusive maximum-difference behavior is enforced with exact representable 0.5 evidence and no generic reinterpretation of Phase 02 tolerances.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The provided patch helper was unavailable because the runtime could not create its sandbox namespace. Narrow, file-scoped Node-based edits were used as a fallback; only the three declared plan files were changed.
- The focused suite retains the repository's pre-existing R6 local-field-assignment warning; all benchmark-gate assertions passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03-20 can run the installed qualification against a gate that cannot pass on metrics-only, missing, reordered, duplicated, malformed, or nonfinite solution evidence.
- The exact source/installed resource boundary and Phase 02 tolerance authority are independently regression-tested.
- No release, publication, canonical baseline refresh, or unrelated artifact mutation was performed.

---
*Phase: 03-gemodelr-identity-migration*
*Completed: 2026-09-18*

## Self-Check: PASSED

- Summary file exists and contains `status: complete`.
- Task commits 9e838bc, f13789e, a97f7f8, and 77b4eb6 are present.
- Declared source, installed mirror, and focused regression files exist.
