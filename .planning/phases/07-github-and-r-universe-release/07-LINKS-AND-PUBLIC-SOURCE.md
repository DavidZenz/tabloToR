# Pending publication links and development/publication split

The maintainer requested URL updates, explicitly selected keeping GEModelR as
the destination with publication links pending, then created
`git@github.com:DavidZenz/GEModelR.git` and requested a full-history development /
clean-history publication split. This authorizes local preparation and link
edits. Keep-local remains active; no push, tag, settings change, or deployment
is implied.

Read-only GitHub metadata confirms public repository ID `1434914481`, empty
history and enabled issues. The default-branch preference is main, but no branch
commit exists yet. The existing development origin is unchanged. The canonical
repository and issues endpoints are now available; the documentation site and
first public source snapshot remain pending. The previous development repo's
issue tracker is disabled and is not substituted as the reporting channel.

Local migration navigation now points to the bundled legacy-to-sparse article.
The two affected vignettes use local guide/source-checkout references instead of
an unavailable remote master file. The future complete migration reference is
documented on main. DESCRIPTION keeps the selected canonical GEModelR endpoints;
the planned Pages address is not relabeled as live.

The source archive intentionally omits repository site config and the curated
landing page. The documentation builder now stages those exact two checkout
files into its extracted build source before rendering; it rejects missing or
linked inputs. This keeps archive cleanup intact and the configured local
navigation testable. Package R/native implementations are unchanged.

The existing release CLI prepares a separate initial public Git root from an
exact committed allowlist, with no remote or development parents. Local staging
and identity checks pass against the updated source.
Later releases must append only public history; the initial-root staging command
is not a repeat-release fast-forward mechanism and must not be force-pushed over
an existing public branch.

Verification evidence and the local staged snapshot are external under
`/tmp/GEModelR-links-u1vDCw`. No frozen earlier packet is rewritten.

## Verified local results — 2026-10-26

- Development source: `610fefa6f15aadb26b8489a684dfb95b75b6d987`.
- Public root: `779203999966db0c664936536f5c7c2b2cfa3187`.
- Public tree: `3c2d2afe35c1787c2d2cd251f28e931cc3f34045`.
- Packet: `/tmp/GEModelR-links-u1vDCw/packet-git220`.
- Review-content SHA256: `1c9c576258d40df87f466f3dafe05a25e4cd9d4da5121bd2e0197e2227c02d9e`.
- Packet verification passes. Independent history proof confirms one commit,
  no parents, branch main, no remotes, 202 public files, no `.planning/` or
  `docs/release/` or `docs/provenance/` paths, and no development commit object.
  The local checkout is `packet-git220/private/public-source`.
- Actual staging first reproduced `GIT_READ_FAILED`: Git 2.20.1 does not support
  the newer init branch/format options. Commit `610fefa` uses ordinary SHA-1
  init plus symbolic-ref, retaining the explicit format option for SHA-256.
  All 24 release-tool tests pass, including branch, root and absent-development
  object assertions. The failed intermediate packet remains separate.
- The updated finite identity occurrence allowlist is
  `3749d2f121715390a7037bfbcd97e55b83155c1384dfd2ea9850a739f6011537`.
  Exactly one existing row changed (`pkgdown/index.md`); no rows were added or
  removed. Both identity audits pass, with counts 421/2 and unchanged normalized
  runtime fingerprint `99cc904fa2d5934dd9aa8294782175ad`.
- A separate clean clone of the public root built the source archive and all
  vignettes successfully. Archive SHA256:
  `1b76add7bc4aa82b5f1ed8c5c070977671e7a8e6d918eb668a48508fd4036d90`
  (284046 bytes, 183 archive entries). This is a documentation build archive,
  not a newly qualified release archive or replacement for prior check evidence.
- The full pkgdown builder passes from that archive plus the exact checkout
  config/landing page. Site and artifact scans both pass (61 entries each).
  Rendered home/navbar, backend article and installed-vignette migration links
  resolve to existing local guide files; obsolete master migration links are
  absent. Output: `/tmp/GEModelR-links-u1vDCw/site-run/pkgdown-site`.
- Logs retain the pre-existing serialized-fixture R >=3.5 build warning and
  Pandoc highlight-option deprecation messages. No new full R CMD check or GTAP
  benchmark was run for these documentation/tooling changes; prior numerical
  check evidence remains tied to its original source/archive.
- Read-only GitHub metadata confirms the canonical repository is still empty.
  Repository/issues HTTP endpoints return 200. GitHub returns a 200 empty-repo
  shell even for the future main/MIGRATION URL; the contents API correctly
  returns 404 with "This repository is empty." Pages remains HTTP 404. The
  source guide and Pages are still pending publication.
- All sixteen preserved pre-existing file hashes remain unchanged. Development
  development origin (SSH port 443) and upstream remotes remain unchanged.
  Shared R libraries were not changed. No push, tag, deployment or remote setting
  change occurred; the packet remains unqualified and publication_authorized=false.

Reproducible staging commands from the development checkout (choose a new empty
external output directory for another run):

```sh
rtk node tools/release/prepare-release.cjs prepare --source-ref 610fefa6f15aadb26b8489a684dfb95b75b6d987 --output /tmp/GEModelR-new-packet --tag v0.1.0
rtk node tools/release/prepare-release.cjs stage-public-source --packet /tmp/GEModelR-new-packet
rtk node tools/release/prepare-release.cjs verify --packet /tmp/GEModelR-new-packet
rtk node --test tools/release/prepare-release.test.cjs
```

Build the docs in a separate clone of the public root: run `R CMD build` with
the supported isolated Matrix library, Pandoc and qpdf, then put the built archive
in that checkout and run `Rscript --vanilla tools/ci/build-pkgdown-site.R` with
an external RUNNER_TEMP. Exact local logs are `logs/archive-build.log` and
`logs/site-build.log`; the standalone link checker is `check-local-links.R`.
Do not build inside or add remotes to the frozen packet checkout. Its structural
verification is not publication approval, provenance approval, or a successful
release qualification. The separate standing release limitations remain intact.
