---
phase: 05-portable-native-build-and-ci
plan: 07
subsystem: infra
tags: [R, Matrix, GitHub-Actions, evidence, provenance]
requires:
  - phase: 05-06
    provides: original 30 candidate outcomes and 24 passing supported hosted tuples
provides:
  - Matrix minimum 1.6-5 selected from five passing oldrel-1 platform/build rows
  - matching DESCRIPTION minimum and README interval through current Matrix 1.7-6
  - checked original job/artifact provenance and complete eligible official CRAN release prefix
  - authentic final declared-metadata confirmation on all 24 supported hosted tuples
affects: [CI-01, PORT-01, release]
tech-stack:
  added: [base-R offline evidence gate, Python collection adjuncts]
  patterns: [checksum-bound hosted provenance, complete eligible release prefix, separate pre/post-metadata proof]
key-files:
  created:
    - tools/ci/verify-matrix-floor-evidence.R
    - tools/ci/test-matrix-floor-evidence.R
    - tools/ci/normalize-matrix-provenance.py
    - tools/ci/collect-matrix-catalog.py
    - .gitattributes
    - .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE.md
    - .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE-FINAL-METADATA.md
  modified:
    - DESCRIPTION
    - README.md
    - .planning/phases/05-portable-native-build-and-ci/hosted-evidence/
    - .planning/phases/05-portable-native-build-and-ci/05-VALIDATION.md
key-decisions:
  - Select provisional Matrix 1.6-5 only after all five oldrel-1 rows pass; no fallback release was needed.
  - Preserve all 30 original candidate outcomes and the six individually proven exclusions.
  - Keep the original pre-metadata support proof reproducible and retain final metadata confirmation separately with explicit supported-run input.
  - Report the informational full-check exit and findings independently of the passing supported matrix.
requirements-completed: [CI-01, PORT-01]
actuals:
  tokens: 102947
  tasks: 2
  commits: 7
duration: 44min including hosted verification and review repairs
completed: 2026-10-05
status: complete
coverage:
  - id: D1
    description: Matrix floor selected using checked oldrel-1 source-install and solver evidence
    requirement: PORT-01
    verification:
      - kind: integration
        ref: tools/ci/test-matrix-floor-evidence.R --expect-final-metadata; 71 checks passed
        status: pass
    human_judgment: false
  - id: D2
    description: Final declared minimum and endpoint passed every supported hosted combination
    requirement: CI-01
    verification:
      - kind: e2e
        ref: https://github.com/DavidZenz/tabloToR/actions/runs/37277215498; 24 supported row contracts passed
        status: pass
      - kind: integration
        ref: tools/ci/verify-matrix-floor-evidence.R --verify-final-metadata --evidence .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE-FINAL-METADATA.md
        status: pass
    human_judgment: false
---

# Phase 05 Plan 07: Evidence-backed Matrix minimum Summary

**Matrix 1.6-5 is the declared minimum, backed by five oldrel-1 source-install/solver results and a successful final metadata run across all 24 supported combinations.**

## Performance

- First task commit: 2026-10-05T07:19:10Z. Closeout: 2026-10-05, following the final hosted run and evidence review repairs.
- Tasks: 2/2 complete. The orchestrator owns STATE, ROADMAP, shared requirements and phase completion.
- Actual tokens are realized diff characters divided by four over the task-owned implementation, metadata, evidence and validation files since `0e3834f`: 411,786 characters, rounded upward to 102,947 tokens. Root review reports, STATE and handoff changes are excluded. Summary commit is included in the seven plan/fix/evidence/summary commits, alongside earlier continuation commits.

## Accomplishments

### 05-07-T1: Floor selection

The original primary input remains the complete 30-row candidate artifact from run `37273713572`, attempt 1. Matrix 1.6-5 passed all five required oldrel-1 R 4.5.3 pairings: Linux/macOS/Windows serial and Linux/Windows OpenMP. The supported pre-metadata run `37274723569` passed all 24 valid tuples. No successor was substituted and no fallback candidate was required.

The offline base-R gate checks original manifest digests, strict normalized job/artifact identity, actual source and solver step outcomes, exact retained CSV payloads and failed-source logs. The official CRAN catalog includes 1.6-5 and 1.7-0 through 1.7-6 with actual source DESCRIPTION R requirements, ordered archive identities and a checked snapshot. A later candidate can be selected only after the complete eligible ascending prefix has five rows per candidate and every predecessor fails the all-five-pass condition. Narrow `.gitattributes` rules preserve all checksum-bound evidence bytes during Windows checkout.

### 05-07-T2: Final metadata and hosted confirmation

Commit `a0e0181` declares `Matrix (>= 1.6-5)` in DESCRIPTION and documents `Matrix support: 1.6-5 through 1.7-6` plus the current-endpoint refresh and floor-advance policy in README. SuiteSparse unavailable wording and explicit Matrix remediation are preserved.

