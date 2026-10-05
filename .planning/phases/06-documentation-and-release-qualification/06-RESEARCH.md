# Phase 6: Documentation and Release Qualification — Research

**Researched:** 2026-10-05  
**Domain:** R package documentation, source-archive qualification, release provenance  
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Build a pkgdown documentation site for GitHub Pages alongside the package vignettes.
- **D-02:** Include user guides, API reference, migration instructions, architecture guidance, and contributor guidance in the site. Keep detailed release-gate and provenance evidence repository-only rather than adding it to site navigation.
- **D-03:** Organize the five required topics as focused vignettes: first simulation, legacy-to-sparse migration, backend selection, diagnostics and memory budgeting, and external full-scale benchmarking.
- **D-04:** Keep ordinary vignette, source-package, and site builds runnable with small redistributable fixtures. The full-scale benchmark vignette documents the external run commands and required evidence; it does not execute the full benchmark during normal builds.

### the agent's Discretion

- Choose the pkgdown theme, navigation details, and build wiring while keeping package documentation as the source of truth.
- Choose shared vignette helpers and fixture reuse so examples remain deterministic and lightweight.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within the Phase 6 documentation-delivery scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NUM-03 | “The full GTAP benchmark records package/model signatures, residuals, finiteness, dense-fallback status, time, memory, and hardware without distributing proprietary inputs.” [VERIFIED: .planning/REQUIREMENTS.md:41] | Reuse the external benchmark gate and metadata checks; distinguish existing fingerprints from cryptographic signing. |
| CI-02 | “Built source archives pass package checks without errors, warnings, or unexplained significant notes before release.” [VERIFIED: .planning/REQUIREMENTS.md:42] | Build and inspect the source archive, then qualify that archive with R CMD check; address existing failures and warnings explicitly. |
| DOCS-02 | “Vignettes cover first simulation, legacy-to-sparse migration, backend selection, diagnostics/memory budgeting, and external full-scale benchmarking.” [VERIFIED: .planning/REQUIREMENTS.md:43] | Five separate lightweight vignettes with redistributable fixtures; benchmark instructions remain unevaluated in normal builds. |
| DOCS-03 | “Contributor and architecture documentation explains subsystem boundaries, numerical gates, data restrictions, and cross-platform native development.” [VERIFIED: .planning/REQUIREMENTS.md:44] | Reflect live R/Rcpp subsystem boundaries, numerical gates, portability, and proprietary-data rules. |
| REL-01 | “NEWS, semantic-versioning policy, lifecycle/deprecation rules, citation/provenance text, and release checklists exist.” [VERIFIED: .planning/REQUIREMENTS.md:45] | Reconcile NEWS, DESCRIPTION, CITATION, migration guidance, and repository-only release evidence. |
| DATA-01 | “Source archives and public CI contain no proprietary model data, private credentials, giant solutions, or unsupported benchmark scratch files.” [VERIFIED: .planning/REQUIREMENTS.md:46] | Audit archive and public CI artifact contents; preserve the external-input boundary. |
</phase_requirements>

## Summary

Use R’s standard vignette mechanism with knitr and rmarkdown, build a pkgdown site from package help, README, and vignettes, and qualify the built source archive with R CMD check. Keep the five required vignettes small and deterministic, using redistributable fixtures accessible to installed package code. Configure site output so it cannot clean or overwrite repository-only release evidence. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] [CITED: https://r-pkgs.org/vignettes] [CITED: https://pkgdown.r-lib.org/reference/build_site.html]

Keep full-scale benchmarking outside normal source builds, checks, vignettes, and public CI. The repository already has a GTAP benchmark runner and gate checking residuals, finite outputs, dense full-system operations, elapsed time, peak RSS, model/package fingerprints, and hardware metadata. Its fingerprints are currently MD5-based; that is not the same as an authenticated signature. Clarify the meaning of “signed” before treating NUM-03 as complete. [VERIFIED: benchmarks/check_benchmark_gate.R:62-68,179-180] [VERIFIED: benchmarks/benchmark_config.R:30-48] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations]

**Primary recommendation:** Add five HTML vignettes and a pkgdown build with current CRAN documentation tools; run R CMD check against the built archive; keep benchmark evidence and sensitive inputs outside public documentation/build artifacts; resolve release blockers without suppressing warnings.

