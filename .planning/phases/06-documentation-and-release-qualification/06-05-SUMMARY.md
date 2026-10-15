---
phase: 06-documentation-and-release-qualification
plan: 05
subsystem: benchmark-evidence
tags: [GTAP 12a, benchmark, unsigned evidence, provenance]

requires:
  - phase: 06-02
    provides: External full-scale benchmark instructions
  - phase: 06-04
    provides: Release boundaries and exact current blockers
provides:
  - Repository-only procedure for running and checking the full-scale A/B benchmark
  - Redacted public summary fields and an explicit unsigned-evidence policy
affects: [NUM-03, phase-06 release qualification]

actuals:
  tasks_complete: 1
  tasks_total: 2
  commits: 1

key-files:
  created:
    - docs/release/BENCHMARK-EVIDENCE.md

key-decisions:
  - "A GPG key is not required for numerical benchmark acceptance; the result summary is explicitly unsigned."
  - "Treat MD5-derived model, package, pair, and run values as fingerprints, not author authentication."
  - "Keep all GTAP inputs and detailed run outputs outside the repository."

requirements-completed: []

coverage:
  - id: D1
    description: "Benchmark run, acceptance, redaction, and unsigned-evidence procedure"
    requirement: NUM-03
    verification:
      - kind: other
        ref: "Required-content scan for runner, checker, gate fields, fingerprint policy, and unsigned status"
        status: pass
    human_judgment: false
  - id: D2
    description: "Current full-scale run and independent gate"
    requirement: NUM-03
    verification:
      - kind: external
        ref: "Inputs, closure, output directory, and source package prepared locally; full-scale A/B runner is active"
        status: in-progress
    human_judgment: false

duration: 3 min
completed: 2026-10-15
status: in-progress
---

# Phase 06 Plan 05: Benchmark Evidence Procedure Summary

**The local inputs, closure, output directory, and exact source installation are prepared. The result will be unsigned; no GPG key is needed.**

## Accomplishments

- Documented the existing A/B runner, independent gate invocation, required NUM-03 result fields, output redaction, and unchanged acceptance thresholds.
- Updated the procedure to require the benchmark gate and independent checker while explicitly omitting cryptographic author authentication.
- Kept MD5 values labeled as fingerprints and retained the separate Phase 1 legal and attribution blockers.
- Staged the four runner inputs outside the repository with private permissions and created the closure RDS from the existing 53-variable GTAPinR example closure.
- Built the source archive from commit `ae3ba3cb1e16e18ad1bd0567a91d2933580b13be` and installed GEModelR 0.1.0 into a temporary library. Archive SHA-256: `8d3774d787dcef7b8f7a95c1a85e41093161e454ac7386241da1e72b5ca372fc`.
- Confirmed the host has 12 logical CPUs and 62 GiB RAM; the plan's four-thread setting fits.

## Pending Task: Full-Scale External Benchmark

The authorized input files, closure RDS, and external output directory are
prepared on the local benchmark host. The package built and installed from the
exact source commit into an isolated temporary library. The user's decision is
to keep the summary unsigned, so there is no signer setup requirement.

The full-scale A/B runner is active. NUM-03 remains pending until the runner's
gate and independent checker both pass.

## Next Step

After the runner exits successfully, run the independent checker against the
same external output directory. Append a redacted, unsigned result only if
both gates pass.

---
*Phase: 06-documentation-and-release-qualification*
*Status: in progress*
