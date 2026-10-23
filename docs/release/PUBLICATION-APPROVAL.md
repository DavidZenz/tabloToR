# GEModelR publication decision — pending

Status: pending_local_only
Package: GEModelR
Version: 0.1.0
Candidate-Status: development
Intended-Tag: v0.1.0
Tag-Type: annotated_unsigned
Preparation-Status: complete
Publication-Readiness: blocked
Packet-Specific-Maintainer-Decision: not_received
Publication-Authorization: not_authorized
Authorized-External-Actions: none
Standing-Instruction: keep local
Standing-Instruction-Superseded: false
REL-02-Status: pending

## Exact prepared candidate

| Identity | Value |
|----------|-------|
| Development source commit | `e46ea70e737bc709880458ab1548244a2fd525cd` |
| Development source tree | `6ef6c2d60b4dce13bea34f31b47473bc96b40673` |
| Proposed public root commit | `ee8f5d26c9565db3407567e065633a0b0252da9a` |
| Proposed public source tree | `cb74d2a4000c3d84ae005d05c63769597988d24a` |
| Review content digest (`content_sha256`) | `e9a41d268ac88238bff47ded201fe3d0bbd391365fbc288e288e0d0a05b3b4dd` |
| Private manifest file SHA-256 | `66782d716bd9b9b9e0cf7ca6809068d898b266787b369b01319be98cea5159d5` |
| Public manifest file SHA-256 | `9c49ebc2693cbeb46b50b4586b1686daa4ac2b13ae11791675a3b1ef5e5186ef` |
| Explicit source-policy SHA-256 | `d5df0943ae5ce47c8aba148732fecf69da899e3345b54578566c7f96167215cd` |
| Release notes SHA-256 | `7a7498688223ce803eb3a4b0989c433ee3b43f831a7da7ea19e18a52df04a8b5` |
| Tag-pinned registry SHA-256 | `18fc79f3540ebdccc05b393eaf6c7d5b0cde663dc5b49cf3ba365e73d6ba70a8` |
| Installed smoke runner SHA-256 | `f7241b877ff0112151fc22634930bc5f43ef9ed90d0c414599f7b2055d877d15` |
| Archive source commit / basename / SHA-256 | `not_built` / `not_built` / `not_built` |

The review content digest and the private manifest file SHA-256 are different identities: the former is the manifest's recorded content identity, while the latter hashes the complete serialized manifest bytes. Neither is a cryptographic signature or a maintainer approval.

The public-source proposal has one new root commit and no inherited private development history. Only the explicitly included public tree is proposed for `main` and the annotated unsigned `v0.1.0` tag. The original development repository, its refs/index, and unrelated working changes remain outside this publication proposal. Private paths, guard logs, planning records, proprietary GTAP inputs, raw solutions, and raw measurements are not upload assets.

## Actual local verification and readiness

On 2026-10-23, the retained external packet was reverified with `prepare-release.cjs verify`: exit 0, `status=verified`, and the exact source/public commits and review content digest above. The stricter `verify --for-publication` returned exit 1 with `FAIL PUBLICATION_NOT_READY`.

| Check | Actual disposition |
|-------|--------------------|
| Packet integrity and retained source identities | Verified locally |
| Qualification evidence kind | `actual` |
| Installed Matrix / declared minimum | `1.6.3` / `1.6-5` |
| Runtime qualification | `unavailable`; `MATRIX_BELOW_FLOOR` |
| Exact archive build / scan / check | `not_run`; archive `not_built` |
| Installed numerical smoke | `not_run` |
| Separate explicit URL check | `not_run`; no network URL pass claimed |
| Offline canonical release guard | `invalid`, exit 1; `PROVENANCE_KEY_MISMATCH` |
| Canonical Git installation | `not_run` |
| R-universe installation | `not_run` |
| External publication | `not_run` |

These actual outcomes make this candidate unready for publication. No executable publication approval is being requested for it. The accepted Phase 06 limitations remain recorded under `06-ACCEPTANCE.md`; they are not reopened, converted into passing results, or treated as rights or publication authority. Dependency compatibility and attribution identity also retain their existing release dispositions. Current public-CI dependencies on excluded private evidence remain a documented readiness limitation.

The candidate identities above supersede the initial packet after the two focused tooling review fixes. The initial packet was not edited. The new source policy explicitly excludes the private review, summary and pending approval records. This refresh records new candidate bytes only: the packet-specific maintainer decision is still `not_received`, no external action is authorized, and Plan 07-04 remains at its existing checkpoint.

## Standing instruction and pending decision

The maintainer's existing instruction was:

> keep local

That restriction continues to apply. This file records the reviewable local handoff and the absence of a new packet-specific decision; it does not interpret the standing restriction as approval of these candidate bytes, the new public history, or any external action. No prior local-only restriction is superseded.

Plan 07-04 remains at Task 1. Tasks 2 and 3 have not run, and REL-02 remains pending. A future publication decision is relevant only after actual readiness is satisfied and must name the exact then-current packet, assets, destinations, actions, and identities. Changed candidate bytes or actions require a fresh recorded scope; this draft cannot authorize them.

## Proposed external scope for a future ready candidate

The concrete proposal in `PUBLICATION-PLAN.md` remains unapproved:

1. Canonical source destination: `DavidZenz/GEModelR`, `https://github.com/DavidZenz/GEModelR`; proposed public `main` and exact tag `v0.1.0` at the approved public commit. Current remote state has not been probed for this decision.
2. Repository creation/visibility, default-branch/protection/required-check settings, or hosted CI dispatches only if each is explicitly named in the eventual authorization. A push may itself trigger the listed workflows.
3. An annotated unsigned tag and a GitHub draft release containing the exact retained R-built archive and frozen notes, using the named repository and verified tag. No archive exists for this candidate.
4. Registry destination: `DavidZenz/davidzenz.r-universe.dev`; proposed universe `https://davidzenz.r-universe.dev`; one `GEModelR` entry with canonical URL and branch `v0.1.0`. Registry publication and GitHub app authorization require their own expressly included scope.
5. Two clean supported-library installations and the same exact numerical smoke, with Git tag/source and R-universe `RemoteSha`/`RemoteRef` evidence retained. Any later GitHub draft promotion must be included in the same exact authorization and wait for both real channel results.

The candidate retains GPL-3.0-or-later, existing credit, migration/backend/platform limits, and the proposed capacity-dependent weekly triage/monthly patch cadence in the frozen release notes. These are available for review; this pending record does not newly approve the cadence or claim a published support service.

Pages deployment, private history/evidence publication, force-push, destructive ref recovery, credential transfer, and changes to canonical rights/license/provenance records are outside the proposal. The retained packet stays local without another Phase 06 gap or UAT cycle.
