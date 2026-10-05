# Phase 02: Compatibility and Numerical Baseline - Research

**Researched:** 2026-09-02
**Domain:** R reference-class compatibility, sparse numerical validation, transactional model state, portable serialization, and reproducible baselines
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

<!-- DATA_X7K2P9Q4_START -->
### Locked Decisions

### Compatibility boundary

- **D-01:** Freeze an explicit supported contract covering the documented workflow and an enumerated set of GEModel methods, fields, arguments, defaults, outputs, and serialization behavior.
- **D-02:** Classify the observed surface into `supported`, `compatibility-only`, and `internal`. Compatibility-only behavior remains tested but may later follow a documented deprecation path.
- **D-03:** Guarantee both closure/shock workflows. Preserve the `variableValues` workflow exactly while making `setClosure()` and `setShocks()` the preferred documented workflow.
- **D-04:** Freeze full output structure: names, classes, dimensions, ordering, compact/full selection behavior, and missing/zero conventions. Compare numeric values under the separate numerical tolerance policy.

### Numerical authority

- **D-05:** Use sparse-first layered authority. Matrix sparse is the reference for generic sparse solves; structured R is the reference for structured C++ solves. Legacy is only a small-fixture public-workflow compatibility smoke path, not a numerical oracle.
- **D-06:** Every accepted backend result must independently pass a full-system true-residual gate.
- **D-07:** Use fixture/conditioning tolerance tiers: one strict default for ordinary redistributable fixtures and explicit, justified exceptions for ill-conditioned cases. Tolerances must not be loosened merely because a backend is C++.
- **D-08:** Backend equivalence requires exact structural output parity, finite values, absolute-plus-relative solution comparison, and independently recomputed true residuals.
- **D-09:** Fixtures declare required and optional backends. Required paths must execute; unavailable optional C++ or OpenMP paths must emit explicit, tested skip reasons rather than silently passing.

### Fixture and artifact portfolio

- **D-10:** Use a layered fixture portfolio: tiny algebraic systems for exact edge cases, a redistributable synthetic three-region TABLO workflow, SmallAg/debug only after redistribution is verified, and fingerprinted external reduced/full GTAP benchmarks.
- **D-11:** Commit compact, transparent artifacts: fixture fingerprints, solver metadata, structural expectations, selected canonical output values, and tolerances in reviewable text or CSV formats. Regenerate full solutions during tests; do not commit opaque complete solved-model snapshots as numerical goldens.
- **D-12:** Baseline changes require an explicit reviewed refresh. A deterministic command must generate proposed old/new artifacts and a readable diff; tests never rewrite canonical baselines automatically. Acceptance records the reason and reviewer.
- **D-13:** Tiny and synthetic three-region fixtures gate ordinary package checks. Redistributable SmallAg may gate extended checks after clearance. Reduced/full GTAP remain external benchmark and release gates.

### Failure and state semantics

- **D-14:** Compilation, factorization, convergence, finiteness, or residual failure is transactional. Caller-visible closure, shocks, levels, applied-shock progress, prior successful outputs, and caches remain unchanged; only structured failure diagnostics may be recorded.
- **D-15:** If the numerical solve is accepted but requested post-simulation processing fails, preserve the valid solved levels and diagnostics, mark post-simulation output failed/incomplete, and support retrying post-simulation without solving again. Never expose partial post-simulation updates.
- **D-16:** Serialization preserves portable logical state: source/model identity, loaded mutable levels, closure, shocks, accepted solution/output state, and diagnostics. Native pointers, factors, caches, and workspaces are excluded and rebuilt lazily.
- **D-17:** Characterize current consecutive-solve and shock-consumption behavior, then require `variableValues` and `setShocks()` to follow one explicitly documented application rule. Repair unintended divergence before accepting the baseline rather than preserving backend-specific behavior.

### the agent's Discretion

- Choose the exact compatibility-manifest schema and test organization while preserving the three contract tiers.
- Derive strict default and documented ill-conditioned tolerances from existing evidence and characterization; current `1e-8` synthetic and `2e-7` full-GTAP gates are starting evidence, not automatic final values.
- Choose reviewable baseline file formats, fingerprint algorithms, and deterministic refresh tooling.
- Choose a portable serialization implementation and an efficient transactional-state mechanism that does not violate the sparse-path memory constraint.

### Deferred Ideas (OUT OF SCOPE)

- Package/native identity migration remains Phase 3.
- Public API narrowing and backend interface cleanup remain Phase 4.
- Cross-platform native build and CI remain Phase 5.
- Signed full-scale benchmark qualification and public release artifacts remain Phases 6 and 7.
<!-- DATA_X7K2P9Q4_END -->
</user_constraints>

## Summary

Phase 2 should freeze behavior before changing identity or narrowing exports. The current checkout already has strong sparse compiler, solver, native-kernel, residual, and benchmark scaffolding, and the focused public/sparse/native tests passed locally on 2026-09-02. [VERIFIED: local `testthat::test_local` runs for `public-solver-contract`, `public-cpp-backend`, `sparse-core`, and `sparse-cpp-cache`] The missing work is contract completeness: the namespace is broad by pattern, the model surface is not enumerated in a durable manifest, output structure and consecutive-solve semantics are only partially characterized, and the existing serialization test checks pointer absence rather than a portable logical round trip. [VERIFIED: NAMESPACE:1-6; R/GEModel.R:9-36; tests/testthat/test-sparse-cpp-cache.R:42-51]

The most important numerical gap is that full true residuals are mandatory only for structured backends, diagnostics runs, or an option-enabled generic solve; Matrix and SparseM results can otherwise be applied without an acceptance threshold. [VERIFIED: R/sparseSolver.R:1826-1908] The most important state gap is that sparse Euler substeps mutate the live state and `model$sparseIndex` before the full solve completes, while post-simulation updates run on the same state before outputs are committed. [VERIFIED: R/sparseSolver.R:1934-2145] The planner should therefore centralize a backend-neutral acceptance result first, then put both legacy and sparse execution behind a two-phase commit, with post-simulation as a separate retryable transaction.

Baseline artifacts should reuse the repository's deterministic metadata helpers but remain plain text/CSV. The benchmark harness already fingerprints files, object signatures, package trees, model configuration, package versions, platform, CPU, RAM, and BLAS metadata. [VERIFIED: benchmarks/benchmark_config.R:30-48,79-132; benchmarks/benchmark_gtap12a_run.R:61-103] Canonical baselines must exclude full solution RDS files and must never be refreshed by tests, matching the locked artifact policy.

