# Deferred Items

## 03-02

- `R CMD check .` still reports pre-existing repository warnings for compiled
  artifacts, hidden/non-portable files, license metadata, undocumented exports,
  and LazyData. Its test stage also has two pre-existing source-only benchmark
  harness failures because top-level benchmark scripts are absent in the check

## 03-07

- `R CMD check .` installs and loads GEModelR, but the full installed test stage
  remains blocked by pre-existing source-check contamination and active helper
  identity/source-path failures assigned to Plan 03-09. The 03-07 focused
  serialization/identity suite passes, as do the approved-digest,
  migration-source, and historical-only gates.
