---
phase: 07-github-and-r-universe-release
reviewed: 2026-10-23T12:25:28Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - tools/release/prepare-release.cjs
  - tools/release/prepare-release.test.cjs
  - tools/ci/run-installed-release-smoke.R
  - docs/release/public-source.json
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: fixes_pending_review
---

# Phase 07: Local release tooling code review

## Summary

The review covers the four committed files listed above. It finds two defects in the new qualification path: the archive can be built from a checkout whose bytes differ from the recorded public commit, and a standard successful R check log is rejected because it lacks a synthetic URL-check line. The already recorded Matrix and provenance limitations are outside these findings; Phase 06 acceptance remains unchanged.

## Narrative Findings (AI reviewer)

### CR-07-01: Qualification verifies the Git tree ID, but builds an unchecked filtered worktree

**Classification:** BLOCKER

**File:** `tools/release/prepare-release.cjs:540-544,615-618`

**Issue:** `selectedClone()` performs a normal checkout under inherited global/system Git configuration. It disables hooks, but leaves attributes, smudge/process filters, `ident`, and line-ending conversion active. `qualifyReleasePacket()` then checks only `HEAD^{tree}` before passing the worktree to `R CMD build`. That ID describes the committed objects and remains unchanged when checkout filters rewrite the files. The final `verifyPublicSource()` checks the separate original projection, not `private/work/build-source`. An archive built from altered `R/` or native source can therefore be labelled `archive_source_commit=public_source_commit` and pass the new qualification checks without having been built from those frozen bytes.

**Concrete trigger:** A global `core.attributesFile` assigns `R/model.R filter=review`, and `filter.review.smudge` replaces a marker in that file. Public staging still copies and verifies the original blob bytes. The later build clone applies the filter while keeping the same `HEAD` and tree ID. The build runner observes changed bytes. Ordinary checkout conversion is documented by [Git's attributes/filter specification](https://git-scm.com/docs/gitattributes#_filter); global attributes are supported independently of a tracked `.gitattributes` file.

**Fix:** Export the selected public blob bytes directly into the build directory, or verify every actual build-worktree path, mode, and byte digest against the frozen public tree immediately before building. Isolate Git configuration/filters as defense in depth. Apply the same source-byte guarantee to the private guard checkout, which also uses `selectedClone()`. Add a focused fixture with an external global attribute/filter configuration and assert either exact original build bytes or rejection before the build command.

**Evidence boundary:** This follows directly from the checkout call and the tree-only check, with the checkout transformation behavior confirmed against the official Git documentation. An isolated temporary-fixture reproduction was attempted, but execution was blocked by the environment's `bwrap: No permissions to create a new namespace` failure. No real package build or install ran.

### CR-07-02: A literal standalone URL step rejects clean checks on supported R versions

**Classification:** BLOCKER

**File:** `tools/release/prepare-release.cjs:636-640`; masking fixture at `tools/release/prepare-release.test.cjs:508`

**Issue:** Archive qualification requires a literal `* checking URL ... OK` or `* checking URLs ... OK` line as well as `Status: OK`. R 4.3.0's actual `tools:::.check_packages` does not emit a standalone URL-check step: URL checks run inside `CRAN incoming feasibility`. A genuine successful log on this supported R version can contain `* checking CRAN incoming feasibility ... OK` and `Status: OK`, with no matching URL line, so the new code records `archive_check=failed` and never attempts installation. The positive unit fixture inserts the nonexistent standalone line and therefore misses the failure.

**Evidence:** Read-only inspection of the installed R implementation via `deparse(body(getFromNamespace(".check_packages", "tools")))` lists its `checkingLog()` calls, including `CRAN incoming feasibility` and no URL step. Inspection of `.check_package_CRAN_incoming` shows `url_db_from_package_sources()` and `check_url_db()` inside that incoming check. This is independent of the currently unavailable Matrix prerequisite.

**Fix:** Parse the actual supported R check format and preserve a separate, explicit URL-check disposition using reliable raw evidence or a dedicated URL check. Do not infer a network URL pass when checking was disabled or unavailable. Add realistic successful and failing R check-log fixtures rather than manufacturing a standalone URL line; ensure a clean supported log can advance to installation while URL failures/unavailable evidence retain their intended failure status.

## Checks and limitations

## Implemented resolution notes — pending independent re-review

- **CR-07-01 — `25e065a`:** Reproduced the transformed guard input with an external temporary `GIT_CONFIG_GLOBAL` attributes/smudge setup; a separate ordinary checkout confirms that setup really changes bytes. Clone setup now ignores inherited global/system Git settings and templates, replaces checkout conversions with the exact committed blobs/modes, and checks the complete actual file set, blob hashes and executable modes immediately before both guard and build commands. The regression also includes tracked CRLF attributes and checks actual consumed bytes independently of Git HEAD/tree IDs. User-global Git settings were never changed.
- **CR-07-02 — `8b8b242`:** Reproduced failure to reach installation using a realistic R 4.3 clean log without a synthetic URL step. A zero-exit archive check with one `Status: OK` now advances to installation. URL evidence is a separate dedicated R tools check with explicit passed/failed/unavailable/not-applicable/not-run disposition; incoming/remote URL checks disabled by configuration remain unavailable. Realistic clean/warning fixtures and failed/unavailable URL cases pass, including an actual disabled R URL-probe invocation with no network access. No network URL pass is inferred from incoming feasibility or a general clean check.
- Combined focused packet/scanner regression result after both fixes: **38/38 passed**, about 7.7 seconds. Package build/check/install remains unperformed in the actual unsupported Matrix runtime. The fixes above are implementation results awaiting the independent reviewer; this section does not self-certify a clean review.
- The old frozen candidate is retained unchanged. A new selected revision and packet will bind these committed fixes, with this private review document explicitly excluded by the source policy. Review-content and raw manifest-file digests will be labelled separately in the refreshed handoff.

- Packet refresh is required after these fixes: the current policy explicitly includes `tools/release/prepare-release.cjs`, its test file, and the smoke runner. A fixed committed source therefore produces a new public tree/commit and review digest. Prepare a new packet rather than modifying the existing frozen packet. Give this new private `07-REVIEW.md` an explicit exclusion in the source policy before selecting the next source revision.
- Inspected the complete release CLI, focused test file, standalone R runner, and public-source policy.
- Policy inspection found 197 includes, 465 exclusions, no duplicate paths, no missing included paths, and no blank exclusion reasons.
- Read the directly called scanner/qualification contracts where relevant.
- No source files were changed and no tests, package builds, installs, baseline runs, hosted actions, or publication were performed. Temporary fixture execution failed before it ran because the sandbox could not create a namespace.
- This report does not repeat or reopen accepted Phase 06 evidence gaps.

---

Reviewed by `gsd-code-reviewer`; standard depth. Findings remain open pending a focused fix and re-review.
