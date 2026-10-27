# Repository Guidelines

## Project Structure & Module Organization

This is an R package that parses GEMPACK-style TABLO models and solves them.

- `R/` contains the package implementation. Parsing, set/data processing, equation and coefficient generation, update handling, and model orchestration are split across focused files; `R/GEModel.R` defines the main reference-class model.
- `DESCRIPTION` and `NAMESPACE` define package metadata, exports, and dependencies.
- `README.md` contains installation and an end-to-end simulation example using `.tab` and `.har` inputs.
- `tests/testthat/` contains regression tests and small fixtures; `vignettes/` contains package guides.

## Build, Test, and Development Commands

Run these from the repository root:

```sh
R CMD check .       # Validate package structure, code, and examples
R CMD build .       # Build a source package archive
R CMD INSTALL .     # Install the local package for interactive testing
```

After installation, exercise the README workflow with a representative TABLO file and HAR data, for example `GEModelR::GEModel$new()`, `loadTablo()`, `loadData()`, and `solveModel()`. Keep external model/data files outside the repository unless they are deliberately small, redistributable fixtures.

## Coding Style & Naming Conventions

Use two-space indentation and preserve the existing base-R style: `=` assignment, short focused functions, and explicit `character`/`numeric` handling where model data require it. Use `camelCase` for functions and methods, descriptive filenames such as `processEquationStatement.R`, and `PascalCase` for class-like objects such as `GEModel`. No formatter or linter is configured; keep changes consistent with nearby code and avoid unrelated reformatting.

## Testing Guidelines

Use the existing testthat suite and run checks appropriate to the change. For parser or solver changes, run `R CMD check .` and exercise the affected path. For documentation-only changes, check the affected links/build or release policy without repeating unrelated numerical benchmarks. Add small deterministic regression fixtures under `tests/testthat/` and name tests after the behavior they protect; do not commit proprietary or oversized `.tab`/`.har` data.

## Commit & Pull Request Guidelines

Recent commits use short, present-tense subjects such as `Fixed a bug in updates` and `Improved the example description`. Follow that concise style and keep each commit focused. Pull requests should explain the behavior change, identify validation performed, include a minimal reproducible model/data description when relevant, and link an issue or discussion when one exists.

## Publication Contract

- **Development:** `DavidZenz/tabloToR` retains the full development history. Keep the existing development `origin`, branches, and local checkout intact. The published R package is named `GEModelR`; the development repository and directory may retain the `tabloToR` name.
- **Publication:** `git@github.com:DavidZenz/GEModelR.git` is the separate publication repository, using `main`. Publish reviewed source snapshots there; do not push development branches, mirror development refs, copy the development `.git` directory, or merge development history into it.
- **First publication:** Create a separate repository with one new root commit containing only the selected committed files allowed by `docs/release/public-source.json`. Verify the exact tree, absence of development commit objects and parents, and exclusion of private development records. Use `prepare`, `stage-public-source`, and `verify` as documented in `tools/release/README.md`.
- **Later publications:** Apply each reviewed snapshot to a clean checkout of the existing public history and append a public snapshot commit. Use normal fast-forward updates and retain previous public release tags. Do not force-push a fresh orphan root for each release. The current staging CLI creates the initial root only; it does not implement repeat-release parenting.
- **Published contents:** Preserve GPL-3.0-or-later licensing, required notices, attribution, and `inst/CITATION`. Include the public source, tests, and documentation selected by the explicit policy. Exclude private planning/approval/provenance evidence, credentials, proprietary GTAP inputs, and unapproved generated results. Do not copy the entire working directory or include unrelated uncommitted work.
- **Verification:** Record the selected development commit, separate public commit/tree, and built archive checksum. Build and check the selected public source, run the relevant tests and installed-package smoke check, and scan the archive/site/artifacts using the existing release tools. Keep results tied to their actual source and archive; report failures or unavailable checks accurately. Local staging or a passing structural check does not establish full release qualification.
- **Authority:** Keep publication local until the maintainer explicitly authorizes the concrete publication action. Creating the destination repository, preparing a snapshot, or adding this contract does not authorize a push, tag, release, Pages/R-universe deployment, or remote settings change. Complete local preparation before requesting any missing final authorization. Honor authorization already given in the conversation without asking again for the same action.
- **Public links:** Keep repository, issue, and planned documentation links directed at `GEModelR`. Mark source/site links pending until their contents are actually published; use bundled migration guides for working local navigation. Do not substitute development-repository links as the public destination without maintainer direction.

## Data and Generated Files

Do not commit `.RData`, `.Rhistory`, `.Rproj.user/`, build archives, or `*.Rcheck/` output; these are already ignored. Avoid adding credentials, private model inputs, or generated solver results to source control.
