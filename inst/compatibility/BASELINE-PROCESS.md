# Phase 02 Baseline Process

Phase 02 baselines are compact, reviewable compatibility and numerical evidence.
Ordinary tests and proposal refreshes are read-only with respect to the canonical
directory at `tests/testthat/baselines/phase02`. Only the reviewed acceptance
command may replace canonical artifacts.

## Artifact boundary

The stable canonical set is `expectations.csv`, `tolerances.csv`, and
`fingerprints.dcf`. It records selected transparent values, exact structures,
fixture and approved source identities, package/model signatures, and the
fixture-conditioning tolerance policy. Generated baselines and proposals are
excluded from the source fingerprint so the fingerprint is not recursive.

Each proposal also contains `run-metadata.dcf`, `proposal.dcf`, and `DIFF.md`.
Run metadata is deliberately volatile and separate: it records R and dependency
versions, platform, CPU, physical RAM, BLAS, elapsed time, peak RSS, and solver
metadata. `proposal.dcf` hashes only the stable artifacts. `DIFF.md` compares
stable old/new values by artifact and key, so two unchanged runs produce the
same review diff even though volatile execution metadata changes.

Full solutions are regenerated in memory and reduced to the committed selected
values and structural records. No solved-model RDS, full solution, private model,
or proprietary input belongs in a proposal or canonical baseline.

## Propose and check

Create a new proposal beneath an explicit directory whose parent already exists:

```sh
rtk Rscript --vanilla tools/refresh_phase02_baselines.R \
  --output=.planning/phases/02-compatibility-and-numerical-baseline/02-06-baseline-proposal
```

The refresh tool rejects the canonical directory and any path that overlaps it,
rejects symbolic-link artifacts, bounds source inputs and generated outputs, and
writes only beneath the selected proposal root. It never accepts a proposal.

Check canonical drift without changing canonical files:

```sh
rtk Rscript --vanilla tools/refresh_phase02_baselines.R --check
```

Missing, stale, or corrupt stable artifacts make the check fail and print the
key-based old/new diff. Ordinary tests exercise the same read-only boundary and
never honor an environment variable or snapshot-update switch.

## Review and accept

Review all six proposal files. Confirm the source/fixture/model signatures,
selected values, tolerance tier, environment metadata, and every row in
`DIFF.md`. Then run the sole canonical mutator with a named reviewer and a
substantive reason:

```sh
rtk Rscript --vanilla tools/accept_phase02_baselines.R \
  --proposal=.planning/phases/02-compatibility-and-numerical-baseline/02-06-baseline-proposal \
  --reviewer="Reviewer Name" \
  --reason="Reviewed Phase 02 compatibility and numerical evidence"
```

Use `--dry-run` first when desired. Acceptance revalidates regular files, size
bounds, the proposal manifest/hash, and the exact diff against the current
canonical set. It stages and verifies all stable artifacts before replacement,
keeps rollback copies during the operation, and writes `ACCEPTANCE.md` with the
reviewer, reason, UTC date, proposal hash, old/new canonical hashes, fixture and
source identities, and tolerance tier.

No environment flag, ordinary test, or refresh invocation can accept a proposal.
A stale proposal must be regenerated and reviewed again.

## External benchmark evidence

The canonical fingerprint records the reviewable external benchmark report at
`benchmarks/GTAP12A_CPP_RESULTS.md`, not its underlying model/data paths or full
solutions. Reduced and full GTAP evidence remains an external benchmark/release
gate. It is not run by ordinary package checks and proprietary GTAP/HAR inputs
must never be copied into the package, proposal, or test fixture directories.

## Integrated Phase 02 gate

After reviewed acceptance, run the documented-workflow, compatibility-manifest,
numerical-baseline, transactional-state, model-serialization,
baseline-artifacts, public-solver-contract, public-cpp-backend, sparse-core, and
sparse-cpp-cache filters; then run the read-only baseline check and `rtk R CMD
check .`. Required capabilities must execute. Optional capabilities must report
their explicit tested skip reason. `WF-UNCLASSIFIED` remains visibly
`FLAGGED-UNVERIFIED` until a documented workflow branch and executable test are
added; it must not be hidden or silently treated as covered.
