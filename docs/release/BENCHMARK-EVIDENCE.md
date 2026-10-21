# Full-Scale Benchmark Evidence

**Status:** Procedure only. NUM-03 remains pending until a current GEModelR
run passes the existing benchmark gate and its redacted summary records the
required evidence. The summary is intentionally unsigned; no GPG key is
required.

## Data and artifact boundary

Run the full-scale workflow only on a host with authorized GTAP 12a inputs and
adequate memory and CPU resources. Keep the input directory, TABLO model,
closure file, temporary output directory, CSV files, logs, RDS solutions, and
other run artifacts outside the repository. Do not run this workflow in normal
package checks, vignettes, pkgdown builds, or public CI.

Only the reviewed, redacted Markdown summary may be added to the repository.
Do not publish input paths, direct hashes of proprietary files, credentials,
raw CSV rows, logs, RDS files, solution values, or full model outputs.

## Required local setup

Set these variables in the maintainer's local shell. All paths must resolve
outside the repository:

| Variable | Required value |
| --- | --- |
| `GEMODELR_GTAP12A_DATA_DIR` | Authorized local GTAP 12a HAR input directory |
| `GEMODELR_GTAP12A_TABLO` | Authorized GTAP TABLO model file |
| `GEMODELR_GTAP12A_CLOSURE_FILE` | Authorized benchmark closure RDS file |
| `GEMODELR_GTAP12A_OUTPUT_DIR` | Existing external reference directory and destination for candidate CSV/RDS artifacts |
| `GEMODELR_GTAP12A_REFERENCE_BUILD_RECORD` | Retained DCF build record for the existing reference package |
| `GEMODELR_GTAP12A_CANDIDATE_BUILD_RECORD` | Retained DCF build record for the currently installed candidate package |
| `GEMODELR_GTAP12A_PREFLIGHT_REPORT` | External DCF report path for the preflight; keep it outside the repository |

`GEMODELR_GTAP12A_OUTPUT_DIR` is also the reference directory unless an
explicit `--reference-dir` is supplied. If the reference benchmark used an RDS
shock input, pass `--shocks-file` or set
`GEMODELR_GTAP12A_SHOCKS_FILE`; otherwise the preflight uses the no-shock
configuration.

Both retained build records are DCF files with one record and these fields:

```text
schema_version: 1
package_name: GEModelR
package_version: 0.1.0
source_commit: <40- or 64-digit Git commit>
source_archive_sha256: <64-digit SHA-256>
installed_package_signature: <32-digit package fingerprint>
compiler_identity: <compiler name and version captured at build time>
compiler_flags: <compiler flags captured at build time>
r_version: <full R version string>
matrix_version: <Matrix version>
rcpp_version: <Rcpp version>
blas: <extSoftVersion values>
platform: <R platform>
cpu: <CPU model>
ram_bytes: <physical RAM in bytes>
model_signature: <runner model fingerprint>
pair_signature: <runner pair fingerprint>
run_signature: <runner backend/run fingerprint>
backend: StructuredSchurFGMRES
threads: 1
iter: 3
steps: 1,3
postsim: true
panel_size: 64
region_batch_size: 8
memory_budget: none
```

The candidate build record has `backend: StructuredSchurFGMRESCpp` and the
candidate's thread count. Keep actual compiler identity in each record; the
current `PATH` is not evidence of which compiler built an installed package.
The preflight requires the records to identify the same source archive,
package, compiler, and environment. Their pair settings must match, while the
backend-specific run signatures may differ. Do not put the build records,
archive, inputs, or full run output in the repository, site, or CI artifact.

## Run and check

Run the read-only reference preflight before starting any solver. It checks
existing schema-v3 reference CSVs and measured solution RDS files, recomputes
the model and pair fingerprints from the local inputs and installed package,
and compares retained source/package/compiler/runtime/build records. It reads
no solution values into its report, launches no solver, and does not copy input
files. The DCF report and standard output contain only safe software/build
identifiers, artifact counts, fingerprints, and reason codes; they omit private
paths, input filenames, direct input hashes, and solution values.

```sh
Rscript --vanilla benchmarks/preflight_gtap12a_reference.R \
  --reference-dir="$GEMODELR_GTAP12A_OUTPUT_DIR" \
  --data-dir="$GEMODELR_GTAP12A_DATA_DIR" \
  --tablo="$GEMODELR_GTAP12A_TABLO" \
  --closure-file="$GEMODELR_GTAP12A_CLOSURE_FILE" \
  --reference-build-record="$GEMODELR_GTAP12A_REFERENCE_BUILD_RECORD" \
  --candidate-build-record="$GEMODELR_GTAP12A_CANDIDATE_BUILD_RECORD" \
  --output="$GEMODELR_GTAP12A_PREFLIGHT_REPORT"
```

