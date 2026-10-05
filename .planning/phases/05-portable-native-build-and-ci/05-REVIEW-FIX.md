---
phase: 05-portable-native-build-and-ci
fixed_at: 2026-10-05T07:48:49Z
review_path: .planning/phases/05-portable-native-build-and-ci/05-REVIEW.md
iteration: 2
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 05: Code Review Fix Report

**Source review:** `.planning/phases/05-portable-native-build-and-ci/05-REVIEW.md` (commit `417dd50`)
**Iteration:** 2

Two blockers were fixed in separate commits; zero skipped. Earlier iteration 1 is preserved in Git history (`2ed32f0`). A separate narrowly scoped portability adjunct was also authorized and committed. This pass did not install packages, run a full package check, edit the workflow or declared floor, push a branch, or fabricate hosted candidate results.

## Fixed Issues

### CR-02: Floor and metadata validation never inspect retained provenance manifests

**Files modified:** `tools/ci/verify-matrix-floor-evidence.R`, `tools/ci/test-matrix-floor-evidence.R`, new `tools/ci/normalize-matrix-provenance.py`, regenerated `MATRIX-FLOOR-EVIDENCE.md`, and checked provenance/payloads under `hosted-evidence/`.
**Commit:** `70555e6` (68 scoped files)
**Status:** fixed: requires human verification

The collection adjunct strictly parses original JSON (including duplicate-key rejection), matches each tuple to one job and artifact, verifies step outcomes, and checks extracted CSV and failed-source log SHA256 values against the manifest. It retains checked normalized CSV/DCF provenance and exact artifact payloads. The offline base-R gate binds the normalization to the original JSON using its digest, validates run/attempt and job/artifact identity, checks normalized-table and payload digests, compares accepted rows to retained artifact rows, and checks step/job outcomes. Missing files, malformed or changed manifests, contradictory outcomes, and digest mismatches are rejected.

Specific exclusion reasons are now derived from checked retained source logs instead of the unconditional `OBJECT undeclared` sentence.

New evidence is scoped to authentic candidate run `37273713572` (30 rows) and supported run `37274723569` (24 rows), both attempt 1: four normalized CSV/DCF files, 54 original artifact CSV payloads, and six small failed-source logs. Payloads/logs total 22,902 bytes. Existing original JSON and merged CSVs are unchanged; archives, native binaries and full check directories are not committed.

Modified sections were reread; R files and Python adjunct parse. At this commit, all **50 probes** passed: original 30 plus 20 provenance checks. These cover the exact malformed-manifest reproduction; changed JSON run, attempt, outcome, and artifact digest; changed normalized attempt, source/solver/job outcomes, missing SHA256 and reason, tested before and after resealing only its table hash; changed/missing artifact CSV; and changed failed-source log.

### CR-03: Fallback selection can skip eligible earlier releases and claim the oldest passing floor

**Files modified:** `tools/ci/verify-matrix-floor-evidence.R`, `tools/ci/test-matrix-floor-evidence.R`, new `tools/ci/collect-matrix-catalog.py`, regenerated `MATRIX-FLOOR-EVIDENCE.md`, and `hosted-evidence/cran-catalog/`.
**Commit:** `8bfb52c` (15 scoped files)
**Status:** fixed: requires human verification

