# Phase 6: Documentation and Release Qualification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-05
**Phase:** 06-Documentation and Release Qualification
**Areas discussed:** Documentation delivery; release policy

---

## Documentation delivery

### Reader entry point

**Question:** How should readers find Phase 6 documentation?

| Option | Description | Selected |
|--------|-------------|----------|
| Build a pkgdown GitHub Pages site with vignettes | Adds a navigable site alongside package help and README. | ✓ |
| Use package help, vignettes, and README; defer a site | Keeps documentation within current package and repository surfaces. | |
| Build the site after the first release | Delays the hosted site until after publication. | |

### Site content

**Question:** What should the documentation site include?

| Option | Description | Selected |
|--------|-------------|----------|
| User guides, API reference, migration, architecture, and contributor docs; keep detailed gate evidence repository-only | Covers user and maintainer needs without exposing detailed release-gate evidence in site navigation. | ✓ |
| All docs, including release and provenance evidence, in the site navigation | Makes the full repository documentation set available through the site. | |
| User guides and API reference only; keep architecture and contributor docs repository-only | Limits the site to package users. | |

### Vignette structure

**Question:** How should the five required vignette topics be organized?

| Option | Description | Selected |
|--------|-------------|----------|
| Five focused vignettes, one per topic | Gives each required topic a separate entry point. | ✓ |
| Three grouped tutorials: getting started, solver operations, full-scale benchmarking | Combines related topics into broader tutorials. | |
| One end-to-end tutorial plus focused migration and reference guides | Centers the documentation on one complete example. | |

### Full-scale benchmark guidance

**Question:** How should the full-scale benchmark vignette handle private, user-supplied inputs?

| Option | Description | Selected |
|--------|-------------|----------|
| Use small runnable fixtures; document external benchmark commands and evidence, but keep full-scale execution outside normal builds | Keeps ordinary builds reproducible without proprietary data while preserving a reproduction path. | ✓ |
| Add an opt-in benchmark chunk enabled by a local input-path setting | Allows local benchmark execution from the vignette when users configure data. | |
| Keep benchmark steps in a separate guide and link to it from the vignettes | Separates full-scale instructions from the benchmark vignette. | |

**User's choice:** Build a pkgdown GitHub Pages site with five focused vignettes, user and maintainer documentation, and a separate external-input full-scale benchmark procedure.

**Notes:** The user selected the first option in each of the four decisions. Detailed release-gate and provenance evidence remains repository-only. Full-scale execution stays outside normal vignette, source-package, and site builds.

## Pre-1.0 compatibility policy

**Date:** 2026-10-06

**Question:** Which compatibility promise should `VERSION-LIFECYCLE.md` record for 0.x releases?

| Option | Description | Selected |
|--------|-------------|----------|
| Adopt the documented proposal | 0.x minor releases may include documented breaking changes; patches carry compatible fixes; post-1.0 follows SemVer. Deprecations name a replacement and expected removal timing when practical. | ✓ |
| Provide an alternative policy | Record maintainer-supplied compatibility and deprecation terms. | |
| Keep unresolved | Retain the proposal and leave REL-01 pending. | |

**User's choice:** Adopt the documented proposal. Version 0.1.0 remains a development version and is not a public release.

---

## the agent's Discretion

- Choose the pkgdown theme, navigation, and build wiring.
- Choose shared vignette helpers and fixture reuse, keeping examples deterministic and lightweight.

## Deferred Ideas

None.
