# Clean-room replacement protocol

Cleanroom-Protocol-Version: 2
Cleanroom-Coverage: not-activated
Cleanroom-Review-Status: not-reviewed

## Status and governing decision

This document defines the D-02 and D-04 fallback for replacing inherited
expression. It does not assert that replacement work has started or that any
component is independently implemented. Activating the protocol requires a
reviewed decision and changes `Rights-Status` to `clean-room-required`, never
directly to `cleared`.

Assumption delta: no change. The primary noun remains the rights basis.
Clean-room replacement is an alternative evidentiary route for inherited
expression, not a generalized identity, attribution, or data-model transition.
It cannot clear an unrelated release gate or authorize publication.

Release eligibility requires complete evidence for every inherited provenance
key. Zero inherited keys, zero component specifications, or one missing,
duplicate, stale, or unreviewed key is incomplete rather than vacuously
complete.

## Distinct roles

Each component has a behavior-only specification author, an independently
eligible implementer, and an independent reviewer. The independently generated
result also names its producer. The specification author, implementer, reviewer,
and result producer must be distinct for the same component. Names or stable
identities are evidence labels; they do not by themselves prove independence.

The implementer records `implementer_source_access: none` and
`no-inherited-source-access`. Any inherited-source exposure returns
`CLEANROOM_IMPLEMENTER_INELIGIBLE`. Review feedback must never transmit
inherited expression, source-derived structure, or implementation hints.

## Admissible inputs

The implementer may receive only the approved behavior specification, public
standards, and redistributable synthetic or reduced fixtures. Inherited source
excerpts, source-derived pseudocode or structural descriptions, private
correspondence, proprietary fixtures, credentials, private model inputs, and
large result artifacts are prohibited.

## Root-confined artifact evidence

Every component record under `specs/cleanroom/` identifies five distinct files:

- replacement source and `replacement_source_md5`;
- runnable behavior test and `behavior_test_md5`;
- public-standard evidence and `public_standard_evidence_md5`;
- redistributable fixture and `fixture_md5`; and
- independent result and `independent_result_md5`.

Every path is a non-empty repository-relative path. The checker rejects
absolute paths, drive-qualified paths, empty/dot/parent segments, missing files,
directories, non-regular files, empty files, symlink escape after real-path
resolution, duplicate artifact reuse, malformed hashes, and byte drift. Each
hash is the exact lowercase 32-character MD5 of the resolved file. Diagnostics
return only stable reason codes and never external paths or file contents.

## Runnable test and independent result

The behavior test is invoked only through the R installation's fixed `Rscript`
executable with `--vanilla`, the resolved test path, and fixed named
`--source`/`--fixture` arguments. No component supplies a shell command. A
nonzero status, subprocess error, or absent fresh pass returns
`CLEANROOM_EVIDENCE_INCOMPLETE`.

The independent result is a single-record DCF artifact. It binds the component
and provenance key; source, test, fixture, and public-standard hashes; command
identity `rscript-cleanroom-v1`; exit status zero; result status `pass`; result
producer; produced-at UTC timestamp; reviewer; and review date. All dates must
round-trip exactly. A stale, malformed, self-produced, hash/key/command/status
mismatch is incomplete evidence, or implementer ineligibility when the collision
shows the implementer produced the result.

## Coverage and integrated release boundary

`Cleanroom-Coverage: complete` means exact one-to-one equality between the
`Inherited-Provenance-Key` set and component records. Before synthetic release
readiness, every covered ledger row must exist, have classification
`new-independent`, and match the validated replacement-source hash. The full
integrated source, attribution, name, governance, repository, description, and
license evidence graph must also pass.

Temporary synthetic fixtures may prove the positive route. They never update
canonical RIGHTS or PROVENANCE evidence. The checked-in repository therefore
retains `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and
`ATTRIBUTION_IDENTITY_UNRESOLVED` until separately reviewed evidence resolves
them.

## Fail-closed outcomes

- `CLEANROOM_IMPLEMENTER_INELIGIBLE` means an implementer is source-exposed or
  occupies an incompatible independent role.
- `CLEANROOM_EVIDENCE_INCOMPLETE` means a required field, artifact, hash,
  runnable pass, result binding, role, attestation, or exact coverage record is
  absent or contradictory.
- `CLEANROOM_REVIEW_INCOMPLETE` means protocol-level independent approval is
  absent.

All outcomes keep `release_ready=false` unless every clean-room and integrated
predicate passes.
