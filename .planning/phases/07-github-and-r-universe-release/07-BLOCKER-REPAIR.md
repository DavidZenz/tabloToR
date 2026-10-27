# Remaining release blocker repair

The maintainer requested repair of all remaining release blockers on 2026-10-27.
The GPL-3.0-or-later selection is binding. The maintainer also explicitly
confirmed that Git author mivanicERS and GitHub account MarosIvanic-USDA identify
Maros Ivanic. This is a factual identity disposition, not a new package role.

Work starts from committed development source 46ee33d in an isolated clone at
`/tmp/GEModelR-release-repair-j9oha8/source`. The original working tree's sixteen
preserved files remain byte-identical. No uncommitted numerical changes enter
this repair, and accepted Phase 06 evidence is not reopened.

## Implemented evidence and public CI prerequisites

- Current provenance has 347 keys, versus the stale ledger's 324: 23 additions,
  28 changed expression hashes, no removed keys. The refreshed ledger and
  expected keys pass the shared validator. An explicit 324-to-347 review is
  appended; earlier review transitions remain intact. The changed inherited
  sumToMap expression is correctly classified as inherited-modified. Current
  aliases normalize to the existing credited author; raw Git history is intact.
- The dependency audit inspects the mandatory R package closure, Rcpp LinkingTo,
  standard native include/link inputs and runtime notices. Actual official source
  archives and license files for Matrix 1.6-5/1.7-6 and SparseM 1.81 were inspected
  externally. Public audit hashes and bounded conclusions are recorded under
  inst/compatibility. Technical reviews name Codex and their real date; the
  original human license selection authority and date remain explicit.
- Both former intentional blocker records now have reviewed dispositions. All
  six public credit destinations retain the same people/roles/evidence keys.
  The complete attribution regression group passes, including its previously
  failing README/NEWS/CITATION destination checks.
- License CI consumes either the private canonical decision or the matching
  public summary, validates the audit digest and actual dependency licenses,
  and rejects missing, stale, conflicting, linked or incompatible evidence.
  Public-only fixture tests pass without private release records.
- The public Matrix contract retains 24 passing hosted tuples and six exact
  failed-source exclusions. It was derived only after the existing full private
  evidence audit passed. Public checks validate tuple coverage, digest, README
  interval and DESCRIPTION floor; development checks additionally retain the
  full private audit. Native CI runs on main as well as the development branch.
- The strict canonical guard now passes provenance, attribution, licensing,
  governance, repository and metadata checks. It currently stops only at
  NAME_REPORT_STALE. This is not yet full release qualification.

## Work in progress

Fresh live name verification, preserved historical serialization review plus
an exact current-source follow-up, public administrative test mode, reviewed
check-note handling, and final exact-archive/site/installed validation are still
being completed. A live name refresh exposed changed primary Bioconductor HTML;
the original malformed-response failure is retained externally.

No historical serialization approval/patch, predecessor fixture, accepted
numerical baseline, shared R library, external repository setting, or GEModelR
publication has been changed by this evidence repair. Concrete publication
authority remains a final boundary after local qualification.

## Fresh name reservation and pending site metadata

The maintainer explicitly approved recognizing only the canonical
`DavidZenz/GEModelR` repository as an authorized reservation and accepting a
clearly labeled automated registry verification. The live scan includes CRAN
current/archive, all discovered Bioconductor repositories and historical
releases, R-universe, and GitHub; its complete timestamped details and hashes
are retained in the canonical name report. Other owners and registry matches
still fail. Bioconductor release-table and repository-discovery parsing now
handle the actual current markup.

The package URL advertises the live repository while documentation status is
explicitly pending. The configured Pages destination remains the intended site;
it enters DESCRIPTION only after actual deployment and URL verification.
Unknown states and arbitrary additional URLs fail the metadata gate.

Complete test files passed: name availability 21 tests / 96 assertions; release
gates 64 / 639; attribution 10 / 60. All have zero failures, errors, and skips.
Synthetic intentionally blocked fixtures retain their rejection assertions.
A passing eligibility check grants no publication authorization.

## Separate public and development source checks

The source-only runner has an explicit public mode for the projected repository.
It rejects private working-tree paths and private paths anywhere in reachable
Git history. It runs public license, Matrix build-contract and registry-tool
assertions against a single archive-installed namespace in a fresh R process.
Development mode retains the historical/preflight groups. The hosted workflow
fetches full history and selects the appropriate mode; it cannot bypass private
checks by deleting working-tree folders. Two focused tests / six assertions
passed, including a private-history deletion bypass. Full positive public-mode
integration is part of the final exact archive check and is not yet claimed.
