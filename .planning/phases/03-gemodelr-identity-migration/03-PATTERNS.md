# Phase 3: GEModelR Identity Migration - Pattern Map

**Mapped:** 2026-09-09
**Target entries classified:** 32 (grouped rows include mechanical identity-sweep families)
**Analogs found:** 31 / 32
**Requirements:** COMP-04, MIGR-01, MIGR-02

## Scope Rules

- Treat this as an identity and lineage migration. Do not change solver algorithms, public method signatures, backend defaults, numerical tolerances, or the Phase 2 workflow.
- Run the pre-rename serialization bridge and freeze its fixture/ref plus historical baseline digests before changing `Package:`.
- Generated `R/RcppExports.R` and `src/RcppExports.cpp` are outputs of `Rcpp::compileAttributes(".")`; do not hand-edit them.
- Preserve accepted Phase 2 artifacts as predecessor evidence. Active producers migrate to GEModelR; historical records retain `tabloToR` and are covered by exact allowlist records.
- Scan both tracked path names and text, case-insensitively, for `tabloToR`/`TABLOTOR`. Permit only exact reviewed occurrences, never directory or glob exclusions.
- Existing unrelated worktree changes and compiled artifacts are not implementation inputs. Build from a clean temporary source copy and install into an isolated temporary library.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `DESCRIPTION` | config | transform | current `DESCRIPTION`; `tests/testthat/test-attribution-contract.R` | exact |
| `NAMESPACE` | config | request-response/DLL loading | current `NAMESPACE`; generated registration in `src/RcppExports.cpp` | exact |
| `R/identityMigration.R` (new) | utility | request-response/validation | `R/modelSerialization.R`; `tools/provenance_inventory.R` | role-match |
| `R/modelSerialization.R` | service | file-I/O/transform | same file's existing schema, validation, and isolated restore pipeline | exact |
| `R/GEModel.R` | model | request-response/file-I/O | same file's `saveState()`, `loadState()`, and transactional legacy solve | exact |
| `R/sparseSolver.R` | service | request-response | local option validation and transaction gates in the same file | exact |
| `R/sparseElimination.R` | service | request-response/native call | `R/sparseSuiteSparse.R`; `R/zzzSparseSchurCpp.R` | role-match |
| `R/sparseSchurComplement.R` | service | request-response | local scalar option validation in the same file | exact |
| `R/sparseSuiteSparse.R` | service | request-response | `sparse_suite_sparse_ordering()` in the same file | exact |
| `R/zzzSparseSchurCpp.R` | provider | request-response/native call | native preflight in the same file | exact |
| `R/zzzzSparseSchurOpenMP.R` | provider | request-response/native call | wrapper dispatch in the same file | exact |
| `R/RcppExports.R` (generated) | provider | request-response/native call | current generated file | exact-generated |
| `src/RcppExports.cpp` (generated) | config/provider | request-response/native registration | current generated file | exact-generated |
| `src/dense-schur.cpp` | service | request-response/native call | its current Rcpp export attributes | exact |
| `src/sparse-elimination.cpp` and `inst/cpp/sparse-elimination.cpp` | service | request-response/native call | their paired current Rcpp exports | exact |
| `src/sparse-lu.cpp` | service | request-response/native call | its current named Rcpp exports | exact |
| `src/sparse-schur.cpp` and `src/sparse-schur-openmp.cpp` | service | request-response/native call | their current named Rcpp exports | exact |
| `src/tablo-sparse-lu.h` | utility | request-response/native validation | native class/symbol naming in `src/dense-schur.cpp` | role-match |
| `inst/migration/old-identity-allowlist.csv` (new) | config | batch/transform | `docs/provenance/EXPECTED-KEYS.csv`; `docs/provenance/PROVENANCE.csv` | role-match |
| `inst/migration/predecessor-fingerprints.dcf` (new) | config | file-I/O/validation | `tests/testthat/baselines/phase02/fingerprints.dcf` | role-match |
| `inst/migration/benchmark-identity-map.dcf` (new) | config | batch/transform | Phase 2 `fingerprints.dcf` plus `ACCEPTANCE.md` | role-match |
| `tests/testthat/fixtures/serialization/<predecessor-state>.rds` (new) | test fixture | file-I/O | no committed logical-state fixture exists | no analog |
| `tests/testthat/test-identity-migration.R` (new) | test | batch/request-response | `test-provenance-inventory.R`, `test-attribution-contract.R`, `test-public-solver-contract.R` | role-match |
| `tests/testthat/test-model-serialization.R` | test | file-I/O/request-response | same file's malformed-payload matrix and fresh-process cases | exact |
| `tests/testthat.R` plus identity-bearing test helpers | test/config | request-response | `tests/testthat.R`; helper source/installed fallback conventions | exact |
| Existing native/solver/benchmark tests containing old identity | test | request-response/batch | nearby assertions in each test; `test-public-solver-contract.R` | role-match |
| `tools/check_identity_migration.R` (new) | utility | batch/file-I/O | `tools/provenance_inventory.R`; `tools/check_release_gates.R` | role-match |
| `tools/provenance_inventory.R` and `tools/check_release_gates.R` | utility | batch/validation | their fixed-schema, fail-closed checks | exact |
| Accepted Phase 2 baseline files | config/test evidence | batch | `refresh_phase02_baselines.R` read-only check and immutability tests | exact |
| Active benchmark scripts (`benchmark_config.R`, `benchmark_gtap12a*.R`, run/check scripts) | service/utility | batch/file-I/O | `benchmark_gtap12a_run.R`; `test-benchmark-harness.R` | exact |
| `MIGRATION.md` (new), `README.md`, `inst/CITATION`, compatibility docs/manifest | config/documentation | transform | `inst/compatibility/SERIALIZATION.md`; README provenance links; attribution tests | role-match |
| `.gitignore`, `CONTRIBUTORS.md`, `NEWS.md`, provenance/release docs, and every remaining tracked old-token hit | config/documentation | transform/batch | exact identity scanner and attribution destination parity test | role-match |

