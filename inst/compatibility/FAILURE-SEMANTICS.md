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

## Post-simulation transaction

The independently retryable post-simulation contract is completed in the next
task of Plan 02-04. Until then, sparse post updates remain inside the same
private working state and cannot publish partial output.
