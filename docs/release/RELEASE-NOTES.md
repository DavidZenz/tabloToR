# GEModelR 0.1.0 development candidate

Status: draft for maintainer review; publication and release qualification are pending.
Proposed tag: `v0.1.0` (annotated, unsigned).

GEModelR interprets GEMPACK-style TABLO models in R and provides legacy and sparse solver paths. This candidate is intended for an initial public validation period. Version `0.1.0` currently remains a development version; these notes do not establish a published release or a stability guarantee.

## Installation and migration

The proposed distribution channels are the canonical `DavidZenz/GEModelR` Git repository at tag `v0.1.0` and the `davidzenz` R-universe, pinned to that tag. Neither channel is verified as published for this candidate. Installation instructions will become release instructions only after the tag, retained source archive, and both installed smoke results are recorded.

Existing users should follow `MIGRATION.md`: replace the package namespace with `GEModelR`, retain the `GEModel` facade, and migrate supported options and saved logical state explicitly. No predecessor shim, automatic uninstall, or startup option scan is provided. Raw predecessor ReferenceClass RDS objects require the documented predecessor bridge before the package migration.

## Solver behavior and platforms

- The default engine remains `legacy`; the sparse engine remains opt-in and its default backend is `Matrix`.
- The structured C++ backend is optional. Backend availability and OpenMP capability depend on the installed build; native acceleration is not a new default.
- Solver acceptance continues to require the package's documented finiteness and true-residual checks. This release preparation changes no numerical tolerances or public solver signatures.
- The declared dependency floor is `Matrix >= 1.6-5`. A clean exact-archive check and installed serialization verification under a supported R/Matrix combination remain unverified for this candidate.
- Hosted Windows provenance regression evidence remains unavailable. Workflow definitions and earlier platform observations do not substitute for a current candidate result.

## Benchmark evidence and known limitations

Existing C++ shock and thread-scaling measurements are diagnostic evidence. Component timings, factor-reuse prototypes, and thread-scaling results are not guaranteed package-wide or end-to-end GTAP speedups. A current matched full-scale R/C++ comparison and independent acceptance review remain unqualified for this candidate. No new R reference benchmark was run during release preparation.

The external benchmark preflight has two known tooling limitations: invalid build-record fields can enter its report, and an eligible reference set is not bound to later benchmark stages by a file manifest. Do not treat a preflight report alone as publication-grade numerical evidence. Proprietary model inputs, full solutions, raw measurements, and private evidence are not distributed with the proposed release.

Public release remains subject to dependency compatibility, attribution/provenance, name availability, and technical qualification review. The current provenance mismatch is unresolved. No unavailable or waived check is represented here as passing.

## License, credit, and support

The selected package license is GPL-3.0-or-later (`GPL (>= 3)` in package metadata). Existing upstream credit for Maros Ivanic and current maintainer credit are retained. Use `citation("GEModelR")` for the package citation.

The proposed issue tracker is `https://github.com/DavidZenz/GEModelR/issues`; private security reports go to `zenz@wiiw.ac.at`. During initial public validation, the proposed cadence is weekly issue triage when maintainer capacity permits and patch releases grouped monthly or sooner for correctness fixes. This is a proposed working cadence, not a guaranteed response or release schedule.
