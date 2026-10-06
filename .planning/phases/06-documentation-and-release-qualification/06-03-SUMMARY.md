---
phase: 06-documentation-and-release-qualification
plan: 03
subsystem: documentation
tags: [R, pkgdown, rmarkdown, Rcpp, native-ci]

# Dependency graph
requires:
  - phase: 06-01
    provides: [isolated pkgdown destination, archive-based site builder, first-simulation guide]
  - phase: 06-02
    provides: [four additional user guide articles]
provides:
  - Source-backed architecture and contributor articles
  - Navigation for all user and maintainer articles, API reference, and migration guide
affects: [pkgdown, contributor documentation, DOCS-02, DOCS-03]

# Actuals (#2632): chars/4 over the plan deliverable diff.
actuals:
  tokens: 2566
  tasks: 1
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Audience-grouped pkgdown article navigation using vignette basenames as IDs
    - Generate the site from the scanned source archive in an isolated temporary directory

key-files:
  created:
    - vignettes/architecture.Rmd
    - vignettes/contributing.Rmd
  modified:
    - _pkgdown.yml

key-decisions:
  - "Expose the five user articles and two maintainer articles alongside the generated API reference and canonical migration link."
  - "Keep the site-output privacy gate halted because pkgdown's default pages render release and provenance details from package-root sources."

patterns-established:
  - "Maintainer guidance traces model, solver, native, test, and CI ownership to current package sources."
  - "Use an archive-based site build so checkout-only repository files cannot enter the generated site."

requirements-completed: []

# Coverage metadata
coverage:
  - id: D1
    description: "Architecture and contributor guides explain R/native ownership, acceptance gates, portability, review, and data restrictions."
    requirement: DOCS-03
    verification:
      - kind: integration
        ref: "R CMD build .; tools/ci/build-pkgdown-site.R; rendered article scan"
        status: pass
    human_judgment: true
    rationale: "Maintainer review can still improve the technical explanations and reader flow."
  - id: D2
    description: "Pkgdown navigation exposes all seven articles, the generated API reference, and the root migration guide."
    requirement: DOCS-02
    verification:
      - kind: integration
        ref: "Archive-based pkgdown build; link scan of index.html and articles/index.html"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated site output excludes repository-only release and provenance evidence."
    verification:
      - kind: integration
        ref: "Content scan of archive-built site output for docs/provenance paths and release blocker identifiers"
        status: fail
    human_judgment: false

# Metrics
duration: 28 min
completed: 2026-10-06
status: halted
---

# Phase 06 Plan 03: Architecture, Contributor Guides, and Site Navigation Summary

**Source-backed maintainer guides and complete article navigation are built; the site-output privacy gate is halted by provenance and release details in inherited package pages.**

## Performance

- **Duration:** 28 min
- **Started:** 2026-10-06T09:11:00Z
- **Completed:** 2026-10-06T09:39:33Z
- **Tasks:** 1 complete, 1 halted at its output privacy gate
- **Files modified:** 3

## Accomplishments

- Added an architecture guide covering `GEModel` orchestration, parsing and compilation, legacy and sparse solver layers, Matrix and structured/native boundaries, generated Rcpp registration, numerical acceptance, diagnostics, cleanup, tests, and benchmark ownership.
- Added a contributor guide with focused test and archive-check commands, native serial/OpenMP expectations, Rcpp wrapper regeneration rules, the pull request route, and proprietary-data restrictions.
- Added all five user guides and both maintainer guides to pkgdown article navigation, retained the generated API reference, and added a canonical repository link to `MIGRATION.md`.
- Built the complete pkgdown site from the scanned source archive in `/tmp`; all seven article pages rendered, navigation targets were present, and the archive, generated site tree, and staged artifact path scanners passed.

## Task Commits

1. **Task 1: Write architecture and contributor guides from live package ownership** - `e973b79` (`docs`)
2. **Task 2: Complete site navigation and keep repository evidence private to the repository** - `b12e413` (`docs`; navigation is complete, but the output privacy criterion remains blocked)

## Files Created/Modified

- `vignettes/architecture.Rmd` - Architecture and solver-boundary guidance grounded in current R, C++, tests, and CI.
- `vignettes/contributing.Rmd` - Package development, testing, review, native-build, and data-handling guidance.
- `_pkgdown.yml` - Navigation for user and maintainer guides, API reference, and migration instructions.

## Decisions Made

- Grouped the five user topics and two maintainer guides separately while preserving their R Markdown basenames as article IDs.
- Kept the migration link pointed at the canonical repository's `master` branch and left the site destination at `.pkgdown-site`.
- Built from the scanned source archive under `/tmp` to preserve the pre-existing untracked `.pkgdown-site/` directory in the shared checkout.

## Deviations from Plan

### Verification adjustment

The plan's inline verification builds pkgdown from the checkout. This run used `R CMD build .` followed by `tools/ci/build-pkgdown-site.R`, which scans and extracts the source archive before invoking pkgdown. The archive build produced 222 entries; the generated site and staged artifact scans each passed with 86 entries. This avoids overwriting existing generated output and validates the archive-based workflow already configured by Plan 06-01.

### Blocking output issue

The site build passes the path-based scanner but fails the required content boundary. pkgdown copies and renders inherited package-root material:

- `index.html` renders `README.md`, which links to `docs/provenance/ATTRIBUTION.md`, `RIGHTS.md`, and `PROVENANCE.csv`.
- `CONTRIBUTORS.html` repeats attribution evidence keys, the unresolved identity marker, and links to provenance records.
- `authors.html` renders provenance notes from package author metadata.
- `news/index.html` exposes release blocker identifiers and links to the provenance records.
- `search.json` indexes those pages unless they are excluded; generated LLM documents repeat indexed material unless disabled.

An isolated fresh-archive probe added `llm-docs: false`, `search.exclude` entries for the affected pages, and disabled the home sidebar. This suppresses the LLM documents and removes excluded pages from search, but pkgdown still renders `index.html`, `CONTRIBUTORS.html`, `authors.html`, and `news/index.html` with the sensitive references. The probe was not applied to `_pkgdown.yml` because it does not satisfy the output requirement. The source files causing these pages are outside this plan's assigned file scope; the plan remains halted until the site-output boundary is repaired.

## Issues Encountered

- `R CMD build .` passed, with an existing warning that its serialized test fixture raises the package's effective R requirement to 3.5.0.
- pkgdown emitted the existing Pandoc `--highlight-style` deprecation warning while rendering articles.
- The two authored maintainer pages contain no release-gate or provenance ledger references. The leak is confined to other automatically generated site surfaces described above.
- The standard site path scanner checks file paths and does not detect provenance references embedded in rendered HTML; a content scan was necessary to find this issue.

## User Setup Required

None.

## Next Phase Readiness

Task 1 and the navigation portion of Task 2 are committed. Do not mark Plan 06-03 complete or treat DOCS-02/site privacy as fully qualified until the inherited README, contributor/author metadata, and NEWS output no longer expose repository-only release and provenance details. The orchestrator owns any scope expansion and phase state updates.

## Self-Check: PASSED

- Confirmed both maintainer articles, `_pkgdown.yml`, and this summary exist.
- Confirmed task commits `e973b79` and `b12e413` are present.
- Confirmed `git diff --check` reports no whitespace errors in the plan files.
- Confirmed task commits add the two articles and modify only `_pkgdown.yml`; no tracked files were deleted.

---
*Phase: 06-documentation-and-release-qualification*
*Status: halted*