The collector retains the [official CRAN archive index](https://cran.r-project.org/src/contrib/Archive/Matrix/), ordered release catalog, and actual DESCRIPTION metadata read from exact official source tarballs. The offline gate checks snapshot/catalog/description digests, compares the complete release sequence against the retained index, validates source URL/description identities, and derives R requirements from those descriptions.

Selection requires a complete eligible ascending prefix through the selected candidate for the exact recorded oldrel-1 R. Every earlier candidate must provide all five required pairings and fail the all-five-pass condition before a successor can be selected. Nonexistent versions, skipped eligible candidates, forged requirements, renumbered history/catalog entries, missing descriptions, and arbitrary source URLs are rejected.

The official snapshot was collected `2026-10-05T07:42:48Z` and includes eight actual releases: `1.6-5`, then `1.7-0` through `1.7-6`. Actual source requirements are R >= 3.5.0 for 1.6-5 and R >= 4.4/4.4.0 for successors. Eleven retained files total 79,721 bytes: archive HTML, eight DESCRIPTION files, releases CSV and snapshot DCF. Source archive SHA256 values and exact URLs are recorded; tarballs are not retained.

Modified sections were reread; both R files and the Python collector parse. All **71 probes** pass: original 30, 20 provenance probes, and 21 catalog/order/eligibility probes. The review's omitted-release reproduction now specifically fails with `Missing complete eligible CRAN candidate prefix`. A complete synthetic rejection-prefix positive probe remains only in memory. Other probes cover omitted earlier pairings, forged history requirements, ineligible successors, renumbered history, omitted/nonexistent/renumbered catalog entries, arbitrary source URLs and changed/missing source DESCRIPTION. Catalog mutations are checked both before and after resealing only the table hash. The old nonexistent 1.6-6 success fixture is replaced with actual 1.7-0.

## Portability Adjunct

**File:** new `.gitattributes`
**Commit:** `45d724c`

The orchestrator requested a bounded Windows checkout check. No existing attribute protection was present. Narrow `-text` rules now protect checksum-bound files under this phase's `hosted-evidence/` and its input `matrix-candidate-evidence.csv` from newline conversion.

Git attribute checks report `text: unset`. With `core.autocrlf=true`, filtered and unfiltered object hashes match. A disposable checkout-index export at `/tmp/gemodelr-reviewfix05-autocrlf-export/` preserves all **84 protected evidence files byte-for-byte**. All **71 probes and metadata verification pass** from that export too. No host Git setting was modified.

## Verification and Execution Context

All code edits, collection, syntax checks, and bounded gates ran sequentially in the main checkout; the additional checkout conversion gate ran in the disposable export. The authorized temporary `workflow.use_worktrees=false` opt-out created no worktree or branch. Exact original config bytes were saved to `/tmp/gemodelr-reviewfix05-iteration2-config-original.json`, restored after the two finding commits, and compared byte-for-byte. SHA256: `82f6914417d8d72357125cac248abd9f825077e3c7f25618f0d0cf5f049843a2`. Config was not committed. Unrelated edits, native outputs, libraries and earlier evidence were preserved.

Passed commands:

```sh
rtk proxy Rscript --vanilla tools/ci/test-matrix-floor-evidence.R --expect-final-metadata
rtk proxy Rscript --vanilla tools/ci/verify-matrix-floor-evidence.R --verify-final-metadata --evidence .planning/phases/05-portable-native-build-and-ci/MATRIX-FLOOR-EVIDENCE.md
rtk proxy Rscript --vanilla -e 'source("tools/ci/test-matrix-floor-evidence.R"); stopifnot(!"Matrix" %in% loadedNamespaces())' --expect-final-metadata
```

Fast metadata regeneration passes on authentic retained evidence and selects Matrix **1.6-5**. Matrix is never loaded. DESCRIPTION/README values are unchanged. No actionlint or full package build/check is needed for this evidence-only change.

## Remaining Collection Contract

The latest metadata run's artifacts remain for the orchestrator's Plan 05-07 continuation. Its manifest and extracted artifacts must be normalized before offline validation:

```sh
rtk proxy python3 tools/ci/normalize-matrix-provenance.py <retained-hosted-run.json> --artifacts-root <downloaded-artifacts-directory>
```

The Python adjunct is collection tooling, not an offline runtime R dependency. The gate trusts a checked normalized representation bound to original JSON and artifact payloads. It detects inconsistent retained files; coordinated replacement of all trusted provenance is outside its contract. A candidate beyond catalog endpoint 1.7-6 needs a fresh official snapshot. Current evidence format remains attempt 1; other attempts fail closed rather than being relabeled.

Per-finding human-verification labels are retained for logic fixes despite passing automated semantic probes. Final review and phase completion remain with the orchestrator.

---

_Fixed: 2026-10-05T07:48:49Z_
_Fixer: gsd-code-fixer_
_Iteration: 2_
