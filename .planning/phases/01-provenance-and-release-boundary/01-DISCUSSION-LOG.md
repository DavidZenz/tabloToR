# Phase 1: Provenance and Release Boundary - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-22
**Phase:** 1-Provenance and Release Boundary
**Areas discussed:** Rights-clearance path, Attribution model, Ownership and governance, Name and release boundary

---

## Rights-clearance path

### Primary upstream request

| Option | Description | Selected |
|--------|-------------|----------|
| Upstream license and fork confirmation | Ask upstream to add an explicit license and confirm continuation as GEModelR. | ✓ |
| Private GEModelR grant | Request permission only for this successor. | |
| File-specific permission | Request grants for individually inherited files. | |

**User's choice:** Upstream open-source license and fork confirmation.
**Notes:** A draft upstream issue was provided; it was not posted.

### No-response path

| Option | Description | Selected |
|--------|-------------|----------|
| Block indefinitely | Wait for upstream before doing replacement work. | |
| Replacement audit | Identify and independently replace inherited expression. | ✓ |
| Stop the successor | Abandon GEModelR if permission is unavailable. | |

**User's choice:** Investigate independently implemented replacements.
**Notes:** The estimate that about 90% is new must be verified at file/function level.

### Audit timing

| Option | Description | Selected |
|--------|-------------|----------|
| After 30 days | Wait one month before starting the audit. | |
| After 60 days | Wait two months before starting the audit. | |
| Immediately | Audit in parallel with the license request. | ✓ |

**User's choice:** Begin immediately.
**Notes:** No waiting period applies.

### Replacement standard

| Option | Description | Selected |
|--------|-------------|----------|
| Strict clean room | Behavior-only specifications and implementers who do not inspect inherited source. | ✓ |
| Same-team rewrite | Existing developers rewrite, followed by legal review. | |
| Remove subsystems | Eliminate inherited functionality rather than replace it. | |

**User's choice:** Strict clean-room replacement.
**Notes:** Independence must be demonstrable.

---

## Attribution model

### Contributor roles

| Option | Description | Selected |
|--------|-------------|----------|
| Evidence-based roles | Assign `aut`, `ctb`, `cph`, and `cre` from verified evidence. | ✓ |
| Always retain upstream as author | Keep upstream author status regardless of retained expression. | |
| Metadata credits new team only | Put upstream credit outside `Authors@R`. | |

**User's choice:** Evidence-based roles.
**Notes:** Conceptual-predecessor credit remains appropriate if clean-room replacement removes inherited expression.

### Provenance granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Package-level | One aggregate statement for the package. | |
| File-level | Classify each source file. | |
| Function-level | Audit inherited/modified functions and classify wholly new files at file level. | ✓ |

**User's choice:** Function-level.
**Notes:** This is the required granularity for mixed-origin files.

### Attribution locations

| Option | Description | Selected |
|--------|-------------|----------|
| Metadata and README only | Use `DESCRIPTION` and `README.md`. | |
| Comprehensive attribution | Use `DESCRIPTION`, `README.md`, `CITATION`, provenance inventory, and `NEWS.md`. | ✓ |
| Inventory only | Keep attribution in the audit artifact. | |

**User's choice:** Comprehensive attribution.
**Notes:** Transition history belongs in `NEWS.md`.

### Future contributors

| Option | Description | Selected |
|--------|-------------|----------|
| Full contributor record | Use `Authors@R`, a contributor record, and `NEWS.md` where release-relevant. | ✓ |
| `Authors@R` only | Keep credits only in package metadata. | |
| Git history only | Treat commits as the contributor record. | |

**User's choice:** Full contributor record.
**Notes:** Substantive contribution is the threshold.

---

## Ownership and governance

### Repository ownership

| Option | Description | Selected |
|--------|-------------|----------|
| Personal GitHub account | Host the canonical v1 repository under the maintainer's account. | ✓ |
| Dedicated organization | Create an organization before v1. | |

**User's choice:** Personal GitHub account.
**Notes:** An organization can be considered after the maintainer group expands.

### Maintainer authority

| Option | Description | Selected |
|--------|-------------|----------|
| Single v1 maintainer | David Zenz is maintainer and release authority; others contribute by pull request. | ✓ |
| Maintainer team | Share release authority from the outset. | |

**User's choice:** Single v1 maintainer.
**Notes:** A valid public contact address remains required before release.

### Merge policy

| Option | Description | Selected |
|--------|-------------|----------|
| Protected main with CI | Merge through pull requests after checks pass; permit maintainer self-review initially. | ✓ |
| Direct pushes | Allow routine direct changes to `main`. | |
| Independent approval | Require another reviewer for every merge. | |

**User's choice:** Protected `main` with CI-gated pull requests.
**Notes:** Self-review is temporary single-maintainer pragmatism.

### Governance record

| Option | Description | Selected |
|--------|-------------|----------|
| Governance before release | Document authority, new maintainers, succession, and security responsibility. | ✓ |
| Informal governance | Rely on repository permissions and convention. | |
| Governance after v1 | Defer the document until after release. | |

**User's choice:** Add `GOVERNANCE.md` before public release.
**Notes:** The policy should support later maintainer expansion.

---

## Name and release boundary

### Exact identity

| Option | Description | Selected |
|--------|-------------|----------|
| GEModelR everywhere | Use identical package and repository spelling/capitalization. | ✓ |
| Different repository slug | Use GEModelR for R and another GitHub slug. | |

**User's choice:** `GEModelR` for both package and repository.
**Notes:** Identity migration itself belongs to Phase 3.

### Name availability

| Option | Description | Selected |
|--------|-------------|----------|
| Release-gated documented check | Verify R validity, current/historical CRAN and Bioconductor records, R-universe, and GitHub. | ✓ |
| Informal search | Rely on a one-time web search. | |
| Check during publication | Defer collision checks until release. | |

**User's choice:** Make the documented check a release gate.
**Notes:** The result must be current when the repository is reserved and released.

### Development visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Private development | Keep work private until redistribution rights are resolved. | ✓ |
| Existing public fork | Continue publicly but publish no formal releases. | |
| Stop all work | Pause engineering until legal clearance. | |

**User's choice:** Go private in the meantime.
**Notes:** Verify GitHub fork visibility; use a private standalone repository if needed.

### Public artifacts before clearance

| Option | Description | Selected |
|--------|-------------|----------|
| Licensing request only | Keep source, binaries, docs, releases, and R-universe unpublished. | ✓ |
| Public planning and docs | Publish non-code GEModelR materials while source stays private. | |
| Public prereleases | Publish development artifacts with a disclaimer. | |

**User's choice:** Only the upstream licensing request may be public.
**Notes:** No redistribution claim may be made before clearance.

---

## the agent's Discretion

- Provenance inventory schema and supporting audit tooling.
- Exact organization of evidence and governance records.
- Private repository migration mechanics consistent with preserving history and upstream attribution.

## Deferred Ideas

- Numerical/API compatibility, package renaming, backend refactoring, native portability, release documentation, and publication remain assigned to later roadmap phases.
