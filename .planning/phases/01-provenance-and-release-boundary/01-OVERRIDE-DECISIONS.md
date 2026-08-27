# Phase 1 Historical Override Decisions

Override-Decision-Record-Version: 1
Rights-Blocked-Marker-Override: pending
Request-Posting-Override: pending
D-03-Concurrency-Override: pending
Accepted-By: pending
Decided-At-UTC: pending

## Decision boundary

These are three independent maintainer decisions. No choice is accepted from
silence, ambiguity, a partial answer, prior conversation, prior SUMMARY claims,
existing project state, or auto-advance. Identity and time also remain pending
until the maintainer supplies one complete response tuple.

An acceptance records an intentional historical deviation; it does not rewrite
history or authorize release, publication, repository mutation, request posting,
or any other external action. A rejection leaves the corresponding truth failed
and creates no verification override.

## 1. Superseded Plan 01-01 blocked-rights marker

**Canonical verification target:** `The checked-in repository is valid only as the Plan 01-01 blocked private-development state.`

**Original Plan 01-01 must-have:** `Per D-05 and D-17, the checked-in repository
is valid only as an explicitly blocked private-development state; it is never
release-ready while rights are unresolved.`

**Observed deviation:** Plan 01-01 required `Rights-Status: blocked`. The
canonical record now says `Rights-Status: cleared` for the scoped
upstream-authored inherited baseline, while repository release readiness remains
blocked for separate reasons.

**Why acceptance may be defensible:** `docs/provenance/RIGHTS.md` binds the
audited upstream repository and commit to the public owner response in
`docs/provenance/UPSTREAM-RESPONSE.md`, records David Zenz's review, limits the
clearance to upstream-authored inherited source, and excludes unrelated
third-party components. The integrated blocked-state assertion still returns
`release_ready=false` with exactly the two canonical release blockers. This
evidence can support treating the initial rights marker as superseded rather
than restoring a marker that would contradict the reviewed scoped rights basis.

**Consequence of rejection:** This target remains failed and receives no
override. Phase 1 cannot claim literal Plan 01-01 conformance until the governing
contract is revised or the blocked marker is restored with evidentially
consistent rights records.

## 2. Superseded Plan 01-02 request-posting checkpoint

**Canonical verification target:** `Posting the reviewed request is the only completion path unless an accepted override changes the contract.`

**Original Plan 01-02 must-have:** `Posting the exact reviewed request is a
blocking human action and the only completion path for Task 01-02-03;
defer/cancel leaves this plan and Phase 1 unresolved with the D-05 blocker
intact.`

**Observed deviation:** Task 01-02-03 completed without posting the drafted
three-part request. The public response already present at the reviewed issue was
accepted instead, and `docs/provenance/UPSTREAM-REQUEST.md` is retained as
`superseded-do-not-post` evidence.

**Why acceptance may be defensible:** The response artifact records the public
URL, timestamp, owner association, exact statement, audited commit, and
supporting interpretation. `docs/provenance/RIGHTS.md` binds its MD5 and states
that no additional upstream request is required or authorized. Posting the
historical draft now would be redundant and would conflict with that reviewed
do-not-post record; the rights intent is already covered by the existing public
response without new external communication.

**Consequence of rejection:** This target remains failed and receives no
override. The governing completion contract must be revised, or a future posting
path must receive separate explicit authorization and evidential review; this
decision record itself authorizes no posting.

## 3. Historical D-03 sequential execution

**Canonical verification target:** `Rights/clean-room work and provenance audit ran concurrently in Wave 2 per D-03.`

**Original Plan 01-02 must-have:** `Per D-03, this rights-request/clean-room work
runs in Wave 2 concurrently with Plan 01-03's provenance and replacement audit
rather than waiting for an upstream response.`

**Observed deviation:** Git chronology is sequential. Plan 01-02's final
implementation commit `e3b7267` is dated `2026-08-25T12:19:30+02:00`; Plan
01-03's RED commit `cebcb5a` is dated `2026-08-25T12:34:13+02:00`.

**Why acceptance may be defensible:** The chronology cannot be repaired
retroactively, but both evidence streams were completed. Plans 01-07 through
01-10 subsequently revalidated their integrated source, attribution, name,
native-hash, license-boundary, and clean-room links while preserving the
canonical release blockers. Acceptance would acknowledge nonconformance with
D-03 while accepting the completed and revalidated evidence outcome.

**Consequence of rejection:** This target remains failed and receives no
override. Because execution history is immutable, the governing D-03 decision
or phase record must be revised before Phase 1 can pass.

## Ineligible override scope

None of CR-01 through CR-08 or WR-01 through WR-04 is eligible for override.
Those findings concern implementation correctness and must be established by
code and evidence. The PROV-01 adjacency probe remains `FLAGGED-UNVERIFIED`
because no legal-evidence merge or touch operation is defined; it is not
silently converted into a check or override.

`DEPENDENCY_COMPATIBILITY_AUDIT_PENDING` and
`ATTRIBUTION_IDENTITY_UNRESOLVED` remain canonical release blockers regardless
of all three decisions. They are not eligible for override here. The rights
basis remains the primary basis, with clean-room evidence retained only as an
alternative evidentiary route; this plan makes no assumption change.

## Required maintainer response

Reply with all three independent choices and an explicit identity in exactly
this format:

`rights=accept|reject; request=accept|reject; d03=accept|reject; accepted_by=NAME`

Any missing, ambiguous, or differently scoped response leaves every field
pending and leaves `01-VERIFICATION.md` unchanged.
