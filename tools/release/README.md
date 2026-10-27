# Local release packet

Run from the development Git checkout, choosing one committed revision:

```sh
rtk node tools/release/prepare-release.cjs prepare --source-ref HEAD --output /tmp/GEModelR-release-packet --tag v0.1.0
rtk node tools/release/prepare-release.cjs verify --packet /tmp/GEModelR-release-packet
```

The selected commit must contain `Package: GEModelR`, a numeric DESCRIPTION
version, and `tools/ci/run-installed-release-smoke.R`. The intended tag must be
`v` followed by that version. The command does not create or publish the tag.
An existing local tag may name the selected commit; a different target fails.
Output must be outside the source repository and cannot overwrite nonempty
output. Invalid commands return stable `FAIL CODE` messages without raw paths.

`private/source/` contains the selected committed files, excluding working-tree
edits and untracked files. It is private audit material, never an upload area.
`private/support/` retains the executing preparation and scanner scripts.
`private/manifest.json` records their inventories and SHA-256 fingerprints.
The original Git commit object stays private in `private/support/source-commit.txt`.
`public/` contains only the same-revision standalone smoke, a tag-pinned
R-universe registry draft, an allowlisted public manifest, and release notes
when the selected commit contains a draft. The existing public-content scanner
checks this public artifact directory. It does not qualify a public Git tree
or reachable repository history.

Verification validates field allowlists before reporting identity, rejects linked
packet entries before reading them, and reconstructs Git blob/tree identities
against the retained commit object. `INVALID_MANIFEST`, `PACKET_SYMLINK`,
`PACKET_CONTENT_CHANGED`, and `SOURCE_IDENTITY_MISMATCH` distinguish these failures.
It compares the whole governed file set and content fingerprints;
timestamps do not enter its content identity. Never edit a prepared packet to
make it pass: prepare a new reviewed candidate after a source change.

`preparation_status=prepared` and `status=verified` establish local packet
integrity only. `publication_authorized=false`, `publication_readiness=unqualified`,
`public_source_commit=not_created`, and unexecuted `checks` stay explicit.
Missing draft notes remain `release_notes_status=unavailable`. No installation,
package qualification, signature, public source selection, or release is claimed.
The initial tag proposal is `annotated_unsigned`; no GPG setup is required.

## Freeze the proposed public source

The selected commit must contain `docs/release/public-source.json`, with
`schema_version: 1`, an `include` array of paths and an `exclude` array of
`{path, reason}` objects. Exactly one disposition is required for every tracked
path in the selected commit. Private planning/release/provenance paths cannot
be included, and package implementation plus notices cannot be silently dropped.

```sh
rtk node tools/release/prepare-release.cjs stage-public-source --packet /tmp/GEModelR-release-packet
rtk node tools/release/prepare-release.cjs qualify --packet /tmp/GEModelR-release-packet --library /existing/supported-library
rtk node tools/release/prepare-release.cjs verify --packet /tmp/GEModelR-release-packet
rtk node tools/release/prepare-release.cjs verify --packet /tmp/GEModelR-release-packet --for-publication
```

Staging constructs a separate local repository with one deterministic root commit,
no configured remote, and exactly the selected committed blobs/modes. It preserves
both development and public commit/tree identities. The development repository's
history, refs, index and dirty files are untouched. The local public repository is
private review material, not automatically a publishable artifact or a mirror.
Only `main` and an optional matching intended tag are accepted; conflicting or
additional refs are rejected. No tag is created by these commands.

Qualification first probes the already-installed Matrix floor without loading or
installing a package. It retains one offline canonical release-guard result from
a private local clone of the selected development commit. That clone is guard-only.
Clone setup ignores inherited global/system Git settings and templates. After
checkout, raw committed blobs replace any tracked EOL/ident conversions. The
actual guard/build file set, blob bytes and executable modes (where the platform
supports them) are checked immediately before the corresponding command. A Git
HEAD/tree identifier alone is not proof of the files consumed by that command.

When supported prerequisites exist, it builds solely from this verified checkout of
the frozen projected public commit, then scans, checks and installs the same
retained archive. `archive_source_commit` must equal `public_source_commit`, and
the retained archive must match its declared SHA-256. The archive check requires
zero exit status, errors and warnings. The shared
`tools/ci/assess-r-cmd-check.cjs` assessor permits only three explicitly reviewed
informational NOTEs: CRAN “New submission” alone, inability to verify external
clock time, and an installed size no greater than 12 MB with only a native-library
subdirectory no greater than 10 MB. Additional messages (including invalid URLs),
unknown notes, duplicate check sections and size regressions fail. The original
status, counts, note bodies, log SHA256 and assessor SHA256 remain in private
assessment evidence. This GitHub-source policy was explicitly approved by the
maintainer on 2026-10-27 and does not claim CRAN acceptance. Supported R4.3 logs
need not contain a standalone URL line.

URL disposition is separate evidence from a dedicated R tools URL check against
the same verified source. It is `passed`, `failed`, `unavailable`, `not_applicable`
(no URLs), or `not_run`; disabled checks, missing capabilities or failed probes
never imply a network pass. Raw URL results stay private. Publication requires a
successful explicit URL disposition as well as all package checks; failed or
unavailable URLs remain blocking even if a clean package can install locally.

