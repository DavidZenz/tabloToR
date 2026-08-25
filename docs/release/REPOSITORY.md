# GEModelR Repository Identity and Private-Development Boundary

## Canonical identity record

Owner-Slug: awaiting-human-approval
Repository-Name: GEModelR
Canonical-URL: awaiting-human-approval
Issue-Tracker: awaiting-human-approval
Visibility-Boundary: private-development
Identity-Approval: unapproved
Reviewer: awaiting-human-approval
Review-Date-UTC: awaiting-human-approval
Reservation-Authorization: not-authorized
Visibility-Detachment-Authorization: not-authorized
Branch-Settings-Authorization: not-authorized
Release-Authorization: not-authorized

The v1 canonical repository belongs on David Zenz's personal GitHub account,
but the account owner slug is not inferred from local Git configuration,
remotes, credentials, operating-system names, or commit history. After the slug
is approved, the only admissible URL pair is derived without redirects or
aliases:

- canonical repository: `https://github.com/<approved-owner-slug>/GEModelR`
- issue tracker: `https://github.com/<approved-owner-slug>/GEModelR/issues`

The exact slug and both exact HTTPS URLs remain pending until the blocking
identity checkpoint. `Identity-Approval`, `Reviewer`, and `Review-Date-UTC` must
then match `GOVERNANCE.md`. No marker in this document authorizes an external
action.

## Private-development boundary

Development remains private until the applicable release gates and a separate
publication authorization pass. The canonical v1 target must therefore be a
private repository. A public GitHub fork cannot independently become private
inside a public fork network; if GitHub confirms that constraint applies, the
target must be a private standalone repository created by an authorized
reservation or produced through an authorized detach/mirror workflow.

Do not publish source, binaries, package archives, documentation sites, release
tags, or an R-universe channel from this record. Do not change the current
repository's visibility, fork relationship, remotes, default branch, protection
rules, or CI settings without the corresponding fresh blocking-human gate.

## Required pre-detach or pre-mirror inventory

Before any visibility, detachment, or mirror action, capture a dated local
inventory without exposing private content:

1. current repository owner/name, visibility, fork-network status, default
   branch, remote names, and the exact source HEAD;
2. all local branches, remote-tracking branches, tags, and their object IDs;
3. open and closed issues, pull requests, discussions, releases, projects,
   wiki state, deploy keys, webhooks, environments, secrets names (never secret
   values), collaborators/teams, branch rules, required checks, stars, and
   watchers that would not move with Git history;
4. Git LFS use, submodules, package registries, pages/sites, Actions artifacts,
   and other separately stored objects; and
5. an explicit migration or intentional-nonmigration disposition for every
   inventoried metadata class.

The inventory itself may contain private repository metadata and therefore
must remain outside public evidence unless the maintainer separately approves
a redacted version.

## History verification and recovery

An authorized detach or mirror must preserve the original repository unchanged
until the target has been verified. Verification must compare source and target
HEAD, branches, tags, and reachable object IDs; run Git object-integrity checks;
confirm the intended default branch and private visibility; and verify every
inventoried metadata disposition. A source URL or successful push alone is not
sufficient evidence.

Before changing local remotes, record their exact prior configuration. If
verification fails, stop use of the target, restore the recorded local remote
configuration, keep the original repository authoritative, and report the
failed target for an explicit recovery decision. Deletion, recreation,
force-push, or visibility changes are destructive recovery actions and require
their own human authorization; this runbook never authorizes them implicitly.

## Separate external-action gates

### Repository reservation

Immediately before reservation, rerun the six-source checker with
`--check-kind reservation`. Continue only if the fresh report has no exact
case-insensitive collision and a blocking-human checkpoint approves the exact
owner slug, `GEModelR` repository name, private visibility, and action. The
current marker is `Reservation-Authorization: not-authorized`.

### Visibility, detachment, or mirroring

Complete the metadata inventory and recovery plan first. A fresh
blocking-human checkpoint must then approve the exact source, target, method,
visibility, and preserved metadata. The current marker is
`Visibility-Detachment-Authorization: not-authorized`.

### Branch and CI settings

After the approved private target exists and history is verified, a separate
blocking-human checkpoint must approve changing the default branch or settings.
The target policy is protected `main`, passing required CI before merge, and
the sole-maintainer self-review rule in `GOVERNANCE.md`. The current marker is
`Branch-Settings-Authorization: not-authorized`.

### Release or publication

Immediately before any release or publication, rerun the checker with
`--check-kind release`, satisfy every release gate, and obtain a separate
blocking-human authorization for the exact commit, tag, artifacts, visibility,
and publication destinations. This includes GitHub releases, public source,
package archives, documentation sites, and R-universe. The current marker is
`Release-Authorization: not-authorized`.