**Primary recommendation:** Build one manifest-driven characterization harness around a committed synthetic three-region fixture, then make every backend return an uncommitted candidate that passes structure, finiteness, absolute-plus-relative equivalence, and independently recomputed true-residual gates before state commit.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Public `GEModel` contract and serialization entry points | R package API | Test contract | `GEModel` owns public fields, methods, defaults, and caller-visible state. [VERIFIED: R/GEModel.R:9-36,37-467] |
| TABLO fixture compilation and model identity | Compiler/runtime | Baseline tooling | `loadTablo()` builds both legacy and sparse representations from one TABLO source. [VERIFIED: R/GEModel.R:39-71] |
| Generic sparse numerical authority | Sparse solver | Matrix package | `solve_sparse_system()` dispatches generic Matrix, SuiteSparse, and SparseM paths. [VERIFIED: R/sparseSolver.R:1219-1292] |
| Structured native numerical authority | Structured R solver | C++ kernels | The C++ wrapper routes through the R structured algorithm and changes only the implementation path. [VERIFIED: R/zzzSparseSchurCpp.R:503-527,558-618] |
| Candidate acceptance and true residual | Sparse solver boundary | Test oracle | Residuals use the full sparse coefficient matrix and RHS before updates. [VERIFIED: R/sparseSolver.R:1294-1319,1826-1908] |
| Transactional mutation | Model orchestration | Sparse state environment | The orchestration layer owns when working levels, shocks, outputs, diagnostics, and caches become caller-visible. [VERIFIED: R/sparseSolver.R:1934-2145] |
| Baseline generation and reviewed refresh | Maintainer tooling | Tests | Existing benchmark helpers already provide most fingerprint and metadata primitives. [VERIFIED: benchmarks/benchmark_config.R:30-48,79-132] |

## Phase Requirements

<phase_requirements>

| ID | Description | Research Support |
|---|---|---|
| COMP-01 | Existing users can perform the documented `GEModel$new()`, `loadTablo()`, `loadData()`, closure/shock, `solveModel()`, and output workflow under GEModelR. | Characterize README legacy and sparse workflows with both shock APIs on redistributable fixtures; keep legacy as compatibility smoke only. [VERIFIED: README.md:44-169; .planning/REQUIREMENTS.md:19-22] |
| COMP-02 | Omitted engine/backend arguments preserve the legacy engine and Matrix sparse backend defaults already protected by tests. | Manifest and formals tests must freeze `engine = c("legacy", "sparse")` and `backend = "Matrix"`, plus omitted-vs-explicit execution parity. [VERIFIED: R/GEModel.R:72-75,233-249; tests/testthat/test-public-solver-contract.R:1-17] |
| COMP-03 | Supported model fields, method signatures, closure/shock semantics, output names, compact/full output behavior, and serialization behavior are documented and regression-tested. | Add complete manifest coverage, structural output snapshots in CSV/text, shock/consecutive-solve characterization, and a versioned logical serialization round trip. [VERIFIED: R/GEModel.R:9-36,37-467; R/sparseSolver.R:90-184,1661-1697,1934-2145] |
| NUM-01 | Legacy, Matrix sparse, structured R, and optional structured C++ paths satisfy documented solution-equivalence and true-residual tolerances on redistributable fixtures. | Use Matrix as generic reference, structured R as C++ reference, exact structure checks, finite checks, absolute-plus-relative comparison, and explicit optional skip reasons. [VERIFIED: tests/testthat/test-sparse-core.R:370-452,752-773; tests/testthat/test-public-cpp-backend.R:1-39] |
| NUM-02 | Solver results are applied to mutable model state only after the selected backend passes its required residual and finiteness checks. | Introduce candidate/accept/commit separation and fault-injection tests at compilation, factorization, solve, residual, update, and post-simulation boundaries. [VERIFIED: R/sparseSolver.R:1826-2145] |

</phase_requirements>

## Project Constraints (from AGENTS.md)

- Run package commands from the repository root; required validation includes `rtk R CMD check .`, and affected behavior must also be exercised through a representative `GEModel$new()`, `loadTablo()`, `loadData()`, and `solveModel()` workflow. [VERIFIED: AGENTS.md:12-24]
- Use two-space indentation, base-R style with `=` assignment in implementation, short focused functions, explicit character/numeric handling, `camelCase` public methods, descriptive filenames, and `PascalCase` class-like objects; do not introduce unrelated reformatting. [VERIFIED: AGENTS.md:26-30]
- Add small deterministic regression fixtures under `tests/testthat/`; do not commit proprietary or oversized `.tab`/`.har` inputs. [VERIFIED: AGENTS.md:32-35]
- Keep commits focused with short present-tense subjects; PR evidence must state behavior, validation, and a minimal reproducible model/data description. [VERIFIED: AGENTS.md:37-40]
- Do not commit `.RData`, `.Rhistory`, `.Rproj.user/`, package archives, `*.Rcheck/`, credentials, private model inputs, or generated solver results. [VERIFIED: AGENTS.md:42-45]
- Preserve unrelated and untracked files. The working tree contained an unrelated untracked `.gsd/` directory at research time. [VERIFIED: local `git status --short` 2026-09-02]

## Exact Current Contract Inventory

### GEModel fields and declared methods

The class currently declares 24 typed fields. The manifest must include every field, its type, initial empty-state behavior, mutability, tier, serialization disposition, and whether it is derived or portable. [VERIFIED: R/GEModel.R:9-36]

<!-- DATA_M4R8T2V6_START -->
```text
shocks = "numeric"
skeletonGenerator = 'function'
sparseSkeletonGenerator = 'function'
equationCoefficientMatrixGenerator = 'function'
equationCoefficientGenerator = 'function'
generateVariables = 'function'
generateUpdates = 'function'
data = 'list'
solution = 'numeric'
changeVariables = 'character'
variables = 'character'
basicChangeVariables = 'character'
variableValues = 'list'
tabloStatements = 'list'
sparseSpec = 'list'
sparseIndex = 'list'
sparseState = 'environment'
loadedEngine = 'character'
closure = 'character'
explicitShocks = 'list'
sourceData = 'list'
memoryBudget = 'numeric'
lastDiagnostics = 'list'
compactOutput = 'list'
```
<!-- DATA_M4R8T2V6_END -->

The class directly defines `loadTablo`, `loadData`, `setShocks`, `setClosure`, `setMemoryBudget`, `estimateMemory`, `generateSolution`, and `solveModel`; inherited reference-class utility methods should be represented separately so they are not accidentally promised as package APIs. [VERIFIED: R/GEModel.R:37-467; local `GEModel$methods()` introspection 2026-09-02]

### Signatures and defaults to freeze

