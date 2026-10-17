## Repairs implemented (17 October 2026)

The baseline for these repairs is the captured working tree, including
its earlier uncommitted optimizations, at HEAD
`901fcb0c070f802b6ca0e4e15604de5e0e0c39bd`. A fresh isolated build reproduced
the findings before editing. The untouched pre-optimization package also
reproduced the numerical, memory and cache defects. Existing unrelated edits
remain unstaged; repair commits contain the new changes and their tests.

### Changes and compatibility

| Finding | Implemented change | Regression coverage |
| --- | --- | --- |
| R001 | Form residual norm ratios on a common scale; preserve `max(1, ||rhs||)` semantics and reject invalid arithmetic before acceptance. A nonzero residual cannot underflow to an exact zero ratio. | `test-scaled-residuals.R`: overflowed RHS norm, ordinary/extreme/zero RHS, non-finite inputs and zero tolerance. |
| R002 | Use scaled L2 norms, normalize large RHS vectors before Arnoldi, use stable rotations, and verify the returned unscaled solution before reporting convergence. Full Schur checks and tolerance mapping use scaled arithmetic too. | `test-scaled-numerics.R`: finite identity systems through `1e308`, tiny RHS, large operators and full-system convergence. |
| R003 | Use stable compounding and remaining-shock formulas in both engines. Preserve tiny nonzero RHS through native elimination/reconstruction; pivot rejection is relative to the block's original coefficient scale. | Tiny positive/negative shocks, substeps, values immediately above -100%, exact -100% boundaries, and matrices scaled from `1e-200` to `1e200`. |
| R004 | Evaluate source baseline proposals in a clean Rscript process, with an explicit tool path and no inherited `R_TESTS` startup hook. Installed benchmark tests copy the installed package into an isolated library instead of rebuilding it as source. | Namespace/registry/runtime identity checks, an unrelated outer script, inherited startup hooks, standalone installed benchmark execution, and a second full-suite file order. |
| R005 | Add regional/global dense matrices, factors, simultaneous copies, transfers, Arnoldi vectors and native scratch to the budget estimate. Native scratch follows the bounded kernel buffers; sparse factor fill remains an estimate from sparse capacity. | The original 770-equation synthetic reproducer now rejects a 2 MiB budget; large original local groups retain linear scratch accounting. |
| R006 | Prepare validated sparse-factor snapshots once, protect their R storage, and reuse native scratch. Tagged handles reject foreign, released and deserialized pointers; cleanup releases them explicitly. Preflight verifies the prepare/solve/release protocol. | All four Matrix LU orderings, repeated RHS and panel widths, original-factor mutation, GC, malformed factors, released/foreign/serialized handles and partial native installations. |
| R007 | Retain regional transfer matrices already computed during construction and reuse first-pass regional solutions. | Reference preconditioner equivalence, regional solve counts, coefficient updates, fresh versus cached builds and changed ordering/batching. |
| R008 | Carry only structural metadata into the next transaction. Keys check index layout, pattern, grouping and batching; every build refactors current numeric coefficients. | Consecutive public solves, serialization/closure invalidation, value changes, pattern changes and all LU orderings. |
| R009 | Clear `emitted$A` after acceptance. Disabled diagnostics retain only the latest solver record and discard its unused solution vector; requested detailed reference diagnostics retain their existing solution field. | Update-hook matrix lifetime and diagnostic-structure compatibility checks. |

No public method signatures, backend defaults, RNG behavior or registered
native routine arities changed. No dependencies or compiler flags were added.
Tiny-shock preservation, scale-relative pivots and rejection of falsely
accepted residuals are intentional numerical corrections. The percentage
formulas retain compounding semantics, including rates below -100%; they do
not substitute logarithmic formulas with a narrower domain.

Prepared factors own immutable snapshots of their input factors. Changing a
model's coefficients creates new numeric factors and regional transfers;
structural cache entries contain no factors, external pointers or solutions.
A snapshot copy costs setup time and transient memory. Retained transfer
storage scales with regional size times global width. Budget estimates are
planning guards, not a hard RSS limit or a proven bound on sparse LU fill.

### Repeat the component measurements

Use separate before/after installations with `--install-tests` and identical
R, Matrix, Rcpp, compiler, BLAS and thread settings. The script uses seed
171017, seven measured batches and three warm-ups. Matrix factorization and
prepared-handle construction are outside the repeated solve timing; handle
setup time is reported separately. R allocation profiling is also outside
timing. Process peak RSS includes setup, retained oracle inputs and the R
heap, and is available on Linux. The component harness deliberately retains
the original Matrix factor alongside its prepared snapshot for comparison;
its RSS is not the steady-state footprint of a production model solve.

