# Phase 05: Portable Native Build and CI - Research

**Researched:** 2026-10-01  
**Domain:** R package native builds, optional OpenMP, installed solver capability, GitHub Actions  
**Confidence:** MEDIUM overall; repository boundaries and current OpenMP pattern are directly verified, while the exact Matrix support floor and hosted-runner capability combinations still need execution evidence.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Phase Boundary
Make GEModelR install and run its supported native solver predictably on Linux, macOS, and Windows, both with and without OpenMP. Establish a required CI matrix across supported R, Matrix, platform, and native build variants. Every supported installed solve path must avoid runtime compilation and hard-coded Linux SuiteSparse paths.

Keep the established one-thread default, the opt-in C++ backend, explicit backend selection, and fail-closed capability checks. Do not add portable direct SuiteSparse integration in this phase; that remains deferred work. Long full-scale benchmarks remain external to routine CI.

### Locked Decisions
- **D-01:** Run the full set of supported platform, R, Matrix, and serial/OpenMP combinations on every pull request. Run the same supported matrix on default-branch pushes and weekly. Only installable and supported R/Matrix pairings are valid matrix cells.
- **D-02:** Every matrix cell installs the package and runs core tests. Run full `R CMD check` in one representative cell. The exact representative cell and how it reports the currently documented package-check findings are for planning to resolve; report the result accurately.
- **D-03:** R jobs cover release, oldrel, and devel as scoped by the roadmap. Long full-scale benchmarks stay outside routine CI.
- **D-04:** Require an OpenMP-enabled build on every platform where the supported R toolchain offers OpenMP; maintain serial-build coverage on all three operating systems.
- **D-05:** Compare serial and two-thread native results. Expected OpenMP jobs fail if the built package reports OpenMP unavailable. Explicitly serial jobs may skip OpenMP-only tests.
- **D-06:** Verify capability reporting, effective thread bounds, and numerical equivalence. CI reports measured timing but does not gate on a speedup threshold.
- **D-07:** Preserve the one-thread default. Requests for more than one thread on a serial build continue to fail clearly; no automatic backend or thread substitution is introduced.
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

### Deferred Ideas (OUT OF SCOPE)
- Portable direct SuiteSparse detection and packaging remain future work as specified by the project’s v2 boundary.
- Full-scale benchmark execution remains external to routine CI.
- Broader release qualification and full package-check cleanup remain later release work; Phase 05 must still report representative `R CMD check` results accurately.
</user_constraints>

[VERIFIED: .planning/phases/05-portable-native-build-and-ci/05-CONTEXT.md:7-11,18-49,126-132]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PORT-01 | The package installs and passes its core tests on Linux, macOS, and Windows with OpenMP unavailable. | Current Makevars uses R’s OpenMP macro; add an explicit serial CI build on each OS and assert capability reports OpenMP false / max threads one before running installed core tests. |
| PORT-02 | OpenMP acceleration is optional, capability-reported, bounded, and numerically equivalent across supported thread counts. | Native capability payload already reports OpenMP and max threads; strengthen expected-OpenMP assertions, requested/effective thread-bound tests, and serial-vs-two-thread parity. |
| PORT-03 | Supported installed workflows do not compile native code at solve time or depend on hard-coded Linux SuiteSparse paths. | Remove/replace the solve-time Rcpp::sourceCpp path in structured elimination and make SuiteSparse preflight fail closed before matrix construction; assert no sourceCpp call. |
| CI-01 | CI checks R release, oldrel, and devel across an appropriate Linux/macOS/Windows matrix and exercises native/serial capability paths. | Add a pull-request, default-branch push, and weekly GitHub Actions workflow with explicit valid cells and required serial/OpenMP capability assertions. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Keep implementation in the focused R package modules; `R/GEModel.R` owns the main reference-class facade. Repository text: “Parsing, set/data processing, equation and coefficient generation, update handling, and model orchestration are split across focused files” and “`R/GEModel.R` defines the main reference-class model.” [VERIFIED: AGENTS.md:5-9]
- Match local style: “Use two-space indentation and preserve the existing base-R style: `=` assignment, short focused functions, and explicit `character`/`numeric` handling”; use camelCase functions and descriptive filenames. [VERIFIED: AGENTS.md:24-26]
- Reuse the existing testthat layout and add small deterministic fixtures only; “do not commit proprietary or oversized `.tab`/`.har` data.” [VERIFIED: AGENTS.md:28-30]
- Required package commands are `R CMD check .`, `R CMD build .`, and `R CMD INSTALL .`; shell commands in this project session must be prefixed with `rtk`. [VERIFIED: AGENTS.md:12-22; RTK instruction supplied for this task]
- Do not commit `.RData`, `.Rhistory`, `.Rproj.user/`, archives, `*.Rcheck/`, credentials, private model inputs, or generated solver results. [VERIFIED: AGENTS.md:36-38]
- Nyquist validation is enabled because `"nyquist_validation": true` appears in config. No `security_enforcement` key is present, so include the security mapping below. [VERIFIED: .planning/config.json:15-20]

## Summary

The package already has the standard R OpenMP build wiring in both platform makefiles. The exact lines are `PKG_CXXFLAGS = $(SHLIB_OPENMP_CXXFLAGS)` and `PKG_LIBS = $(SHLIB_OPENMP_CXXFLAGS) $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)` in both files. [VERIFIED: src/Makevars:1-2; src/Makevars.win:1-2] R Core’s current guidance says use the OpenMP macro in compile and link flags, guard optional code with `#ifdef _OPENMP`, and expect some toolchains—specifically default Apple clang on macOS—to have no OpenMP support. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html] The C++ capability function already returns the quoted fields `Rcpp::Named("openmp") = openmp` and `Rcpp::Named("max_threads") = max_threads`; the serial branch sets `openmp = false` and `max_threads = 1`. [VERIFIED: src/sparse-lu.cpp:13-32]

