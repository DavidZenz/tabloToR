---
phase: 06-documentation-and-release-qualification
plan: 08
subsystem: release-documentation
tags: [R, pkgdown, testthat, public-content, release-gates]
requires:
  - phase: 06-07
    provides: Integrated release evidence and package documentation outputs
provides:
  - Root-bound authority and citation reads, plus complete evidence validation for blocked assertions
  - HTML-reference decoding and case-insensitive repository-only path checks
  - Verified help links for installed vignettes and pkgdown articles
affects: [release-qualification, documentation, public-content]
actuals:
  tokens: 5856
  tasks: 3
  commits: 7
tech-stack:
  added: []
  patterns: [temporary build-install-site verification, output-specific vignette links]
key-files:
  created: [tools/ci/check-vignette-help-links.R]
  modified:
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
    - tools/ci/check-public-content.cjs
    - tools/ci/check-public-content.test.cjs
    - vignettes/backend-selection.Rmd
    - vignettes/diagnostics-memory-budgeting.Rmd
key-decisions:
  - "Resolve fixed authority and citation paths against the canonical repository root before reading them."
  - "Use pkgdown's IN_PKGDOWN render marker to choose between generated help locations; the Rd command did not produce an anchor in the R Markdown output."
  - "Keep DEPENDENCY_COMPATIBILITY_AUDIT_PENDING and ATTRIBUTION_IDENTITY_UNRESOLVED as active release blockers."
patterns-established:
  - "Build, install, and render documentation under a unique temporary root, then assert both hrefs and target files."
  - "Normalize HTML references before URL separator checks and case-fold reserved path comparisons."
requirements-completed: [DOCS-02, REL-01, DATA-01]
coverage:
  - id: D1
    description: Release authority and citation reads stay inside the repository root, and blocked assertions validate integrated evidence.
    requirement: REL-01
    verification:
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#release gate rejects authority and citation targets outside root"
        status: pass
      - kind: unit
        ref: "tests/testthat/test-release-gates.R#assert-blocked validates integrated evidence"
        status: pass
    human_judgment: false
  - id: D2
    description: Public-content scans reject HTML-encoded percent separators and case variants of protected paths.
    requirement: DATA-01
    verification:
      - kind: unit
        ref: "node --test tools/ci/check-public-content.test.cjs"
        status: pass
    human_judgment: false
  - id: D3
    description: Package-help links resolve to generated manual pages in installed vignettes and pkgdown articles.
    requirement: DOCS-02
    verification:
      - kind: integration
        ref: "Rscript --vanilla tools/ci/check-vignette-help-links.R"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-10-20
status: complete
---

# Phase 06 Plan 08: Release Gate and Documentation Gaps Summary

**Release evidence is root-bound, protected paths are normalized before public-content checks, and both vignette renderers produce working package-help links.**

## Performance

- **Duration:** 15 min (from first TDD commit through the final focused link check)
- **Started:** 2026-10-20T07:15:50Z
- **Completed:** 2026-10-20T07:31:12Z
- **Tasks:** 3
- **Files modified:** 7 task files

## Accomplishments

- The release gate resolves `GOVERNANCE.md` and `inst/CITATION` to canonical, regular files inside the selected root and continues integrated evidence parsing for intentionally blocked roots.
- Scanner normalization decodes numeric and named HTML references before percent-separator checks and compares protected paths case-insensitively.
- A temporary build/install/pkgdown checker verifies each generated link and its target. Installed vignette pages use `../html/GEModelR-package.html`; pkgdown articles use `../reference/GEModelR-package.html`.

## Task Commits

1. **Task 1 RED:** `520148f` — add release-gate regressions
2. **Task 1 GREEN:** `ae4a44c` — bind release evidence to repository root
3. **Task 2 RED:** `e845f02` — add encoded-path and case-variant regressions
4. **Task 2 GREEN:** `40d55a1` — normalize encoded release paths
5. **Task 3 RED:** `9da3e09` — reproduce installed vignette link failure
6. **Task 3 GREEN:** `efdd70f` — route package-help links by output

**Plan metadata:** Summary and planning state are recorded in the final GSD metadata commit.

## Files Created/Modified

- `tools/check_release_gates.R` — canonical in-root authority/citation resolution and complete blocked-state evidence validation.
- `tests/testthat/test-release-gates.R` — escaping-symlink and blocked-with-missing-record regressions.
- `tools/ci/check-public-content.cjs` — HTML-reference decoding and case-insensitive reserved-path matching.
- `tools/ci/check-public-content.test.cjs` — numeric/named entity and case-variant regressions across scan modes.
- `tools/ci/check-vignette-help-links.R` — self-cleaning temporary build, install, and pkgdown link validation.
- `vignettes/backend-selection.Rmd` — chooses the generated package-help URL for the active renderer.
- `vignettes/diagnostics-memory-budgeting.Rmd` — chooses the generated package-help URL for the active renderer.

## Decisions Made

- Authority and citation evidence must resolve to regular files inside the canonical root before their contents can affect release status.
- Both selected release blockers remain active; the plan does not qualify a release or change lifecycle status.
- The checker builds only in a unique temporary directory and removes only that directory on exit.

## Deviations from Plan

### Task 3 link mechanism adjusted after RED evidence

The plan proposed the Rd command `\link[GEModelR:GEModelR-package]{GEModelR package help}`. In the actual `R CMD INSTALL --html` output, that command produced no package-help anchor in the vignette HTML. The original relative link did produce an anchor, but it pointed to `../reference/GEModelR-package.html`, a path absent from the installed package. The implementation therefore emits a normal Markdown link from an `asis` chunk and selects its target using pkgdown's `IN_PKGDOWN` render marker. The exported `pkgdown::in_pkgdown()` and its marker setup were confirmed in the installed pkgdown 2.2.0 renderer. The same checker passes and validates both generated targets.

This is one implementation adjustment, limited to preserving the required two-output behavior. No public API or release status changed.

## Verification

- Both named release-gate regressions passed individually with `testthat::test_file()`.
- `rtk node --test tools/ci/check-public-content.test.cjs` passed all 14 tests.
- `rtk Rscript --vanilla tools/ci/check-vignette-help-links.R` passed after a temporary source build, `R CMD INSTALL --html`, and pkgdown site build. It printed and checked both installed `doc/` pages against `html/GEModelR-package.html` and both pkgdown articles against `reference/GEModelR-package.html`.
- The red run using the original relative links failed on the installed `backend-selection` page with the observed incorrect `../reference/GEModelR-package.html` target. The red test for the proposed Rd form also confirmed it emits no matching anchor, motivating the output-specific link adjustment.
- Pkgdown emitted its `--highlight-style` deprecation warning while rendering articles; the link check passed.
- Per the scoped gap-plan instructions, the historical baseline, full test suite, full source-archive qualification, and benchmarks were not rerun.

## Next Phase Readiness

The five review findings assigned to this plan have focused fixes and regressions. `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED` remain active blockers. Phase 06 release qualification remains incomplete until its separately documented checks and blockers are resolved.

---
*Phase: 06-documentation-and-release-qualification*
*Completed: 2026-10-20*

## Self-Check: PASSED

- The summary file exists at the required phase path.
- All six RED/GREEN task commits are present in the repository history.
