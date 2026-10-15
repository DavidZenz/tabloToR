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
        ref: "Inputs and source package prepared locally; run not started because no maintainer-designated signer is configured"
        status: pending-user-setup
    human_judgment: false

duration: 3 min
completed: 2026-10-06
status: awaiting-signing-identity
---

# Phase 06 Plan 05: Benchmark Evidence Procedure Summary

**The local inputs, closure, output directory, and exact source installation are prepared; the full-scale run remains pending a maintainer-designated signing identity.**

## Accomplishments

- Documented the existing A/B runner, independent gate invocation, required NUM-03 result fields, output redaction, and unchanged acceptance thresholds.
- Specified an armored detached GPG signature over the final summary and full-fingerprint verification against a trusted public-key source.
- Kept MD5 values labeled as fingerprints and retained the separate Phase 1 legal and attribution blockers.
- Staged the four runner inputs outside the repository with private permissions and created the closure RDS from the existing 53-variable GTAPinR example closure.
- Built the source archive from commit `ae3ba3cb1e16e18ad1bd0567a91d2933580b13be` and installed GEModelR 0.1.0 into a temporary library. Archive SHA-256: `8d3774d787dcef7b8f7a95c1a85e41093161e454ac7386241da1e72b5ca372fc`.
- Confirmed the host has 12 logical CPUs and 62 GiB RAM; the plan's four-thread setting fits.

## Task Commit

1. **Specify the checked benchmark summary and detached-signature policy** - `2ca2d73` (`docs`)

## Pending Task: Full-Scale External Benchmark

The authorized input files, closure RDS, and external output directory are
prepared on the local benchmark host. The package built and installed from the
exact source commit into an isolated temporary library. The host has no GPG
secret key, and `GEMODELR_BENCHMARK_SIGNING_FINGERPRINT` is unset. No
maintainer-designated trusted public-key source has been supplied.

The full-scale run has not started, and no result summary or signature was
produced. Plan 06-05 Task 2 remains pending because its signer precondition is
not met; NUM-03 remains pending.

## Next Step

Provision or identify the maintainer-designated GPG key on this host and
provide its full fingerprint plus a trusted public-key source. Then run Plan
06-05 Task 2 with the prepared external inputs and temporary package library.
The runner and independent checker must both pass before a redacted result is
appended and signed.

---
*Phase: 06-documentation-and-release-qualification*
*Status: awaiting user setup*
