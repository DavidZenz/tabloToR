# Phase 6: Documentation and Release Qualification - Context

**Gathered:** 2026-10-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce a publication-quality source package and auditable evidence for users and maintainers. This phase qualifies built source archives, completes the required vignettes and contributor/architecture guidance, records full-scale benchmark evidence without distributing private inputs, and aligns NEWS, version/lifecycle policy, citation/provenance text, and release checklists with package behavior. Package publication remains Phase 7 work and is subject to the existing legal and release gates.

Documentation delivery for this phase includes a pkgdown site configured for GitHub Pages and five focused vignettes. Site content covers users and maintainers while keeping detailed release-gate evidence in the repository. Vignette examples use small redistributable fixtures; full-scale benchmark execution remains external to normal package checks and site builds.

</domain>

<decisions>
## Implementation Decisions

### Documentation delivery and structure

- **D-01:** Build a pkgdown documentation site for GitHub Pages alongside the package vignettes.
- **D-02:** Include user guides, API reference, migration instructions, architecture guidance, and contributor guidance in the site. Keep detailed release-gate and provenance evidence repository-only rather than adding it to site navigation.
- **D-03:** Organize the five required topics as focused vignettes: first simulation, legacy-to-sparse migration, backend selection, diagnostics and memory budgeting, and external full-scale benchmarking.
- **D-04:** Keep ordinary vignette, source-package, and site builds runnable with small redistributable fixtures. The full-scale benchmark vignette documents the external run commands and required evidence; it does not execute the full benchmark during normal builds.

### the agent's Discretion

- Choose the pkgdown theme, navigation details, and build wiring while keeping package documentation as the source of truth.
- Choose shared vignette helpers and fixture reuse so examples remain deterministic and lightweight.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and acceptance

- `.planning/PROJECT.md` — Product direction, compatibility constraints, legal release gate, and prohibition on bundling proprietary GTAP inputs.
- `.planning/REQUIREMENTS.md` — Phase 6 requirements NUM-03, CI-02, DOCS-02, DOCS-03, REL-01, and DATA-01.
- `.planning/ROADMAP.md` — Phase 6 goal and success criteria.

### Inherited decisions

- `.planning/phases/03-gemodelr-identity-migration/03-CONTEXT.md` — Authoritative migration guide, immediate package replacement, attribution, and deferred documentation site.
- `.planning/phases/04-public-api-and-solver-boundaries/04-CONTEXT.md` — Supported GEModel facade, solver IDs, diagnostics, lifecycle, and generated API documentation contract.
- `.planning/phases/05-portable-native-build-and-ci/05-CONTEXT.md` — Cross-platform CI boundary, external full-scale benchmarks, and package checks deferred to Phase 6.

### Package documentation and structure

- `README.md` — Current installation, migration entry point, and simulation/solver examples.
- `MIGRATION.md` — Authoritative predecessor-package migration instructions.
- `DESCRIPTION` and `NAMESPACE` — Package metadata, dependency declarations, and exported API.
- `R/GEModel.R` and `R/sparseSolver.R` — Public workflow and solver behavior that examples must describe accurately.
- `NEWS.md` and `inst/CITATION` — Existing version history, provenance, and citation surfaces.
- `.planning/codebase/CONVENTIONS.md` — R, generated documentation, and example conventions.
- `.planning/codebase/STRUCTURE.md` — Package subsystem and documentation layout.
- `.planning/codebase/TESTING.md` — Test fixtures, package-check commands, and full-scale benchmark harnesses.

### Benchmark and archive boundaries

- `benchmarks/GTAP12A_CPP_RESULTS.md` — Existing full-scale result summary and its current run metadata.
- `benchmarks/run_gtap12a_ab.R` and `benchmarks/check_benchmark_gate.R` — External benchmark execution and acceptance harnesses.
- `.Rbuildignore` — Current exclusions for planning artifacts, local benchmark data, and hidden benchmark scratch files.
- `docs/release/RELEASE-GATES.md` — Repository-only release qualification and legal gate evidence; detailed evidence stays outside site navigation.

No external specifications were referenced during discussion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `README.md` already has installation, migration, first-run, sparse workflow, backend, diagnostics, and memory-budget examples that can seed concise vignettes.
- Phase 4 generated package help for the supported facade; pkgdown can present that reference alongside authored guides.
- Small redistributable TABLO fixtures and test helpers exist under `tests/testthat/fixtures/` and `tests/testthat/helper-*.R`.
- Existing GTAP benchmark scripts record solver metrics and accept locally supplied inputs; the checked-in result summary contains no proprietary model files.

### Established Patterns

- Documentation uses executable R and shell examples with exact public option names.
- Legacy and Matrix defaults, explicit backend selection, and fail-closed capability behavior are part of the public contract.
- Full-scale model inputs and solution artifacts remain external. Source archives already exclude `.planning/`, local benchmark data, and hidden files under `benchmarks/`.
- Routine checks should exercise deterministic, redistributable examples; the full-scale benchmark is a separately invoked workflow.

### Integration Points

- New `vignettes/` content and pkgdown configuration must stay consistent with `README.md`, generated API help, and `MIGRATION.md`.
- Vignette rendering and site generation must work with the package's declared dependencies and the clean source archive.
- Architecture and contributor guides need to match the R/native subsystem boundaries, numerical gates, cross-platform build process, and data restrictions.
- The benchmark guide should describe existing external harnesses and evidence fields without introducing private inputs into package or CI artifacts.

</code_context>

<specifics>
## Specific Ideas

- Make the documentation site useful to both package users and maintainers, with user-facing API/migration material and architecture/contributor guidance.
- Keep one focused vignette per required topic rather than combining the five topics into a few broad tutorials.
- Use runnable small examples in ordinary builds and document the complete full-scale benchmark procedure for readers supplying their own external inputs.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within the Phase 6 documentation-delivery scope.

</deferred>

---

*Phase: 06-Documentation and Release Qualification*
*Context gathered: 2026-10-05*
