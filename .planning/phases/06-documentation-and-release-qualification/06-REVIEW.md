---
phase: 06-documentation-and-release-qualification
reviewed: 2026-10-20T08:59:45Z
depth: deep
files_reviewed: 3
files_reviewed_list:
  - tools/check_release_gates.R
  - tests/testthat/test-release-gates.R
  - tools/provenance_inventory.R
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-10-20T08:59:45Z  
**Depth:** deep  
**Files Reviewed:** 3  
**Status:** issues_found

## Summary

The cumulative Phase 06 review covers the selected-root and provenance changes from 06-09 through 06-12. The 06-12 test change moves trailing-root coverage into its own top-level `test_that()` and loads the provenance tool independently, so symlink creation in the following symlink-security test cannot skip it. The adjacent outside-root symlink assertions remain intact, including checks that the outside source is not read, extracted, or hashed and that integrated validation fails with `PROVENANCE_SOURCE_OUTSIDE_ROOT`. The new test has portability gaps: its POSIX expected value assumes `/etc/hosts` keeps the lexical `etc/hosts` path after canonicalization, and its Windows branch assumes a local drive-letter checkout and write access at the volume root. The prior selected-root and blocked-result findings are also closed as summarized below. Tests were not run for this review.

## Resolved Findings from Previous Review

- **CR-01 (BLOCKER):** Closed in 06-09. `release_gate_validate_release_license_decision()` and `release_gate_validate_license_decision()` call `release_gate_resolve_evidence_path()` before `release_gate_read_lines()`. The symlink regression asserts each stable missing-record code and `parse_status[['license']] == 'fail'`.
- **WR-01 (WARNING):** Closed in 06-09. The missing-record case copies complete integrated evidence and removes only `docs/release/LICENSE-DECISION.md`; it checks `LICENSE_RELEASE_DECISION_MISSING`, failed license parsing, and CLI status 1. The intact blocked fixture checks both blocker IDs, passing parse statuses, and CLI status 0.
- **CR-02 (BLOCKER):** Closed in 06-10. The reviewed fixed evidence readers, hashes, CSV/DCF parsers, and attribution destinations resolve the canonical path before consumption; tests cover escaping evidence links and stable failure codes.
- **CR-03 (BLOCKER):** Closed in 06-10. Both validator callers resolve tool scripts before loading. The tests check stable tool-load errors and absent outside-root canaries.
- **WR-02 (WARNING):** Closed in 06-10. The child prefix preserves a root's trailing slash, and the POSIX root regression resolves a real file beneath `/`.
- **CR-04 (BLOCKER):** Closed in 06-11. The cleanroom directory and each enumerated specification are resolved and root-contained before listing or reading; regressions cover escaping directory and component-file symlinks.
- **CR-05 (BLOCKER):** Closed in 06-11. Provenance candidates are canonicalized and checked as regular in-root files before return, and relative paths require the separator-safe root prefix; tests assert no outside read/extraction/hash and stable integrated failure.
- **WR-03 (WARNING):** Closed in 06-12. The trailing-root regression is now a separate top-level test with its own tool setup and supported-platform assertions, independent of symbolic-link creation.

## Narrative Findings (AI reviewer)

### WR-04 (WARNING): POSIX assertion assumes `/etc/hosts` has no symlinked parent

**File:** `tests/testthat/test-release-gates.R:3116-3119`  
**Issue:** The helper canonicalizes both arguments with `normalizePath()`, but the assertion hard-codes `etc/hosts`. On POSIX systems where `/etc` resolves through a symlink (for example, `/etc` to `/private/etc`), the correct helper result is `private/etc/hosts`, so this regression test fails even when the helper handles `/` correctly.  
**Fix:** Derive the expected relative value from the normalized file path under the normalized `/` root, or use a fixture whose canonical path is known on each supported platform.

### WR-05 (WARNING): Windows assertion can skip or derive an invalid volume root

**File:** `tests/testthat/test-release-gates.R:3106-3111`  
**Issue:** Taking the first three characters of the checkout path assumes a local drive-letter path; a UNC checkout produces an invalid root such as `//s`. Even for a local drive, creating a file directly under `C:/` commonly fails for a non-administrator, turning the intended Windows coverage into a skip.  
**Fix:** Derive a valid volume root for local and UNC paths and use an existing readable file under that root, or another fixture strategy that tests the trailing-root case without requiring write permission at the volume root.

---

_Reviewed: 2026-10-20T08:59:45Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: deep_