<!-- DATA_B9N3C7L5_START -->
```r
loadData = function(inputData, engine = c("legacy", "sparse"))
estimateMemory = function(engine = c("legacy", "sparse"), postsim = TRUE)
solveModel = function(iter = 3, steps = c(1,3),
                      engine = c("legacy", "sparse"),
                      postsim = TRUE, diagnostics = FALSE,
                      output = c("full", "compact"),
                      variables = NULL, dimensions = NULL,
                      backend = "Matrix",
                      reduction = c("auto", "off", "on"),
                      memory_budget = NULL)
```
<!-- DATA_B9N3C7L5_END -->

These defaults are the source-level contract; tests should compare `formals()` to canonical deparsed values rather than relying only on behavior. [VERIFIED: R/GEModel.R:72-75,123-149,233-249]

### Backend values to characterize

<!-- DATA_H2D8S5W1_START -->
```r
backend = match.arg(backend, c(
  "Matrix", "SuiteSparse", "SparseM", "StructuredSchur", "StructuredSchurFGMRES"
))

if (!identical(backend, "StructuredSchurFGMRESCpp")) {
```
<!-- DATA_H2D8S5W1_END -->

The public backend matrix therefore consists of generic `Matrix`, `SuiteSparse`, and `SparseM`; structured R `StructuredSchur` and `StructuredSchurFGMRES`; and the wrapper-only native `StructuredSchurFGMRESCpp`. [VERIFIED: R/sparseSolver.R:1951-1953; R/zzzSparseSchurCpp.R:558-588]

### Namespace seam

<!-- DATA_P6F1J8A3_START -->
```text
exportPattern("^[[:alpha:]]+")
```
<!-- DATA_P6F1J8A3_END -->

Because all alphabetic symbols are exported by pattern, Phase 2 must inventory the observed namespace and assign each symbol one of the three locked tiers without narrowing it; narrowing remains Phase 4. [VERIFIED: NAMESPACE:1-6; 02-CONTEXT.md D-02]

## Characterization Seams and Gaps

| Seam | Existing reusable evidence | Missing characterization required in Phase 2 |
|---|---|---|
| Documented legacy workflow | README shows constructor, TABLO/data load, direct `variableValues`, solve, and `data` output. [VERIFIED: README.md:44-133] | Run a redistributable equivalent and freeze field/state transitions, return invisibility, output classes/names/dimensions, and repeated-solve behavior. |
| Preferred sparse workflow | README shows `setClosure()`, sparse `loadData()`, `setShocks()`, compact output, diagnostics, and memory budget. [VERIFIED: README.md:134-171] | Freeze omitted/explicit defaults, full/compact structural outputs, selected dimensions, `postsim` branches, and zero/missing conventions. |
| Shock APIs | Explicit shocks are normalized; zeros/NA/empty labels are dropped; duplicate labels are summed. [VERIFIED: R/sparseSolver.R:120-147] | Test direct `variableValues` assignment and `setShocks()` against one application rule, including zero shocks, duplicate labels, indexed labels, and two consecutive solves. |
| Sparse `variableValues` | Sparse `loadData()` resets `variableValues` to `list()`, then fallback resolution reads explicitly assigned entries or sparse state. [VERIFIED: R/GEModel.R:86-105; R/sparseSolver.R:386-443] | Characterize assignment after load. A local run showed assigning a complete `variableValues$a` array works, while subassigning `variableValues$a[]` when the element is absent has no effect. [VERIFIED: local characterization run 2026-09-02] |
| Missing/zero convention | Missing exogenous values are converted to zero; missing endogenous values remain missing; zero shocks remain implicit. [VERIFIED: R/sparseCompiler.R:740-749; tests/testthat/test-sparse-core.R:53-100,189-228] | Put these exact conventions in the manifest and test both scalar and indexed cases. |
| Generic numerical reference | Matrix is the default and sparse-core tests cover direct solves and Matrix-vs-legacy smoke parity. [VERIFIED: R/sparseSolver.R:1219-1271; tests/testthat/test-sparse-core.R:230-260,370-394] | Recompute and threshold true residual for every generic backend even when diagnostics are off. |
| Structured R/C++ pair | Existing public C++ test compares structured C++ to structured R and checks finite residual metadata/no pointers. [VERIFIED: tests/testthat/test-public-cpp-backend.R:1-39] | Use a committed fixture rather than only a temporary helper and mocked partition; require exact structure plus abs/rel value gates. |
| Optional paths | SuiteSparse and OpenMP tests currently skip when unavailable. [VERIFIED: tests/testthat/test-sparse-core.R:262-276; tests/testthat/test-sparse-schur-openmp.R:1-4] | Give each optional fixture/backend an explicit required/optional declaration and assert the exact skip reason. The current OpenMP skip has no message. [VERIFIED: tests/testthat/test-sparse-schur-openmp.R:1-4] |
| Output structure | Full output names the solution and may materialize labels; compact output may include selected arrays and an unnamed solution; `postsim = FALSE` empties `model$data`. [VERIFIED: R/sparseSolver.R:1661-1697,2103-2125] | Freeze list names, array classes, dimensions, dimnames, order, solution naming, compact selection, empty-data behavior, and stale-output clearing. |
| Failure mutation | Native preflight failure already proves state unchanged before solving. [VERIFIED: tests/testthat/test-public-solver-contract.R:19-37] | Inject failures after one accepted substep, at residual rejection, simulation update, post-update, and output projection for all caller-visible fields. |
| Serialization | Current test confirms no external pointer in restored sparse state/diagnostics. [VERIFIED: tests/testthat/test-sparse-cpp-cache.R:42-51] | Round-trip every portable field, solve again, verify cache rebuild, reject incompatible schema, and document raw-object serialization as compatibility-only. |
| Baseline metadata | Benchmark helpers already record model/package signatures and environment details. [VERIFIED: benchmarks/benchmark_gtap12a_run.R:61-103] | Add compact canonical artifacts, fixture/source fingerprints, explicit tolerance tier, acceptance metadata, and deterministic old/new proposal output. |

## Standard Stack

### Core

No dependency upgrade should be coupled to this phase; use the package's existing dependency set and record exact runtime versions in every generated baseline. [VERIFIED: DESCRIPTION:21-30]

