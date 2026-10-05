# Phase 4: Public API and Solver Boundaries - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-28  
**Phase:** 4-Public API and Solver Boundaries  
**Areas discussed:** Public namespace, Backend contract, Model lifecycle boundaries, Output and diagnostics

---

## Public namespace

| Option | Description | Selected |
|---|---|---|
| Facade-first | Explicitly export `GEModel` and deliberate user-facing helpers; keep parser, compiler, solver, and native wrappers internal. | ✓ |
| Explicit compatibility surface | Replace the pattern with explicit exports for all currently reachable functions. | |
| Hybrid transition | Export the core facade plus selected existing helpers and defer the rest for deprecation. | |

| Option | Description | Selected |
|---|---|---|
| Keep them internal | Select backends through `GEModel$solveModel()` and inspect results through model diagnostics. | ✓ |
| Add a capability probe | Expose a documented helper for checking backend availability without solving. | |
| Expose low-level solvers | Document functions such as `solve_sparse_system()` for expert use. | |

| Option | Description | Selected |
|---|---|---|
| Stabilize high-level options | Document memory, tolerance, ordering, batching, and thread controls; keep transaction/fault and cache keys private. | ✓ |
| Document every existing option | Preserve all current `GEModelR.*` keys as public compatibility options. | |
| Minimize options | Move supported tuning into method arguments and retain options only internally. | |

| Option | Description | Selected |
|---|---|---|
| Hard boundary | Stop exporting former accidental exports; support only the documented workflow, with no aliases or deprecation wrappers. | ✓ |
| One-release deprecation | Retain explicit compatibility exports temporarily with warnings. | |
| Permanent compatibility exports | Keep former exports explicit but undocumented. | |

**User's choices:** Facade-first; keep advanced utilities internal; stabilize high-level options; hard boundary.
**Notes:** User selected option 1 for each question.

## Backend contract

| Option | Description | Selected |
|---|---|---|
| Stable explicit backend IDs | Retain existing backend names and make `StructuredSchurFGMRESCpp` explicit; unavailable requests fail closed. | ✓ |
| Automatic structured selection | Choose native C++ when available and structured R otherwise. | |
| New backend registry objects | Replace string selection with opaque backend handles. | |

| Option | Description | Selected |
|---|---|---|
| Fail closed before solving | Preflight before matrix construction/state mutation and report the missing capability and remediation. | ✓ |
| Fallback automatically | Use Matrix or structured R when the requested backend is unavailable. | |
| Defer failure | Initialize successfully and report an error only at the solve step. | |

| Option | Description | Selected |
|---|---|---|
| Cache structure, release numerics | Retain sparsity/order metadata but release factors, RHS buffers, and workspaces per solve. | ✓ |
| Persist numeric factors | Retain factors across solves with explicit invalidation. | |
| No persistent cache | Rebuild structure and factors on every solve. | |

| Option | Description | Selected |
|---|---|---|
| Candidate plus evidence | Return candidate, structural metadata, residual/finiteness evidence, timing, and cleanup information; central layer commits state. | ✓ |
| Solution only | Return vectors and compute all checks in the outer layer. | |
| Backend-owned lifecycle | Let each backend validate and commit its own result. | |

**User's choices:** Stable explicit backend IDs; fail closed; cache structure/release numerics; candidate plus evidence.
**Notes:** User selected option 1 for each question.

## Model lifecycle boundaries

| Option | Description | Selected |
|---|---|---|
| Method-first with narrow legacy inputs | Preserve `variableValues`, closure, and shock workflows; treat compiler/data/cache fields as internal. | ✓ |
| All fields remain compatible | Support edits to every existing field. | |
| Accessor redesign | Hide direct fields and require methods, accepting a larger compatibility break. | |

| Option | Description | Selected |
|---|---|---|
| Conservative invalidation | Closure invalidates structural state/output; shocks invalidate pending solve/postsim state while compiled structures remain. | ✓ |
| Minimal invalidation | Retain prior results until the next solve and invalidate only directly affected caches. | |
| Eager rebuild | Rebuild sparse structures immediately after setters return. | |

| Option | Description | Selected |
|---|---|---|
| Explicit engine coherence | `loadData(engine=...)` selects the runtime; `solveModel(engine=...)` must match; switching requires reload. | ✓ |
| Lazy conversion | Rebuild the requested runtime from retained source data at solve time. | |
| Dual initialization | Load both runtimes up front. | |

| Option | Description | Selected |
|---|---|---|
| Explicit state validation | Enforce prerequisites, give the next required action, and preserve prior state on failure. | ✓ |
| Permissive lazy initialization | Construct missing runtime pieces automatically. | |
| Preserve low-level behavior | Permit partial states and rely on downstream errors. | |

**User's choices:** Method-first with narrow legacy inputs; conservative invalidation; explicit engine coherence; explicit state validation.
**Notes:** User selected option 1 for each question.

## Output and diagnostics

| Option | Description | Selected |
|---|---|---|
| Strict validated selectors | Reject unknown/oversized variable and dimension selections with actionable errors. | ✓ |
| Permissive filtering | Ignore unknown names and return matching values. | |
| Warning-based filtering | Ignore unmatched selectors but emit warnings. | |

| Option | Description | Selected |
|---|---|---|
| Lazy and output-driven | Reconstruct labels only for selected compact output; full output explicitly materializes compatibility data. | ✓ |
| Always materialize labels | Attach full labels after every solve. | |
| Sparse output objects | Return sparse state/data even for full output. | |

| Option | Description | Selected |
|---|---|---|
| Stable envelope with opt-in detail | Always retain a small status/backend/result envelope; collect detailed measurements only with `diagnostics=TRUE`. | ✓ |
| Diagnostics only when requested | Keep `lastDiagnostics` empty unless requested. | |
| Always full diagnostics | Collect and retain all measurements on every solve. | |

| Option | Description | Selected |
|---|---|---|
| Structured conditions and diagnostics | Use stable condition classes and a versioned envelope with phase, status, retryability, backend, and commit state. | ✓ |
| Message-based errors | Require callers to inspect plain error messages. | |
| Diagnostics-only classification | Use generic errors and classify failures only in `lastDiagnostics`. | |

**User's choices:** Strict selectors; lazy/output-driven materialization; stable envelope with opt-in detail; structured conditions and diagnostics.
**Notes:** User selected option 1 for each question.

## the agent's Discretion

- Exact export inventory, internal registry/result-record shape, condition class names, diagnostic field names, and high-level option allowlist remain implementation choices constrained by the captured decisions and prior contracts.

## Deferred Ideas

- Portability/CI, release documentation, automatic backend selection, object-system redesign, native package extraction, and publication remain in later phases as recorded in `04-CONTEXT.md`.
