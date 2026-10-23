# Phase 07: GitHub and R-universe Release — Research

**Researched:** 2026-10-23
**Domain:** R source releases, GitHub publication, R-universe registry, installed smoke verification
**Confidence:** MEDIUM — current official documentation and local source inspection; no remote account state, installation, build, test, or publication was exercised.

<user_constraints>
## User Constraints (from CONTEXT.md)

<!-- DATA_K7N2R8QA_START -->
### Locked decisions

- Phase 06 is complete by explicit maintainer acceptance. Honor `../06-documentation-and-release-qualification/06-ACCEPTANCE.md`; retain its known limitations without creating another Phase 06 gap, UAT, benchmark, or security-review cycle.
- Keep current work local. Planning and reversible local release preparation are authorized. A remote push, hosted dispatch, repository/settings change, tag publication, public release, Pages deployment, or R-universe publication requires authorization for the concrete prepared result.
- Complete the useful local preparation before requesting approval of an external action. Do not stop at the start of the phase solely because later publication is not yet authorized.
- GPL-3.0-or-later is selected. Preserve the approved package identity, public API, numerical behavior, solver tolerances, and canonical historical/provenance records.
- No R baseline rerun or proprietary GTAP data publication. Preserve existing benchmark evidence and accurately describe unavailable checks and known limitations.
- Preserve the existing unrelated dirty solver/native/benchmark files. Scope release preparation to a deliberate source revision; do not stage the entire working tree.

### Phase scope

Plan how to prepare, review, and eventually publish the first installable GEModelR release through its canonical Git repository and R-universe. Include installation and redistributable smoke verification, compatibility/platform notes, known limitations and migration instructions, and a practical support/issue/release cadence.

The accepted Phase 06 disposition does not grant public release authority or declare its unperformed checks successful. Existing release guards remain applicable at publication. Explain their current disposition in the local handoff; do not reopen the completed phase automatically.

### Implementation discretion

Reuse existing release tooling, workflows, documentation, identity records, and artifact scans. Research current official integration documentation where needed. Keep the plan bounded and executable; use one concrete approval checkpoint for external publication after local preparation is reviewable. Do not create repetitive evidence-only plans for the same accepted limitations.
<!-- DATA_K7N2R8QA_END -->

Source: [VERIFIED: 07-CONTEXT.md:11-28], copied verbatim. No new design decision or publication permission is inferred from this research.
</user_constraints>

## Summary

**Recommendation:** Deliver a local, reproducible release packet first: explicit source revision and file selection, exact artifact fingerprints, draft release notes and installation instructions, a tag-pinned R-universe registry draft, redistributable smoke runner, and a handoff listing the exact later external actions. Place one concrete publication decision after that packet is reviewable. This ordering follows the locked local-only scope. [VERIFIED: 07-CONTEXT.md:13-28]

The package and existing CI provide most of the qualification machinery. Do not build another release framework or make the already accepted Phase 06 evidence gaps a new early planning blocker. Preserve their actual status in the packet. Public distribution still needs its own actual readiness and authorization; a local packet is a completed preparation deliverable even when publication is pending. [VERIFIED: ../06-documentation-and-release-qualification/06-ACCEPTANCE.md:18-33]

## Architectural Responsibility Map

| Capability | Owner | Boundary and recommendation |
|---|---|---|
| Candidate source and artifacts | Local Git revision and package build | Select explicit committed bytes; never collect arbitrary dirty work. This is the locked repository-safety rule. [VERIFIED: 07-CONTEXT.md:18] |
| Archive qualification | Existing R/Node workflow | Reuse one build, archive digest, content scan, exact-archive check, and retained raw statuses. [VERIFIED: .github/workflows/release-qualification.yaml:62-187] |
| Release decision | Maintainer, outside numerical code | The canonical record says `Release-Authority: David Zenz`; technical readiness does not authorize external actions. [VERIFIED: GOVERNANCE.md:5-25] |
| Public release and registry | GitHub and R-universe services | Keep as later explicitly authorized external operations. [VERIFIED: 07-CONTEXT.md:14-15] |
| Installation smoke | Fresh installed R process | Exercise the supported public facade and a generated three-region model. [VERIFIED: vignettes/first-simulation.Rmd:37-75] |

## Project Constraints (from AGENTS.md)

