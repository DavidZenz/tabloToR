# API Coverage — Phase 1 Name and Repository Evidence

> Full coverage by default. Opt-outs are explicit, reasoned decisions. The matrix covers every external capability used or deliberately excluded by the Phase 1 name-availability contract.

| capability | decision | reason |
|---|---|---|
| r-package-name-syntax-local | INTEGRATE | |
| cran-current-package-index | INTEGRATE | |
| cran-archive-package-index | INTEGRATE | |
| bioconductor-current-release-discovery | INTEGRATE | |
| bioconductor-current-all-advertised-repositories | INTEGRATE | |
| bioconductor-historical-release-discovery | INTEGRATE | |
| bioconductor-historical-all-advertised-repositories | INTEGRATE | |
| r-universe-search-complete-result-set | INTEGRATE | |
| github-repository-search-complete-pagination | INTEGRATE | |
| source-query-identity-and-raw-response-hash | INTEGRATE | |
| source-count-cardinality-and-completeness-validation | INTEGRATE | |
| github-authenticated-private-repository-search | OPT-OUT | D-15 requires public package and repository collision evidence; credentials and private repository discovery are outside this phase and prohibited from evidence artifacts. |
| github-repository-create-reserve-rename-delete | OPT-OUT | D-16 and D-17 prohibit repository mutation or reservation during this phase. |
| github-repository-settings-visibility-branch-protection | OPT-OUT | D-12 records the target policy, while D-16 and D-17 require a separate future human-authorized external action. |
| cran-submission-and-incoming-queue | OPT-OUT | Immediate CRAN submission is explicitly out of scope; Phase 1 reads public current and archive name evidence only. |
| bioconductor-package-submission | OPT-OUT | PROV-03 requires name discovery across published current and historical repositories, not submission. |
| r-universe-channel-publication | OPT-OUT | D-17 prohibits R-universe publication until the release boundary is cleared. |
| trademark-register-search-or-clearance | OPT-OUT | D-15 defines point-in-time exact package and repository collision evidence and explicitly does not claim trademark clearance. |
| non-github-code-forge-search | OPT-OUT | D-15 names GitHub as the repository search surface; no GitLab, Bitbucket, or other forge integration is planned for Phase 1. |

## Integration contract

Every INTEGRATE row must have all four links in Plan 01-08: a collector or local validator in `tools/check_name_availability.R`, deterministic offline regression coverage in `tests/testthat/test-name-availability.R`, a complete `Source-Detail` or local-validation record in `docs/release/NAME-CHECK.md`, and fail-closed consumption by the integrated release gate in Plan 01-07.

Bioconductor repository coverage is manifest-driven. “All advertised repositories” includes software, annotation, experiment, workflows, books, and any additional installable repository advertised by each applicable current or historical release; it is not a fixed allow-list that may silently omit a newly advertised repository.

The GitHub and R-universe search capabilities include exhaustive bounded pagination, stable query identity, declared-versus-returned count agreement, completeness flags, raw response hashes, case-insensitive ASCII exact-name matching, and explicit failure for unavailable, malformed, semantically empty, repeated, or truncated responses.

The OPT-OUT rows are scope fences, not permissions for partial source coverage. Any future phase that adds one of those capabilities must revise this durable subtraction record before verification.
