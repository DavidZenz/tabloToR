---
phase: 07-github-and-r-universe-release
source: existing_session_decisions
captured: 2026-10-23
---

# Phase 07 context

This record carries forward decisions already made in the session. It does not represent a new discuss-phase interview. The maintainer selected advancement to Phase 07 planning after accepting Phase 06 completion.

## Locked decisions

- Phase 06 is complete by explicit maintainer acceptance. Honor `../06-documentation-and-release-qualification/06-ACCEPTANCE.md`; retain its known limitations without creating another Phase 06 gap, UAT, benchmark, or security-review cycle.
- Keep current work local. Planning and reversible local release preparation are authorized. A remote push, hosted dispatch, repository/settings change, tag publication, public release, Pages deployment, or R-universe publication requires authorization for the concrete prepared result.
- Complete the useful local preparation before requesting approval of an external action. Do not stop at the start of the phase solely because later publication is not yet authorized.
- GPL-3.0-or-later is selected. Preserve the approved package identity, public API, numerical behavior, solver tolerances, and canonical historical/provenance records.
- No R baseline rerun or proprietary GTAP data publication. Preserve existing benchmark evidence and accurately describe unavailable checks and known limitations.
- Preserve the existing unrelated dirty solver/native/benchmark files. Scope release preparation to a deliberate source revision; do not stage the entire working tree.

## Phase scope

Plan how to prepare, review, and eventually publish the first installable GEModelR release through its canonical Git repository and R-universe. Include installation and redistributable smoke verification, compatibility/platform notes, known limitations and migration instructions, and a practical support/issue/release cadence.

The accepted Phase 06 disposition does not grant public release authority or declare its unperformed checks successful. Existing release guards remain applicable at publication. Explain their current disposition in the local handoff; do not reopen the completed phase automatically.

## Implementation discretion

Reuse existing release tooling, workflows, documentation, identity records, and artifact scans. Research current official integration documentation where needed. Keep the plan bounded and executable; use one concrete approval checkpoint for external publication after local preparation is reviewable. Do not create repetitive evidence-only plans for the same accepted limitations.
