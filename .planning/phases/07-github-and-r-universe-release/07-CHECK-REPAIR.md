# Local archive check repair

This is the maintainer-authorized repair of the ten installed-test failures from
the supported Matrix qualification. Phase 06 acceptance remains binding. All work
stays local; no publication, remote operation, or evidence adoption is authorized.

## Baseline and repair scope

The preceding frozen archive checked with Matrix 1.6-5: 1 ERROR, 2 WARNINGs,
7 NOTEs; testthat reported 3036 passes, 10 failures, 102 skips. The concrete
failures were four unavailable installed administrative tools, five preflight
source paths, and one assignment to a locked namespace binding. Missing qpdf and
undeclared withr use caused the warnings.

The repair makes source-only tests skip explicitly in installed contexts while
retaining their assertions in a separate fresh-process source-tool runner. A
missing tool in an actual checkout still fails. Serialization uses a scoped
testthat mock and checks restoration of the function and its lock state. Suggests
declares withr and the minimum testthat supporting that mocking API. The
qualification workflow installs actual qpdf/tidy and runs source-tool checks
separately. Public APIs, numerical implementation, and canonical evidence are
unchanged.

Running the old source groups against one installed namespace also reproduced
pre-existing source-only defects. The preflight script took its caller's
`--file` path; its lookup now prefers its own source frame and accepts only its
own CLI basename. Six focused preflight tests pass (20 assertions). The genuine
predecessor serialization test now passes 25 assertions in an installed context,
including restoration and all existing rejection/normalization checks.

Order validation exposed top-level fixture definitions that testthat can shuffle
after their callers. Baseline/preflight helpers now live in dedicated helper
files; the serialization snapshot helper also moved to its existing helper file.
The duplicate serialization field helper and fallback that sourced all R files
into the global environment were removed. Shuffled installed-context groups pass:
46 tests, 177 assertions, 27 explicit source-only skips, seed 709. The acceptance
and identity audit tools also resolve their own `sys.source()` frames instead of
the runner's relative `--file` argument; a focused regression checks their paths.

The baseline source run additionally reported eight migration-evidence errors
(seven in baseline-artifacts and one in serialization): reviewed identity counts
are stale, `package-mixed-case=420/328`. These exist in the untouched committed
source before this repair. This task does not rewrite reviewed mappings,
canonical baseline artifacts, provenance, rights, or rejected proposals to clear
them. The new source runner retains these failures; they cannot count as a pass.

## Reproduction and evidence

Baseline source copy and logs: `/tmp/GEModelR-check-repair-1jttZn`.
Supported Matrix library: `/tmp/GEModelR-release-runtime-PVoXZ7/library`.
Shared R library is unchanged. Local qpdf 8.4.0 and tidy 5.6.0 were extracted
under the repair directory, with SHA256 checked against APT metadata before use.
The existing Positron-bundled Pandoc is placed on PATH for the new check.

Use committed sources, not the unrelated dirty solver/native working files:

```sh
rtk node tools/release/prepare-release.cjs prepare --source-ref REPAIR_COMMIT --output NEW_PACKET --tag v0.1.0
rtk node tools/release/prepare-release.cjs stage-public-source --packet NEW_PACKET
rtk node tools/release/prepare-release.cjs qualify --packet NEW_PACKET --library SUPPORTED_DEPENDENCY_LIBRARY
rtk proxy Rscript --vanilla tools/ci/run-source-tool-tests.R SELECTED_SOURCE ARCHIVE_INSTALLED_LIBRARY
```

Set R_LIBS to the isolated Matrix library followed by existing read-only package
libraries; use OMP_NUM_THREADS=2, OPENBLAS_NUM_THREADS=1, MAKEFLAGS=-j2. Add actual
qpdf/tidy/Pandoc to PATH and the extracted tool libraries to LD_LIBRARY_PATH.
The packet CLI records archive checks; the separate source-runner log must remain
separate, without editing frozen packet manifests. No full-scale GTAP or R
baseline benchmark is part of this repair.

## Refreshed qualification

The first repair commit, `482e73be4305d445a1a80a9502ba052f60ff0f34`, built
and scanned successfully in `/tmp/GEModelR-check-repair-1jttZn/packet`.
Its actual `R CMD check --as-cran` finished with **0 errors, 0 warnings, 6 notes**;
testthat reported **3053 passes, 0 failures, 112 skips**, and tests took 202.092
seconds wall time (248 CPU seconds). Vignettes and PDF/HTML manual checks passed.
The separate installed numerical smoke passed. This is an intermediate candidate:
the final helper/order isolation changes require their own committed archive.
The packet's strict archive gate rejects notes, so gated smoke/URL steps correctly
remain not_run; an independent smoke pass does not override that state.