## Pattern Assignments

### Package identity: `DESCRIPTION`, `NAMESPACE`, and package-facing tests

**Primary analogs:** `DESCRIPTION`, `NAMESPACE`, `tests/testthat/test-attribution-contract.R`, `tests/testthat.R`

`DESCRIPTION` is DCF and keeps identity-sensitive fields explicit. Change the package field and identity-bearing evidence symbol, but preserve authorship, dependencies, version, URLs, testthat edition, and solver description unless separately required.

**Metadata pattern** (`DESCRIPTION:1-14`, `DESCRIPTION:21-30`):

```dcf
Package: tabloToR
Type: Package
Title: TABLO models in R with legacy and sparse solvers
Version: 0.1.0
URL: https://github.com/DavidZenz/GEModelR
BugReports: https://github.com/DavidZenz/GEModelR/issues
Imports:
    Matrix,
    Rcpp,
    SparseM,
    methods
LinkingTo:
    Rcpp
Suggests:
    testthat
Config/testthat/edition: 3
```

**Namespace/DLL pattern** (`NAMESPACE:1-3`):

```r
useDynLib(tabloToR, .registration=TRUE)
importFrom(Rcpp, evalCpp)
exportPattern("^[[:alpha:]]+")
```

Only the DLL identity changes here. Preserve `exportPattern("^[[:alpha:]]+")`; export narrowing is Phase 4.

**Exact metadata assertion pattern** (`tests/testthat/test-attribution-contract.R:275-315`):

```r
description = read.dcf(attributionPath("DESCRIPTION"))
expect_identical(unname(description[[1L, "Package"]]), "tabloToR")
expect_identical(
  unname(description[[1L, "Maintainer"]]),
  "David Zenz <zenz@wiiw.ac.at>"
)
expect_identical(
  unname(description[[1L, "URL"]]),
  "https://github.com/DavidZenz/GEModelR"
)
```

**Test launcher pattern** (`tests/testthat.R:1-4`):

```r
library(testthat)
library(tabloToR)

test_check("tabloToR")
```

Mechanically migrate both package references together. Do not leave a mixed `library(GEModelR)` / `test_check("tabloToR")` launcher.

---

### `R/identityMigration.R`: centralized identity maps and option errors

**Closest analogs:** `R/modelSerialization.R:18-20,54-73`; `tools/provenance_inventory.R:597-622,775-790`

There is no exact existing centralized option migration registry. Build it from these established conventions:

**Small internal error constructor** (`R/modelSerialization.R:18-20`):

```r
.serialization_stop = function(message) {
  stop(sprintf("Invalid logical state payload: %s", message), call. = FALSE)
}
```

**Exact allowlist shape validation** (`R/modelSerialization.R:54-73`):

```r
.serialization_validate_names = function(value, expected, context) {
  actual = names(value)
  invalid_names = is.null(actual) || !is.character(actual) ||
    length(actual) != length(expected) || anyNA(actual) ||
    any(!nzchar(actual)) || anyDuplicated(actual)
  if (invalid_names || !setequal(actual, expected)) {
    missing = if (is.null(actual)) expected else setdiff(expected, actual)
    unknown = if (is.null(actual)) character() else setdiff(actual, expected)
    .serialization_stop(sprintf(
      "%s fields are not allowlisted (%s)", context,
      paste(c(
        if (length(missing)) sprintf("missing: %s", paste(missing, collapse = ", ")),
        if (length(unknown)) sprintf("unknown: %s", paste(unknown, collapse = ", "))
      ), collapse = "; ")
    ))
  }
  invisible(TRUE)
}
```

**Exact key-set validation** (`tools/provenance_inventory.R:604-622`):