The actionable repository guidance requires: run shell commands through `rtk`; preserve two-space, base-R `=` assignment and existing camelCase style; keep edits focused; keep private or oversized model inputs external; use small deterministic regression fixtures; do not commit session files, generated archives/check trees, credentials, private inputs, or generated solver results; explain validation in focused present-tense commits. [VERIFIED: AGENTS.md, sections Coding Style, Testing Guidelines, Commit Guidelines, Data and Generated Files; /home/zenz/.codex/RTK.md, Rule]

Its historical statement that tests and vignettes are absent is stale: the concrete test and vignette source files read in this session establish the current implementation. The parent task explicitly prohibits running tests/builds/installations during this research. [VERIFIED: tests/testthat/test-documented-workflow.R:95-112; vignettes/first-simulation.Rmd:1-76; parent research task]

## Phase Requirements

<phase_requirements>
| ID | Verbatim requirement | Research support |
|---|---|---|
| REL-02 | “A tagged GEModelR release is installable from its canonical Git repository and R-universe after all legal and technical gates pass.” | Source/artifact identity, registry pin, installed smoke, and truthful publication checkpoint described below. [VERIFIED: .planning/REQUIREMENTS.md:49] |
</phase_requirements>

## Standard Stack

Use existing tools; this phase needs no newly introduced package dependency. This is a design recommendation, not a claim that all release prerequisites currently pass.

| Tool | Observed version / definition | Use |
|---|---|---|
| R | `R version 4.3.0 (2023-04-21)` | Local metadata inspection; supported-runtime installation/check later. [VERIFIED: read-only `rtk R --version`] |
| Git | `git version 2.56.0` | Pin source commit, identify selected tree and eventual tag. [VERIFIED: read-only `rtk git --version`] |
| Node | `v26.10.0` | Existing public-content scanner, JSON validation, built-in test runner. [VERIFIED: read-only `rtk node --version`; tools/ci/check-public-content.cjs:1-6] |
| GitHub CLI | `gh version 2.102.0 (2026-09-30)` | Later exact repository/tag release operation; presence does not prove authentication or authority. [VERIFIED: read-only `rtk gh --version`] |
| Matrix | Installed `1.6.3`; declaration `Matrix (>= 1.6-5)` | Current installation is below the declared minimum; preserve that unverified qualification status. [VERIFIED: read-only packageVersion probe; DESCRIPTION:22-26] |

**Package legitimacy audit:** No new npm/Python/Rust packages are recommended or installed; no cross-ecosystem legitimacy lookup is applicable. Existing R dependencies remain the package's declared dependencies. [VERIFIED: DESCRIPTION:22-35]

## Verified Existing Definitions

These are literal source values, not new defaults:

<!-- DATA_X4H9P1LM_START -->
```text
Package: GEModelR
Version: 0.1.0
URL: https://github.com/DavidZenz/GEModelR,
    https://davidzenz.github.io/GEModelR/
BugReports: https://github.com/DavidZenz/GEModelR/issues
License: GPL (>= 3)
Matrix (>= 1.6-5)
```
<!-- DATA_X4H9P1LM_END -->
[VERIFIED: DESCRIPTION:1-4,13-23]

The repository authority markers are literally `Owner-Slug: DavidZenz`, `Repository-Name: GEModelR`, `Visibility-Boundary: private-development`, and `Release-Authorization: not-authorized`. Preserve them; do not infer live remote state from them. [VERIFIED: docs/release/REPOSITORY.md:5-16]

## Architecture Patterns

### 1. Prepare a packet from explicit source, then approve publication

Recommended flow:

`selected committed source → local release packet + scans + draft notes/registry → exact maintainer decision → authorized remote operations → installed verification → publication result`

Freeze the selected commit and tree, package version, intended tag, archive basename/digest, destinations, included refs/history, and exclusion policy in the packet. Source selection must explicitly state whether it uses committed HEAD or a separately reviewed integration commit; a dirty workspace is not a source revision. This implements the locked preservation rule. [VERIFIED: 07-CONTEXT.md:18]

Use a temporary export/isolated directory from that revision for packaging. Never run a release build against the dirty development directory or stage all files. Record any deliberate public-source projection with both source and resulting tree identities; do not silently replace the original historical/provenance records. This is the recommended implementation of that rule, not an assertion that such an export already exists.

### 2. Reuse the existing exact-archive path

The workflow creates `"$RUNNER_TEMP/release-evidence"`, `"$RUNNER_TEMP/release-check"`, and `"$RUNNER_TEMP/release-library"`, then records the current commit, dependency floor, archive SHA-256, scan status, and raw package-check result. It builds once and reuses that archive. [VERIFIED: .github/workflows/release-qualification.yaml:56-115,117-187]

