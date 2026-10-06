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
  - Archive-built pkgdown output with repository-only content removed and scanned
affects: [pkgdown, contributor documentation, DOCS-02, DOCS-03]

# Actuals (#2632): chars/4 over the plan deliverable diff.
actuals:
  tokens: 2566
  tasks: 2
  commits: 5

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Audience-grouped pkgdown article navigation using vignette basenames as IDs
    - Generate the site from the scanned source archive in an isolated temporary directory
    - Remove generated repository-only pages before scanning or staging the public site
    - Scan site and staged text content for release/provenance markers

key-files:
  created:
    - vignettes/architecture.Rmd
    - vignettes/contributing.Rmd
    - pkgdown/index.md
  modified:
    - .Rbuildignore
    - _pkgdown.yml
    - tools/ci/build-pkgdown-site.R
    - tools/ci/check-public-content.cjs
    - tools/ci/check-public-content.test.cjs

key-decisions:
  - "Expose the five user articles and two maintainer articles alongside the generated API reference and canonical migration link."
  - "Use pkgdown/index.md as a site-only landing page while keeping repository README and citation records unchanged."
  - "Exclude governance and contributor ledgers from the source archive; remove pkgdown's generated citation and NEWS pages before full-tree scanning and staging."
  - "Make site and staged-artifact scans reject embedded repository-only provenance, release blockers, and ledger markers."

patterns-established:
  - "Maintainer guidance traces model, solver, native, test, and CI ownership to current package sources."
  - "Use an archive-based site build so checkout-only repository files cannot enter the generated site."

requirements-completed: [DOCS-02, DOCS-03]

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
        ref: "R CMD build .; archive-based pkgdown build; Node site and staged-artifact content scans; no repository-only markers or links in output"
        status: pass
    human_judgment: false

# Metrics
duration: 42 min
completed: 2026-10-06
status: complete
---

# Phase 06 Plan 03: Architecture, Contributor Guides, and Site Privacy Summary

**Source-backed maintainer guides and complete article navigation are built; the exact archive-to-site path now removes and rejects repository-only release and provenance content.**

## Performance

- **Duration:** 42 min, including the privacy repair follow-up
- **Started:** 2026-10-06T09:11:00Z
- **Completed:** 2026-10-06T09:53:00Z
- **Tasks:** 2 complete
- **Files modified:** 8

## Accomplishments

- Added an architecture guide covering `GEModel` orchestration, parsing and compilation, legacy and sparse solver layers, Matrix and structured/native boundaries, generated Rcpp registration, numerical acceptance, diagnostics, cleanup, tests, and benchmark ownership.
- Added a contributor guide with focused test and archive-check commands, native serial/OpenMP expectations, Rcpp wrapper regeneration rules, the pull request route, and proprietary-data restrictions.
- Added all five user guides and both maintainer guides to pkgdown article navigation, retained the generated API reference, and added a canonical repository link to `MIGRATION.md`.
- Replaced the site homepage with a compact `pkgdown/index.md`, leaving the provenance-rich GitHub README and citation records unchanged.
- Excluded `CONTRIBUTORS.md` and `GOVERNANCE.md` from the source archive. Removed pkgdown's generated author/citation, contributor, governance, and NEWS pages before scanning or staging, and pruned their sitemap entries.
- Added text-content checks for repository-only paths, current release blocker IDs, and provenance-ledger markers in generated sites and staged artifacts.
- Built the final source archive and complete site under `/tmp`; all seven articles rendered and navigation targets were present. Archive, site-tree, and staged-artifact gates passed (222, 62, and 62 entries respectively).

## Task Commits

1. **Task 1: Write architecture and contributor guides from live package ownership** - `e973b79` (`docs`)
2. **Task 2: Complete site navigation and keep repository evidence private to the repository** - `b12e413` (`docs`)
3. **Record the initial site privacy failure** - `0ccd0f0` (summary, superseded below)
4. **Resolve inherited pkgdown output leaks and enforce content scanning** - `b6fafd6` (`fix`)
5. **Record the completed site privacy verification** - this summary follow-up