| Library/runtime | Planning baseline | Purpose | Why standard here |
|---|---:|---|---|
| R | 4.3.0 installed | Package runtime, reference classes, serialization, test execution | This is the verified local characterization environment; artifacts must record rather than assume it. [VERIFIED: local `R.version.string` 2026-09-02] |
| Matrix | 1.6-3 installed; CRAN 1.7-6 published 2026-07-25 | Generic sparse reference, sparse LU, sparse matrix-vector residual | It is already imported and is the locked generic numerical authority. [VERIFIED: DESCRIPTION:21-25] [CITED: https://cran.r-project.org/web/packages/Matrix/index.html] |
| testthat | 3.3.2 installed; edition 3 | Contract, fault-injection, backend, skip, and artifact tests | The repository already configures edition 3 and uses its mocking/skip facilities. [VERIFIED: DESCRIPTION:28-30; local `packageVersion` 2026-09-02] [CITED: https://testthat.r-lib.org/reference/skip.html] |
| Rcpp | 1.1.1-1.1 installed; CRAN 1.1.2 published 2026-07-05 | Existing native backend bridge | Already imported/linked; no new native interface is needed for baseline work. [VERIFIED: DESCRIPTION:21-27; local `sessionInfo()` 2026-09-02] [CITED: https://stat.ethz.ch/CRAN/web/packages/Rcpp/index.html] |
| SparseM | 1.81 installed; CRAN 1.84-2 published 2024-07-17 | Existing compatibility comparison backend | Already imported and selectable; it is not a numerical authority. [VERIFIED: DESCRIPTION:21-25; local `packageVersion` 2026-09-02] [CITED: https://stat.ethz.ch/CRAN/web/packages/SparseM/SparseM.pdf] |

### Supporting base facilities

| Facility | Purpose | When to use |
|---|---|---|
| `tools::md5sum()` | Deterministic content fingerprint for files | Use for change detection and fixture/source identity, clearly not as an authority or signature. Existing benchmark tooling already uses it. [VERIFIED: benchmarks/benchmark_config.R:30-48,123-132] [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-devel/packages/tools/refman/tools.html] |
| `utils::sessionInfo()`, `packageVersion()`, `packageDescription()` | Platform, BLAS/LAPACK, locale, R, and dependency metadata | Capture in generated proposal/run metadata, not in structural expected-output comparisons. [CITED: https://www.stat.ethz.ch/R-manual/R-devel/library/utils/html/sessionInfo.html] [CITED: https://stat.ethz.ch/R-manual/R-devel/library/utils/html/packageDescription.html] |
| `saveRDS(..., version = 3L)` | Transport for an explicit plain-list portable payload | Use outside canonical baselines; do not serialize the raw reference object as the supported long-term format. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRDS.html] |
| Reference-class `$copy()` | Isolated legacy working object | Deep-copy only the legacy compatibility path; shallow copies share reference fields and are unsafe for sparse mutation. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/methods/html/refClass.html] |

### Alternatives considered

| Instead of | Could use | Tradeoff |
|---|---|---|
| Plain CSV/DCF artifacts | testthat snapshot files | Snapshot update workflows make accidental acceptance easier and do not naturally record reviewer/reason; use explicit proposal/accept tooling instead. |
| Existing `tools::md5sum()` | New digest/crypto package | A new dependency is unnecessary for deterministic change detection and would expand Phase 2 scope. |
| Versioned logical payload | Raw `serialize(model)` | Raw serialization includes reference environments/functions, is large even for tiny models, and R documents that the serialization format is not for long-term storage. A local tiny-model raw round trip was about 3 MB. [VERIFIED: local characterization run 2026-09-02] [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/serialize.html] |
| Copy-on-write sparse working state | Full deep copy of the model | Full duplication conflicts with the locked sparse-memory constraint; isolate only changed arrays and derived caches. |

**Installation:** none. Phase 2 should not add or update packages.

## Package Legitimacy Audit

Not applicable: the recommended implementation installs no external package and uses only existing Imports/Suggests plus base/recommended R facilities. [VERIFIED: DESCRIPTION:21-30]

## Architecture Patterns

### System Architecture Diagram

```text
TABLO + input data + closure/shocks
              |
              v
       Compile/load model state
              |
              v
      Build isolated working state
              |
              v
   Emit full sparse system A and rhs
              |
              +-----------------------------+
              |                             |
              v                             v
  Generic: Matrix reference         Structured: R reference
  SuiteSparse/SparseM candidate      C++ candidate (optional)
              |                             |
              +-------------+---------------+
                            v
                 Candidate acceptance gate
                 - exact structure contract
                 - finite solution/output
                 - abs + relative comparison
                 - independent true residual
                            |
                 +----------+----------+
                 | pass                | fail
                 v                     v
        Commit solved logical state   Preserve public state;
                 |                    record failure only
                 v
       Isolated post-simulation pass
                 |
          +------+------+
          | pass        | fail
          v             v
  Commit outputs    Keep solved state;
                    mark retryable post failure
```

### Recommended project structure

```text
R/
├── compatibilityBaseline.R      # manifest readers, structural comparison, metadata
├── modelSerialization.R         # versioned logical payload and restore
├── GEModel.R                    # public methods/fields and legacy transaction boundary
└── sparseSolver.R               # candidate, acceptance gate, sparse transaction
inst/compatibility/
└── GEModel-contract.csv         # complete supported/compatibility-only/internal manifest
tests/testthat/
├── fixtures/
│   ├── three-region.tab         # committed synthetic workflow
│   └── PROVENANCE.md            # origin, license/basis, purpose, fingerprint scope
├── baselines/phase02/
│   ├── expectations.csv         # structural and selected canonical values
│   ├── tolerances.csv           # fixture conditioning tiers
│   ├── fingerprints.dcf         # fixture/source identities and schema
│   └── ACCEPTANCE.md            # reviewer, reason, accepted proposal hash
├── helper-compatibility.R
├── test-compatibility-manifest.R
├── test-documented-workflow.R
├── test-numerical-baseline.R
├── test-transactional-state.R
├── test-model-serialization.R
└── test-baseline-artifacts.R
tools/
└── refresh_phase02_baselines.R  # proposal + readable old/new diff; never auto-accepts
```

These are recommended new seams, not a package rename or export cleanup. Keep functions focused and preserve the existing public camelCase/sparse-internal naming split. [VERIFIED: AGENTS.md:26-30; .planning/codebase/CONVENTIONS.md:7-35]

### Pattern 1: Manifest completeness before behavioral assertions

Generate observed exports and class members at test time, then require every observed item to have exactly one manifest row and tier. Separately assert exact signatures/defaults only for supported and compatibility-only methods. This prevents the broad namespace from silently gaining an unclassified symbol while respecting the Phase 4 scope boundary. [VERIFIED: NAMESPACE:1-6; 02-CONTEXT.md D-02]

### Pattern 2: Candidate → validate → commit

Numerical code should return a candidate containing the unpermuted solution, emitted sparse system/RHS or a residual callback, backend metadata, structural output descriptor, and working state. The acceptance function validates the candidate without touching `GEModel`; only its successful return can reach the commit function.

The true-residual calculation can remain sparse:

```r
residual = as.numeric(A %*% solution) - as.numeric(rhs)
relative_l2 = sqrt(sum(residual * residual)) /
  max(1, sqrt(sum(as.numeric(rhs)^2)))
```

This follows the existing implementation and Matrix's sparse multiplication behavior. [VERIFIED: R/sparseSolver.R:1294-1319] [CITED: https://stat.ethz.ch/CRAN/web/packages/Matrix/refman/Matrix.html]

### Pattern 3: Sparse-safe transactional state

Use two mechanisms:

1. Run the legacy engine on an isolated deep reference-class copy and commit only portable/public fields after success. Legacy is already the dense compatibility path. [VERIFIED: R/GEModel.R:233-467]
2. Run sparse solves in a new working environment whose `data` list initially shares immutable vectors with the committed state. R copy-on-modify then duplicates arrays as they are changed; keep the working solver cache private and swap the accepted environment into the model only at commit. Reference-class shallow copy alone is insufficient because nested reference fields remain shared. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/methods/html/refClass.html]

The existing `sparse_checkpoint_state()` remains useful inside Euler extrapolation, but it is not the outer transaction because it only saves variable/update targets and restores the live state. [VERIFIED: R/sparseSolver.R:1499-1521,2019-2093]

### Pattern 4: Split numerical commit from post-simulation commit

After the last candidate passes, commit solved levels, accepted solution, and numerical diagnostics. Run `post_updates` on another working state. On post failure, retain the accepted solve, retain the previous complete output object, record an explicit incomplete/retryable status, and expose a manifest-listed retry operation that reruns only post-simulation processing. The current code instead applies post updates before assigning public solution/output fields. [VERIFIED: R/sparseSolver.R:2094-2145]

### Pattern 5: Versioned logical serialization payload

Use a plain list with a schema identifier/version, source identity/fingerprint and reconstructable TABLO source, loaded engine, mutable levels, closure, normalized shocks, accepted solution/output, memory budget, and diagnostics. On restore, validate schema and fingerprints, reconstruct `GEModel`, compiler functions/index, and an empty cache, then install logical state. Exclude function fields, native pointers, factors, cache/workspace environments, and transient applied-shock progress.

Raw `saveRDS(model)` should be classified compatibility-only for same-version best-effort use; the supported format should be the explicit payload. R supports `saveRDS` transport for one object but warns that serialization formats may change, and reference classes use environment semantics. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRDS.html] [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/serialize.html] [CITED: https://stat.ethz.ch/R-manual/R-devel/library/methods/html/refClass.html]

### Pattern 6: Proposal-only baseline refresh

`rtk Rscript --vanilla tools/refresh_phase02_baselines.R --output=<proposal-dir>` should regenerate full solutions in memory, emit only compact CSV/DCF/text artifacts, and write a key-based old/new comparison. It must fail if canonical files are named as output. A separate explicit acceptance action should require reviewer and reason and update `ACCEPTANCE.md`; ordinary tests remain read-only.

### Anti-patterns to avoid

- **Backend-specific acceptance logic:** one backend can bypass a gate or report a different residual definition.
- **Residual checks enabled only by diagnostics:** correctness cannot depend on observability settings. [VERIFIED: R/sparseSolver.R:1867-1871]
- **Mutating the live state and attempting broad rollback:** failures after several substeps can miss caches, outputs, or progress fields. [VERIFIED: R/sparseSolver.R:2019-2093]
- **Full deep copy on the sparse path:** it can double large mutable arrays and violate the product memory constraint.
- **Post-simulation inside numerical acceptance:** it destroys the locked retry-without-resolve semantics.
- **Opaque RDS numerical goldens:** they hide structure/value changes and are globally ignored by `.gitignore`. [VERIFIED: .gitignore:1-7]
- **Treating legacy as an oracle:** legacy is only a public-workflow smoke path by locked decision.
- **Silent optional skips:** capability absence must be visible and tested.

## Recommended Planning Sequence

1. **Freeze observed compatibility surface and characterization harness.** Create the manifest, enumerate exports/fields/methods/signatures/defaults, and add failing completeness tests before changing solver behavior.
2. **Create the redistributable fixture portfolio and proposal-only artifact tooling.** Add tiny edge cases, a committed synthetic three-region workflow, provenance metadata, fingerprint schema, tolerance tiers, and deterministic old/new output. Do not add SmallAg until its redistribution basis is reviewed.
3. **Centralize candidate acceptance.** Make all generic and structured backends return the same candidate shape; enforce finite values, exact output structure, abs-plus-rel equivalence, and independent full residual before any update.
4. **Add transactional solve and post-simulation isolation.** Cover legacy with isolated-copy commit, sparse with copy-on-write working state, fault injection, failure diagnostics, and retryable post-simulation.
5. **Add versioned portable serialization.** Define payload/restore, cache exclusion/rebuild, schema rejection, pre/post-solve round trips, and compatibility-only raw serialization.
6. **Close the full requirement matrix.** Execute both shock workflows, repeated solves, full/compact/postsim combinations, all required backends, optional skip paths, artifact drift checks, and package check.

This order prevents baselining behavior before its authority, mutation, and serialization semantics are coherent.

## Numerical Tolerance Policy

Use one committed row per fixture with `tier`, `solution_atol`, `solution_rtol`, `residual_rtol`, rationale, and reviewer. The comparator should require `abs(candidate - reference) <= atol + rtol * max(abs(reference), abs(candidate))` elementwise, after exact structural parity and finiteness checks.

Recommended initial ordinary-fixture policy is `solution_atol = 1e-10`, `solution_rtol = 1e-8`, and `residual_rtol = 1e-10`, subject to measurement on the new three-region fixture before acceptance. Existing deterministic native tests already use `1e-10` block/residual thresholds and `1e-8` solution comparisons; the current public structured fixture produced zero R/C++ difference and zero residual locally. [VERIFIED: tests/testthat/test-sparse-schur-cpp.R:1-46,58-85; local structured R/C++ characterization run 2026-09-02]

Keep `2e-7` only as an explicitly named ill-conditioned full-GTAP/external tier until redistributable evidence justifies another exception; do not apply that loose gate to ordinary fixtures. [VERIFIED: README.md:196-202; benchmarks/check_benchmark_gate.R:9-15; benchmarks/GTAP12A_CPP_RESULTS.md:15-27]

Legacy comparisons should assert workflow/state/structure and a narrow smoke-value tolerance, but a legacy disagreement must not override Matrix or structured-R authority. That distinction should be encoded in fixture metadata, not left to test naming.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Sparse residual | Dense conversion or a second custom solver | Existing `sparse_true_residual()` pattern with Matrix sparse multiplication | It checks the actual full system without densifying. [VERIFIED: R/sparseSolver.R:1294-1319] |
| Generic reference solve | New decomposition | Matrix backend | Matrix is the locked generic numerical authority and current default. [VERIFIED: R/sparseSolver.R:1219-1264] |
| Structured native oracle | Dense full solve for production-sized models | Structured R path | The C++ wrapper already routes through the same structured algorithm while R remains the reference. [VERIFIED: R/zzzSparseSchurCpp.R:503-527,558-618] |
| Test capability skips | Ad hoc `if`/return | testthat `skip_if()`/`skip_if_not()` with explicit messages | Official skip conditions terminate with visible skip status. [CITED: https://testthat.r-lib.org/reference/skip.html] |
| Platform/dependency metadata | Shell-specific parsing | `sessionInfo()`, `packageVersion()`, `Sys.info()` | These are portable R APIs for the required metadata. [CITED: https://www.stat.ethz.ch/R-manual/R-devel/library/utils/html/sessionInfo.html] [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/Sys.info.html] |
| Content hashes | New cryptographic implementation | `tools::md5sum()` for change detection | Existing tooling uses it and official R documents it as a file checksum. [VERIFIED: benchmarks/benchmark_config.R:30-48] [CITED: https://stat.ethz.ch/CRAN/doc/manuals/r-devel/packages/tools/refman/tools.html] |
| Long-term model persistence | Raw reference-object serialization | Versioned plain-list payload over `saveRDS` | Raw serialization is environment-heavy and not a stable long-term schema. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/serialize.html] |

**Key insight:** The hard part is not solving again; it is making authority, acceptance, mutation, output, and persistence share one explicit contract.

## Common Pitfalls

### Pitfall 1: Diagnostics changes correctness

**What goes wrong:** Matrix/SparseM can apply a solution without any true-residual gate when diagnostics and the residual option are off. [VERIFIED: R/sparseSolver.R:1867-1908]

**How to avoid:** Compute acceptance residual unconditionally and make diagnostics control retention/reporting only.

**Warning sign:** A test passes with `diagnostics = TRUE` and fails to detect an injected bad solution with `diagnostics = FALSE`.

### Pitfall 2: Partial Euler state survives a later failure

**What goes wrong:** Each substep applies solution, shocks, and simulation updates to the live sparse environment; the checkpoint is per extrapolation branch, not per public call. [VERIFIED: R/sparseSolver.R:1826-1908,2019-2093]

**How to avoid:** Solve against an isolated working state and swap only after the entire accepted simulation.

**Warning sign:** `sparseState`, cache contents, or update targets differ after a deliberately injected failure on substep two.

### Pitfall 3: Post-simulation failure discards an expensive valid solve

**What goes wrong:** Current post updates occur before public result assignment, so an error prevents the accepted result from being published coherently. [VERIFIED: R/sparseSolver.R:2094-2145]

**How to avoid:** Commit numerical state first, run post updates transactionally, retain a retry token/status.

**Warning sign:** Retrying requires factorization or the caller sees partially updated reporting arrays.

### Pitfall 4: Shallow reference-class copies share sparse environments

**What goes wrong:** R reference-class assignment and shallow copy preserve shared reference fields. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/methods/html/refClass.html]

**How to avoid:** Construct a distinct sparse working environment and a separate cache; use deep copy only for legacy.

**Warning sign:** Mutating the candidate changes the original before commit.

### Pitfall 5: Output tests compare values but miss structure

**What goes wrong:** A backend can reorder names/dimnames, change array class/drop behavior, retain stale compact output, or alter missing/zero conventions while numeric vectors still compare equal. Current tests mostly compare numeric coercions. [VERIFIED: tests/testthat/test-sparse-core.R:278-314,370-452]

**How to avoid:** Compare names, class, type, dimensions, dimnames, ordering, missingness pattern, and zero convention exactly before numeric tolerance.

**Warning sign:** Tests call only `as.numeric()` on outputs.

### Pitfall 6: Raw serialization appears portable because a tiny round trip works

**What goes wrong:** Same-session round trips can restore function/reference environments while hiding version coupling and payload bloat. The current test does not solve the restored object. [VERIFIED: tests/testthat/test-sparse-cpp-cache.R:42-51]

**How to avoid:** Restore from a versioned logical payload in a fresh R process and solve again; require empty/rebuilt caches.

**Warning sign:** The only assertion is absence of `externalptr`.

### Pitfall 7: Baseline metadata is itself volatile or recursive

**What goes wrong:** Hashing a tree that contains the generated baseline changes the hash after every refresh; timestamps, elapsed time, absolute paths, CPU, and locale also make canonical equality platform-dependent.

**How to avoid:** Define explicit source scope excluding generated artifacts; keep volatile run metadata separate from canonical structural expectations.

**Warning sign:** Two clean runs create a diff with no model/code change.

### Pitfall 8: Unreviewed fixture provenance

**What goes wrong:** A useful SmallAg/debug dataset can still violate the project's public-data boundary. Repository search found no committed SmallAg/debug fixture or clearance record. [VERIFIED: repository-wide `rg` scan 2026-09-02]

**How to avoid:** Gate inclusion on a written redistribution basis; use newly authored tiny/three-region synthetic fixtures meanwhile.

**Warning sign:** Fixture origin is “copied from an example” without source, license/basis, author, and fingerprint scope.

### Pitfall 9: Baseline refresh happens during ordinary tests

**What goes wrong:** A regression overwrites the expected result and turns itself green.

**How to avoid:** Tests are read-only; proposal generation and acceptance are separate commands, with reviewer/reason and old/new hashes.

**Warning sign:** `UPDATE_SNAPSHOTS`-style environment state can modify canonical Phase 2 artifacts.

## Code Examples

### Structural-first comparison

```r
expect_identical(class(candidate), class(reference))
expect_identical(typeof(candidate), typeof(reference))
expect_identical(dim(candidate), dim(reference))
expect_identical(dimnames(candidate), dimnames(reference))
expect_identical(names(candidate), names(reference))
expect_identical(is.na(candidate), is.na(reference))
expect_true(all(is.finite(candidate[!is.na(candidate)])))

limit = solution_atol + solution_rtol *
  pmax(abs(reference), abs(candidate))
expect_true(all(abs(candidate - reference) <= limit))
```

This implements locked D-08 directly; tolerance values come from the fixture's reviewed row rather than backend identity.

### Explicit optional-backend skip

```r
capability = backend_capability(fixture, backend)
if (!capability$available) {
  testthat::skip(sprintf(
    "optional backend %s unavailable: %s",
    backend, capability$reason
  ))
}
```

The skip message should itself be tested in a capability-mocked test. Official testthat skip helpers preserve explicit skip outcomes. [CITED: https://testthat.r-lib.org/reference/skip.html]

### Reviewable fingerprint record

```r
files = sort(normalizePath(files, mustWork = TRUE))
fingerprints = data.frame(
  path = relative_paths,
  md5 = unname(tools::md5sum(files)),
  stringsAsFactors = FALSE
)
```

This reuses the current benchmark hashing mechanism. [VERIFIED: benchmarks/benchmark_config.R:30-48,123-132]

### Versioned serialization envelope

```r
payload = list(
  schema = "gemodel-logical-state",
  schema_version = 1L,
  source = source_identity,
  engine = model$loadedEngine,
  levels = committed_levels,
  closure = model$closure,
  shocks = model$explicitShocks,
  accepted = accepted_result,
  diagnostics = portable_diagnostics
)
saveRDS(payload, path, version = 3L)
```

The schema and field names above are recommended Phase 2 values, not current in-repo constants. `saveRDS` version 3 is the documented default/current format family for supported R versions. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRDS.html]

## State of the Art

| Existing approach | Phase 2 approach | Impact |
|---|---|---|
| Broad namespace export pattern [VERIFIED: NAMESPACE:1-6] | Complete tiered manifest without narrowing | Phase 3/4 can detect rename/API drift against a frozen surface. |
| Structured-only mandatory residual threshold [VERIFIED: R/sparseSolver.R:1867-1891] | Backend-neutral mandatory acceptance gate | NUM-02 becomes independent of backend and diagnostics mode. |
| Live sparse mutation with branch checkpoints [VERIFIED: R/sparseSolver.R:1499-1521,2019-2093] | Isolated working state and commit | Failures preserve all caller-visible state. |
| Post updates before public result commit [VERIFIED: R/sparseSolver.R:2094-2145] | Separate retryable post transaction | Valid expensive solves survive reporting failures. |
| Pointer-absence serialization test [VERIFIED: tests/testthat/test-sparse-cpp-cache.R:42-51] | Versioned logical payload and fresh-process solve-after-restore | Persistence becomes explicit and portable. |
| Full RDS solution files in external benchmark tooling [VERIFIED: benchmarks/benchmark_gtap12a_run.R:154-162] | Compact canonical CSV/DCF expectations; full solutions regenerated | Reviewable public baselines obey D-11. |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| — | No claims are tagged `[ASSUMED]`; unresolved choices are recorded below rather than presented as facts. | — | — |

## Open Questions (RESOLVED)

1. **Can a SmallAg/debug fixture be redistributed?**
   - What we know: No such fixture or clearance record was found in this checkout, and proprietary/private model inputs are forbidden. [VERIFIED: repository-wide `rg` scan 2026-09-02; AGENTS.md:42-45]
   - What's unclear: The provenance and license of any external candidate.
   - Resolution: SmallAg is excluded until its redistribution provenance is reviewed and recorded. The synthetic three-region fixture is the required ordinary-check substitute.

2. **What strict numbers should the three-region fixture lock?**
   - What we know: Current synthetic/native evidence supports `1e-8` solution and `1e-10` residual/block thresholds, while full GTAP uses `2e-7`. [VERIFIED: tests/testthat/test-sparse-schur-cpp.R:1-85; benchmarks/check_benchmark_gate.R:9-15]
   - What's unclear: Conditioning of the not-yet-authored three-region workflow.
   - Resolution: Ordinary three-region starts use a 1e-8 solution tolerance and 1e-10 true-residual tolerance, with conditioning evidence recorded in the proposal; any exception requires explicit review.

3. **How much raw `saveRDS(model)` compatibility should be promised?**
   - What we know: Same-session tiny legacy and sparse models round-tripped and solved locally, but raw objects were about 3 MB and R does not define serialization as a stable long-term format. [VERIFIED: local characterization run 2026-09-02] [CITED: https://stat.ethz.ch/R-manual/R-devel/library/base/html/serialize.html]
   - What's unclear: Whether downstream users currently persist raw models.
   - Resolution: raw saveRDS(model) is same-version compatibility-only; the versioned logical payload is the supported contract.

## Environment Availability

| Dependency | Required by | Available | Version/capability | Fallback |
|---|---|---:|---|---|
| R | All phase work | ✓ | 4.3.0 | None; blocking if absent. [VERIFIED: local environment probe 2026-09-02] |
| Matrix | Generic reference/residual | ✓ | 1.6-3 | None; imported dependency. [VERIFIED: local `packageVersion` 2026-09-02] |
| testthat | Contract tests | ✓ | 3.3.2 | None; suggested dependency. [VERIFIED: local `packageVersion` 2026-09-02] |
| Rcpp/native symbols | Optional C++ path | ✓ | ABI 1, `sparseLU-v1`, LAPACK true | Explicit tested skip on unavailable platforms. [VERIFIED: local native capability probe 2026-09-02] |
| OpenMP | Optional threaded path | ✓ | compiled, maximum 12 threads reported | Serial C++ with explicit skip reason. [VERIFIED: local native capability probe 2026-09-02] |
| SuiteSparse path | Optional generic backend | ✓ | availability probe true | Matrix reference; explicit optional skip. [VERIFIED: local `sparse_suite_sparse_available()` probe 2026-09-02] |
| HARr | External GTAP only | ✓ | installed | Not required for tiny/three-region ordinary checks. [VERIFIED: local `requireNamespace` probe 2026-09-02] |

**Missing dependencies with no fallback:** none in the current environment. [VERIFIED: local environment probes 2026-09-02]

**Missing dependencies with fallback:** none locally; tests must still exercise mocked absence for native/OpenMP/SuiteSparse paths.

## Validation Architecture

### Test framework

| Property | Value |
|---|---|
| Framework | testthat 3.3.2, edition 3 [VERIFIED: DESCRIPTION:28-30; local `packageVersion` 2026-09-02] |
| Config file | `DESCRIPTION`; launcher `tests/testthat.R` [VERIFIED: DESCRIPTION:28-30; .planning/codebase/TESTING.md:7-14] |
| Quick run | `rtk R --vanilla -q -e 'testthat::test_local(filter = "compatibility|numerical-baseline|transactional-state|model-serialization|baseline-artifacts", reporter = "summary")'` |
| Focused existing regression | `rtk R --vanilla -q -e 'testthat::test_local(filter = "public-solver-contract|public-cpp-backend|sparse-core|sparse-cpp-cache", reporter = "summary")'` |
| Full suite | `rtk R CMD check .` [VERIFIED: AGENTS.md:12-24] |

The focused existing regression completed successfully in about 26 seconds locally, with the pre-existing reference-class warning about local assignment to `data$eqcoeff`. [VERIFIED: local test run 2026-09-02; R/GEModel.R:184-193]

### Phase requirements → test map

| Req ID | Behavior | Test type | Automated command | File exists? |
|---|---|---|---|---|
| COMP-01 | Complete documented legacy and sparse workflow, both shock APIs | integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="documented-workflow")'` | ❌ Wave 0 |
| COMP-02 | Omitted engine/backend defaults equal explicit legacy/Matrix | contract/integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="public-solver-contract|compatibility-manifest")'` | Partial: existing default test [VERIFIED: tests/testthat/test-public-solver-contract.R:1-17] |
| COMP-03 | Manifest completeness, output structure, shock semantics, serialization | contract/integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="compatibility-manifest|model-serialization|documented-workflow")'` | ❌ Wave 0 |
| NUM-01 | Matrix/structured-R authority, optional C++, solution/structure/residual gates | numerical integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="numerical-baseline|public-cpp-backend")'` | Partial: backend tests exist [VERIFIED: tests/testthat/test-public-cpp-backend.R:1-39; tests/testthat/test-sparse-core.R:370-452,752-773] |
| NUM-02 | No mutation before acceptance; retryable post failure | fault-injection integration | `rtk R --vanilla -q -e 'testthat::test_local(filter="transactional-state")'` | ❌ Wave 0 |

