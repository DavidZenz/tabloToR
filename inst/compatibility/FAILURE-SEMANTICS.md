# Solve Failure and Transaction Semantics

This document defines the caller-visible state contract for solve failures. It
is normative for the compatibility and numerical baseline and does not change
the package's equations, solver algorithms, or numerical tolerances.

## Sparse numerical transaction

A sparse solve runs against a private working environment. Its `data` list and
numeric arrays use R copy-on-write behavior, while rebuilt index and cache
metadata remain local to the call. The live `GEModel` is not used as rollback
storage.

Compilation, factorization, candidate finiteness, true-residual acceptance,
substep application, and simulation updates all happen before the single
`.commit_accepted_state()` boundary. If any of those phases fails, closure,
shock inputs, levels, applied work, solution, complete output, and sparse cache
metadata retain their pre-call values. `lastDiagnostics` is the sole permitted
change and records:

- `status = "failed"`;
- `accepted_numerical_state = FALSE`;
- `retryable_postsim = FALSE`;
- `failure_phase` and `failure_reason`.

After all numerical acceptance gates pass, `.commit_accepted_state()` publishes
the complete sparse state exactly once. A completed diagnostics record uses
`status = "complete"` and `accepted_numerical_state = TRUE`.

## Legacy numerical transaction

Legacy execution uses a deep reference-class copy. Shock resolution, coefficient
generation, factorization, convergence/finiteness/residual gates, level changes,
and simulation updates mutate only that copy. A failure at any boundary leaves
the original closure, both shock sources, levels, solution, output, diagnostics,
and derived state unchanged except for the structured failure diagnostics.

After every boundary succeeds, `.commit_legacy_state()` publishes the accepted
copy once. A failed call does not consume either `setShocks()` input or direct
`variableValues`; retrying `solveModel()` therefore applies the same retained
source once under the D-17 rule.

## Post-simulation transaction

Sparse numerical acceptance and post-simulation publication are separate
transactions. Once all numerical gates pass, `.commit_accepted_state()`
publishes solved levels, solution, numerical diagnostics, and a private retry
record containing accepted state plus the original `postsim`, `output`,
`variables`, and `dimensions` inputs. Existing complete `data` and
`compactOutput` remain untouched at this boundary.

Post updates and output projection run against a fresh working environment. On
complete success, `.commit_postsim_state()` publishes the post state and output
together and clears the retry record. On failure:

- accepted solved levels and the solution remain available;
- the last complete `data` and `compactOutput` remain unchanged;
- `status = "postsim-incomplete"`;
- `accepted_numerical_state = TRUE`;
- `retryable_postsim = TRUE`;
- `failure_phase` distinguishes `post-update`, `output-projection`, and
  `commit-postsim-state`.

`model$retryPostsim(diagnostics = FALSE)` starts from the stored accepted state
and immutable post inputs. Each attempt gets a new working environment, so a
failed retry cannot expose partial updates. A successful retry publishes the
complete post state/output and sets status to `complete` when diagnostics are
requested. The retry never compiles, factorizes, iterates, solves, or reapplies
numerical shocks. Without a valid retry record it errors before entering any
solver or post-simulation stage.
