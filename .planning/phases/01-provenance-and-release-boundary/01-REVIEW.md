---
phase: 01-provenance-and-release-boundary
reviewed: 2026-08-25T13:03:41Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - docs/provenance/RIGHTS.md
  - docs/release/RELEASE-GATES.md
  - tools/check_release_gates.R
  - tests/testthat/test-release-gates.R
  - docs/provenance/UPSTREAM-REQUEST.md
  - docs/provenance/CLEANROOM.md
  - specs/cleanroom/README.md
  - tools/provenance_inventory.R
  - docs/provenance/EXPECTED-KEYS.csv
  - docs/provenance/PROVENANCE.csv
  - tests/testthat/test-provenance-inventory.R
  - tools/check_name_availability.R
  - tests/testthat/test-name-availability.R
  - docs/release/NAME-CHECK.md
  - GOVERNANCE.md
  - docs/release/REPOSITORY.md
  - docs/provenance/ATTRIBUTION.md
  - CONTRIBUTORS.md
  - NEWS.md
  - tests/testthat/test-attribution-contract.R
  - DESCRIPTION
  - README.md
  - inst/CITATION
findings:
  critical: 8
  warning: 5
  info: 0
  total: 13
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-25T13:03:41Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

The checked-in blocked state and all four targeted test files pass, but the release machinery is not fail-closed under several reachable evidence transitions. Isolated temporary-root reproductions showed that the checker reports `release_ready=TRUE` after removing the integrated-evidence marker, and also reports ready with no `R/` or `src/` tree, no README/CITATION/contributor destinations, and an invalid license string. Separate fixtures proved that native provenance hashes ignore string-literal changes and that an incomplete GitHub result page is accepted as collision-free.

No hardcoded credential or direct command-injection defect was found in the scoped files. The blockers below are correctness and release-integrity defects that can authorize an invalid public release.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Missing integration marker bypasses every integrated release gate

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:1027-1035`
**Issue:** If `Integrated-Evidence-Version` is absent, duplicated, or changed, `release_gate_evaluate()` returns the legacy `base` result instead of failing. The legacy public-domain path reports the canonical evidence root as eligible even when intentional blockers exist. Removing only line 31 from `RIGHTS.md` reproduced `repository_state=eligible` and `release_ready=TRUE`, bypassing provenance, attribution, name, governance, repository, and DESCRIPTION validation.
**Fix:** Reject any marker cardinality or value other than exactly one supported version before consulting the legacy result. Legacy evaluation may inform diagnostics, but must never produce release readiness for an integrated repository.

```r
integratedVersion = release_gate_marker_values(
  rightsLines, "Integrated-Evidence-Version"
)
if (!identical(integratedVersion, "1")) {
  return(release_gate_result(
    reason_codes = "INTEGRATED_EVIDENCE_VERSION_INVALID",
    parse_status = c(base$parse_status, integrated = "fail")
  ))
}
```

### CR-02: Provenance validation is not bound to the source tree

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:705-759`
**Issue:** The integrated gate compares `PROVENANCE.csv` only with the mutable `EXPECTED-KEYS.csv` and checks a few ledger fields. It never extracts symbols from `R/`, `src/`, or `inst/cpp`, and never compares ledger expression hashes with current source. A temporary root containing the evidence documents but no source directories was accepted as release-ready. Source deletion, new symbols, or stale hashes therefore do not block release.
**Fix:** Source `tools/provenance_inventory.R`, require a non-empty source tree, run `provenance_collect_sources(root, include_git = TRUE)`, and call `provenance_validate_ledger(inventory = actual)` as part of the integrated gate. Treat tool absence, extraction failure, Git-evidence failure, and any hash/key mismatch as blocking.

### CR-03: Native provenance hashes erase string literals and preprocessor directives

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/provenance_inventory.R:183-233`
**Issue:** `provenance_mask_native()` replaces string and character literal contents with spaces and removes preprocessor lines. `provenance_native_rows()` then hashes that masked text at lines 307-317. Changing a function from `return "allow"` to `return "deny"` produced identical hashes. Behavior-changing literal or conditional-compilation edits can consequently retain a reviewed provenance status.
**Fix:** Use the current mask only to locate brace boundaries. Build the expression hash from a separate comment-stripping normalizer that preserves literals and preprocessor tokens while normalizing insignificant whitespace. Add regression tests for changed string/character literals and `#if`/`#define` content.

### CR-04: Attribution gate never validates the required public destinations

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:770-849`
**Issue:** The gate validates the ATTRIBUTION tables but never opens `README.md`, `inst/CITATION`, `CONTRIBUTORS.md`, or `NEWS.md`, despite the documented destination contract. It also does not validate allowed role values, non-empty rights bases/destinations, reviewer/date fields, or blocker evidence keys. The synthetic ready root was accepted with all of those destination files absent.
**Fix:** Move the destination-parity checks from `test-attribution-contract.R` into production release-gate code, require all six destinations, and validate the complete role/blocker schema against provenance keys before setting `attribution=pass`. Tests should independently delete or corrupt each destination and expect a stable failure reason.

### CR-05: Any non-placeholder license string is considered finalized

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:1151-1165`
**Issue:** Once `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` is removed, the checker rejects only the exact placeholder `What license is it under?`. It does not require an approved license value or bind the value to dependency-audit evidence. Replacing the field with `definitely-not-a-valid-license` reproduced `release_ready=TRUE`.
**Fix:** Add a reviewed dependency/license decision record containing the exact approved DESCRIPTION license expression and its evidence hash. Require exact equality with that value and validate it using R package license rules; absence or an unsupported expression must fail closed.

