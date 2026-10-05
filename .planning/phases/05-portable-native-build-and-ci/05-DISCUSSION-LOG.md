# Phase 05: Portable Native Build and CI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-01
**Phase:** 05-Portable Native Build and CI
**Areas discussed:** CI matrix and timing, OpenMP coverage, Matrix compatibility range, SuiteSparse boundary

---

## CI matrix and timing

1. **Which CI coverage should block every pull request?**
   - Tiered: serial/core checks on all three OS for every PR; broader version and OpenMP matrix on schedule
   - **Selected:** Full: all supported OS, R, Matrix, and OpenMP combinations on every PR
   - Lean: Linux PR gate; macOS and Windows run on schedule

2. **What should each full-matrix CI cell run?**
   - **Selected:** Install and core tests in every cell; run full R CMD check in a representative cell
   - Full R CMD check in every cell
   - Install and core tests only; reserve R CMD check for release qualification

3. **Should CI rerun the full matrix on default-branch pushes?**
   - **Selected:** Yes, on pull requests and default-branch pushes
   - No, on pull requests only
   - Run on every branch push

4. **Should CI run a periodic full matrix too?**
   - **Selected:** Yes, weekly as a non-PR drift check
   - No, only on pull requests and default-branch pushes
   - Yes, nightly, with failures reported as required

**Notes:** The complete matrix means all supported and installable combinations; full package checks are reserved for one representative cell.

---

## OpenMP coverage

1. **Which platforms should have a required OpenMP-enabled CI job?**
   - **Selected:** Every platform whose supported R toolchain offers OpenMP; serial coverage remains on all three
   - Linux and macOS; Windows remains serial
   - Linux only; macOS and Windows remain serial

2. **Which thread counts should OpenMP CI exercise and compare with serial results?**
   - **Selected:** Serial and 2 threads
   - Serial, 2 threads, and the runner's reported maximum within configured bounds
   - Every thread count from 1 through the runner's maximum

3. **How should expected OpenMP jobs handle a missing OpenMP capability?**
   - **Selected:** Fail when an expected OpenMP job lacks capability; skip only explicitly serial jobs
   - Report a skip and keep the job green
   - Fail only on Linux; allow skips on macOS and Windows

4. **Should OpenMP CI gate on performance?**
   - **Selected:** Gate capability, bounds, and serial equivalence; report timing without a speed threshold
   - Require a minimum two-thread speedup over serial
   - Collect no timing in CI; measure performance only in separate benchmarks

**Notes:** The public C++ thread default remains one. Multi-thread requests in serial builds continue to fail clearly.

---

## Matrix compatibility range

1. **How broad should GEModelR's supported Matrix version range be?**
   - **Selected:** Set a minimum and test it plus current Matrix; the minimum must run on the oldest supported R
   - Support each R job's default Matrix version only
   - Support the latest Matrix release only

2. **How should we choose the minimum Matrix version?**
   - **Selected:** The oldest Matrix release installable on the oldest supported R
   - The oldest actively maintained Matrix release that works across supported R versions
   - R's default Matrix version for oldrel

3. **What should the Matrix support promise cover between the tested versions?**
   - **Selected:** Every Matrix version from the minimum through current
   - Only the tested minimum and current versions; other versions are best-effort
   - Only Matrix versions paired with each supported R release

4. **How should the Matrix minimum change over time?**
   - **Selected:** Track the oldest Matrix release installable on the oldest supported R; update when that R support window advances
   - Keep the minimum fixed until an explicit support-policy review
   - Raise the minimum whenever an older Matrix CI job becomes difficult to maintain

---

## SuiteSparse boundary

1. **How should installed SuiteSparse requests behave in Phase 05?**
   - **Selected:** Keep the backend ID, but fail clearly with a capability error until portable support exists
   - Keep runtime compilation only behind an explicit maintainer/development-only path; installed workflows fail closed

2. **What should the SuiteSparse capability error recommend?**
   - **Selected:** Name the unavailable backend and explicitly suggest Matrix as an alternative, with no automatic fallback
   - Name the unavailable backend and explain the portable-build limitation without recommending an alternative

3. **How should Phase 05 backend docs present SuiteSparse?**
   - **Selected:** List it as a recognized backend that is unavailable in supported installed builds pending portable support
   - Keep it out of the supported-backend list; the explicit error explains the limitation

4. **How should CI verify SuiteSparse stays unavailable without runtime compilation?**
   - **Selected:** Assert in every platform job that explicit requests fail before runtime compilation
   - Assert this in one representative platform job; other jobs verify package installation
   - No dedicated test; rely on general backend capability checks

**Notes:** Phase 04 keeps explicit backend identities and fail-closed preflight. Portable direct SuiteSparse support remains outside this phase.

---

## the agent's Discretion

- Exact CI job implementation, runner labels, compatible R/Matrix pairings, and the representative full R CMD check cell.
- Exact Matrix endpoint versions once compatibility with the oldest supported R is verified.
- The test mechanism that proves SuiteSparse requests do not start a runtime compiler.

## Deferred Ideas

- Portable direct SuiteSparse integration remains deferred per the project’s v2 boundary.
- Long full-scale benchmark execution remains outside routine CI.