```sh
REPAIR_LIBRARY=/tmp/before-lib REPAIR_DEPENDENCIES=/path/to/deps \
  REPAIR_OUTPUT=/tmp/before-components.csv \
  Rscript --vanilla benchmarks/benchmark_repairs.R
REPAIR_LIBRARY=/tmp/after-lib REPAIR_DEPENDENCIES=/path/to/deps \
  REPAIR_OUTPUT=/tmp/after-components.csv \
  Rscript --vanilla benchmarks/benchmark_repairs.R

R_LIBS=/tmp/after-lib:/path/to/deps Rscript --vanilla -e \
  'testthat::test_package("GEModelR", filter="^(scaled-.*|prepared-.*|regional-reuse|memory-cache-lifecycle|randomized-native-reuse)$")'

R CMD build .
R CMD check GEModelR_0.1.0.tar.gz
```

The randomized native group repeats 200 cases using seed 171018, independent
row/column permutations, zero retained variables, scales `1e-150`, `1` and
`1e150`, all four LU orderings and multiple RHS values per prepared factor.
Comparisons use independent Matrix solves and the full-system scaled
residual, at tolerance `1e-12`.

### Results and verification

The [validation record](repair-validation-20261017.json) and
[package-check log](repair-check-20261017.txt) bind the checks to source hashes.
The [component repetitions](repair-components-20261017.csv) record the final
seven-batch comparison on R 4.3.0, Matrix 1.6-5, Rcpp 1.1.1.1.1, GCC 8.3.0
with the existing `-O2` build, and ATLAS BLAS on this Linux x86_64 host. Times
below are medians; brackets give the observed range. Each process used one
native thread. Other verification and full-model jobs shared the host.

| Component | Before | Integrated reuse | Speedup |
| --- | ---: | ---: | ---: |
| Sparse LU, 512 rows, one RHS | 0.670 ms [0.660, 0.920] | 0.270 ms [0.260, 0.300] | 2.48x |
| Sparse LU, 2,469 rows, one RHS | 26.800 ms [25.400, 34.800] | 10.500 ms [10.400, 11.500] | 2.55x |
| Regional preconditioner, eight 128-row regions, four global variables | 0.650 ms [0.625, 0.825] | 0.375 ms [0.375, 0.425] | 1.73x |

The sparse factors have 161,837 and 5,650,785 stored L/U entries respectively.
Their one-time prepared-snapshot setup took 0.002 and 0.234 seconds, outside
solve timing: the larger setup amortizes after about 15 repeated vector
solves in this measurement. Sparse-solve oracle differences were zero.
Regional reuse reduced 16 regional solves to eight, retained 34,608 transfer
bytes and differed from the prior application by at most `5.56e-17`.
Per-application R allocation fell from 154,824 to 91,144 bytes (41.1%).
Sparse-solve R allocation totals were unchanged. Process peak RSS after the
larger LU case was 368.77 MiB before and 371.77 MiB after; it includes the
original factor retained for the oracle and is not isolated native scratch.
These measurements establish component gains, not equivalent whole-model
speedups or universal memory reductions.

The [public workflow summaries](repair-public-20261017.csv) contain seven
repetitions for each existing small/large case, with diagnostics disabled or
enabled. An initial large, non-diagnostic comparison was 0.154 to 0.190
seconds, a 23% slowdown. It did not repeat consistently in interleaved fresh
processes with 15 repetitions each: before medians were 0.147 and 0.148
seconds; after medians were 0.156 and 0.146 seconds, with overlapping ranges.
The [60 control repetitions](repair-public-controls-20261017.csv) span
0.140–0.190 seconds before and 0.144–0.228 seconds after.
Profiles remained dominated by existing label parsing and updates. This
shared-host experiment establishes neither a consistent regression nor a
public Matrix-workflow speedup. Compilation and setup remain excluded.

Completed verification includes:

- 3,308 installed assertions passing in both ordinary and deterministic
  random file order, with zero failures or test warnings. The 165 skips
  concern repository-only audits, the optional SuiteSparse capability and an
  empty conditional serial test. Source-only producer audits still run from
  actual sources; installed scripts execute in their own library/processes.
- 1,482 focused assertions passing under combined ASan/UBSan, including the
  200-case scaled elimination/reconstruction and repeated-RHS comparison.
  The final handwritten native sources match the instrumented sources.
  LeakSanitizer was disabled; R and dependency libraries were not rebuilt
  with sanitizers. No whole-process leak or race-detector claim is made.
- 1,547 focused assertions passing in the serial build, including public
  rejection of unsupported thread counts. All four LU orderings are covered.
- `-Wall -Wextra -Wpedantic` syntax diagnostics on the prepared native
  boundary: zero diagnostics from handwritten code; Rcpp header warnings
  remain in the saved diagnostic log.
- Complete source suite: 4,334 passing assertions across all 44 test files,
  26 failed assertions and
  19 errors, versus 3,026 / 42 / 23 at this task's baseline. No newly failing
  test case was found, and no existing case gained failed assertions or a new
  error. Registry/cache/cleanup failures were repaired. The
  remaining cases are inherited identity/provenance/release-evidence audits,
  including frozen source counts and historical inventory assumptions. Their
  assertions and accepted records were preserved; this is not a claim that
  the repository source/release gate is green.

The final full `R CMD check`, including tests, rebuilt vignettes and the PDF
manual, completed with zero errors, zero warnings and two inherited notes
(installed library size and the existing license placeholder). The source
build also retains the existing version-3 serialization fixture notice for
R >= 3.5.0. The [source test comparison](repair-source-test-delta-20261017.csv)
records the inherited audit failures and the resolved runtime cases.
Windows and macOS were unavailable for execution. Portable Makevars and the
serial fallback remain unchanged.

