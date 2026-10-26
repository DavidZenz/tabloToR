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

Pending the committed repair candidate's actual archive check. The original
failed packet remains intact. The canonical guard's previously observed
PROVENANCE_KEY_MISMATCH and unpublished canonical URLs are independent blockers;
the installed numerical smoke alone cannot authorize publication.
