# Behavior-only clean-room component specifications

This directory is an index and schema. Component specifications are created
only after the clean-room fallback is formally activated. A specification
describes externally observable behavior; it must not describe inherited
implementation structure.

## Record format

Each component uses one Markdown file other than this README. Every field below
is a single line in `field: value` form and appears exactly once:

| Field | Required evidence |
| --- | --- |
| `component_id` | Unique stable identifier for the replacement component. |
| `provenance_key` | Exact inherited `PATH::SYMBOL` key being replaced. |
| `inputs` | Observable accepted input types, shapes, and preconditions. |
| `outputs` | Observable output types, shapes, and meaning. |
| `errors` | Observable rejected cases and error behavior. |
| `invariants` | Properties that hold for every valid execution. |
| `compatibility_example` | At least one input/output or input/error example. |
| `specification_author` | Named author of the behavior-only specification. |
| `specification_attestation` | Exact value `behavior-only-no-inherited-expression`. |
| `implementer` | Named independent implementation author. |
| `implementer_eligibility` | Exact value `eligible`. |
| `implementer_source_access` | Exact value `none`. |
| `implementer_attestation` | Exact value `no-inherited-source-access`. |
| `reviewer` | Named independent reviewer, distinct from both authors. |
| `reviewer_attestation` | Exact value `independent-review-complete`. |
| `behavior_test` | Stable test path and behavior name. |
| `behavior_test_status` | Exact value `pass`. |
| `public_standard` | Public behavior source prefixed with `public:`. |
| `redistributable_fixture` | Fixture evidence prefixed with `redistributable:`. |
| `provenance_classification` | Exact value `new-independent`. |

Role labels must be non-empty and pairwise distinct. The `provenance_key` must
appear exactly once in the activated protocol's
`Inherited-Provenance-Key` list, and each listed key must have exactly one
component specification.

## Template

```text
component_id: example-component
provenance_key: R/example.R::example
inputs: numeric scalar x
outputs: numeric scalar y
errors: non-numeric input is rejected
invariants: output length equals input length
compatibility_example: x=1 produces y=1
specification_author: SPECIFICATION_AUTHOR
specification_attestation: behavior-only-no-inherited-expression
implementer: INDEPENDENT_IMPLEMENTER
implementer_eligibility: eligible
implementer_source_access: none
implementer_attestation: no-inherited-source-access
reviewer: INDEPENDENT_REVIEWER
reviewer_attestation: independent-review-complete
behavior_test: tests/testthat/FILE.R#BEHAVIOR
behavior_test_status: pass
public_standard: public:STABLE_REFERENCE
redistributable_fixture: redistributable:FIXTURE_AND_BASIS
provenance_classification: new-independent
```

Upper-case example values are instructions, not valid evidence. Do not create a
component record until actual role identities and evidence are available.

## Input boundary

Allowed inputs are approved behavior specifications, public standards, and
redistributable synthetic or reduced fixtures. Black-box observations are
allowed only when they expose behavior without inherited expression or private
data.

Inherited source excerpts, source-derived pseudocode, source-derived structural
descriptions, and proprietary fixtures are prohibited. An implementer who has
inspected inherited source is ineligible for that component even if no excerpt
is copied into the specification.

## Acceptance

A component becomes eligible for `new-independent` only when every field is
complete, the behavior test passes, the three roles are distinct, the
implementer is eligible, all attestations have their exact values, and the
independent reviewer approves it. Release readiness additionally requires
complete one-to-one coverage of every inherited provenance key.

Specifications and fixtures are evidence inputs, not permission grants. Missing
or contradictory evidence fails closed.
