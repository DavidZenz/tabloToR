# Phase 1: Provenance and Release Boundary - Pattern Map

**Mapped:** 2026-08-24
**Files analyzed:** 13 new files
**Analogs found:** 8 / 13

## Scope Interpretation

Phase 1 creates evidence, policy, request, and release-gate artifacts. It does not rename the package, assign a license to inherited code, publish anything, or alter solver behavior.

The following files are later integration targets, not Phase 1 modifications: `DESCRIPTION`, `README.md`, `inst/CITATION`, and `NEWS.md`. Phase 1 records their approved future content in `docs/provenance/ATTRIBUTION.md`, `docs/provenance/RIGHTS.md`, and `docs/release/REPOSITORY.md`.

`specs/cleanroom/README.md` is inferred because Git cannot retain an empty `specs/cleanroom/` directory. It should define the admissible behavior-specification format and explicitly state that component specifications are created only if the clean-room fallback is activated.

`tools/check_release_gates.R` is inferred from the validation commands and the requirement that the release boundary be executable and fail closed.

## File Classification

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `docs/provenance/RIGHTS.md` | config | event-driven | `benchmarks/GTAP12A_CPP_RESULTS.md` | role-match |
| `docs/provenance/UPSTREAM-REQUEST.md` | config | request-response | None | no analog |
| `docs/provenance/PROVENANCE.csv` | model | batch | `tests/testthat/test-benchmark-harness.R` | role-match |
| `tools/provenance_inventory.R` | utility | batch | `benchmarks/benchmark_config.R` | role-match |
| `docs/provenance/CLEANROOM.md` | config | event-driven | None | no analog |
| `specs/cleanroom/README.md` | config | event-driven | None | no analog |
| `docs/provenance/ATTRIBUTION.md` | config | transform | `benchmarks/GTAP12A_CPP_RESULTS.md` | partial |
| `docs/release/RELEASE-GATES.md` | config | batch | `benchmarks/check_benchmark_gate.R` | data-flow match |
| `tools/check_release_gates.R` | utility | batch | `benchmarks/check_benchmark_gate.R` | exact |
| `tools/check_name_availability.R` | utility | request-response | `benchmarks/run_gtap12a_ab.R` | role-match |
| `docs/release/NAME-CHECK.md` | config | request-response | `benchmarks/GTAP12A_CPP_RESULTS.md` | role-match |
| `GOVERNANCE.md` | config | event-driven | None | no analog |
| `docs/release/REPOSITORY.md` | config | event-driven | None | no analog |

## Pattern Assignments

### `docs/provenance/RIGHTS.md` (config, event-driven)

**Analog:** `benchmarks/GTAP12A_CPP_RESULTS.md`

Use the existing evidence-report pattern: identify the exact configuration and source first, then state the result and reproducibility/privacy boundary. Replace benchmark configuration with upstream repository, upstream commit, request date/URL, contacted rights holders, evidence links or hashes, reviewer, and the single status value `blocked`, `cleared`, or `clean-room-required`.

**Evidence identity pattern** (`benchmarks/GTAP12A_CPP_RESULTS.md`, lines 3-13):

```markdown
## Configuration

Benchmarks ran on 2026-08-22 using the package at commit `6d8ea6c`, R 4.x,
Matrix 1.6.3, an AMD Ryzen 5 3600X (6 cores/12 threads), and 62.9 GiB of
physical RAM.

The final run selected the opt-in `StructuredSchurFGMRESCpp` backend ...
its run signature was `cb5d4dcc252c43c66c52f8e6b6f5bb7b`.
```

**Sensitive-evidence boundary** (`benchmarks/GTAP12A_CPP_RESULTS.md`, lines 55-58):

```markdown
Use `run_gtap12a_ab.R`, `run_gtap12a_sweep.R`, `run_gtap12a_scaling.R`, and
`check_benchmark_gate.R` to reproduce these checks with locally supplied GTAP
inputs. Proprietary inputs and full solution artifacts are intentionally not
stored in the repository.
```

