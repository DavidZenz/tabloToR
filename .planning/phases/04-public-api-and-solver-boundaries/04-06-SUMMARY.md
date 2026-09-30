---
phase: 04-public-api-and-solver-boundaries
plan: 06
subsystem: api
tags: [R, GEModelR, roxygen2, NAMESPACE, Rd, testthat]
requires:
  - phase: 04-public-api-and-solver-boundaries
    provides: typed solve outcomes, backend dispatch contracts, and diagnostics schema
provides:
  - Explicit GEModel-only public export with retained native registration and imports
  - Generated GEModel class and package reference help for supported options and solver contract
  - Namespace, documentation, and installed-package parity checks
affects: [05-portable-native-build-and-ci, 06-documentation-and-release-qualification]
actuals:
  tokens: 8619
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns:
    - Roxygen source generates NAMESPACE and Rd help without a runtime documentation dependency
    - Exact export assertions keep internal parser, solver, and native wrappers private
key-files:
  created:
    - R/apiDocumentation.R
    - man/GEModel.Rd
    - tests/testthat/test-api-documentation.R
  modified:
    - DESCRIPTION
    - NAMESPACE
    - R/GEModel.R
    - man/GEModelR-package.Rd
    - tests/testthat/test-public-solver-contract.R
    - tests/testthat/test-compatibility-manifest.R
    - tests/testthat/test-documented-workflow.R
    - .planning/phases/04-public-api-and-solver-boundaries/deferred-items.md
key-decisions:
  - "Export only GEModel; keep native registration and required imports while leaving implementation helpers private."
  - "Compare the compatibility manifest's supported export tier with the live namespace."
  - "Assert schema-version-1 diagnostics for successful legacy solve attempts."
patterns-established:
  - "Read generated help from source Rd files or the installed package Rd database, depending on test context."
  - "Resolve NAMESPACE from the package installation when source-tree files are unavailable."
requirements-completed: [API-01, DOCS-01]
coverage:
  - id: D1
    description: GEModel is the sole deliberate public package binding, with implementation helpers private.
    requirement: API-01
    verification:
      - kind: unit
        ref: tests/testthat/test-public-solver-contract.R#GEModel is the only exported package binding
        status: pass
      - kind: integration
        ref: installed namespace assertion via Rscript; GEModel only, explicit export, no exportPattern
        status: pass
    human_judgment: false
  - id: D2
    description: Generated package and GEModel help covers supported methods, backends, diagnostics, options, and defaults.
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: tests/testthat/test-api-documentation.R#generated help covers the deliberate GEModel API
        status: pass
      - kind: integration
        ref: installed Rd_db documentation test from /tmp context
        status: pass
    human_judgment: false
duration: 35min
completed: 2026-09-30
status: complete
---

# Phase 04 Plan 06: Explicit Public API Summary

**The package now exports only GEModel and generates reference help for its supported workflow, solver controls, backends, and versioned diagnostics.**

## Performance

- **Duration:** 35 minutes
- **Started:** 2026-09-30T19:56:35Z
- **Completed:** 2026-09-30T20:31:35Z
- **Tasks:** 2
- **Plan implementation files:** 11

## Accomplishments

- Replaced the broad alphabetic namespace with `export(GEModel)` while preserving native routine registration and required imports.
- Generated class and package help documenting supported method signatures, engine/backend separation, backend tiers, output modes, diagnostics, option defaults/scopes, and memory-budget controls.
- Added deterministic tests for exact exports, private helper families, and generated help parity.
- Updated the compatibility manifest assertion to compare its supported export tier, and aligned workflow expectations with the diagnostics envelope introduced in Plan 04-05.
- Recorded the updated 416/328 mixed-case identity-gate result in the phase-local deferred note without changing the reviewed Phase 02 map.

## Task Commits

