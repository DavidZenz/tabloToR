---
phase: 07-github-and-r-universe-release
plan: 02
subsystem: release-documentation
tags: [release-proposal, public-source-policy, R-universe, installation, governance]
requires:
  - phase: 07-01
    provides: Local packet and selected-library smoke tooling
  - phase: 06
    provides: Accepted development qualification limitations
provides:
  - Concrete development-candidate release, registry, source/history, and external-action proposal
  - Explicit sorted public-source disposition for 662 current or planned paths
  - Pending-channel installation and proposed support/lifecycle guidance
  - Existing qualification/pkgdown push filters for both master and main
affects: [07-03, 07-04, REL-02]
actuals:
  tokens: 29795
  tasks: 3
  commits: 5
tech-stack:
  added: []
  patterns: [explicit per-path source disposition, pending-channel documentation, unchanged authority markers]
key-files:
  created:
    - docs/release/RELEASE-NOTES.md
    - docs/release/PUBLICATION-PLAN.md
    - docs/release/public-source.json
    - docs/release/runiverse/packages.json
  modified:
    - README.md
    - NEWS.md
    - GOVERNANCE.md
    - docs/release/VERSION-LIFECYCLE.md
    - .github/workflows/release-qualification.yaml
    - .github/workflows/pkgdown.yaml
key-decisions:
  - "Propose GEModelR 0.1.0 as a development candidate with annotated unsigned v0.1.0; publication and all external actions remain pending."
  - "A separately reviewed public root commit is proposed; private development history and canonical evidence remain unchanged."
  - "The source policy enumerates every committed path plus five planned private records; unknown paths require a new explicit disposition."
  - "Existing public CI/private-evidence dependencies are reported as readiness limitations, not solved by publishing private evidence or weakening guards."
requirements-completed: []
coverage:
  - id: D1
    description: Exact registry identity and explicit sorted tracked-file source policy with reasons and private exclusions
    requirement: REL-02
    verification:
      - kind: integration
        ref: Node assert checks of registry JSON, policy completeness/order/uniqueness, required credit/smoke paths, and note redaction
        status: pass
    human_judgment: false
  - id: D2
    description: Reviewable release/source-history proposal and pending installation/support/lifecycle drafts
    requirement: REL-02
    verification:
      - kind: other
        ref: Node source assertions and scoped git diff checks for public documentation and unchanged governance identity markers
        status: pass
    human_judgment: true
    rationale: Exact publication actions, public-source selection/history, notes, and proposed cadence await the existing final packet-bound maintainer decision in Plan 07-04.
  - id: D3
    description: Existing workflow push filters recognize both master and main with every other byte preserved
    requirement: REL-02
    verification:
      - kind: integration
        ref: Node comparison against committed workflow bytes with only branches master to master/main replacement
        status: pass
    human_judgment: false
duration: 7min approximately
completed: 2026-10-23
status: complete
---

# Phase 07 Plan 02: Release and public-source proposals Summary

**Concrete GEModelR 0.1.0 release, tag-pinned registry, public-source selection, installation, and support drafts are ready for review, with two local workflow filter updates.**

## Accomplishments

- Drafted `v0.1.0` as an annotated unsigned development-candidate tag, the canonical GitHub destination, the proposed registry repository/universe, exact later external effects, and the final publication approval boundary.
- Inventoried the 657 committed paths at the start of this plan and added explicit exclusions for its four new private draft/policy files plus its planned private summary. The source policy contains 197 includes and 465 reasoned exclusions, in stable bytewise order, with no implicit public inclusion. Plan 07-03 must refresh it against its selected exact revision before freezing the candidate.
- Kept private planning, provenance/release evidence, raw benchmark/repair records, scratch prototypes, and private historical path bindings out of the proposed public tree. The policy retains package code/tests/help, upstream credit, installed migration/compatibility records, deterministic examples, benchmark runners, and required smoke/release tools.
- Added pending-publication tag-pinned Git and R-universe/CRAN installation instructions, retained the migration and first-simulation paths, and described unsupported checks and benchmark-tool limitations in ordinary public language.
- Added a clearly proposed weekly triage/monthly-or-correctness-fix patch cadence without a guaranteed response/release schedule. The exact governance identity/authority/security markers were unchanged.
- Changed only the `branches: [master]` filter to `[master, main]` in each existing qualification/pkgdown workflow. Current branch, read-only permissions, scans, artifact-only publishing behavior, and hosted state were unchanged.

## Verification

All verification in this plan was scoped to the actual documentation/JSON/workflow changes. No package build, installation, test suite, benchmark, hosted dispatch, tag, or external write ran.

1. Node `assert/strict` verified the registry's single exact `GEModelR` entry, canonical Git URL, and `v0.1.0` tag.
2. Node assertions checked policy schema version, array shapes, every tracked path's disposition, unique relative paths, stable byte ordering, nonempty exclusion reasons, private-directory exclusion, and required credit/smoke paths. They also checked the development/unsigned/unverified note labels and absence of raw local/private evidence paths in the public note draft.
3. Node source assertions checked both proposed installation channels, CRAN fallback, migration/first-simulation links, the development-to-published transition, and the proposed cadence. Exact governance marker lines matched the preceding committed record.
4. Node compared each workflow to its preceding committed bytes and proved the only difference was the branch-filter replacement. It also asserted read-only permissions, disabled credential persistence, scan-before-upload ordering, absent Pages deployment, and unchanged current branch `master`.
5. Scoped `git diff --check` passed for all ten task files, including the final committed range.

These are passing source/format/integration assertions; they do not establish that the proposed channels exist or that a public package installation passed. REL-02 remains pending.

## Task Commits

1. `e301718` — `docs(07-02): draft exact release and public source proposal`.
2. `bd6dd67` — `docs(07-02): prepare installation and support guidance`.
3. `c68443f` — `ci(07-02): recognize main alongside development master`.

## Deviations from Plan

- **[Rule 2 — missing critical documentation consistency]** Replaced README links to internal benchmark-summary/optimization-note files excluded by the explicit public-source policy with accurate public benchmark limitations. Keeping those links would have produced broken public-source instructions. No numerical behavior or evidence was changed.
- The source inventory includes five explicitly named not-yet-committed private record paths so this plan's new drafts and summary are not implicitly public. This is a draft source disposition; Plan 07-03 remains responsible for complete exact-revision revalidation.

## Remaining Boundaries

The intended registry/domain and remote repository state are proposals, not probed facts. All exact source/public commit/tree and retained archive identities are intentionally pending Plan 07-03. Public-source workflows currently reference excluded private evidence; the publication handoff states that limitation explicitly and preserves the guards. The selected license, development version, private canonical provenance, rejected proposal, Phase 06 acceptance, and local-only direction remain unchanged.

No unintended runtime stubs were introduced. The pending identity/status fields in the draft publication plan are intentional inputs for Plan 07-03 and the final Plan 07-04 decision, not fabricated successful results. No additional release authority is inferred from these documents.

## Self-Check: PASSED

- All four created files and six modified task files exist.
- Task commits `e301718`, `bd6dd67`, and `c68443f` exist.
- Source/JSON/workflow assertions and scoped whitespace checks passed.
- Only owned task paths were committed; temporary configuration and unrelated user work were preserved.