If the result is `reference_preflight_status=blocked`, stop. Record its exact
reason codes and artifact counts, keep NUM-03 open, and do not run a candidate.
Historical prose, candidate-only files, missing build provenance, stale or
mismatched signatures, incomplete repetitions, and absent solution artifacts
are not sufficient reference evidence. Never rerun the R baseline as part of
this gap closure.

Only after an `eligible` result, run the measured and warmup repetitions in the
candidate build record using `benchmarks/benchmark_gtap12a_run.R` with
`--backend=StructuredSchurFGMRESCpp` only. Use its exact `iter`, `steps`,
`postsim`, `panel_size`, `region_batch_size`, and `memory_budget` settings, the
candidate record's thread count, and the same authorized TABLO, input, closure,
and optional shock files. Use one invocation per repetition, with unique
`--run-id`, CSV `--output`, and `--solution-output` values under the external
output directory. Do not invoke `run_gtap12a_ab.R`; it starts both backends.

After all candidate warmups and measured repetitions complete, run the existing
checker unchanged against the combined directory:

```sh
Rscript --vanilla benchmarks/check_benchmark_gate.R \
  --input-dir="$GEMODELR_GTAP12A_OUTPUT_DIR" \
  --reference=StructuredSchurFGMRES \
  --candidate=StructuredSchurFGMRESCpp \
  --output="$GEMODELR_GTAP12A_OUTPUT_DIR/comparison.csv"
```

All candidate invocations and the unchanged checker must exit successfully
before recording results.
The checker command above is a separate invocation after the C++ candidate
runs; no R baseline command is part of this procedure.
The existing acceptance thresholds are at least 20% candidate speedup, no
more than 1.10 candidate/reference peak-RSS ratio, maximum residual at most
`2e-7`, and maximum absolute solution difference at most `1e-6`. The gate also
requires completed records, finite solution and selected outputs, no dense
full-system operations, matching run metadata, and valid reference/candidate
solution comparisons. Do not relax the gate to make a run pass.

Use four candidate threads, panel size 64, and regional batch size 8 when they
fit the selected host. If target-host limits require different values, keep
the existing gate unchanged and record the actual thread, panel, and batch
settings in the summary.

## Public summary fields

Append a dated section to `benchmarks/GTAP12A_CPP_RESULTS.md` only after both
gate runs pass. Keep the 2026-08-22 measurements labeled as historical. The
new section must report:

| Field | Evidence to record |
| --- | --- |
| Package and source identity | Package name and version, exact tested source commit, tested source-archive SHA-256, and the runner's `installed_package_signature` fingerprint |
| Model/configuration identity | `model_signature`, `pair_signature`, and `run_signature` fingerprints; reference and candidate backend names; iterations, steps, postsimulation, thread count, panel size, region batch, and memory budget setting |
| Software/platform | Run date in UTC, R, Matrix, and Rcpp versions, operating system/platform, and BLAS implementation |
| Hardware | CPU model and core/thread counts, physical RAM, and peak RSS with units |
| Numerical result | Reference and candidate maximum full relative residuals, maximum solution difference, `solution_finite=true`, `selected_outputs_finite=true`, and `dense_full_system_operations=false` |
| Performance | Reference and candidate median solve times, candidate/reference speedup or time ratio, and peak-RSS ratio |
| Selected outputs | State which selected-output checks were run and that they were finite; omit solution values and arrays |
| Evidence status | State that the summary is unsigned and that its fingerprints identify recorded inputs/configuration without authenticating authorship |

The runner's model, pair, run, and installed-package values are MD5-derived
fingerprints. Label them **fingerprints**; they identify recorded inputs or
configuration but do not authenticate authorship. Do not publish direct hashes
of individual proprietary inputs, their paths, or their filenames. The source
commit and source-archive SHA-256 identify the GEModelR code that was tested.

Review the entire Markdown summary for private details before recording it.
Include only aggregate metrics and approved public identity metadata; keep
per-run records and full solution artifacts in the external output directory.

## Authenticity scope

This procedure verifies numerical and resource acceptance through the runner
and independent checker. It does not cryptographically authenticate who ran
the benchmark or who wrote the summary. The package, model, pair, and run
fingerprints identify recorded inputs/configuration only; Git history and the
source commit identify code but do not authenticate benchmark authorship.
NUM-03 does not require GPG signing. If a future release policy requires
author authentication, define that as a separate provenance requirement with
its own trusted identity and verification process.

Passing this numerical gate does not resolve the separate package license or
attribution blockers, authorize redistribution, or approve publication.
