---
phase: 1
slug: provenance-and-release-boundary
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-24
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | R maintenance scripts plus Git/source assertions |
| **Config file** | `DESCRIPTION`; Wave 0 adds scripts under `tools/` |
| **Quick run command** | `Rscript --vanilla tools/check_release_gates.R --offline` |
| **Full suite command** | `Rscript --vanilla tools/provenance_inventory.R --check && Rscript --vanilla tools/check_release_gates.R --offline && git diff --check` |
| **Estimated runtime** | ~30 seconds offline; online name checks are manual release gates |

---

## Sampling Rate

- **After every task commit:** Run `Rscript --vanilla tools/check_release_gates.R --offline`
- **After every plan wave:** Run the full suite command above
- **Before `$gsd-verify-work`:** Full offline suite must be green and manual evidence statuses must be explicit
- **Max feedback latency:** 30 seconds for offline checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | PROV-01 | T-01-01 | Rights default to blocked; no inferred license | source/schema | `Rscript --vanilla tools/check_release_gates.R --offline` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | PROV-01 | T-01-02 | External request/posting requires explicit approval | source assertion | `Rscript --vanilla tools/check_release_gates.R --offline` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | PROV-01 | T-01-03 | Clean-room roles and evidence are separated | source/schema | `Rscript --vanilla tools/check_release_gates.R --offline` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | PROV-02 | T-01-04 | Every source symbol has one provenance classification | inventory check | `Rscript --vanilla tools/provenance_inventory.R --check` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | PROV-02 | T-01-05 | Unknown origin/holder/license basis blocks release | inventory check | `Rscript --vanilla tools/check_release_gates.R --offline` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | PROV-03 | T-01-06 | Name checks fail closed on collision or unavailable source | offline fixture + manual online | `Rscript --vanilla tools/check_name_availability.R --self-test` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | PROV-04 | T-01-07 | Maintainer/repository fields cannot remain placeholders | source assertion | `Rscript --vanilla tools/check_release_gates.R --offline` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tools/check_release_gates.R` — fail-closed parser and cross-document consistency checks for PROV-01, PROV-02, and PROV-04
- [ ] `tools/provenance_inventory.R` — function/file extraction, normalized hashes, coverage checks, and deterministic CSV validation
- [ ] `tools/check_name_availability.R` — name syntax, offline self-test fixtures, and explicit online query mode for PROV-03
- [ ] `docs/provenance/PROVENANCE.csv` — schema/header fixture consumed by the audit scripts

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Upstream licensing request is posted | PROV-01 | External communication requires user authority | Review `UPSTREAM-REQUEST.md`, explicitly approve posting, then record URL, UTC timestamp, and content hash in `RIGHTS.md`. |
| Rights grant is adequate | PROV-01 | Legal scope and rights-holder authority require human review | Compare the written grant/license against repository commit and inventory scope; record reviewer and retain blocked status if uncertain. |
| Clean-room independence is credible | PROV-01 | Source-access history and contributor attestations are human evidence | Verify role separation, attestations, behavior specs, and independent review before changing any row to `new-independent`. |
| Live package-name availability | PROV-03 | Network registries are time-varying | Run the online name checker at reservation and release; review raw evidence and sign `NAME-CHECK.md`. |
| Repository detachment/privacy change | PROV-04 | GitHub operation changes external state and may discard metadata | Inventory issues/PRs/settings, approve the operation, perform it in GitHub, and record resulting private standalone repository evidence. |
| Maintainer contact is approved | PROV-04 | The contact address is personal/public information | David Zenz confirms the durable address before it is recorded in release metadata. |

---

## Threat Model

| ID | Threat | Severity | Mitigation | Verification |
|----|--------|----------|------------|--------------|
| T-01-01 | Placeholder or absent license is treated as permission | Critical | Rights status defaults to `blocked`; only evidence-backed transitions allowed | Offline release-gate script |
| T-01-02 | Agent posts an issue or changes repository settings without authority | High | External actions are non-autonomous checkpoints | Plan task metadata plus manual sign-off |
| T-01-03 | Same source-exposed person claims clean-room independence | High | Separate roles and source-access attestations | Human clean-room review |
| T-01-04 | Functions disappear from provenance coverage | High | Deterministic symbol inventory and one-row cardinality check | Provenance check script |
| T-01-05 | Unknown or contradictory attribution is silently accepted | High | Unknown/missing evidence fails release gate | Offline release-gate script |
| T-01-06 | Stale or partial name search is called authoritative | Medium | Timestamped multi-registry checks at reservation and release | Online report review |
| T-01-07 | Private migration loses GitHub metadata/history | Medium | Pre-migration inventory, mirror verification, explicit approval | Manual repository checklist |

---

## Validation Sign-Off

- [x] All anticipated tasks have automated verification or documented Wave 0 dependencies
- [x] Sampling continuity: no three consecutive tasks lack automated verification
- [x] Wave 0 covers all missing automated references
- [x] No watch-mode flags
- [x] Offline feedback latency target is below 30 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-08-24 for planning; execution evidence remains pending
