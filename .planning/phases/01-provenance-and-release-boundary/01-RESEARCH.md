# Phase 1: Provenance and Release Boundary - Research

**Researched:** 2026-08-24
**Scope:** PROV-01, PROV-02, PROV-03, PROV-04
**Confidence:** High for repository/package mechanics; legal conclusions require the relevant rights holders or qualified counsel.

## Summary

Phase 1 should build an evidence system, not merely select a license label. The upstream repository has no explicit license and its `DESCRIPTION` still contains placeholder author, maintainer, and license values. GitHub states that absent a license, default copyright restrictions apply; the platform permission to view and fork public content does not itself grant general derivative redistribution rights. GEModelR therefore needs either written upstream permission/license covering inherited expression or a completed, independently reviewed clean-room replacement before public distribution.

The phase can finish while that external response is pending if it produces an explicit blocked release status, a complete function-level provenance inventory, and an approved clean-room fallback. Private technical work may continue, but releases, package archives, R-universe publication, public documentation sites, and claims of redistributability stay blocked.

GitHub also states that a public fork cannot change visibility independently from its public fork network. The practical private path is to detach the fork into a standalone repository, or mirror the history into a new private standalone repository. Detaching preserves Git commits but not repository metadata such as issues, pull requests, stars, or watchers, so these must be inventoried before any external action.

## Planning Implications

### Rights evidence and release status

- Create `docs/provenance/RIGHTS.md` as the canonical status record. It should identify the upstream repository and commit, the request URL/date, contacted rights holders, the exact grant/license received, scope, evidence links or hashes, reviewer, and one machine-readable status: `blocked`, `cleared`, or `clean-room-required`.
- Create `docs/provenance/UPSTREAM-REQUEST.md` as a reviewable request draft. Posting it is an external checkpoint, not an autonomous task.
- Create `docs/release/RELEASE-GATES.md` with fail-closed gates. Public release must fail unless rights are `cleared`, or every inherited function is replaced under the documented clean-room process and independently reviewed.
- Do not add a package `LICENSE` or change `DESCRIPTION` to a chosen license until the applicable rights basis is established. R requires the `License` field to describe the actual package license, and CRAN requires ownership and rights for every component to be clear.

### Function-level provenance audit

- Create `docs/provenance/PROVENANCE.csv` with one row per top-level R function and per inherited/substantially modified native function. Wholly new files may use one file-level row.
- Required columns: `path`, `symbol`, `language`, `classification`, `upstream_repository`, `upstream_commit`, `upstream_path`, `first_local_commit`, `expression_hash`, `contributors`, `copyright_holder`, `license_basis`, `evidence`, `reviewer`, `review_date`, `status`, `notes`.
- Allowed classifications should be fixed: `inherited-identical`, `inherited-modified`, `new-independent`, `generated`, `third-party`, and `unknown`. Any `unknown`, missing holder, or missing license basis blocks redistribution.
- Add `tools/provenance_inventory.R` to extract top-level R symbols, source ranges, normalized expression hashes, and Git evidence. Generated files such as `RcppExports` must point to their generator/source rather than being treated as independent authorship.
- Git history, blame, and textual similarity are audit evidence, not proof of copyright ownership or independent creation. Mixed-origin functions require manual review.

### Strict clean-room fallback

- Create `docs/provenance/CLEANROOM.md` defining separate specification and implementation roles, source-access restrictions, behavior-only specifications, contributor attestations, review evidence, and replacement acceptance criteria.
- Store behavior-only specifications under `specs/cleanroom/`. The implementer must not inspect inherited source. People who already inspected inherited implementations should not serve as the independent implementer for those components.
- A replacement is complete only when the provenance row changes to `new-independent`, the behavior contract passes, review evidence is recorded, and no inherited expression remains in the distributable tree.

### Attribution and package metadata

- Use verified evidence to assign `aut`, `ctb`, `cph`, and `cre`. R's package manual requires all significant contributors to be included and supports these roles through `Authors@R`.
- Record the approved target metadata in `docs/provenance/ATTRIBUTION.md`; later migration phases apply it to `DESCRIPTION`, `README.md`, `inst/CITATION`, and `NEWS.md` without guessing.
- `inst/CITATION` should normally derive package citation metadata from `DESCRIPTION` to avoid divergence.
- Phase 1 must record a real human maintainer and durable contact address before release, but should not invent or expose an address that the maintainer has not approved.

### Name and repository checks