Two concrete implementation seams need to be included in the plan. First, a structured solve still calls `sparse_elimination_cpp()` at solve time, and that loader may use `Rcpp::sourceCpp()`; it checks predecessor package/symbol strings `"_tabloToR_tabloToR_eliminate_blocks"`, `"tabloToR"`, and `"cpp/sparse-elimination.cpp"` before falling back to a repository-relative source file. [VERIFIED: R/sparseElimination.R:3-45,350-354] The current package already has GEModelR-registered elimination wrappers and native registration, so plan to route this path through the package DLL wrappers instead of compiling code during a solve. [VERIFIED: R/RcppExports.R:15-22; src/RcppExports.cpp:46-75,168-185] Second, SuiteSparse currently checks hard-coded Linux paths and its solve function calls `Rcpp::sourceCpp()`; the backend registry can declare it available when those files exist. [VERIFIED: R/sparseSuiteSparse.R:3-13,89-137; R/sparseSolver.R:145-183] Make the registered request unconditionally unavailable in supported installed builds until portable support is separately delivered.

No `.github/workflows/` directory exists yet (the Phase 05 context records: “There is no `.github/workflows/` directory yet.”). [VERIFIED: .planning/phases/05-portable-native-build-and-ci/05-CONTEXT.md:105] The current OpenMP test skips whenever the capability is false; that is appropriate only for explicitly serial jobs, and it would let an expected OpenMP job pass by skipping. [VERIFIED: tests/testthat/test-sparse-schur-openmp.R:1-4] Add an explicit job expectation so an OpenMP-enabled matrix row fails if its installed build reports false.

