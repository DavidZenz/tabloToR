# Phase 2: Compatibility and Numerical Baseline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-02
**Phase:** 2-Compatibility and Numerical Baseline
**Areas discussed:** Compatibility boundary, Numerical authority, Fixture and artifact portfolio, Failure and state semantics

---

## Compatibility boundary

| Question | Selected | Alternatives considered |
|----------|----------|-------------------------|
| Surface to freeze | Explicit supported contract | Everything reachable; workflow only |
| Manifest classification | Supported / compatibility-only / internal | Two tiers; equal support for all enumerated behavior |
| Closure/shock workflows | Guarantee both; prefer `setClosure()`/`setShocks()` | Equal status; legacy-only guarantee |
| Output compatibility | Full structural contract plus tolerant numeric comparison | Names/values only; numeric equivalence only |

**User's choice:** Accepted all recommended options.
**Notes:** Preserve `variableValues` exactly while positioning the explicit setters as the preferred workflow.

---

## Numerical authority

| Question | Selected | Alternatives considered |
|----------|----------|-------------------------|
| Reference hierarchy | Matrix for generic sparse; structured R for C++; independent true residual for every result | Legacy oracle; C++ oracle; pairwise consensus |
| Tolerances | Fixture/conditioning tiers | Universal tolerance; backend-specific tolerances |
| Equivalence gate | Structure, finiteness, absolute/relative solution comparison, and true residual | Residual only; solution comparison only |
| Missing capabilities | Required/optional declarations with explicit tested skips | Require all backends everywhere; opportunistic comparison |

**User's choice:** Initially stated that legacy is not numerically relevant and that sparse/C++ are the production direction, then accepted the revised layered sparse/C++ recommendation.
**Notes:** Legacy remains only a small-fixture public-workflow compatibility check.

---

## Fixture and artifact portfolio

| Question | Selected | Alternatives considered |
|----------|----------|-------------------------|
| Canonical models | Layered tiny, synthetic three-region, conditionally redistributable SmallAg, and external GTAP portfolio | Synthetic-only; reduced GTAP in routine checks |
| Committed artifacts | Compact transparent fingerprints, metadata, structures, selected values, and tolerances | Full serialized results; no golden values |
| Baseline changes | Deterministic reviewed refresh with old/new diff | Automatic rewrites; direct manual editing |
| Execution tiers | Tiny/synthetic in ordinary checks; SmallAg extended; GTAP external release gate | All models every check; algebraic-only checks |

**User's choice:** Accepted all recommended options.
**Notes:** SmallAg/debug enters committed or extended tests only after redistribution is verified.

---

## Failure and state semantics

| Question | Selected | Alternatives considered |
|----------|----------|-------------------------|
| Numerical failure | Transactional caller-visible state with failure diagnostics only | Preserve partial progress; clear prior state |
| Post-simulation failure | Preserve accepted numerical solve and permit retry | Roll back solve; expose partial postsimulation |
| Serialization | Portable logical state; rebuild native runtime resources | Serialize pointers/factors; configuration only |
| Repeated solves/shocks | Characterize then unify both workflows under one rule | Mandate idempotent; mandate cumulative; preserve divergence |

**User's choice:** Accepted all recommended options.
**Notes:** Unintended shock-application divergence is repaired before baseline acceptance rather than frozen.

---

## the agent's Discretion

- Exact compatibility-manifest schema and test-file organization.
- Exact strict and ill-conditioned thresholds after characterization.
- Reviewable baseline file formats and fingerprint implementation.
- Portable serialization and memory-safe transactional-state mechanism.

## Deferred Ideas

- Package identity migration, API narrowing, portability/CI, release qualification, and publication remain assigned to later roadmap phases.
