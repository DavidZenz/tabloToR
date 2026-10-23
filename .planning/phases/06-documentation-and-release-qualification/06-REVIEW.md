---
phase: 06-documentation-and-release-qualification
reviewed: 2026-10-23T09:15:59Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - .github/workflows/native-ci.yaml
  - .github/workflows/release-qualification.yaml
  - benchmarks/preflight_gtap12a_reference.R
  - tests/testthat/test-gtap12a-reference-preflight.R
  - docs/release/BENCHMARK-EVIDENCE.md
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-10-23T09:15:59Z  
**Depth:** standard  
**Files Reviewed:** 5  
**Status:** issues_found

## Summary

This post-execution review covers the five committed non-planning files changed after the prior review's 06-13 source boundary. The latest 06-22 summary lists no implementation changes; the existing dirty working-tree files were excluded. Two blockers remain in the benchmark preflight's privacy and evidence-integrity guarantees. The 06-22 summary records that the preflight was blocked because no local benchmark paths were configured and archive qualification was blocked by Matrix 1.6-3 below the 1.6-5 floor. I did not rerun tests or package checks.

## Narrative Findings (AI reviewer)

### CR-06: Invalid build-record values can leak into the preflight report

**Classification:** BLOCKER  
**File:** `benchmarks/preflight_gtap12a_reference.R:873-902,907-915`; privacy contract in `docs/release/BENCHMARK-EVIDENCE.md:87-89`

**Issue:** The validator rejects malformed source commits, archive digests, package versions, and signatures, but the result list still copies those original DCF values with `preflight_text()`. The report is written even when validation has blocked the preflight. If a malformed field contains a local path or other private text, the external DCF report includes it, contrary to the documented promise that reports omit private paths and filenames.

**Fix:** Emit only values that pass their field-specific allowlist; replace invalid values with `redacted` or `not_available`. Apply the same strict sanitization to every field included in the report, and add a regression case with a path-like invalid fingerprint to verify that it is absent from the DCF output.

### CR-07: Eligible preflight results are not bound to the reference files that were read

**Classification:** BLOCKER  
**File:** `benchmarks/preflight_gtap12a_reference.R:324-357,559-625,867-915`; execution sequence in `docs/release/BENCHMARK-EVIDENCE.md:82-129`

**Issue:** The preflight validates reference CSV and RDS contents, then records counts and metadata fingerprints, but does not record a digest of the accepted CSV/RDS files. The documented candidate and comparison commands do not consume or revalidate the preflight report. A reference artifact can therefore change after an `eligible` result (or during the scan), and the later candidate/gate steps can use different reference evidence without detecting that the eligibility decision covered another file state. This leaves the plan's stated mutation-invalidates-attempt condition unenforced.

**Fix:** Compute a deterministic manifest digest for the accepted reference CSVs and measured RDS files, store it in the external DCF report, and require the candidate and comparison steps to verify the same reference-file manifest before proceeding. Abort if any accepted artifact is added, removed, or changed.

## Previous Review Findings Resolved Through 06-13

- **CR-01 (BLOCKER):** Closed in 06-09. `release_gate_validate_release_license_decision()` and `release_gate_validate_license_decision()` call `release_gate_resolve_evidence_path()` before `release_gate_read_lines()`. The symlink regression asserts each stable missing-record code and `parse_status[['license']] == 'fail'`.
- **WR-01 (WARNING):** Closed in 06-09. The missing-record case copies complete integrated evidence and removes only `docs/release/LICENSE-DECISION.md`; it checks `LICENSE_RELEASE_DECISION_MISSING`, failed license parsing, and CLI status 1. The intact blocked fixture checks both blocker IDs, passing parse statuses, and CLI status 0.
- **CR-02 (BLOCKER):** Closed in 06-10. The reviewed fixed evidence readers, hashes, CSV/DCF parsers, and attribution destinations resolve the canonical path before consumption; tests cover escaping evidence links and stable failure codes.
- **CR-03 (BLOCKER):** Closed in 06-10. Both validator callers resolve tool scripts before loading. The tests check stable tool-load errors and absent outside-root canaries.
- **WR-02 (WARNING):** Closed in 06-10. The child prefix preserves a root's trailing slash, and the POSIX root regression resolves a real file beneath `/`.
- **CR-04 (BLOCKER):** Closed in 06-11. The cleanroom directory and each enumerated specification are resolved and root-contained before listing or reading; regressions cover escaping directory and component-file symlinks.
- **CR-05 (BLOCKER):** Closed in 06-11. Provenance candidates are canonicalized and checked as regular in-root files before return, and relative paths require the separator-safe root prefix; tests assert no outside read/extraction/hash and stable integrated failure.
- **WR-03 (WARNING):** Closed in 06-12. The trailing-root regression is now a separate top-level test with its own tool setup and supported-platform assertions, independent of symbolic-link creation.
- **WR-04 (WARNING, closed in 06-13):** **File:** `tests/testthat/test-release-gates.R:3120-3134`. **Original issue:** The POSIX assertion assumed the canonical path for `/etc/hosts` remained the lexical `etc/hosts`. **Resolution:** The test now derives the expected suffix from normalized root and file paths.
- **WR-05 (WARNING, closed in 06-13):** **File:** `tests/testthat/test-release-gates.R:3104-3113`. **Original issue:** The Windows branch parsed a drive root from the checkout path and attempted to write beneath it, which failed for UNC paths and restricted volume roots. **Resolution:** The all-platform regression writes and cleans up a file only beneath a temporary directory and passes that directory with a trailing separator.

### Previous review conclusion

The 06-13 re-review was limited to `tests/testthat/test-release-gates.R` and commit `ddb0d23`; it confirmed the temporary fixture is platform-neutral, cleanup is registered, the POSIX root/file expectation uses canonical paths, and the unavailable `/etc/hosts` case does not skip the cross-platform fixture. Its plan summary records focused test results; those checks were not rerun during this review.

---

_Reviewed: 2026-10-23T09:15:59Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_

