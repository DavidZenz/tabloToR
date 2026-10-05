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
| **Estimated runtime** | ~1,800 seconds provisional; record measured time during the first full archive check |

---

## Sampling Rate

- **After every task commit:** Run Rscript -e 'testthat::test_local()'
- **After every plan wave:** Build the source archive and run R CMD check on that archive
- **Before $gsd-verify-work:** Full source-archive check must meet CI-02
- **Max feedback latency:** 1,800 seconds; update from the measured archive-check duration

---

## Per-Task Verification Map

Task IDs and plan waves are assigned by the planner after decomposition. Each requirement below must be linked to its implementing task before execution.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| Pending | Pending | Pending | NUM-03 | Pending | Benchmark summary validates residuals, finiteness, no dense fallback, time, memory, hardware, and package/model fingerprints; private inputs stay external | external gate | Existing benchmark runner and checker with user-supplied GTAP inputs | runner/checker exist | pending |
| Pending | Pending | Pending | CI-02 | Pending | Only the built archive is qualified; existing warnings and significant notes are resolved or accurately explained | package check | R CMD build . && R CMD check <built-source-archive.tar.gz> | package check available | pending |
| Pending | Pending | Pending | DOCS-02 | Pending | Five focused vignettes use small redistributable examples; full-scale execution is excluded from normal builds | vignette build | Built-archive R CMD check and pkgdown site build | vignettes to be created | pending |
| Pending | Pending | Pending | DOCS-03 | Pending | Architecture and contributor guidance describe subsystem boundaries, numerical gates, native development, and data restrictions | documentation review | Site build plus source-backed content review | phase guides to be created | pending |
| Pending | Pending | Pending | REL-01 | Pending | NEWS, SemVer/lifecycle policy, citation/provenance text, and release checklist match current package behavior and blockers | metadata review | Cross-check NEWS, DESCRIPTION, inst/CITATION, and release documents | metadata files exist | pending |
| Pending | Pending | Pending | DATA-01 | Pending | Source archive and public CI artifacts contain no proprietary inputs, private credentials, giant solutions, or unsupported benchmark scratch | archive/artifact inspection | Inspect built archive manifest and public CI artifact contents | archive-content gate to be established | pending |

---

## Wave 0 Requirements

- Existing testthat edition 3 infrastructure and redistributable fixture helpers cover the package test harness; no framework installation is required.
- The planner must assign every requirement row above to a concrete task and wave.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full-scale GTAP run and evidence review | NUM-03 | Requires externally held GTAP inputs and target hardware; the repository must not bundle them. | Run the existing external benchmark workflow with authorized local inputs; use the benchmark gate; review residuals, finiteness, dense-fallback status, runtime, peak memory, hardware, and package/model fingerprints. Treat MD5 fingerprints as fingerprints, not authenticated signatures. |
| Architecture/contributor guide accuracy | DOCS-03 | A reader must confirm the prose matches current R/native ownership and contributor workflow. | Compare documented subsystem boundaries, numerical gates, platform build paths, and data restrictions against the implementation and CI configuration. |
| Release and provenance wording | REL-01 | Legal clearance and attribution identity remain separately gated and cannot be inferred from a green package check. | Verify the version/lifecycle wording, citation, NEWS, and checklist against package behavior and current release-gate status; do not imply publication is cleared. |

---

## Validation Sign-Off

- [ ] All tasks have an automated verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 1,800s
- [ ] nyquist_compliant: true set in frontmatter after validation

**Approval:** pending
