# Package `tabloToR`

A package that can interpret GEMPACK-style TABLO models in R and solve them

# To install, you can try the following: 

```R
install.packages('devtools')
devtools::install_git('https://github.com/mivanic/tabloToR.git')
```

# To perform a simulation, you can try the following:

```R
model = tabloToR::GEModel$new()

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
model <- tabloToR::GEModel$new()
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

The sparse path uses Matrix sparse LU with fill-reducing ordering. SparseM remains available as `backend = "SparseM"` for comparison. DuckDB is intentionally not a solver dependency: it may be useful for staging or aggregating HAR-derived data, but the indexed equation compiler still requires direct numeric access to the model arrays.

For a separate-process GTAP 12a measurement, install the package and run:

```sh
Rscript benchmarks/benchmark_gtap12a.R \
  --data-dir="/path/to/gtap12a" \
  --tablo="/path/to/gtapv7.tab" \
  --closure-file="/path/to/closure.rds" \
  --steps="1,3"
```

The harness records HAR load, compilation, sparse construction/factor-solve timings, estimated triplets, peak resident memory, physical RAM, and whether a dense fallback was used.
