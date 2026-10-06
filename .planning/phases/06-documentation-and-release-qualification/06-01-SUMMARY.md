---
phase: 06-documentation-and-release-qualification
plan: 01
subsystem: documentation
tags: [R, pkgdown, knitr, rmarkdown, GitHub Actions, archive-scanning]

requires:
  - phase: 04-public-api-and-solver-boundaries
    provides: Supported GEModel workflow documented by the first simulation guide
  - phase: 05-portable-native-build-and-ci
    provides: Portable package build and CI conventions
provides:
  - Deterministic first-simulation vignette built from redistributable fixtures
  - Artifact-only pkgdown workflow built from the inspected source archive
  - Fail-closed source archive, generated-site, and upload-artifact content gates
affects: [phase-06-documentation, release-qualification]

actuals:
  tokens: 9500
  tasks: 2
  commits: 3

tech-stack:
  added: [knitr, rmarkdown, pkgdown]
  patterns:
    - Build documentation dependencies remain in Suggests
    - Generate the public site from the checked source archive
    - Scan all generated and staged site paths before upload

key-files:
  created:
    - vignettes/first-simulation.Rmd
    - vignettes/helpers.R
    - _pkgdown.yml
    - .github/workflows/pkgdown.yaml
    - tools/ci/build-pkgdown-site.R
    - tools/ci/check-public-content.cjs
    - tools/ci/check-public-content.test.cjs
  modified:
    - DESCRIPTION
    - .Rbuildignore

key-decisions:
  - "Build pkgdown from the inspected source archive so checkout-only maintainer files cannot enter the site."
  - "Keep the workflow read-only and upload a static artifact without deploying GitHub Pages."
  - "Fail closed when archive parsing or any source, site, or staged-artifact content scan fails."

requirements-completed: [DOCS-02]

coverage:
  - id: D1
    description: "First-simulation vignette with a deterministic three-region fixture and declared vignette dependencies"
    requirement: DOCS-02
    verification:
      - kind: integration
        ref: "R CMD build . (first-simulation vignette rendered)"
        status: pass
    human_judgment: true
    rationale: "Rendering proves the example runs, while instructional clarity still needs a reader review."
  - id: D2
    description: "Pkgdown site and complete static artifact generated from the checked package archive"
    requirement: DOCS-02
    verification:
      - kind: integration
        ref: "tools/ci/build-pkgdown-site.R; generated-site and staged-artifact scans"
        status: pass
    human_judgment: true
    rationale: "Build and content scans prove completeness and path safety, but do not judge site navigation and readability."
  - id: D3
    description: "Fail-closed source archive and public-content scanner with synthetic regression fixtures"
    requirement: DOCS-02
    verification:
      - kind: unit
        ref: "node --test tools/ci/check-public-content.test.cjs"
        status: pass
      - kind: integration
        ref: "node tools/ci/check-public-content.cjs --archive GEModelR_0.1.0.tar.gz"
        status: pass
    human_judgment: false
  - id: D4
    description: "Read-only GitHub Actions workflow scans both site outputs before uploading the artifact"
    requirement: DOCS-02
    verification:
      - kind: other
        ref: "Static workflow inspection: contents: read; archive, site, and artifact gates precede upload-artifact"
        status: pass
    human_judgment: false

duration: 26 min
completed: 2026-10-06
status: complete
---

# Phase 06 Plan 01: First Simulation Documentation Summary

**A runnable first-simulation guide and artifact-only pkgdown site, generated from a source archive guarded against repository-only content.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-10-06T06:22:45Z
- **Completed:** 2026-10-06T06:48:13Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added a deterministic first-simulation vignette and shared three-region fixture helper using development-only documentation dependencies.
- Built the pkgdown site from the package archive and staged it as a static artifact; the workflow uses `contents: read` and does not deploy Pages.
- Added a dependency-free archive/site scanner with malformed-input and repository-only-content regression fixtures.

## Task Commits

1. **Task 1: Wire one user documentation path through vignette, site, and CI** - `10910cb` (`feat`)
2. **Task 2: Fail closed on generated-site archive inclusion** - `1434e42` (`feat`), corrected by `f222785` (`fix`)

## Files Created/Modified

- `DESCRIPTION` - Added vignette/site development dependencies and the vignette builder.
- `_pkgdown.yml` - Configured site navigation and the isolated `.pkgdown-site` output.
- `.github/workflows/pkgdown.yaml` - Builds, scans, and uploads a static site artifact with read-only repository permissions.
- `vignettes/first-simulation.Rmd`, `vignettes/helpers.R` - Added the executable guide and small deterministic fixture generator.
- `.Rbuildignore` - Excluded generated site and repository-only evidence from source archives.
- `tools/ci/build-pkgdown-site.R` - Scans and extracts the archive, builds the site, and stages the complete artifact.
- `tools/ci/check-public-content.cjs`, `tools/ci/check-public-content.test.cjs` - Added fail-closed content scanning and synthetic fixtures.

## Decisions Made

- The site is built from the package archive so the published artifact contains only distributable package content.
- GitHub Actions uploads the site artifact for later Pages use and has no Pages deployment permission or deployment step.
- The archive gate also rejects repository-only planning, workflow, provenance, and release material.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Excluded repository-only material from the generated site**
- **Found during:** Task 2 (Fail closed on generated-site archive inclusion)
- **Issue:** Building pkgdown from the checkout exposed maintainer-only pages such as `AGENTS.html` and the solver acceleration plan.
- **Fix:** Expanded `.Rbuildignore` and the scanner's forbidden paths, then added an archive-based build-and-stage helper. The required archive scan remains mandatory before site generation.
- **Files modified:** `.Rbuildignore`, `.github/workflows/pkgdown.yaml`, `tools/ci/build-pkgdown-site.R`, `tools/ci/check-public-content.cjs`, `tools/ci/check-public-content.test.cjs`
- **Verification:** Source archive scan passed with 200 entries; Node tests passed 6/6; site tree and staged artifact scans each passed with 74 entries.
- **Committed in:** `f222785`

**Total deviations:** 1 auto-fixed (1 missing critical content-boundary mitigation).
**Impact on plan:** The additional exclusions and archive-based build enforce the planned repository-content boundary; the workflow remains artifact-only.

## Issues Encountered

- R passed its library search path to the Node subprocess, causing incompatible GLIBC libraries to load locally. The helper now clears `LD_LIBRARY_PATH` for Node; the mandatory scanner then passed before extraction and site generation.
- The pkgdown build emitted a non-fatal Pandoc `--highlight-style` deprecation warning.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 06-01 is complete. `DOCS-02` remains pending until the sibling plan covering the remaining vignette topics is complete.
- Ready to continue the independent Phase 06 Wave 1 release documentation plan; release and legal gates remain separate.

## Post-plan Integration Correction

An archive review during Plan 06-02 found that the R chunks above were fenced
with tildes, so the first-simulation HTML showed source without executing the
example. The fences were changed to knitr backticks in `e2cecee`. A subsequent
`R CMD build .` passed, and inspection of the packaged HTML confirmed the
fixture output (`south` solution value `6`) and Matrix diagnostics.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-06*
