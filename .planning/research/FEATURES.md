# Feature Research

**Domain:** Maintained R package for TABLO/CGE modeling
**Researched:** 2026-08-22
**Confidence:** HIGH

## Feature Landscape

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Clear license, authorship, and provenance | Users and repositories need redistribution certainty | HIGH | Requires upstream permission or documented replacement of unlicensed code |
| Stable documented public API | Downstream models need reproducibility | MEDIUM | Export `GEModel` and selected solver/diagnostic contracts only |
| Legacy compatibility | Existing scripts must continue to run | HIGH | Lock defaults and output semantics with contract tests |
| Portable installation | R users expect source/binary installation on major platforms | HIGH | OpenMP optional; remove runtime compilation |
| Numerical verification | Solver speed is irrelevant without trustworthy output | HIGH | Residual and cross-backend gates are mandatory |
| Actionable diagnostics | Full-scale failures are expensive | MEDIUM | Memory preflight, backend capability, phase timing, fallback detection |
| Small automated examples | Users need a redistributable path to first success | MEDIUM | Synthetic HAR/TABLO fixtures; no GTAP data |
| Versioned releases and NEWS | Users need migration and compatibility expectations | LOW | Semantic versioning and explicit lifecycle policy |

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Full-scale low-memory GTAP execution | Makes previously infeasible R runs practical | HIGH | Already validated on 163 × 65 GTAP 12a |
| Optional native structured solver | ~4× validated speedup without changing methodology | HIGH | Keep R reference and fail-closed selection |
| Reproducible benchmark gates | Auditable performance and numerical claims | MEDIUM | Signatures prevent comparing stale/wrong builds |
| Compact selected outputs | Avoids serializing giant model state | MEDIUM | Preserve full output for compatibility |
| Explicit closure/shock interface | Avoids dense named zero arrays | LOW | Keep `variableValues` adapter for migration |

### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Native backend as immediate default | Fastest measured path | Platform maturity and structured-model specificity | Keep opt-in and document selection |
| Separate C++ solver package now | Appears architecturally clean | Internal metadata is not yet a stable boundary | Modularize internally first |
| Full GTAP test in CI | Strong end-to-end confidence | Proprietary data, hours of runtime, >25 GiB RAM | Separate signed benchmark process |
| Automatic backend heuristics in v1 | Easier user experience | Can hide methodological/platform changes | Explicit backend with preflight advice |
| Database-backed equation solving | Suggests out-of-core scale | Sparse factorization requires numeric matrix access | Use databases only for optional staging |

## Feature Dependencies

```text
Legal provenance
  -> public package identity
      -> release metadata and distribution

Compatibility inventory
  -> explicit public API
      -> package rename
          -> migration guide and v1 release

Portable native boundary
  -> cross-platform CI
      -> R-universe binaries
```

## MVP Definition

### Launch With (v1)

- [ ] Legally distributable GEModelR identity with attribution.
- [ ] Compatible `GEModel` API and explicit backend contracts.
- [ ] Legacy, Matrix sparse, structured R, and optional native paths tested.
- [ ] Linux/macOS/Windows checks with a serial native build path.
- [ ] User, migration, architecture, and contributor documentation.
- [ ] Reproducible synthetic examples and external GTAP benchmark instructions.
- [ ] GitHub release and R-universe installation path.

### Add After Validation (v1.x)

- [ ] Improve optional SuiteSparse configure-time integration.
- [ ] Expand TABLO language compatibility fixtures from redistributable models.
- [ ] Add pkgdown benchmark dashboards and downstream model compatibility reports.

### Future Consideration (v2+)

- [ ] New model object system with a compatibility adapter.
- [ ] Automatic backend selection based on validated preflight rules.
- [ ] Standalone native solver library/package if a stable interface emerges.

## Prioritization

| Feature | User Value | Cost | Priority |
|---------|------------|------|----------|
| Legal/provenance gate | HIGH | HIGH | P1 |
| Compatibility/API contract | HIGH | HIGH | P1 |
| Rename and metadata | HIGH | MEDIUM | P1 |
| Portable CI/build | HIGH | HIGH | P1 |
| Documentation/release | HIGH | MEDIUM | P1 |
| SuiteSparse redesign | MEDIUM | HIGH | P2 |
| New object system | MEDIUM | HIGH | P3 |

## Sources

- [Upstream repository](https://github.com/mivanic/tabloToR) — existing public project and workflow.
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) — publication-quality, provenance, portability, checks.
- [R-universe publishing rules](https://docs.r-universe.dev/publish/terms.html) — package naming and collisions.
- Existing repository map and `benchmarks/GTAP12A_CPP_RESULTS.md` — validated technical differentiators.

---
*Feature research for: GEModelR*
*Researched: 2026-08-22*
