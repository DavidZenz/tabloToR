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
The tag proposal is `annotated_unsigned`; no GPG setup is required.

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
