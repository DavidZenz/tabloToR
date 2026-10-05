# Phase 6: Documentation and Release Qualification - Pattern Map

**Mapped:** 2026-10-05  
**Files analyzed:** 25 planned or implied files  
**Analogs found:** 22 / 25

The phase decisions specify the documentation topics and release outcomes, but not every filename. Paths below are concrete suggestions for the planner where the scope names a deliverable rather than an exact path. The site configuration and release publication workflow remain separate: phase 6 builds documentation; release evidence says publication is still gated.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `vignettes/first-simulation.Rmd` | documentation | request-response | `README.md`; `tests/testthat/helper-three-region.R` | role-match |
| `vignettes/legacy-to-sparse.Rmd` | documentation | transform | `MIGRATION.md`; `README.md` | role-match |
| `vignettes/backend-selection.Rmd` | documentation | request-response | `R/apiDocumentation.R`; `README.md` | role-match |
| `vignettes/diagnostics-memory-budgeting.Rmd` | documentation | request-response | `R/apiDocumentation.R`; `README.md` | role-match |
| `vignettes/external-full-scale-benchmarking.Rmd` | documentation | batch | `README.md`; `benchmarks/run_gtap12a_ab.R` | role-match |
| `vignettes/helpers.R` (if shared helper is used) | utility | transform | `tests/testthat/helper-three-region.R` | role-match |
| `inst/extdata/three-region.tab` (if the vignette reuses the fixture) | model / fixture | file-I/O | `tests/testthat/fixtures/three-region.tab` | partial |
| `inst/extdata/PROVENANCE.md` (if installed fixture is added) | documentation | transform | `tests/testthat/fixtures/PROVENANCE.md` | role-match |
| `_pkgdown.yml` | config | transform | `README.md`; `DESCRIPTION` | none |
| `.github/workflows/pkgdown.yaml` (or equivalent build-only job) | config | batch | `.github/workflows/native-ci.yaml` | role-match |
| `.Rbuildignore` | config | batch | `.Rbuildignore` | exact |
| `DESCRIPTION` | config | transform | `DESCRIPTION` | exact |
| `README.md` | documentation | request-response | `README.md` | exact |
| `MIGRATION.md` | documentation | transform | `MIGRATION.md` | exact |
| `docs/architecture.md` | documentation | transform | `R/apiDocumentation.R`; `.github/workflows/native-ci.yaml` | none |
| `CONTRIBUTING.md` | documentation | request-response | `GOVERNANCE.md`; `.github/workflows/native-ci.yaml` | partial |
| `NEWS.md` | documentation | batch | `NEWS.md` | exact |
| `inst/CITATION` | config | transform | `inst/CITATION` | exact |
| `docs/release/VERSION-LIFECYCLE.md` | documentation | transform | `NEWS.md`; `docs/release/RELEASE-GATES.md` | partial |
| `docs/release/RELEASE-CHECKLIST.md` | documentation | batch | `docs/release/RELEASE-GATES.md` | role-match |
| `docs/release/RELEASE-GATES.md` | documentation | batch | `docs/release/RELEASE-GATES.md` | exact |
| `benchmarks/GTAP12A_CPP_RESULTS.md` | documentation | batch | `benchmarks/GTAP12A_CPP_RESULTS.md` | exact |
| `tools/ci/check-source-archive.R` (if a separate manifest gate is added) | utility | batch | `tools/ci/summarize-r-cmd-check.R` | none |
| `tools/ci/summarize-r-cmd-check.R` | utility | batch | `tools/ci/summarize-r-cmd-check.R` | exact |
| `.github/workflows/native-ci.yaml` | config | batch | `.github/workflows/native-ci.yaml` | exact |

## Pattern Assignments

### `vignettes/first-simulation.Rmd` (documentation, request-response)

**Analog:** `tests/testthat/helper-three-region.R` and `tests/testthat/test-documented-workflow.R`

Use a small authored model with explicit inputs so the vignette works after installation. The current test fixture is under `tests/`, so it is not available to an installed package vignette through `system.file()` without an installed copy or a generated temporary fixture.

**Deterministic input pattern** (`tests/testthat/helper-three-region.R`, lines 31-47):

