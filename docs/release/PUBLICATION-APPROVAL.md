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
| Development source commit | `a0a42662a5a1199c5bf67276b97f772f83e68fa8` |
| Development source tree | `57ceade529c648b68a1326d2122aff76647aa591` |
| Proposed public root commit | `4041517a944ca67724b4ca45b53a6ba27911eea5` |
| Proposed public source tree | `de6ea107d489528280ed13294320c7996ff4b425` |
| Review content digest (`content_sha256`) | `7a61380fc34c9c8a632376b9090295b2281e37be12ddf0bc75c5fddd567ab833` |
| Private manifest file SHA-256 | `0331d44297ea2b3f7d5612a705c45457cc8fa5fc25479f2b4c0899fcadbbb3d1` |
| Public manifest file SHA-256 | `60168ca7b09bb3c7612232ccd2d5be2f51f5c3ffe047e2a2b1f8f2580938c25a` |
| Explicit source-policy SHA-256 | `0369647df01eae5b633e20efd9a460cae95f4e8559947c6ae991832066859947` |
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
| Offline canonical release guard | `invalid`, exit 1; `PROVENANCE_KEY_MISMATCH` |
| Canonical Git installation | `not_run` |
| R-universe installation | `not_run` |
| External publication | `not_run` |

These actual outcomes make this candidate unready for publication. No executable publication approval is being requested for it. The accepted Phase 06 limitations remain recorded under `06-ACCEPTANCE.md`; they are not reopened, converted into passing results, or treated as rights or publication authority. Dependency compatibility and attribution identity also retain their existing release dispositions. Current public-CI dependencies on excluded private evidence remain a documented readiness limitation.

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
