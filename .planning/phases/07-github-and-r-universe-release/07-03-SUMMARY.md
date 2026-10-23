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
  tokens: 20749
  tasks: 2
  commits: 9
tech-stack:
  added: []
  patterns: [explicit Git source projection, fixture-labelled qualification, single retained archive]
key-files:
  created:
    - .planning/phases/07-github-and-r-universe-release/07-REVIEW.md
  modified:
    - tools/release/prepare-release.cjs
    - tools/release/prepare-release.test.cjs
    - tools/release/README.md
    - docs/release/PUBLICATION-PLAN.md
    - docs/release/public-source.json
    - docs/release/PUBLICATION-APPROVAL.md
key-decisions:
  - "The canonical development clone is guard-only; every built package archive must name the frozen projected public commit."
  - "Injected subprocess fixtures never qualify a real candidate; unsupported runtime still permits completion of local preparation."
  - "Freeze e46ea70e737bc709880458ab1548244a2fd525cd as this candidate; later private handoff/summary commits do not silently change it."
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
development_source_commit: e46ea70e737bc709880458ab1548244a2fd525cd
development_source_tree: 6ef6c2d60b4dce13bea34f31b47473bc96b40673
public_source_commit: ee8f5d26c9565db3407567e065633a0b0252da9a
public_source_tree: cb74d2a4000c3d84ae005d05c63769597988d24a
review_sha256: e9a41d268ac88238bff47ded201fe3d0bbd391365fbc288e288e0d0a05b3b4dd
private_manifest_file_sha256: 66782d716bd9b9b9e0cf7ca6809068d898b266787b369b01319be98cea5159d5
post_review_fixes: [CR-07-01, CR-07-02]
duration: 12min initial execution plus focused post-review repair
completed: 2026-10-23
status: complete
---

# Phase 07 Plan 03: Frozen local candidate and qualification Summary

**An exact public-source root and review packet now exist locally, with projected-source archive orchestration and an actual blocked publication-readiness result.**

## Accomplishments

- Added `stage-public-source`, `qualify`, and `verify --for-publication` to the existing packet CLI.
- Projected exactly the policy's 197 public files from the refreshed 665-path committed source; all 468 exclusions have reasons. The post-review refresh explicitly excludes the new private review, summary and pending approval records.
- Preserved selected R/src blobs and modes, required notices, the original source index and ref IDs, and private development history. Public Git has one deterministic root commit, no remote, and only the reviewed main ref plus an optional matching intended tag.
- Qualification probes existing prerequisites first, retains one actual offline guard result from the private selected-source clone, and builds only the projected public commit when supported. Scan/check/install use one retained archive and its recorded `archive_source_commit`/SHA-256.
- Completed the private handoff with actual source/tree, policy/notes/registry/smoke/review fingerprints and a precise later action list. Generated packet paths and raw logs remain external to Git.

## Verification

- Combined focused packet/smoke-negative and existing scanner suite after the post-review fixes: **38/38 tests pass**, about 7.7 seconds; the initial execution had 35/35 passes.
- Tests cover complete separate-root projection, private-path and unknown-path rejection, mutation, allowed/conflicting refs, unchanged original index/refs, actual R prerequisite-code parsing, unsupported-runtime completion, and source/archive/readiness mismatches.
- Mocked archive/subprocess successes are labelled `evidence_kind=fixture`; the publication predicate rejects them. They are unit evidence, never a real package-check or numerical pass.
- The actual packet's local `verify` passed after staging and qualification, with review digest `e9a41d268ac88238bff47ded201fe3d0bbd391365fbc288e288e0d0a05b3b4dd`.
- The actual installed prerequisite was Matrix 1.6.3, below 1.6-5. No actual R package archive build, archive scan/check, installation or numerical smoke ran; archive fields remain `not_built` and package steps remain `not_run`.
- One actual offline canonical guard evaluation returned state `invalid`, exit 1 and `PROVENANCE_KEY_MISMATCH`. No canonical evidence changed and no retry/Phase 06 gap loop was started.
- The actual stricter publication check returned exit 1 and `FAIL PUBLICATION_NOT_READY`, as required.
- Scoped `git diff --check` passed. No package/native/API change, dependency installation/upgrade, baseline rerun, hosted dispatch or external publication occurred.

## Task Commits

1. Task 1 RED: `39444ce` — projected-source and qualification regression cases.
2. Task 1 GREEN: `a0a4266` — source staging, qualification and usage.
3. Task 2: `e6eec29` — frozen actual candidate and readiness handoff.
4. Post-review fix: `25e065a` — actual guard/build checkout bytes, modes and paths bound before execution.
5. Post-review fix: `8b8b242` — realistic supported R check parsing and separate explicit URL disposition.
6. Refreshed candidate selection: `e46ea70` — repaired source policy with private review evidence excluded.

## Focused Post-Review Repair

Both new tooling findings were reproduced and repaired within Phase 07. CR-07-01 now has a temporary external Git attributes/smudge fixture that independently demonstrates transformed ordinary checkout bytes; actual guard/build inputs remain the frozen blobs and modes under both external filters and tracked CRLF attributes. CR-07-02 now uses a realistic R4.3 clean log without an invented URL step. Clean checks advance to installation while dedicated failed/unavailable/disabled URL evidence blocks publication; an actual disabled R URL-probe fixture makes no network request.

One fresh packet was generated from the repaired selected commit. Its actual runtime and single offline guard evaluation remain unavailable/invalid respectively, so no package build/install or URL network check ran. The previous packet was retained unchanged. The handoff now distinguishes the review-content digest from the raw private/public manifest-file digests; none is a signature or maintainer approval. Independent re-review of the implemented fixes is pending; no clean-review claim is made here.

## Decisions and Limitations

The selected development commit is `e46ea70e737bc709880458ab1548244a2fd525cd`; projected public commit is `ee8f5d26c9565db3407567e065633a0b0252da9a`. Later private documentation commits do not alter this frozen candidate. A later source revision needs a new explicit policy selection and packet.

REL-02 remains pending. The candidate is reviewable but not publishable under the actual results and continuing local-only instruction. Plan 07-04 is the single concrete publication decision; no executable publication approval should be requested while readiness remains blocked. Existing public CI/private-evidence dependencies, legal/attribution holds and accepted Phase 06 limitations remain visible in the handoff.

## Deviations from Plan

No scope deviation. The specific Phase 07 context authorizes autonomous local preparation and reserves user approval for the final publication boundary; the tracer's real focused verification was rerun successfully before the actual-candidate expansion. No manual numerical pass or `--auto` flag was inferred.

The pre-existing dirty `.planning/WINDOWS.md` was preserved under the executor's ownership constraint. Planned unavailable checks are recorded here and in the actual external packet rather than appending to that user-modified ledger.

## Self-Check: PASSED

- All modified tooling/document paths exist; no new source path was omitted from the selected policy.
- Task commits `39444ce`, `a0a4266`, and `e6eec29` exist.
- The external packet passes local verification and fails stricter publication verification for its actual unavailable/invalid evidence.
- REL-02 remains pending and canonical provenance plus unrelated user work remain unchanged.
