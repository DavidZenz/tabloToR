# tabloToR 0.1.0 (development)

## Provenance and release boundary

Attribution-Role: David Zenz|aut,cre,cph
Attribution-Role: Maros Ivanic|aut

Evidence-Key: R/GEModel.R::GEModel$loadTablo
Evidence-Key: R/GEModel.R::GEModel$solveModel
Evidence-Key: R/processTablo.R::processTablo
Evidence-Key: R/sparseCompiler.R::sparse_compile_spec
Evidence-Key: R/sparseSolver.R::sparse_solve_model
Evidence-Key: src/sparse-schur.cpp::tabloToR_schur_accumulate_global

- Established a deterministic 250-key provenance inventory for the package's R
  and native source surface.
- Credited Maros Ivanic for the upstream `tabloToR` baseline under the reviewed
  public-domain/CC0 evidence, while retaining stable source keys for the cited
  model-loading, solve, and TABLO-processing work.
- Credited David Zenz for the reviewed post-baseline sparse compiler, solver,
  and native structured-solver work and recorded his approved maintainer role.
- Kept the package name `tabloToR` and package license unresolved. Apache-2.0 is
  provisional for original post-baseline code pending the dependency
  compatibility audit; this entry does not authorize a release or publication.

See `docs/provenance/ATTRIBUTION.md`, `docs/provenance/PROVENANCE.csv`, and
`docs/provenance/RIGHTS.md` for the evidence and scope behind these credits.
