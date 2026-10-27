# Package License Decision

## Canonical status

License-Decision-Version: 1
Decision-Status: reviewed
Description-License: GPL (>= 3)
Dependency-Audit-Artifact: inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md
Dependency-Audit-MD5: 7e92c9e09bd509fca57a1a368e7061e9
Reviewer: Codex automated technical review (maintainer-requested)
Review-Date-UTC: 2026-10-27

The maintainer selected GPL-3.0-or-later on 2026-10-19. That selection is
unchanged. The 2026-10-27 automated technical review completed the separate
dependency/native compatibility audit bound above. Reviewer/date fields here
identify that technical review; the original human license authority remains
David Zenz and is not replaced by an invented human audit signature.

The audit covers the mandatory package closure, LinkingTo, native include/link
inputs, and the inspected standard runtime. Its compatible result clears
DEPENDENCY_COMPATIBILITY_AUDIT_PENDING for this source scope. Alternative
runtime bundles or future dependency license changes require a new review.
The artifact must remain under-root, nonlinked, and match Dependency-Audit-MD5;
DESCRIPTION must retain GPL (>= 3), and no dependency blocker may coexist with
the reviewed state. Publication authority remains a separate boundary.
