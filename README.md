<!-- generated-by: gsd-doc-writer -->
# GEModelR

GEModelR parses GEMPACK-style TABLO models and solves them in R. It preserves
the established `GEModel` workflow and adds an opt-in sparse engine for models
that need a lower-memory solve.

The package is licensed under GPL-3.0-or-later. It builds on the reviewed
public-domain/CC0 `tabloToR` baseline authored by Maros Ivanic; David Zenz
maintains GEModelR and authored its reviewed post-baseline sparse and native
solver work.

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
by standard R package installation tools.

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
shocks, and runs a simulation. The legacy engine remains the default. Choose
`engine = "sparse"` when initializing data for sparse execution.

| Choice | Intended use |
| --- | --- |
| `engine = "legacy"` | Existing in-memory solver workflow and compatibility. |
| `engine = "sparse", backend = "Matrix"` | Supported general sparse solver and a good starting point for sparse execution. |
| `backend = "StructuredSchur"` or `"StructuredSchurFGMRES"` | Supported structured R methods for models with recognized block layouts. |
| `backend = "SparseM"` or `"StructuredSchurFGMRESCpp"` | Recognized for compatibility; these are not currently supported solver choices. |

`SuiteSparse` is recognized as a backend identifier but is unavailable in the
supported installed builds. Explicit backend requests fail capability checks
rather than silently switching to a different solver. See the
[backend-selection guide](vignettes/backend-selection.Rmd) for details and
examples. The [diagnostics and memory guide](vignettes/diagnostics-memory-budgeting.Rmd)
covers memory estimates, budgets, compact output, and solve diagnostics.

## Guides

- [Run a first simulation](vignettes/first-simulation.Rmd) with a self-contained fixture.
- [Migrate from `tabloToR`](vignettes/legacy-to-sparse.Rmd) and read the detailed [migration reference](MIGRATION.md).
- [Choose a solver backend](vignettes/backend-selection.Rmd).
- [Estimate memory and inspect diagnostics](vignettes/diagnostics-memory-budgeting.Rmd).
- [Read about development full-scale benchmarking](vignettes/external-full-scale-benchmarking.Rmd); its experimental candidate is not a supported production backend.
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
