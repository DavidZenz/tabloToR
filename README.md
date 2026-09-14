# GEModelR

GEModelR interprets GEMPACK-style TABLO models in R and solves them through the
established `GEModel` workflow.

## Provenance and redistribution status

This package derives from the public
[`mivanic/tabloToR`](https://github.com/mivanic/tabloToR) repository at audited
commit
[`7e063c65a19713857ed13023f8b77dad45b15c90`](https://github.com/mivanic/tabloToR/tree/7e063c65a19713857ed13023f8b77dad45b15c90).
Maros Ivanic authored that upstream baseline and David Zenz authored the
reviewed post-baseline sparse and native solver work. The upstream baseline has
an accepted public-domain/CC0 basis; it is credited here even though CC0 does
not require attribution.

The current package identity is `GEModelR`. Public redistribution remains
blocked: the dependency compatibility audit needed to finalize the package
license is still pending. The identity migration does not authorize
publication.

The evidence-to-role mapping is in
[`docs/provenance/ATTRIBUTION.md`](docs/provenance/ATTRIBUTION.md), the accepted
rights basis and scope are in
[`docs/provenance/RIGHTS.md`](docs/provenance/RIGHTS.md), and the reviewed source
ledger is in
[`docs/provenance/PROVENANCE.csv`](docs/provenance/PROVENANCE.csv).

Reviewed attribution evidence keys:

- `R/GEModel.R::GEModel$loadTablo`
- `R/GEModel.R::GEModel$solveModel`
- `R/processTablo.R::processTablo`
- `R/sparseCompiler.R::sparse_compile_spec`
- `R/sparseSolver.R::sparse_solve_model`
- `src/sparse-schur.cpp::tabloToR_schur_accumulate_global`

## Migrating from the predecessor package

[Migrate from `tabloToR`](MIGRATION.md) for exact library, namespace,
dependency, `renv`, runtime-option, installation, and saved-state instructions.
GEModelR is an immediate replacement and does not provide a compatibility shim.

## Installation

From a local GEModelR checkout:

```sh
R CMD INSTALL .
```

## Running a simulation

```r
model = GEModelR::GEModel$new()

# You need to have the model, such as gtap.tab 
model$loadTablo('gtap.tab')

# You need to get the data files .har
data = list(
  # The file with GTAP sets may alternatively be called sets.har by some data aggregation programs
  gtapsets = HARr::read_har('gsdgset.har'),
  # The file with GTAP parameters may alternatively be called default.prm by some data aggregation programs
  gtapparm = HARr::read_har('gsdgpar.har'),
  # The file with GTAPdata may alternatively be called basedata.har by some data aggregation programs
  gtapdata = HARr::read_har('gsdgdat.har')
)

# Initialize the model object

model$loadData(data)

# Set up the closure

for(var in c("afall",
      "afcom",
      "afeall",
      "afecom",
      "afereg",
      "afesec",
      "afreg",
      "afsec",
      "ams",
      "aoall",
      "aoreg",
      "aosec",
      "atall",
      "atd",
      "atf",
      "atm",
      "ats",
      "au",
      "avaall",
      "avareg",
      "avasec",
      "cgdslack",
      "dpgov",
      "dppriv",
      "dpsave",
      "endwslack",
      "incomeslack",
      "pfactwld",
      "pop",
      "profitslack",
      "psaveslack",
      "tf",
      "tfd",
      "tfm",
      "tgd",
      "tgm",
      "tm",
      "tms",
      "to",
      "tpd",
      "tpm",
      "tp",
      "tradslack",
      "tx",
      "txs")){
  model$variableValues[[var]][]=0
}

model$variableValues$qo[model$data$endw_comm,] = 0

# Specify sets for shocks 

ag= c("grains", "v_f", "osd", "c_b", "pfb", "ocr", "ctl", "oap", "rmk", "wol")
model$variableValues$aoall[ag,c("northam")] = 1

agFood = c("grains", "v_f", "osd", "c_b", "pfb", "ocr", "ctl", "oap", "rmk", "wol", "food")

model$variableValues$tms[agFood,,c("northam")] = (model$data$viws[agFood,,c("northam")] / model$data$vims[agFood,,c("northam")] -1)*100

# Run the model
model$solveModel(iter = 3,steps = c(1,3))

# View the results (variable ev--welfare)
model$data$ev

```
## Low-memory sparse execution

The legacy solver remains the default. For large, unaggregated GTAP runs, opt into the integer-indexed sparse engine after loading the TABLO recipe and HAR data:

```r
model <- GEModelR::GEModel$new()
model$loadTablo("gtapv7.tab")

model$setClosure(c("tm", "tms", "qo", "pop"))
model$loadData(
  list(
    gtapsets = HARr::read_har("sets.har"),
    gtapdata = HARr::read_har("basedata.har"),
    gtapparm = HARr::read_har("default.prm")
  ),
  engine = "sparse"
)

# Only nonzero shocks need to be stored.
model$setShocks(setNames(
  c(1.5),
  'tms["eu27","uk"]'
))

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

Use `model$setMemoryBudget(bytes)` or `memory_budget = bytes` to make the solver fail during preflight when the estimate exceeds the available budget. `setClosure()` accepts base variable names; indexed labels belong in `setShocks()`. Existing `variableValues` initialization remains supported when `setShocks()` is omitted.

The sparse path uses Matrix sparse LU with fill-reducing ordering by default. For systems where SuperLU runs out of fill workspace, use the optional SuiteSparse/UMFPACK backend:

```r
options(GEModelR.sparse.suite_sparse_ordering = "amd")
model$solveModel(engine = "sparse", backend = "SuiteSparse")
```

The SuiteSparse ordering can be `cholmod`, `amd`, `metis`, `best`, or `natural`; it requires Rcpp and a system SuiteSparse installation. SparseM remains available as `backend = "SparseM"` for comparison. DuckDB is intentionally not a solver dependency: it may be useful for staging or aggregating HAR-derived data, but the indexed equation compiler still requires direct numeric access to the model arrays.

For the unaggregated GTAP layout, the opt-in `StructuredSchur` backend performs exact staged elimination of the local production, bilateral, and (when nonsingular) endowment blocks, then solves the remaining sparse system in block-triangular form. Singular local blocks are retained in the reduced system and reconstructed exactly after solving:

```r
model$solveModel(
  engine = "sparse",
  backend = "StructuredSchur",
  iter = 3,
  steps = c(1, 3),
  diagnostics = TRUE
)
```

Its native elimination helper is compiled during package installation, so solves do not invoke a compiler at runtime. The backend keeps the reduced system sparse, and refuses to apply a result whose true residual exceeds the configured tolerance. It is intentionally opt-in and recognizes the GTAP family layout; other TABLO models should use Matrix, SuiteSparse, or SparseM.

When the remaining BTF block is numerically difficult, use the matrix-free regional Schur backend:

```r
model$solveModel(engine = "sparse", backend = "StructuredSchurFGMRES", iter = 1, steps = 1, diagnostics = TRUE)
```

It eliminates commodity blocks exactly, preconditions the external system with condensed regional blocks and the global arrowhead, and verifies the true residual. The default structured residual guard is 2e-7 for the ill-conditioned full GTAP system; set options(GEModelR.sparse.structured_residual_tolerance = 1e-7, GEModelR.sparse.schur_tolerance = 1e-7) for a stricter check. Tune GEModelR.sparse.schur_region_batch_size, GEModelR.sparse.schur_panel_size, GEModelR.sparse.schur_restart, GEModelR.sparse.schur_max_iterations, and GEModelR.sparse.schur_refinement_iterations only after checking convergence diagnostics.

## Experimental native structured backend

The C++ acceleration remains opt-in while the R implementation is the correctness reference. It preserves the exact matrix-free operator and uses native sparse triangular solves, fused Schur accumulation, and LAPACK only for dense regional and global factors:

```r
options(GEModelR.sparse.schur_cpp_threads = 4L)
model$solveModel(
  engine = "sparse",
  backend = "StructuredSchurFGMRESCpp",
  iter = 3,
  steps = c(1, 3),
  diagnostics = TRUE
)
```

The native backend performs a registered-symbol, ABI, Matrix-factor, and thread-capability check before constructing the coefficient matrix. An unavailable or incompatible native backend fails clearly and never substitutes the R solver. The option defaults to `1L`; request more than one thread only when diagnostics report `openmp_compiled = TRUE`. On the GTAP 12a benchmark machine, panel size 64 and four threads retained most of the available parallel speedup; see [`benchmarks/GTAP12A_CPP_RESULTS.md`](benchmarks/GTAP12A_CPP_RESULTS.md).

For reproducible A/B measurements, use `benchmarks/run_gtap12a_ab.R`. It launches fresh R processes, validates input/configuration signatures, compares solutions and residuals, and exits nonzero when a numerical, memory, or performance gate fails.

For a separate-process GTAP 12a measurement, install the package and run:

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

The harness records HAR load, compilation, sparse construction/factor-solve timings, estimated triplets, peak resident memory, physical RAM, and whether a dense fallback was used.
