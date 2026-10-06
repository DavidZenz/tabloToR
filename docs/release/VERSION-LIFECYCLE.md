# Version and Compatibility Lifecycle

**Status: Proposal.** Assumption A-SEMVER-01 remains unresolved until the
maintainer approves this policy or records an alternative. Do not present the
proposal as an established compatibility promise before that decision.

Version `0.1.0` is a development version and is not a public release.

## Proposed pre-1.0 policy

While the major version is zero, minor releases may include documented
breaking changes. Patch releases carry compatible fixes. Release notes should
identify user-visible behavior changes and migration steps when a minor release
changes a documented interface.

## Proposed post-1.0 policy

After version `1.0.0`, use Semantic Versioning meanings: patch releases contain
compatible fixes, minor releases add backward-compatible functionality, and
major releases may change documented interfaces incompatibly.

## Deprecations

When practical, a deprecation notice should identify the replacement and give
an expected removal timing. Release notes and package help should describe the
deprecation consistently.

## Release boundary

This proposal does not resolve the package license or attribution identity,
clear a release gate, or authorize redistribution or publication. The current
blockers remain `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and
`ATTRIBUTION_IDENTITY_UNRESOLVED`; see [Release Gates](RELEASE-GATES.md).
