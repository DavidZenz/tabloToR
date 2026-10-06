# Release Preparation Checklist

This checklist is repository-only. It records evidence to review and actions
that require separate authorization; completing a technical check does not
authorize a tag, repository change, release, or publication.

## Current blocked-state check

- [x] Run `Rscript --vanilla tools/check_release_gates.R --assert-blocked`
  (validated 2026-10-06; result: `repository_state=blocked`, with all evidence
  parsers passing and exactly the two blockers below).
  This is an intentional current-state assertion: it passes only when the
  evidence parsers pass and the exact blockers remain
  `DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and
  `ATTRIBUTION_IDENTITY_UNRESOLVED`. A passing assertion confirms the blocked
  state; it does not clear either blocker.

## Technical and evidence review

- [ ] Build and inspect the exact source archive with `R CMD build .` and
  `node tools/ci/check-public-content.cjs --archive GEModelR_0.1.0.tar.gz`;
  after the release gates allow qualification, run
  `R CMD check GEModelR_0.1.0.tar.gz`. See
  [the source archive gate](RELEASE-GATES.md#command-contracts).
- [ ] Complete the dependency compatibility and package-license review in
  [Release Gates](RELEASE-GATES.md#package-license) and
  [Rights and Redistribution Status](../provenance/RIGHTS.md). Keep the
  dependency blocker until the audit and authoritative license decision are
  recorded; do not substitute the provisional Apache-2.0 basis.
- [ ] Resolve the Git identity alias through the reviewed attribution process
  in [the attribution contract](../provenance/ATTRIBUTION.md#blocking-facts).
  Preserve the exact reviewed people, roles, and evidence keys across
  `DESCRIPTION`, `README.md`, `NEWS.md`, and `inst/CITATION`.
- [ ] Immediately before repository reservation or release, refresh name
  evidence and review [the name-check record](NAME-CHECK.md). Run
  `Rscript --vanilla tools/check_name_availability.R --name GEModelR --output docs/release/NAME-CHECK.md --check-kind release`.
  A prior initial report is not current release evidence.
- [ ] Require a current result that passes
  [`benchmarks/check_benchmark_gate.R`](../../benchmarks/check_benchmark_gate.R)
  and verify its detached signature with
  `gpg --verify benchmarks/GTAP12A_CPP_RESULTS.md.asc benchmarks/GTAP12A_CPP_RESULTS.md`.
  Check the signer fingerprint and trusted-key source in the
  [benchmark evidence procedure](BENCHMARK-EVIDENCE.md). The checked-in result
  is historical; it does not satisfy the current full-scale benchmark
  requirement by itself.
- [ ] Compare the development heading and release boundary in
  [`NEWS.md`](../../NEWS.md) and [`inst/CITATION`](../../inst/CITATION) with
  [`DESCRIPTION`](../../DESCRIPTION) and the reviewed
  [attribution contract](../provenance/ATTRIBUTION.md). Citation and NEWS
  text do not grant redistribution rights.

## Separately authorized external actions

- [ ] Follow [the repository identity and private-development boundary](REPOSITORY.md)
  before any reservation, visibility, detachment, mirror, remote, branch, or CI
  settings change. Each action requires its own approval.
- [ ] Keep release tags, GitHub releases, public source and archives, a deployed
  documentation site, and R-universe publication in Phase 7. Before any such
  action, rerun the release gate and obtain separate authorization for the
  exact commit, tag, artifact, visibility, and destination. This checklist
  grants no such authority.

Detailed release and provenance evidence remains outside pkgdown navigation
and source archives.
