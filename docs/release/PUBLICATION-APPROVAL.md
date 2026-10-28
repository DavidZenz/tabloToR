# GEModelR publication decision — source published, channel verification in progress

Status: publication_in_progress
Package: GEModelR
Version: 0.1.0
Candidate-Status: public_tag_published
Intended-Tag: v0.1.0
Tag-Type: annotated_unsigned
Preparation-Status: complete
Publication-Readiness: hosted_followup_and_channel_verification_required
Packet-Specific-Maintainer-Decision: approved_in_conversation
Publication-Authorization: authorized_for_scoped_plan
Authorized-External-Actions: canonical-main-and-tag; github-draft-and-four-assets; public-pinned-registry; channel-verification
Standing-Instruction: keep local
Standing-Instruction-Superseded: true_for_exact_approved_scope_only
REL-02-Status: pending

## Exact reviewable candidate

| Identity | Value |
| --- | --- |
| Development source commit | `a70bf28c6186775eee0f3a35752ab59edc9286c6` |
| Development source tree | `685d2e41315feca7911976e4f0bba283a3793689` |
| Public root commit | `f8c2876cb49f8cfef6371ed445dd641ebc1f760f` |
| Public source tree | `ac0f4e73f298223c0b0d186ee9d8e622f516c4fa` |
| Archive SHA256 | `6a84b4f80b599a69946fa2dd42b72f106b1c05681b22629dc2c4b3ffa6d644fe` |
| Review content digest | `32ddcc5775eb803975b9cb9a3938a98284c123b1d25d9df86b994b1a7b8ad408` |
| Private manifest file SHA256 | `ddddc102e271fb02f3b4d01559a16059a8d5f48be8a5dfd2a720acdc6e5b88aa` |
| Public manifest file SHA256 | `09059db13a8ccc879c125a7471b66e13dad5ec2e7b1f30e2f5a8316562675556` |
| Source policy SHA256 | `c5c416f5a28326b9644a9a8b8f547856eea799060b8815a00e0b72750ba31704` |
| Release notes SHA256 | `7a7498688223ce803eb3a4b0989c433ee3b43f831a7da7ea19e18a52df04a8b5` |
| Registry draft SHA256 | `18fc79f3540ebdccc05b393eaf6c7d5b0cde663dc5b49cf3ba365e73d6ba70a8` |
| Smoke runner SHA256 | `f7241b877ff0112151fc22634930bc5f43ef9ed90d0c414599f7b2055d877d15` |
| Documentation inventory SHA256 | `ba30afa8a0a2300595274b3f8d5fbe1a3b8e311c12112b5a4ab2ccbd53241f82` |

The frozen packet is `/tmp/GEModelR-release-repair-j9oha8/release-packet`.
Its source archive is `public/GEModelR_0.1.0.tar.gz`. The review content digest
and serialized private-manifest file hash identify different bytes. Neither
supplies a maintainer signature or publication authority. The selected source
remains the committed revision above; the following private handoff commit is
excluded from the public policy and does not change these frozen identities.

## Actual completed verification

- Actual-kind supported runtime: R 4.3.0, GCC 8.3, isolated Matrix 1.6.5 against
  declared floor 1.6-5. Shared installed libraries were not changed.
- Canonical guard: eligible, ready=true, no reason codes, all 12 stages passed.
- Exact public source: one root commit, no inherited development parents,
  no development commit objects, no remote, complete selected-file policy.
- Exact archive: build and strict scan passed; full R CMD check exits0 with
  0 errors,0 warnings,3 notes. All 3,037 installed assertions pass,0 failures,
  0 test warnings,122 explicit context/platform skips.
- The three notes are only New submission, native installed size9.3MB
  (libs8.1MB), and unavailable external clock verification. The explicitly
  approved bounded GitHub-source policy accepts these exact dispositions;
  raw notes/counts/log hash/assessor hash remain retained. This is not CRAN approval.