```r
three_region_input_data = function() {
  regions = c("north", "south", "east")
  list(
    basedata = list(
      weight = array(
        c(1, 1.5, 2),
        dim = 3L,
        dimnames = list(reg = regions)
      ),
      stock = array(
        c(100, 200, 300),
        dim = 3L,
        dimnames = list(reg = regions)
      )
    )
  )
}
```

**Core public workflow pattern** (`tests/testthat/helper-three-region.R`, lines 66-72):

```r
make_three_region_model = function(engine = "sparse") {
  model = GEModel$new()
  model$loadTablo(three_region_fixture_path())
  model$setClosure("tax")
  model$loadData(three_region_input_data(), engine = engine)
  model
}
```

The companion `set_three_region_shocks()` and `solve_three_region_once()` helpers in lines 82-116 provide explicit shock labels and a deterministic one-step solve.

For installed-package access, adapt the `system.file()` resolution style in `tests/testthat/helper-three-region.R` lines 15-28 to `system.file("extdata", ..., package = "GEModelR")`, or generate the tiny `.tab` file in the vignette helper using `tempfile()` and `writeLines()`. Do not rely on `testthat::test_path()` in a published vignette.

### `vignettes/legacy-to-sparse.Rmd` (documentation, transform)

**Analog:** `MIGRATION.md`

Retain exact before/after replacements, explicit sequencing, and warnings that explain runtime behavior. Preserve the authoritative migration guide as the source of truth and keep the vignette shorter.

**Replacement-table pattern** (`MIGRATION.md`, lines 33-47):

````markdown
| Before | After |
|---|---|
| `library(tabloToR)` | `library(GEModelR)` |
| `require(tabloToR)` | `require(GEModelR)` |
| `tabloToR::` | `GEModelR::` |

For example:

```r
model = GEModelR::GEModel$new()
```
````

Use the same concise contract language as `README.md` lines 38-42: immediate package replacement, no compatibility shim, and a direct link to the detailed guide.

### `vignettes/backend-selection.Rmd` (documentation, request-response)

**Analog:** `R/apiDocumentation.R` and `README.md`

Keep runtime `engine` separate from sparse `backend`, spell out defaults and unavailable capability behavior, and show the explicit supported choice. Do not duplicate signatures by hand when generated package help can be linked.

**Public API workflow and backend contract** (`R/apiDocumentation.R`, lines 17-23 and 50-70):

```r
model <- GEModel$new()
model$loadTablo("model.tab")
model$loadData(input_data, engine = "sparse")
model$setShocks(shocks)
model$solveModel(engine = "sparse", backend = "Matrix")
```

The `engine` argument chooses the model runtime: `legacy` uses the established
in-memory solver and `sparse` uses sparse execution. The sparse `backend`
argument independently chooses a solver implementation and defaults to
`"Matrix"`. Explicit unavailable backend requests fail capability preflight;
they are not silently replaced.

The README demonstrates explicit `backend = "Matrix"` selection at lines 208-214 and describes reserved SuiteSparse behavior. Keep that behavior aligned with generated help.

### `vignettes/diagnostics-memory-budgeting.Rmd` (documentation, request-response)

**Analog:** `R/apiDocumentation.R` and `README.md`

Present the supported memory API and diagnostics envelope instead of exposing private cache or compiler fields. Link the help reference for the full stable diagnostic field list.

**Diagnostics and memory API pattern** (`README.md`, lines 193-204; `R/apiDocumentation.R`, lines 81-115 and 151-153):

```r
print(model$estimateMemory(engine = "sparse"))
model$solveModel(
  iter = 3,
  steps = c(1, 3),
  engine = "sparse",
  postsim = FALSE,
  output = "compact",
  variables = c("ev", "qo"),
  diagnostics = TRUE
)
model$compactOutput
```

`diagnostics = TRUE` adds residual history, timings, allocation and capability
evidence, detailed cleanup, and memory estimates. `memory_budget` on
`solveModel()` overrides the instance budget for that solve; `setMemoryBudget()`
sets the instance budget.

