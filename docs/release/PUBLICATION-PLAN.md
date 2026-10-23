# GEModelR first-release publication proposal

Status: draft_not_authorized
Package: GEModelR
Version: 0.1.0
Candidate-Status: development
Intended-Tag: v0.1.0
Tag-Type: annotated_unsigned
Canonical-Repository: DavidZenz/GEModelR
Canonical-URL: https://github.com/DavidZenz/GEModelR
Proposed-Public-Branch: main
Proposed-Registry-Repository: DavidZenz/davidzenz.r-universe.dev
Proposed-Universe: https://davidzenz.r-universe.dev
Publication-Authorization: pending
Publication-Readiness: unqualified
Development-Source-Commit: not_selected
Development-Source-Tree: not_selected
Public-Source-Commit: not_created
Public-Source-Tree: not_created
Archive-Source-Commit: not_built
Archive-Basename: not_built
Archive-SHA256: not_built
Public-Policy-SHA256: not_frozen
Registry-SHA256: not_frozen
Release-Notes-SHA256: not_frozen
Packet-Manifest-SHA256: not_prepared

This is a local proposal, not a rights decision, qualification result, or external-action authorization. Phase 06 was accepted for development workflow completion; its existing limitations are retained without reopening that phase. The final decision in Plan 07-04 follows useful local preparation and concerns one exact packet and action list. Public release guards retain their meanings at that boundary.

## Source and history proposal

Select an explicit committed development revision after the local preparation changes are committed. Record its full commit and tree IDs; do not capture unrelated dirty or untracked files. `public-source.json` is the explicit per-path disposition for a recorded tracked-file inventory. Included paths are enumerated; every exclusion has a reason; no new or unclassified path is public by default. The candidate-preparation task must refresh and validate the policy against its exact selected revision, including new planning/release records, then freeze the policy digest.

Prepare a separate local public-source Git repository with one reviewed root commit containing only the selected public tree. The original development repository, refs, remotes, index, dirty files, private history, provenance records, and rejected provenance proposal remain unchanged. This proposes a new public history; it is not a detach, mirror, history rewrite, or migration of existing private metadata.

Record both development and projected public commit/tree identities. Build the package solely from the frozen projected public commit. Retain one archive from that source for scanning, checking, installation, and any later upload; `archive_source_commit` must equal `public_source_commit`. Use the original private source only for canonical provenance and release-guard evaluation. Rebuilt R-universe archives are identified by their recorded source SHA/ref and installed behavior; do not claim byte equality with the retained R-built release asset.

The explicit source policy differs from `.Rbuildignore`, which governs the R archive only. Keep private planning and rights/release evidence, generated artifacts, proprietary inputs, raw benchmark data/solutions, and development scratch files outside public Git and the public packet. Preserve package code, tests, help, installed compatibility/migration records, upstream notices, GPL metadata, the redistributable examples, and required release/smoke tooling.

Current public CI definitions include private-evidence checks. Excluding that evidence does not make those checks pass. The candidate handoff must report any resulting public-tree CI or source-test limitation honestly; it must not publish private evidence or remove a guard merely to obtain a green result.

## Private and public packet areas

The private area retains source selection, the complete include/exclude ledger and reasons, canonical guard results, local paths, raw logs, and detailed qualification outcomes. None is automatically an upload asset.

The public area contains only deliberately selected, scanned artifacts: a redacted release-note draft, tag-pinned registry draft, self-contained redistributable installed smoke runner, and any retained qualified package archive approved for upload. An exact public-source tree is separately reviewed; the archive/site scanner is not a Git-history scanner. Record source-policy, registry, notes, smoke, archive, and manifest fingerprints before asking for publication approval. A missing archive or unavailable check remains `not_built`/`not_run`/`unqualified`.

## Current readiness dispositions

| Item | Current disposition |
|------|---------------------|
| Local packet tooling | Implemented by Plan 07-01; future real packet is selected and frozen in Plan 07-03 |
| Version/tag | `0.1.0` development candidate; proposed annotated unsigned `v0.1.0`; no tag published |
| Local supported-runtime smoke | `not_run`; installed Matrix 1.6.3 is below the declared 1.6-5 floor |
| Exact public-source archive, scan, check, and installation | Not yet built or qualified for this proposal |
| Full-scale benchmark and hosted Windows/serialization evidence | Existing accepted Phase 06 limitations; no new run or passing claim |
| Benchmark preflight report privacy/reference binding | CR-06 and CR-07 remain known limitations; no new preflight attempt |
| Canonical release guards | Dependency compatibility and attribution identity remain open; live provenance mismatch remains unresolved |
| Name availability | Must be refreshed immediately before an authorized release; no current release check is claimed |
| Canonical repository, registry repository, R-universe app/domain | Proposed destinations; current remote state was not probed during this draft |
| Source/metadata migration | New public root is proposed; no private Git history or private repository metadata is included implicitly |

These statuses permit local preparation to finish. They do not establish publication readiness or authorize inventing evidence, changing canonical rights facts, or reopening the accepted Phase 06 workflow.

## Exact later external actions for the final decision

The final packet must replace every unavailable identity above with the actual candidate identity or a clearly retained missing result. Present these actions together for one concrete maintainer decision:

1. Confirm the canonical target `DavidZenz/GEModelR`, live name/visibility/fork/default-branch state, public-source commit/tree, and the intentional new-root history proposal. If a target or metadata already exists, retain it and present the observed conflict; do not overwrite, force-push, delete, detach, or mirror implicitly.
2. If separately authorized and all applicable release guards genuinely pass, create/configure the intended canonical public source target and push only the reviewed public `main` commit/ref. Any visibility or default-branch/protection/required-check change must be named explicitly in this same decision and satisfy its canonical authority record; the proposal grants no settings authority.
3. Create the exact annotated unsigned `v0.1.0` tag at the approved public commit and publish it only if authorized. Verify any existing tag targets the same commit before reuse. No signing key installation is proposed, and no unsigned tag is described as cryptographically signed.
4. Run only the specifically authorized hosted qualification jobs for that revision, retaining actual results. Create the GitHub release/draft with the frozen notes and exact retained archive only after the actual publication-readiness check succeeds. A hosted draft is an external write. Use the intended repository explicitly and verify the tag; do not let release tooling create a tag on a default branch implicitly.
5. If authorized, create/update `DavidZenz/davidzenz.r-universe.dev`, install/authorize the R-universe GitHub app with the intended account/repository scope, and publish the exact registry draft. It contains one entry: `GEModelR`, URL `https://github.com/DavidZenz/GEModelR`, branch `v0.1.0`. Registry setup and app authorization are separate external effects named in the decision; neither is presumed already available.
6. Verify the deployed registry ref and source SHA, exact GitHub asset digest, and both fresh supported-library installations using the same numerical smoke from unrelated directories. Record GitHub/tag/archive identity and R-universe source/ref metadata separately. Mark REL-02 complete only after the real two-channel installed results pass.

Pages deployment, publishing private history/evidence, unrelated Actions dispatches, credential transfer, force-push, destructive recovery, and changes to canonical rights/license/provenance are not proposed by this packet. If the candidate is still unqualified or the maintainer retains local-only scope, record the exact pending disposition and stop at the final boundary without starting another Phase 06 gap cycle.