### Sampling rate

- **Per task commit:** run the new focused file plus `public-solver-contract` and the directly affected sparse/native file.
- **Per wave merge:** run the focused existing regression command and all new Phase 2 filters.
- **Phase gate:** `rtk R CMD check .` plus a clean proposal diff from `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check` before `$gsd-verify-work`.

### Wave 0 gaps

- [ ] `tests/testthat/fixtures/three-region.tab` and fixture provenance record.
- [ ] `inst/compatibility/GEModel-contract.csv` with complete observed-surface tiers.
- [ ] `tests/testthat/helper-compatibility.R` for structural descriptors, backend capabilities, tolerances, and state snapshots.
- [ ] `tests/testthat/test-compatibility-manifest.R` for export/member/signature completeness.
- [ ] `tests/testthat/test-documented-workflow.R` for both shock APIs, repeated solves, outputs, and legacy smoke.
- [ ] `tests/testthat/test-numerical-baseline.R` for layered authority and universal residual/equivalence gates.
- [ ] `tests/testthat/test-transactional-state.R` for injected failure points and post retry.
- [ ] `tests/testthat/test-model-serialization.R` for versioned payload, fresh-process restore, and cache rebuild.
- [ ] `tests/testthat/test-baseline-artifacts.R` plus proposal/accept tooling.

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set it to false. [VERIFIED: .planning/config.json]

