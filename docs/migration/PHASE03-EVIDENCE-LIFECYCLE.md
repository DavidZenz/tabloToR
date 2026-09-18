# Phase 03 Evidence Lifecycle

This document defines the noncircular handoff for D-09 / CR-03. The workflow
identity policy is a narrow, proposed classification of retained predecessor
evidence. It does not change the active tracked-source auditor until the exact
policy bytes have been reviewed and activated by the later reseal plan.

## Two authorities

The technical qualification manifest is historical evidence for the exact
source-tree HEAD recorded in its `HEAD` field. Its stage chain may prove a clean
export, build, installation, workflow, test, and migration result for that
tree, but it cannot certify later summary, state, review, or verification
writes.

The final-tree audit is a separate read-only check after all durable evidence
has been written and committed. It reads the final tracked tree, validates the
approved exact-row inventory, and emits its result to the conversation or
external run log. The audit result is not written into the tree it certifies.
If any durable write follows the audit, the audit is run again.

## Exact policy scope

The policy contains concrete rows only for these paths:

- `.planning/STATE.md` — orchestrator-owned state handoff
- `.planning/ROADMAP.md` — orchestrator-owned roadmap handoff
- `.planning/phases/03-gemodelr-identity-migration/03-VALIDATION.md` — verifier-owned report
- `.planning/phases/03-gemodelr-identity-migration/03-REVIEW.md` — verifier-owned report
- `.planning/phases/03-gemodelr-identity-migration/03-13-SUMMARY.md` through `03-20-SUMMARY.md` — orchestrator-owned plan evidence

Every row has category `migration-instruction`, owner `orchestrator` or
`verifier`, an exact SHA-256 of the complete UTF-8 line including its trailing
LF, and a positive `max_count`. The line number is deliberately not part of
the authorization, so inserting non-identity evidence above a retained line
does not invalidate it. A changed line produces a new digest and is rejected.

Not-yet-produced summary paths may be listed in the policy without granting an
occurrence. A future summary may contain only one plain-text metadata line
whose value is obtained from the reviewed predecessor registry. The line must
be outside Markdown or executable fences. Other prose should use an alias such
as `approved predecessor fixture`; it must not repeat the package identity.

## Producer handoff

The lifecycle is ordered and each stage remains independently attributable:

1. The executor makes and commits production changes for a plan.
2. The executor writes and commits that plan's substantive summary.
3. The orchestrator updates and commits `STATE.md` and `ROADMAP.md`.
4. The verifier writes or commits review and validation evidence.
5. The orchestrator invokes the approved policy checker and the exact-row
   review in Plan 03-19. A proposal is not an active exception.
6. Plan 03-20 runs one technical qualification from the clean recorded HEAD.
7. After all qualification evidence is durable, the verifier runs
   `tools/seal_phase03_identity.R --check-final-tree` in read-only mode and
   publishes only its stdout in the conversation or external run log.

The qualification manifest records the tree it actually examined. The final
audit records no self-referential durable result, and no later plan may reuse an
older manifest to certify a newer source tree.

## Fail-closed rules

The policy checker rejects wildcard, absolute, traversal, source, executable,
symlink-escaping, arbitrary planning, malformed, duplicate, and unknown paths.
It rejects unknown line hashes, changed metadata lines, duplicate lines above
their bound, invalid categories or owners, and any predecessor identity inside
a fenced code block. The five active tracked-source categories remain exactly
those defined by `tools/check_identity_migration.R`; this policy is a reviewed
subtype of `migration-instruction`, not a new category.

The proposal command proves the policy and current evidence without authorizing
activation:

```text
Rscript --vanilla tools/check_workflow_identity_policy.R --proposal
```

Only a later exact review may change the DCF to `Review-State: approved` with a
real reviewer, UTC timestamp, and the same policy SHA-256. The approved command
is a separate gate:

```text
Rscript --vanilla tools/check_workflow_identity_policy.R --verify-approved
```

No policy expansion, source change, release action, publication, remote
mutation, or automatic inventory refresh is implied by this lifecycle.
