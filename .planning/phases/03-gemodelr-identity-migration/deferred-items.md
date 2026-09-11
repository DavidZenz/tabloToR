# Deferred Items

## 03-02

- `R CMD check .` still reports pre-existing repository warnings for compiled
  artifacts, hidden/non-portable files, license metadata, undocumented exports,
  and LazyData. Its test stage also has two pre-existing source-only benchmark
  harness failures because top-level benchmark scripts are absent in the check