```r
missing <- setdiff(expected_keys, actual_keys)
extra <- setdiff(actual_keys, expected_keys)
if (length(missing) || length(extra)) {
  provenance_abort(
    "PROVENANCE_KEY_MISMATCH",
    sprintf("missing=%d extra=%d rekeyed=%s",
            length(missing), length(extra), toupper(as.character(rekeyed)))
  )
}
```

Implementation assignment:

- Keep one named old-to-new public option map.
- Detect presence with `oldKey %in% names(options())`, not `getOption(oldKey)`, so an explicitly set `NULL` is still rejected.
- Error text must include the exact rejected key, exact `GEModelR.*` replacement, and `MIGRATION.md`, with `call. = FALSE`.
- Expose an internal guard that accepts one or more relevant old keys; call it locally at the operation boundary. Do not scan all options in `.onLoad()`.
- Private hooks and attributes are direct renames only and must not enter the predecessor option map.

#### Public option replacement matrix

| Old key | Exact replacement | First relevant consumer |
|---|---|---|
| `tabloToR.serialization.max_bytes` | `GEModelR.serialization.max_bytes` | `R/GEModel.R:170-191`; `R/modelSerialization.R:6-10` |
| `tabloToR.serialization.max_elements` | `GEModelR.serialization.max_elements` | `R/modelSerialization.R:12-16,125-179` |
| `tabloToR.sparse.lu_order` | `GEModelR.sparse.lu_order` | `R/sparseSolver.R:1425-1456`; structured path at 2142-2158 |
| `tabloToR.sparse.schur_cpp_threads` | `GEModelR.sparse.schur_cpp_threads` | `R/zzzSparseSchurCpp.R:577-594` |
| `tabloToR.sparse.schur_max_iterations` | `GEModelR.sparse.schur_max_iterations` | `R/sparseElimination.R:472-485` |
| `tabloToR.sparse.schur_panel_size` | `GEModelR.sparse.schur_panel_size` | `R/sparseElimination.R:472-485` |
| `tabloToR.sparse.schur_refinement_iterations` | `GEModelR.sparse.schur_refinement_iterations` | `R/sparseSchurComplement.R:649-678` |
| `tabloToR.sparse.schur_region_batch_size` | `GEModelR.sparse.schur_region_batch_size` | `R/sparseElimination.R:472-485` |
| `tabloToR.sparse.schur_restart` | `GEModelR.sparse.schur_restart` | `R/sparseElimination.R:472-485` |
| `tabloToR.sparse.schur_tolerance` | `GEModelR.sparse.schur_tolerance` | `R/sparseElimination.R:472-485` |
| `tabloToR.sparse.structured_residual_tolerance` | `GEModelR.sparse.structured_residual_tolerance` | `R/sparseSolver.R:2202-2212` |
| `tabloToR.sparse.suite_sparse_ordering` | `GEModelR.sparse.suite_sparse_ordering` | `R/sparseSuiteSparse.R:15-39` |

**Local option parse/validation pattern** (`R/sparseSuiteSparse.R:15-39`):

```r
ordering = tolower(as.character(getOption(
  "tabloToR.sparse.suite_sparse_ordering", "amd"
))[1L])
if (!length(ordering) || is.na(ordering) ||
    !(ordering %in% names(values)) || ordering == "given") {
  stop(
    paste(
      "tabloToR.sparse.suite_sparse_ordering must be one of",
      "cholmod, amd, metis, best, natural"
    ),
    call. = FALSE
  )
}
```

Place the legacy-key guard immediately before the renamed `getOption()` and preserve conversion, validation, defaults, and error semantics after that point.

**Private direct-renames (no legacy lookup):**

- `tabloToR.legacy.transaction.working` — `R/GEModel.R:296-303`
- `tabloToR.transaction.fault` and `tabloToR.accepted_numerical_state` — `R/sparseSolver.R:13-23,170-174,2531-2539`
- `tabloToR.sparse.sum_vectorized_limit`, `.vectorized`, `.elimination_pivot_tolerance` — `R/sparseSolver.R:1025-1060,1309-1314,2149-2158`
- `tabloToR.sparse.schur_validation_chunk_size`, `.schur_progress`, `.schur_true_residual_frequency` — `R/sparseSchurComplement.R:181-240,454-457`; `R/sparseElimination.R:482-484`
- fault hooks used only by tests/tools, including `tabloToR.phase02.acceptance.fault`, are direct renames.

---

### Logical-state migration: `R/modelSerialization.R`, `R/GEModel.R`, predecessor DCF, bridge fixture

**Primary analog:** the current logical-state implementation and tests.

**Frozen schema constants and limits** (`R/modelSerialization.R:3-16`):

```r
.serialization_schema = "gemodel-logical-state"
.serialization_schema_version = 1L

.serialization_max_bytes = function() {
  value = getOption("tabloToR.serialization.max_bytes", 256 * 1024^2)
  value = suppressWarnings(as.numeric(value)[1L])
  if (!is.finite(value) || value <= 0) 256 * 1024^2 else value
}

.serialization_max_elements = function() {
  value = getOption("tabloToR.serialization.max_elements", 50000000)
  value = suppressWarnings(as.numeric(value)[1L])
  if (!is.finite(value) || value <= 0) 50000000 else value
}
```