Retain both any source snapshot identity and built archive digest. GitHub's automatically generated source download is a Git snapshot whose compression can vary; it is not a substitute for the exact checked R package tarball. Attach the retained R-built archive as a release asset when publication is authorized. [CITED: https://docs.github.com/en/enterprise-cloud%40latest/repositories/working-with-files/using-files/downloading-source-code-archives]

### 3. Draft a separate R-universe registry pinned to the approved tag

Official setup uses a lowercase account registry repository named `<username>.r-universe.dev`, with a JSON array containing `package` and `url`. An optional `branch` accepts a branch or tag; otherwise builds follow the repository default branch. The Git URL must be public and the R-universe GitHub app must be installed. Draft this locally and choose an explicit release tag for the initial channel. Creation, app authorization, push, and deployment remain publication actions. [CITED: https://docs.r-universe.dev/publish/set-up.html]

The lowercase domain derived from the approved owner is a proposed destination, not a verified live channel. Do not silently use the moving default branch or the automatically changing latest-release selector. This is a release reproducibility recommendation.

### 4. Carry accurate release notes and a practical support policy

Keep the current development version until the release task deliberately establishes a release boundary. The adopted policy says “Version `0.1.0` is a development version and is not a public release.” Do not choose a version bump or claim 1.0 stability merely from the milestone name. [VERIFIED: docs/release/VERSION-LIFECYCLE.md:3-5]

Draft compatibility/migration/backend/platform notes from current documentation, with the accepted unverified checks and component-versus-end-to-end benchmark distinction visible. Link ordinary issues to the approved issue tracker and keep private security reports on the approved `Security-Route: mailto:zenz@wiiw.ac.at`. Propose a lightweight initial triage/release cadence for maintainer review; it is a new policy proposal, not an established service-level promise. [VERIFIED: DESCRIPTION:15; GOVERNANCE.md:5-8,64-75; 07-CONTEXT.md:22-24]

## Don't Hand-Roll

| Need | Use | Reason |
|---|---|---|
| Package tarball/check | Existing R commands and qualification workflow | Final R checks should target the R-built tar archive; building and checking are separate operations. [CITED: https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html] |
| Artifact privacy scan | Existing scanner | Supported modes are exactly `--archive`, `--site`, `--artifact-dir`; no repository-history mode exists in its dispatch. [VERIFIED: tools/ci/check-public-content.cjs:564-578] |
| GitHub release upload | GitHub CLI | Use the exact repository, already published tag, retained asset and notes file; `--verify-tag` prevents accidental default-branch tag creation. A hosted draft is still an external write. [CITED: https://cli.github.com/manual/gh_release_create] |
| R repository installation | Standard `install.packages()` | R-universe exposes CRAN-like URLs; list the universe and a CRAN dependency fallback. [CITED: https://docs.r-universe.dev/install/dependencies.html] |

## Common Pitfalls

1. **Reopening the accepted phase.** The acceptance literally says `publication_authorized: false` and forbids repeating the same gap cycle. Record its disposition once; reserve actual release guards for the later publication boundary. [VERIFIED: ../06-documentation-and-release-qualification/06-ACCEPTANCE.md:9,20-33]
2. **Publishing a dirty checkout or all private history.** Package ignore rules are not a Git publication filter: the package excludes `^\\.planning$`, `^docs/provenance$`, and `^docs/release$`. Public refs and their reachable history need an explicit content disposition, independently of the package tarball. Do not assume that excluding files from the R archive makes a repository or mirror safe. [VERIFIED: .Rbuildignore:12,26-27; docs/release/REPOSITORY.md:43-78]
3. **Using the archive scanner as an unmodified public-repository scanner.** Its repository-only segment list includes `".git"`, `".github"`, and `".planning"`; scan the package/assets/site with existing modes and separately review the intended public Git tree/history. Never weaken existing artifact policy to admit a repository. [VERIFIED: tools/ci/check-public-content.cjs:12-29]
4. **Changing the target branch incidentally.** Existing qualification and pkgdown workflows say `branches: [master]`, while governance targets protected `main`. A later branch/settings migration must be explicit and part of the reviewed action list. Planning must not switch the current branch. [VERIFIED: .github/workflows/release-qualification.yaml:3-10; .github/workflows/pkgdown.yaml:3-9; GOVERNANCE.md:27-31]
5. **Treating every rebuild as byte-identical.** Compare exact retained GitHub release assets by digest. R-universe adds build provenance fields including `RemoteUrl`, `RemoteRef`, and `RemoteSha`; verify the deployed source identity and installed behavior rather than claiming its rebuilt tarball has the original asset's bytes. [CITED: https://docs.r-universe.dev/browse/api.html]
6. **Using source-mode loading to prove installation.** Existing installed tests load the selected library, verify the namespace path, and run from an unrelated directory. Keep that fresh-process boundary for release smoke. [VERIFIED: tools/ci/run-installed-core-tests.R:20-37,81-93]

## Code Examples

### Existing scan commands to reuse

The existing commands are `node tools/ci/check-public-content.cjs --archive "$GEModelR_SOURCE_ARCHIVE"` and `node tools/ci/check-public-content.cjs --artifact-dir "$GEModelR_RELEASE_EVIDENCE_DIR"`. Their archive and evidence destinations are assigned by the workflow, rather than guessed from the development directory. Prefix shell invocations with `rtk` under the repository rule. [VERIFIED: .github/workflows/release-qualification.yaml:113,122,239-240; /home/zenz/.codex/RTK.md, Rule]

### Redistributable installed smoke contract

Reuse the fixture's `makeFirstSimulationFixture()` and public vignette sequence: `GEModelR::GEModel$new()`, `setClosure("tax")`, `engine = "sparse"`, `backend = "Matrix"`, `reduction = "off"`, shock `setNames(4, 'tax["south"]')`. [VERIFIED: vignettes/helpers.R:1-38; vignettes/first-simulation.Rmd:37-62]

An existing regression asserts `expect_equal(unname(preferred$solution), c(0, 6, 0), tolerance = 1e-12)`. Use this independent numerical expectation in the release smoke rather than printing the solution and calling the command successful. Make the smoke self-contained in its distribution artifact; do not assume a source-tree helper path exists in an installed package. [VERIFIED: tests/testthat/test-documented-workflow.R:104-112]

## Environment Availability

The read-only probes above found the local R, Matrix, Git, Node, and GitHub CLI versions. The current Matrix does not satisfy the declared minimum. Context7 tools were not exposed and `ctx7` was absent; primary official web documentation supplied the integration research. No authentication probe or live canonical-repository/R-universe existence check ran. [VERIFIED: research tool/probe outputs; DESCRIPTION:23]

Recommended fallback: finish local source selection, drafts, static manifest/scanner validation, and the smoke-runner implementation here; report installation checks as unavailable until a supported isolated runtime is available. Do not upgrade the user's library during preparation. A future authenticated publication and hosted verification is a separate stage, not a reason to prevent local work.

## Validation Architecture

**Observed existing tools:** Node's test runner has scanner regression fixtures, and the installed R core runner uses `testthat::test_package()`. This research inspected them but ran neither. [VERIFIED: tools/ci/check-public-content.test.cjs:75-87; tools/ci/run-installed-core-tests.R:90-93]

| Phase behavior | Recommended check | Execution boundary |
|---|---|---|
| Local packet selects exact source and excludes dirty inputs | Focused tests for commit/tree identity, artifact digest mismatch, unsafe output destinations, and absence of existing dirty/untracked canaries if a packet builder is added | Tests required only for new executable release logic; no package suite for prose edits |
| Existing artifact scan remains intact | `rtk node --test tools/ci/check-public-content.test.cjs` if scanner integration changes; scan every exact staged archive/site/evidence artifact | Local preparation; preserve original result/status |
| Registry draft names the intended package/source/tag | JSON parse, exact package identity versus selected DESCRIPTION, explicit tag matching the packet, no credentials, no implicit remote writes | Local static validation; does not claim a deployed universe |
| REL-02 Git installation | Install the approved retained archive/tag in a clean supported library, then run the generated three-region smoke from an unrelated directory | Local supported runtime when available; otherwise record unavailable, never fabricate pass |
| REL-02 R-universe installation | After authorized publication, verify source SHA/registry ref and install into another clean library; run the same numerical smoke | Authorized external distribution stage |
| Release exactness | Download retained asset, verify digest and tag-to-commit identity; confirm version and limitations match notes | After authorization; keep network/publication failures explicit |
| Support documentation | Check links and consistency of maintainer/contact, issue/security routes, supported backend statements, and version policy | Local review; new cadence remains a proposed policy until reviewed |

**Sampling:** Run focused release-tool tests after executable changes, artifact scans on the exact packet, and installed smoke once per distinct installation channel. Run the full package check on the final built archive in a supported environment when qualifying a release; do not repeat the same unavailable Phase 06 checks as a plan loop. [CITED: R Extensions manual above; VERIFIED: 07-CONTEXT.md:13-18,24]

**Wave 0:** Proposed release packet/manifest validation and a self-contained installed smoke entry point need implementation; their paths should be selected by the planner. Existing source fixture and scanner are reusable. No new test framework is needed. This is an implementation recommendation; no new production artifact is claimed to exist.

## Security Domain

Use a bounded threat model for publication authority, artifact integrity, and disclosure. The package is not a web authentication/session service; do not add unrelated application controls. The existing workflow uses `permissions: contents: read` and `persist-credentials: false`, and the content scanner detects credential/private-input patterns. [VERIFIED: .github/workflows/release-qualification.yaml:9-20; tools/ci/check-public-content.cjs:60-105]

| Applicable boundary | Mitigation to plan |
|---|---|
| External mutation without authority | No mutation in local preparation; exact source/tag/assets/destinations and each requested repository/registry action listed at the final decision. This implements the locked approval boundary. [VERIFIED: 07-CONTEXT.md:14-15,28] |
| Artifact or tag substitution | Explicit source/tree SHA and asset digest; verify existing tag and downloaded asset at publication. [CITED: GitHub CLI manual above] |
| Sensitive material in package, upload, or public refs | Existing artifact scans plus deliberate public-tree/history inventory; no unrestricted mirror. [VERIFIED: tools/ci/check-public-content.cjs:12-29,60-105; docs/release/REPOSITORY.md:43-78] |
| Unnecessary credential exposure | Prepare commands/config without tokens or secret values; app/account administration only at the authorized external stage. [VERIFIED: docs/release/REPOSITORY.md:51-62; CITED: R-universe setup above] |

## Open Questions and Dispositions

- **Live canonical repository, registry/app state, credentials:** not inspected. Resolve read-only status when preparing a concrete external-action handoff; do not assume absence, create a repository automatically, or block local drafts. [VERIFIED: scope of this research]
- **Final public source/ref/history selection and release tag/version:** not decided by the current files. Put explicit values in the local packet for the final decision. The current metadata is `Version: 0.1.0`; the policy still calls it development. [VERIFIED: DESCRIPTION:4; docs/release/VERSION-LIFECYCLE.md:3-5]
- **Tag signature:** Phase 07 says “signed/tagged release”; REL-02 requires a tagged release. Do not install a signing tool or invent a key requirement. Clarify the proposed tag type in the final packet, and never label an unsigned tag cryptographically signed. [VERIFIED: .planning/ROADMAP.md:340; .planning/REQUIREMENTS.md:49]
- **Known Phase 06 limitations:** already accepted for phase closure. Retain them and existing publication guards; no new Phase 06 remediation plan is recommended here. [VERIFIED: ../06-documentation-and-release-qualification/06-ACCEPTANCE.md:20-33]

## Assumptions Log

No unverified external state, package installation, policy cadence, version bump, or public destination is treated as an approved fact. Proposed implementation choices above are recommendations for the planner and final review, not new maintainer decisions.

## Sources and Research Method

- Opened the cited repository sources in this session; line references and verbatim values above identify the evidence.
- Official primary documentation: [R-universe setup](https://docs.r-universe.dev/publish/set-up.html), [installation repositories](https://docs.r-universe.dev/install/dependencies.html), [API/build provenance](https://docs.r-universe.dev/browse/api.html), [GitHub CLI release create](https://cli.github.com/manual/gh_release_create), [GitHub source archives](https://docs.github.com/en/enterprise-cloud%40latest/repositories/working-with-files/using-files/downloading-source-code-archives), and [Writing R Extensions](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html).
- The research-plan seam selected Context7; unavailable tools/CLI required the official web fallback. The confidence seam returned `MEDIUM` for cross-checked `websearch --verified`; that is the overall integration confidence used here. No new package legitimacy gate was needed. Research cache writes were omitted to honor the parent instruction limiting repository writes to this file. [VERIFIED: research-plan, availability, and classify-confidence command outputs]
- No tests, builds, installs, baseline reruns, pushes, hosted dispatches, or publication occurred. [VERIFIED: research execution record]

**Validity:** Recheck service documentation and live destinations immediately before an authorized publication; source facts apply to the inspected checkout and must be rebound to the eventual selected release revision.
