---
phase: 6
slug: documentation-and-release-qualification
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-05
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat edition 3 |
| **Config file** | DESCRIPTION; runner tests/testthat.R |
| **Quick run command** | Rscript -e 'testthat::test_local()' |
| **Full suite command** | R CMD build . && R CMD check <built-source-archive.tar.gz> |
| **Estimated runtime** | Full built-archive check: ~1,800 seconds provisional; record the measured duration on the first run. The external full-scale benchmark is a separate manual gate with a historical duration near 4,680 seconds (~78 minutes); remeasure on target hardware. |

---

## Sampling Rate

- **After every task commit:** Run Rscript -e 'testthat::test_local()'
- **After every plan wave:** Build the source archive and run R CMD check on that archive
- **Before $gsd-verify-work:** Full source-archive check must meet CI-02
- **Max automated feedback latency:** 1,800 seconds provisional for package/site/archive tasks; record actual duration. External manual gates are reported separately and do not use this sampling target.

---

## Per-Task Verification Map

Plans assign every requirement to concrete tasks and waves. Commands below remain pending until execution; the built-archive check is the qualification authority.

Task IDs and plan waves are assigned by the planner after decomposition. Each requirement below must be linked to its implementing task before execution.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-05-T2 | 06-05 | 4 | NUM-03 | T-06-05-01 | Current benchmark evidence records required numerical, runtime, memory, hardware, and source/model identity; private inputs remain external | automated procedure review + separate external benchmark gate (~78 minutes historically) | Confirm the repository-only procedure names `run_gtap12a_ab.R`, its explicit external `--output-dir`, and `check_benchmark_gate.R`; run the full benchmark only with authorized inputs and explicitly mark the summary unsigned | Existing runner/checker; result update planned | pending (external user setup) |
| 06-06-T3 | 06-06 | 5 | CI-02 | T-06-06-01, T-06-06-02 | The exact guarded archive is checked with Pandoc and PDF-manual tooling; warnings remain visible | hosted source-archive qualification | Build once, inspect the tarball with the archive guard, and run full R CMD check on that same archive in the blocking workflow | Planned | pending (license gate may remain blocked) |
| 06-01-T1 | 06-01 | 1 | DOCS-02 | T-06-01-01, T-06-01-02 | First redistributable vignette renders through the built package and read-only site artifact | archive/site build | `R CMD build . && Rscript -e 'pkgdown::build_site()' && test -s .pkgdown-site/index.html && test -f .pkgdown-site/articles/first-simulation.html` | Planned | pending |
| 06-01-T2 | 06-01 | 1 | DOCS-02 | T-06-01-02 | Generated site output is absent from the source archive | archive manifest | Build the archive, then assert its tar member list has no `.pkgdown-site` entries | Planned | pending |
| 06-02-T1 | 06-02 | 2 | DOCS-02 | T-06-02-01 | Migration and backend articles use redistributable fixtures and explain explicit backend behavior | vignette build | `R CMD build .` | Planned | pending |
| 06-02-T2 | 06-02 | 2 | DOCS-02 | T-06-02-01, T-06-02-02 | Diagnostics remain lightweight and full-scale benchmark chunks remain unevaluated | archive/site/content check | `R CMD build . && Rscript -e 'pkgdown::build_site()'` plus article content review | Planned | pending |
| 06-03-T1 | 06-03 | 3 | DOCS-03 | T-06-03-02 | Architecture and contributor guidance matches current R/native ownership and governance | archive/site build | `R CMD build . && Rscript -e 'pkgdown::build_site()' && test -s .pkgdown-site/articles/architecture.html && test -s .pkgdown-site/articles/contributing.html` | Planned | pending |
| 06-03-T2 | 06-03 | 3 | DOCS-02, DOCS-03 | T-06-03-01, T-06-03-02 | Navigation exposes user/API/migration/maintainer guidance while release/provenance evidence stays out of the site | site/content inspection | `Rscript -e 'pkgdown::build_site()'` plus positive navigation and negative repository-evidence assertions on generated output | Planned | pending |
| 06-04-T1 | 06-04 | 1 | REL-01 | T-06-04-01 | NEWS, citation, lifecycle semantics, and identity retain reviewed metadata and both blocker identifiers | metadata gate/archive build | Check lifecycle artifact, blocker strings, citation metadata, then run `R CMD build .` | Planned | pending |
| 06-04-T2 | 06-04 | 1 | REL-01 | T-06-04-02 | Release checklist links executable evidence and retains intentional blocked state | release gate/content check | `Rscript --vanilla tools/check_release_gates.R --assert-blocked` plus checklist content checks | Planned | pending |
| 06-05-T1 | 06-05 | 4 | NUM-03 | T-06-05-01 | Evidence guide defines all required metrics, redaction, and the unsigned evidence policy; MD5 is only a fingerprint | documentation review | Check `docs/release/BENCHMARK-EVIDENCE.md` for runner/checker, required fields, unsigned status, and the limits of fingerprints | Planned | pending |
| 06-06-T1 | 06-06 | 5 | CI-02 | T-06-06-02 | Hosted predecessor serialization failures are repaired without weakening lineage, payload, or transactional validation | focused regressions/BUGFIX gate | Focused test files followed by `tools/check_serialization_bugfix.R --verify` | Planned | pending |
| 06-06-T2 | 06-06 | 5 | DATA-01 | T-06-06-01 | Archive-content guard accepts clean fixtures and rejects forbidden paths, suspicious content, and oversized result data | synthetic privacy tests | `Rscript -e 'testthat::test_file("tests/testthat/test-source-archive.R")'` | Planned | pending |

