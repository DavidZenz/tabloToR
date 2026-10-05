---
phase: 04
slug: public-api-and-solver-boundaries
status: verified
threats_open: 0
asvs_level: 1
created: 2026-10-01
verified: 2026-10-01
---

# Phase 04 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Public R API to model and solver state | Caller-provided models, selectors, shocks, closures, solve options, and serialized state enter the GEModel validation and lifecycle methods. | TABLO model structure, input arrays, selector strings, logical state, candidate results, diagnostics. |
| R backend registry to native code | Registered C++ adapters receive solver inputs and return candidates through the R acceptance boundary. | Sparse matrices, candidate vectors, capability/ABI evidence, thread limits, solve-scoped factors and buffers. |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-04-01 | Tampering | 04-01: backend selection and candidate acceptance | high | mitigate | Validate the requested ID before matrix construction; validate candidate structure, finiteness, and true residual before the single commit. Covered by solver-contract tests and post-fix review. | closed |
| T-04-01 | Tampering | 04-02: backend IDs and solver options | high | mitigate | Resolve exact registered IDs and validate options before matrix construction or state mutation. Covered by backend-routing contract tests. | closed |
| T-04-03 | Tampering / Denial of Service | 04-02: Rcpp symbols, ABI, kernels, and thread limits | high | mitigate | Check symbols, arities, ABI, capability payload, Matrix self-test, and thread bounds before solving; release resources through cleanup callbacks. Covered by native backend tests. | closed |
| T-04-01 | Tampering | 04-03: engine selection and public lifecycle methods | high | mitigate | Validate prerequisites and engine identity before solver construction or mutation; publish staged load state only after preparation succeeds. Covered by lifecycle-contract tests. | closed |
| T-04-02 | Denial of Service / Tampering | 04-03: logical-state payload loading | high | mitigate | Preserve byte/element limits and validate the complete payload before receiver installation; failures preserve receiver snapshots. Covered by lifecycle and serialization tests. | closed |
| T-04-01 | Tampering / Denial of Service | 04-04: compact output selectors and projection | high | mitigate | Validate exact variable/dimension names and estimated output size before allocation or postsimulation. Covered by documented-workflow tests. | closed |
| T-04-01 | Tampering | 04-05: conditions and diagnostic status fields | high | mitigate | Derive state from central transaction records, initialize a fresh diagnostics envelope per solve, and use stable typed condition classes. Covered by solver and transactional tests. | closed |
| T-04-03 | Denial of Service / Tampering | 04-05: native cleanup and capability evidence | high | mitigate | Retain unconditional cleanup and expose capability/cleanup outcomes on success and error paths. Covered by native backend tests. | closed |
| T-04-01 | Tampering / Denial of Service | 04-06: public exports and documented solver options | high | mitigate | Export only the approved GEModel facade, validate supported option ranges/defaults, and keep private controls outside the supported surface. Covered by namespace and documentation contracts. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*  
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*  
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-01 | 9 | 9 | 0 | Codex orchestrator, ASVS L1 |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-10-01
