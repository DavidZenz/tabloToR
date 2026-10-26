# Current source identity evidence refresh

The maintainer explicitly requested “update the identity evidence” on 2026-10-26.
This authorizes the local technical evidence update. It does not authorize
publication, rights/license changes, or adoption of rejected provenance proposals.
Phase 06 remains accepted. Existing uncommitted solver/native work is excluded.

## Reviewed source and changes

The reviewed implementation is committed source
`5e23ca046dc4c12a2e25528756d5d5de6ddddb50`. Verification uses a clean local clone
at `/tmp/GEModelR-identity-refresh-WRkH9w/source`, with Matrix 1.6-5 from the
existing isolated library. The installed namespace is the preceding qualified
archive at `/tmp/GEModelR-check-repair-1jttZn/final-packet/private/work/library`;
its production R/native code matches the reviewed implementation exactly.

The prior map was last maintained during Phase 03, before subsequent API,
lifecycle, overflow-safe residual, scaling, cache, and preconditioner changes.
Its mapping literals and exclusion remain unchanged. Mixed-case occurrences
change from 328 to 420; upper-case occurrences remain 2. The current normalized
source fingerprint is `edc688b8dc55aa908dd41f7afb420375`.

Four protected whole-source digests are resealed to the current committed
implementation. Their rationales explicitly describe post-migration fixes rather
than claiming that those fixes were only identity substitutions. The exact
sparseMatrix construction line originally protected at line 228 now occurs at
line 615. Its text is unchanged; the region location and numbered-region digest
are updated together, with an assertion for that exact text.

The numerical contract audit now requires the existing stable residual helper
call instead of the superseded overflow-prone formula. Negative mutation tests
still reject changed residual semantics, tolerance, ordering, API signature,
defaults, and unmapped identity. The original numerical comparison is unchanged:
only the three existing package/source identity fields may differ.

The finite occurrence allowlist grows from 121 to 148 rows: 27 added, 24 refreshed,
none removed. Added paths cover later planning/history, historical CI references,
migration documentation, package attribution, and the serialized-fixture policy
reference. Explicit path classifications and the exact existing NEWS attribution
line are recognized; no wildcard or blanket directory exemption was added.
The compatibility manifest's citation count is corrected from three to four.

## Bound records and preservation

`inst/migration/source-identity-review.dcf` records the source commit, old/new
digests, actual counts, scope, maintainer instruction, and automated technical
review. `identity-reseal-review.dcf` binds the exact new allowlist and unchanged
workflow policy. Neither record impersonates a separate human rights review.

| Evidence | Before SHA256 | After SHA256 |
|----------|---------------|--------------|
| Mapping | `ab22940ea1f27568e02007cf841abafabaf48767d12ed520698320f1128e7be7` | `bc86a9f7663c6102ea92b95492c8e06f7039982f4aa7a90fed318cd92498b9ca` |
| Registry | `1ef7e42f6af7ca02b71d68744530afcc673d6f8d985c89021e5258ed14f56673` | `3ed6b5601d207cad56dd6d88a6eecac250e12bf1c612d9a06f82201cd1e72b0a` |
| Occurrence allowlist | `1bf1d3117bce193ef4ca6018ac6dec2fc55e2605f9fb89939d894cba82ae60ac` | `5582aa37a3932e2f293064d7bf0d3423b19820cf2702355c56e9caa3bb2a133a` |

The four accepted Phase 02 files, historical GTAP result, original expectations
and tolerances, predecessor registry and serialized predecessor fixture remain
byte-identical. The unchanged approved workflow policy digest is
`882f3f92a8afe84fdd50b4565ed189af5242afd8cfc2bfd72a22db4553f2ce1e`.
The new source regression binds the exact map/registry/allowlist hashes and
verifies original artifacts again. The public-source policy includes the small
technical review record and excludes this private report.

## Validation

- Source-tool runner: 26 tests, 152 assertions, zero failures and zero skips.
- Historical identity audit: passed; five immutable records, four protected
  source records, one protected region, 170 historical occurrences.
- Tracked-source audit: passed; 1063 exact allowlisted occurrences, zero active
  owners, 11 workflow-policy occurrences.
- Numerical defaults/ordering/tolerance identity contracts: passed.
- Source serialization group passed in the preliminary combined run. A stale
  citation count discovered there is fixed. The reseal lifecycle test clones
  committed HEAD and must be rerun after committing the candidate evidence.
- The independent release guard remains invalid with PROVENANCE_KEY_MISMATCH;
  canonical provenance and rights records were not edited.

Raw logs, exact occurrence inventory, original allowlist bytes, candidate rows,
and aggregate row comparison remain under the external repair directory.
Use a clean committed snapshot, with the existing supported dependency libraries
on R_LIBS and bounded thread settings:

```sh
rtk proxy Rscript --vanilla tools/check_identity_migration.R --historical-only
rtk proxy Rscript --vanilla tools/check_identity_migration.R --tracked-source
rtk proxy Rscript --vanilla tools/ci/run-source-tool-tests.R SOURCE_ROOT ARCHIVE_LIBRARY
```

The final combined source/serialization/reseal regressions will be recorded
after the evidence commit so Git lifecycle tests consume the actual update.
The previous archive's full check (3053 passes, zero errors/warnings, six notes)
is historical evidence, not a newly qualified archive of these metadata bytes.
No GTAP or full R baseline benchmark is rerun; no tag, push, hosted job or
publication occurs. The six check notes and provenance mismatch remain separate
release blockers. Frozen release packets are not edited.
