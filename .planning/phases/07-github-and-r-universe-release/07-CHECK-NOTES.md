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

The intermediate archive's full suite also exposed five benchmark test errors
from two additional hardcoded root benchmark lookups. Their source locators now
support inst/benchmarks in source archives; execution and independent installed
script hash assertions remain intact. No tests are disabled to clear these
errors. The changes are test-only and outside the runtime fingerprint scope.

## Final archive and validation

The final archive is built from committed source
`c3bca33d06190ad5afd48880aee058d7a819adf1` after all archive-layout corrections.
It is retained at
`/tmp/GEModelR-check-cleanup-ZGGkPD/release/GEModelR_0.1.0.tar.gz`.
SHA256: `e0c6da89610e5ca8cea37e7904f26f93c793022dac08aeb03eeed14227425763`.
Size: 283589 bytes, versus 306101 bytes in the preceding qualified-build attempt.
The content scan passes on all 183 entries. All six nonstandard root paths are
absent; all five installed benchmark drivers remain present.

The first intermediate check's five benchmark lookup errors were reproduced and
fixed without removing assertions. The targeted archive-layout run now passes
all 6 tests and 95 assertions, with zero skips. The six affected source groups
pass 68 tests and 604 assertions with zero failures/errors/skips, using one
installed namespace in a separate fresh process. Focused combined coverage is
therefore 699 passing assertions. Logs are `logs/layout-tests.log` and
`logs/source-tests.log`; their RDS reports retain per-test results.

An attempted reuse of unchanged rendered vignette outputs caused an intermediate
freshness warning because the fresh checkout had newer source timestamps. That
check was stopped; its logs remain at `logs/verified-R-CMD-check.log`. The final
archive uses normal vignette regeneration (`logs/release-build.log`), and its
actual output freshness was checked before the final package check. No timestamp
warning is waived or converted into a pass.

The final archive-installed numerical smoke passes with supported Matrix 1.6-5
and expected solution `(0, 6, 0)` within 1e-12. The recorded source basis is
caller-attested local source; surrounding archive/check records bind it to the
retained archive. Historical and tracked-source identity audits also pass against
the final committed source, without regenerating the identity records again.
Logs: `logs/release-installed-smoke.log` and
`logs/release-identity-validation.log`.

All three requested check steps, plus actual vignette freshness, report OK in the
completed final check: **zero errors, zero warnings, three notes**. Installed tests
report **3037 passes, zero failures/warnings, 115 skips**, taking 200.183 seconds
wall time (236.190 user + 9.348 system CPU seconds). Vignette rebuild, PDF and HTML
manual checks pass. Raw results are
`release/check/GEModelR.Rcheck/00check.log` and `tests/testthat.Rout`; the command
log is `logs/release-R-CMD-check.log`.

Compared with the earlier 3053-pass installed suite, 21 source-only producer
assertions now execute in the separately verified source benchmark audit, and
five new formula assertions run in the installed suite. Their source-only audit
is explicitly skipped when the development drivers are absent from the archive.
The second added skip versus the earlier archive is the source-only identity
review regression introduced in the preceding identity task. No assertion was
removed to suppress a numerical failure.

The remaining three notes are CRAN incoming/unpublished canonical URLs (404),
installed size (9.3 MB; native library 8.1 MB), and inability to verify current
time. The preceding six-note archive is preserved as history. The normal build
also retains its pre-existing automatic R >=3.5.0 dependency notice for the
unchanged version-3 serialized predecessor fixture; this is separate from the
zero-warning final R CMD check result.

No source archive is published and no frozen release packet is rewritten by this
standalone local check. The original historical serialization approval and patch,
numerical/predecessor evidence, provenance/rights, and sixteen pre-existing working
file hashes remain unchanged. No full-scale data or benchmark is used.

Implementation commits: `8d4d9c9` (routine cleanup), `fc92bb0` (single identity
refresh), `bc040dd` (complete repository documentation exclusions), and `c3bca33`
(archive-layout test corrections). The public-source policy has 675 exact
tracked-path dispositions. No shared R package was installed/upgraded. The
remaining provenance and historical serialization approval limitations are
unchanged, and the strict release gate still requires a note-free check and
publication authority.