### Applicable ASVS categories

| ASVS 5.0 category | Applies | Standard control |
|---|---:|---|
| Authentication/session/access control | No | This phase adds no network service, identity, or authorization boundary. [VERIFIED: Phase 2 boundary in 02-CONTEXT.md] |
| V1.5 Safe Deserialization | Yes | Treat model payloads as trusted local artifacts; validate schema, types, sizes, source fingerprint, and allowed fields before reconstruction. Do not accept arbitrary raw reference objects as untrusted input. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x10-V1-Encoding-and-Sanitization.md] |
| V5 File Handling | Yes | Normalize/validate fixture and proposal paths, reject canonical-output targets from refresh mode, and bound artifact/model input sizes. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/docs_en/OWASP_Application_Security_Verification_Standard_5.0.0_en.flat.json] |
| Cryptography | No | MD5 is used only for deterministic change detection, not signatures, authentication, or adversarial integrity. Existing rights documentation makes the same distinction. [VERIFIED: docs/provenance/RIGHTS.md:79-85] |

### Known threat patterns for this stack

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| Loading untrusted raw RDS/reference objects | Tampering / Elevation of privilege | Supported payload is allowlisted, typed, versioned, size-bounded, and documented as trusted-input only; reject unknown fields/classes. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x10-V1-Encoding-and-Sanitization.md] |
| Refresh tool writes outside proposal directory | Tampering | Normalize paths, require explicit proposal root, and reject canonical baseline paths unless a separate reviewed acceptance mode is invoked. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/docs_en/OWASP_Application_Security_Verification_Standard_5.0.0_en.flat.json] |
| Oversized/malicious fixture or payload exhausts memory | Denial of service | Check file size, dimensions, counts, numeric finiteness, and configured memory budget before allocation/solve. Existing sparse preflight already rejects over-budget estimates. [VERIFIED: R/sparseSolver.R:1772-1824] |
| Crafted baseline silently becomes canonical | Tampering / Repudiation | Tests are read-only; acceptance records proposal hash, reviewer, reason, and date in reviewable text. |