- Actual URL validation, installation and installed numerical smoke passed.
  Smoke checks the finite expected solution within 1e-12 and verifies namespace
  ownership. Local source provenance is correctly labeled caller-attested.
- Separate clean-process source checks use the same final archive installation:
  public 4 groups / 28 tests / 117 assertions and development 4 groups / 30 tests / 167 assertions,
  all passing with zero skips and no namespace/native reloads.
- Final public-only license/dependency and Matrix build-contract checks passed.
- The same final archive builds pkgdown successfully. Complete generated site
  and complete staged artifact both pass strict scans (61 entries each, including 48 regular files).
- Strict `verify --for-publication` passes with the exact review digest above.
  Frozen manifest still records publication_authorized=false.
- All 44 Node packet/scanner/policy tests passed; the affected 26 packet tests
  were rerun after the readiness ordering correction and passed. Source identity,
  original numerical artifacts and preserved historical approval checks pass.

Final sidecar evidence lives under `/tmp/GEModelR-release-repair-j9oha8/logs`
and `validation/`; it is deliberately outside the immutable packet inventory.
The final documentation artifact is
`validation/final-site-build/pkgdown-site` and its exact 48-file inventory is
`validation/final-site-inventory.json`.

Production R/C++ implementations and accepted numerical baselines were unchanged.
The pre-existing local solver/benchmark edits remain outside this committed
candidate and are preserved. No GTAP workload or historical benchmark was rerun.
Earlier failed/provisional packets remain unchanged with their actual failures;
they were not edited into passing results. Prior candidate history and accepted
Phase 06 limitations remain in the existing private repair reports and Git history.

## Resolved decisions

GPL-3.0-or-later remains the existing human-selected license. Dependency audit,
347-row current provenance, and the confirmed Maros Ivanic attribution are
complete. The maintainer separately approved the exact canonical name reservation,
the labeled automated current serialization verification (original human approval
unchanged), and the bounded informational NOTE policy. These approvals repair
qualification rules and do not authorize publication.

## Approved scope and actual execution

The maintainer answered yes to this exact scope after all local qualification was complete:

1. Push only public root `f8c2876cb49f8cfef6371ed445dd641ebc1f760f` to `main` in
   `DavidZenz/GEModelR`, and create an annotated unsigned `v0.1.0` tag targeting
   that public commit. Require the destination still be empty; use no force push,
   development refs, private history, or repository visibility/default-branch changes.
2. Create a GitHub **draft** release at that tag with the exact source archive,
   frozen release notes, public manifest and standalone smoke from this packet.
   Allow normal workflows triggered by these pushes, retain their actual results,
   and perform the clean GitHub tag installation/smoke. Draft promotion is separate.
3. Create the public registry repository `DavidZenz/davidzenz.r-universe.dev`
   with the exact prepared `packages.json` entry at `main`, pinning the canonical
   package source to `v0.1.0`; verify the R-universe installation and RemoteSha
   against the public commit. A read-only probe currently returns 404 for that
   repository. Any required interactive account/app authorization remains explicit;
   no access to private repositories or new app permission grant is inferred.

## Actual publication results

The maintainer explicitly approved this plan in conversation on
2026-10-27T12:02:53Z. This supersedes the former keep-local restriction
only for the named actions. The immutable packet remains unchanged: its recorded
publication_authorized=false describes preparation; this separate decision record
supplies the actual later authority.

- Public main and tag are published at the exact approved commit. A new clone
  fetched from GitHub verifies the root tree and one-commit history, with no
  development parents or development commit objects.
- Annotated unsigned tag object: `14c160546b34490701fbcc81979ac1181c4ce42d`; peeled target:
  `f8c2876cb49f8cfef6371ed445dd641ebc1f760f`. No GPG key, force push or development ref was used.
- GitHub draft release ID `425404563`:
  https://github.com/DavidZenz/GEModelR/releases/tag/untagged-226e90e0204123894133. It remains a draft. All four approved assets were
  downloaded again and matched their frozen SHA256 bytes exactly.
