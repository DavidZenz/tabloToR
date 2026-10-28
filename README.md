<!-- generated-by: gsd-doc-writer -->
# GEModelR

GEModelR parses GEMPACK-style TABLO models and solves them in R. Its sparse
engine and supported structured-R solvers target full-scale GTAP-family
workloads. The established `GEModel` API remains compatible with the legacy
in-memory engine for smaller workloads, but that engine is not a practical path
for solving the whole GTAP model and data.

The package is licensed under GPL-3.0-or-later. It builds on the reviewed
public-domain/CC0 `tabloToR` baseline authored by Maros Ivanic; David Zenz
maintains GEModelR and authored its sparse and native solver work.

## Install

The GEModelR 0.1.0 package is available from R-universe:

```r
install.packages(
  "GEModelR",
  repos = c(
    GEModelR = "https://davidzenz.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
```

Check the [R-universe package page](https://davidzenz.r-universe.dev/GEModelR)
for current platform build availability. To build the current source from
GitHub, install `remotes` and use:

```r
install.packages("remotes")
remotes::install_github("DavidZenz/GEModelR", ref = "main")
```

Source installation requires a working compiler toolchain for your R and
platform. Package dependencies are listed in `DESCRIPTION` and are installed
by standard R package installation tools. Package metadata declares R >= 3.5.0
and Matrix >= 1.6-5. Current tested Matrix support: 1.6-5 through 1.7-6,
with combinations varying by R version and platform. See the [backend-selection guide](vignettes/backend-selection.Rmd)
and [current GitHub Actions checks](https://github.com/DavidZenz/GEModelR/actions)
for compatibility details.

## Start here

The [first-simulation guide](vignettes/first-simulation.Rmd) is the quickest
way to try GEModelR. It creates a small model and input arrays locally, so it
needs no external HAR files or GTAP dataset. After installation, open the
installed guides with:

```r
browseVignettes("GEModelR")
```

For package help, use `help(package = "GEModelR")` or
`?GEModelR::GEModel`.

## Engines and solver backends

The `GEModel` object loads TABLO text and model data, applies a closure and
shocks, and runs a simulation. For API compatibility, `loadData()` still
defaults to the legacy engine; it remains useful for smaller models and
existing workflows. Its in-memory approach is not practical for the full GTAP
workload. Use `engine = "sparse"` for full-scale GTAP, with a supported
structured-R backend when the model has a recognized GTAP-family block layout.
Use the same engine in `loadData()` and `solveModel()`.

| Choice | Intended use |
| --- | --- |
| `engine = "sparse", backend = "Matrix"` | Supported general-purpose sparse solver and default sparse backend. |
| `backend = "StructuredSchur"` or `"StructuredSchurFGMRES"` | Supported structured-R methods for recognized GTAP-family layouts and the intended route for full-scale GTAP solves. |
| `engine = "legacy"` | API default for compatibility and smaller workloads; not practical for the whole GTAP workload. |
| `backend = "SparseM"` | Recognized for compatibility; not a currently supported solver choice. |
| `backend = "StructuredSchurFGMRESCpp"` | Compatibility-only identifier, not a supported solver choice. C++ sparse-kernel optimization remains development and qualification work. |

`SuiteSparse` is recognized as a backend identifier but is unavailable in the
supported installed builds. Explicit backend requests fail capability checks
rather than silently switching to a different solver. See the
[backend-selection guide](vignettes/backend-selection.Rmd) for details and
examples. The [diagnostics and memory guide](vignettes/diagnostics-memory-budgeting.Rmd)
covers memory estimates, budgets, compact output, and solve diagnostics. Native
C++ kernels support low-level sparse operations; the separate C++ FGMRES solver
remains compatibility-only. Current component measurements do not establish
package-wide or end-to-end GTAP speedups.

## Guides

- [Run a first simulation](vignettes/first-simulation.Rmd) with a self-contained fixture.
- [Migrate from `tabloToR`](vignettes/legacy-to-sparse.Rmd) and read the detailed [migration reference](MIGRATION.md).
- [Choose a solver backend](vignettes/backend-selection.Rmd).
- [Estimate memory and inspect diagnostics](vignettes/diagnostics-memory-budgeting.Rmd).
- [Read the full-scale benchmarking guide](vignettes/external-full-scale-benchmarking.Rmd) for development and qualification procedures. It requires external model data; component measurements are not package-wide or end-to-end speedup claims.
- [Understand the package architecture](vignettes/architecture.Rmd).
- [Contribute changes](vignettes/contributing.Rmd).

The pkgdown site is configured but has not yet been deployed. The current
documentation workflow builds and scans the site artifact without publishing
it. Until deployment, use the installed vignettes or open the guide files above
in the repository. GTAP input files and full-scale model results are not
included with the package.

## Citation and support

Please acknowledge and cite GEModelR when you use it in research or other
published work. `citation("GEModelR")` returns the recommended package and
predecessor citations. These citation and disclosure requests do not add
conditions to the GPL license.

Report bugs and request features in the
[GEModelR issue tracker](https://github.com/DavidZenz/GEModelR/issues). For
private security reports, contact the maintainer listed in `DESCRIPTION`.
