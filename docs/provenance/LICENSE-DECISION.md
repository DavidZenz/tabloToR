# Package License Decision

## Canonical status

License-Decision-Version: 1
Decision-Status: pending
Description-License: What license is it under?
Dependency-Audit-Artifact: pending
Dependency-Audit-MD5: pending
Reviewer: pending
Review-Date-UTC: pending

The package license remains unresolved while
`DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` is an intentional release blocker.
The placeholder above must match `DESCRIPTION` exactly and cannot authorize a
release.

## Reviewed transition contract

A future transition to `Decision-Status: reviewed` is valid only when every
condition below is satisfied in the same evaluated root:

- `Description-License` exactly equals the `DESCRIPTION` `License` field.
- `Dependency-Audit-Artifact` is a relative, under-root file path.
- `Dependency-Audit-MD5` exactly matches that artifact.
- `Reviewer` and `Review-Date-UTC` identify a completed review.
- R's package-license checker accepts the exact license expression.
- `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` is absent from all blocker records.

This record does not perform the dependency audit, select a final license, or
authorize repository mutation, release, or publication. Until a reviewed
transition satisfies every predicate, the checked-in pending values remain
canonical.
