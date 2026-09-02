# GEModel Compatibility Workflows

This matrix gives each documented public workflow a stable identifier and an executable test case. Numerical expected values are deliberately deferred to the numerical-authority plans; this document freezes public calls, state transitions, and output structure.

## Case matrix

| ID | Setup and public calls | Expected state transition | Output descriptor | Executable test | Status |
|----|------------------------|---------------------------|-------------------|-----------------|--------|
| `WF-PREFERRED-SPARSE` | `GEModel$new() -> loadTablo() -> setClosure() -> loadData() -> setShocks() -> solveModel()` with sparse engine and Matrix backend | Empty model → parsed TABLO → `tax` closure → sparse data state → normalized named shocks → solved state | Full named numeric solution plus indexed `stock` update and `reported` post-simulation arrays | `test-documented-workflow.R`: `WF-PREFERRED-SPARSE runs the public three-region workflow` | VERIFIED |
| `WF-VARIABLEVALUES-SPARSE` | Load the sparse three-region model, assign a complete named `tax` element through `variableValues`, then solve | Complete direct values become the retained shock source; zero and missing entries are implicit | Same named solution structure as the preferred API for the same resolved shocks | `test-documented-workflow.R`: `D-03 shock APIs share normalized indexed application semantics` | VERIFIED |
| `WF-REPEATED-SOLVE` | Solve twice without replacing shocks, then clear through the same API and solve again | The retained source is applied once in each solve call; clearing yields an empty source and mutable backend state is never reused as a shock | First and retained solutions match; the cleared solution is a named zero vector for both APIs and engines | `test-documented-workflow.R`: `WF-REPEATED-SOLVE retains then clears shocks for both APIs` | VERIFIED |

## Fixture boundary

`tests/testthat/fixtures/three-region.tab` is the only model used by this case. It is newly authored, CC0-1.0, deterministic, and contains no GTAP, SmallAg, private-model, or proprietary-data content. The input list is constructed by `three_region_input_data()` and the workflow uses public `GEModel` methods for setup and execution.

## Numerical authority

Matrix is the generic sparse reference. The legacy engine is reserved for a narrow public-workflow smoke check and must not supply numerical expected values or override Matrix or structured-R authority.

## Shock application and consumption rule (D-03/D-17)

Normalized named shocks are retained until the caller replaces or clears their
source, and are applied exactly once during each solve call. `setShocks()` is the
preferred source; complete `variableValues` element assignment remains supported.
Zero values, `NA` values, and empty labels are implicit and contribute no shock.
Duplicate labels that identify the same indexed element after quote and whitespace
normalization sum deterministically; scalar `name[]` and multi-index labels retain
their declared arity.

A later solve without a replacement reuses the retained public source. Calling
`setShocks()` with only implicit values, or replacing `variableValues` with an
empty list, clears that source. Current sparse-state levels are never inferred as
new shocks. Subassignment into a missing `variableValues` element creates partial
positional input and is not equivalent to assigning a complete indexed element.
