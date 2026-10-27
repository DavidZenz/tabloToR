# GEModelR 0.1.0 (development)

## Initial public-validation candidate

- Local release preparation proposes `v0.1.0` as an annotated unsigned tag and a
  tag-pinned R-universe registry. The tag, GitHub release, and public channel are
  pending publication; no cryptographic signing or successful public installation
  is claimed.
- Version `0.1.0` becomes a public release only when the exact approved tag and
  release are actually published and recorded. Preparation, an accepted
  development phase, or the milestone name does not create that boundary or
  imply `1.0.0` stability.
- The legacy engine and Matrix sparse-backend defaults are unchanged; native
  structured acceleration remains opt-in. Migration instructions cover the
  GEModelR namespace, options, and portable logical state.
- Exact-archive qualification, supported-runtime serialization, hosted Windows
  provenance evidence, and a current matched full-scale benchmark remain
  unverified for this candidate. Existing component and C++ scaling observations
  are not guaranteed end-to-end performance gains. Benchmark preflight report
  redaction and reference-file binding remain known tooling limitations.
- A proposed initial support cadence is recorded in governance for maintainer
  review, with no guaranteed response time or release schedule.

## Provenance and release boundary

- Maros Ivanic authored the upstream `tabloToR` baseline; David Zenz authored the
  reviewed post-baseline sparse compiler, solver, and native structured-solver
  work. The predecessor baseline is credited under its reviewed
  public-domain/CC0 basis.
- The selected license is GPL-3.0-or-later; package metadata declares
  `GPL (>= 3)`.
- Version 0.1.0 remains a development version and is not a public release. Before
  1.0.0, minor releases may include documented breaking changes and patch
  releases carry compatible fixes. After 1.0.0, Semantic Versioning applies:
  patches are compatible, minors add backward-compatible functionality, and
  majors may change documented interfaces incompatibly.
- Dependency/native compatibility has been audited and the maintainer has
  confirmed the upstream Git identity alias. Public release remains pending
  artifact qualification and actual publication; no channel is claimed live.

## Reviewed source attribution

Evidence-Key: R/GEModel.R::GEModel$loadTablo
Evidence-Key: R/GEModel.R::GEModel$solveModel
Evidence-Key: R/processTablo.R::processTablo
Evidence-Key: R/sparseCompiler.R::sparse_compile_spec
Evidence-Key: R/sparseSolver.R::sparse_solve_model
Evidence-Key: src/sparse-schur.cpp::GEModelR_schur_accumulate_global

Attribution-Role: David Zenz|aut,cre,cph
Attribution-Role: Maros Ivanic|aut