Keep schema/version/default limits exactly. Add package lineage to schema-1 output without changing numerical/model payload fields.

**Writer validates its own payload** (`R/modelSerialization.R:215-257`):

```r
payload = list(
  schema = .serialization_schema,
  schema_version = .serialization_schema_version,
  source = source[source_fields],
  engine = model$loadedEngine,
  levels = levels,
  closure = model$closure,
  shocks = .serialization_model_shocks(model),
  accepted = list(
    solution = model$solution,
    data = .serialization_strip_runtime(model$data),
    compact_output = model$compactOutput
  ),
  memory_budget = model$memoryBudget,
  diagnostics = model$lastDiagnostics
)
.validate_logical_state_payload(payload)
```

Use this pattern for bridge and current writes: construct a complete plain list, then pass it through the same strict validator before `saveRDS()`.

**Validation ordering** (`R/modelSerialization.R:260-337`): validate top-level list and exact names, exact schema/version, engine, source list shape, scalar source name, raw TABLO bytes, loaded-data list, 32-hex fingerprints, and recomputed TABLO/data fingerprints. Insert package-lineage validation after structural scalar/type checks and before reconstruction. Do not weaken any existing content check.

**File decode before restore, receiver commit last** (`R/GEModel.R:161-193`):

```r
payload = tryCatch(
  readRDS(file),
  error = function(error) {
    .serialization_stop(sprintf(
      "RDS decoding failed: %s", conditionMessage(error)
    ))
  }
)
restored = .restore_logical_state_payload(payload)
.install_restored_logical_state(.self, restored)
```

**Isolated reconstruction and one final install seam** (`R/modelSerialization.R:655-713`):

```r
restored = tryCatch({
  candidate = GEModel$new()
  candidate$loadTablo(path)
  candidate$setClosure(payload$closure)
  candidate$loadData(
    payload$source$loaded_data, engine = payload$engine
  )
  candidate
}, error = function(error) {
  .serialization_stop(sprintf(
    "source reconstruction failed: %s", conditionMessage(error)
  ))
})
.validate_reconstructed_logical_state(payload, restored)

.install_restored_logical_state = function(model, restored) {
  fields = names(GEModel$fields())
  values = lapply(fields, function(field) restored[[field]])
  names(values) = fields
  for (field in fields) model[[field]] = values[[field]]
  invisible(model)
}
```

Normalize an accepted predecessor identity to GEModelR on the isolated `restored` object. Save subsequent states only with current GEModelR identity.

**Nonmutation test helper** (`tests/testthat/helper-serialization.R:81-99`):

```r
before = serialize(
  serializationReceiverSnapshot(receiver), NULL, version = 3L
)
testthat::expect_error(receiver$loadState(state_file), pattern, info = info)
after = serialize(
  serializationReceiverSnapshot(receiver), NULL, version = 3L
)
testthat::expect_identical(after, before, info = info)
```

Apply this helper to missing, malformed, unknown, and non-allowlisted lineage; changed TABLO/data fingerprints; invalid object types; oversized files/payloads; and failed reconstruction.

**Reviewed predecessor DCF analog** (`tests/testthat/baselines/phase02/fingerprints.dcf:1-12`):

```dcf
Schema: phase02-baseline-fingerprints-v1
Source-Fingerprint: f57c39e0bdd3020b48a602773c580a8d
Package-Name: tabloToR
Package-Version: 0.1.0
Package-Signature: e21c5c3dd162c549ad53321a93ba9375
```

The accepted predecessor source fingerprint is `f57c39e0bdd3020b48a602773c580a8d`. Store it in a reviewed predecessor DCF with an exact schema and one scalar record. This is compatibility lineage, not cryptographic authenticity.

Bridge fixture requirements have no existing exact analog: generate it while the package still identifies as `tabloToR`, record the stable predecessor ref and fixture digest, and never fabricate predecessor lineage by editing a post-rename payload.

---

### Rcpp wrappers, registration, DLL loading, and native preflight

**Primary analogs:** current generated export files plus `R/zzzSparseSchurCpp.R`.

**Generated-file convention** (`R/RcppExports.R:1-17`):

```r
# Generated by using Rcpp::compileAttributes() -> do not edit by hand

.tabloToR_dense_lu_factor <- function(matrix) {
    .Call(`_tabloToR_tabloToR_dense_lu_factor`, matrix)
}

tabloToR_eliminate_blocks <- function(matrix_sexp, rhs, row_group,
                                      column_group, n_groups, pivot_tolerance) {
    .Call(`_tabloToR_tabloToR_eliminate_blocks`, matrix_sexp, rhs,
          row_group, column_group, n_groups, pivot_tolerance)
}
```