`README.md` lines 193-206 shows the compact-output and memory-budget path. Copy public option names and keep claims about estimates and preflight behavior precise.

### `vignettes/external-full-scale-benchmarking.Rmd` (documentation, batch)

**Analog:** `README.md`, `benchmarks/run_gtap12a_ab.R`, and `benchmarks/check_benchmark_gate.R`

Document the external command, required locally supplied inputs, generated evidence, and gate invocation. Mark benchmark chunks unevaluated or use plain shell text; ordinary archive and site builds must not execute this full-scale workflow.

**External command pattern** (`README.md`, lines 257-268):

```sh
Rscript benchmarks/benchmark_gtap12a.R \
  --data-dir="/path/to/gtap12a" \
  --tablo="/path/to/gtapv7.tab" \
  --closure-file="/path/to/closure.rds" \
  --backend=StructuredSchurFGMRESCpp \
  --threads=4 \
  --panel-size=64 \
  --steps="1,3"
```

**Gate field contract** (`benchmarks/check_benchmark_gate.R`, lines 62-68):

```r
c(
  "solve_seconds", "peak_rss_bytes", "max_full_relative_residual",
  "solution_finite", "selected_outputs_finite",
  "dense_full_system_operations"
)
```

The checker rejects non-finite solution/output flags and dense full-system operations (`check_benchmark_gate.R`, lines 251-263). The runner writes result CSVs and optional solution artifacts; tell readers to keep those outputs outside the package/repository when they are large or private.

### `vignettes/helpers.R`, `inst/extdata/three-region.tab`, and `inst/extdata/PROVENANCE.md` (utility / fixture)

**Analog:** `tests/testthat/helper-three-region.R`, `tests/testthat/fixtures/three-region.tab`, and `tests/testthat/fixtures/PROVENANCE.md`

The existing fixture is small and explicitly documented as newly authored, CC0-1.0, deterministic, and free of GTAP/SmallAg content (`fixtures/PROVENANCE.md`, lines 3-12). The `.tab` file describes three regions and a simple equation (`fixtures/three-region.tab`, lines 1-11). If vignettes reuse it, install a redistributable copy and its provenance note under `inst/extdata`; if examples create it dynamically, place the shared generator/data-array helper in `vignettes/helpers.R`. Existing test helpers can be adapted, but must not be sourced from testthat in installed vignettes.

### `_pkgdown.yml` and `.github/workflows/pkgdown.yaml` (config, transform / batch)

**Analog:** partial site-build pattern in `.github/workflows/native-ci.yaml`; content inputs in `README.md`, `man/GEModelR-package.Rd`, and `MIGRATION.md`

No pkgdown config exists. Build the reference from R help, README, and the five vignettes; add links for migration, architecture, and contributor guidance. Keep detailed `docs/release` and `docs/provenance` evidence out of navigation. pkgdown cleans its output directory, so use a dedicated generated destination outside those evidence directories and outside the source package if appropriate.

**Existing CI boundary pattern** (`.github/workflows/native-ci.yaml`, lines 10-12 and 142-149):

```yaml
permissions:
  contents: read

# Existing R dependency setup keeps docs renderers out of runtime Imports.
- name: Install package dependencies
  uses: r-lib/actions/setup-r-dependencies@f9a764fea8d5c63df6ef9a5c7795bf7deb5d7e05
  with:
    packages: deps::.
    cache: false
    install-pandoc: false
    install-quarto: false
```

Follow the workflow's read-only permission and credential-free checkout pattern. Phase 6 needs a build artifact/check path; any Pages deployment belongs to the later protected publication gate.

### `DESCRIPTION`, `.Rbuildignore`, and archive qualification (config, batch)

**Analogs:** `DESCRIPTION`, `.Rbuildignore`, `tools/ci/summarize-r-cmd-check.R`

Put knitr and rmarkdown in `Suggests`, declare `VignetteBuilder: knitr`, and keep pkgdown as a development/site dependency rather than a runtime import. Exclude generated site output, local benchmark data, and scratch files explicitly.

**Current dependency sections** (`DESCRIPTION`, lines 21-30):

```text
Imports:
    Matrix (>= 1.6-5),
    Rcpp,
    SparseM,
    methods
Suggests:
    testthat
Config/testthat/edition: 3
```

