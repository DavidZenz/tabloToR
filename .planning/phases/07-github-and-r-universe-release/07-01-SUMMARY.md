---
phase: 07-github-and-r-universe-release
plan: 01
subsystem: release-tooling
tags: [release-packet, Git, Node, installed-smoke, source-integrity]
requires:
  - phase: 06
    provides: Accepted qualification limitations and existing public artifact scanner
provides:
  - Committed-source local release packet preparation and integrity verification
  - Standalone selected-library numerical smoke with pre-load runtime checks
affects: [07-03, 07-04, REL-02]
actuals:
  tokens: 11676
  tasks: 3
  commits: 7
tech-stack:
  added: []
  patterns: [argument-vector Git reads, private/public artifact separation, Git object identity verification]
key-files:
  created:
    - tools/release/prepare-release.cjs
    - tools/release/prepare-release.test.cjs
    - tools/ci/run-installed-release-smoke.R
    - tools/release/README.md
  modified: []
key-decisions:
  - "Local packet verification establishes source/content integrity, never publication authorization or package qualification."
  - "The retained private commit object and reconstructed source blobs/tree bind exported bytes to the selected Git identities."
  - "Unsupported actual Matrix runtime remains not_run for numerical installation evidence; negative fixtures never create a numerical pass."
requirements-completed: []
coverage:
  - id: D1
    description: Committed-source packet creation, private/public separation, integrity checks, and source-workspace preservation
    requirement: REL-02
    verification:
      - kind: integration
        ref: tools/release/prepare-release.test.cjs
        status: pass
      - kind: integration
        ref: tools/ci/check-public-content.test.cjs
        status: pass
    human_judgment: false
  - id: D2
    description: Standalone installed-smoke runner parses and rejects missing inputs, bad metadata, unsupported Matrix, and mismatched R-universe source before loading
    requirement: REL-02
    verification:
      - kind: unit
        ref: tools/release/prepare-release.test.cjs#installed smoke requires explicit inputs and never accepts a missing library
        status: pass
      - kind: unit
        ref: tools/release/prepare-release.test.cjs#installed smoke rejects bad metadata and the actual declared Matrix floor before loading
        status: pass
      - kind: other
        ref: Rscript --vanilla parse of tools/ci/run-installed-release-smoke.R
        status: pass
    human_judgment: false
installed_numerical_smoke_status: not_run
installed_numerical_smoke_reason: MATRIX_BELOW_FLOOR
matrix_installed_versions: [1.6.3, 1.5.3]
publication_status: not_run
duration: 12min
completed: 2026-10-23
status: complete
---

# Phase 07 Plan 01: Local release packet and installed smoke Summary

**A local CLI now exports one committed source revision into separate private/public packet areas, verifies its Git and SHA-256 identities, and distributes an isolated numerical smoke runner.**

## Accomplishments

- Added `prepare --source-ref REF --output DIRECTORY --tag TAG` and `verify --packet DIRECTORY` using Node built-ins and read-only argument-vector Git subprocesses.
- Recorded source commit/tree, package/version, intended unsigned annotated tag, a tag-pinned registry draft, executing tool/scanner hashes, and explicit unexecuted-check states. Working-tree edits and untracked files are excluded.
- Added field allowlists, canonical output guards, nonempty-output refusal, source-link rejection, pre-read packet-link checks, deterministic inventories, mutation detection, and original Git commit/blob/tree verification.
- Reused the existing scanner for staged public artifacts without extending its policy to public Git history.
- Added a self-contained R runner with explicit library/version/channel/commit inputs, installed namespace ownership checks, Matrix minimum checks, R-universe RemoteSha verification, and the independent expected solution `c(0, 6, 0)` within `1e-12`.

## Task Commits

1. Task 1 RED — `972f548`: specify committed release packet workflow.
2. Task 1 GREEN — `8e8f464`: prepare committed local release packets.
3. Task 2 RED — `2a3e2a7`: cover release packet mutation and path boundaries.
4. Task 2 GREEN — `b7803de`: validate packet identities before reading or reporting.
5. Task 3 — `d37d384`: isolate installed release smoke and runtime checks.

Task 1's real CLI verification was rerun successfully after its GREEN commit before expansion. The orchestrator applied the locked autonomous local-preparation scope over a redundant manual tracer pause; no manual pass or `--auto` flag was invented. The final publication checkpoint remains mandatory.

## Verification

- `rtk node --test tools/release/prepare-release.test.cjs tools/ci/check-public-content.test.cjs`: **28 tests passed**, zero failed/skipped/todo. This includes 14 packet/smoke-negative tests and the 14 existing scanner tests. The final recorded run took about 8.49 seconds; an earlier equivalent run took about 3.48 seconds. These are test durations, not package performance benchmarks.
- `rtk Rscript --vanilla -e 'invisible(parse(file="tools/ci/run-installed-release-smoke.R"))'`: passed.
- The actual selected installed GEModelR library rejected the smoke before namespace loading with `FAIL MATRIX_BELOW_FLOOR` and exit 1. Read-only inventory found Matrix 1.6.3 and 1.5.3. **The actual numerical branch is not_run**, not a pass.
- The DESCRIPTION-only negative fixtures check rejection before namespace loading; they do not stand in for installed numerical evidence.
- Fixture canaries confirmed unchanged source index bytes and refs, no dirty/untracked source collection, no remote Git operation, no destructive output replacement, and no read of linked outside manifest content.
- Scoped staged whitespace checks passed before each implementation commit.
- The GSD narrative progress updater reported unscoped milestone status and skipped its percentage rewrite; the state counters and roadmap separately reflect one of four Phase 07 summaries. This is tracking output, not a test-suite result.

No package install, dependency upgrade, R CMD check, full package suite, GTAP benchmark, tag creation, push, hosted dispatch, or publication ran. The selected real library's historical bare `Matrix` Imports declaration is accepted syntactically while the project minimum is still enforced; a stricter selected-package declaration also remains binding.

## Decisions and Limitations

`prepared`/`verified` mean local integrity only. The packet still records `publication_authorized=false`, `publication_readiness=unqualified`, `public_source_commit=not_created`, and check statuses `not_run`. A missing release-note draft is explicitly `unavailable`. Public source projection, exact archive qualification, authorization, and two-channel installation are the later plans' work. REL-02 remains pending.

The GitHub/local source commit is labeled `caller_attested_source`; installed R-universe metadata is checked directly. The runner's source-commit input alone is not proof of GitHub source provenance.

No implementation stubs prevent this plan's local preparation goal. The unsupported numerical runtime is the planned availability branch, not a newly introduced defect or a reason to reopen Phase 06. Existing user changes and the temporary orchestrator config are untouched.

## Deviations from Plan

No scope deviation. During Task 2's TDD cycle, failing negative cases exposed malformed manifest acceptance and pre-check linked reads in the new tracer implementation; the GREEN change corrected both and added original Git-object verification. During Task 3, actual library inspection showed a historical bare Matrix import; the runner now handles that declaration while enforcing the unchanged project minimum.

## Next Plan Readiness

Plan 07-02 can prepare the release drafts independently. Plan 07-03 can extend the local packet tool with its explicit public-source projection and exact archive identity contract. Preserve Phase 06 acceptance and the local-only/publication boundary.

## Self-Check: PASSED

All four created implementation files and all five task commit objects were verified on disk/in Git. The focused checks above passed. Only the four owned implementation paths were staged in the task commits; no tracked deletion occurred. Source/content measurements for `actuals.tokens` use realized diff characters divided by four, rather than harness usage.
