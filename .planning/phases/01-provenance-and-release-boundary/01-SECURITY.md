---
phase: 01
slug: provenance-and-release-boundary
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-31
---

# Phase 01 — Security

> Per-phase security contract for provenance evidence, rights state, package identity, and release gating.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Public/human evidence → repository records | Only scoped, attributable evidence may change rights or identity state. | Public legal and maintainer evidence |
| Source/Git history → provenance ledger | Technical evidence must not be promoted to unsupported authorship or ownership claims. | Source identities, hashes, commit metadata |
| Remote registries/APIs → release decisions | Partial, stale, or malformed responses must fail closed. | Public package and repository metadata |
| Repository evidence → filesystem/process | Paths, fixtures, and subprocesses must remain bounded and non-sensitive. | Local files and test execution |
| Human checkpoints → verification overrides | Ambiguous or automatic responses must not clear blockers. | Maintainer identity and decisions |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-001 | Elevation of privilege | rights transition | critical | mitigate | Exact states, scoped evidence, synthetic-only eligibility, and fail-closed unknown transitions. | closed |
| T-01-002 | Tampering | `--assert-blocked` | high | mitigate | Complete parser success and exact intentional-blocker matching. | closed |
| T-01-003 | Spoofing | rights evidence identity | high | mitigate | Evidence bound to repository, commit, scope, URL/hash, reviewer, and date. | closed |
| T-01-004 | Information disclosure | evidence and diagnostics | high | mitigate | Sensitive evidence rejected; diagnostics expose stable codes only. | closed |
| T-01-005 | Tampering | package supply chain | low | accept | Phase installs no packages and uses existing R/testthat dependencies only. | closed |
| T-01-006 | Elevation of privilege | request response transition | critical | mitigate | Draft, silence, and ambiguity cannot advance rights status. | closed |
| T-01-007 | Spoofing | upstream request/response identity | high | mitigate | Repository, commit, URL, UTC date, hash, responder evidence, and reviewer are bound. | closed |
| T-01-008 | Repudiation | external posting | high | mitigate | Human authorization and public URL/hash provide an audit trail. | closed |
| T-01-009 | Tampering | clean-room role evidence | high | mitigate | Distinct roles, attestations, provenance keys, behavior tests, and independent review. | closed |
| T-01-010 | Information disclosure | request/specification content | high | mitigate | Private correspondence, credentials, inherited excerpts, and proprietary fixtures excluded. | closed |
| T-01-011 | Tampering | source-key coverage | high | mitigate | Independent expected-key oracle, exact set/cardinality checks, and stable hashes. | closed |
| T-01-012 | Repudiation | reviewed provenance rows | high | mitigate | Stable-key reviewer/date/evidence preservation with changed-hash reporting. | closed |
| T-01-013 | Elevation of privilege | role assignment | high | mitigate | Roles require reviewed provenance and rights keys; Git metadata is non-authoritative. | closed |
| T-01-014 | Tampering | attribution destinations | high | mitigate | Independent schema, link, and parity checks cover all locked destinations. | closed |
| T-01-015 | Information disclosure | evidence and contributor records | high | mitigate | Only public commit/hash references retained; private and proprietary inputs excluded. | closed |
| T-01-016 | Spoofing | registry/search sources | medium | mitigate | Fixed endpoints, timestamps, hashes, availability, exact-match rules, and review. | closed |
| T-01-017 | Tampering | stale/partial name report | high | mitigate | Six-source report completeness, fresh check kinds, and verifier signatures. | closed |
| T-01-018 | Information disclosure | approved contact/security route | high | mitigate | Blocking human approval precedes committed public values. | closed |
| T-01-019 | Elevation of privilege | repository/release actions | high | mitigate | Explicit non-authorization markers and separate blocking checkpoints. | closed |
| T-01-020 | Repudiation | identity approval | medium | mitigate | Exact values, reviewer, UTC date, and cross-document parity recorded. | closed |
| T-01-021 | Tampering | cross-document parsers | critical | mitigate | Exact schemas, cardinality, cross-links, and parser reason codes. | closed |
| T-01-022 | Elevation of privilege | release-ready calculation | critical | mitigate | Fail-closed evaluation, synthetic-only success, and exact real blocker assertions. | closed |
| T-01-023 | Spoofing | identity/package parity | high | mitigate | Approved contact, slug, URLs, issue, and security values cross-checked. | closed |
| T-01-024 | Repudiation | reviewer/signature evidence | medium | mitigate | Reviewer/date required on rights, provenance, name, governance, and repository records. | closed |
| T-01-025 | Information disclosure | integrated diagnostics | high | mitigate | Diagnostics emit field/reason identifiers without sensitive values or contents. | closed |
| T-01-026 | Denial of service | online/stale evidence | medium | mitigate | Deterministic offline fixtures and explicit freshness/source failures. | closed |
| T-01-027 | Spoofing | source query identity | high | mitigate | Pages/repositories bound to HTTPS query, availability, raw MD5, and signed report row. | closed |
| T-01-028 | Tampering | pagination/count metadata | high | mitigate | Contiguous unique pages, stable totals, complete flags, and exact cardinality. | closed |
| T-01-029 | Tampering | Bioconductor scope | high | mitigate | Every advertised installable repository is derived and verified. | closed |
| T-01-030 | Denial of service | remote source availability | medium | mitigate | Bytes, time, and pages bounded; unavailable sources fail closed. | closed |
| T-01-031 | Elevation of privilege | GitHub name result | high | mitigate | Read-only requests and explicit non-authorization markers. | closed |
| T-01-032 | Information disclosure | raw remote payloads | low | accept | Temporary payloads are hashed then deleted; reports retain public metadata/hashes only. | closed |
| T-01-033 | Tampering | native hash normalizer | high | mitigate | Quoted/preprocessor tokens preserved; behavioral fixtures prove hash sensitivity. | closed |
| T-01-034 | Repudiation | native row re-review | high | mitigate | Versioned complete mapping, exact-set tests, and maintainer checkpoint. | closed |
| T-01-035 | Elevation of privilege | provenance status | high | mitigate | Classification-compatible statuses, real dates, and complete evidence validated centrally. | closed |
| T-01-036 | Spoofing | Git evidence as ownership | medium | mitigate | D-06 policy prohibits hash/Git-only role or ownership assignment. | closed |
| T-01-037 | Information disclosure | review fixtures | low | accept | Tiny synthetic native snippets and public commit/hash identifiers only. | closed |
| T-01-038 | Elevation of privilege | integrated version fallback | critical | mitigate | Exact marker cardinality/value checked before base eligibility. | closed |
| T-01-039 | Tampering | source/provenance binding | critical | mitigate | Fresh extraction, Git evidence, and shared key/hash/review validation. | closed |
| T-01-040 | Tampering | attribution destinations | high | mitigate | Six destinations checked for exact reviewed role/key parity. | closed |
| T-01-041 | Spoofing | dependency/license decision | high | mitigate | Exact expression bound to reviewed under-root audit evidence and R license validation. | closed |
| T-01-042 | Information disclosure | diagnostics/fixtures | high | mitigate | Stable reason codes and synthetic fixtures; no sensitive paths or contents retained. | closed |
| T-01-043 | Repudiation | reviewer/date evidence | medium | mitigate | Status, reviewer, date, and hash-bound records validated exactly. | closed |
| T-01-044 | Denial of service | source extraction/license validation | medium | mitigate | Evaluated roots and inputs bounded; parser/tool failures are explicit. | closed |
| T-01-045 | Elevation of privilege | evidence path resolution | critical | mitigate | Real paths normalized; traversal, symlink escape, and non-regular files rejected. | closed |
| T-01-046 | Tampering | source/test/fixture/result hashes | high | mitigate | Exact MD5 parity plus fresh test execution. | closed |
| T-01-047 | Spoofing | independent result producer | high | mitigate | Pairwise role constraints and hash-bound result metadata. | closed |
| T-01-048 | Repudiation | clean-room review | high | mitigate | Attestations, reviewer/date, test result, and immutable artifact hash required. | closed |
| T-01-049 | Denial of service | behavior test subprocess | medium | mitigate | One bounded Rscript invocation per component with explicit failure handling. | closed |
| T-01-050 | Information disclosure | external/sensitive fixture path | high | mitigate | Root escape and sensitive classes rejected; diagnostics omit paths/contents. | closed |
| T-01-051 | Spoofing | accepted_by identity | high | mitigate | Explicit identity, complete choice tuple, and UTC decision record. | closed |
| T-01-052 | Repudiation | override decision | high | mitigate | Exact persistent decision, reason, identity, timestamp, and one-to-one mapping. | closed |
| T-01-053 | Elevation of privilege | auto-approved checkpoint | critical | mitigate | Blocking-human gate prevents pending/ambiguous responses updating verification. | closed |
| T-01-054 | Tampering | fuzzy override scope | high | mitigate | Exact must-have targets and accepted entry/count validation. | closed |
| T-01-055 | Information disclosure | decision record | low | accept | Only public planning/evidence references and maintainer identity are recorded. | closed |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-01-005 | No dependency installation occurs during the phase. | Phase 01 plan | 2026-08-31 |
| AR-02 | T-01-032 | Remote payloads are public, temporary, hashed, and deleted. | Phase 01 plan | 2026-08-31 |
| AR-03 | T-01-037 | Review fixtures contain only tiny synthetic snippets and public identifiers. | Phase 01 plan | 2026-08-31 |
| AR-04 | T-01-055 | Decision records contain public references and maintainer identity only. | Phase 01 plan | 2026-08-31 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-31 | 55 | 55 | 0 | Codex, ASVS level 1 |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-31
