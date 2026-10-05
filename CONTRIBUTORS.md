# Contributors

## Evidence threshold

A person is listed only when reviewed provenance, rights, and governance
evidence supports a substantive contribution or package role. Commit counts,
Git author strings, local configuration, and repository access do not create an
authorship, contributor, copyright-holder, or maintainer claim.

Attribution-Role: David Zenz|aut,cre,cph
Attribution-Role: Maros Ivanic|aut

Evidence-Key: R/GEModel.R::GEModel$loadTablo
Evidence-Key: R/GEModel.R::GEModel$solveModel
Evidence-Key: R/processTablo.R::processTablo
Evidence-Key: R/sparseCompiler.R::sparse_compile_spec
Evidence-Key: R/sparseSolver.R::sparse_solve_model
Evidence-Key: src/sparse-schur.cpp::GEModelR_schur_accumulate_global

## Reviewed contributors

### David Zenz

David Zenz authored the reviewed post-baseline sparse compiler, solver, and
native structured-solver work represented by the evidence keys above. He is the
approved v1 maintainer and release authority. His `aut`, `cre`, and `cph` roles
are defined in `docs/provenance/ATTRIBUTION.md`; the `cph` role covers reviewed
original expression and does not finalize the package license.

### Maros Ivanic

Maros Ivanic authored the upstream `tabloToR` baseline, including the reviewed
model-loading, solve orchestration, and TABLO-processing work represented by the
evidence keys above. The upstream public response records that this work was
created as U.S. federal government work and placed in the public domain/CC0.
GEModelR credits that authorship even though attribution is not required by CC0.

## Unresolved identities

The Git-derived label `mivanicERS` is not listed as a separate person and is not
silently merged into another identity. Its status remains
`ATTRIBUTION_IDENTITY_UNRESOLVED` until reviewed public evidence resolves it.

For the complete evidence-to-role mapping, inventory snapshot, and privacy
boundary, see `docs/provenance/ATTRIBUTION.md`. For the accepted upstream rights
basis and redistribution scope, see `docs/provenance/RIGHTS.md`.