**Registration table and initializer** (`src/RcppExports.cpp:168-185`):

```cpp
static const R_CallMethodDef CallEntries[] = {
    {"_tabloToR_tabloToR_dense_lu_factor", (DL_FUNC) &_tabloToR_tabloToR_dense_lu_factor, 1},
    {"_tabloToR_tabloToR_eliminate_blocks", (DL_FUNC) &_tabloToR_tabloToR_eliminate_blocks, 6},
    {"_tabloToR_tabloToR_reconstruct_blocks", (DL_FUNC) &_tabloToR_tabloToR_reconstruct_blocks, 7},
    {NULL, NULL, 0}
};

RcppExport void R_init_tabloToR(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
```

Preserve all eleven routine arities and `R_useDynamicSymbols(dll, FALSE)`. Expected generated initializer is `R_init_GEModelR`; expected generated symbols use `_GEModelR_...` consistently.

**Hand-authored export annotations to rename before regeneration:**

- `src/dense-schur.cpp:43-44,73-74,114-115`
- `src/sparse-elimination.cpp:212-213,380-381` and its `inst/cpp/` copy
- `src/sparse-lu.cpp:13-14,35-36,67-68`
- `src/sparse-schur.cpp:155-156,267-268`
- `src/sparse-schur-openmp.cpp:149-150`

Representative pattern (`src/dense-schur.cpp:43-44`):

```cpp
// [[Rcpp::export(name = ".tabloToR_dense_lu_factor")]]
SEXP tabloToR_dense_lu_factor(Rcpp::NumericMatrix matrix) {
```

Rename both the R-facing attribute name and C++ function identifier, then run `Rcpp::compileAttributes(".")` once both metadata and hand-authored exports are ready. Inspect both generated files after regeneration.

**Native preflight pattern** (`R/zzzSparseSchurCpp.R:11-69`):

```r
.sparse_schur_cpp_symbols = c(
  "_tabloToR_tabloToR_schur_cpp_capabilities",
  "_tabloToR_tabloToR_sparse_lu_solve",
  "_tabloToR_tabloToR_sparse_pattern_hash"
)

missing = .sparse_schur_cpp_symbols[!vapply(
  .sparse_schur_cpp_symbols,
  is.loaded, logical(1), PACKAGE = "tabloToR"
)]
if (length(missing)) {
  fail(sprintf("registered native routine is missing: %s", missing[[1L]]))
}
```

Migrate the symbol vector, wrapper names, `PACKAGE`, native class tags, OpenMP wrapper aliases, benchmark namespace lookups, and tests as one native-identity family. Keep the ABI/capability/arity/self-test checks intact.

---

### Identity audit and machine-readable old-identity allowlist

**Primary analog:** `tools/provenance_inventory.R`; secondary analog `tools/check_release_gates.R`.

**Deterministic source collection** (`tools/provenance_inventory.R:529-595`):

```r
root <- normalizePath(root, winslash = "/", mustWork = TRUE)
files <- provenance_source_files(root)
if (!length(files)) provenance_abort("PROVENANCE_SOURCE_EMPTY")
...
order_id <- order(inventory$path, inventory$symbol, method = "radix")
inventory <- inventory[order_id, , drop = FALSE]
rownames(inventory) <- NULL
```

**Strict CSV loading** (`tools/provenance_inventory.R:775-790`):

```r
value <- tryCatch(
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                  colClasses = "character", na.strings = NULL),
  error = function(error) provenance_abort(
    "PROVENANCE_CSV_INVALID", conditionMessage(error)
  )
)
value[] <- lapply(value, as.character)
if (!is.null(columns) && !identical(names(value), columns)) {
  provenance_abort("PROVENANCE_COLUMNS_MISSING")
}
```

Use an exact CSV schema such as:

```text
path,category,expected_count,literal_or_line_digest,file_digest,rationale
```

Required categories are exactly:

1. `upstream-attribution`
2. `migration-instruction`
3. `immutable-historical-evidence`
4. `old-option-replacement`
5. `reviewed-serialization-fingerprint`

Audit behavior:

- Obtain tracked files and tracked path names from Git; sort with `method = "radix"`.
- Search content and path names case-insensitively for the old package token.
- Match every hit to one exact path/category/count/digest record.
- Fail on unexpected hits, duplicate records, count/digest drift, invalid categories, and stale/unused allowlist records.
- Do not treat generic `TABLO` language/model references as package identity.
- Repeat the identity checks against the built source archive and isolated installation. Inspect loaded namespaces, DLL basename, registration entries, and symbol table in a fresh process.
- Do not require the independently installed predecessor package to be absent from user libraries.

**Safe evidence path pattern** (`tools/check_release_gates.R:47-94`): reject absolute paths, `.`/`..`, missing/non-regular/empty files, out-of-root resolution, and digest mismatches before reading allowlisted evidence.

