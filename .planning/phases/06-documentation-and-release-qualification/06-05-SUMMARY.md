---
phase: 06-documentation-and-release-qualification
plan: 05
subsystem: benchmark-evidence
tags: [GTAP 12a, benchmark, GPG, provenance]

requires:
  - phase: 06-02
    provides: External full-scale benchmark instructions
  - phase: 06-04
    provides: Release boundaries and exact current blockers
provides:
  - Repository-only procedure for running and checking the full-scale A/B benchmark
  - Redacted public summary fields and detached GPG signature/verification policy
affects: [NUM-03, phase-06 release qualification]

actuals:
  tasks_complete: 1
  tasks_total: 2
  commits: 1

key-files:
  created:
    - docs/release/BENCHMARK-EVIDENCE.md

key-decisions:
  - "Treat MD5-derived model, package, pair, and run values as fingerprints, not signer authentication."
  - "Keep all GTAP inputs and detailed run outputs outside the repository; sign only the final redacted summary with a maintainer-designated external key."

requirements-completed: []

coverage:
  - id: D1
    description: "Benchmark run, acceptance, redaction, and signature procedure"
    requirement: NUM-03
    verification:
      - kind: other
        ref: "Required-command scan for runner, checker, gate fields, fingerprint policy, and GPG verification"
        status: pass
    human_judgment: false
  - id: D2
    description: "Current full-scale run and detached signature"
    requirement: NUM-03
    verification:
      - kind: external
        ref: "Not run: all four authorized-input/output variables and designated signing fingerprint are unset"
        status: pending-user-setup
    human_judgment: false

duration: 3 min
completed: 2026-10-06
status: awaiting-user-setup
---

# Phase 06 Plan 05: Benchmark Evidence Procedure Summary

**The repository-only procedure is ready; the full-scale result remains pending external benchmark inputs, hardware, and signer setup.**

## Accomplishments

- Documented the existing A/B runner, independent gate invocation, required NUM-03 result fields, output redaction, and unchanged acceptance thresholds.
- Specified an armored detached GPG signature over the final summary and full-fingerprint verification against a trusted public-key source.
- Kept MD5 values labeled as fingerprints and retained the separate Phase 1 legal and attribution blockers.

## Task Commit

1. **Specify the checked benchmark summary and detached-signature policy** - `2ca2d73` (`docs`)

## Pending Task: Full-Scale External Benchmark

The required environment variables are currently unset:

- `GEMODELR_GTAP12A_DATA_DIR`
- `GEMODELR_GTAP12A_TABLO`
- `GEMODELR_GTAP12A_CLOSURE_FILE`
- `GEMODELR_GTAP12A_OUTPUT_DIR`
- `GEMODELR_BENCHMARK_SIGNING_FINGERPRINT`

No proprietary inputs were accessed, no full-scale run was started, and no
summary or signature was produced. NUM-03 remains pending until the authorized
inputs and temporary output location are available outside the repository and
the maintainer-designated key is available in the local GPG keyring.

## Next Step

Set the five variables in the authorized local environment, then resume Plan
06-05 Task 2. The runner and independent checker must both pass before a
redacted result is appended and signed.

---
*Phase: 06-documentation-and-release-qualification*
*Status: awaiting user setup*
