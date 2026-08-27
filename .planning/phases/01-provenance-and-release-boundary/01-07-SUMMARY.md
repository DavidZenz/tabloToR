---
phase: 01-provenance-and-release-boundary
plan: 07
subsystem: release-governance
tags: [r, provenance, attribution, release-gates, license, tdd]

requires:
  - phase: 01-08
    provides: strict name-evidence verification
  - phase: 01-09
    provides: expression-hash provenance inventory
provides:
  - fail-closed integrated release evaluation over current Git-backed source
  - exact attribution parity across six public destinations
  - hash-bound pending/reviewed package-license decision contract
  - self-contained positive release fixture and exact negative mutation matrix
affects: [release-qualification, dependency-audit, attribution-resolution, phase-03]

actuals:
  tokens: 21401
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - isolated loading of repository verification tools
    - source-derived synthetic evidence graphs
    - exact parser and reason-code mutation matrices

key-files:
  created:
    - docs/provenance/LICENSE-DECISION.md
  modified:
    - tools/check_release_gates.R
    - tests/testthat/test-release-gates.R
    - docs/release/RELEASE-GATES.md

key-decisions:
  - "Integrated release readiness must validate freshly extracted Git-backed source before trusting provenance ledgers."
  - "Attribution release evidence is complete only when all six public destinations preserve reviewed people, roles, and evidence keys."
  - "A pending license decision is valid only with the dependency-audit blocker; a reviewed decision requires an under-root hash-bound audit and an R-valid exact license expression."
  - "The positive release path is proven by source-derived synthetic evidence, while the checked-in tree retains exactly the two approved blockers."

patterns-established:
  - "Evidence graph: derive expected keys, hashes, ledgers, destinations, and decisions from committed fixture source."
  - "Fail-closed matrix: mutate one boundary at a time and assert repository state, parser status, and stable reason code."

requirements-completed: [PROV-01, PROV-02, PROV-03, PROV-04]

coverage:
  - id: D1
    description: "Integrated evaluation validates exact contract version and fresh Git-backed current-source provenance."
    requirement: PROV-01
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#integrated evidence version and current source"
        status: pass
      - kind: integration
        ref: "tools/provenance_inventory.R --check --expected docs/provenance/EXPECTED-KEYS.csv"
        status: pass
    human_judgment: false
  - id: D2
    description: "Attribution destinations and pending/reviewed license decisions are exact and fail closed."
    requirement: PROV-02
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#attribution destinations and reviewed license evidence"
        status: pass
      - kind: integration
        ref: "tests/testthat/test-attribution-contract.R"
        status: pass
    human_judgment: false
  - id: D3
    description: "A self-contained synthetic release graph proves eligibility and exact boundary failures without changing production blockers."
    requirement: PROV-04
    verification:
      - kind: integration
        ref: "tests/testthat/test-release-gates.R#complete integrated fixture and mutation matrix"
        status: pass
      - kind: integration
        ref: "tools/check_release_gates.R --assert-blocked"
        status: pass
    human_judgment: false

duration: 41min
completed: 2026-08-27
status: complete
---

# Phase 01 Plan 07: Integrated Release Gate Summary

**Current-source provenance, six-destination attribution, and hash-bound license evidence now form one fail-closed release decision with a fully proven synthetic positive path.**

## Performance

- **Duration:** 41 min
- **Started:** 2026-08-27T09:37:59Z
- **Completed:** 2026-08-27T10:19:08Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Bound integrated eligibility to exactly one evidence version and freshly extracted, Git-backed R/native source validated through the shared provenance contract.
- Required reviewed attribution people, roles, and evidence keys across DESCRIPTION, README, CITATION, PROVENANCE, CONTRIBUTORS, and NEWS.
- Added a canonical pending license-decision schema plus a reviewed transition requiring safe under-root audit evidence, exact MD5 and DESCRIPTION parity, completed review, and R license validation.
- Replaced the copied-ledger ready fixture with a complete synthetic source/evidence graph and a table-driven negative matrix covering every integration boundary.
- Preserved the real repository's exact blockers: `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED`.

## Task Commits

Each task was committed atomically with TDD RED and GREEN gates:

1. **Task 1: Trace one real source definition through the integrated gate**
   - `d2194aa` — test(01-07): add failing integrated source contracts
   - `2a8e607` — feat(01-07): bind release gate to current source