**Current archive exclusions** (`.Rbuildignore`, lines 1-7):

```text
^\.benchmark-data$
^\.git$
^\.planning$
^\.Rcheck$
^\.Rproj.user$
^benchmarks/\.
^rcpp-solver-acceleration-plan\.md$
```

Do not treat `^benchmarks/\.` as excluding all benchmark files; it excludes hidden files under `benchmarks/` only. Inspect the built archive manifest for private inputs, credentials, giant solutions, and unsupported scratch artifacts.

**Archive build/check pattern** (`tools/ci/summarize-r-cmd-check.R`, lines 183-193):

```r
buildStatus = system2(r, c("CMD", "build", shQuote(sourceCopy)),
                      stdout = buildLog, stderr = buildLog)
writeLines(as.character(buildStatus), file.path(artifacts, "build-exit-status.txt"))
if (identical(buildStatus, 0L)) {
  checkStatus = system2(r, c("CMD", "check", paste0("--library=", shQuote(library)),
                            paste0("--output=", shQuote(artifacts)), shQuote(archive)),
                        stdout = rawLog, stderr = rawLog)
  writeLines(as.character(checkStatus), file.path(artifacts, "check-exit-status.txt"))
}
```

The source-copy helper separately uses `git ls-files` and excludes planning, tool-state, generated binary, and local-state paths (`summarize-r-cmd-check.R`, lines 109-131). This helper already checks the built tarball but its workflow labels the current representative check informational/non-required. Make CI-02's release qualification explicit; do not infer a clean release from an informational baseline or hide current warnings/notes.

### `README.md`, `MIGRATION.md`, `NEWS.md`, and `inst/CITATION` (documentation / metadata)

**Analogs:** the files themselves

Keep README as the concise installation/current-workflow entry point. It already documents the package identity, migration link, Matrix boundary, sparse workflow, and benchmark command (`README.md`, lines 38-77, 169-214, 255-270). The migration document is authoritative for exact predecessor replacements and saved-state conversion; link to it instead of duplicating the full procedure.

`NEWS.md` uses a version heading followed by categorized change prose and explicit release-boundary wording (`NEWS.md`, lines 1-27). `inst/CITATION` derives the package title, author, and version from `meta`, cites the upstream baseline separately, and ends with the release boundary (`inst/CITATION`, lines 1-37). Preserve metadata-driven fields and reviewed attribution evidence keys when updating citation/provenance text.

### `docs/architecture.md` and `CONTRIBUTING.md` (documentation)

**Closest material:** `R/apiDocumentation.R`, `GOVERNANCE.md`, `.github/workflows/native-ci.yaml`

There is no existing architecture or contributor guide. For architecture, derive subsystem boundaries from package help and the actual `R/`, `src/`, and `inst/` ownership; use the CI workflow to describe native serial/OpenMP and platform variation. Include numerical acceptance gates, solver/backend boundaries, and the private-input rule from `docs/provenance/RIGHTS.md` lines 79-85. For contribution steps, `GOVERNANCE.md` lines 27-31 states pull requests, protected `main`, required CI, and review; do not mistake `CONTRIBUTORS.md` for a contributor process guide (it records attribution only).

### `docs/release/VERSION-LIFECYCLE.md`, `docs/release/RELEASE-CHECKLIST.md`, and `docs/release/RELEASE-GATES.md` (documentation, batch)

**Analog:** `docs/release/RELEASE-GATES.md`

Reuse the gate document's fail-closed structure: canonical status, gate/evidence/predicate/blocker table, command contracts, and a clear separation between technical readiness and external authorization (`RELEASE-GATES.md`, lines 3-19 and 21-34). Keep version/lifecycle policy explicit about pre-1.0 compatibility choices; current package metadata does not establish a SemVer promise. Checklist items should point to executable checks and evidence files rather than copy their implementation details. Maintain repository-only release/provenance detail outside pkgdown navigation.

**Release-boundary wording pattern** (`docs/release/RELEASE-GATES.md`, lines 64-71):