The original failed packet remains intact. The canonical guard's previously observed
PROVENANCE_KEY_MISMATCH and unpublished canonical URLs are independent blockers;
the installed numerical smoke alone cannot authorize publication.

### Final committed candidate (2026-10-26)

| Identity | Value |
|----------|-------|
| Packet | `/tmp/GEModelR-check-repair-1jttZn/final-packet` |
| Development source | `0ac93368be49b814998868b6fe56c9ad097a2e7f` |
| Development tree | `f0415116ec4f874718f7242db32c6f1f5584eb34` |
| Public/archive source | `382af3d087c5f545ce523cf52dfff475a2197e8b` |
| Public tree | `d22deb4414a67bc3756c4ae6b5ae1988b40e303e` |
| Archive size | 306101 bytes |
| Archive SHA-256 | `c4c0d237cb438e3330fa59d61dfa8204587b9f173a55179a426a9844ef41ced7` |
| Review content digest | `9e776314b8528ba7533fac415015e2ae59a5011a2efacc018b58e7a9674f0d77` |
| Private manifest SHA-256 | `ca8faae2376c748d828a55da51756ea679581c7b80ec0d5fd9f07d0efbd64132` |
| Public manifest SHA-256 | `4e56bf73805074762251c27316eade50e90565aa851b6230f1cdd50c52d3d2a9` |

Build, archive scan, installation, vignette rebuild, and PDF/HTML manual checks
passed. Final `R CMD check --as-cran`: **0 errors, 0 warnings, 6 notes**.
Testthat: **3053 passes, 0 failures, 113 skips**, zero warnings; 214.572 seconds
wall time (249.512 user + 9.674 system CPU seconds). The extra skip versus the
intermediate candidate is the new source-only administrative path regression.
No test assertions were removed to accommodate a numerical failure.

The six notes are incoming/new-submission information and four unpublished URLs
returning 404; installed size; unverifiable current time; the existing Author
versus Authors@R attribution comment; nonstandard top-level documentation/tool
paths; and `class(expr) == "name"`. Pandoc discovery and HTML validation now work,
and neither missing qpdf nor undeclared withr is reported. The release CLI still
requires exactly `Status: OK`, so `archive_check=failed` is the correct strict
qualification disposition even though the package's tests have no failures.

The final fresh-process numerical smoke passes against the package installed by
this final archive check, Matrix 1.6-5, with expected solution `(0, 6, 0)` within
1e-12. Its separate result does not overwrite gated `installed_smoke=not_run` or
URL `not_run` in the packet. Offline guard again reports invalid/exit 1 with
`PROVENANCE_KEY_MISMATCH`. Local packet verification passes; publication
verification fails with `PUBLICATION_NOT_READY`.

The final separate source-tool run uses an independent copy of the selected
commit and the final archive-installed namespace. All six preflight tests pass;
the baseline-tool group has seven errors, all the same pre-existing reviewed
identity count mismatch, and no skips. The source-only serialization migration
gate's eighth mismatch was reproduced in the baseline run. Neither source result
is represented as a passing migration or release gate. No accepted evidence was
regenerated/adopted.

Raw final logs are `logs/final-qualification.log`,
`logs/final-source-tool-tests.log`, and
`logs/final-independent-installed-smoke.log` under the repair directory. The
packet retains raw check evidence in `private/evidence` and `private/work/check`.
The shuffled focused result is `logs/shuffled-installed-final.log`: 177 passes,
27 source-only skips, no failures. Packet/scanner tests: 38/38 passed; release
tool/scanner code is unchanged. R syntax and whitespace checks pass.

Commits `482e73b` and `0ac9336` contain the repairs. Their committed diff changes
no `R/`, `src/`, or `inst/cpp/` implementation. Sixteen pre-existing working files
match their earlier SHA256 hashes. Shared Matrix remains 1.6-3; isolated Matrix
is 1.6-5. Earlier packets remain intact. No benchmark, hosted job, push, tag,
publication, external setting, or canonical evidence update occurred. Phase 06
remains accepted; Plan 07-04/REL-02 and the keep-local boundary remain pending.
