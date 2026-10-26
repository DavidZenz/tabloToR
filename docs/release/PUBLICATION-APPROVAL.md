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
| Development source commit | `0ac93368be49b814998868b6fe56c9ad097a2e7f` |
| Development source tree | `f0415116ec4f874718f7242db32c6f1f5584eb34` |
| Proposed public root commit | `382af3d087c5f545ce523cf52dfff475a2197e8b` |
| Proposed public source tree | `d22deb4414a67bc3756c4ae6b5ae1988b40e303e` |
| Review content digest (`content_sha256`) | `9e776314b8528ba7533fac415015e2ae59a5011a2efacc018b58e7a9674f0d77` |
| Private manifest file SHA-256 | `ca8faae2376c748d828a55da51756ea679581c7b80ec0d5fd9f07d0efbd64132` |
| Public manifest file SHA-256 | `4e56bf73805074762251c27316eade50e90565aa851b6230f1cdd50c52d3d2a9` |
| Explicit source-policy SHA-256 | `c2a64e5c2810d5f29e45163c510e42c4af52e8d7dc3eed0c45483472fcb6b5ef` |
| Release notes SHA-256 | `7a7498688223ce803eb3a4b0989c433ee3b43f831a7da7ea19e18a52df04a8b5` |
| Tag-pinned registry SHA-256 | `18fc79f3540ebdccc05b393eaf6c7d5b0cde663dc5b49cf3ba365e73d6ba70a8` |
| Installed smoke runner SHA-256 | `f7241b877ff0112151fc22634930bc5f43ef9ed90d0c414599f7b2055d877d15` |
| Archive source commit / basename / SHA-256 | `382af3d087c5f545ce523cf52dfff475a2197e8b` / `GEModelR_0.1.0.tar.gz` / `c4c0d237cb438e3330fa59d61dfa8204587b9f173a55179a426a9844ef41ced7` |

The review content digest and the private manifest file SHA-256 are different identities: the former is the manifest's recorded content identity, while the latter hashes the complete serialized manifest bytes. Neither is a cryptographic signature or a maintainer approval.

The public-source proposal has one new root commit and no inherited private development history. Only the explicitly included public tree is proposed for `main` and the annotated unsigned `v0.1.0` tag. The original development repository, its refs/index, and unrelated working changes remain outside this publication proposal. Private paths, guard logs, planning records, proprietary GTAP inputs, raw solutions, and raw measurements are not upload assets.

## Actual local verification and readiness

On 2026-10-26, the final repaired packet at `/tmp/GEModelR-check-repair-1jttZn/final-packet` was verified with `prepare-release.cjs verify`: exit 0, `status=verified`, and the exact source/public commits and review content digest above. The stricter `verify --for-publication` returned exit 1 with `FAIL PUBLICATION_NOT_READY`.

| Check | Actual disposition |
|-------|--------------------|
| Packet integrity and retained source identities | Verified locally |
| Qualification evidence kind | `actual` |
| Installed Matrix / declared minimum | Isolated `1.6.5` / `1.6-5`; shared `1.6.3` unchanged |
| Runtime qualification | Supported |
| Exact archive build / scan / check | Build and scan passed; check has 0 errors, 0 warnings, 6 notes; 3053 assertions passed, 0 failed, 113 skipped. The strict `Status: OK` archive gate remains failed |
| Installed numerical smoke | Separate fresh-process smoke passed against the check-installed archive; pipeline-gated smoke remains `not_run` |
| Separate source-tool tests | Frozen packet history: seven stale identity-count errors; the later current-source identity refresh below resolves them |
| Separate explicit URL check | `not_run`; no network URL pass claimed |
| Offline canonical release guard | `invalid`, exit 1; `PROVENANCE_KEY_MISMATCH` |
| Canonical Git installation | `not_run` |
| R-universe installation | `not_run` |
| External publication | `not_run` |

