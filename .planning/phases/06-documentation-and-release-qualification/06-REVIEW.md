---
phase: 06-documentation-and-release-qualification
reviewed: 2026-10-19T15:12:12Z
depth: standard
files_reviewed: 33
files_reviewed_list:
  - .Rbuildignore
  - DESCRIPTION
  - README.md
  - NEWS.md
  - _pkgdown.yml
  - .github/workflows/pkgdown.yaml
  - vignettes/first-simulation.Rmd
  - vignettes/helpers.R
  - vignettes/legacy-to-sparse.Rmd
  - vignettes/backend-selection.Rmd
  - vignettes/diagnostics-memory-budgeting.Rmd
  - vignettes/external-full-scale-benchmarking.Rmd
  - vignettes/architecture.Rmd
  - vignettes/contributing.Rmd
  - pkgdown/index.md
  - docs/release/VERSION-LIFECYCLE.md
  - docs/release/RELEASE-CHECKLIST.md
  - docs/release/RELEASE-GATES.md
  - docs/release/BENCHMARK-EVIDENCE.md
  - docs/release/LICENSE-DECISION.md
  - docs/provenance/EXPECTED-KEYS.csv
  - docs/provenance/PROVENANCE.csv
  - docs/provenance/INVENTORY-REVIEW.csv
  - docs/provenance/ATTRIBUTION.md
  - docs/provenance/LICENSE-DECISION.md
  - inst/CITATION
  - tests/testthat/test-release-gates.R
  - tools/provenance_inventory.R
  - tools/check_release_gates.R
  - tools/ci/build-pkgdown-site.R
  - tools/ci/check-public-content.cjs
  - tools/ci/check-public-content.test.cjs
  - tools/ci/check-license-decision.R
findings:
  critical: 3
  warning: 2
  info: 0
  total: 5
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-10-19T15:12:12Z  
**Depth:** standard  
**Files Reviewed:** 33  
**Status:** issues_found

## Summary

The Phase 06 package, documentation, provenance, and release-gate files were reviewed. Three blockers remain in the submitted implementation: the integrated release gate does not validate the separately designated authoritative license record, the public-content scanner can be bypassed with HTML named entities, and NEWS reports a license that conflicts with the selected package license.

The phase record says full archive qualification remains halted because the local Matrix version is below the declared minimum and the canonical repository/site URLs return 404. It also reports a current-source provenance mismatch and that NUM-03 has no matched reference A/B result. Those are recorded as qualification limitations, not treated as evidence that the reviewed code is correct. Tests and package checks were not rerun during this review.

## Critical Issues

### CR-01: Integrated release gate skips the authoritative license record

**Classification:** BLOCKER  
**File:** `tools/check_release_gates.R:1599-1601,1765-1772`; contract in `docs/release/RELEASE-GATES.md:34`

**Issue:** The integrated gate validates only `docs/provenance/LICENSE-DECISION.md`. It never checks `docs/release/LICENSE-DECISION.md` or invokes the preflight that validates that record. The documented package-license gate requires both records. After the active blockers are cleared, `tools/check_release_gates.R` can report release readiness even if the designated release decision is missing or disagrees with DESCRIPTION.

**Fix:** Validate both decision records in the integrated gate and require their license, reviewer, date, authority, citation, and blocker fields to agree with DESCRIPTION and the live gate state. Add a regression case for a missing or conflicting release decision.

### CR-02: HTML named entities bypass public-content marker checks

**Classification:** BLOCKER  
**File:** `tools/ci/check-public-content.cjs:340-355`

**Issue:** `contentViolation()` decodes only selected numeric HTML entities and `%2f`. It does not decode named entities such as `&sol;`. An HTML page containing `docs&sol;provenance&sol;...` is rendered by a browser with slash characters, but the scanner's repository-only path marker does not match it. The site/artifact gate can therefore accept content that its policy intends to reject.

**Fix:** Normalize HTML entities with a complete decoder before applying markers (and normalize encoded URL characters consistently). Add a regression case using `&sol;` in generated HTML.

### CR-03: NEWS gives a conflicting package-license status

**Classification:** BLOCKER  
**File:** `NEWS.md:22-24`

**Issue:** NEWS says the package license is unresolved and describes Apache-2.0 as provisional, while DESCRIPTION and both current license-decision records select GPL-3.0-or-later. NEWS is included in the source archive, so users receive contradictory license information.

**Fix:** State that GPL-3.0-or-later is the selected package license and that the dependency-compatibility audit and attribution-identity blockers still prevent release.

## Warnings

### WR-01: Vignette links resolve to pages the pkgdown site does not build

**Classification:** WARNING  
**File:** `vignettes/diagnostics-memory-budgeting.Rmd:101-103`; `vignettes/legacy-to-sparse.Rmd:91-92`; `vignettes/backend-selection.Rmd:88-90`

**Issue:** The diagnostics article links to bare `GEModelR-package.html`, which resolves under `/articles/` instead of the generated `/reference/` directory. The migration articles link to `../MIGRATION.html`, but the site configuration does not build the root `MIGRATION.md` as an HTML page; the configured migration navigation instead points to GitHub. These links are broken in the generated site.

**Fix:** Link the reference page as `../reference/GEModelR-package.html`, and use the configured migration URL or add a migration article to the site.

### WR-02: Package-facing files link to evidence omitted from the source archive

**Classification:** WARNING  
**File:** `.Rbuildignore:12,26-27`; references in `README.md:23-28,70-71` and `inst/CITATION:25-29`

**Issue:** The source archive excludes `.planning/`, `docs/provenance/`, and `docs/release/`, but the README and installed citation still point to files in those directories. Readers of the built archive cannot follow those relative references to the cited provenance, rights, or compatibility evidence.

**Fix:** Replace archive-facing relative references with stable accessible URLs, or remove them and keep the relevant concise status inline. Keep repository-only evidence excluded from the archive.

---

_Reviewed: 2026-10-19T15:12:12Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
