# Package License Decision

Decision-Record-Version: 1
Decision-Status: reviewed
SPDX-License-Identifier: GPL-3.0-or-later
Description-License: GPL (>= 3)
Decision-Authority: GOVERNANCE.md
Reviewer: Codex automated technical review (maintainer-requested)
Review-Date-UTC: 2026-10-27
Referenced-License-Files: none
Citation-File: inst/CITATION
Outstanding-Blockers: NONE

Dependency-Audit-Artifact: inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md
Dependency-Audit-MD5: 7e92c9e09bd509fca57a1a368e7061e9
License-Selection-Authority: David Zenz
License-Selection-Date: 2026-10-19

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

The package-license choice was approved by David Zenz on 2026-10-19. The
2026-10-27 reviewer/date fields identify the subsequent maintainer-requested
automated dependency compatibility review. The audited source uses standard
GPL-compatible dependencies and native interfaces; the audit is retained at
`inst/compatibility/DEPENDENCY-LICENSE-AUDIT.md`. It does not claim approval of
arbitrary future dependencies or alternative binary runtime bundles.

The maintainer also confirmed the upstream Git identity alias on 2026-10-27.
Both previous intentional blockers are cleared for this reviewed source scope.
Artifact qualification, exact source selection and publication authorization
remain separate. This record does not authorize external publication.
