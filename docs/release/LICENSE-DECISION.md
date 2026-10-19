# Package License Decision

Decision-Record-Version: 1
Decision-Status: reviewed
SPDX-License-Identifier: GPL-3.0-or-later
Description-License: GPL (>= 3)
Decision-Authority: GOVERNANCE.md
Reviewer: David Zenz
Review-Date-UTC: 2026-10-19
Referenced-License-Files: none
Citation-File: inst/CITATION
Outstanding-Blockers: DEPENDENCY_COMPATIBILITY_AUDIT_PENDING,ATTRIBUTION_IDENTITY_UNRESOLVED

## Decision

The maintainer selected GPL-3.0-or-later for GEModelR on 2026-10-19. R package
metadata uses the equivalent standard expression `GPL (>= 3)`. The approved
maintainer and release authority are recorded in `GOVERNANCE.md`.

This license permits commercial use and applies its copyleft and source-
availability terms when covered adaptations are conveyed. It does not require
citation or disclosure of private or internal use. GEModelR requests scholarly
citation and encourages commercial users to disclose use in relevant outputs
through `inst/CITATION`; these requests are not added GPL conditions.

## Scope and release status

This decision supplies the authoritative license choice for package metadata
and archive qualification. The standard GPL text is identified by the R license
expression, so no separate license text file is referenced here. The citation
metadata remains in the package at `inst/CITATION`.

The Phase 1 dependency-compatibility and attribution-identity blockers remain
open. This record does not clear either blocker and does not authorize a public
release, repository change, or publication.