- Public registry: https://github.com/DavidZenz/davidzenz.r-universe.dev/blob/main/packages.json; initial commit
  `58a4125ef436a1482b51f40e68b3822dc7a48480`. Its exact packages.json SHA256 is
  `18fc79f3540ebdccc05b393eaf6c7d5b0cde663dc5b49cf3ba365e73d6ba70a8` and its source is pinned to v0.1.0.
- GitHub channel installation and fresh-process numerical smoke passed in
  `/tmp/GEModelR-publication-s456sck4/github-library`, Matrix1.6.5. The actual
  remote tag/tree is verified separately; smoke honestly labels its local source
  basis caller-attested. No shared library was changed.
- The maintainer confirmed installation of the R-universe app for the two new
  public repositories. No agent performed an app permission grant. The initial
  R-universe API reports no package yet; first build/activation and R-universe
  installation verification remain pending. Its generated build repository was
  not yet visible at the first post-install check. This is not a package pass.
- Actual hosted results for the published source: documentation40500796318
  passed; native40500796258 failed only the Windows evidence scanner's shell;
  archive40500796263 failed with an unset OpenMP test profile, missing PDF font,
  and cross-version author metadata. These failures remain recorded, not waived.
- Development repair d9be316 fixed those causes. Its R4.6.1 archive run40504984250
  exposed six additional serialization failures (two predecessor re-save errors,
  four runtime leaf-shape assumptions). The corrected archive has no warnings;
  it still fails tests and is not reported as qualified.
- At2026-10-27T13:11:28Z the R-universe package API and generated build repository
  still return404. Its public onboarding run40508566340 (13:02) listed1207
  installed app accounts, with no DavidZenz, and reported no new installations.
  The maintainer's installation confirmation remains recorded. The agent asked
  for the saved installation's account/status in GitHub Settings, without
  requesting broader repository access or changing any app permission.

External evidence is retained under `/tmp/GEModelR-publication-s456sck4`,
including authorization.json, actual tag clone identity, remote refs, draft
metadata, re-downloaded asset checksums, registry bytes, channel logs and probes.
The frozen qualified packet is not edited to represent these later actions.

Pages publication/settings, draft promotion, branch protection/default settings,
private evidence upload and app grants remain outside agent authorization.
Bundled vignettes and prepared local site remain usable; planned hosted-site
metadata stays pending. No earlier technical approval is reinterpreted as broader
publication authority.


## Verified development repair; canonical publication not yet authorized

Focused development commits d9be316,7f01c1a,3150115 and d4e8ed0 are pushed to
the development repository only. They fix the owned CI profiles, Bash evidence scan,
standard PDF fonts, author comment rendering and timed check-log parsing.
The serialization correction recomputes fingerprints only when saving the exact
immutable predecessor source; strict read-time lineage/content checks remain.
Legacy leaf tests compare actual runtime metadata before/after serialization and
retain explicit numeric values/type/names. No numerical solver or native code changed.
The new fingerprint regression fails on the original GitHub installation and
passes on the repair, including altered-content rejection and unchanged receiver.
Original human approval/patch and the frozen original publication packet verify unchanged.

Concrete proposed append-only public repair (local only):

- Development source: d4e8ed0d16df483357a0f32ca441917fe7755ab7.
- Public parent: f8c2876cb49f8cfef6371ed445dd641ebc1f760f.
- Public commit: 9b257ccf9baf9a79b5b3748d2ee60bcb10e84508.
- Public tree: 1ad42e570b1cc5a55282d42b61bb1e5d234c9313.
- New local archiveSHA256:3e2ef62c79eae95b32deed16dacda9bf9328995620fdc822a45a2c9f728d8a39.