---

## Wave 0 Requirements

- Existing testthat edition 3 infrastructure and redistributable fixture helpers cover the package test harness; no framework installation is required.
- Wave mapping is explicit in the plan set: wave 1: 06-01 and 06-04; wave 2: 06-02; wave 3: 06-03; wave 4: 06-05; wave 5: 06-06.
- Documentation and site checks require development-only `knitr`, `rmarkdown`, and `pkgdown` plus Pandoc; the full archive check also requires `pdflatex`.
- Hosted serialization regressions must pass before archive qualification; archive/privacy tests must pass before any public CI artifact upload.
- The full-scale NUM-03 run requires authorized external GTAP inputs and target hardware. These are external gates, not Wave 0 fixtures.
- CI-02 remains blocked while the real placeholder-license warning or unexplained significant notes remain; preserve the Phase 1 legal-gate state.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full-scale GTAP run and evidence review | NUM-03 | Requires externally held GTAP inputs and target hardware; the repository must not bundle them. A prior run took about 78 minutes, but the current runner and target hardware may differ. | Run the A/B workflow from `benchmarks/run_gtap12a_ab.R` with authorized local inputs and an output directory outside the repository; review the gate, residuals, finiteness, dense-fallback status, runtime, peak memory, hardware, and package/model fingerprints. Record the target duration. Treat MD5 fingerprints as fingerprints, not authenticated signatures. |
| Summary authorship authentication | NUM-03 | The summary is intentionally unsigned; package/model fingerprints and source identity do not authenticate who ran or recorded the benchmark. | No authorship claim is made. Numerical acceptance depends on the runner and independent checker; any future authorship-authentication requirement needs a separate policy decision. |
| Architecture/contributor guide accuracy | DOCS-03 | A reader must confirm the prose matches current R/native ownership and contributor workflow. | Compare documented subsystem boundaries, numerical gates, platform build paths, and data restrictions against the implementation and CI configuration. |
| Release and provenance wording | REL-01 | Legal clearance and attribution identity remain separately gated and cannot be inferred from a green package check. | Verify the version/lifecycle wording, citation, NEWS, and checklist against package behavior and current release-gate status; do not imply publication is cleared. |
| Hosted release qualification | CI-02 | R, Matrix, Pandoc, and TeX availability differ from the local environment; the current license warning is a real Phase 1 blocker. | Run the blocking workflow against the built archive with full manual tooling. Preserve its warning and fail status until the legal gate is separately resolved; do not report qualification as green while the warning persists. |

---

## Validation Sign-Off

- [ ] All tasks have an automated verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 1,800s
- [ ] nyquist_compliant: true set in frontmatter after validation

**Approval:** pending
