---
phase: 06-documentation-and-release-qualification
plan: 11
subsystem: release-qualification
tags: [R, provenance, symlinks, selected-root, security]
requires:
  - phase: 06
    provides: Canonical selected-root evidence resolution and integrated release-gate parsing.
provides:
  - Canonical in-root regular-file checks for enumerated cleanroom specifications and provenance sources.
  - Stable fail-closed provenance status and separator-safe relative paths for filesystem-root inputs.
affects: [phase-06-verification, release-gates, provenance]
actuals:
  tokens: 3179
  tasks: 1
  commits: 3
tech-stack:
  added: []
  patterns:
    - Canonicalize and contain enumerated evidence paths before content reads, parsing, or hashing.
key-files:
  created:
    - .planning/phases/06-documentation-and-release-qualification/06-11-SUMMARY.md
  modified:
    - tools/check_release_gates.R
    - tools/provenance_inventory.R
    - tests/testthat/test-release-gates.R
key-decisions:
  - "An integrated gate may continue from a blocked base result only when every base parser stream passed."
  - "Use a separator-safe canonical root prefix, preserving an existing trailing slash at filesystem roots."
patterns-established:
  - "Reject an escaping canonical target before returning the source inventory or consuming its contents."
requirements-completed: [REL-01]
coverage:
  - id: D1
    description: Cleanroom specifications and provenance source paths cannot authorize evidence outside the selected root.
    requirement: REL-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#cleanroom specifications stay within selected root"
        status: pass
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#provenance sources stay within selected root"
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-10-20
status: complete
---

# Phase 06 Plan 11: Selected-Root Path Boundary Summary

**Cleanroom attestations and provenance inventory reject canonical paths outside the selected repository root before evidence content is consumed.**

## Performance

- **Duration:** 6 minutes
- **Started:** 2026-10-20T08:27:38Z
- **Completed:** 2026-10-20T08:33:52Z
- **Tasks:** 1
- **Files modified:** 3 task files

## Accomplishments

- Validated the canonical `specs/cleanroom` directory before listing specification names, then resolved every selected-root-relative Markdown file before reading it.
- Canonicalized every enumerated provenance source and rejected non-regular or escaping targets before source extraction, line reads, hashing, or inventory return.
- Made relative-path slicing require a separator-safe root prefix, including `/` and slash-terminated drive roots.
- Mapped `PROVENANCE_SOURCE_OUTSIDE_ROOT` to the integrated gate's stable failure reason and preserved failed parser status.
- Preserved intentional blocked-state behavior while preventing an integrated gate from overwriting a failed base parser stream.

## RED Evidence

- The complete cleanroom fixture passed with an external component Markdown symlink and with an external `specs/cleanroom` directory symlink: both returned `release_ready = TRUE` and `cleanroom = pass` before the fix.
- A same-length root/outside pair with identical `R/processTablo.R` bytes let provenance collection read, parse, and hash the external source. The integrated provenance stream passed and the result retained only the two expected blockers.
- The old trailing-root calculation returned `tc/hosts` for `provenance_relative_path("/etc/hosts", "/")` instead of `etc/hosts`.
- The regressions were committed before production changes in `22415fe`.

## GREEN Verification

Both focused groups passed in separate fresh `Rscript --vanilla` processes with `stop_on_failure = TRUE`:

- `testthat::test_file("tests/testthat/test-release-gates.R", desc = "cleanroom specifications stay within selected root", reporter = "summary", stop_on_failure = TRUE)` — passed; includes a valid in-root cleanroom pass and escaping file/directory symlink failures with `CLEANROOM_EVIDENCE_INCOMPLETE` and `cleanroom = fail`.
- `testthat::test_file("tests/testthat/test-release-gates.R", desc = "provenance sources stay within selected root", reporter = "summary", stop_on_failure = TRUE)` — passed; asserts no external read, extraction, or hash hook runs, direct and integrated stable errors, `/` relative paths, and the unchanged blocked fixture with successful `--assert-blocked`.

No baseline, full test suite, `R CMD check`, source-archive qualification, or benchmark was run, as required by this gap plan.

## Task Commits

1. **Task 1 RED: escaping path regressions** — `22415fe` (`test(06-11): cover escaping cleanroom and provenance sources`)
2. **Task 1 GREEN: selected-root containment** — `afaad58` (`fix(06-11): contain cleanroom and provenance sources`)

## Files Created/Modified

- `tools/check_release_gates.R` — validates cleanroom directory and specification paths, returns provenance escape failures, and preserves base parser failures in integrated evaluation.
- `tools/provenance_inventory.R` — checks canonical source containment and safe relative-path derivation.
- `tests/testthat/test-release-gates.R` — covers file/directory symlinks, no-content-access rejection, in-root controls, blocked-fixture compatibility, and trailing-root behavior.

## Decisions Made

- A blocked base result continues through integrated evidence only when every base parser stream passed. This keeps intentional blockers compatible while preventing failed evidence from being replaced by a later blocked result.
- Canonical containment uses a root prefix that includes exactly one separator, preserving roots that already end in `/`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical behavior] Preserve failed base parser status in integrated results**
- **Found during:** Task 1 GREEN
- **Issue:** The cleanroom evaluator returned `CLEANROOM_EVIDENCE_INCOMPLETE`, but the integrated evaluator continued through intentional blockers and returned `release_ready = TRUE`.
- **Fix:** Continue from a blocked base result only if all base parser statuses passed.
- **Files modified:** `tools/check_release_gates.R`, `tests/testthat/test-release-gates.R`
- **Verification:** Both focused groups pass; the in-root blocked control still has the two exact blockers, passing parser statuses, and successful `--assert-blocked`.
- **Committed in:** `afaad58`

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Required for the cleanroom boundary failure to remain fail-closed in the integrated public gate; no API or intentional blocker changed.

## Issues Encountered

- The provenance tool is loaded into an environment whose parent is `baseenv()`, so the regular-file predicate must be namespace-qualified as `utils::file_test()`.
- Windows drive-root behavior is covered conditionally but was not exercised on this POSIX host.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The selected-root dynamic-path findings are closed. Phase 06 still requires its separate verification and other outstanding technical/release evidence; this plan does not clear release blockers.

## Self-Check: PASSED

- Summary file exists at the planned path.
- Task commits `22415fe` and `afaad58` exist.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-20*
