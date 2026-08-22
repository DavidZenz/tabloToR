---
last_mapped: 2026-08-22
---

# Coding Conventions

## R Style

- Existing code uses two-space indentation in newer sparse modules, with some older legacy files less consistently formatted.
- Assignment generally uses `=` rather than `<-` in package implementation; tests use conventional `<-` more often.
- Public and legacy functions use `camelCase` (`processTablo`, `generateSolution`); sparse internals predominantly use `snake_case` with a `sparse_` prefix.
- Class-like public objects use `PascalCase`, notably `GEModel`.
- Functions prefer explicit `stop(..., call. = FALSE)` checks at API and numerical boundaries.
- Sparse code normalizes names to lower case and coerces indices/values explicitly to integer/numeric storage.

## API and Compatibility

- New behavior is opt-in: legacy engine and Matrix backend defaults are asserted in `tests/testthat/test-public-solver-contract.R`.
- Native requests fail closed when symbols, ABI, factor contracts, LAPACK, or OpenMP capabilities do not match.
- Numerical outputs are guarded by true full-system residual checks before state mutation.
- Large-system sparse paths avoid full dimnames, dense full-system conversions, and dense substep history.

## Native Style

- Rcpp exports use private names beginning `.tabloToR_`; user-facing native wrappers are not exported.
- C++ validates dimensions, storage classes, finiteness, and pointer lifecycle before work.
- OpenMP workers operate on extracted native views and buffers; R API calls and R allocations stay on the main thread.
- LAPACK resources use external pointers/finalizers and explicit release paths.

## File Organization

- One focused subsystem per R file is the prevailing pattern.
- `zzz*` prefixes intentionally control R source collation so wrappers replace reference functions after base definitions load.
- Generated Rcpp export files should be regenerated, not hand-edited.
- Tests are named `test-<behavior>.R`; reusable fixtures belong in `helper-*.R`.

## Documentation

- Markdown uses executable R/shell examples and names exact solver options.
- Large/proprietary model inputs remain external; committed fixtures must be small and deterministic.
- Package-level roxygen/man documentation is currently missing and should be introduced during GEModelR productization.
