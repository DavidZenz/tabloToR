# GEModelR

GEModelR parses GEMPACK-style TABLO models and solves them in R through the
`GEModel` workflow. These guides cover the first simulation, solver choices,
diagnostics, migration, and package development.

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