[Final hosted run 37277215498](https://github.com/DavidZenz/tabloToR/actions/runs/37277215498), attempt 1, executed head `a0e01810cfdc7afdcfcf7a109afc3ab39a4d43b4` and completed **success with 26/26 jobs**. Every one of the **24 valid candidate jobs** source-installed its exact Matrix endpoint and passed the installed core contracts, including the declared minimum compatibility test. Exact aliases resolved to oldrel-1 R 4.5.3, release R 4.6.1 and devel R 4.7.0. All five oldrel-1 floor pairings remain present. There are 14 serial and 10 OpenMP supported tuples.

The independent official endpoint resolver artifact records Matrix **1.7-6**, source `https://cran.r-project.org/src/contrib/Matrix_1.7-6.tar.gz`, resolution `2026-10-05 07:21:17 UTC` and R >= 4.4. The final manifest retains actual run/job/step/artifact identities, artifact digests and extracted-file SHA256 values. Its checked normalization contains 24 rows and 24 exact CSV payloads. No local or synthetic candidate row was added.

`MATRIX-FLOOR-EVIDENCE.md` retains the original pre-metadata proof and exact planned default command. The companion `MATRIX-FLOOR-EVIDENCE-FINAL-METADATA.md` is generated by the same validator using explicit `--supported hosted-evidence/matrix-candidate-evidence-37277215498-1.csv`. Both metadata gates pass without consulting or loading Matrix. The six exclusions remain the original individually failed source rows; their outcomes and reason logs are unchanged.

## Verification

- Both planned task command contracts pass. The final confirmation's explicit supported-run gate also passes.
- `tools/ci/test-matrix-floor-evidence.R --expect-final-metadata`: **71 checks passed**, including contradictory provenance, tampering, missing/failed rows, source metadata and omitted predecessor probes.
- Final confirmation `--verify-final-metadata` passes in a clean R process with an explicit assertion that Matrix is absent from loaded namespaces.
- `git diff --check` passes. No new R build/install or full check was needed for evidence closeout.
- Final API and retained row checks establish all 24 exact tuples, exact endpoint versions, actual successful steps/jobs and five floor pairings.

The latest representative informational report preserves original exit **1**, **1,868 passes, nine failures, 164 skips, two ERRORs, two WARNINGs and one NOTE**. Its job succeeds because that full check is deliberately informational. Existing full-suite failures, missing pdflatex and provisional-license findings remain deferred; this plan makes no claim that they were fixed. The inherited Phase 04 baseline is labeled separately and remains 2,364 passes, 19 failures, 65 skips, one ERROR, four WARNINGs and four NOTEs.

Complete raw check logs, original status, source archive and check directory stay under `/tmp/gemodelr-hosted-37277215498/artifacts/representative-check-37277215498-1/`. The original hosted job-log archive stays `/tmp/gemodelr-hosted-37277215498/job-logs.zip`. Only bounded evidence CSVs, JSON metadata, normalized CSV/DCF, exact small payloads, resolver text and the Markdown report are versioned.

## Task Commits

1. **05-07-T1, validate hosted floor evidence:** `85ca4f8`.
2. **05-07-T2, declare verified Matrix minimum:** `a0e0181`.
3. **Review repair, checked hosted provenance:** `70555e6`.
4. **Review repair, complete eligible official release prefix:** `8bfb52c`.
5. **Windows checksum-byte protection:** `45d724c`.
6. **Final hosted metadata evidence closeout:** `fee003b`.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 - Bug] Evidence gate did not bind rows to retained hosted provenance.** Repaired original JSON/normalized metadata/payload checks and required actual matching step outcomes in `70555e6`; collection adjunct preserves small original payloads. Twenty provenance probes were added.

**2. [Rule 1 - Bug] Fallback could skip an earlier eligible official release.** Added complete ordered official CRAN catalog and actual source DESCRIPTION validation in `8bfb52c`, with 21 catalog/prefix probes. No fallback run was fabricated or needed for the actual passing floor.

**3. [Rule 2 - Missing critical] Checksum-bound evidence needed newline protection.** Added narrow `.gitattributes` rules in `45d724c`; all 84 earlier protected evidence files survived a disposable `core.autocrlf=true` export byte-for-byte, and both metadata verification and 71 probes passed there.

## Issues and readiness

No authentication gate or manual setup arose during final artifact collection. The earlier hosted checkpoint was satisfied by authentic completed evidence. Phase verification passed at 22/22 distinct must-haves; no human verification remains. Existing informational package-check findings are tracked in `deferred-items.md` and the cross-phase WINDOWS ledger.

The package's dependency promise is traceable to actual pre- and post-metadata hosted evidence. GSD tracking advanced to Phase 6; the remaining orchestrator closeout is to update the authorized draft PR and push the aggregate branch.

## Self-Check: PASSED

All created implementation/evidence files exist, all six listed task/fix/evidence commits exist, and both original and final confirmation metadata records regenerate from retained authentic provenance. The canonical 30-row input and unrelated checkout changes are preserved.