Repeat the installed test orders with the committed runner:

```sh
REPAIR_LIBRARY=/tmp/after-lib REPAIR_DEPENDENCIES=/path/to/deps \
  Rscript --vanilla benchmarks/check_repair_tests.R
REPAIR_LIBRARY=/tmp/after-lib REPAIR_DEPENDENCIES=/path/to/deps \
  REPAIR_ORDER_SEED=171023 Rscript --vanilla benchmarks/check_repair_tests.R
```

This changes file order while retaining helper declarations before their
uses. `testthat`'s expression-level `shuffle=TRUE` also shuffles top-level
helper definitions and is unsuitable for the current test-file layout.

### Full GTAP comparison

Three interleaved before/after C++ pairs completed successfully against
the same local GTAP 12a inputs and nonzero productivity shock. Each fresh
process used `iter=1`, `steps=1`, postsimulation and detailed diagnostics,
four threads, panel size 64 and region batch size 16, with no additional
warm-up. The workload has 26,781,398 simulation equations, a 389,253-row
reduced system and 124,378 retained external unknowns. Both builds used 18
reduced iterations in every run. This compares two C++ builds; trusted
Matrix/reference comparisons use the generated workloads above.

The [six measured runs](repair-gtap-20261017.csv) and
[three complete solution/output comparisons](repair-gtap-agreement-20261017.csv)
contain aggregate evidence only. Values below are medians with observed
ranges; process wall time includes input/setup and saving the solution RDS.

| Metric | Before | Integrated repairs |
| --- | ---: | ---: |
| Public solve, including postsimulation (s) | 691.888 [633.172, 757.403] | 637.278 [632.132, 706.501] |
| Process wall time (s) | 766.204 [694.663, 818.002] | 694.506 [682.572, 760.151] |
| Peak process RSS (GiB) | 14.599 [14.599, 14.693] | 15.511 [15.509, 15.519] |

Median solve time was 7.9% lower. The first two pairs were 6.72% and 8.64%
faster; the third was 0.65% slower. Peak RSS increased by 6.2% at the median.
Prepared snapshots and retained transfers add storage, but this experiment
does not isolate their contribution to the RSS change. The first run was
slowest for both builds on the shared host. Fixed interleaving, three pairs,
host contention and cache effects limit causal precision; these observations
are not a guaranteed GTAP-wide speedup or a peak-memory improvement.

All solution attributes and selected-output structures matched. Maximum
absolute differences across all three complete solution vectors and compact
outputs were `9.95e-14` and `9.95e-14` respectively. Every value was
finite; full relative residuals were at most
`6.247e-09` before and
`6.267e-09` after, below `2e-7`.

The immutable after benchmark snapshot has the same handwritten native
sources as the final code. Later R refinements cover boundary arithmetic,
preflight validation, budget scratch accounting and requested reference
history fields; those refinements have focused regression coverage. Licensed
inputs and full solution artifacts remain outside source control in
`/tmp/gemodelr-repairs-20261017/gtap`. Only aggregate metrics and input
fingerprints are committed.

To repeat this comparison, set the library, dependency and licensed input
paths below. Run from the repository root and keep the output directory
private, because the RDS files contain complete model solutions. Each
library must be an immutable installation made from its recorded source
snapshot; the launch process's Git HEAD is not the library's source identity.

```sh
mkdir -p "$REPAIR_GTAP_OUTPUT"
for repetition in 1 2 3; do
  for build in before after; do
    case "$build" in
      before) library="$REPAIR_BEFORE_LIBRARY" ;;
      after) library="$REPAIR_AFTER_LIBRARY" ;;
    esac
    R_LIBS="$library:$REPAIR_DEPENDENCIES" \
      OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
      Rscript --vanilla benchmarks/benchmark_gtap12a_run.R \
      --data-dir="$REPAIR_DATA_DIR" --tablo="$REPAIR_TABLO" \
      --closure-file="$REPAIR_CLOSURE" --shocks-file="$REPAIR_SHOCKS" \
      --backend=StructuredSchurFGMRESCpp --threads=4 --iter=1 --steps=1 \
      --postsim=true --diagnostics=true --warmup=false \
      --panel-size=64 --region-batch-size=16 --repetition="$repetition" \
      --run-id="$build-$repetition" \
      --output="$REPAIR_GTAP_OUTPUT/$build-$repetition.csv" \
      --solution-output="$REPAIR_GTAP_OUTPUT/$build-$repetition.rds"
  done
done
Rscript --vanilla benchmarks/compare_repair_gtap.R \
  "$REPAIR_GTAP_OUTPUT" /tmp/gtap-agreement.csv 3
```

The comparator verifies CSV/artifact identity, workload/runtime settings,
types, attributes, output structure and finiteness before reporting maximum
absolute differences. Its synthetic checks cover changed values, non-finite
solutions, mismatched attributes/output shapes and stale artifact metadata.
