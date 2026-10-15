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
  - Completed C++-only full-scale measurements retained outside the repository
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
        ref: "C++-only full-scale run completed (one warm-up, three measurements); no matched reference or A/B gate was run"
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
- Following the user's direction, stopped the R reference run and completed one C++ warm-up plus three C++ measurements at four effective threads. The repetitions completed with finite outputs, no dense full-system operations, and identical zero-shock solutions; raw records and a redacted candidate-only summary remain outside the repository.

## Pending Task: Matched A/B Acceptance

The candidate-only measurements do not provide a matched reference record, so
the A/B checker was not run and NUM-03 remains pending. The existing R baseline
is retained as historical; it was not rerun. The C++ run had no shocks file and
its 26,781,398-entry solution was all zero, so it is evidence only for the
configured zero-shock run.

The candidate-only summary and full records are stored outside the checkout.
The benchmark CSV's automatic `git_commit` field is `NA` because the shell's
Homebrew Git binary cannot run against the host glibc; source commit and archive
SHA-256 are available from the package-build record.

## Next Step

Keep NUM-03 pending unless an approved matched-reference policy is established
and its corresponding comparison gate passes. Do not describe the C++-only
measurements as a current A/B acceptance result.

---
*Phase: 06-documentation-and-release-qualification*
*Status: in progress*
