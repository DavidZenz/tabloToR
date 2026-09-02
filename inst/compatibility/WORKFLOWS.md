# GEModel Compatibility Workflows

This matrix gives each documented public workflow a stable identifier and an executable test case. Numerical expected values are deliberately deferred to the numerical-authority plans; this document freezes public calls, state transitions, and output structure.

## Case matrix

| ID | Setup and public calls | Expected state transition | Output descriptor | Executable test | Status |
|----|------------------------|---------------------------|-------------------|-----------------|--------|
| `WF-PREFERRED-SPARSE` | `GEModel$new() -> loadTablo() -> setClosure() -> loadData() -> setShocks() -> solveModel()` with sparse engine and Matrix backend | Empty model → parsed TABLO → `tax` closure → sparse data state → normalized named shocks → solved state | Full named numeric solution plus indexed `stock` update and `reported` post-simulation arrays | `test-documented-workflow.R`: `WF-PREFERRED-SPARSE runs the public three-region workflow` | VERIFIED |
| `WF-VARIABLEVALUES-SPARSE` | Load the sparse three-region model, assign a complete named `tax` element through `variableValues`, then solve | Complete direct values become the retained shock source; zero and missing entries are implicit | Same named solution structure as the preferred API for the same resolved shocks | `test-documented-workflow.R`: `D-03 shock APIs share normalized indexed application semantics` | VERIFIED |
| `WF-REPEATED-SOLVE` | Solve twice without replacing shocks, then clear through the same API and solve again | The retained source is applied once in each solve call; clearing yields an empty source and mutable backend state is never reused as a shock | First and retained solutions match; the cleared solution is a named zero vector for both APIs and engines | `test-documented-workflow.R`: `WF-REPEATED-SOLVE retains then clears shocks for both APIs` | VERIFIED |
| `WF-PREFERRED-LEGACY-SMOKE` | Run the public three-region workflow through omitted legacy defaults | Legacy reaches solved state through public methods only | Finite named solution and three-element public data shape; no cross-engine numerical baseline | `test-documented-workflow.R`: `WF-PREFERRED-LEGACY-SMOKE exercises only public compatibility` | VERIFIED |
| `WF-DEFAULT-OMITTED` | Omit the load/solve engine and sparse backend/selector arguments | Load and solve select legacy; sparse backend selection defaults to Matrix; omitted selectors project nothing | Structurally equal to the corresponding explicit-default calls | `test-documented-workflow.R`: `WF-DEFAULT-OMITTED and WF-DEFAULT-EXPLICIT are equivalent` | VERIFIED |
| `WF-DEFAULT-EXPLICIT` | Pass `engine = "legacy"`, `backend = "Matrix"`, and explicit `NULL` selectors | Explicit values preserve the same state transitions as omission | Same names, types, dimensions, values, and retained fields as omitted defaults | `test-documented-workflow.R`: `WF-DEFAULT-OMITTED and WF-DEFAULT-EXPLICIT are equivalent` | VERIFIED |
| `WF-FULL-OUTPUT` | Solve sparse with `output = "full"`, including omitted, empty, and singleton selectors | Full solution and post-simulation data materialize; selected projections are isolated in `compactOutput` | Named full solution, exact data ordering, and dimension-preserving singleton projection | `test-documented-workflow.R`: `WF-FULL-OUTPUT freezes full and selected structures` | VERIFIED |
| `WF-COMPACT-OUTPUT` | Solve sparse with `output = "compact"` and optional variable/dimension selectors | Compact projections and unnamed solution replace prior projections | Ordered list of selected arrays followed by compact solution; empty selectors retain only solution | `test-documented-workflow.R`: `WF-COMPACT-OUTPUT and WF-POSTSIM-OFF freeze compact structures` | VERIFIED |
| `WF-POSTSIM-OFF` | Solve sparse with `postsim = FALSE` | Numerical solution remains accepted while materialized `data` is cleared | Compact output remains available and diagnostics mark post-simulation retention false | `test-documented-workflow.R`: `WF-COMPACT-OUTPUT and WF-POSTSIM-OFF freeze compact structures` | VERIFIED |
| `WF-UNCLASSIFIED` | No additional documented workflow branch exists in the current sources | Unknown future documented steps must add a classified row and executable test | No fabricated output contract | Not executable until a source workflow is documented | FLAGGED-UNVERIFIED |

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

## Output and state rule (D-04)

Full output is a named numeric solution and, when post-simulation is enabled, a
materialized data list in deterministic model order. Compact output keeps the
solution unnamed and stores requested variable projections before `solution` in
`compactOutput`; dimensions retain array rank and dimnames even for one element.
`NULL` selectors equal omission, explicit empty selectors select no variables,
and unknown variables produce no variable projection.

Missing exogenous levels are implicit zero during equation evaluation, while
missing endogenous levels remain missing until solved. Zero, missing, and
empty-label shocks do not create explicit shock entries. Every successful solve
replaces `solution`, `data`, `compactOutput`, and diagnostics according to the
requested mode, so no selected or compact output survives a later unselected full
solve. Both engines return invisibly; legacy is smoke-only and supplies no
numerical expected values for another backend.