## Files Created/Modified

- `vignettes/architecture.Rmd` - Architecture and solver-boundary guidance grounded in current R, C++, tests, and CI.
- `vignettes/contributing.Rmd` - Package development, testing, review, native-build, and data-handling guidance.
- `pkgdown/index.md` - Site-specific landing page that does not render repository-only README material.
- `_pkgdown.yml` - Navigation plus search, footer, and LLM-output controls for the public site.
- `.Rbuildignore`, `tools/ci/build-pkgdown-site.R` - Keep governance/contributor records out of the archive and remove remaining autogenerated repository-only pages before staging.
- `tools/ci/check-public-content.cjs`, `tools/ci/check-public-content.test.cjs` - Check full paths and text content for repository-only release/provenance markers.

## Decisions Made

- Grouped the five user topics and two maintainer guides separately while preserving their R Markdown basenames as article IDs.
- Kept the migration link pointed at the canonical repository's `master` branch and left the site destination at `.pkgdown-site`.
- Built from the scanned source archive under `/tmp` to preserve the pre-existing untracked `.pkgdown-site/` directory in the shared checkout.
- Left `README.md`, `NEWS.md`, `inst/CITATION`, and the canonical governance/provenance records unchanged; the public site builder filters generated surfaces rather than rewriting those records.

## Deviations from Plan

### Verification adjustment

The plan's inline verification builds pkgdown from the checkout. This run used `R CMD build .` followed by `tools/ci/build-pkgdown-site.R`, which scans and extracts the source archive before invoking pkgdown. The final archive contained 222 entries; the generated site and staged artifact scans each passed with 62 entries. This avoids overwriting existing generated output and validates the archive-based workflow already configured by Plan 06-01.

### Auto-fixed output privacy issue

The initial site probe found that pkgdown copied and rendered inherited package-root material:

- `index.html` rendered README links to provenance ledgers.
- `CONTRIBUTORS.html`, `authors.html`, and `news/index.html` exposed attribution and release evidence.
- `GOVERNANCE.html` copied the maintainer identity and release-authority record.
- Search and generated LLM documents could repeat content from those pages.

The repair adds a site-specific homepage, excludes governance and contributor records from the archive, removes the generated citation/author, NEWS, and repository-ledger pages before site scans and staging, prunes those pages from `sitemap.xml`, and disables LLM document output. The reusable scanner now rejects provenance/release paths, the two active blocker identifiers, and attribution-ledger markers in HTML, JSON, Markdown, text, and XML output. `README.md`, `NEWS.md`, and `inst/CITATION` retain the approved release and attribution wording in their source locations.

**Verification:** The final archive-based site contains all seven articles, API reference, and Migration links. Archive, site-tree, and staged-artifact scans passed; no provenance paths, release blocker IDs, attribution ledger markers, hidden-page links, or sitemap links to removed pages were found.

## Issues Encountered

- `R CMD build .` passed, with an existing warning that its serialized test fixture raises the package's effective R requirement to 3.5.0.
- pkgdown emitted the existing Pandoc `--highlight-style` deprecation warning while rendering articles.
- The authored maintainer articles contain no repository-only release or provenance markers.

## User Setup Required

None.

## Next Phase Readiness

Plan 06-03 is complete. Site generation remains archive-based, artifact-only, and unpublished; no Pages deployment or release authorization was performed.

## Self-Check: PASSED

- Confirmed both maintainer articles, `_pkgdown.yml`, and this summary exist.
- Confirmed task commits `e973b79`, `b12e413`, and privacy repair `b6fafd6` are present.
- Confirmed `R CMD build .`, Node content-gate tests (7/7), and archive/site/staged-artifact scans pass.
- Confirmed the site index and article index expose all required guides, API reference, and canonical migration link.
- Confirmed generated site output contains no hidden page references or repository-only release/provenance markers.

---
*Phase: 06-documentation-and-release-qualification*
*Status: complete*
