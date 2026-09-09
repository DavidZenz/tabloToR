# Phase 3: GEModelR Identity Migration - Context

**Gathered:** 2026-09-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Rename the package, native registration, runtime options, diagnostics, benchmark metadata, tests, and current documentation from `tabloToR` to `GEModelR` without changing solver algorithms, numerical defaults, or the Phase 2 public workflow. This phase also provides an explicit source and saved-state migration path. It does not narrow the API, introduce a compatibility package, redesign serialization, perform portability work, rewrite historical evidence, or publish a release.

</domain>

<decisions>
## Implementation Decisions

### Namespace transition

- **D-01:** Use an immediate package replacement. Users remove `tabloToR`, install `GEModelR`, and update namespace-qualified calls; do not build a `tabloToR` compatibility shim. GEModelR does not inspect, uninstall, warn about, or block an independently installed old package. — **Reversibility:** costly — reversing this requires restoring the old package namespace and downstream dependency declarations.
- **D-02:** Provide exact mechanical replacements for `library(tabloToR)`, `require(tabloToR)`, `tabloToR::`, installation commands, and package dependency declarations. For `renv` projects, reinstall the renamed package and run `renv::snapshot()`; never prescribe manual `renv.lock` editing.

### Runtime options

- **D-03:** Rename every supported runtime option to the exact `GEModelR.*` prefix. If a documented `tabloToR.*` option is set, reject it at the first relevant operation before model-state mutation, identify the exact replacement, and link to `MIGRATION.md`. Do not silently ignore or temporarily honor old public keys. — **Reversibility:** costly — changing the option contract again would require another user-facing migration.
- **D-04:** Rename private fault hooks, internal transaction options, and internal error attributes directly to GEModelR identity. They receive no compatibility aliases or migration guarantee.

### Saved models

- **D-05:** Explicitly load fully validated pre-rename `gemodel-logical-state` files. Keep schema version `1L`, normalize package identity to GEModelR in memory, and write only GEModelR identity on subsequent saves. — **Reversibility:** costly — removing this support would strand logical states covered by the migration contract.
- **D-06:** Accept an old logical state only when its package source fingerprint is in a reviewed pre-rename allowlist; continue validating TABLO/model fingerprints and payload integrity. Raw `saveRDS(model)` ReferenceClass objects are not supported across the rename, and users must create a logical `saveState()` file before upgrading.

### Migration experience and identity audit

- **D-07:** Make root-level `MIGRATION.md` the authoritative guide. Add a prominent migration subsection to the README/GitHub repository landing page. Runtime migration errors show the rejected identifier, its exact GEModelR replacement, and a guide reference. A separate GitHub Pages site belongs to Phase 6.
- **D-08:** Preserve existing benchmark and baseline records as immutable pre-rename evidence. Label them historical and add a reviewed mapping from old package/source identities to the GEModelR migration baseline; never mechanically relabel past runs.
- **D-09:** Maintain a machine-readable allowlist for intentional `tabloToR` occurrences. Automated tests reject every unexpected occurrence and permit only upstream attribution, migration instructions, immutable historical evidence, old-option replacement mappings, and reviewed serialization fingerprints.

### the agent's Discretion

- Choose the implementation shape for centralized option migration checks and actionable error construction.
- Choose the machine-readable formats for the old-identity occurrence allowlist, pre-rename source-fingerprint allowlist, and benchmark identity mapping.
- Choose task boundaries and generated Rcpp regeneration commands while preserving numerical code and the Phase 2 contract.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and inherited decisions

- `.planning/PROJECT.md` — GEModelR identity, package boundary, compatibility constraints, and deferred work.
- `.planning/REQUIREMENTS.md` — Phase 3 requirements COMP-04, MIGR-01, and MIGR-02.
- `.planning/ROADMAP.md` — Phase 3 goal, dependency, and success criteria.
- `.planning/phases/01-provenance-and-release-boundary/01-CONTEXT.md` — reviewed package/repository name, maintainer identity, attribution, and release boundary.
- `.planning/phases/02-compatibility-and-numerical-baseline/02-CONTEXT.md` — frozen public workflow, backend defaults, numerical authority, and serialization decisions.
- `.planning/phases/02-compatibility-and-numerical-baseline/02-VERIFICATION.md` — verified Phase 2 behavioral baseline that the rename must preserve.