**Primary recommendation:** Keep R’s existing OpenMP make macros; first remove solve-time compilation from the structured elimination and SuiteSparse seams, then make capability-specific installed tests fail closed, and only then add the full CI matrix. Pick Matrix endpoints after source/binary installation checks on the exact supported R/platform cells. Report the existing package-check baseline separately from the new portability gate.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Compile the package’s C++ sources | R package build / platform toolchain | Native C++ | `src/Makevars` and `src/Makevars.win` supply R’s compiler macros; the compiler decides whether `_OPENMP` is defined. [VERIFIED: src/Makevars:1-2; src/Makevars.win:1-2] |
| Report OpenMP and bound thread requests | Native C++ capability function | R solver preflight | C++ reports OpenMP/max threads; R validates ABI, capability payload, and requested thread count before dispatch. [VERIFIED: src/sparse-lu.cpp:13-32; R/zzzSparseSchurCpp.R:48-152] |
| Dispatch a solve and reject unavailable SuiteSparse | R backend registry / solver API | Native package DLL | The R registry sees the exact requested backend and must fail before matrix emission or state mutation. [VERIFIED: .planning/phases/04-public-api-and-solver-boundaries/04-VERIFICATION.md:30-38] |
| Validate installed package behavior | Hosted CI | testthat | Each OS/R/Matrix/build variant must install the package and test the installed library, not just load the source tree. [CITED: https://testthat.r-lib.org/reference/test_package.html] |

## Standard Stack

### Core

| Component | Version / choice | Purpose | Why standard |
|-----------|------------------|---------|--------------|
| R | `release`, `oldrel-1`, `devel` aliases | Test current release, previous release, and development R. | The official r-lib example uses these R labels, including `oldrel-1`; translate the roadmap’s “oldrel” to the action’s supported oldrel alias. [CITED: https://github.com/r-lib/actions/blob/v2-branch/examples/check-standard.yaml] |
| `r-lib/actions/setup-r` | `@v2` | Provision R on hosted Linux/macOS/Windows runners. | Current r-lib guidance recommends the `v2` major tag. [CITED: https://github.com/r-lib/actions] |
| `r-lib/actions/setup-r-dependencies` | `@v2` | Install dependencies declared in DESCRIPTION for the selected R. | This is the official action’s purpose. [CITED: https://github.com/r-lib/actions] |
| `r-lib/actions/check-r-package` | `@v2` | Build/check the package archive in the one representative full-check cell. | Official action wraps the package check flow. [CITED: https://github.com/r-lib/actions] |
| Matrix | Candidate minimum `1.6-5`; current `1.7-6` as of 2026-10-01 | Cover the declared sparse API interval. | CRAN lists current `1.7-6` (published 2026-07-25, R >= 4.4) and the archive lists `1.6-5` (2024-01-11, DESCRIPTION says R >= 3.5). These facts make `1.6-5` a plausible candidate, not a proven GEModelR minimum. [CITED: https://cran.r-project.org/web/packages/Matrix/index.html; https://cran.r-project.org/src/contrib/Archive/Matrix/; https://raw.githubusercontent.com/cran/Matrix/1.6-5/DESCRIPTION] |
| Rcpp | Existing dependency; no new version pin proposed | Compile package native code and call registered wrappers. | DESCRIPTION already has `Rcpp` under Imports and LinkingTo. [VERIFIED: DESCRIPTION:21-30] |
| testthat | Edition 3; locally observed version `3.3.2` | Run the existing package contract suite. | DESCRIPTION sets edition 3 and `tests/testthat.R` calls `test_check("GEModelR")`. [VERIFIED: DESCRIPTION:28-30; tests/testthat.R:1-4] |

### Supporting

| Component | Version / choice | Purpose |
|-----------|------------------|---------|
| GitHub Actions `schedule` event | Weekly POSIX cron at an off-hour minute | Re-run the same matrix on default-branch HEAD. GitHub says schedules use UTC by default, run only from the default branch, and may be delayed or dropped during high load; avoid the top of the hour. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows] |
| R package build flags | Existing `SHLIB_OPENMP_CXXFLAGS` macro | Compile and link optional OpenMP support using the selected R toolchain. [VERIFIED: src/Makevars:1-2; src/Makevars.win:1-2] |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| R Core’s per-toolchain OpenMP macro | Hard-coded `-fopenmp` or custom platform checks | Hard-coded flags fail on toolchains without OpenMP and can omit link flags. Use the existing macro unless a custom compiler is intentionally selected and compile+link probed. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html] |
| Registered GEModelR routines | Runtime `Rcpp::sourceCpp()` | Runtime compilation requires an available compiler and source-tree/resource lookup; it violates the installed-workflow requirement. Compile native code at package installation and call the registered wrappers. [VERIFIED: R/sparseElimination.R:23-45; src/RcppExports.cpp:168-185] |
| Fail-closed SuiteSparse request | Direct portable SuiteSparse integration | The latter is explicitly deferred by D-11 and the project’s v2 boundary. Keep the string ID accepted, return a structured unavailable capability error, and recommend the explicit Matrix request. [VERIFIED: .planning/phases/05-portable-native-build-and-ci/05-CONTEXT.md:37-42] |

**Installation:** No new R package dependency is needed. In each CI cell, use the official dependency action for the existing DESCRIPTION dependencies, then install the package from source with test files available:

```sh
R CMD INSTALL --preclean --install-tests .
Rscript --vanilla -e 'testthat::test_package("GEModelR", reporter = "summary")'
```

testthat documents `test_package()` for an installed package and `test_check()` for `R CMD check`; R’s INSTALL docs state that `--install-tests` copies the package’s tests into the installation. [CITED: https://testthat.r-lib.org/reference/test_package.html; https://stat.ethz.ch/R-manual/R-devel/library/utils/html/INSTALL.html] Use a test filename filter or a focused portability test file if the full package suite is not the chosen per-cell “core” subset; do not use `test_local()` as proof of installed behavior.

**Version verification:** Runners should assert `as.character(packageVersion("Matrix"))` equals the matrix cell’s requested endpoint. Install the current endpoint from CRAN and the minimum endpoint from its CRAN archive source tarball if no compatible binary is available. The local environment is R 4.3.0 / Matrix 1.6-3, so it cannot establish behavior for current Matrix 1.7-6, which requires R >= 4.4. [VERIFIED: local R and package version probes; CITED: https://cran.r-project.org/web/packages/Matrix/index.html]

## Package Legitimacy Audit

No new R package is recommended; the workflow uses existing `Matrix`, `Rcpp`, `SparseM`, and `testthat` dependencies already listed in DESCRIPTION. The npm/PyPI/crates package-legitimacy gate does not apply to these existing CRAN dependencies. GitHub Actions are sourced from the official r-lib repository and should be reviewed/pinned according to project policy.

## Architecture Patterns

### System Architecture Diagram

```mermaid
flowchart LR
  TR[Pull request / default push / weekly schedule] --> MATRIX[Explicit supported matrix rows]
  MATRIX --> RUNNER[Hosted OS + R + Matrix endpoint]
  RUNNER --> BUILD[Install dependencies and build GEModelR]
  BUILD --> FLAGS{Build variant}
  FLAGS -->|serial override| SERIAL[Capability: OpenMP false, max threads 1]
  FLAGS -->|toolchain OpenMP| OMP[Capability: OpenMP true, bounded threads]
  SERIAL --> INST[Installed core tests]
  OMP --> INST
  INST --> CHECK{Representative full check?}
  CHECK -->|one cell| RCMD[R CMD check with known-baseline result visible]
  CHECK -->|other cells| DONE[Required portability result]

  REQUEST[Explicit solve request] --> DISPATCH[R backend registry preflight]
  DISPATCH -->|SuiteSparse| FAIL[Structured unavailable error; recommend backend="Matrix"]
  DISPATCH -->|Matrix or structured C++| NATIVE[Installed registered GEModelR DLL]
  NATIVE --> CAP[ABI / Matrix contract / thread capability validation]
  CAP -->|serial| ONE[One-thread native path]
  CAP -->|OpenMP| PAR[Bounded parallel Schur path]
  ONE --> ACCEPT[Residual and finiteness acceptance]
  PAR --> ACCEPT
  ACCEPT --> STATE[Commit accepted model state]
```

### Recommended Project Structure

```
.github/workflows/R-CMD-check.yaml      # new: supported matrix + triggers
.Rbuildignore                           # update if needed to exclude CI metadata
R/sparseElimination.R                   # replace solve-time sourceCpp loader
R/sparseSuiteSparse.R                   # remove reachable runtime compile path
R/sparseSolver.R                        # unconditional explicit SuiteSparse preflight
R/apiDocumentation.R                    # document SuiteSparse as recognized/unavailable
src/Makevars, src/Makevars.win           # retain R macros; change only with evidence
tests/testthat/test-sparse-schur-openmp.R
tests/testthat/test-public-cpp-backend.R
tests/testthat/test-public-solver-contract.R
tests/testthat/test-native-portability.R # proposed focused installed-contract tests
```

The `.github/workflows/` directory is absent today. Existing workflow test paths do not exist; the new file path above is a proposed location. If CI files create package metadata or outputs, make sure the source archive excludes workflow-only content. `.Rbuildignore` currently lists `^\.planning$` and other top-level paths but no explicit `.github` entry. [VERIFIED: .Rbuildignore:1-7] R Core documents `.Rbuildignore` as the package-build exclusion mechanism. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html]

### Pattern 1: One build, runtime-reported capability

**What:** Let R’s make macros decide whether the current toolchain compiles and links OpenMP. Keep native code behind `#ifdef _OPENMP`; report the compiled capability from the package DLL and validate the requested thread count in R.

**When to use:** Every build variant. Serial is a deliberate supported configuration, not an accidental result inferred from a test skip.

**Existing pattern, verbatim:**

```make
PKG_CXXFLAGS = $(SHLIB_OPENMP_CXXFLAGS)
PKG_LIBS = $(SHLIB_OPENMP_CXXFLAGS) $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)
```

Source: [VERIFIED: src/Makevars:1-2; src/Makevars.win:1-2]. R Core specifies using the corresponding macro in both compile and link flags, and says OpenMP-dependent code must be guarded because some supported toolchains lack OpenMP entirely. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html]

For explicit serial jobs, create a job-local user Makevars file that clears `SHLIB_OPENMP_CXXFLAGS` and point `R_MAKEVARS_USER` at it before installation. R Core’s inclusion order places `R_MAKEVARS_USER` after the package makevars on Unix-alikes and Windows; still prove the outcome from the installed capability payload, not from the presence or absence of a compiler flag string. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html] This override mechanism is a recommendation to validate in the first workflow run.

### Pattern 2: Installed C++ entry points only

The package already has generated R wrappers and registered native entry points for elimination/reconstruction: the wrapper calls `_GEModelR_GEModelR_eliminate_blocks` and the registration table lists that symbol with arity 6. [VERIFIED: R/RcppExports.R:15-22; src/RcppExports.cpp:46-75,168-185] Replace the stale runtime loader path with these installed wrappers; keep generated Rcpp files generated rather than hand-editing registration tables. In tests, invoke the installed structured solver from a temporary working directory with no package source tree and verify that the solver does not call `Rcpp::sourceCpp()`.

### Pattern 3: Fail closed before solve setup

The existing public contract runs backend preflight before `sparse_emit_system`, and Phase 04 requires capability failures to preserve requested backend, cause, and remediation. [VERIFIED: .planning/phases/04-public-api-and-solver-boundaries/04-VERIFICATION.md:30-38; .planning/phases/04-public-api-and-solver-boundaries/04-CONTEXT.md:23-28] For SuiteSparse, preserve the exact recognized backend value `"SuiteSparse"` and make the preflight always unavailable until portable support lands. The remediation text must name the explicit Matrix selection `backend="Matrix"`; assert that no matrix emission, solver invocation, runtime compilation, or model-state mutation occurred.

### Anti-Patterns to Avoid

- Treating `skip_if_not(isTRUE(capabilities$openmp))` as sufficient in expected OpenMP jobs; the current test uses this exact skip. [VERIFIED: tests/testthat/test-sparse-schur-openmp.R:1-4]
- Depending on a source-tree copy or runtime `Rcpp::sourceCpp()` in an installed solve path; `sparse_elimination_cpp()` calls it on demand. [VERIFIED: R/sparseElimination.R:23-45,350]
- Treating “SuiteSparse happens to be present on Linux” as support. Existing availability checks name `"/usr/include/suitesparse/umfpack.h"`, `"/lib/x86_64-linux-gnu/libumfpack.so"`, and `"/usr/lib/x86_64-linux-gnu/libumfpack.so.5"`; the solver then sets `"-I/usr/include/suitesparse"` and links `"-lumfpack -lamd -lcolamd -lsuitesparseconfig -lblas"`. [VERIFIED: R/sparseSuiteSparse.R:3-12,113-129]
- Putting OpenMP flags only in compile flags. R Core warns the package can compile but fail to link on another toolchain; inspect build logs and runtime-reported capability. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html]
- Requiring speedup: D-06 explicitly asks to report timings without a speed threshold; Windows OpenMP overhead can be substantial. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html]

## Don't Hand-Roll

| Problem | Don’t build | Use instead | Why |
|---------|-------------|-------------|-----|
| Cross-platform OpenMP detection | Per-OS guesses and unconditional compiler flags | R’s `SHLIB_OPENMP_CXXFLAGS` for compile+link, plus runtime capability assertions | R supplies the compiler-specific macro; macOS default clang has no native OpenMP support. |
| R CI setup and package dependency discovery | Custom installer scripts for R and DESCRIPTION dependencies | `r-lib/actions/setup-r@v2`, `setup-r-dependencies@v2`, and `check-r-package@v2` | Official R community actions already implement R setup, dependency installation, and package checks. |
| Installed native routine loading | Solve-time source discovery and `sourceCpp` | Existing Rcpp-generated wrappers and package DLL registration | The package already compiles/registers the routine during install; runtime compile creates compiler/source-tree coupling. |
| Unsupported direct SuiteSparse request | Automatic Matrix fallback | A structured capability error with explicit `backend="Matrix"` remediation | Locked decisions require request identity and fail-closed behavior. |
| Numerical performance CI thresholds | Fixed “must be faster” ratio | Report elapsed time; gate on capability, bounds, and numerical parity | Hosted runners vary; the locked success criteria require correctness and capability, not a speedup. |

**Key insight:** Portability is determined by the installed DLL and the selected R toolchain. A successful source-tree test, a skipped OpenMP test, or the presence of a local Linux SuiteSparse header does not demonstrate that the installed package supports the claimed path.

## Common Pitfalls

### Pitfall 1: OpenMP jobs go green by skipping

**What goes wrong:** The current test skips when OpenMP is false; an expected OpenMP job could therefore pass without exercising parallel code.  
**Why:** Test behavior currently treats every no-OpenMP build identically.  
**How to avoid:** Set a matrix expectation per job. An OpenMP row must assert `openmp == TRUE` and `max_threads >= 2` before running the parity test; a serial row must assert `openmp == FALSE` and `max_threads == 1`. Only the explicitly serial row may skip OMP-only behavior.  
**Warning signs:** A CI job reports a skipped rather than passed OpenMP parity test.

### Pitfall 2: Runtime compilation remains reachable after fixing SuiteSparse

**What goes wrong:** Removing SuiteSparse `sourceCpp` alone still leaves solve-time compilation in structured elimination.  
**Why:** `R/sparseElimination.R` calls `sparse_elimination_cpp()`; the loader can reach `Rcpp::sourceCpp()` and searches predecessor package identity paths. [VERIFIED: R/sparseElimination.R:3-45,350]  
**How to avoid:** Route to the existing GEModelR generated wrappers and add an installed-package test that runs outside the checkout, with sourceCpp mocked to fail if called.

### Pitfall 3: “Serial” builds still inherit host OpenMP

**What goes wrong:** A job intended to test serial behavior receives OpenMP compiler flags from the hosted runner’s R configuration.  
**Why:** Makevars expands R’s toolchain macro at build time.  
**How to avoid:** Use an isolated job-local `R_MAKEVARS_USER` override; clean before compilation with `--preclean`; assert the installed package reports serial capability and rejects a request above one thread with the existing capability-error class. R Core documents user Makevars inclusion order but CI must prove the final result. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html]

