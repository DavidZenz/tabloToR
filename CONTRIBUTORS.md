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
original expression. The selected package license is GPL-3.0-or-later.

### Maros Ivanic

Maros Ivanic authored the upstream `tabloToR` baseline, including the reviewed
model-loading, solve orchestration, and TABLO-processing work represented by the
evidence keys above. The upstream public response records that this work was
created as U.S. federal government work and placed in the public domain/CC0.
GEModelR credits that authorship even though attribution is not required by CC0.

## Reviewed Git identity alias

On 2026-10-27 the maintainer confirmed that `mivanicERS` and GitHub account
`MarosIvanic-USDA` identify Maros Ivanic. GitHub maps upstream commit
`78d3fc16759aa3102d566aa2bae68178498a2113` to that account, ID `67010332`.
The alias is explicitly resolved to the existing credited author; no new person
or extra package role is added. Raw Git author history is preserved.

The bundled [dependency audit](inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md)
records the compatible runtime/native license scope. Detailed source/rights
review history remains in the development repository; publication authority
and exact release qualification are separate.
