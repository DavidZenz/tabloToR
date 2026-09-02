# GEModel Compatibility Workflows

This matrix gives each documented public workflow a stable identifier and an executable test case. Numerical expected values are deliberately deferred to the numerical-authority plans; this document freezes public calls, state transitions, and output structure.

## Case matrix

| ID | Setup and public calls | Expected state transition | Output descriptor | Executable test | Status |
|----|------------------------|---------------------------|-------------------|-----------------|--------|
| `WF-PREFERRED-SPARSE` | `GEModel$new() -> loadTablo() -> setClosure() -> loadData() -> setShocks() -> solveModel()` with sparse engine and Matrix backend | Empty model → parsed TABLO → `tax` closure → sparse data state → normalized named shocks → solved state | Full named numeric solution plus indexed `stock` update and `reported` post-simulation arrays | `test-documented-workflow.R`: `WF-PREFERRED-SPARSE runs the public three-region workflow` | VERIFIED |

## Fixture boundary

`tests/testthat/fixtures/three-region.tab` is the only model used by this case. It is newly authored, CC0-1.0, deterministic, and contains no GTAP, SmallAg, private-model, or proprietary-data content. The input list is constructed by `three_region_input_data()` and the workflow uses public `GEModel` methods for setup and execution.

## Numerical authority

Matrix is the generic sparse reference. The legacy engine is reserved for a narrow public-workflow smoke check and must not supply numerical expected values or override Matrix or structured-R authority.