Apply the same separation: public records may contain request URLs, public grants, hashes, and review status, but not private correspondence or personal data beyond an approved maintainer contact.

---

### `docs/provenance/UPSTREAM-REQUEST.md` (config, request-response)

**Analog:** None. The repository contains no rights-clearance request or external communication template.

Use `01-RESEARCH.md` and the locked decisions as the source pattern. The draft must request all three items explicitly: an open-source license, permission to modify and redistribute existing source, and permission to continue under the `GEModelR` name with attribution. Keep posting the request as a human checkpoint; creating this draft does not authorize external communication.

---

### `docs/provenance/PROVENANCE.csv` (model, batch)

**Analog:** `tests/testthat/test-benchmark-harness.R`

Copy the fixed-schema, explicit-type data-frame convention. Keep every required column present even when a value is awaiting manual review; write empty strings rather than allowing schema drift.

**Stable record schema pattern** (`tests/testthat/test-benchmark-harness.R`, lines 27-52):

```r
data.frame(
  schema_version = 3L,
  run_id = run_id,
  repetition = 1L,
  warmup = FALSE,
  timestamp_utc = "2026-08-22 00:00:00 UTC",
  run_signature = paste0("run-", run_id),
  pair_signature = pair_signature,
  model_signature = model_signature,
  git_commit = "fixture",
  package_version = "0.1.0",
  r_version = "4",
  matrix_version = "1.6.3",
  platform = R.version$platform,
  backend = "StructuredSchurFGMRESCpp",
  threads = threads,
  iter = 1L,
  steps = "1",
  postsim = TRUE,
  status = "completed",
  error = "",
  metric = names(metrics),
  value = unname(metrics),
  unit = "value",
  stringsAsFactors = FALSE
)
```

For the provenance inventory, replace these fields with the exact required columns from research, preserve their order, restrict `classification` to the six approved values, and use one row per top-level R function plus each inherited or substantially modified native function. Wholly new files may use one file-level row.

**CSV emission pattern** (`benchmarks/check_benchmark_gate.R`, line 86):

```r
write.csv(summary, output, row.names = FALSE)
```

---

### `tools/provenance_inventory.R` (utility, batch)

**Analog:** `benchmarks/benchmark_config.R`

Use short base-R helpers, explicit scalar types, `call. = FALSE` validation errors, and qualified calls for non-base namespaces. Do not add a hashing dependency: the repository already uses `tools::md5sum`.

**Argument parsing and validation** (`benchmarks/benchmark_config.R`, lines 1-21):

```r
benchmark_get_arg <- function(args, name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[1L]], fixed = TRUE)
}

benchmark_flag <- function(args, name, default = FALSE) {
  value <- benchmark_get_arg(args, name)
  if (is.null(value)) return(default)
  tolower(value) %in% c("1", "true", "yes", "y")
}

benchmark_integer <- function(value, default, minimum = 0L) {
  if (is.null(value)) return(as.integer(default))
  result <- suppressWarnings(as.integer(value)[1L])
  if (is.na(result) || result < minimum) {
    stop(sprintf("Expected an integer of at least %s, got %s", minimum, value),
         call. = FALSE)
  }
  result
}
```

**Deterministic expression/file hashing** (`benchmarks/benchmark_config.R`, lines 30-47):

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

**Deterministic tree ordering** (`benchmarks/benchmark_config.R`, lines 123-132):

```r
root <- normalizePath(path, mustWork = TRUE)
files <- sort(list.files(root, recursive = TRUE, full.names = TRUE,
                         all.files = TRUE, no.. = TRUE))
info <- file.info(files)
files <- files[!is.na(info[["isdir"]]) & !info[["isdir"]]]
relative <- substring(files, nchar(root) + 2L)
hashes <- unname(tools::md5sum(files))
```

Adapt this to sort source paths and symbols before CSV output. `--check` must compare generated records with the checked-in inventory and fail on missing/duplicate symbols, `unknown`, empty status, missing holder/license basis, or contradictory origin fields. Git history and hashes are evidence fields, not automatic ownership conclusions.

