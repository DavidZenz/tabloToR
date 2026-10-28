# GEModelR

GEModelR parses GEMPACK-style TABLO models and solves them in R through the
`GEModel` workflow. These guides cover the first simulation, solver choices,
diagnostics, migration, and package development.

## Full-scale models

For full-size, unaggregated GTAP data, select the sparse runtime when loading
model data. The legacy in-memory engine remains the API default for compatibility
and smaller models, but it was not practical for the complete GTAP workload used
in this project. The supported `Matrix` backend handles general sparse systems;
the structured R backends are intended for recognized GTAP-family layouts.

Native C++ kernels optimize sparse operations. The separately named
`StructuredSchurFGMRESCpp` backend is compatibility-only, and its A/B benchmark
is development and qualification material rather than a production solver
recommendation.

## Start here

- [Run your first simulation](articles/first-simulation.html)
- [Choose a solver backend](articles/backend-selection.html)
- [Migrate from `tabloToR`](articles/legacy-to-sparse.html)

## Guides

- [Move from legacy to sparse execution](articles/legacy-to-sparse.html)
- [Diagnostics and memory budgeting](articles/diagnostics-memory-budgeting.html)
- [External full-scale benchmarking](articles/external-full-scale-benchmarking.html)
- [Architecture](articles/architecture.html)
- [Contributing](articles/contributing.html)

Browse the [package reference](reference/index.html) for the documented API.

The GEModelR source is publicly available from the
[canonical GitHub repository](https://github.com/DavidZenz/GEModelR). Install
the package from R-universe with:

```r
install.packages(
  "GEModelR",
  repos = c(
    GEModelR = "https://davidzenz.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
```

The pkgdown site is configured for GitHub Pages but has not yet been deployed.
Until deployment, the installed package vignettes are available with
`browseVignettes("GEModelR")`.
