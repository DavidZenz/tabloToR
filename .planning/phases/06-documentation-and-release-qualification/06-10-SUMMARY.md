---
phase: 06-documentation-and-release-qualification
plan: 10
subsystem: release-qualification
tags: [R, release-gates, path-containment, symlinks]
requires:
  - phase: 06-09
    provides: Integrated release evidence validation and exact blocked-state checks
provides:
  - Canonical selected-root reads for fixed release evidence and validator scripts
  - Filesystem-root-safe selected-root containment
affects: [release-qualification, provenance, release-gates]
actuals:
  tokens: 6400
  tasks: 1
  commits: 2
tech-stack:
  added: []
  patterns: [Resolve selected-root paths before reading, hashing, parsing, or sourcing]
key-files:
  created: [.planning/phases/06-documentation-and-release-qualification/06-10-SUMMARY.md]
  modified: [tools/check_release_gates.R, tests/testthat/test-release-gates.R]
key-decisions:
  - Preserve each gate's existing failure reason and parser stream when selected-root resolution fails.
  - Keep the existing lifecycle blockers unchanged; Windows drive-root behavior remains unverified on this Linux host.
patterns-established:
  - Fixed release inputs and validator scripts are consumed only through canonical in-root regular paths.
requirements-completed: [REL-01]
coverage:
  - id: D1
    description: Fixed release evidence and validator paths are bound to the selected root before use.
    requirement: REL-01
    verification:
      - kind: unit
        ref: tests/testthat/test-release-gates.R#fixed selected-root evidence fails closed
        status: pass
      - kind: unit
        ref: tests/testthat/test-release-gates.R#selected-root validator symlinks are never sourced
        status: pass
    human_judgment: false
  - id: D2
    description: Resolver accepts real evidence beneath the POSIX filesystem root and retains blocked-state behavior.
    verification:
      - kind: unit
        ref: tests/testthat/test-release-gates.R#release gate resolver accepts filesystem-root evidence
        status: pass
      - kind: unit
        ref: tests/testthat/test-release-gates.R#assert-blocked validates integrated evidence
        status: pass
    human_judgment: false
duration: 28min
completed: 2026-10-20
status: complete
---

# Phase 06 Plan 10: Selected-Root Evidence Summary

**Fixed release inputs now resolve to canonical in-root regular files before they are read, hashed, parsed, or sourced.**

## Performance

- **Duration:** 28 minutes
- **Started:** 2026-10-20T07:44:40Z
- **Completed:** 2026-10-20T08:12:18Z
- **Tasks:** 1
- **Files modified:** 2 implementation/test files

## Accomplishments

- Bound legacy and integrated rights, release, upstream, cleanroom, provenance, attribution, repository, name, DESCRIPTION, pkgdown, license, and dependency-audit evidence to the selected root.
- Resolved provenance and name-check validator scripts before `sys.source()` and added outside-root canaries proving neither script executes through an escaping symlink.
- Fixed containment for roots that already end in `/`; the POSIX filesystem-root regression passes.
- Preserved stable reason codes, parser stream statuses, and the intentionally blocked fixture's exact active blockers.

## Task Commits

1. **Task 1 RED tests:** `c687e60` — `test(06-10): cover selected-root release evidence boundaries`
2. **Task 1 GREEN implementation:** `4f7c164` — `fix(06-10): bind release evidence to selected root`

## Verification

Each focused group ran in its own `Rscript --vanilla` process with `stop_on_failure = TRUE`:

- `fixed selected-root evidence fails closed` — passed (`release-gates: ...........................................................`)
- `selected-root validator symlinks are never sourced` — passed (`release-gates: ........`)
- `release gate resolver accepts filesystem-root evidence` — passed (`release-gates: .`)
- `assert-blocked validates integrated evidence` — passed (`release-gates: .........`)
- `git diff --check` for both task files — passed.

The three new boundary groups failed in RED as expected: outside evidence was consumed, the validator canaries were written, and `/` containment returned `NULL`. The pre-existing `assert-blocked` group passed during RED. Full-suite checks, R CMD check, archive checks, and benchmarks were not run, as this gap plan explicitly excludes them.

## Fixed-Path Call-Site Audit and Remaining Dynamic Reads

The plan's fixed evidence list and existing governance, citation, license-decision, and dependency-audit paths now pass through `release_gate_resolve_evidence_path()` before use. The loader receives only the canonical validator path. A broader call-site scan found these dynamic enumerations outside that fixed-path list:

- `tools/check_release_gates.R:198` (`release_gate_evaluate_cleanroom`) enumerates `specs/cleanroom/*.md` and reads each listed path at line 269 without resolving it first. A valid outside-root component specification could contribute to a passing cleanroom stream; this path can affect authorization and merits a follow-up closure plan.
- `tools/check_release_gates.R:575` (`release_gate_has_sensitive_evidence`) recursively enumerates files beneath `docs/provenance`, `docs/release`, and `specs/cleanroom`, then reads them at line 599. Its result only adds a sensitive-evidence failure, so an outside file can conservatively block but cannot authorize a pass.
- `tools/check_release_gates.R:1037` (`release_gate_validate_current_source`) calls `provenance_collect_sources(root)` after loading the validator from a canonical path. `tools/provenance_inventory.R:41` (`provenance_source_files`) recursively enumerates `R/`, `src/`, and `inst/cpp/`; `tools/provenance_inventory.R:581` (`provenance_collect_sources`) reads the resulting normalized paths. This inventory controls provenance validation and can affect whether its parser stream passes; no escaping-source symlink regression was run here. The helper lives outside this plan's two-file change scope and should be evaluated in a follow-up.

These dynamic-read findings are recorded for the orchestrator's scope decision; this plan did not silently treat them as fixed-path coverage.

## Platform Limitations

The POSIX `/` root and symlink cases ran successfully on Linux. The Windows active-drive-root branch was not exercised on this host. Symlink regressions are conditionally skipped by the tests only on platforms that cannot create symbolic links.

## Deviations from Plan

None. Added one additional direct regression for the license validator's separate DESCRIPTION read while keeping the same two code/test files.

## Self-Check: PASSED

- Summary file exists at the planned path.
- Task commits `c687e60` and `4f7c164` exist.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-20*
