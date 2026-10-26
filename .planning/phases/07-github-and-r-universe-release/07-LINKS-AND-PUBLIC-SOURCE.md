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

The existing release CLI already prepares a separate initial public Git root
from an exact committed allowlist, with no remote or development parents. Its
local staging and identity checks will be exercised against the updated source.
Later releases must append only public history; the initial-root staging command
is not a repeat-release fast-forward mechanism and must not be force-pushed over
an existing public branch.

Verification evidence and the local staged snapshot are external under
`/tmp/GEModelR-links-u1vDCw`. Final local documentation and root-history results
will be recorded after execution. No frozen earlier packet is rewritten.