1. **Task 1: Generate the explicit GEModel namespace and public reference help** — `773028e` (`feat(04-06): publish explicit GEModel API`)
2. **Task 2: Enforce namespace and documentation parity** — `9fa68bb` (`test(04-06): enforce public API help parity`)

Additional focused test corrections:

- `a13561d` — `test(04-06): align manifest check with supported exports`
- `e960a4b` — `test(04-06): align checks with generated API contracts`
- `b799894` — `test(04-06): support installed namespace check context`

## Files Created/Modified

- `R/apiDocumentation.R` — roxygen package topic for the supported public API and options.
- `R/GEModel.R` — generated class help and explicit export tag.
- `DESCRIPTION`, `NAMESPACE` — roxygen metadata, the sole GEModel export, imports, and native registration.
- `man/GEModel.Rd`, `man/GEModelR-package.Rd` — generated class and package help topics.
- `tests/testthat/test-public-solver-contract.R` — exact namespace assertions and installed-source fallback.
- `tests/testthat/test-api-documentation.R` — generated help parity checks across source and installed contexts.
- `tests/testthat/test-compatibility-manifest.R` — supported-tier export parity.
- `tests/testthat/test-documented-workflow.R` — versioned diagnostics envelope assertion.
- `deferred-items.md` — latest identity-source gate count and unchanged uppercase result.

## Decisions Made

- Keep GEModel as the only supported export, without compatibility aliases or broad export directives.
- Keep transaction, fault-injection, cache, and other implementation controls outside the public option list.
- Keep numerical defaults unchanged and document the existing per-model memory budget controls.

## Verification

- `roxygen2::roxygenise()` completed; generated Rd files parse and package documentation checks passed during `R CMD check`.
- `testthat::test_local(filter = "public-solver-contract|api-documentation", reporter = "summary")` passed after the final test changes. The existing ReferenceClass assignment warning at `R/GEModel.R` in `generateSolution` remains.
- `testthat::test_local(filter = "api-documentation|documented-workflow", reporter = "summary")` passed after updating the stale diagnostics expectation.
- The documentation test passed in an installed-package context from `/tmp`; a direct installed NAMESPACE assertion also passed.
- The focused compatibility-manifest test passed.
- `R CMD check .` was run before commits `e960a4b` and `b799894`. Package installation, namespace loading, syntax, Rd parsing/metadata/cross-references, documentation entries, code/documentation matching, and manual generation passed. The overall command exited 1 with `1 ERROR, 4 WARNINGs, 4 NOTEs`; it was not rerun after those test-only corrections.

### Complete `R CMD check` Test Failure Snapshot

The check's testthat summary was `[FAIL 27 | WARN 2 | SKIP 65 | PASS 2113]`. Three of the 27 failures were caused by the plan's tests running in installed-package context; focused validation now covers the corrections in `e960a4b` and `b799894`.

- **Fixed in this plan (3):** `test-api-documentation.R:17` could not find source Rd files; `test-documented-workflow.R:451` expected an empty diagnostics list instead of the Plan 04-05 version-1 success envelope; `test-public-solver-contract.R:401` could not find source `NAMESPACE`. Source focused tests pass, and installed docs/NAMESPACE checks pass.
- **Benchmark source-tree availability (6):** four `test-benchmark-correctness-gate.R` cases at lines 164, 458, 718, and 821, and two `test-installed-benchmark-execution.R` cases at lines 178 and 267, failed because the installed check context has no GEModelR source tree.
- **Compatibility helper (1):** `test-compatibility-helpers.R:79` expected names on `dimnames(selected)` (`region`, `commodity`); the result's names were absent.
- **Provenance inventory (4):** `test-provenance-inventory.R:565` and `:617` expected 291 rows while the live inventory had 314; `:656` and `:657` found checked-in provenance key lists diverged from the live inventory.
- **Release-gate expectations (9):** `test-release-gates.R:244`, `:246`, `:251`, `:257`, `:258`, `:260`, `:1118`, `:1804`, and `:1806` expected blocked-state/reason-code outcomes; the repository instead reported invalid state due to provenance duplicate-key/inventory failures.
- **Sparse-core fixture lifecycle (4):** `test-sparse-core.R:282`, `:358`, `:457`, and `:478` failed because `solveModel` required a successfully loaded TABLO model.