### CR-06: Incomplete remote name-search results are accepted as exhaustive

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_name_availability.R:122-149`
**Issue:** The GitHub and R-universe parsers extract names but ignore result counts, page limits, and pagination. The live GitHub request is capped at 100 rows (lines 653-660). A fixture with `total_count: 101` and one non-matching returned item was reported as `NAME_AVAILABLE_NO_EXACT_COLLISION`, so an exact match outside the first page can be missed. The CRAN archive parser similarly treats any HTML-like 200 response with zero package links as a valid empty archive.
**Fix:** Parse and validate source-specific count metadata, fetch all pages until the reported total is covered, and reject truncated or semantically empty responses. For sources without reliable count metadata, require a known index signature plus a defensible minimum structure rather than accepting arbitrary HTML/JSON shells.

### CR-07: Bioconductor checks omit several package repositories

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_name_availability.R:590-619`
**Issue:** Current and historical Bioconductor collection queries only `bioc/src/contrib/PACKAGES` (also lines 637-640). It omits annotation data, experiment data, workflows, and any other installable Bioconductor package repositories. An exact package-name collision in one of those repositories is therefore reported as available.
**Fix:** Enumerate and hash every installable Bioconductor repository for current and historical releases (software, annotation, experiment, workflows, and supported variants), record each query identity separately, and require every source to be available and completely parsed.

### CR-08: Clean-room readiness trusts unverified self-declared strings

**Classification:** BLOCKER
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:108-193`
**Issue:** The clean-room path accepts any non-empty `behavior_test`, `public:` value, and `redistributable:` value when `behavior_test_status: pass` is written in Markdown. It does not require replacement source, resolve the test path, verify a fixture or redistribution basis, bind component evidence to hashes, or consume an independently produced test result. The built-in self-test demonstrates readiness with a nonexistent `self-test#observable-contract` reference and no replacement implementation.
**Fix:** Require hash-bound component source and fixture paths under the evaluated root, validate that referenced tests and public standards exist, and consume a reproducible test-result artifact generated independently of the component record. Missing source, fixtures, tests, or hashes must return `CLEANROOM_EVIDENCE_INCOMPLETE`.

## Warnings

### WR-01: Third-party provenance can pass the inventory tool but can never pass the integrated gate

**Classification:** WARNING
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:747-754`
**Issue:** `provenance_validate_ledger()` supports `third-party` rows with complete upstream and license evidence, while the integrated gate's allowed classification list excludes `third-party` unconditionally. This contradicts `RIGHTS.md:69-71`, which says third-party code remains blocked only until its own basis is established.
**Fix:** Share one classification validator between both tools and allow `third-party` only when all required upstream identity, copyright, license, and reviewed evidence fields pass.

### WR-02: Integrated name parsing marks malformed metadata as passed

**Classification:** WARNING
**File:** `/home/zenz/R/tabloToR/tools/check_release_gates.R:852-911`
**Issue:** `Checked-At-UTC` is not syntax-validated in `release_gate_validate_name()`, and machine rows are not required to contain valid raw MD5 values or approved query identities. With intentional blockers present, `--assert-blocked` can therefore report every parser as `pass` for malformed name evidence; freshness validation happens only after all blockers disappear.
**Fix:** Reuse `name_check_verify_report()` or a shared strict parser during every integrated evaluation. Validate timestamp semantics, raw hash format, exact source query identities, reviewer approval, and source-row grammar before setting `name=pass`.

### WR-03: Standalone ledger validation accepts arbitrary review statuses and dates

**Classification:** WARNING
**File:** `/home/zenz/R/tabloToR/tools/provenance_inventory.R:580-615`
**Issue:** The standalone checker requires `status` and `review_date` only to be non-empty, excluding just three status strings. Values such as `approved-by-unknown-process` and `yesterday` pass. This makes `provenance_status=reviewed` less strict than the integrated release validator and allows malformed review evidence to be blessed by the primary inventory command.
**Fix:** Define an exact allowed status set (including the current reviewed variants), validate real ISO dates, and require reviewer/status/classification combinations through one shared validator used by both commands.

### WR-04: The synthetic-ready test encodes missing-source and missing-destination behavior as success

**Classification:** WARNING
**File:** `/home/zenz/R/tabloToR/tests/testthat/test-release-gates.R:786-869`
**Issue:** `copyIntegratedReleaseEvidence()` copies neither package source nor README/CITATION/CONTRIBUTORS/NEWS, yet the subsequent test expects the root to be release-ready. This makes the suite affirm the CR-02 and CR-04 bypasses instead of detecting them. There is also no negative test for a missing/unknown integration marker or an invalid non-placeholder license.
**Fix:** Build the positive fixture from a complete minimal source and destination tree. Add independent negative cases for source deletion/hash drift, every missing destination, invalid integration marker cardinality/version, and invalid or unapproved license values.

### WR-05: README installation instructions install the upstream package, not this implementation

**Classification:** WARNING
**File:** `/home/zenz/R/tabloToR/README.md:37-42`
**Issue:** The installation command points to `mivanic/tabloToR`, while the remainder of the README documents post-baseline sparse APIs that are not provided by that upstream baseline. A user following the instructions installs different code and then encounters missing methods/backends.
**Fix:** While redistribution is blocked, replace the command with an explicit statement that no public installation URL is authorized and provide local-source development instructions only. After authorization, point installation to the canonical reviewed repository and release.

---

_Reviewed: 2026-08-25T13:03:41Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