An unsupported runtime completes local preparation with
`qualification_status=unavailable`, archive fields `not_built`, and untouched
`not_run` package steps. Failed attempted commands keep their real exits/logs in
`private/evidence/`. Local integrity verification can pass in this state;
`--for-publication` rejects it. Qualification is recorded once per packet: prepare
a new packet to make another attempt. The review digest is the final private
manifest's `content_sha256`, covering artifact identities and qualification state.

Subprocess-injected unit fixtures are always marked `evidence_kind=fixture` and
can never qualify a real packet. This flag is unavailable in the CLI. Publication
readiness requires actual supported runtime, successful canonical guard, exact
archive/scan/check/install/smoke evidence, and matching selected identities.
Even a ready packet retains `publication_authorized=false`: the separate concrete
maintainer approval remains mandatory. No command here pushes, publishes,
dispatches hosted work or changes external settings.

Git object databases are excluded from the ordinary file inventory, because they
contain local Git bookkeeping; their repositories and allowed reachable refs,
root commit, tree, selected blobs, and absence of remotes are checked separately.
The projected repository and private original clone never enter the public assets.

The standalone smoke is invoked in a fresh process with an already supported
isolated package library:

```sh
rtk proxy env GEModelR_TEST_LIBRARY=/tmp/release-library GEModelR_EXPECTED_VERSION=0.1.0 GEModelR_DISTRIBUTION_CHANNEL=local GEModelR_EXPECTED_SOURCE_COMMIT=FULL_COMMIT Rscript --vanilla /tmp/GEModelR-release-packet/public/run-installed-release-smoke.R
```

Use `local`, `github`, or `runiverse` as the channel. For GitHub, the caller must
first verify the tag-to-clone/source identity. For R-universe, installed
`RemoteSha` must equal the expected commit. Other channels record the commit as
`caller_attested_source`; that field alone is not installed source provenance.
The script requires both Matrix >=1.6-5 and the selected package's declared floor,
loads the selected installed namespace once, works from an unrelated temporary
directory, and asserts the finite expected solution `c(0, 6, 0)` within `1e-12`.
It does not load source code or discover GTAP inputs. Unsupported libraries fail
with a stable code and never become a numerical pass through a mock test.

Focused checks are `rtk node --test tools/release/prepare-release.test.cjs
tools/ci/check-public-content.test.cjs` and an R parse of the standalone runner.
The DESCRIPTION-only unsupported-runtime fixtures prove rejection before loading;
they are not evidence that an installed package completed the numerical smoke.

Source-only administrative tests are separate from installed-package checks.
The baseline regeneration/acceptance tools are deliberately excluded from the
archive installation, and benchmark preflight scripts require a source checkout.
Those tests skip explicitly in installed contexts; their assertions must also run
from the selected committed source in another fresh process, using the package
installed from the same archive:

```sh
rtk proxy Rscript --vanilla tools/ci/run-source-tool-tests.R /path/to/selected-source /path/to/archive-library
```

For a projected public repository, add `--public-source`. That mode requires a
Git history without private planning/release/provenance paths and runs the public
license, build-contract, and name-check groups. Development mode retains the two
historical/preflight groups and the canonical private identity-record checks.
Both modes additionally require the source-mode
isolation regressions and use the same installed namespace.

Use the same supported dependency library as qualification (via `R_LIBS` when
needed). This runner requires all selected groups to execute with zero skips,
checks the installed namespace path, and never loads/reloads source package code.
The source-archive workflow also runs it as a separate required step. The local
packet CLI does not record this additional test result; retain its log alongside
the packet evidence. Keep the raw result separate from the packet manifest and
from the installed suite's status. PDF/HTML checks need actual `qpdf` and `tidy`
executables, and Markdown checks need Pandoc on `PATH`.

## Development and publication history

Keep the current development checkout's `origin` and full history unchanged.
The canonical `git@github.com:DavidZenz/GEModelR.git` repository is a separate
publication destination; the maintainer has created it as an empty public repo.
Its initial public branch is intended to be `main`.

For the first publication, `prepare` freezes one development commit and
`stage-public-source` writes only its explicit public allowlist into a new local
repository. That repository has one root commit, no development-history parents,
and no remote. Its public tree, source files and separate development/public
identities are verified before any publication decision. Do not push development
`master`, mirror development refs, copy `.git`, or merge development history into
the publication repository. The CLI commands above never push or deploy.

Later releases should append commits to the existing public release history from
a clean public checkout, applying only the new reviewed snapshot. Use normal
fast-forward updates and retain prior public tags; do not force-push another
orphan root. The current staging CLI prepares an initial root, so repeat-release
parenting must be handled explicitly before a later publication, rather than
assuming that a newly staged root can fast-forward the existing public branch.

The maintainer's creation of the empty target establishes its location, not
approval of any particular source snapshot, archive, tag, or hosted deployment.

The local qualification runner permits thirty minutes for the complete archive
check and five minutes for each other command. A timeout remains a real command
failure with its raw evidence retained.