Both exact development/public archives pass full R4.3.0/Matrix1.6.5 checks:
3060assertions,0failures,0testwarnings,121contextskips,0checkerrors/0checkwarnings,
only the three approved informational notes. Separate source-tool groups pass
167development and117public assertions with zero skips. Forty-five affected Node
tests pass. Installed public-repair numerical smoke and live URL checks pass.
The original numerical canonical hashf6f2297a6ab257c9737a64354c82d7f1 remains exact.
At13:18:43UTC, d4e8ed0 documentation40508573786 passes. Native40508573943 has20
successful jobs, including all8Windows, with6R-setup/dependency jobs pending and
no failures. Dedicated archive40508573946 is still setting up R; it has not reached
package checking. Next CI poll no earlier than13:33:43UTC. The completed
representative R4.6.1/Matrix1.7.6 serial check passes3086assertions,0testfailures,
123skips. Its actual overall1error/1warning is missing PDF tooling, retained as
informational evidence rather than claimed as full release qualification.

No new canonical source bytes, tag, registry pin or draft assets are authorized
by the earlier one-snapshot publication decision. The proposed action is only a
normal fast-forward of GEModelR/main to the reviewed repair; a new maintainer
decision is required under AGENTS.md. The existing v0.1.0 tag and its R-universe
pin would retain their original source and known defects after a main-only repair;
a later corrected distribution needs its own reviewed release decision. Neither
an unchanged tag nor a future green main run is claimed to repair that old tag.


The maintainer subsequently checked GitHub Installed Apps and reported that
R-universe is absent. The earlier installation confirmation therefore does not
establish a saved app installation. Direct installation instructions were supplied:
https://github.com/apps/r-universe/installations/new, accountDavidZenz, only
GEModelR and davidzenz.r-universe.dev, final Install/Save. Awaiting completion;
no agent app permission grant or new external settings action was performed.


## Separate approved repair publication — executed

After reviewing the concrete repair and registry proposal, the maintainer explicitly
selected “Approve repaired main + R-universe” in conversation. This authorizes only
normal fast-forward updates of the two reviewed branches and channel verification;
original v0.1.0 tag/draft/assets, Pages and app/settings changes remain excluded.

At2026-10-27T13:25:32.643025+00:00 the approved public main advanced to
9b257ccf9baf9a79b5b3748d2ee60bcb10e84508 (tree1ad42e570b1cc5a55282d42b61bb1e5d234c9313),
sole parentf8c2876cb49f8cfef6371ed445dd641ebc1f760f. Registry main advanced to
fc01ef428bfd64cea2d63d11f775784ba28375b7, sole parent58a4125. Both remote refs
were read back and verified; original annotated v0.1.0 tag object/target are exact.
No development commit object exists in the public repair repository. Registry
packages.json now follows only the separate reviewed public main; exact SHA256
95fee4de1d0721e388227a8eb66454cec06daf1a024ef726da5b9d2c066101c1. Future approved
public main snapshots rebuild automatically. The original tag is not represented
as containing these repairs. No old draft asset was replaced or promoted.

The maintainer completed the previously absent R-universe app installation at
about13:22UTC using the direct app page and confirmed it. Initial post-install
service/build-repo probes remain404; next probe no earlier than13:37:34UTC.
Earlier absent-installation evidence is retained as historical, not current failure.
Actual corrected GitHub main installation/smoke and R-universe RemoteSha verification
are being recorded under /tmp/GEModelR-publication-s456sck4. No channel pass is
inferred from app installation or a branch push.


Corrected GitHub main verification is complete: fresh actual remote clone verifies
9b257cc/tree1ad42e57, exactly two public commits and no development commit objects.
Isolated installation in github-repaired-library and fresh-process numerical smoke
PASS using Matrix1.6.5. The smoke labels local source provenance caller-attested;
actual remote identity is independently retained. Shared R libraries are unchanged.


## Actual R-universe onboarding and first-build race