---

### `docs/provenance/CLEANROOM.md` (config, event-driven)

**Analog:** None. There is no clean-room or source-access protocol in the repository.

Use the research contract directly. Define separate specification and implementation roles, source-access restrictions, behavior-only inputs, implementer attestations, independent review, replacement acceptance criteria, and the exact evidence needed before a provenance row becomes `new-independent`. A person who inspected inherited implementation cannot be listed as its independent implementer.

---

### `specs/cleanroom/README.md` (config, event-driven)

**Analog:** None. Existing test fixtures describe parser behavior but are not clean-room specifications and must not be presented as independent implementation inputs.

Define a template/index only: component identifier, observable behavior, inputs, outputs, errors, invariants, compatibility examples, specification author, implementer eligibility, reviewer, and provenance-row link. State that inherited source excerpts, structural descriptions derived from source, and private/proprietary fixtures are forbidden.

---

### `docs/provenance/ATTRIBUTION.md` (config, transform)

**Analog:** `benchmarks/GTAP12A_CPP_RESULTS.md`

Use the evidence-first report structure from lines 3-13, but transform verified provenance rows into proposed package metadata. Separate current verified facts from later target changes to `Authors@R`, maintainer, copyright, license, URLs, `inst/CITATION`, README attribution, and NEWS credit.

Do not infer `aut`, `ctb`, `cph`, or `cre`; every proposed role must cite a provenance row or rights record. Do not place unapproved contact details in the document.

---

### `docs/release/RELEASE-GATES.md` (config, batch)

**Analog:** `benchmarks/check_benchmark_gate.R`

Mirror the executable gate's fail-closed assertions. Each Markdown gate should name its evidence file, exact passing condition, offline/online applicability, reviewer requirement, and blocking result.

**Input completeness and consistency checks** (`benchmarks/check_benchmark_gate.R`, lines 16-25):

```r
files <- list.files(input_dir, pattern = "\\.csv$", full.names = TRUE)
files <- setdiff(files, output)
if (!length(files)) stop("No benchmark CSV files found", call. = FALSE)
frames <- lapply(files, read.csv, stringsAsFactors = FALSE)
frame <- do.call(rbind, frames)
if (any(frame$status != "completed")) {
  stop("At least one benchmark child failed", call. = FALSE)
}
if (length(unique(frame$pair_signature)) != 1L) {
  stop("Benchmark pair signatures do not match", call. = FALSE)
}
```

The Phase 1 equivalent must reject absent rights status, unknown provenance, inconsistent status documents, missing reviewed name evidence, absent approved maintainer/repository data, unavailable online sources, and any attempted release-ready result while rights remain blocked.

---

### `tools/check_release_gates.R` (utility, batch)

**Analog:** `benchmarks/check_benchmark_gate.R`

Copy the full fail-closed shape: parse paths/options, read all evidence, validate consistency before summarizing, write a machine-readable/inspectable result, then terminate nonzero on any failed predicate.

**Summarize first, then fail** (`benchmarks/check_benchmark_gate.R`, lines 72-94):

```r
summary <- data.frame(
  metric = c(
    "reference_median_solve_seconds", "candidate_median_solve_seconds",
    "wall_time_ratio", "peak_rss_ratio",
    "reference_max_full_relative_residual",
    "candidate_max_full_relative_residual",
    "max_abs_solution_difference"
  ),
  value = c(
    reference_time, candidate_time, candidate_time / reference_time,
    candidate_rss / reference_rss, reference_residual, candidate_residual,
    maximum_solution_difference
  ), stringsAsFactors = FALSE
)
write.csv(summary, output, row.names = FALSE)
if (!is.finite(reference_time) || !is.finite(candidate_time) ||
    candidate_time / reference_time > 1 - minimum_speedup ||
    candidate_rss / reference_rss > maximum_rss_ratio ||
    candidate_residual > maximum_residual ||
    (!is.na(maximum_solution_difference) &&
       maximum_solution_difference > maximum_difference)) {
  stop("A/B benchmark gate failed", call. = FALSE)
}
```