### Pitfall 4: SuiteSparse still passes preflight on one platform

**What goes wrong:** A Linux image containing the named header/library passes availability detection, after which solving compiles against hard-coded paths.  
**Why:** The current registry gates on file detection rather than the phase’s supported-build contract.  
**How to avoid:** Make supported installed preflight unavailable regardless of host files until a future portable integration phase; keep D-14 assertions in every OS/build job.

### Pitfall 5: Matrix endpoint jobs silently install the wrong version

**What goes wrong:** All cells test current Matrix despite a matrix dimension intended to pin the minimum.  
**Why:** Normal dependency setup follows the current CRAN repository unless the endpoint is explicitly selected.  
**How to avoid:** Install the exact endpoint in each endpoint row; assert packageVersion before installation/testing; record the resolved R version and Matrix version in CI logs. Exclude only R/Matrix/platform cells that cannot install or are outside the documented support window, and record that exclusion.

### Pitfall 6: R CMD check baseline is confused with portability status

**What goes wrong:** A new CI matrix is described as fixing the package’s existing full-check failures.  
**Why:** Phase 04 already records independent source-tree, provenance, and release-gate failures.  
**How to avoid:** Run the representative check in a clearly named baseline job, retain its log/artifact, and report the result as non-clean; keep the serial/OpenMP install/core-test jobs as separate portability gates. Phase 06 owns broader check cleanup.

