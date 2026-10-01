# Phase 05: Portable Native Build and CI - Context

**Gathered:** 2026-10-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Make GEModelR install and run its supported native solver predictably on Linux, macOS, and Windows, both with and without OpenMP. Establish a required CI matrix across supported R, Matrix, platform, and native build variants. Every supported installed solve path must avoid runtime compilation and hard-coded Linux SuiteSparse paths.

Keep the established one-thread default, the opt-in C++ backend, explicit backend selection, and fail-closed capability checks. Do not add portable direct SuiteSparse integration in this phase; that remains deferred work. Long full-scale benchmarks remain external to routine CI.

</domain>

<decisions>
## Implementation Decisions

### CI matrix and gates

- **D-01:** Run the full set of supported platform, R, Matrix, and serial/OpenMP combinations on every pull request. Run the same supported matrix on default-branch pushes and weekly. Only installable and supported R/Matrix pairings are valid matrix cells.
- **D-02:** Every matrix cell installs the package and runs core tests. Run full `R CMD check` in one representative cell. The exact representative cell and how it reports the currently documented package-check findings are for planning to resolve; report the result accurately.
- **D-03:** R jobs cover release, oldrel, and devel as scoped by the roadmap. Long full-scale benchmarks stay outside routine CI.

### OpenMP coverage

- **D-04:** Require an OpenMP-enabled build on every platform where the supported R toolchain offers OpenMP; maintain serial-build coverage on all three operating systems.
- **D-05:** Compare serial and two-thread native results. Expected OpenMP jobs fail if the built package reports OpenMP unavailable. Explicitly serial jobs may skip OpenMP-only tests.
- **D-06:** Verify capability reporting, effective thread bounds, and numerical equivalence. CI reports measured timing but does not gate on a speedup threshold.
- **D-07:** Preserve the one-thread default. Requests for more than one thread on a serial build continue to fail clearly; no automatic backend or thread substitution is introduced.

### Matrix compatibility

- **D-08:** Define a supported Matrix range with a minimum and current endpoint. The minimum is the oldest Matrix release installable on the oldest supported R version.
- **D-09:** The support promise covers every Matrix version from the minimum through current. CI explicitly tests the minimum and current endpoints in supported R/platform pairings.
- **D-10:** Advance the minimum when the oldest supported R window advances, choosing the oldest Matrix release still installable on that R.

### SuiteSparse installed boundary

- **D-11:** Keep `SuiteSparse` as a recognized explicit backend ID. In supported installed workflows, an explicit request fails with a clear capability error until portable support exists. The request must not invoke runtime compilation or silently switch to Matrix.
- **D-12:** The capability error names SuiteSparse and recommends explicitly selecting `backend="Matrix"` as the available alternative.
- **D-13:** Backend documentation lists SuiteSparse as recognized but unavailable in supported installed builds pending portable support.
- **D-14:** Every platform CI job asserts that an explicit SuiteSparse request fails before runtime compilation.

### the agent's Discretion

- Select the actual Matrix endpoint versions and supported R/Matrix pairings after checking current compatibility and installation availability.
- Choose the representative full `R CMD check` cell and job reporting details. The Phase 04 verification report records known package-check failures; do not present them as resolved by the Phase 05 portability matrix.
- Choose the exact CI workflow layout, build flags, and test mechanism, provided the requirements above remain explicit and serial/OpenMP capabilities are verified rather than inferred from a green skip.
- Preserve the Phase 04 contract for structured capability errors: identify the requested backend, cause, and remediation before matrix construction or model-state mutation.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and acceptance requirements

- `.planning/PROJECT.md` — Package direction, portability constraints, backend policy, and the v2 boundary for direct SuiteSparse support.
- `.planning/REQUIREMENTS.md` — PORT-01, PORT-02, PORT-03, and CI-01 acceptance requirements.
- `.planning/ROADMAP.md` — Phase 05 goal and success criteria. No Phase 05-specific canonical refs are listed there.

### Prior solver and API contracts

