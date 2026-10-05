# Deferred hosted package-check findings

Observed in run `37273713572`, attempt 1, Linux release R 4.6.1 / Matrix 1.7.6 serial. These are outside the current native portability task changes; no fixture, serialization, provisional license, or broad release cleanup was performed.

- Nine full-suite failures in `test-model-serialization.R:688` and `test-serialization-leaf-types.R:269,272,278,282,291,413`: immutable predecessor source fingerprint and exact legacy leaf metadata differ under this newer R context. Preserve the original fixture and investigate separately; the installed native core matrix passes.
- Hosted full-check PDF manual generation reports `pdflatex is not available`, yielding one ERROR and one WARNING in addition to the test ERROR. The raw check and Rdlatex logs are preserved; this is an informational runner-tooling limitation, not a claim that Rd documentation is invalid.
- Existing DESCRIPTION license text `What license is it under?` produces a WARNING. The Phase 1 unresolved license/release decisions remain authoritative.
- 164 skipped tests in the representative packaged check include source-only provenance/release/migration contracts and the explicit parallel-only test in serial mode. Their raw names and reasons remain in the artifact; they do not qualify a release gate.

Raw artifacts: `/tmp/gemodelr-hosted-37273713572/artifacts-final/representative-check-37273713572-1/`; immutable artifact IDs/digests and file hashes: `hosted-evidence/hosted-run-37273713572-1.json`. The earlier equivalent full-check result is retained under run `37273389483`.