**CLI pattern** (`tools/provenance_inventory.R:805-834`; `tools/check_release_gates.R:2141-2180`): parse arguments in a function, emit stable machine-readable status/reason codes, return nonzero on failure, and guard execution with `if (sys.nframe() == 0L)`.

There is no existing archive/install/DLL identity audit, so `tools/check_identity_migration.R` must extend these patterns rather than copy a complete tool.

---

### Tests: identity matrix, exact docs, options, native registration, and installed process

**Primary analogs:** `tests/testthat/test-provenance-inventory.R`, `test-model-serialization.R`, `test-public-solver-contract.R`, `helper-serialization.R`.

**Fixed-schema and drift tests** (`tests/testthat/test-provenance-inventory.R:320-346`):

```r
expect_true(tool$provenance_validate_keys(inventory, expected))
expect_error(
  tool$provenance_validate_keys(inventory[-1L, ], expected),
  "PROVENANCE_KEY_MISMATCH.*missing=1"
)
expect_error(
  tool$provenance_validate_keys(inventory, expected[-1L, ]),
  "PROVENANCE_KEY_MISMATCH.*extra=1"
)
expect_error(
  tool$provenance_validate_keys(
    inventory, rbind(expected, expected[1L, , drop = FALSE])
  ),
  "PROVENANCE_DUPLICATE_KEY"
)
```

Apply the same mutation style to old-identity records: missing, extra, duplicate, wrong category, changed count, changed literal digest, changed immutable file digest, and stale allowlist entry.

**Native preflight nonmutation** (`tests/testthat/test-public-solver-contract.R:19-37`):

```r
before <- sparse_state_data(model$sparseState)
expect_error(
  model$solveModel(
    iter = 1, steps = 1, engine = "sparse", postsim = FALSE,
    backend = "StructuredSchurFGMRESCpp"
  ),
  "injected preflight failure"
)
expect_identical(sparse_state_data(model$sparseState), before)
expect_false(isTRUE(runtime$active))
```

Use this shape for every old public option: set only the predecessor key with `withr::local_options()`, invoke its first relevant operation, assert the error contains old key + exact replacement + `MIGRATION.md`, and compare a complete pre/post receiver snapshot where mutation is possible.

**Fresh-process pattern** (`tests/testthat/helper-serialization.R:109-147`): construct a temporary R script, execute `Rscript --vanilla` with `system2()`, capture stdout/stderr and exit status, and read a compact RDS result. For the installed-package gate, remove the source-tree `sys.source()` fallback: set an isolated `.libPaths()`, call `library(GEModelR)`, inspect `loadedNamespaces()`, `getLoadedDLLs()`, and registered routines, then run the redistributable public workflow.

**Source/installed path fallback** (`tests/testthat/helper-compatibility.R:1-15`):

```r
installed = system.file(
  "compatibility", "GEModel-contract.csv",
  package = "tabloToR"
)
source = testthat::test_path(
  "..", "..", "inst", "compatibility", "GEModel-contract.csv"
)
candidates = c(installed, source)
candidates = candidates[nzchar(candidates) & file.exists(candidates)]
```

Migrate package identity and preserve source/check/install portability for packaged migration registries and compatibility documents.

---

### Phase 2 baseline fingerprints and immutable historical evidence

**Primary analogs:** `inst/tools/refresh_phase02_baselines.R`, `tests/testthat/test-baseline-artifacts.R`, accepted Phase 2 files.

**Deterministic source fingerprint** (`inst/tools/refresh_phase02_baselines.R:192-229`):

```r
relative = unique(c(fixed, recursive))
relative = relative[order(tolower(relative), relative, method = "radix")]
...
hashes = unname(tools::md5sum(paths))
phase02_signature(as.list(stats::setNames(hashes, relative)))
```

**Identity-bearing producer fields** (`inst/tools/refresh_phase02_baselines.R:325-378`):

```r
list(
  Schema = "phase02-baseline-fingerprints-v1",
  `Source-Fingerprint` = source_fingerprint,
  `Package-Name` = unname(description[["Package"]]),
  `Package-Version` = unname(description[["Version"]]),
  `Package-Signature` = phase02_signature(list(
    package = unname(description[["Package"]]),
    version = unname(description[["Version"]]),
    source = source_fingerprint
  )),
  `Model-Signature` = model_signature
)
```

Active baseline/benchmark producers should report GEModelR. Do not run the predecessor acceptance updater to rewrite accepted artifacts.

**Read-only diff/check** (`inst/tools/refresh_phase02_baselines.R:465-506,569-578`): merge key/value entries, mark `unchanged`/`added`/`removed`/`changed`, render a deterministic diff, generate proposals only in a temp directory, and return `clean` without mutating canonical files.

**Immutability test** (`tests/testthat/test-baseline-artifacts.R:150-173`):

