---
phase: 07-github-and-r-universe-release
reviewed: 2026-10-23T12:39:43Z
original_reviewed: 2026-10-23T12:25:28Z
re_review_commits: [25e065a, 8b8b242]
resolved_findings: 2
depth: standard
files_reviewed: 4
files_reviewed_list:
  - tools/release/prepare-release.cjs
  - tools/release/prepare-release.test.cjs
  - tools/ci/run-installed-release-smoke.R
  - docs/release/public-source.json
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 07: Local release tooling code review

## Summary

The initial review covered the four committed files listed above and identified two qualification defects. Independent re-review of fixes `25e065a` and `8b8b242`, their focused regressions, and necessary adjacent source-policy/handoff fields confirms both findings are resolved. There are no remaining findings in this scoped review. The already recorded Matrix and provenance limitations are outside these findings; Phase 06 acceptance remains unchanged. A clean code review does not establish package or publication readiness.

## Narrative Findings (AI reviewer)

### CR-07-01: Unchecked filtered build worktree — RESOLVED

**Classification:** BLOCKER

**Disposition:** Resolved by `25e065a`, independently re-reviewed on 2026-10-23. The issue and original evidence below are retained as history.

**File:** `tools/release/prepare-release.cjs:540-544,615-618`

**Issue:** `selectedClone()` performs a normal checkout under inherited global/system Git configuration. It disables hooks, but leaves attributes, smudge/process filters, `ident`, and line-ending conversion active. `qualifyReleasePacket()` then checks only `HEAD^{tree}` before passing the worktree to `R CMD build`. That ID describes the committed objects and remains unchanged when checkout filters rewrite the files. The final `verifyPublicSource()` checks the separate original projection, not `private/work/build-source`. An archive built from altered `R/` or native source can therefore be labelled `archive_source_commit=public_source_commit` and pass the new qualification checks without having been built from those frozen bytes.

