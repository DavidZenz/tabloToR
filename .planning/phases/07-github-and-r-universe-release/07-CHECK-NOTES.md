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

Cleanup code commit: `8d4d9c9ee183fbe391fdb3e3e3876331f8c0ef8e`.
The single identity refresh changes mixed-case counts from 420 to 421 because
the Author field now carries the same upstream credit as Authors@R; upper-case
counts remain 2. The normalized fingerprint changes from
`edc688b8dc55aa908dd41f7afb420375` to `99cc904fa2d5934dd9aa8294782175ad`.
Historical and tracked-source audits pass. Four existing allowlist rows change,
none are added or removed. Protected solver/region hashes and all historical
numerical/predecessor artifacts remain unchanged.

Updated map SHA256:
`eea9db2264234e7b9cf1129bb4e568fd6d904235b7c0b20146c3337e00545f97`.
Updated allowlist SHA256:
`5f7fb37bc9ce20d940d7402babb7248fecd852944fe96bae20ac4d51d1d5dba4`.
Protected registry SHA256 remains
`3ed6b5601d207cad56dd6d88a6eecac250e12bf1c612d9a06f82201cd1e72b0a`.

Focused formula regressions pass all 5 assertions, including independently
calculated nested-sum results. Source benchmark contracts pass all 6 tests and
57 assertions with zero skips; source-only producer coverage is preserved.

The initial direct-check archive confirmed the author and R-code checks are OK.
Its top-level check exposed two additional repository-only directories that
earlier projected builds omitted: docs/migration and specs/cleanroom. The build
filter now excludes all root docs and specs as well. These paths and Rbuildignore
are outside the fingerprinted runtime scope; the one identity refresh remains
valid unchanged. The intermediate archive/logs are retained; the final archive
will be rebuilt into a separate directory, never overwritten while being checked.