2. **Task 2: Bind public attribution destinations and exact license evidence**
   - `79bd7e9` — test(01-07): add failing attribution and license contracts
   - `34c20ea` — feat(01-07): bind attribution and license evidence
3. **Task 3: Replace the hollow ready fixture with complete release evidence**
   - `050ba21` — test(01-07): require self-contained release fixture
   - `e754dec` — feat(01-07): prove complete integrated release graph

## Files Created/Modified

- `tools/check_release_gates.R` — integrated source, attribution destination, strict name, governance/repository, and package-license validators.
- `tests/testthat/test-release-gates.R` — real-source regressions, six-destination/license failures, complete synthetic graph, and exact mutation matrix.
- `docs/release/RELEASE-GATES.md` — executable predicate and stable reason-code parity.
- `docs/provenance/LICENSE-DECISION.md` — canonical pending state and reviewed transition contract.

## Decisions Made

- Mutable provenance ledgers cannot prove readiness without successful fresh extraction and Git evidence from the evaluated root.
- Public attribution is one cross-file contract; missing destinations, evidence keys, role parity, or reviewed identities invalidate release.
- License readiness cannot be inferred from a non-placeholder DESCRIPTION value. It requires an explicit reviewed decision bound to a dependency audit.
- Synthetic eligibility evidence must be internally derived and disposable; checked-in mutable evidence is not copied into a source-less ready fixture.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reconciled skipped derived state progress**
- **Found during:** Final state update
- **Issue:** The SDK correctly counted nine summaries but skipped the human-readable progress and velocity fields because the active phase is unscoped.
- **Fix:** Reconciled the progress bar, plan count, duration totals, recent trend, and last-activity narrative to the authoritative 9/11 summary count.
- **Files modified:** `.planning/STATE.md`, `.planning/WINDOWS.md`
- **Verification:** STATE frontmatter and prose now both report nine completed plans and ROADMAP reports 9/11.
- **Committed in:** Final plan metadata commit

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Planning metadata now matches disk state; implementation scope and release blockers are unchanged.

## Verification

- Release-gate suite: **354 passed**, 0 failed, 0 warnings, 0 skipped.
- Provenance inventory suite: **98 passed**, 0 failed, 0 warnings, 0 skipped.
- Attribution contract suite: **43 passed**, 0 failed, 0 warnings, 0 skipped.
- Provenance drift check: **250 reviewed rows / 250 expected keys**.
- Name report verification: **approved**.
- Isolated checker self-test: **pass**.
- `--assert-blocked`: **pass**, with all 12 parsers passing.
- `--offline`: expected nonzero exit with exactly the two intentional blockers.
- `git diff --check`: **pass**.

## TDD Gate Compliance

All three tasks have a failing `test(01-07)` RED commit followed by a `feat(01-07)` GREEN commit.

## Known Stubs

| File | Line | Stub | Reason |
| --- | ---: | --- | --- |
| `docs/provenance/LICENSE-DECISION.md` | 7 | `Description-License: What license is it under?` | Intentional pending value until the dependency compatibility audit produces reviewed hash-bound evidence. |

The corresponding DESCRIPTION license placeholder was pre-existing and is already tracked in `.planning/WINDOWS.md`. The new decision-record entry is also registered there.

## Issues Encountered

- The environment's patch helper cannot create its unprivileged namespace; repository patches were applied through Git's patch reader while preserving the required RTK command boundary.
- `R CMD check .` reached installation but failed on the known host toolchain mismatch: Linuxbrew binutils require GLIBC symbols unavailable on Debian 10. This pre-existing portability issue is already recorded in `deferred-items.md`; focused release and provenance verification passed.

## User Setup Required

None - no external service configuration or repository mutation was performed.

## Next Phase Readiness

- The integrated gate is authoritative over source, attribution, name, governance, repository, and license evidence.
- Release remains intentionally blocked only by `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and `ATTRIBUTION_IDENTITY_UNRESOLVED`.
- Resolving either blocker requires its explicit reviewed evidence transition; no further human approval was inferred.

## Self-Check: PASSED

All four plan artifacts exist and all six task commits are present in Git history.

---
*Phase: 01-provenance-and-release-boundary*
*Completed: 2026-08-27*