For `--offline`, do not silently skip live gates: report them as not evaluated and retain a blocked release result unless a current reviewed `NAME-CHECK.md` satisfies the documented policy. `blocked` must never coerce to success.

---

### `tools/check_name_availability.R` (utility, request-response)

**Analog:** `benchmarks/run_gtap12a_ab.R`

Use the repository's standalone Rscript bootstrap, explicit required arguments, normalized output path, and checked subprocess status. There is no existing HTTP/registry-query implementation, so registry-specific query behavior must come from `01-RESEARCH.md` and authoritative APIs/indexes rather than an invented codebase convention.

**Standalone CLI bootstrap** (`benchmarks/run_gtap12a_ab.R`, lines 1-11):

```r
#!/usr/bin/env Rscript

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), mustWork = TRUE))
source(file.path(script_dir, "benchmark_config.R"))
args <- commandArgs(trailingOnly = TRUE)
output_dir <- benchmark_get_arg(args, "--output-dir")
if (is.null(output_dir)) stop("--output-dir is required", call. = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
```

**Checked external command pattern** (`benchmarks/run_gtap12a_ab.R`, lines 54-59):

```r
status <- system2(file.path(R.home("bin"), "Rscript"),
                  shQuote(c("--vanilla", child_args)), stdout = log, stderr = log)
if (!identical(status, 0L)) {
  stop(sprintf("Benchmark child %s failed; see %s", run_id, log),
       call. = FALSE)
}
```

Hash every raw response with the `tools::md5sum` pattern from `benchmarks/benchmark_config.R` lines 30-32. Search CRAN current/archive, Bioconductor current/history, R-universe, and GitHub case-insensitively. Any unavailable source or exact collision is an error, not a warning or assumed pass.

---

### `docs/release/NAME-CHECK.md` (config, request-response)

**Analog:** `benchmarks/GTAP12A_CPP_RESULTS.md`

Copy the configuration/result-table/reproduction structure:

- Lines 3-13 establish timestamp, versions/configuration, exact source identity, and signature.
- Lines 17-22 present comparable results in a compact table.
- Lines 55-58 identify the reproduction command and excluded private artifacts.

Adapt the table to one row per registry/source with UTC timestamp, exact query URL or command, case-insensitive exact matches, raw-result hash, availability, reviewer, and pass/fail result. State explicitly that the report is point-in-time collision evidence, not trademark clearance or permanent reservation.

---

### `GOVERNANCE.md` (config, event-driven)

**Analog:** None. The repository has no governance or maintainer-succession document.

Use the locked decisions directly: David Zenz is sole v1 maintainer and release authority; contributions arrive through pull requests; `main` is protected with passing CI; self-review is permitted during the single-maintainer stage. Add concrete procedures for adding maintainers, succession, and assigning security-reporting responsibility without inventing an unapproved public contact address.

---

### `docs/release/REPOSITORY.md` (config, event-driven)

**Analog:** None. The repository has no canonical-hosting or fork-detachment runbook.

Record intended personal-account ownership, canonical repository and issue-tracker placeholders, private-development requirement, branch-protection target, metadata to inventory before detachment/mirroring, history-preservation checks, and rollback/recovery notes. Mark visibility changes, detachment, deletion/recreation, repository reservation, and branch-protection changes as explicit human checkpoints. This file documents external actions; Phase 1 planning must not perform them autonomously.

## Shared Patterns

### Base-R Utility Style

**Sources:** `benchmarks/benchmark_config.R` lines 1-47; `benchmarks/run_gtap12a_ab.R` lines 1-11

**Apply to:** All three `tools/*.R` files.

- Use two-space indentation and the repository's short base-R helper style.
- Prefer explicit `character`, `integer`, and logical normalization.
- Use `call. = FALSE` for expected command-line validation failures.
- Use qualified non-base calls such as `tools::md5sum`; do not add dependencies for functionality already available in base/recommended R.
- Resolve the script directory from `--file=` before sourcing a sibling helper.
- Normalize required paths with `mustWork = TRUE` after creating only explicitly requested output directories.

