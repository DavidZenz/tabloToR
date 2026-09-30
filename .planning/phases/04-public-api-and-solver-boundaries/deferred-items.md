# Deferred Items

## Validation gate drift

- Found during: Phase 04 Plan 04-03 focused lifecycle and serialization validation.
- Issue: test-model-serialization.R fails in “migration source gate narrows only reviewed serialization source”: the Phase 02 identity map expects 328 mixed-case package-name occurrences, while the current tree contains 354; the uppercase count remains 2/2. The pre-plan source already exceeded the mapped count by 21, and Task 1 adds five GEModelR literals for the required stable condition class.
- Disposition: Preserve the reviewed Phase 02/03 identity mapping. Do not refresh its count or fingerprint as part of this lifecycle plan. Reconcile the source gate under a separately reviewed identity-baseline change.

## Existing ReferenceClass warning

- Found during: Phase 04 Plan 04-03 focused tests and documented workflow validation.
- Issue: R reports that the local assignment to data$eqcoeff in GEModel$generateSolution() does not update a ReferenceClass field (R/GEModel.R:532).
- Disposition: Pre-existing solver warning outside this plan's lifecycle and setter changes; left unchanged.
