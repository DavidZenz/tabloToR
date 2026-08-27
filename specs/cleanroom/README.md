# Behavior-only clean-room component specifications

This directory is a schema and index. Component specifications are created only
after the fallback is formally activated. They describe externally observable
behavior and must not contain inherited expression or source-derived structure.

## Component record format

Each component uses one Markdown file other than this README. Every field is a
single `field: value` line and appears exactly once.

| Field | Required evidence |
| --- | --- |
| `component_id` | Unique stable replacement identifier. |
| `provenance_key` | Exact inherited `PATH::SYMBOL` key. |
| `inputs` | Observable accepted types, shapes, and preconditions. |
| `outputs` | Observable output types, shapes, and meaning. |
| `errors` | Observable rejected cases and error behavior. |
| `invariants` | Properties holding for every valid execution. |
| `compatibility_example` | At least one observable input/output or error example. |
| `specification_author` | Named behavior-only specification author. |
| `specification_attestation` | Exact `behavior-only-no-inherited-expression`. |
| `implementer` | Named independent implementation author. |
| `implementer_eligibility` | Exact `eligible`. |
| `implementer_source_access` | Exact `none`. |
| `implementer_attestation` | Exact `no-inherited-source-access`. |
| `reviewer` | Named independent reviewer. |
| `reviewer_attestation` | Exact `independent-review-complete`. |
| `replacement_source` | Under-root relative replacement-source path. |
| `replacement_source_md5` | Exact lowercase MD5 of replacement source. |
| `behavior_test` | Under-root relative runnable R test path. |
| `behavior_test_md5` | Exact lowercase MD5 of behavior test. |
| `public_standard_evidence` | Under-root relative public-standard evidence path. |
| `public_standard_evidence_md5` | Exact lowercase MD5 of standard evidence. |
| `redistributable_fixture` | Under-root relative redistributable fixture path. |
| `fixture_md5` | Exact lowercase MD5 of the fixture. |
| `independent_result` | Under-root relative independent DCF result path. |
| `independent_result_md5` | Exact lowercase MD5 of the result artifact. |
| `provenance_classification` | Exact `new-independent`. |

The specification author, implementer, reviewer, and result producer are
pairwise distinct. Each inherited key appears once in the protocol and once in
the component set. Every artifact path is distinct, relative, root-confined,
regular, non-empty, and hash-bound.

## Component template

```text
component_id: example-component
provenance_key: R/example.R::example
inputs: numeric scalar x
outputs: numeric scalar y
errors: non-numeric input is rejected
invariants: output length equals input length
compatibility_example: x=2 produces y=4
specification_author: SPECIFICATION_AUTHOR
specification_attestation: behavior-only-no-inherited-expression
implementer: INDEPENDENT_IMPLEMENTER
implementer_eligibility: eligible
implementer_source_access: none
implementer_attestation: no-inherited-source-access
reviewer: INDEPENDENT_REVIEWER
reviewer_attestation: independent-review-complete
replacement_source: cleanroom/replacement/example.R
replacement_source_md5: LOWERCASE_MD5
behavior_test: cleanroom/tests/example-behavior.R
behavior_test_md5: LOWERCASE_MD5
public_standard_evidence: cleanroom/standards/example.md
public_standard_evidence_md5: LOWERCASE_MD5
redistributable_fixture: cleanroom/fixtures/example.dcf
fixture_md5: LOWERCASE_MD5
independent_result: cleanroom/results/example-result.dcf
independent_result_md5: LOWERCASE_MD5
provenance_classification: new-independent
```

Upper-case values are instructions, not valid evidence.

## Independent result DCF

The result artifact contains exactly one record with these fields:

```text
Component-ID: example-component
Provenance-Key: R/example.R::example
Replacement-Source-MD5: LOWERCASE_MD5
Behavior-Test-MD5: LOWERCASE_MD5
Fixture-MD5: LOWERCASE_MD5
Public-Standard-Evidence-MD5: LOWERCASE_MD5
Test-Command-ID: rscript-cleanroom-v1
Exit-Status: 0
Result-Producer: INDEPENDENT_RESULT_PRODUCER
Produced-At-UTC: YYYY-MM-DDTHH:MM:SSZ
Reviewer: INDEPENDENT_REVIEWER
Review-Date: YYYY-MM-DD
Result-Status: pass
```

The checker freshly runs:

```text
Rscript --vanilla BEHAVIOR_TEST --source REPLACEMENT_SOURCE --fixture FIXTURE
```

The component cannot replace inherited expression unless this fresh execution
passes, the DCF bindings match exactly, the producer is independent, and the
corresponding provenance row is `new-independent` with the replacement-source
hash.

## Input boundary

Allowed inputs are approved behavior specifications, public standards, and
redistributable synthetic or reduced fixtures. Black-box observations are
allowed only when they reveal behavior without inherited expression or private
data. Inherited source excerpts, source-derived pseudocode or structural
descriptions, proprietary fixtures, credentials, private correspondence, and
private model inputs are prohibited.

Specifications and artifacts are evidence inputs, not permission grants.
Missing, empty, escaped, duplicated, stale, or contradictory evidence fails
closed.