- `.planning/phases/04-public-api-and-solver-boundaries/04-CONTEXT.md` — Stable backend IDs, fail-closed preflight, diagnostics, the one-thread default, and OpenMP option contract.
- `.planning/codebase/STACK.md` — R, Matrix, Rcpp, native build setup, and current optional SuiteSparse dependency.
- `.planning/codebase/ARCHITECTURE.md` — Native solver flow and Matrix integration boundary.
- `.planning/codebase/INTEGRATIONS.md` — Existing platform and external native-library dependencies.

### Native builds, capability checks, and tests

- `DESCRIPTION` — Package and Matrix dependency declarations.
- `src/Makevars` — Unix-like native build flags.
- `src/Makevars.win` — Windows native build flags.
- `src/sparse-lu.cpp` — Native capability report, including OpenMP and maximum threads.
- `src/sparse-schur-openmp.cpp` — Serial/OpenMP Schur implementation.
- `R/zzzSparseSchurCpp.R` — Native preflight, thread limits, and diagnostics.
- `R/sparseSuiteSparse.R` — Current solve-time SuiteSparse compilation and hard-coded Linux paths.
- `tests/testthat/test-sparse-schur-openmp.R` — Existing OpenMP test and serial skip behavior.
- `tests/testthat/test-public-cpp-backend.R` — Public native backend contracts and diagnostics.

No external specifications were referenced.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `src/sparse-schur-openmp.cpp` already contains the serial and OpenMP Schur implementation.
- `src/sparse-lu.cpp` reports whether OpenMP was compiled and the native maximum thread count.
- `R/zzzSparseSchurCpp.R` already checks requested thread bounds and rejects multi-thread requests on serial builds.
- `tests/testthat/test-sparse-schur-openmp.R` compares a two-thread run against serial execution.

### Established Patterns

- Native OpenMP code uses `_OPENMP` guards, and the public C++ thread option defaults to one.
- Missing optional native capabilities fail closed; backend requests are not silently substituted.
- OpenMP-only tests currently skip when OpenMP is absent, so CI must distinguish expected OpenMP jobs from explicitly serial jobs.
- `src/Makevars` and `src/Makevars.win` currently use R's `SHLIB_OPENMP_CXXFLAGS`.
- Matrix is imported without a declared minimum version; native preflight checks a `sparseLU-v1` contract.
- The current SuiteSparse path uses `Rcpp::sourceCpp()` at solve time and hard-codes `/usr/include/suitesparse` plus Linux library flags.
- There is no `.github/workflows/` directory yet.

### Integration Points

- Package build metadata and platform flags: `DESCRIPTION`, `src/Makevars`, and `src/Makevars.win`.
- Native capability contract and solver preflight: `src/sparse-lu.cpp` and `R/zzzSparseSchurCpp.R`.
- OpenMP behavior and regression checks: `src/sparse-schur-openmp.cpp` and `tests/testthat/test-sparse-schur-openmp.R`.
- SuiteSparse request handling: `R/sparseSuiteSparse.R` and backend dispatch/diagnostics.
- New CI workflows must connect package installation and core test commands with the serial/OpenMP and R/Matrix variants above.

</code_context>

<specifics>
## Specific Ideas

- A green OpenMP job must demonstrate the compiled capability; a skipped test in an expected OpenMP job is not sufficient.
- Keep serial and two-thread results equivalent under the existing numerical contract; do not impose a noisy speed threshold.
- The Matrix minimum follows the oldest supported R window, while the promised package range includes intervening Matrix versions.

</specifics>

<deferred>
## Deferred Ideas

- Portable direct SuiteSparse detection and packaging remain future work as specified by the project’s v2 boundary.
- Full-scale benchmark execution remains external to routine CI.
- Broader release qualification and full package-check cleanup remain later release work; Phase 05 must still report representative `R CMD check` results accurately.

</deferred>

---

*Phase: 05-Portable Native Build and CI*
*Context gathered: 2026-10-01*