R-universe setup run40511398497 detects accountdavidzenz, installed13:21:59UTC,
and creates r-universe/davidzenz at13:25:00UTC. Installation is therefore verified.
The first sync starts13:25:20UTC and commits submodulef8c2876 at13:25:38UTC,
just before the approved registry push is verified13:25:40UTC. Build40511938593
therefore builds the original v0.1.0 source, not the repaired public main. This
old-source run is not counted as corrected-source verification. The package API
still404 at13:37:51UTC. Wait for the normal service sync to pick up registryfc01ef4.

A detached temporary verifier (PID2702; watch-runiverse.py under the external
evidence root) polls no more frequently than15minutes, first13:52:51UTC. It requires
actual API RemoteSha9b257cc, then performs source installation into the isolated
runiverse-library, asserts installed Version/RemoteSha, and runs the approved
fresh-process numerical smoke. Success/failure is written to runiverse-completion.json;
raw install/smoke and JSONL probe logs are retained. It runs for at most3hours and
records pending rather than success if the service never exposes the source. No
shared R library or release packet is changed; no channel pass is assumed.

Canonical current-source CI at13:33:59UTC: docs40511924192 passes; archive40511924193
has reached exact-source checking. Native40511924185 contains a Windows CRAN Matrix
source-download timeout before GEModelR compilation/tests. A targeted retry is
not yet allowed by GitHub because the workflow is still running (HTTP403); original
failure evidence is retained and no check rule/source is changed to mask it.


## Corrected public archive qualification passed; autonomous service verification

Canonical run40511924193 for exact public source9b257cc completes successfully.
Actual R4.6.1 full --as-cran check:3060passes,0failures/0testwarnings,121context
skips,0checkerrors,0checkwarnings,1NOTE only New submission. The approved assessor
passes, URLs pass, source-only public groups117assertions/zero skips, strict archive
scan190entries. Hosted archiveSHA8cf2feb321f8a918567c7e6da3ebc5ed9dbd6f1976b61b13699d812fd5dd0a12.
This is distinct from the locally qualified archiveSHA3e2ef62c...; actual build
artifacts remain tied to their own runtime/bytes. Canonical docs40511924192 passes.
Raw hosted evidence is in canonical-repaired-archive-evidence under the external
publication root, artifact12738067781/digestb6f4842378103ca856477b37192f4b5be1013cb70b91ed27b8404453f549c672.

At14:07:51UTC the R-universe API first exposes0.1.0 with RemoteShaf8c2876 and
RemoteRefv0.1.0. The verifier rejects this old source for corrected-source acceptance.
No new sync has run as of14:08; wait for the service's normal hourly registry sync
of approved public main9b257cc. No extra user installation/permission step remains.
The detached verifier continues15-minute probes, next14:22:51UTC, and will perform
isolated source install plus fresh-process smoke only when actual RemoteSha matches9b257cc.

Native CI40511924185 is still running. Last detailed result:22successful jobs,
1known Windows Matrix-download timeout before GEModelR compilation/tests,
3R-setup/dependency jobs pending (one representative informational job). A detached
observer PID6466 polls15minutes, next14:19:17UTC, and may retry at most2times only
the exact known Windows tuple after the workflow completes, with source9b257cc,
failed Matrix-install step, skipped core tests and literal download-timeout log all
required. Any unknown/numerical failure stops for review; no gate is waived. It
records native-ci-completion.json; R-universe records runiverse-completion.json.
Both processes have PPID1 and run independently of the editor session, with a3hour
monitor window and honest pending/failure output if external services remain blocked.
Original tag/draft/four assets, frozen packet, human approval and all16pre-existing
local work files remain unchanged. No Pages publication or draft promotion occurred.


## Approved native-CI download repair — pushed

On2026-10-28 the maintainer explicitly approved pushing the prepared snapshot
`ece78a9d086a0886183f3c8d7fcdd823539d236a` to `DavidZenz/GEModelR:main`.
The normal fast-forward completed over the existing SSH connection from parent
`9b257ccf9baf9a79b5b3748d2ee60bcb10e84508`; no tag, draft release, registry
configuration or Pages settings were changed.