```markdown
A fresh release-kind name report is required before a blocker-free root can be
release-ready. Even a technically ready result does not create, reserve, change,
or publish a repository: every such action requires its separate human
authorization.

Diagnostics report stable field names and reason codes only. Evidence contents,
credentials, private correspondence, and proprietary model data are never
printed.
```

Keep the blocker status synchronized with `DESCRIPTION`, `NEWS.md`, `inst/CITATION`, and `docs/provenance/RIGHTS.md`; a successful archive check does not clear legal or attribution gates.

### `benchmarks/GTAP12A_CPP_RESULTS.md` (documentation, batch)

**Analog:** existing results summary and external runner

The results document leads with date, package/environment, hardware, model scale, and run configuration; it separates full-run results from one-step gates and identifies external inputs (`GTAP12A_CPP_RESULTS.md`, lines 3-13, 15-27, 55-58). Keep only the checked summary and required provenance in the repository. Current runner/checker use MD5 fingerprints as change-detection bindings; call them fingerprints, not authenticated signatures.

## Shared Patterns

### Public API and example behavior

**Source:** `R/apiDocumentation.R` and `README.md`  
**Apply to:** all five vignettes and site API links

Treat package help as the API source of truth. The supported flow is `GEModel$new()` → `loadTablo()` → `loadData()` → `setClosure()` / `setShocks()` → `solveModel()` → inspect results/diagnostics. Examples use exact public option names and demonstrate unavailable capabilities as explicit failures rather than silent backend changes.

### Small redistributable fixtures

**Source:** `tests/testthat/fixtures/three-region.tab`, its `PROVENANCE.md`, and `tests/testthat/helper-three-region.R`  
**Apply to:** runnable vignettes, source archives, and site builds

Keep ordinary examples deterministic and small. Record fixture origin, redistribution basis, scope, and checksum/provenance. A test-only path is not an installed-package fixture; install the asset under `inst/` or generate it in a shared vignette helper.

### External benchmark and evidence boundary

**Source:** `benchmarks/run_gtap12a_ab.R`, `benchmarks/check_benchmark_gate.R`, `benchmarks/GTAP12A_CPP_RESULTS.md`, and `docs/provenance/RIGHTS.md`  
**Apply to:** benchmark vignette, results updates, archive/site artifact checks

Reuse the existing runner and checker; preserve solve time, peak RSS, maximum full residual, solution/output finiteness, and no-dense-fallback checks. Keep GTAP inputs and oversized solution outputs external. Report hardware/runtime and package/model fingerprints without calling MD5 an authenticated signature.

### Fail-closed release wording

**Source:** `docs/release/RELEASE-GATES.md` and `inst/CITATION`  
**Apply to:** release policy/checklist, NEWS, citation/provenance text, site build decisions

Distinguish source-package qualification from legal, attribution, repository, and publication authorization. Keep the current intentional blockers accurate and never imply that a successful build, check, or site render grants publication clearance.

### Generated and repository-only outputs

**Source:** `.Rbuildignore`, `tools/ci/summarize-r-cmd-check.R`, and `docs/release/REPOSITORY.md`  
**Apply to:** pkgdown output, archive inspection, CI artifacts

Build into an isolated generated directory; never let pkgdown clean `docs/release` or `docs/provenance`. Inspect both the built source archive and site/CI artifacts against the private-input boundary. Keep check/build scratch artifacts outside the source checkout.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `_pkgdown.yml` | config | transform | No site configuration currently exists; use package help, README, and the research recommendations. |
| `docs/architecture.md` | documentation | transform | No existing architecture guide; derive it from current R/native sources and CI. |
| `tools/ci/check-source-archive.R` (if standalone) | utility | batch | No archive-content allowlist checker exists; the current check helper is the closest build/check analog. |

## Metadata

**Analog search scope:** `README.md`, `MIGRATION.md`, `DESCRIPTION`, `NAMESPACE`, `R/`, `man/`, `inst/`, `tests/testthat/`, `docs/`, `benchmarks/`, `tools/ci/`, and `.github/workflows/`  
**Files scanned:** 25 directly relevant existing files, plus directory/file-name discovery  
**Pattern extraction date:** 2026-10-05
