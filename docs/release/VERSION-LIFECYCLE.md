# Version and Compatibility Lifecycle

**Status: Adopted policy.** The maintainer approved this policy on 2026-10-06.

Version `0.1.0` is a development version and is not a public release.

## Proposed first-release transition

The current local proposal names an annotated unsigned `v0.1.0` tag. No signing
key is required by this proposal, and an unsigned tag must not be called
cryptographically signed. This publication mechanism is pending review; it does
not change the adopted compatibility rules below.

Version `0.1.0` becomes a public release only after the exact approved tag and
release are actually published and recorded. At that boundary, update the public
release heading and record source/artifact identities and the real installation
results for both distribution channels. Local preparation or acceptance of a
development phase does not establish that transition, clear a public release
guard, or imply `1.0.0` stability from the milestone name.

## Pre-1.0 policy

While the major version is zero, minor releases may include documented
breaking changes. Patch releases carry compatible fixes. Release notes should
identify user-visible behavior changes and migration steps when a minor release
changes a documented interface.

## Post-1.0 policy

After version `1.0.0`, use Semantic Versioning meanings: patch releases contain
compatible fixes, minor releases add backward-compatible functionality, and
major releases may change documented interfaces incompatibly.

## Deprecations

When practical, a deprecation notice should identify the replacement and give
an expected removal timing. Release notes and package help should describe the
deprecation consistently.

## Release boundary

This policy does not resolve the package license or attribution identity,
clear a release gate, or authorize redistribution or publication. The current
blockers remain `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and
`ATTRIBUTION_IDENTITY_UNRESOLVED`; see [Release Gates](RELEASE-GATES.md).
