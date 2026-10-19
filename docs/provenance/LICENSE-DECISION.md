# Package License Decision

## Canonical status

License-Decision-Version: 1
Decision-Status: selected
Description-License: GPL (>= 3)
Dependency-Audit-Artifact: pending
Dependency-Audit-MD5: pending
Reviewer: David Zenz
Review-Date-UTC: 2026-10-19

The maintainer selected GPL-3.0-or-later for the package. The exact R metadata
expression is recorded above and in `DESCRIPTION`. This is an authoritative
license choice, not compatibility clearance: the dependency audit remains
pending, so public redistribution is still blocked.

## Final review transition contract

A future transition from `selected` to `reviewed` is valid only when every
condition below is satisfied in the same evaluated root:

- `Description-License` exactly equals the `DESCRIPTION` `License` field.
- `Dependency-Audit-Artifact` is a relative, under-root file path.
- `Dependency-Audit-MD5` exactly matches that artifact.
- `Reviewer` and `Review-Date-UTC` identify a completed review.
- R's package-license checker accepts the exact license expression.
- `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` is absent from all blocker records.

This record does not perform the dependency audit or authorize repository
mutation, release, or publication. The `selected` status keeps the exact
maintainer-approved package license visible while the compatibility blocker
remains active. Only a reviewed transition satisfying every predicate clears
that blocker.