**Concrete trigger:** A global `core.attributesFile` assigns `R/model.R filter=review`, and `filter.review.smudge` replaces a marker in that file. Public staging still copies and verifies the original blob bytes. The later build clone applies the filter while keeping the same `HEAD` and tree ID. The build runner observes changed bytes. Ordinary checkout conversion is documented by [Git's attributes/filter specification](https://git-scm.com/docs/gitattributes#_filter); global attributes are supported independently of a tracked `.gitattributes` file.

**Fix:** Export the selected public blob bytes directly into the build directory, or verify every actual build-worktree path, mode, and byte digest against the frozen public tree immediately before building. Isolate Git configuration/filters as defense in depth. Apply the same source-byte guarantee to the private guard checkout, which also uses `selectedClone()`. Add a focused fixture with an external global attribute/filter configuration and assert either exact original build bytes or rejection before the build command.

**Evidence boundary:** This follows directly from the checkout call and the tree-only check, with the checkout transformation behavior confirmed against the official Git documentation. An isolated temporary-fixture reproduction was attempted, but execution was blocked by the environment's `bwrap: No permissions to create a new namespace` failure. No real package build or install ran.

**Resolution verified:** `selectedClone()` now supplies empty global/system configuration and templates, restores each selected committed blob and executable mode after checkout, and calls `verifyCheckoutBytes()`. That verifier checks the entire actual file set, rejects linked/special entries, recomputes blob IDs from the worktree bytes, and checks executable modes where supported. Both guard and archive-build call sites repeat this verification immediately before consuming their source. The regression independently demonstrates that an ordinary checkout transforms the fixture under a temporary global smudge/EOL configuration, then asserts the guard and build commands receive the original bytes and mode. Tracked CRLF attributes are also exercised. This directly covers the original tree-ID-versus-worktree defect.

### CR-07-02: Literal standalone URL-step requirement — RESOLVED

**Classification:** BLOCKER

**Disposition:** Resolved by `8b8b242`, independently re-reviewed on 2026-10-23. The issue and original evidence below are retained as history.

**File:** `tools/release/prepare-release.cjs:636-640`; masking fixture at `tools/release/prepare-release.test.cjs:508`

**Issue:** Archive qualification requires a literal `* checking URL ... OK` or `* checking URLs ... OK` line as well as `Status: OK`. R 4.3.0's actual `tools:::.check_packages` does not emit a standalone URL-check step: URL checks run inside `CRAN incoming feasibility`. A genuine successful log on this supported R version can contain `* checking CRAN incoming feasibility ... OK` and `Status: OK`, with no matching URL line, so the new code records `archive_check=failed` and never attempts installation. The positive unit fixture inserts the nonexistent standalone line and therefore misses the failure.

**Evidence:** Read-only inspection of the installed R implementation via `deparse(body(getFromNamespace(".check_packages", "tools")))` lists its `checkingLog()` calls, including `CRAN incoming feasibility` and no URL step. Inspection of `.check_package_CRAN_incoming` shows `url_db_from_package_sources()` and `check_url_db()` inside that incoming check. This is independent of the currently unavailable Matrix prerequisite.

**Fix:** Parse the actual supported R check format and preserve a separate, explicit URL-check disposition using reliable raw evidence or a dedicated URL check. Do not infer a network URL pass when checking was disabled or unavailable. Add realistic successful and failing R check-log fixtures rather than manufacturing a standalone URL line; ensure a clean supported log can advance to installation while URL failures/unavailable evidence retain their intended failure status.

**Resolution verified:** The archive check now accepts zero exit status plus exactly one `Status: OK` line without requiring a fictional URL step. URL evidence comes from a separate R tools probe with explicit status/reason fields. The probe respects disabled checking, reports unavailable execution honestly, distinguishes no URLs from validated URLs, and uses `check_url_db()`'s returned invalid-URL rows. Publication readiness requires the corresponding explicit successful or no-URLs disposition. The realistic R 4.3 fixture reaches installation; warning logs do not; failed, unavailable, and disabled URL evidence keep readiness blocked. Read-only inspection of the installed `check_url_db()` confirms that its return value is the collected invalid-URL table, matching the new probe's interpretation.

## Implemented resolution notes — independently re-reviewed

- **CR-07-01 — `25e065a`:** Reproduced the transformed guard input with an external temporary `GIT_CONFIG_GLOBAL` attributes/smudge setup; a separate ordinary checkout confirms that setup really changes bytes. Clone setup now ignores inherited global/system Git settings and templates, replaces checkout conversions with the exact committed blobs/modes, and checks the complete actual file set, blob hashes and executable modes immediately before both guard and build commands. The regression also includes tracked CRLF attributes and checks actual consumed bytes independently of Git HEAD/tree IDs. User-global Git settings were never changed.
- **CR-07-02 — `8b8b242`:** Reproduced failure to reach installation using a realistic R 4.3 clean log without a synthetic URL step. A zero-exit archive check with one `Status: OK` now advances to installation. URL evidence is a separate dedicated R tools check with explicit passed/failed/unavailable/not-applicable/not-run disposition; incoming/remote URL checks disabled by configuration remain unavailable. Realistic clean/warning fixtures and failed/unavailable URL cases pass, including an actual disabled R URL-probe invocation with no network access. No network URL pass is inferred from incoming feasibility or a general clean check.
- Combined focused packet/scanner regression result after both fixes: **38/38 passed**, about 7.7 seconds, as recorded by the fixing executor and parent. The reviewer inspected those regressions and did not repeat the suite. Package build/check/install remains unperformed in the actual unsupported Matrix runtime.
- The old frozen candidate is retained unchanged. The refreshed packet binds source `e46ea70e737bc709880458ab1548244a2fd525cd`, public commit `ee8f5d26c9565db3407567e065633a0b0252da9a`, and review-content digest `e9a41d268ac88238bff47ded201fe3d0bbd391365fbc288e288e0d0a05b3b4dd`. These fields were read directly from `/tmp/GEModelR-release-packet-repaired-bYPwbD/private/manifest.json`; it retains actual evidence with qualification unavailable. The source policy now explicitly excludes this private review record. The handoff distinguishes the review-content digest from the raw manifest-file digest.

## Original review checks and limitations

- Packet refresh was required after these fixes: the policy explicitly includes `tools/release/prepare-release.cjs`, its test file, and the smoke runner. The refreshed packet must bind the committed fixed source and exclude this private review record. The executor has prepared a new packet and left the old packet unchanged; current identities are in the pending handoff, not a public approval.
- Inspected the complete release CLI, focused test file, standalone R runner, and public-source policy.
- Policy inspection found 197 includes, 465 exclusions, no duplicate paths, no missing included paths, and no blank exclusion reasons.
- Read the directly called scanner/qualification contracts where relevant.
- No source files were changed and no tests, package builds, installs, baseline runs, hosted actions, or publication were performed. Temporary fixture execution failed before it ran because the sandbox could not create a namespace.
- This report does not repeat or reopen accepted Phase 06 evidence gaps.

---

Reviewed by `gsd-code-reviewer`; standard depth, with targeted independent re-review of the two fixes. Both findings are resolved; no remaining scoped findings. Publication readiness and authorization remain separate.
