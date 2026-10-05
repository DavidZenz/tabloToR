# Matrix floor evidence

Selected floor: 1.6-5
Current endpoint: 1.7-6
Resolved oldrel-1 R: 4.5.3
Selected archive: https://cran.r-project.org/src/contrib/Archive/Matrix/Matrix_1.6-5.tar.gz
Current source: https://cran.r-project.org/src/contrib/Matrix_1.7-6.tar.gz
Input CSV: matrix-candidate-evidence.csv
Supported CSV: hosted-evidence/matrix-candidate-evidence-37277215498-1.csv
History CSV: none
Catalog snapshot: hosted-evidence/cran-catalog/snapshot.dcf
Catalog MD5: 4f62fa460ac7631ce6c8fb10d4ea4908
Catalog collected at: 2026-10-05T07:42:48Z
Input MD5: caea8d87ebaa570fe92de20a2265ca52
Supported MD5: 68dafceaeafa81364adca27c1ba80c2b
Full supported run: 37277215498 (attempt 1)

## Five required oldrel-1 results

| setup_r_alias | resolved_r_version | os | build_mode | candidate_label | matrix_version | source_install_result | solver_test_result | run_id |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| oldrel-1 | 4.5.3 | Linux | openmp | minimum | 1.6-5 | success | success | 37273713572 |
| oldrel-1 | 4.5.3 | Linux | serial | minimum | 1.6-5 | success | success | 37273713572 |
| oldrel-1 | 4.5.3 | Windows | openmp | minimum | 1.6-5 | success | success | 37273713572 |
| oldrel-1 | 4.5.3 | Windows | serial | minimum | 1.6-5 | success | success | 37273713572 |
| oldrel-1 | 4.5.3 | macOS | serial | minimum | 1.6-5 | success | success | 37273713572 |

## Fallback history

None: provisional 1.6-5 passed all five required pairings; no successor was tested or substituted.

## Full supported matrix

| setup_r_alias | resolved_r_version | os | build_mode | candidate_label | matrix_version | source_install_result | solver_test_result | run_id |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| devel | 4.7.0 | Linux | openmp | current | 1.7-6 | success | success | 37277215498 |
| devel | 4.7.0 | Linux | serial | current | 1.7-6 | success | success | 37277215498 |
| devel | 4.7.0 | Windows | openmp | current | 1.7-6 | success | success | 37277215498 |
| devel | 4.7.0 | Windows | serial | current | 1.7-6 | success | success | 37277215498 |
| devel | 4.7.0 | macOS | serial | current | 1.7-6 | success | success | 37277215498 |
| devel | 4.7.0 | Linux | openmp | minimum | 1.6-5 | success | success | 37277215498 |
| devel | 4.7.0 | Linux | serial | minimum | 1.6-5 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Linux | openmp | current | 1.7-6 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Linux | serial | current | 1.7-6 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Windows | openmp | current | 1.7-6 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Windows | serial | current | 1.7-6 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | macOS | serial | current | 1.7-6 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Linux | openmp | minimum | 1.6-5 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Linux | serial | minimum | 1.6-5 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Windows | openmp | minimum | 1.6-5 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | Windows | serial | minimum | 1.6-5 | success | success | 37277215498 |
| oldrel-1 | 4.5.3 | macOS | serial | minimum | 1.6-5 | success | success | 37277215498 |
| release | 4.6.1 | Linux | openmp | current | 1.7-6 | success | success | 37277215498 |
| release | 4.6.1 | Linux | serial | current | 1.7-6 | success | success | 37277215498 |
| release | 4.6.1 | Windows | openmp | current | 1.7-6 | success | success | 37277215498 |
| release | 4.6.1 | Windows | serial | current | 1.7-6 | success | success | 37277215498 |
| release | 4.6.1 | macOS | serial | current | 1.7-6 | success | success | 37277215498 |
| release | 4.6.1 | Linux | openmp | minimum | 1.6-5 | success | success | 37277215498 |
| release | 4.6.1 | Linux | serial | minimum | 1.6-5 | success | success | 37277215498 |

## Individually evidenced exclusions

| setup_r_alias | resolved_r_version | os | build_mode | candidate_label | matrix_version | source_install_result | solver_test_result | run_id | failure_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| release | 4.6.1 | macOS | serial | minimum | 1.6-5 | failure | not_run | 37273713572 | Csparse.c:288:3: error: call to undeclared function 'OBJECT'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration] |
| devel | 4.7.0 | macOS | serial | minimum | 1.6-5 | failure | not_run | 37273713572 | Csparse.c:288:3: error: call to undeclared function 'OBJECT'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration] |
| release | 4.6.1 | Windows | serial | minimum | 1.6-5 | failure | not_run | 37273713572 | Mdefines.h:210:14: error: implicit declaration of function 'OBJECT' [-Wimplicit-function-declaration] |
| devel | 4.7.0 | Windows | serial | minimum | 1.6-5 | failure | not_run | 37273713572 | Mdefines.h:210:14: error: implicit declaration of function 'OBJECT' [-Wimplicit-function-declaration] |
| release | 4.6.1 | Windows | openmp | minimum | 1.6-5 | failure | not_run | 37273713572 | Mdefines.h:210:14: error: implicit declaration of function 'OBJECT' [-Wimplicit-function-declaration] |
| devel | 4.7.0 | Windows | openmp | minimum | 1.6-5 | failure | not_run | 37273713572 | Mdefines.h:210:14: error: implicit declaration of function 'OBJECT' [-Wimplicit-function-declaration] |

The excluded tuples failed exact Matrix source installation for the individually checked reasons above; solver tests did not run.
Original JSON manifests, checked normalized job/artifact provenance, exact CSV payloads and failed-source logs are retained in hosted-evidence/.
See HOSTED-COMPATIBILITY.md for the exact compiler errors, prior attempts and independent informational full-check findings.
This evidence establishes endpoint compatibility on valid tuples; it does not claim every R/Matrix/platform cross-product installs.