These actual outcomes make this candidate unready for publication. No executable publication approval is being requested for it. The accepted Phase 06 limitations remain recorded under `06-ACCEPTANCE.md`; they are not reopened, converted into passing results, or treated as rights or publication authority. Dependency compatibility and attribution identity also retain their existing release dispositions. Current public-CI dependencies on excluded private evidence remain a documented readiness limitation.

The identities above refer to the final committed test-context repair, including explicit source/installed separation, restored namespace mocking, declared test dependencies, fixture-order isolation, and administrative script path fixes. Production R/C++ implementations and unrelated dirty work were excluded from these changes. Earlier packets were not edited. See `.planning/phases/07-github-and-r-universe-release/07-CHECK-REPAIR.md` for actual results and evidence locations; `07-SUPPORTED-RUNTIME.md` retains the preceding failed candidate's history. Local repair authorization grants no external action: the packet-specific publication decision is still `not_received` and Plan 07-04 remains at its existing checkpoint.

The subsequent maintainer-authorized identity refresh (`5c252ab`) passes current
historical/tracked-source audits, all 152 source-tool assertions, 147
identity-migration assertions and 243 current serialization assertions, with zero
skips in those groups. Original historical artifacts and rights/provenance are
unchanged. The broader reseal check exposed a separate stale historical
serialization BUGFIX approval whose After-SHA256 differs from current source;
that approval is preserved. See `07-IDENTITY-REFRESH.md` in the same private
planning directory. This follow-up does not change the frozen packet identities
above or claim a newly qualified archive; it remains local, with provenance,
historical serialization approval and the preceding six check notes unresolved.

## Standing instruction and pending decision

The maintainer's existing instruction was:

> keep local

That restriction continues to apply. This file records the reviewable local handoff and the absence of a new packet-specific decision; it does not interpret the standing restriction as approval of these candidate bytes, the new public history, or any external action. No prior local-only restriction is superseded.

Plan 07-04 remains at Task 1. Tasks 2 and 3 have not run, and REL-02 remains pending. A future publication decision is relevant only after actual readiness is satisfied and must name the exact then-current packet, assets, destinations, actions, and identities. Changed candidate bytes or actions require a fresh recorded scope; this draft cannot authorize them.

## Proposed external scope for a future ready candidate

The concrete proposal in `PUBLICATION-PLAN.md` remains unapproved:

1. Canonical source destination: `DavidZenz/GEModelR`, `https://github.com/DavidZenz/GEModelR`; proposed public `main` and exact tag `v0.1.0` at the approved public commit. Current remote state has not been probed for this decision.
2. Repository creation/visibility, default-branch/protection/required-check settings, or hosted CI dispatches only if each is explicitly named in the eventual authorization. A push may itself trigger the listed workflows.
3. An annotated unsigned tag and a GitHub draft release containing the exact retained R-built archive and frozen notes, using the named repository and verified tag. An archive now exists, but it has not passed release qualification and is not approved for upload.
4. Registry destination: `DavidZenz/davidzenz.r-universe.dev`; proposed universe `https://davidzenz.r-universe.dev`; one `GEModelR` entry with canonical URL and branch `v0.1.0`. Registry publication and GitHub app authorization require their own expressly included scope.
5. Two clean supported-library installations and the same exact numerical smoke, with Git tag/source and R-universe `RemoteSha`/`RemoteRef` evidence retained. Any later GitHub draft promotion must be included in the same exact authorization and wait for both real channel results.

The candidate retains GPL-3.0-or-later, existing credit, migration/backend/platform limits, and the proposed capacity-dependent weekly triage/monthly patch cadence in the frozen release notes. These are available for review; this pending record does not newly approve the cadence or claim a published support service.

Pages deployment, private history/evidence publication, force-push, destructive ref recovery, credential transfer, and changes to canonical rights/license/provenance records are outside the proposal. The retained packet stays local without another Phase 06 gap or UAT cycle.