| Identity | Value |
| --- | --- |
| Development commit | `5ce6aa7266bb72af29772dc9fa464af6d898b5c0` |
| Public snapshot commit | `ece78a9d086a0886183f3c8d7fcdd823539d236a` |
| Public snapshot tree | `e5120120f36dd11344689a0177ee24d97702c6ce` |
| Public parent | `9b257ccf9baf9a79b5b3748d2ee60bcb10e84508` |
| Built source archive SHA256 | `24dc056909581cc2d7db86dddd9b79dcc85940ee1775be60a2c994d93dbe7070` |

The snapshot changes only `.github/workflows/native-ci.yaml`,
`tools/ci/install-matrix-source.R`, and `tools/ci/test-matrix-source-download.R`.
The installer now gives the exact HTTPS source URL up to3 attempts with a300-second
timeout and short exponential waits for transient network failures. HTTP404 current
source fallback remains pinned to the same Matrix version; permanent failures still
fail. A deterministic retry regression runs once in the endpoint job.

Local validation: source build passed; strict archive scan passed (190 entries);
isolated installation and the approved numerical smoke passed with Matrix1.6.5;
the Matrix retry regression passed. R CMD check on local R4.3.0 did not pass in this
environment: 3 provenance-path test errors and PDF manual generation failed because
`pdflatex` is unavailable. The saved full R4.3 check for parent9b passed, and the
canonical hosted R4.6.1 check for parent9b passed with3060 assertions,0 test failures,
0 errors/0 warnings and one approved New submission NOTE. No hosted result is yet
claimed for ece78a9. A detached read-only observer will poll this commit's GitHub
workflow results no more frequently than every15minutes; the first check is scheduled
for2026-10-28T08:00:34Z. The observer retains raw status and failed-job identifiers
under `/tmp/GEModelR-publication-s456sck4`.

## Windows TLS retry follow-up — approved and pushed

The hosted Native portability run40651973892 for `ece78a9` failed in two Windows
Matrix source-install steps, before GEModelR compilation or core tests. The Windows
R oldrel-1 / Matrix1.6-5 job and R release / Matrix1.7-6 job each retried after a
transient download timeout, then stopped on `SSL connect error`. Package
documentation40651973849 and source archive qualification40651973856 passed.
Raw job logs are retained as `published-native-failure-122694217678.log` and
`published-native-failure-122694217731.log` under the external publication logs.

The local follow-up classifies `SSL connect error` and `TLS connect error` as
transient for the same exact URL; certificate-validation failures remain terminal.
The regression simulates a TLS connection failure followed by success and retains
the permanent certificate-error check.

| Identity | Value |
| --- | --- |
| Development commit | `cc00e526bfa80e6ae0a4ad88e4359a1a77a4b60c` |
| Public candidate | `fff2158aba752f00ed68c5571cc8a859879ddde8` |
| Public candidate tree | `eac9b562c8628f6647e3c58fba1c642652ca3ef1` |
| Public parent | `ece78a9d086a0886183f3c8d7fcdd823539d236a` |
| Built archive SHA256 | `7321695c4f9cd7127915c5231942552b0943c2621968d41af39423ca1caffa4b` |

The candidate regression, build, strict 190-entry archive scan, isolated installation
and numerical smoke all pass. After reviewing this exact candidate, the maintainer
explicitly approved its publication. Public main advanced by normal fast-forward from
`ece78a9` to `fff2158` on2026-10-28; no tag, draft release, registry configuration or
Pages settings were changed. All three hosted workflows passed on the exact
`fff2158` head in attempt1: Native portability run40658145478, Package documentation
run40658145646 and Source archive qualification run40658145583. Native portability
completed successfully at08:56:53Z, including its Windows matrix. The detached
read-only monitor recorded `verification=passed` at09:08:01Z.
