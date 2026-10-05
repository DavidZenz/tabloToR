# Hosted compatibility evidence

The candidate run [37273713572, attempt 1](https://github.com/DavidZenz/tabloToR/actions/runs/37273713572) tested all 30 original tuples at commit `98e626aaad0824db07a2012ed1cacfbcaef74a22`: 24 source installs and installed solver contracts passed, and six exact Matrix 1.6-5 source installs failed. `matrix-candidate-evidence.csv` merges its authentic row artifacts without substituting local or synthetic results. All five oldrel-1 / Matrix 1.6-5 OS/build pairs passed with resolved R 4.5.3. Matrix remains a provisional floor until Plan 05-07 validates this evidence.

## Proven source incompatibilities

All exclusions are for `candidate_label=minimum`, `matrix_version=1.6-5`, run `37273713572`, attempt `1`. Each row retains source result `failure` and solver result `not_run`; the package was never installed against a substitute Matrix version.

| R alias | Resolved R | OS/build | Job ID | Exact source failure |
| --- | --- | --- | --- | --- |
| release | 4.6.1 | Windows/openmp | 111646015673 | `Mdefines.h:210:14: error: implicit declaration of function 'OBJECT'` |
| release | 4.6.1 | Windows/serial | 111646015759 | `Mdefines.h:210:14: error: implicit declaration of function 'OBJECT'` |
| devel | 4.7.0 | Windows/openmp | 111646015685 | `Mdefines.h:210:14: error: implicit declaration of function 'OBJECT'` |
| devel | 4.7.0 | Windows/serial | 111646015718 | `Mdefines.h:210:14: error: implicit declaration of function 'OBJECT'` |
| release | 4.6.1 | macOS/serial | 111646015737 | `Csparse.c:288:3: error: call to undeclared function 'OBJECT'; ISO C99 and later do not support implicit function declarations` |
| devel | 4.7.0 | macOS/serial | 111646015756 | `Csparse.c:288:3: error: call to undeclared function 'OBJECT'; ISO C99 and later do not support implicit function declarations` |

These are tuple-specific exact-source failures. Linux release/devel Matrix 1.6-5 passed and remains included. The supported workflow excludes only the six rows above, retains all five oldrel-1 minimum rows, and keeps every current Matrix 1.7-6 row.

## Retained earlier attempts

- Run `37273246073`, attempt 1, commit `99faa571ecb17a413eef1d5194164f3718ccbde6`, was rejected before jobs: `runner.temp` was not available in job-level environment expressions. Commit `1dd2c06` moves those paths into step environment/GITHUB_ENV. There are no candidate results for that rejected run.
- Run [37273389483, attempt 1](https://github.com/DavidZenz/tabloToR/actions/runs/37273389483), commit `1dd2c06376c3f512969895bef3c58336a89d545e`, retained all 30 rows: 20 passed, 10 failed. macOS source builds lacked `libintl.h`; commit `98e626a` supplies gettext headers/library flags in the disposable hosted Makevars. Those setup failures are retained separately and do not justify compatibility exclusions.
- Each successful and failed candidate has raw source-install logs, CSV and job summary in its immutable run/attempt artifact. Successful installed contracts additionally have package-install and installed-core-test logs. API artifact IDs, digests, job IDs/step outcomes and SHA-256 hashes of extracted files are recorded in `hosted-evidence/hosted-run-<run>-1.json`.
- Complete downloads remain under `/tmp/gemodelr-hosted-<run>/artifacts-final/`. Native build archives and check directories remain outside version control. Remote artifacts currently expire after 30 days; the manifests record actual expiration times.

## Representative full check

Both candidate runs preserve an independent Linux/release/current-Matrix/serial check at R 4.6.1 / Matrix 1.7.6. Original exit status is **1**: **1,868 passes, nine failures, 164 skips, two ERRORs, two WARNINGs, one NOTE**. Their report copies are in `hosted-evidence/representative-check-<run>-1.md`; raw check/build logs, status, source archive and complete check directory remain in each downloadable representative artifact and local download.

The nine test failures involve untouched predecessor serialization fixtures and leaf metadata (`test-model-serialization.R:688`; `test-serialization-leaf-types.R:269,272,278,282,291,413`). The manual fails in the hosted LaTeX environment, and DESCRIPTION's provisional license is reported separately. These informational findings do not gate the installed core matrix and have not been repaired or represented as resolved by Phase 05.

Each report separately preserves the exact inherited Phase 04 baseline: **2,364 passes, 19 failures, 65 skips, one ERROR, four WARNINGs, four NOTEs**. Different R/Matrix and packaged/source contexts prevent attributing count differences to Phase 05 fixes.
