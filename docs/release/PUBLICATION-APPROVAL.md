# GEModelR publication decision — source published, channel verification in progress

Status: publication_in_progress
Package: GEModelR
Version: 0.1.0
Candidate-Status: public_tag_published
Intended-Tag: v0.1.0
Tag-Type: annotated_unsigned
Preparation-Status: complete
Publication-Readiness: ready
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
- Normal push-triggered hosted jobs are in progress for the public commit:
  native portability40500796258, archive qualification40500796263,
  documentation40500796318. Poll no more frequently than every15minutes.

External evidence is retained under `/tmp/GEModelR-publication-s456sck4`,
including authorization.json, actual tag clone identity, remote refs, draft
metadata, re-downloaded asset checksums, registry bytes, channel logs and probes.
The frozen qualified packet is not edited to represent these later actions.

Pages publication/settings, draft promotion, branch protection/default settings,
private evidence upload and app grants remain outside agent authorization.
Bundled vignettes and prepared local site remain usable; planned hosted-site
metadata stays pending. No earlier technical approval is reinterpreted as broader
publication authority.
