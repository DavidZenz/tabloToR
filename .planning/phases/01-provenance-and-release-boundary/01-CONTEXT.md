# Phase 1: Provenance and Release Boundary - Context

**Gathered:** 2026-08-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish an auditable legal, attribution, naming, ownership, and governance basis for GEModelR, and define an enforceable boundary around public distribution. This phase produces decisions, inventories, requests, and release gates. It does not rename the package, alter solver behavior, or publish GEModelR.

</domain>

<decisions>
## Implementation Decisions

### Rights-clearance path

- **D-01:** Ask upstream to add an explicit open-source license and confirm that the fork may continue under the GEModelR name.
- **D-02:** If upstream does not respond or cannot provide adequate rights, investigate replacing every inherited expression with independently implemented equivalents.
- **D-03:** Begin the provenance and replacement audit immediately, in parallel with the upstream license request; do not wait for a response deadline.
- **D-04:** Any replacement must follow a strict clean-room process: behavior-only specifications and independent implementers who do not inspect inherited source.
- **D-05:** Public distribution remains blocked until a written license/permission record covers inherited source or the clean-room replacement path is complete and reviewed.

### Attribution model

- **D-06:** Assign `aut`, `ctb`, `cph`, and `cre` roles from verified contribution and ownership evidence rather than assumptions.
- **D-07:** Record provenance at function level for inherited or substantially modified code, with file-level classification for wholly new files.
- **D-08:** Put upstream attribution in `DESCRIPTION`, `README.md`, `CITATION`, the provenance inventory, and `NEWS.md`.
- **D-09:** Record future substantive contributors in `Authors@R` and a contributor record; credit release-relevant work in `NEWS.md`.

### Ownership and governance

- **D-10:** Host the canonical GEModelR repository under David Zenz's personal GitHub account for v1.
- **D-11:** David Zenz is the sole v1 package maintainer and release authority; contributions are accepted through pull requests.
- **D-12:** Protect `main` and require passing CI before merge. During the single-maintainer stage, the maintainer may self-review and merge.
- **D-13:** Add `GOVERNANCE.md` before public release, covering maintainer authority, adding maintainers, succession, and security-reporting responsibility.

### Name and release boundary

- **D-14:** Use the exact name `GEModelR` for both the R package and canonical GitHub repository.
- **D-15:** Make documented name availability a release gate. Check R package-name validity plus current and historical CRAN and Bioconductor records, R-universe, and GitHub before reservation and release.
- **D-16:** Continue development privately while redistribution rights remain unresolved. Verify GitHub fork-visibility constraints and use a private standalone repository if the fork cannot be made private.
- **D-17:** Until clearance, the upstream licensing request is the only public project artifact. Do not publish GEModelR source, binaries, a documentation site, release tags, package archives, or an R-universe channel.

### the agent's Discretion

- Choose the machine-readable format and supporting tools for the provenance inventory.
- Organize the license-request evidence, governance records, and release-gate checklist.
- Choose the repository migration mechanism that preserves useful history while enforcing the private-development boundary.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and phase scope

- `.planning/PROJECT.md` — Defines GEModelR's product direction, compatibility commitments, constraints, and release intent.
- `.planning/REQUIREMENTS.md` — Defines PROV-01 through PROV-04 and the public-release restrictions.
- `.planning/ROADMAP.md` — Defines the Phase 1 goal, release gate, success criteria, and downstream phase boundaries.

### Research and repository evidence

- `.planning/research/PITFALLS.md` — Records the missing-license risk and legal/release failure modes.
- `.planning/research/SUMMARY.md` — Summarizes the recommended productization sequence and release strategy.
- `.planning/codebase/CONCERNS.md` — Identifies placeholder metadata, inherited identity, experimental sources, and other release blockers.
- `DESCRIPTION` — Current package identity, author, maintainer, and license metadata that must be audited.
- `README.md` — Current public narrative and workflow where predecessor attribution and the future migration notice must appear.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- Git history and upstream comparison: provide file/function history for the provenance inventory, subject to manual verification where code was substantially rewritten.
- Existing package metadata and documentation: provide concrete locations for maintainer, license, citation, URL, and attribution changes after clearance.
- `.planning/research/PITFALLS.md`: already captures authoritative licensing and package-release policy sources for the legal/release checklist.

### Established Patterns

- The package remains named `tabloToR` throughout metadata, R code, native symbols, benchmarks, and documentation; Phase 1 records the boundary but does not perform that coordinated rename.
- Solver research includes new R and C++ work, but the proportion of new code must be established by function-level evidence rather than an aggregate estimate.
- Full-scale GTAP inputs are proprietary and external; provenance and public artifacts must not include private model data.

### Integration Points

- `DESCRIPTION`: verified `Authors@R`, maintainer contact, license, URL, and BugReports fields.
- `README.md`, `CITATION`, and `NEWS.md`: predecessor attribution and transition narrative.
- Repository settings: visibility, canonical URL, issue tracker, branch protection, and CI merge gate.
- New provenance inventory and `GOVERNANCE.md`: durable ownership and decision records.

</code_context>

<specifics>
## Specific Ideas

- The upstream issue should request an explicit open-source license, permission to modify and redistribute the existing source, and confirmation that the successor may use the GEModelR name with attribution.
- Upstream should choose or approve the applicable license; GEModelR must not unilaterally assign a license to inherited code.
- The working estimate that roughly 90% of the code is new is a hypothesis for the function-level audit, not a rights-clearance conclusion.
- If replacement is needed, keep behavior specifications and implementation work separated so clean-room independence can be demonstrated.
- If GitHub does not permit an independently private fork within the public fork network, create a private standalone development repository while retaining an auditable history and upstream reference.

</specifics>

<deferred>
## Deferred Ideas

- Compatibility and numerical baselines belong to Phase 2.
- Package/native identity migration belongs to Phase 3.
- Public API and backend-boundary cleanup belongs to Phase 4.
- Cross-platform native build and CI work belongs to Phase 5.
- User documentation, release qualification, and public publication belong to Phases 6 and 7.

</deferred>

---

*Phase: 1-Provenance and Release Boundary*
*Context gathered: 2026-08-22*