The four package-check warnings were: apparent object/library files and an installed package under the source tree; executable shared libraries; non-portable paths including `.benchmark-data/GTAP 12a`; and check directories `..Rcheck` and `tabloToR.Rcheck`. The four notes were: hidden files/directories; non-standard `License` metadata; `LazyData` without a `data` directory; and the compiled-code `abort` symbol note.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking test contract] Updated manifest parity for an explicit namespace.**

- **Found during:** Task 2
- **Issue:** The manifest test required every historical manifest row to be exported, conflicting with the plan's explicit supported-tier-only export.
- **Fix:** Restrict the parity assertion to rows marked `kind == "export"` and `tier == "supported"`.
- **Files modified:** `tests/testthat/test-compatibility-manifest.R`
- **Verification:** Focused compatibility-manifest test passed.
- **Committed in:** `a13561d`

**2. [Rule 1 - Stale test expectation] Updated the documented legacy workflow diagnostics assertion.**

- **Found during:** Package regression validation
- **Issue:** The test expected `lastDiagnostics` to be empty after successful legacy solve, contrary to Plan 04-05's schema-version-1 attempt envelope.
- **Fix:** Assert the fixed field order, legacy engine, requested Matrix backend, successful status, accepted numerical state, and non-retryable result.
- **Files modified:** `tests/testthat/test-documented-workflow.R`
- **Verification:** Focused documented-workflow test passed.
- **Committed in:** `e960a4b`

**3. [Rule 3 - Installed test context] Added generated-artifact lookup fallbacks.**

- **Found during:** `R CMD check`
- **Issue:** Package-check tests execute without the source `man/` and `NAMESPACE` files at their repository-relative paths.
- **Fix:** Read help from `tools::Rd_db("GEModelR")` and NAMESPACE from the installed package path when source artifacts are absent.
- **Files modified:** `tests/testthat/test-api-documentation.R`, `tests/testthat/test-public-solver-contract.R`
- **Verification:** Focused source tests passed; installed Rd test and installed namespace assertion passed.
- **Committed in:** `e960a4b`, `b799894`

**Total deviations:** 3 auto-fixed (two Rule 3 test-context repairs, one Rule 1 stale expectation).
**Impact on plan:** All deviations keep checks aligned with the narrowed namespace and Plan 04-05 diagnostics contract.

## Issues Encountered and Deferred

- The Phase 02 identity-source gate reports 416 mixed-case matches against the reviewed expectation of 328; uppercase remains 2/2. The preceding count was 391/328. The Phase 02 reviewed identity map was left unchanged as directed; this known gate is recorded in the phase-local deferred items.
- The check snapshot also reports provenance inventory 314 versus the historical 291 and release-gate invalid/duplicate-key results. These inventory/review artifacts need their owning phase's review before they can be updated.
- The R CMD check source-tree benchmark tests and sparse-core fixture errors remain unresolved; see the complete failure snapshot above.
- Existing source/shared-library and nested check-directory artifacts produced package warnings. They were preserved as unrelated workspace state.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The GEModel namespace and generated reference help are ready for Phase 5 and Phase 6 consumers. Focused API/documentation tests pass. Package-level qualification still needs the documented source-tree, provenance, fixture, and repository-artifact failures reconciled before CI/release qualification can claim a clean `R CMD check`.

## Self-Check: PASSED

- Summary file exists at the required phase-local path.
- All five plan implementation/fix commits (`773028e`, `9fa68bb`, `a13561d`, `e960a4b`, `b799894`) are present in git history.

---
*Phase: 04-public-api-and-solver-boundaries*
*Completed: 2026-09-30*