```r
before = refresh$phase02_artifact_hash(canonical)
refresh$phase02_generate_proposal(proposal)
clean = refresh$phase02_check_baselines()
expect_true(clean$clean)
expect_identical(before, refresh$phase02_artifact_hash(canonical))
```

Freeze and assert whole-file digests for at least:

- `tests/testthat/baselines/phase02/fingerprints.dcf`
- `tests/testthat/baselines/phase02/ACCEPTANCE.md`
- `tests/testthat/baselines/phase02/expectations.csv`
- `tests/testthat/baselines/phase02/tolerances.csv`

Map their predecessor package/source identity to the GEModelR migration baseline in a separate reviewed DCF. The accepted fingerprint and tolerances remain historical facts, not values to regenerate under the new identity.

---

### Active benchmarks and historical benchmark records

**Primary analogs:** `benchmarks/benchmark_config.R`, `benchmark_gtap12a_run.R`, `test-benchmark-harness.R`.

**Stable hash/signature helpers** (`benchmarks/benchmark_config.R:30-48`):

```r
benchmark_hash_file <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  unname(tools::md5sum(normalizePath(path, mustWork = TRUE))[[1L]])
}

benchmark_signature <- function(value) {
  lines <- capture.output(dput(value, control = c("keepNA", "keepInteger")))
  path <- tempfile("tabloToR-benchmark-signature-")
  on.exit(unlink(path), add = TRUE)
  writeLines(lines, path, useBytes = TRUE)
  benchmark_hash_file(path)
}
```

Rename only identity-bearing temporary prefixes; preserve canonical `dput()` controls and hashing behavior.

**Package/model/run metadata layering** (`benchmarks/benchmark_gtap12a_run.R:61-103`): keep package version and installed-tree signature in `model_config`, derive model/pair/run signatures by adding tuning and runtime dimensions, and copy stable identity fields into every emitted metric row. Change package lookup to GEModelR without changing the model/solver parameters.

**Runtime option and namespace use** (`benchmarks/benchmark_gtap12a_run.R:110-140`): migrate all active `options(...)`, package namespace, and `GEModel$new()` calls mechanically. Do not relabel existing `GTAP12A_CPP_RESULTS.md` or past output files; classify their predecessor references as immutable historical evidence and bind them through `benchmark-identity-map.dcf`.

**Test fixture pattern** (`tests/testthat/test-benchmark-harness.R:13-53`): emit compact synthetic metadata frames with deterministic signatures/status/metrics. Extend the fixture with package identity only if required by the active schema, and test the exact GEModelR value separately from historical map tests.

---

### Documentation migration: `MIGRATION.md`, README, CITATION, compatibility docs

**Closest analogs:** `inst/compatibility/SERIALIZATION.md`, README provenance section, attribution contract tests.

`MIGRATION.md` has no exact existing analog. Follow the repository's authoritative-contract style:

**Contract prose pattern** (`inst/compatibility/SERIALIZATION.md:5-15,21-33`): name the supported entry point and exact schema first, enumerate included fields, then state rejection/validation order and mutation guarantees.

For migration documentation, cover these exact replacements:

- `library(tabloToR)` → `library(GEModelR)`
- `require(tabloToR)` → `require(GEModelR)`
- `tabloToR::` → `GEModelR::`
- package dependency declarations → `GEModelR`
- remove old package/install GEModelR; no compatibility shim and no inspection or removal of an independently installed predecessor
- `renv`: install GEModelR, then run `renv::snapshot()`; never advise manual `renv.lock` editing
- all twelve public option replacements
- raw ReferenceClass RDS files are not cross-rename compatible; use the stable pre-rename bridge ref to create `saveState()` logical state before upgrading
- reviewed predecessor logical states load, normalize to GEModelR, and save back only as GEModelR

**README link pattern** (`README.md:21-26`): keep a concise landing-page summary and link to the authoritative root document rather than duplicating it.

**Historical attribution pattern** (`inst/CITATION:16-30`): retain the upstream `mivanic/tabloToR` title/URL/commit and evidence as intentional predecessor attribution while changing the current package citation/header/footer to GEModelR.

**Exact documentation assertions** (`tests/testthat/test-attribution-contract.R:317-349`): read files as UTF-8, collapse to text, and assert exact URLs/commit IDs/guide links and semantic phrases with `fixed = TRUE` where possible. Add equivalent assertions for every required mechanical replacement and ensure the README prominently links `MIGRATION.md`.

## Shared Patterns

### Fail Before Mutation

**Sources:** `R/GEModel.R:170-193`; `R/modelSerialization.R:655-713`; `R/sparseSolver.R:68-108,2515-2542`.

Apply to option guards, state lineage checks, native preflight, and archive/install verification. Parse and validate first, operate on an isolated candidate or working copy, then commit through one final seam. Tests compare serialized pre/post snapshots after every expected error.

### Exact Schemas and Stable Ordering

**Sources:** `tools/provenance_inventory.R:3-9,591-622,775-790`; `helper-compatibility.R:17-55`.

