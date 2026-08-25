# Clean-room replacement protocol

Cleanroom-Protocol-Version: 1
Cleanroom-Coverage: not-activated
Cleanroom-Review-Status: not-reviewed

## Status and purpose

This document defines the D-02 and D-04 fallback for replacing inherited
expression. It does not assert that replacement work has started or that any
component is independently implemented. Activating the protocol requires a
reviewed decision and changes `Rights-Status` to `clean-room-required`, never
directly to `cleared`.

Release eligibility requires every inherited provenance key to be represented
by complete component evidence under this protocol. One missing, duplicate, or
unreviewed key keeps public distribution blocked.

## Distinct roles

Each component has three named, distinct people:

1. The specification author records only observable behavior. This person may
   study existing user documentation, public standards, and black-box results.
   If they have seen inherited source, they must declare that access and must
   not transmit source expression, source-derived structure, or implementation
   hints to the implementer.
2. The implementer writes the replacement from the approved behavior-only
   specification. An implementer who has inspected inherited source for that
   component is ineligible. Eligibility is component-specific and must be
   declared before implementation begins.
3. The reviewer is independent of both authors. The reviewer verifies role
   separation, source-access declarations, admissible inputs, behavior tests,
   provenance linkage, and absence of inherited expression. Review feedback
   must not expose inherited implementation details to the implementer.

No person may occupy more than one of these roles for the same component.
Names or stable public identities are evidence labels; they do not by
themselves prove independence.

## Source-access declarations

Before work starts, the specification author, implementer, and reviewer record
whether they accessed inherited source for the component. The implementer must
record `implementer_source_access: none` and attest
`no-inherited-source-access`. Prior exposure cannot be cured by forgetting,
waiting, or relying on a different checkout.

If source exposure is discovered later, the evidence returns
`CLEANROOM_IMPLEMENTER_INELIGIBLE`; the implementation cannot be accepted as
independent and must be replaced by a new eligible implementer.

## Admissible inputs

The implementer may receive only:

- the approved component specification under `specs/cleanroom/`;
- public standards identified with a stable citation and the `public:` prefix;
- redistributable synthetic or reduced fixtures identified with the
  `redistributable:` prefix and their redistribution basis;
- black-box expected inputs, outputs, and errors that do not reveal inherited
  expression or proprietary data.

Inherited source excerpts, pseudocode or structural descriptions derived from
inherited source, private correspondence, proprietary fixtures, credentials,
and non-redistributable model data are forbidden implementer inputs.

## Required component evidence

Each component specification must contain every field defined in
`specs/cleanroom/README.md`, exactly once. Acceptance requires:

- a unique `component_id` and exact `provenance_key`;
- complete inputs, outputs, errors, invariants, and compatibility example;
- three distinct roles;
- behavior-only specification, no-source-access implementation, and independent
  review attestations;
- an eligible implementer with no inherited-source access;
- a named passing behavior test;
- public-standard and redistributable-fixture evidence;
- `provenance_classification: new-independent`; and
- an approved protocol-level review after exact coverage is established.

The protocol record lists every inherited row as
`Inherited-Provenance-Key: PATH::SYMBOL`. Component specifications must cover
that set exactly once. A `new-independent` provenance row is accepted only
after its component evidence passes and the complete inherited-key set is
covered. Classification never changes merely because a file was rewritten.

## Independent review

The reviewer checks the specification and implementation histories, confirms
the role identities are distinct, validates all source-access declarations,
runs the behavior tests, and checks that fixtures are redistributable. The
reviewer also compares the complete provenance-key oracle with component
specifications and records the review outcome without exposing inherited
expression in public evidence.

`Cleanroom-Coverage: complete` means exact one-to-one key coverage, not an
estimate. `Cleanroom-Review-Status: approved` means the independent review is
complete. Both markers are necessary but insufficient without valid component
records.

## Fail-closed outcomes

- `CLEANROOM_IMPLEMENTER_INELIGIBLE` means an implementer is source-exposed or
  otherwise declared ineligible.
- `CLEANROOM_EVIDENCE_INCOMPLETE` means a required field, distinct role,
  attestation, passing behavior test, admissible input, provenance link, or
  exact coverage record is missing or contradictory.
- `CLEANROOM_REVIEW_INCOMPLETE` means protocol-level independent approval is
  absent.

These outcomes keep `release_ready=false`. Complete synthetic evidence may
exercise release readiness in temporary tests, but cannot change the canonical
rights record or authorize publication.

## Activation sequence

1. Review and record the decision to activate the fallback.
2. Freeze the inherited provenance-key oracle.
3. Assign a specification author and write behavior-only specifications.
4. Establish implementer eligibility before sharing any specification.
5. Implement and run the named behavior tests using admissible inputs only.
6. Obtain independent review for every component and exact total coverage.
7. Change provenance rows to `new-independent` only when their evidence passes.
8. Re-run the release gate; any uncovered inherited key remains blocked.

Until all steps complete, this document is a process contract rather than a
redistribution grant.
