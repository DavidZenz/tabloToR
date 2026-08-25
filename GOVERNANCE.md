# GEModelR Governance

## Identity record

Maintainer: David Zenz
Approved-Contact: zenz@wiiw.ac.at
Release-Authority: David Zenz
Security-Route: mailto:zenz@wiiw.ac.at
Identity-Approval: approved
Reviewer: David Zenz
Review-Date-UTC: 2026-08-25

These marker values are the canonical v1 governance identity record. The
maintainer and release authority follow decisions D-10 and D-11. The contact,
security route, reviewer, and review date were supplied and positively approved
at the blocking identity checkpoint. Local Git metadata, remotes, commits, and
operating-system account details were not used as approval evidence.

## Initial-release authority

David Zenz is the sole maintainer and release authority for the initial
GEModelR release. The release authority owns release-gate decisions, versioning,
tag and artifact approval, and the final decision to publish. This governance
record does not itself authorize repository reservation, repository mutation,
visibility changes, branch-setting changes, a release, or publication.

Contributions are accepted through pull requests. The target `main` branch must
be protected and merges must require the applicable CI checks to pass. While
David Zenz remains the sole maintainer, self-review and self-merge are permitted
after the pull request is documented and required CI passes. Direct unreviewed
release changes are not part of the initial-release process.

## Adding maintainers

A maintainer is added only through a dedicated governance pull request that:

1. names the candidate and proposed responsibilities;
2. records the candidate's acceptance and an approved durable contact;
3. identifies repository, release, and security permissions to be granted;
4. passes required CI and receives explicit approval from the current release
   authority; and
5. updates this record and any repository access or branch rules only after a
   separate human-authorized settings change.

New access starts with the minimum permissions needed. Adding a maintainer does
not automatically transfer release authority. Any transfer must be stated
explicitly in the approved governance change.

## Succession and loss of availability

For planned succession, the current release authority nominates a successor in
a governance pull request, the successor accepts in writing, and the record
identifies the effective date and transferred responsibilities. Repository
access, package metadata, security routing, and recovery custody are verified
before the transfer is considered complete.

If the sole maintainer becomes unexpectedly unavailable and no approved
successor is recorded, releases and publication stop. A successor must provide
reviewable evidence of repository authority, document the recovery basis in a
governance change, rotate affected credentials, revalidate the security route,
and rerun all release gates. Commit authorship, local credentials, or control of
a clone alone do not confer maintainership or release authority.

## Security responsibility

Until another maintainer is explicitly assigned, David Zenz is responsible for
receiving and triaging vulnerability reports, coordinating fixes and disclosure,
and deciding whether a security release is required. The approved reporting
route is `mailto:zenz@wiiw.ac.at`. Approval of this route does not authorize a
public release or publication.

Potential vulnerabilities must not be posted to a public issue tracker unless
the approved security policy explicitly directs that. Changing the security
route or delegating security responsibility requires a reviewed governance
change and confirmation that the new route is controlled and monitored.

## Approval boundary

`Identity-Approval: approved` records the maintainer's positive approval of the
exact durable contact and security route together with the reviewer identity and
UTC review date. The repository identity record carries the same approval status
and reviewer signature. External repository and release actions remain governed
by their separate `not-authorized` markers.