- `GEModelR` satisfies R's basic package-name syntax: it starts with a letter, contains only ASCII letters, and has at least two characters.
- Create `tools/check_name_availability.R` and `docs/release/NAME-CHECK.md`. The report must record timestamp, exact query URLs/commands, case-insensitive exact matches, raw-result hashes, and a reviewer.
- Check current CRAN package indexes, the CRAN archive, current and historical Bioconductor releases, R-universe search, and GitHub repository search immediately before repository reservation and again before release. A search result is evidence at a point in time, not a legal trademark clearance or permanent reservation.
- Exact web searches on 2026-08-24 found no obvious `GEModelR` R-package collision, but this is not sufficient for the release gate; the scripted and reviewed checks remain mandatory.

### Governance and private development

- Create `GOVERNANCE.md` with David Zenz as sole v1 maintainer/release authority, the process for adding maintainers, succession, and security-reporting responsibility.
- Create `docs/release/REPOSITORY.md` recording the intended personal-account ownership, canonical URL/issue tracker placeholders, private-development requirement, branch-protection target, and the external steps needed to detach or mirror the public fork.
- Repository visibility changes, detachment, deletion/recreation, issue posting, and branch-protection changes are external/destructive checkpoints. Plans should prepare and verify them but require explicit user confirmation before execution.

## Risks and Non-Goals

- This phase does not make a legal determination, choose a license for upstream, or guarantee trademark availability.
- It does not rename the package, alter solver behavior, narrow exports, or publish GEModelR.
- Making work private now cannot retract public forks or local clones that already exist.
- Clean-room replacement is a future implementation program if permission is unavailable; Phase 1 defines and approves its protocol and inventory, but cannot mark rights `cleared` until replacement and review are complete.
- Full-scale GTAP inputs, benchmark outputs, credentials, and private correspondence must not enter public evidence artifacts.

## Validation Architecture

### Layer 1: deterministic repository checks

Run on every Phase 1 change:

```sh
Rscript --vanilla tools/provenance_inventory.R --check
Rscript --vanilla tools/check_release_gates.R --offline
Rscript --vanilla -e 'stopifnot(grepl("^[A-Za-z][A-Za-z0-9.]+$", "GEModelR"), !endsWith("GEModelR", "."))'
git diff --check
```

Assertions:

- Every auditable source symbol has exactly one provenance row.
- No row has `classification=unknown`, an empty `status`, or contradictory origin fields.
- `RIGHTS.md` and `RELEASE-GATES.md` agree on `blocked`, `cleared`, or `clean-room-required`.
- A blocked status prevents any release-ready result; no script may silently default to cleared.
- Public evidence contains no credentials, proprietary `.har`/`.tab` data, giant results, or private correspondence.

### Layer 2: live name/repository checks

Run manually at repository reservation and again at release:

```sh
Rscript --vanilla tools/check_name_availability.R --name GEModelR --output docs/release/NAME-CHECK.md
Rscript --vanilla tools/check_release_gates.R --online
```

The generated report must cover current and historical CRAN/Bioconductor records plus R-universe and GitHub, include a UTC timestamp and evidence hashes, and fail on a case-insensitive exact collision or an unavailable source.

### Layer 3: human evidence gates

- A maintainer reviews and signs the provenance inventory and name report.
- Rights clearance requires the stored upstream grant/license or a completed clean-room review; an unanswered request is never clearance.
- The user explicitly approves posting the upstream request and any repository detachment, visibility, deletion/recreation, or publication action.
- `DESCRIPTION` target roles, copyright holders, license, maintainer, URL, and `BugReports` are checked against `ATTRIBUTION.md`, `RIGHTS.md`, and `REPOSITORY.md` before a later phase applies them.

### Requirement evidence matrix

| Requirement | Primary evidence | Passing condition |
|-------------|------------------|-------------------|
| PROV-01 | `RIGHTS.md`, `CLEANROOM.md`, `RELEASE-GATES.md` | Written coverage exists, or distribution remains explicitly blocked behind an approved replacement strategy. |
| PROV-02 | `PROVENANCE.csv`, `ATTRIBUTION.md` | Every function/file is classified and roles/holders are evidence-backed. |
| PROV-03 | `NAME-CHECK.md` | All required registries were checked at the required times with no exact collision. |
| PROV-04 | `GOVERNANCE.md`, `REPOSITORY.md` | Human maintainer, approved contact, owner, canonical URL, issue tracker, and release authority are recorded. |

## Authoritative Sources

- [GitHub: Licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)
- [GitHub: Terms of Service, license grants](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service)
- [GitHub: Fork visibility](https://docs.github.com/en/pull-requests/reference/forks)
- [GitHub: Detaching a fork](https://docs.github.com/en/pull-requests/how-tos/working-with-forks/detaching-a-fork)
- [GitHub: Setting repository visibility](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)
- [R Core: Writing R Extensions](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html)
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
- [CRAN submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html)
- [Bioconductor package discovery](https://bioconductor.org/install/)
- [R-universe documentation](https://docs.r-universe.dev/)

---

*Research synthesized inline after three phase-researcher runtime failures.*