### Pitfall 7: Weekly schedule is treated as an exact clock

**What goes wrong:** Maintainers expect a weekly job to start at a precise minute or run from a feature branch.  
**Why:** GitHub schedules run from the default branch in UTC by default and may be delayed/dropped under load, especially at the top of an hour.  
**How to avoid:** Define the schedule on the default branch at a non-round minute and treat it as periodic coverage, not a punctual alert. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows]

## State of the Art

| Old approach | Current approach | When changed | Impact |
|--------------|------------------|--------------|--------|
| Manual platform guesses or hard-coded OpenMP compiler flags | R make macro `SHLIB_OPENMP_CXXFLAGS` in compile and link settings, guarded native code, runtime capability result | Current R Core manual, R 4.6.1 (2026-06-24) | The repository already uses this pattern; prove the outcome in each installed runner. [CITED: https://cran.r-project.org/doc/manuals/r-release/R-exts.html] |
| One R CI job or full check on every platform/version | r-lib actions v2 setup/dependency/check actions; standard example covers macOS and Windows release plus Linux devel/release/oldrel-1 | Current official `v2` branch example observed 2026-10-01 | Use it as a starter, then expand the matrix to this project’s required platform, Matrix, and native variants. [CITED: https://github.com/r-lib/actions/blob/v2-branch/examples/check-standard.yaml] |
| Implicit Matrix compatibility | Explicit minimum-to-current supported interval with endpoint jobs | Phase 05 decision D-08–D-10 | Current CRAN Matrix is 1.7-6; the exact minimum is not encoded in DESCRIPTION and remains to be chosen/proven. [VERIFIED: DESCRIPTION:21-25; CITED: https://cran.r-project.org/web/packages/Matrix/index.html] |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `Matrix 1.6-5` is a plausible minimum candidate because CRAN archive metadata permits R >= 3.5, but GEModelR compatibility has not been tested against it. | Standard Stack | If the package’s Matrix sparseLU calls or native contract differ, the support floor and endpoint matrix must move. Verify package build and solver tests before locking it. |
| A2 | Linux and Windows hosted R toolchains will expose at least one supported OpenMP-enabled job, while default macOS jobs remain serial. | Validation Architecture | Runner/compiler changes can make a nominal OpenMP cell serial; fail the cell on false capability and revise only from actual runner evidence. |
| A3 | A user Makevars override clearing `SHLIB_OPENMP_CXXFLAGS` will produce a serial build across supported runners. | Architecture Patterns | Makevars expansion or platform-specific order could differ; capability assertion is the acceptance test and the workflow must be adjusted if it still reports OpenMP. |
| A4 | **RESOLVED FOR PLANNING:** Plan the full 30-row candidate matrix: all 3 OS × 3 R aliases × 2 Matrix endpoints as serial (18 rows), plus Linux and Windows OpenMP for all 6 R/Matrix pairs (12 rows). Execution must retain each row unless its exact R requirement, Matrix source-install result, or installed solver contract demonstrates that pairing is invalid; execution evidence remains pending. | Validation Architecture | The complete 30-row selection is the planning baseline. Hosted execution may exclude only individually evidenced invalid pairings, with row-specific evidence recorded. |

## Open Questions — Resolved for Planning

1. **Which Matrix version becomes the minimum? — RESOLVED FOR PLANNING**
   - Planning choice: Treat Matrix 1.6-5 as the provisional floor candidate and Matrix 1.7-6 as the current endpoint candidate from the 2026-10-01 research snapshot. Refresh the current endpoint from CRAN at execution.
   - Execution evidence remains pending: On oldrel-1, source-install the exact 1.6-5 archive and run the installed GEModelR Matrix solver contract for every supported floor pairing: Linux, macOS, and Windows serial builds, plus Linux and Windows OpenMP builds. Record the exact R version, OS, build mode, Matrix version, source-install result, and solver-test result. Set the DESCRIPTION floor only after these checks pass; if any supported pairing fails, use the oldest Matrix version that passes the same checks. This choice is resolved for planning, not proven.

2. **Which hosted R toolchains actually provide OpenMP? — RESOLVED FOR PLANNING**
   - Planning choice: Require serial jobs on Linux, macOS, and Windows. Include expected OpenMP jobs for the supported Linux and Windows R toolchains; keep the default Apple clang macOS lane serial. Do not infer capability from the OS label.
   - Execution evidence remains pending: Every expected OpenMP job must explicitly assert `openmp == TRUE` and `max_threads >= 2`; every serial job must assert `openmp == FALSE` and `max_threads == 1`. Only a job explicitly marked serial may skip OpenMP-only assertions. These checks decide whether each selected toolchain actually provides the planned capability; the planning choice is not proof of hosted-runner behavior.

3. **How should the representative package-check job surface existing failures? — RESOLVED FOR PLANNING**
   - Planning choice: Use a visibly named, non-required Linux/release/current-Matrix/serial baseline job with a named full-check step. The job summary reports the current check outcome and original exit status and labels the known counts as the inherited Phase 04 baseline only.
   - Evidence retention: Preserve the complete raw check log and check directory as downloadable artifacts even when the check exits nonzero. Do not imply Phase 05 resolves inherited findings. The job and reporting contract are resolved for planning; the current result and artifacts remain pending execution.

## Environment Availability

| Dependency | Required by | Available here | Version / evidence | Fallback |
|------------|-------------|----------------|--------------------|----------|
| R | Local read-only probes | Yes | 4.3.0 | Use hosted release/oldrel/devel jobs for Phase 05. |
| Matrix | Local package metadata | Yes | 1.6-3 | Hosted R >= 4.4 runner is required to validate current 1.7-6. |
| Rcpp | Local package metadata | Yes | 1.1.1.1.1 | Existing DESCRIPTION dependency. |
| testthat | Local package metadata | Yes | 3.3.2, edition 3 | Existing testthat framework. |
| OpenMP build capability | Native CI coverage | Unverified locally | `R CMD config SHLIB_OPENMP_CXXFLAGS` did not report a config value; this does not establish whether package Makevars expansion works. | Assert runtime capability in hosted serial/OpenMP jobs. |
| Linux/macOS/Windows hosted runners | Cross-platform validation | Not available locally | GitHub Actions workflow directory is absent | Add the workflow; no local fallback can validate the other OS toolchains. |

## Validation Architecture

Validation is enabled: `workflow.nyquist_validation` is true. [VERIFIED: .planning/config.json:15-20] Use installed-package tests in the platform matrix. testthat distinguishes `test_local()` (source package), `test_package()` (installed package), and `test_check()` (`R CMD check`). [CITED: https://testthat.r-lib.org/reference/test_package.html]

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat edition 3; local version 3.3.2 |
| Config file | DESCRIPTION and `tests/testthat.R` |
| Quick installed run | `R CMD INSTALL --preclean --install-tests .`, then `Rscript --vanilla -e 'testthat::test_package("GEModelR", reporter = "summary")'` |
| Representative full check | `R CMD build .`, then check the resulting source archive with `R CMD check --no-manual <built-source-archive>.tar.gz` or official `check-r-package@v2` on the selected representative cell |
| Existing full source run | `Rscript --vanilla -e 'testthat::test_local(reporter = "summary")'`; do not treat it as installed-build proof. |

Package metadata quotes `Package: GEModelR` and `Version: 0.1.0`, which are the archive name components if the manual check command is expanded literally. [VERIFIED: DESCRIPTION:1-4] R’s install documentation confirms `--install-tests` copies tests into the package installation. The installed test command should use the cell’s explicit Matrix endpoint and run from outside the repository when checking native resource lookups. [CITED: https://stat.ethz.ch/R-manual/R-devel/library/utils/html/INSTALL.html; https://testthat.r-lib.org/reference/test_package.html]

### Validation Matrix Dimensions

| Dimension | Required coverage | Planning rule |
|-----------|-------------------|---------------|
| OS | Linux, macOS, Windows | Every OS has at least a serial build. |
| R | release, oldrel, devel | Follow official r-lib setup aliases; current example uses `oldrel-1` for the oldrel job. |
| Matrix | Minimum and current endpoint; support promise spans all intervening versions | Pin endpoint per job, assert actual installed version; include only installable/supported R/Matrix cells. |
| Native variant | Serial on all OS; OpenMP where supported toolchain offers it | OMP expected rows must fail on false capability. Default macOS clang is serial unless a separate supported OpenMP toolchain is intentionally selected. |
| Trigger | Pull request, default-branch push, weekly | Same supported matrix for all triggers; schedule at an off-hour UTC minute. |

A full valid cartesian selection would be 30 jobs (18 serial plus 12 Linux/Windows OpenMP) before exclusions. Encode exact valid rows rather than relying on implicit matrix intersections; use `fail-fast: false` so one compiler/R failure does not hide the rest.

### Phase Requirements → Test Map

| Req ID | Behavior | Test type | Automated check | Existing coverage |
|--------|----------|-----------|-----------------|------------------|
| PORT-01 | Clean installed serial build on each OS; report OpenMP false and max threads one; one-thread solve works; multi-thread request fails clearly. | Install integration + capability contract | Install with serial Makevars override; run `testthat::test_package(..., filter = "native-portability|public-cpp-backend")` | No explicit serial matrix assertion yet; proposed `tests/testthat/test-native-portability.R`. |
| PORT-02 | OpenMP expected job reports capability true and max threads >= 2; effective threads are bounded; two-thread Schur result matches serial. | Native unit/integration | Run `testthat::test_package(..., filter = "sparse-schur-openmp|public-cpp-backend")` with job expectation set to OpenMP | Parity test exists in `test-sparse-schur-openmp.R`, tolerance 1e-10, but currently skips on false capability. [VERIFIED: tests/testthat/test-sparse-schur-openmp.R:1-4,24-41] |
| PORT-03 | Installed structured and Matrix workflows do not compile at solve time; SuiteSparse request fails before matrix emission/state mutation and never calls sourceCpp. | Installed integration | Run `testthat::test_package(..., filter = "native-portability|sparse-core|public-solver-contract")` from a temp working directory with sourceCpp instrumented to fail | Add focused assertion; current runtime compile path exists in `R/sparseElimination.R` and `R/sparseSuiteSparse.R`. |
| CI-01 | Matrix runs on PR, default push, weekly with all valid R/OS/Matrix/serial-OMP rows. | Workflow validation | YAML/event/matrix inspection plus successful package install/core-test logs per row | No `.github/workflows` exists yet. [VERIFIED: 05-CONTEXT.md:105] |

### Serial and OpenMP assertions

- **Serial row, every OS:** install from a clean source build with the explicit serial Makevars override; assert the installed capability fields are exactly `openmp == FALSE` and `max_threads == 1`; run a supported one-thread native solve; assert a request above one fails with `GEModelR_capability_error` and remediation, without backend/thread substitution. The native source says `Rcpp::Named("openmp") = openmp`, `Rcpp::Named("max_threads") = max_threads`, and the serial branch sets `const bool openmp = false;` / `const int max_threads = 1;`. The wrapper sets `primary_class = "GEModelR_capability_error"`. [VERIFIED: src/sparse-lu.cpp:15-27; R/zzzSparseSchurCpp.R:48-64,140-152]
- **Expected OpenMP row:** fail before test execution unless `openmp == TRUE` and max threads is at least 2. Run serial and two-thread implementations on the same deterministic fixture; assert numerical equivalence, `threads_effective <= threads_requested <= max_threads`, effective count matches the requested two threads for the two-item fixture, and timing is reported only. The existing direct comparison checks `tolerance = 1e-10` and `threads_effective == 2L`. [VERIFIED: tests/testthat/test-sparse-schur-openmp.R:24-41]
- **SuiteSparse, every OS and build variant:** explicitly request the retained ID, require a structured error naming it and recommending `backend="Matrix"`; spy on sourceCpp/solver/matrix-emission entry points and compare model state before/after to prove fail-before-work. Existing code quotes the ID exactly as `"SuiteSparse"`; the public backend matcher also accepts `"Matrix"`. [VERIFIED: R/sparseSolver.R:145-159,3399-3404]
- **Matrix endpoints:** before tests, assert endpoint packageVersion; then run native capability self-test and representative Matrix sparse solve tests against that endpoint in each selected supported R/OS pairing.
- **Full package check:** one representative Linux/release/current-Matrix/serial cell is the most stable option for a baseline. Phase 04 recorded package tests/checks with known failures; keep this result visible, retain its log, and leave broader cleanup to Phase 06.

### Known Phase 04 package-check baseline

The latest Phase 04 verification, dated 2026-10-01, says the checkout is not package-check clean. Its exact summary is: “Latest R CMD check ran the package tests with 2,364 passes, 19 failures, and 65 skips, ending with 1 ERROR, 4 WARNINGs, and 4 NOTEs.” It further records: “Six benchmark tests fail because the installed-check context cannot locate the source tree. Four provenance-inventory failures report 320 fresh source keys against the reviewed 291-row snapshot, including new Phase 04 helper keys and a duplicate .sparse_accept_candidate key. Nine release-gate failures reflect stale/duplicate provenance and release records.” API, namespace, R-code, and Rd checks pass. [VERIFIED: .planning/phases/04-public-api-and-solver-boundaries/04-VERIFICATION.md:168-173; .planning/STATE.md:166-172]

The Phase 04 report also records separate full-source identity-map drift (mixed-case 416/328; uppercase 2/2), an existing ReferenceClass assignment warning, and check warnings/notes for build artifacts/source-tree context, executable shared libraries, a nonportable benchmark path, check output directories, hidden files/directories, placeholder License metadata, LazyData without `data`, and a compiled-code `abort` note. [VERIFIED: .planning/phases/04-public-api-and-solver-boundaries/04-VERIFICATION.md:168-177] An older 04-06 summary records a pre-fix 27-test-failure snapshot; use the newer 04-VERIFICATION record above as the Phase 05 baseline. [VERIFIED: .planning/phases/04-public-api-and-solver-boundaries/04-06-SUMMARY.md:129-142]

**Wave 0 gaps:** Add or extend tests that (a) distinguish expected OpenMP from serial jobs, (b) assert thread bounds and serial rejection, (c) assert SuiteSparse fails before sourceCpp/matrix emission/state mutation, and (d) prove installed structured solving uses registered DLL routines from outside the checkout. No test framework installation is needed.

## Security Domain

Security enforcement is enabled by default because no `security_enforcement: false` override exists in config. This is an R package with native code and CI, not a network application; ASVS categories are an applicability map, not a claim of full web-application ASVS compliance. OWASP identifies ASVS as a web application verification standard and lists V1–V14 categories. [CITED: https://devguide.owasp.org/en/03-requirements/05-asvs/]

### Applicable ASVS Categories

| ASVS category | Applies | Standard control for this phase |
|----------------|---------|---------------------------------|
| V1 Architecture, Design and Threat Modeling | Yes | Treat source install, package DLL, optional compiler capability, and backend preflight as explicit trust boundaries; fail closed when native capability is absent. |
| V2 Authentication | No | The package has no user authentication service. |
| V3 Session Management | No | No web/session runtime exists. |
| V4 Access Control | No | No server-side user/role authorization surface exists. |
| V5 Validation, Sanitization and Encoding | Yes | Validate backend IDs and positive/bounded thread requests before matrix construction or state mutation. |
| V6 Stored Cryptography | No | Phase 05 adds no cryptographic storage. |
| V7 Error Handling and Logging | Yes | Preserve structured requested-backend, cause, remediation, and capability-error status; do not expose runner secrets in logs. |
| V10 Malicious Code | Yes, CI boundary | Install dependencies from declared metadata and official action sources; use minimal read permissions and avoid secrets in pull-request jobs. |
| V14 Configuration | Yes, CI boundary | Keep serial/OpenMP expectations explicit and make schedule/triggers/matrix rows reviewable. |

### Known Threat Patterns for R and native CI

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Untrusted thread count or unsupported backend request | Tampering / Denial of Service | Validate exact IDs and thread bounds before emission; reject multi-thread requests on serial builds. |
| Runtime compiler invoked during solve | Tampering / Elevation of privilege boundary | Remove solve-time `sourceCpp`; use registered package DLL functions compiled at installation. |
| Platform-specific SuiteSparse path accidentally treated as portable | Tampering / Availability | Fail closed with explicit Matrix remediation until a portable integration is a separate reviewed feature. |
| PR-controlled workflow input reaching shell commands or secrets | Elevation of privilege | Use quoted/environment-mediated values, minimal workflow permissions, and no secrets for test jobs. |

## Sources

### Primary (HIGH confidence: repository source of truth)
- `05-CONTEXT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md` — locked scope, requirements, phase criteria, and current baseline.
- `DESCRIPTION`, `.Rbuildignore`, `src/Makevars`, `src/Makevars.win`, `src/sparse-lu.cpp`, `src/sparse-schur-openmp.cpp` — declared dependencies, package archive exclusions, native build/capability behavior.
- `R/sparseElimination.R`, `R/sparseSuiteSparse.R`, `R/sparseSolver.R`, `R/RcppExports.R`, `src/RcppExports.cpp` — solve-time compile paths, backend preflight, registered wrappers.
- `tests/testthat/test-sparse-schur-openmp.R`, `test-public-cpp-backend.R`, `test-public-solver-contract.R`, `tests/testthat.R` — current assertions and gaps.
- `04-VERIFICATION.md`, `04-VALIDATION.md`, `04-SECURITY.md` — Phase 04 test/check baseline and security contract.

### Official documentation (CITED; current guidance checked 2026-10-01)
- R Core, Writing R Extensions (R 4.6.1, 2026-06-24): https://cran.r-project.org/doc/manuals/r-release/R-exts.html
- r-lib/actions official action versions and R check matrix example: https://github.com/r-lib/actions and https://github.com/r-lib/actions/blob/v2-branch/examples/check-standard.yaml
- CRAN Matrix index and archive metadata: https://cran.r-project.org/web/packages/Matrix/index.html and https://cran.r-project.org/src/contrib/Archive/Matrix/
- testthat installed-package testing: https://testthat.r-lib.org/reference/test_package.html
- R INSTALL `--install-tests`: https://stat.ethz.ch/R-manual/R-devel/library/utils/html/INSTALL.html
- GitHub Actions schedule semantics: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- OWASP Developer Guide ASVS categories: https://devguide.owasp.org/en/03-requirements/05-asvs/

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — official action/Matrix versions are current-source checked; Matrix minimum remains provisional pending install and package API evidence.
- Architecture: HIGH — repository build/runtime seams and registered wrappers were read directly.
- Pitfalls: HIGH — skip behavior, runtime compilation, and hard-coded SuiteSparse paths are present in source.
- CI coverage: MEDIUM — official patterns are verified, but hosted runner R/toolchain combinations have not run in this research session.

**Research date:** 2026-10-01  
**Valid until:** 2026-10-08 for workflow/action and Matrix endpoint details; R’s OpenMP make macro guidance is stable.