Use literal column lists, reject missing/extra/duplicate keys, coerce registry columns to character, keep `na.strings = NULL`, and sort keys with radix ordering. Reject unused allowlist records as drift.

### Error Handling

**Sources:** `R/modelSerialization.R:18-20`; `tools/provenance_inventory.R:11-18`; `tools/check_release_gates.R:2141-2180`.

Internal R API errors use one stable prefix/reason and `call. = FALSE`. CLI tools convert failures to stable reason codes/status and a nonzero exit. Migration errors additionally include old identifier, exact replacement, and `MIGRATION.md`.

### Source vs Installed Resource Lookup

**Sources:** `tests/testthat/helper-compatibility.R:1-15`; `test-baseline-artifacts.R:1-31`.

Tests first resolve an installed `system.file()` resource or a `testthat::test_path()` source copy as appropriate. Source-only tooling should skip clearly when excluded from a built package; installed identity tests must not silently fall back to source.

### Fingerprints Are Change Detection

**Sources:** `inst/compatibility/SERIALIZATION.md:45-49`; `refresh_phase02_baselines.R:93-113,219-229`.

Use MD5 only for deterministic drift/fingerprint checks, never claim authenticity. Recompute payload TABLO/data fingerprints and whole-file historical digests independently.

### Numerical Contract Freeze

Preserve exactly:

```r
solveModel(iter = 3, steps = c(1, 3), engine = c("legacy", "sparse"),
           postsim = TRUE, diagnostics = FALSE,
           output = c("full", "compact"), variables = NULL,
           dimensions = NULL, backend = "Matrix",
           reduction = c("auto", "off", "on"), memory_budget = NULL)
```

Also preserve structured defaults: region batch `8L`, panel `64L`, restart `80L`, max iterations `500L`, Schur tolerance `2e-7`, true-residual frequency `1L`, structured residual tolerance `2e-7`, elimination pivot tolerance `1e-12`, and sparse LU order `3L`.

## Build and Check Tooling Assignment

Use these gates in order:

1. Focused tests: `rtk R --vanilla -q -e 'testthat::test_local(filter = "identity-migration|model-serialization|public-solver-contract", reporter = "summary")'`.
2. Historical baseline check: `rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check`.
3. After native regeneration, inspect generated wrappers/registration and run the native test filters.
4. Run the complete testthat suite after each wave.
5. From a clean temporary tracked-source copy, run `R CMD build`, `R CMD check`, and isolated `R CMD INSTALL`.
6. Launch a new `Rscript --vanilla` process with only the temporary library, load GEModelR, inspect package metadata/namespace/DLL/registered routines, and run the redistributable workflow.
7. Run source/archive/install identity audits and verify accepted Phase 2 file digests are unchanged.

Do not validate against the existing `src/*.o`, `src/tabloToR.so`, local source archive/check directories, or user-library `tabloToR` installation.

## No Exact Analog Found

| File/Capability | Role | Data Flow | Planner Guidance |
|---|---|---|---|
| `tests/testthat/fixtures/serialization/<predecessor-state>.rds` | test fixture | file-I/O | Must be produced by the pre-rename bridge from a reviewed reachable predecessor ref; do not synthesize after rename. |
| `tools/check_identity_migration.R` archive/install/DLL layer | utility | batch/file-I/O | Extend provenance fixed-schema/path-safety/CLI patterns and fresh-process helper; no current tool builds and audits an isolated installation. |
| `MIGRATION.md` | documentation | transform | Use compatibility-contract prose and exact documentation assertions; no repository migration guide exists yet. |
| Centralized public old-option map | utility/config | request-response | Combine repository error/allowlist conventions with operation-local consumers; no centralized option registry exists. |

## Planner Sequencing Constraints

1. Bridge wave under predecessor identity: add lineage fields, reviewed predecessor fingerprint registry, fixture, lineage tests, and frozen historical digests.
2. Human checkpoint: approve the reachable predecessor bridge ref and exact user command.
3. Rename metadata/current R identity/options/docs and add exact source allowlist/audit.
4. Rename hand-authored native exports, regenerate both Rcpp export files, and run fresh native registration checks.
5. Migrate active benchmark/test/tool producers; add historical identity mapping without changing predecessor evidence.
6. Run clean archive/check/install, fresh-process workflow, full identity audit, complete test suite, and Phase 2 read-only baseline gate.

## Metadata

**Analog search scope:** `DESCRIPTION`, `NAMESPACE`, `R/`, `src/`, `tests/testthat/`, `inst/`, `tools/`, `benchmarks/`, `README.md`, tracked old-identity inventory
**Primary analogs read:** 22 files plus targeted sections of `R/sparseSolver.R` and `tools/check_release_gates.R`
**Current tracked old-identity surface:** 131 files reported by `git grep -l -i tabloToR`; the implementation audit must determine exact active edits versus reviewed intentional occurrences
**Pattern extraction date:** 2026-09-09