### Fail-Closed Gates

**Source:** `benchmarks/check_benchmark_gate.R` lines 16-25 and 87-94

**Apply to:** `tools/provenance_inventory.R`, `tools/check_name_availability.R`, and `tools/check_release_gates.R`.

Missing inputs, incomplete records, contradictory signatures/statuses, unavailable sources, non-finite/invalid values, and failed checks terminate nonzero. No code path defaults an unknown legal or registry state to success.

### Deterministic Evidence and Hashing

**Source:** `benchmarks/benchmark_config.R` lines 30-47 and 123-132

**Apply to:** Inventory generation, registry raw responses, and release-gate evidence.

Sort paths and symbols, serialize normalized values deterministically, use byte-preserving writes, and hash the normalized/raw evidence. Hashes support auditability but are not proof of authorship, ownership, or independent creation.

### Stable CSV Output

**Sources:** `tests/testthat/test-benchmark-harness.R` lines 27-52; `benchmarks/check_benchmark_gate.R` line 86

**Apply to:** `docs/provenance/PROVENANCE.csv` and any temporary gate summaries.

Construct an explicit fixed-column `data.frame(..., stringsAsFactors = FALSE)` and write it with `row.names = FALSE`. Preserve column order and use stable empty values so checked-in diffs are reviewable.

### Script-Level Testing

**Source:** `tests/testthat/test-benchmark-harness.R` lines 55-68 and 127-133

**Apply if the planner adds regression tests for the tools.**

```r
output <- suppressWarnings(system2(
  file.path(R.home("bin"), "Rscript"),
  shQuote(c("--vanilla", benchmark_script_path(script), args)),
  stdout = TRUE, stderr = TRUE
))
status <- attr(output, "status")
if (is.null(status)) 0L else as.integer(status)
```

Use `tempfile()`, `dir.create()`, and `on.exit(unlink(..., recursive = TRUE), add = TRUE)` for isolated fixtures. Test both a valid fixture returning zero and a deliberately corrupted/missing fixture returning nonzero. Do not use network-dependent tests for the deterministic/offline layer.

### Public/Private Evidence Boundary

**Source:** `benchmarks/GTAP12A_CPP_RESULTS.md` lines 55-58

**Apply to:** Every new document, report, CSV, fixture, and log.

Commit reproducible commands, public URLs, hashes, and reviewed conclusions. Do not commit proprietary `.har`/`.tab` inputs, benchmark solutions, credentials, private correspondence, or unapproved personal contact details.

## No Analog Found

These files have no close repository precedent. The planner should use the locked decisions and `01-RESEARCH.md`, not force an unrelated implementation pattern.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `docs/provenance/UPSTREAM-REQUEST.md` | config | request-response | No legal request or external-communication template exists. |
| `docs/provenance/CLEANROOM.md` | config | event-driven | No clean-room separation or attestation protocol exists. |
| `specs/cleanroom/README.md` | config | event-driven | Existing fixtures are implementation tests, not behavior-only clean-room inputs. |
| `GOVERNANCE.md` | config | event-driven | No maintainer governance or succession policy exists. |
| `docs/release/REPOSITORY.md` | config | event-driven | No private-fork detachment or canonical-hosting runbook exists. |

## Metadata

**Analog search scope:** `benchmarks/`, `tests/testthat/`, `R/`, root package/docs files, and `.planning/` context/maps

**Candidate search:** Repository-wide file inventory plus searches for `commandArgs`, `system2`, `write.csv`, `read.csv`, `writeLines`, `tools::md5sum`, and fail-closed `stop()` patterns

**Files fully extracted:** 5 analog files

**Analogs selected:**

- `benchmarks/benchmark_config.R`
- `benchmarks/check_benchmark_gate.R`
- `benchmarks/run_gtap12a_ab.R`
- `benchmarks/GTAP12A_CPP_RESULTS.md`
- `tests/testthat/test-benchmark-harness.R`

**Pattern extraction date:** 2026-08-24