## Architectural Responsibility Map

| Capability | Primary tier | Secondary tier | Rationale |
|------------|--------------|----------------|-----------|
| Vignettes and package help | R package documentation | Package examples/fixtures | Vignettes exercise the public R API and should be reproducible with small inputs. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] |
| pkgdown site | Static site build / GitHub Pages | R package documentation | pkgdown renders README, help reference, and vignettes as static HTML; publishing is a separate workflow boundary. [CITED: https://pkgdown.r-lib.org/index.html] |
| Source archive qualification | R package build/check environment | Native compiler and test suite | R CMD check evaluates the built package, examples, and vignettes. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] |
| Full-scale benchmark | External R/native runtime | Repository-only evidence and externally held inputs | The benchmark needs proprietary inputs and should produce summaries without packaging inputs or full solution artifacts. [VERIFIED: benchmarks/GTAP12A_CPP_RESULTS.md:55-58] [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:76-93] |

## Standard Stack

### Core

| Tool | Current version checked | Purpose | Guidance |
|------|-------------------------|---------|----------|
| R package build/check | R release documentation current at research date | Build and qualify source archive | Run R CMD build, then R CMD check on the resulting tarball. Checking only the working directory does not qualify the distributed archive. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] |
| knitr | 1.52, published 2026-09-06 | Render executable package vignettes | Add to Suggests and declare VignetteBuilder. [CITED: https://cran.r-project.org/web/packages/knitr/index.html] |
| rmarkdown | 2.32, published 2026-09-01 | HTML vignette output | Use the R Markdown HTML vignette format and provision Pandoc in docs/check environments. [CITED: https://cran.r-project.org/web/packages/rmarkdown/index.html] |
| pkgdown | 2.2.1, published 2026-07-07 | Package website and API reference | Build from package docs and vignettes; use a destination separate from repo-only release evidence. [CITED: https://cran.r-project.org/web/packages/pkgdown/index.html] [CITED: https://pkgdown.r-lib.org/reference/build_site.html] |

These are documentation/development dependencies; keep them out of runtime Imports unless runtime code requires them. DESCRIPTION says “Package: GEModelR” and lists “Matrix (>= 1.6-5),”, “Rcpp,”, “SparseM,”, and “methods”. [VERIFIED: DESCRIPTION:1,21-25]

### Supporting

| Tool | Purpose | When to use |
|------|---------|-------------|
| testthat edition 3 | Existing package tests | Preserve the test runner; use small regression tests when documentation behavior needs coverage. DESCRIPTION says “Suggests:”, “    testthat”, and “Config/testthat/edition: 3”. [VERIFIED: DESCRIPTION:28-30] [VERIFIED: tests/testthat.R:1-4] |
| GitHub Pages custom workflow | Publish static site | Phase 6 prepares and builds the site. Publication permissions and deployment remain outside PR checks and follow the Phase 7 boundary. [CITED: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages] |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| R Markdown vignettes | Quarto-only articles | R’s package vignette/check flow is the standard package path; an additional renderer adds dependencies and does not replace vignette metadata. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] |
| pkgdown-generated API reference | Hand-maintained API pages | Duplicates R help and can drift from exported functions. [CITED: https://pkgdown.r-lib.org/index.html] |

**Development installation:**

~~~r
install.packages(c("knitr", "rmarkdown", "pkgdown"))
~~~

These are not runtime dependencies. The package-legitimacy seam returned an unsupported-ecosystem error for R and documents only npm, pypi, and crates; official CRAN package records and upstream docs were checked, but no seam verdict or download counts are available. [VERIFIED: package-legitimacy seam response, 2026-10-05] [CITED: https://cran.r-project.org/web/packages/knitr/index.html] [CITED: https://cran.r-project.org/web/packages/rmarkdown/index.html] [CITED: https://cran.r-project.org/web/packages/pkgdown/index.html]

## Package Legitimacy Audit

This phase adds CRAN documentation tools. The legitimacy command rejected ecosystem R as unsupported and accepts only npm, pypi, and crates, so no OK verdict is claimed. [VERIFIED: package-legitimacy seam response, 2026-10-05]

| Package | Registry evidence | Upstream evidence | Verdict | Disposition |
|---------|-------------------|-------------------|---------|-------------|
| knitr 1.52 | CRAN record, published 2026-09-06 | yihui/knitr listed by CRAN | Not rated: seam has no CRAN support | Use as standard vignette builder; keep dev-only |
| rmarkdown 2.32 | CRAN record, published 2026-09-01 | rstudio/rmarkdown listed by CRAN | Not rated: seam has no CRAN support | Use for HTML vignette rendering; keep dev-only |
| pkgdown 2.2.1 | CRAN record, published 2026-07-07 | r-lib/pkgdown listed by CRAN | Not rated: seam has no CRAN support | Use for site generation; keep dev-only |

## Architecture Patterns

### Recommended documentation architecture

1. Keep package help and README as the source of truth for API details and common workflows.
2. Give each required topic its own focused vignette, using small redistributable inputs or fixture helpers available after installation.
3. Render README, reference pages, and vignettes to a dedicated static-site output directory.
4. Keep repository-only release/provenance records out of site navigation and the site artifact.
5. Build and check the source archive in package CI. Let pull-request site checks build only; deployment requires a separate protected workflow.
6. Run the full-scale benchmark externally and retain only its checked summary and provenance.

This follows locked scope and the current external-data boundary. [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:9-11,76-93] [VERIFIED: benchmarks/GTAP12A_CPP_RESULTS.md:55-58]

### Vignette metadata pattern

R package guidance documents the knitr/rmarkdown vignette metadata pattern. Declare knitr as the vignette builder and use HTML vignette output. [CITED: https://r-pkgs.org/vignettes] [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html]

~~~yaml
---
title: "A focused user guide"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{A focused user guide}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---
~~~

### Site output and publishing

pkgdown’s GitHub Pages helper defaults to a docs destination and cleans it. This repository already has repository-only files below docs/release and docs/provenance, so use a separate site destination and inspect the site artifact contents. [CITED: https://pkgdown.r-lib.org/reference/build_site_github_pages.html] [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:76-93]

GitHub’s custom workflow uses Pages configure, upload-artifact, and deploy actions; deployment needs Pages write and OIDC token permissions. Keep PR checks build-only and use a protected deployment environment only after publication is authorized. [CITED: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages] [VERIFIED: .planning/REQUIREMENTS.md:49]

### Source archive qualification

R’s package manual recommends checking the archive produced by R CMD build. Check runs examples and vignette code; vignette builders and dependencies must be available. PDF manual generation may require LaTeX. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html]

~~~sh
R CMD build .
R CMD check <built-source-archive.tar.gz>
~~~

Inspect the archive manifest against intended contents. The current .Rbuildignore entries are “^\.benchmark-data$”, “^\.git$”, “^\.planning$”, “^\.Rcheck$”, “^\.Rproj.user$”, “^benchmarks/\.”, and “^rcpp-solver-acceleration-plan\.md$”. The benchmark rule only excludes hidden files under benchmarks; it is not a full allowlist. [VERIFIED: .Rbuildignore:1-7]

## Don’t Hand-Roll

| Problem | Don’t build | Use instead | Why |
|---------|------------|-------------|-----|
| API reference site | Hand-maintained copies of signatures | R help and pkgdown reference generation | Rendered API stays tied to package help. [CITED: https://pkgdown.r-lib.org/index.html] |
| Vignette execution | Custom R Markdown runner | R CMD build/check and VignetteBuilder | Uses the package lifecycle’s standard vignette build/check flow. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] |
| Benchmark validation | A second summary parser | Existing benchmark gate/checker | It already checks required metrics and result metadata. [VERIFIED: benchmarks/check_benchmark_gate.R:62-68,113-117,179-180] |
| Citation rendering | Static copied package version/authors | Existing CITATION and citation()/bibentry conventions | Metadata-based fields can track package metadata. [CITED: https://search.r-project.org/R/refmans/utils/html/citation.html] |
| Artifact signing | Custom hash/signature scheme | GitHub attestations or another established signer, if authenticated signing is required | Attestations bind artifacts to workflow provenance; a content hash alone does not authenticate its producer. [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] |

## Project Constraints (from AGENTS.md)

- Follow the root RTK command convention. [VERIFIED: /home/zenz/.codex/RTK.md]
- Keep documentation aligned with R package structure and existing base-R style. [VERIFIED: AGENTS.md:3-26]
- Use small deterministic redistributable fixtures; do not commit proprietary or oversized TAB/HAR files. [VERIFIED: AGENTS.md:28-38]
- Do not commit private credentials, private inputs, giant solutions, archives, or R CMD check output. [VERIFIED: AGENTS.md:34-38]
- Root AGENTS.md says “There is currently no tests/ or vignettes/ directory.” and includes “tabloToR::GEModel$new()”. Those facts are stale: DESCRIPTION says “Package: GEModelR”. Follow live DESCRIPTION, NAMESPACE, README, and tests. [VERIFIED: AGENTS.md:10,22] [VERIFIED: DESCRIPTION:1] [VERIFIED: tests/testthat.R:1-4]
- No project-specific skills or CLAUDE.md were found during discovery. [VERIFIED: project skill/discovery scan, 2026-10-05]

## Common Pitfalls

### 1. Checking the checkout instead of the deliverable
The working tree and source archive can differ. Build first, inspect the archive manifest, and check that tarball. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html]

### 2. Site output overwrites repository-only evidence
pkgdown cleans its destination; its default overlaps this repo’s docs/release and docs/provenance. Choose another output path and publish only that artifact. [CITED: https://pkgdown.r-lib.org/reference/build_site_github_pages.html] [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:76-93]

### 3. Vignettes depend on checkout-only fixtures
A vignette may work from source but fail on an installed archive. Include small redistributable fixtures as installed package data or create deterministic inputs in a shared helper. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:76-93]

### 4. Heavy benchmark runs during docs/check
This makes normal builds slow or requires private data. Keep external full-scale commands and evidence requirements descriptive or unevaluated; routine builds use redistributable examples. [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:9-11]

### 5. Technical qualification mistaken for release clearance
Current release records state “Intentional-Blockers: DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED”. Do not suppress a warning or imply that clean checks authorize publication. [VERIFIED: docs/release/RELEASE-GATES.md:5-19]

### 6. Fingerprints described as signatures
The current run/model fingerprints use MD5. Label them as fingerprints unless an authenticated attestation is added; never include proprietary inputs in the attestation subject or artifact. [VERIFIED: benchmarks/benchmark_config.R:30-48] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations]

## Code Examples

### Required benchmark gate fields

The source gate requires these exact metric names: [VERIFIED: benchmarks/check_benchmark_gate.R:62-68]

~~~r
c(
  "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
  "solution_finite", "selected_outputs_finite",
  "dense_full_system_operations"
)
~~~

Preserve status and metadata checks as well. The runner records package/model/config fingerprints, platform, CPU, memory, and runtime details. [VERIFIED: benchmarks/check_benchmark_gate.R:113-117,179-180] [VERIFIED: benchmarks/benchmark_gtap12a_run.R:109-149,193-203]

## State of the Art

| Old approach | Recommended approach | Impact |
|--------------|----------------------|--------|
| Check only the source working directory | Check the built source archive | Qualifies the deliverable users install. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html] |
| Hand-maintained API pages | Generate reference pages from R help with pkgdown | Reduces drift. [CITED: https://pkgdown.r-lib.org/index.html] |
| Treat checksum as signed artifact | Use authenticated attestation if signed provenance is required | Attest the public summary/manifest without exposing model inputs. [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations] |
| Bundle full benchmark data with docs | Run full benchmark externally | Preserves privacy and ordinary-build determinism. [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:9-11] |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | Exact breaking-change semantics before 1.0 remain a maintainer choice, not established by the requirement. [ASSUMED] | Release policy | Users may infer a compatibility promise maintainers do not intend. |
| A2 | “Signed benchmark summary” might require cryptographically authenticated provenance beyond the current MD5 fingerprints. [ASSUMED] | NUM-03 | Calling hashes signatures could create false confidence. |
| A3 | Site output should be configured away from existing repository evidence directories. [ASSUMED] | Site build | Maintainers may prefer another layout. |
| A4 | CRAN docs packages are appropriate dependencies, but the package legitimacy seam cannot rate R. [ASSUMED] | Standard stack | The normal dependency approval path must still accept them. |

## Open Questions and Planning Resolutions

1. **Package license and CI-02 — unresolved, fail-closed.** DESCRIPTION still contains “License: What license is it under?” and the release gate lists the dependency audit as pending. Plan 06-06 Task 3 requires an authorized owner to supply the exact license identity and authority reference before changing metadata or starting archive qualification. If the owner keeps the decision blocked, preserve the warning and keep CI-02 and Phase 6 pending; do not guess or suppress it. [VERIFIED: DESCRIPTION:18] [VERIFIED: docs/release/RELEASE-GATES.md:5-19]
2. **Meaning of “signed” for NUM-03 — planning resolution with an external precondition.** Plan 06-05 uses an armored detached GPG signature over the final redacted benchmark summary and requires an independently verifiable public-key fingerprint. The signer must designate the key; until that identity and authorized inputs are available, NUM-03 remains pending. Existing MD5 values remain fingerprints, not signatures. [VERIFIED: benchmarks/benchmark_config.R:30-48] [CITED: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations]
3. **Pkgdown output and delivery — selected.** Plan 06-01 configures `.pkgdown-site` as the generated output directory and builds a sanitized static artifact. The build is isolated from `docs/release` and `docs/provenance`; the current plan does not grant Pages deployment permissions or publish the site. [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:9-11]
4. **Pre-1.0 SemVer policy — maintainer decision checkpoint.** Plan 06-04 records the proposed compatibility rule but requires the maintainer to adopt it or keep the policy unresolved before it is presented as an established promise. R package version syntax does not decide this project policy. [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html]
5. **Documentation dependency legitimacy — not resolved by the available rating seam.** The R-specific dependency legitimacy check is unsupported. Plan the ordinary dependency review and treat the proposed documentation dependencies as pending that review rather than claiming a legitimacy verdict.

## Environment Availability

| Dependency | Required by | Available | Version/status | Fallback |
|------------|-------------|-----------|----------------|----------|
| R / R CMD | Package build/check | Yes | R 4.3.0 | — |
| C/C++ compiler and make | Native package check | Yes | gcc, g++, make available | — |
| pdflatex | PDF manual check | Yes locally | Available in this environment | Hosted image may need TeX; Phase 5 hosted check lacked pdflatex. [VERIFIED: .planning/phases/06-documentation-and-release-qualification/06-CONTEXT.md:76-93] |
| Pandoc | R Markdown and pkgdown | No on PATH | — | Provision in docs/check workflow |
| Quarto | Optional renderer | No on PATH | — | Not required by recommended stack |
| knitr | Vignettes | Yes locally | 1.45 installed; CRAN lists 1.52 | Provision supported version in CI |
| rmarkdown | Rendering | Yes locally | 2.30 installed; CRAN lists 2.32 | Provision supported version in CI |
| pkgdown | Site | Yes locally | 2.2.0 installed; CRAN lists 2.2.1 | Provision supported version in CI |
| GitHub Pages settings | Deployment | Not verified | Repository settings not available | Build site artifact without deploying |

## Validation Architecture

Nyquist validation is enabled: config contains “    "nyquist_validation": true,”. [VERIFIED: .planning/config.json:19]

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat edition 3; DESCRIPTION says “Config/testthat/edition: 3” |
| Config | DESCRIPTION; runner tests/testthat.R |
| Quick package test | Rscript -e 'testthat::test_local()' |
| Full phase qualification | R CMD build . followed by R CMD check on the built source archive |

The package declares testthat and edition 3: “Suggests:”, “    testthat”, “Config/testthat/edition: 3”. The runner loads testthat and GEModelR before test_check. [VERIFIED: DESCRIPTION:28-30] [VERIFIED: tests/testthat.R:1-4]

### Phase Requirements → Validation Map

| Requirement | Behavior | Validation type | Suggested command/artifact |
|-------------|----------|-----------------|----------------------------|
| NUM-03 | Benchmark evidence checks residual, finiteness, no dense fallback, time, memory, hardware, package/model provenance | External benchmark gate | Existing external runner and checker; keep summary outside source package |
| CI-02 | Archive check has no errors, warnings, or unexplained significant notes | Release check | Build then check the source archive |
| DOCS-02 | Five vignettes build using lightweight redistributable inputs | Vignette build/check | Archive check and site build |
| DOCS-03 | Architecture/contributor guidance matches subsystem and data boundaries | Documentation review | Site build plus review against R/native code |
| REL-01 | NEWS, version/lifecycle policy, citation, provenance, checklist align | Documentation/release review | Compare NEWS, DESCRIPTION, inst/CITATION, docs/release |
| DATA-01 | Archive and CI omit private inputs, credentials, giant solutions, scratch data | Content inspection | Inspect source tarball and CI artifacts |

### Existing gaps and qualification risks

- Existing testthat tests and helpers are present; AGENTS.md says “There is currently no tests/ or vignettes/ directory.”, which is stale. [VERIFIED: AGENTS.md:10] [VERIFIED: tests/testthat.R:1-4]
- Add vignette metadata/dependencies, pkgdown config and site build, installed-package fixture support, and an archive-content inspection gate.
- Phase 5 hosted check reported nine serialization/predecessor metadata failures, missing pdflatex, and the license placeholder warning. Track these; do not suppress them. [VERIFIED: .planning/phases/05-portable-native-build-and-ci/deferred-items.md:5-8]
- No tests, package builds, or release checks were run during this research. [VERIFIED: research session actions, 2026-10-05]

## Security Domain

Security enforcement defaults to enabled because config does not set security_enforcement to false. Current OWASP ASVS 5 category names and numbering differ from older templates. [VERIFIED: .planning/config.json:1-43] [CITED: https://cornucopia.owasp.org/taxonomy/asvs-5.0]

| ASVS 5 category | Applies | Phase control |
|-----------------|---------|---------------|
| V2 Validation and Business Logic | Yes | Validate benchmark summary structure; fail closed on missing metrics/status. |
| V5 File Handling | Yes | Keep proprietary model inputs and results external; inspect package/CI artifacts. |
| V6 Authentication | No for static docs | Public static docs do not authenticate users. |
| V7 Session Management | No for static docs | No user session is part of the static site. |
| V8 Authorization | Limited | Protect deployment through GitHub environment/workflow permissions. |
| V11 Cryptography | Conditional | If actual signed provenance is required, use platform attestation or established cryptography. |
| V13 Configuration | Yes | Use least-privilege workflow permissions and isolate deployment. |
| V14 Data Protection | Yes | Inspect archives/artifacts for private inputs, credentials, and giant results. |

## Sources

### Primary and official sources

- R Core Team, Writing R Extensions: https://stat.ethz.ch/CRAN/doc/manuals/r-release/R-exts.html — archive checks, vignettes, CITATION, version conventions.
- CRAN records: https://cran.r-project.org/web/packages/knitr/index.html ; https://cran.r-project.org/web/packages/rmarkdown/index.html ; https://cran.r-project.org/web/packages/pkgdown/index.html — versions and release dates.
- pkgdown: https://pkgdown.r-lib.org/index.html ; https://pkgdown.r-lib.org/reference/build_site.html ; https://pkgdown.r-lib.org/reference/build_site_github_pages.html
- GitHub Pages custom workflows: https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- GitHub artifact attestations: https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations
- R citation(): https://search.r-project.org/R/refmans/utils/html/citation.html
- OWASP ASVS 5 taxonomy: https://cornucopia.owasp.org/taxonomy/asvs-5.0

### Supporting documentation

- R Packages, Vignettes: https://r-pkgs.org/vignettes
- R Packages, Lifecycle: https://r-pkgs.org/lifecycle.html

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — official R, CRAN, and pkgdown documentation checked; package legitimacy seam does not support CRAN.
- Architecture: HIGH — locked decisions and live source/docs/build files inspected.
- Pitfalls: MEDIUM — R docs and project-specific gate files/evidence reviewed.

**Research date:** 2026-10-05  
**Valid until:** 2026-11-04 for stable workflow guidance; recheck package versions and GitHub Actions guidance before execution.
