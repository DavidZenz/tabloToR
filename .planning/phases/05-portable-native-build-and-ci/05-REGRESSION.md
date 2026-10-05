# Phase 05 regression gate

Completed 2026-10-05 against a fresh disposable installation of the tracked package source at `a9c2361`, excluding generated native objects. The explicit temporary package library and exact Matrix library were asserted before testing. No user-library installation or main-checkout compilation occurred.

- R 4.3.0; exact Matrix 1.6.5 (declared source release 1.6-5).
- Serial native capability: OpenMP FALSE, maximum one thread.
- Seventeen existing test files referenced by Phase 01–04 verification reports were exercised through `testthat::test_package` against the installed namespace.
- Final result: **1,462 passes, zero failures, zero errors, 131 skips; exit 0**.
- Skips include source-only provenance, release/migration checks and unavailable external fixtures. This installed regression gate does not claim those skipped checks passed.
- Disposable source, explicit library, test list, original logs, saved results, CSV and summary: `/tmp/gemodelr-phase05-final-regression/`.

The initial temporary layout lacked three source-only benchmark producer scripts at the paths searched by the existing tests: 1,455 passes, seven missing-source assertions, zero errors, 131 skips. Its CSV writer then rejected a list column after saving the authoritative RDS. Both original results and logs remain retained. A source link in the disposable check layout made the unchanged tracked scripts discoverable; the report writer was corrected to serialize atomic columns. Reusing the same installed package, the full seventeen-file gate was rerun and passed. Neither repair changed package code or tests.

Separate hosted evidence covers modern R versions and platform/build variants. Final declared-metadata run `37277215498` passed all 24 supported tuples (26/26 successful jobs overall). Its informational full check still records nine existing serialization assertions, missing pdflatex and provisional-license findings; those findings remain tracked in `deferred-items.md` and are not represented as a clean full package check.

Final phase code review is clean across 29 changed implementation files. The evidence validator has 71 passing probes. Schema and UI gates found no blocking changes. The codebase-map drift check is advisory (`warn`, no requested mapper); the existing map predates these changes.