### Package and native identity

- `DESCRIPTION` — package name, metadata, URLs, and dependency identity.
- `NAMESPACE` — native library registration and current export policy; export narrowing remains Phase 4.
- `R/RcppExports.R` — generated R-side native wrappers and private symbol names.
- `src/RcppExports.cpp` — generated native registration table and `R_init_tabloToR` entry point.
- `R/zzzSparseSchurCpp.R` and `src/tablo-sparse-lu.h` — native capability and identity-bearing diagnostics.

### Runtime, serialization, and migration surfaces

- `R/GEModel.R` — public GEModel workflow and legacy transaction option.
- `R/sparseSolver.R`, `R/sparseElimination.R`, `R/sparseSchurComplement.R`, and `R/sparseSuiteSparse.R` — supported sparse option keys, errors, and diagnostics.
- `R/modelSerialization.R` — logical-state schema, source identity, limits, and reconstruction checks.
- `tests/testthat/baselines/phase02/fingerprints.dcf` — accepted pre-rename source fingerprint.
- `tests/testthat/baselines/phase02/ACCEPTANCE.md` — human-reviewed baseline acceptance record.

### Documentation, benchmarks, and audit gates

- `README.md` — GitHub landing page and current installation/solver examples.
- `inst/CITATION` — predecessor attribution that must remain intentional.
- `benchmarks/benchmark_config.R` and `benchmarks/benchmark_gtap12a_run.R` — package/model signatures and runtime option metadata.
- `inst/compatibility/GEModel-contract.csv` — frozen observed API tiers and identity-bearing contracts.
- `tools/check_release_gates.R` and `tools/provenance_inventory.R` — release/provenance checks containing intentional predecessor identity.

No external specifications were referenced during discussion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- The Phase 2 compatibility manifest and integrated tests provide a pre-rename contract oracle for namespace, workflow, diagnostics, outputs, and serialization.
- The accepted Phase 2 source fingerprint `f57c39e0bdd3020b48a602773c580a8d` provides the first reviewed entry for old logical-state migration.
- Existing release/provenance tooling already distinguishes intentional predecessor attribution from current package identity.

### Established Patterns

- `GEModel` remains the public class name and the legacy engine/Matrix backend defaults stay fixed during this phase.
- Rcpp wrappers and registration files are generated rather than hand-maintained.
- Public errors fail before mutable model state is committed.
- Historical benchmark evidence is fingerprinted and must not be rewritten as if it were produced by a different package.

### Integration Points

- Identity spans `DESCRIPTION`, `NAMESPACE`, generated Rcpp files, C++ registration/symbol strings, R option keys, error attributes, diagnostics, tests, benchmark schemas, and documentation.
- `R/modelSerialization.R` must distinguish reviewed pre-rename package fingerprints from current GEModelR source identity without weakening payload/model validation.
- A repository identity audit must scan package code and artifacts while allowing only categorized historical or migration references.

</code_context>

<specifics>
## Specific Ideas

- The supported source edits are mechanical: `library(tabloToR)` → `library(GEModelR)`, `require(tabloToR)` → `require(GEModelR)`, `tabloToR::` → `GEModelR::`, and documented `tabloToR.*` options → their exact `GEModelR.*` equivalents.
- Users with raw ReferenceClass RDS files must use the old package to create a logical state before upgrading.
- The GitHub repository landing page should make the rename visible without duplicating the complete authoritative migration guide.

</specifics>

<deferred>
## Deferred Ideas

- A separate `tabloToR` compatibility shim package is not part of v1.
- Automated source/lockfile rewriting and a raw-RDS converter are not part of Phase 3.
- A dedicated GitHub Pages documentation site remains Phase 6 work.
- API narrowing remains Phase 4; native portability and CI remain Phase 5; publication remains Phase 7.

</deferred>

---

*Phase: 3-GEModelR Identity Migration*
*Context gathered: 2026-09-09*
