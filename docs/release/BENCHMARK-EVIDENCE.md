# Full-Scale Benchmark Evidence

**Status:** Procedure only. NUM-03 remains pending until a current GEModelR
run passes the existing benchmark gate and its final redacted summary has a
verified detached signature from a maintainer-designated key.

## Data and artifact boundary

Run the full-scale workflow only on a host with authorized GTAP 12a inputs and
adequate memory and CPU resources. Keep the input directory, TABLO model,
closure file, temporary output directory, CSV files, logs, RDS solutions, and
other run artifacts outside the repository. Do not run this workflow in normal
package checks, vignettes, pkgdown builds, or public CI.

Only the reviewed, redacted Markdown summary and its detached `.asc` signature
may be added to the repository. Do not publish input paths, direct hashes of
proprietary files, credentials, raw CSV rows, logs, RDS files, solution values,
or full model outputs.

## Required local setup

Set these variables in the maintainer's local shell. All paths must resolve
outside the repository:

| Variable | Required value |
| --- | --- |
| `GEMODELR_GTAP12A_DATA_DIR` | Authorized local GTAP 12a HAR input directory |
| `GEMODELR_GTAP12A_TABLO` | Authorized GTAP TABLO model file |
| `GEMODELR_GTAP12A_CLOSURE_FILE` | Authorized benchmark closure RDS file |
| `GEMODELR_GTAP12A_OUTPUT_DIR` | Temporary run output directory outside the repository |
| `GEMODELR_BENCHMARK_SIGNING_FINGERPRINT` | Full fingerprint of the maintainer-designated GPG key present in the local keyring |

Before running, confirm that the exact GEModelR source commit and package
version intended for evaluation are installed on the benchmark host. Record the
source commit, package version, and SHA-256 of the tested source archive in the
public result summary. Do not place the archive, inputs, or full run output in
the site or a CI artifact.

## Run and check

Use the existing A/B runner with the documented full-scale settings. The
runner starts fresh R processes, writes all detailed files under the external
output directory, and invokes `check_benchmark_gate.R` itself:

```sh
Rscript --vanilla benchmarks/run_gtap12a_ab.R \
  --data-dir="$GEMODELR_GTAP12A_DATA_DIR" \
  --tablo="$GEMODELR_GTAP12A_TABLO" \
  --closure-file="$GEMODELR_GTAP12A_CLOSURE_FILE" \
  --output-dir="$GEMODELR_GTAP12A_OUTPUT_DIR" \
  --reference=StructuredSchurFGMRES \
  --candidate=StructuredSchurFGMRESCpp \
  --warmups=1 \
  --repetitions=3 \
  --threads=4 \
  --iter=3 \
  --steps=1,3 \
  --postsim=true \
  --panel-size=64 \
  --region-batch-size=8
```

After the runner exits successfully, independently run the checker against the
same output directory:

```sh
Rscript --vanilla benchmarks/check_benchmark_gate.R \
  --input-dir="$GEMODELR_GTAP12A_OUTPUT_DIR" \
  --reference=StructuredSchurFGMRES \
  --candidate=StructuredSchurFGMRESCpp \
  --output="$GEMODELR_GTAP12A_OUTPUT_DIR/comparison.csv"
```

Both invocations must exit successfully before recording or signing results.
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
| Signature provenance | Full signing-key fingerprint and an independently trusted source for the corresponding public verification key |

The runner's model, pair, run, and installed-package values are MD5-derived
fingerprints. Label them **fingerprints**; they identify recorded inputs or
configuration but do not authenticate authorship. Do not publish direct hashes
of individual proprietary inputs, their paths, or their filenames. The source
commit and source-archive SHA-256 identify the GEModelR code that was tested.

Review the entire Markdown summary for private details before signing. Include
only aggregate metrics and approved public identity metadata; keep per-run
records and full solution artifacts in the external output directory.

## Detached signature

Sign the final summary bytes locally only after both benchmark gates pass and
the summary has been reviewed. The private key must remain in the maintainer's
external GPG keyring; never copy it into the repository, CI, or the output
artifact. Confirm the full key fingerprint against a trusted maintainer or
organization key source, and record both that fingerprint and the trusted
verification-key source in the summary.

Create an armored detached signature over the exact summary file:

```sh
gpg --armor --detach-sign \
  --local-user "$GEMODELR_BENCHMARK_SIGNING_FINGERPRINT" \
  --output benchmarks/GTAP12A_CPP_RESULTS.md.asc \
  benchmarks/GTAP12A_CPP_RESULTS.md
```

Verify the signature and compare the signing fingerprint to the trusted public
key source before accepting the result:

```sh
gpg --verify \
  benchmarks/GTAP12A_CPP_RESULTS.md.asc \
  benchmarks/GTAP12A_CPP_RESULTS.md
gpg --fingerprint "$GEMODELR_BENCHMARK_SIGNING_FINGERPRINT"
```

Any edit to the summary after signing invalidates the detached signature. After
an edit, rerun both benchmark checks if result data changed, then sign and
verify the final bytes again. If the authorized inputs or a designated signer
and trusted public-key source are unavailable, leave NUM-03 pending; never
substitute an MD5 fingerprint, Git identity, or guessed key as the signature.

Passing this numerical gate and signature check does not resolve the separate
package license or attribution blockers, authorize redistribution, or approve
publication.