## Sources

### Primary (HIGH confidence)

- `R/GEModel.R` — fields, methods, defaults, legacy workflow, public solve dispatch.
- `R/sparseSolver.R` — shock semantics, generic solve, residual, checkpoints, outputs, mutation order.
- `R/zzzSparseSchurCpp.R` and `R/zzzzzSchurDiagnostics.R` — native wrapper, preflight, backend adaptation, diagnostics.
- `tests/testthat/test-public-solver-contract.R`, `test-public-cpp-backend.R`, `test-sparse-core.R`, and `test-sparse-cpp-cache.R` — existing executable contracts and gaps.
- `benchmarks/benchmark_config.R`, `benchmark_gtap12a_run.R`, and `check_benchmark_gate.R` — reusable fingerprints, metadata, and external numerical gates.
- Local R/test/native capability and characterization runs on 2026-09-02.

### Secondary (MEDIUM confidence)

- [R serialization interface](https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRDS.html) — single-object transport and format version.
- [R low-level serialization](https://stat.ethz.ch/R-manual/R-devel/library/base/html/serialize.html) — reference hooks and long-term-format warning.
- [R reference classes](https://stat.ethz.ch/R-manual/R-devel/library/methods/html/refClass.html) — reference semantics and copy behavior.
- [R session metadata](https://www.stat.ethz.ch/R-manual/R-devel/library/utils/html/sessionInfo.html) and [package metadata](https://stat.ethz.ch/R-manual/R-devel/library/utils/html/packageDescription.html).
- [Matrix reference manual](https://stat.ethz.ch/CRAN/web/packages/Matrix/refman/Matrix.html) — sparse solve and multiplication contracts.
- [testthat skip documentation](https://testthat.r-lib.org/reference/skip.html) — explicit capability skips.
- [OWASP ASVS 5.0](https://github.com/OWASP/ASVS) — safe deserialization and file-handling categories.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — current package metadata, installed versions, current CRAN records, and official documentation were checked.
- Architecture: HIGH — recommendations follow direct source inspection of the complete public orchestration and mutation seams.
- Pitfalls: HIGH — each major pitfall is visible in source or reproduced by local characterization.
- Tolerance recommendation: MEDIUM — existing fixtures support it, but the new three-region fixture must confirm its conditioning before acceptance.

**Research date:** 2026-09-02
**Valid until:** 2026-10-02 for repository architecture; recheck package versions and environment metadata whenever baselines are refreshed.
