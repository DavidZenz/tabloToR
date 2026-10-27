# GEModelR publication decision — ready locally, authorization pending

Status: pending_local_only
Package: GEModelR
Version: 0.1.0
Candidate-Status: locally_qualified
Intended-Tag: v0.1.0
Tag-Type: annotated_unsigned
Preparation-Status: complete
Publication-Readiness: ready
Packet-Specific-Maintainer-Decision: not_received
Publication-Authorization: not_authorized
Authorized-External-Actions: none
Standing-Instruction: keep local
Standing-Instruction-Superseded: false
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

## Proposed external actions — none executed

A concrete publication approval may authorize the following exact scope:

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

The canonical source repository is currently public/empty/default main by
read-only GitHub metadata and a successful empty Git ref listing. No source/tag,
release, registry, Pages deployment, app permission or remote settings change was
performed. GitHub/R-universe channel installs and newly triggered hosted CI are
not_run until publication is authorized. Current prior hosted Matrix evidence
is retained honestly; no fresh hosted platform results are claimed.

The built site is ready for a later explicit Pages deployment decision. Pages
settings/branch publication, GitHub draft promotion, protection changes, app grants,
private evidence upload and force pushes are outside this proposal. Planned site
metadata remains pending; bundled vignettes work without public deployment.

The standing keep-local instruction remains in force. AGENTS.md requires explicit
maintainer authorization of the concrete publication action after local preparation.
This file records a reviewable proposal, not that authorization.
