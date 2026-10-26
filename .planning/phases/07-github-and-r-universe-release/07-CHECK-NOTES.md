# Routine package-check note cleanup

The maintainer authorized the three proposed routine fixes on 2026-10-26:
align Author with Authors@R, remove repository-only top-level content from the
R source archive, and replace the legacy formula class comparison with inherits.
The affected identity evidence is refreshed once after these changes. Work stays
local; Phase 06 acceptance, historical serialization approval, provenance/rights,
and unrelated uncommitted solver/native changes are preserved.

Baseline: the preceding archive check reported zero errors, zero warnings and
six notes. The three addressed notes are DESCRIPTION author mismatch, nonstandard
top-level files, and the class comparison in R/formulaProcessing.R. Incoming URL,
size, and current-time notes are outside these fixes.

The Author field remains available and now includes the same full upstream
attribution comment as Authors@R. Both people, roles, maintainer, and license
remain unchanged. Rbuildignore excludes root site configuration/content,
MIGRATION.md, and development benchmarks; installed benchmark drivers under
inst/benchmarks remain available. The benchmark test locator supports that
standard source-package layout, and the source-only producer audit is also run
from the checkout. Formula symbols/constants/ordinary calls and indexed/nested
sums have focused regressions with independently calculated expected values.

Verification and raw logs are external at
`/tmp/GEModelR-check-cleanup-ZGGkPD`. Builds/checks use clean committed snapshots,
the existing isolated Matrix 1.6-5 library, actual qpdf/tidy, and bundled Pandoc on
PATH. Current shared libraries and proprietary data are not modified. The full
source archive check and exact final identities will be recorded after execution.
