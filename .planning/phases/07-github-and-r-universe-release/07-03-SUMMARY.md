---
phase: 07-github-and-r-universe-release
plan: 03
subsystem: release-candidate
tags: [public-source, archive-identity, local-qualification, publication-handoff]
requires:
  - phase: 07-01
    provides: Committed-source packet and isolated installed smoke
  - phase: 07-02
    provides: Explicit source policy, notes, registry and external-action proposal
provides:
  - Separate deterministic public-source root with exact selected blobs and modes
  - Projected-source-only archive qualification and stricter publication validation
  - Actual locally verified candidate and private publication handoff
affects: [07-04, REL-02]
actuals:
  tokens: 12868
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [explicit Git source projection, fixture-labelled qualification, single retained archive]
key-files:
  created: []
  modified:
    - tools/release/prepare-release.cjs
    - tools/release/prepare-release.test.cjs
    - tools/release/README.md
    - docs/release/PUBLICATION-PLAN.md
key-decisions:
  - "The canonical development clone is guard-only; every built package archive must name the frozen projected public commit."
  - "Injected subprocess fixtures never qualify a real candidate; unsupported runtime still permits completion of local preparation."
  - "Freeze a0a42662a5a1199c5bf67276b97f772f83e68fa8 as this candidate; later private handoff/summary commits do not silently change it."
requirements-completed: []
coverage:
  - id: D1
    description: Exact isolated public projection, complete dispositions, original index/ref preservation and single-archive source binding
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
    description: Actual frozen local packet verifies; actual unsupported runtime and invalid release guard remain explicit
    requirement: REL-02
    verification:
      - kind: integration
        ref: tools/release/prepare-release.cjs#verify
        status: pass
    human_judgment: false
preparation_status: complete
qualification_status: unavailable
runtime_reason: MATRIX_BELOW_FLOOR
matrix_version: 1.6.3
matrix_minimum: 1.6-5
release_guard_status: invalid
release_guard_exit: 1
release_guard_reason_codes: [PROVENANCE_KEY_MISMATCH]
archive_status: not_built
archive_source_commit: not_built
archive_sha256: not_built
publication_readiness: blocked
publication_status: not_run
development_source_commit: a0a42662a5a1199c5bf67276b97f772f83e68fa8
development_source_tree: 57ceade529c648b68a1326d2122aff76647aa591
public_source_commit: 4041517a944ca67724b4ca45b53a6ba27911eea5
public_source_tree: de6ea107d489528280ed13294320c7996ff4b425
review_sha256: 7a61380fc34c9c8a632376b9090295b2281e37be12ddf0bc75c5fddd567ab833
duration: 12min approximately
completed: 2026-10-23
status: complete
---

# Phase 07 Plan 03: Frozen local candidate and qualification Summary

**An exact public-source root and review packet now exist locally, with projected-source archive orchestration and an actual blocked publication-readiness result.**

## Accomplishments

- Added `stage-public-source`, `qualify`, and `verify --for-publication` to the existing packet CLI.
- Projected exactly the policy's 197 public files from one 662-path committed source; all 465 exclusions have reasons. The policy already covered the selected commit exactly, so no policy bytes required an update.
- Preserved selected R/src blobs and modes, required notices, the original source index and ref IDs, and private development history. Public Git has one deterministic root commit, no remote, and only the reviewed main ref plus an optional matching intended tag.
- Qualification probes existing prerequisites first, retains one actual offline guard result from the private selected-source clone, and builds only the projected public commit when supported. Scan/check/install use one retained archive and its recorded `archive_source_commit`/SHA-256.
- Completed the private handoff with actual source/tree, policy/notes/registry/smoke/review fingerprints and a precise later action list. Generated packet paths and raw logs remain external to Git.

## Verification

- Combined focused packet/smoke-negative and existing scanner suite: **35/35 tests pass**, about 5.8 seconds.
- Tests cover complete separate-root projection, private-path and unknown-path rejection, mutation, allowed/conflicting refs, unchanged original index/refs, actual R prerequisite-code parsing, unsupported-runtime completion, and source/archive/readiness mismatches.
- Mocked archive/subprocess successes are labelled `evidence_kind=fixture`; the publication predicate rejects them. They are unit evidence, never a real package-check or numerical pass.
- The actual packet's local `verify` passed after staging and qualification, with review digest `7a61380fc34c9c8a632376b9090295b2281e37be12ddf0bc75c5fddd567ab833`.
- The actual installed prerequisite was Matrix 1.6.3, below 1.6-5. No actual R package archive build, archive scan/check, installation or numerical smoke ran; archive fields remain `not_built` and package steps remain `not_run`.
- One actual offline canonical guard evaluation returned state `invalid`, exit 1 and `PROVENANCE_KEY_MISMATCH`. No canonical evidence changed and no retry/Phase 06 gap loop was started.
- The actual stricter publication check returned exit 1 and `FAIL PUBLICATION_NOT_READY`, as required.
- Scoped `git diff --check` passed. No package/native/API change, dependency installation/upgrade, baseline rerun, hosted dispatch or external publication occurred.

## Task Commits

1. Task 1 RED: `39444ce` — projected-source and qualification regression cases.
2. Task 1 GREEN: `a0a4266` — source staging, qualification and usage.
3. Task 2: `e6eec29` — frozen actual candidate and readiness handoff.

## Decisions and Limitations

The selected development commit is `a0a42662a5a1199c5bf67276b97f772f83e68fa8`; projected public commit is `4041517a944ca67724b4ca45b53a6ba27911eea5`. Later private documentation commits do not alter this frozen candidate. A later source revision needs a new explicit policy selection and packet.

REL-02 remains pending. The candidate is reviewable but not publishable under the actual results and continuing local-only instruction. Plan 07-04 is the single concrete publication decision; no executable publication approval should be requested while readiness remains blocked. Existing public CI/private-evidence dependencies, legal/attribution holds and accepted Phase 06 limitations remain visible in the handoff.

## Deviations from Plan

No scope deviation. The specific Phase 07 context authorizes autonomous local preparation and reserves user approval for the final publication boundary; the tracer's real focused verification was rerun successfully before the actual-candidate expansion. No manual numerical pass or `--auto` flag was inferred.

The pre-existing dirty `.planning/WINDOWS.md` was preserved under the executor's ownership constraint. Planned unavailable checks are recorded here and in the actual external packet rather than appending to that user-modified ledger.

## Self-Check: PASSED

- All modified tooling/document paths exist; no new source path was omitted from the selected policy.
- Task commits `39444ce`, `a0a4266`, and `e6eec29` exist.
- The external packet passes local verification and fails stricter publication verification for its actual unavailable/invalid evidence.
- REL-02 remains pending and canonical provenance plus unrelated user work remain unchanged.
