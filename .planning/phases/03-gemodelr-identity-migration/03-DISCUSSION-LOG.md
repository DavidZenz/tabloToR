# Phase 3: GEModelR Identity Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-09
**Phase:** 3-GEModelR Identity Migration
**Areas discussed:** Namespace transition, Runtime options, Saved models, Migration experience

---

## Namespace Transition

| Question | Options considered | Selected |
|----------|--------------------|----------|
| Existing `tabloToR::` scripts | Explicit migration with coexistence; compatibility shim; immediate replacement | Immediate replacement |
| Enforce removal of old package | Documentation only; warn on coexistence; refuse coexistence | Documentation only |
| Migration tooling | Exact mechanical instructions; automated scanner; minimal notice | Exact mechanical instructions |
| `renv` projects | Reinstall and snapshot; leave implicit; rewrite lockfile | Reinstall and run `renv::snapshot()` |

**Notes:** GEModelR does not modify installed libraries. No compatibility package or source-rewriting utility is planned.

---

## Runtime Options

| Question | Options considered | Selected |
|----------|--------------------|----------|
| Old public option behavior | Actionable error; temporary aliases; ignore | Actionable error |
| New option prefix | `GEModelR.*`; `gemodelr.*`; `gemodel.*` | `GEModelR.*` |
| Validation timing | First relevant operation; package load; model creation | First relevant operation |
| Private hooks/attributes | Public contract only; migrate all compatibly; retain old names | Rename directly with no compatibility promise |

**Notes:** Errors must occur before relevant state mutation and identify the exact replacement plus migration guide.

---

## Saved Models

| Question | Options considered | Selected |
|----------|--------------------|----------|
| Load old logical states | Explicit support; reject; best effort | Explicit support |
| Re-save identity/schema | Schema 1 + GEModelR identity; schema 2; preserve old identity | Schema 1 + GEModelR identity |
| Old source fingerprints | Reviewed allowlist; ignore; caller override | Reviewed allowlist |
| Raw ReferenceClass RDS | Unsupported; best-effort import; converter | Unsupported across rename |

**Notes:** TABLO/model fingerprints and payload integrity remain mandatory. The rename alone does not change the logical schema.

---

## Migration Experience

| Question | Options considered | Selected |
|----------|--------------------|----------|
| Authoritative guide | `MIGRATION.md` + README; README only; package help only | `MIGRATION.md` + README/GitHub subsection |
| Migration errors | Replacement + guide; replacement only; generic guide error | Replacement + guide |
| Historical benchmark evidence | Preserve; relabel; retire | Preserve as pre-rename evidence |
| Stale identity detection | Machine-readable allowlist; directory exclusions; manual review | Machine-readable allowlist |

**Notes:** A dedicated GitHub Pages site is deferred to Phase 6. Historical records retain the identity under which they were produced.

## the agent's Discretion

- Internal data formats for migration allowlists and identity mappings.
- Exact helper organization and test decomposition.

## Deferred Ideas

- Separate compatibility shim package.
- Automated source or lockfile rewriting.
- Raw ReferenceClass converter.
- Dedicated GitHub Pages documentation site.
