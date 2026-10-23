# Phase 07: GitHub and R-universe Release — Pattern Map

**Mapped:** 2026-10-23
**Scope:** Local release preparation, exact artifact identity, installed smoke, registry draft, and publication handoff.
**Primary analog families:** 5; source excerpts inspected from 8 files.

Paths for new files below are suggested assignments for the planner, not a claim that these files already exist. Keep the final file set small; combine documents where that improves the handoff.

## File Classification

| New/modified file or artifact | Role | Data flow | Closest analog | Match quality |
|---|---|---|---|---|
| `tools/release/prepare-release.cjs` (candidate local packet entry point) | utility | file-I/O, batch, transform | `.github/workflows/release-qualification.yaml` plus scanner CLI | behavior match; new orchestration shape |
| `tools/release/prepare-release.test.cjs` | test | batch, file-I/O | `tools/ci/check-public-content.test.cjs` | exact runtime/test style |
| `tools/ci/run-installed-release-smoke.R` | utility | batch, file-I/O | `tools/ci/run-installed-core-tests.R`, first-simulation fixture | exact installation boundary and public workflow |
| External packet manifest/status files | config | transform, file-I/O | workflow qualification-context/archive-identity/status files | exact evidence shape |
| `docs/release/runiverse/packages.json` (local registry draft) | config | transform | none for registry schema; use RESEARCH.md | no close analog |
| `docs/release/PUBLICATION-PLAN.md` (source/ref inventory and final action list) | config/documentation | file-I/O, transform | `docs/release/REPOSITORY.md` | exact authority and source-history boundary |
| Local release notes, installation instructions, and support-policy draft; eventual selected `NEWS.md`/`README.md`/`GOVERNANCE.md` edits | documentation | transform | existing release identity record for explicit facts/authority; research for content | partial; no dedicated release-note template found |
| Existing qualification/publishing workflow changes, only if required by final plan | config | event-driven, batch | `.github/workflows/release-qualification.yaml` | exact CI conventions |

## Pattern Assignments

### Local packet preparation and exact artifact status

**Primary analog:** `.github/workflows/release-qualification.yaml`.

Copy its separation of isolated destinations (lines 56–60), source/runtime context (62–87), one archive identity (93–115), scan (117–128), actual check status (130–187), and always-recorded outcome (189–232). Implement local orchestration around an explicit selected Git revision/export, rather than copying the workflow's dirty-working-directory assumption into a local tool.

**Isolation pattern** (lines 56–60):

```yaml
- name: Initialize isolated qualification paths
  shell: bash
  run: |
    mkdir -p "$RUNNER_TEMP/release-evidence" "$RUNNER_TEMP/release-check" "$RUNNER_TEMP/release-library"
    printf '%s\n' "GEModelR_RELEASE_EVIDENCE_DIR=$RUNNER_TEMP/release-evidence" "GEModelR_RELEASE_CHECK_DIR=$RUNNER_TEMP/release-check" "GEModelR_RELEASE_LIBRARY=$RUNNER_TEMP/release-library" >> "$GITHUB_ENV"
```

**Exact archive identity** (lines 106–115):

```bash
mapfile -t archives < <(find "$GITHUB_WORKSPACE" -maxdepth 1 -type f -name 'GEModelR_*.tar.gz' -print)
if [[ ${#archives[@]} -ne 1 ]]; then
  echo "Expected exactly one GEModelR source archive; found ${#archives[@]}"
  printf 'build_exit_status=1\n' >> "$GITHUB_OUTPUT"
  exit 1
fi
archive_sha256=$(sha256sum "${archives[0]}" | awk '{print $1}')
printf '%s\n' "GEModelR_SOURCE_ARCHIVE=${archives[0]}" >> "$GITHUB_ENV"
printf 'archive_path=%s\narchive_sha256=%s\n' "${archives[0]}" "$archive_sha256" > "$GEModelR_RELEASE_EVIDENCE_DIR/archive-identity.txt"
```

For new portable Node code, use Node built-ins for paths, hashing, and argument-vector child processes; the shell excerpt identifies the behavior to preserve, not a requirement to introduce GNU-only shell dependencies. Record the selected commit/tree before packaging and preserve a difference between source selection, archive identity, scan result, install result, and unavailable checks. Do not mark preparation failed merely because a later supported-runtime or publication step is unavailable.

**Missing-value semantics** (workflow lines 213–231): `value_or` substitutes `not_available` for unavailable identities and `not_run` for unexecuted steps. Reuse those meanings; never turn an absent check into a zero/`passed` value.

### Scanner integration and focused regression tests

**Analogs:** `tools/ci/check-public-content.cjs` lines 564–606 and `tools/ci/check-public-content.test.cjs` lines 1–120.

**Supported integration seam** (scanner lines 564–568):

```javascript
function inspect(mode, target) {
  if (mode === "--archive") return inspectArchive(target);
  if (mode === "--site") return inspectDirectory(target, "site");
  if (mode === "--artifact-dir") return inspectDirectory(target, "artifact");
  fail("unknown mode " + mode);
}
```

`inspect` is exported (lines 600–605). Its CLI emits each violation and exits nonzero (579–596). Prefer this existing seam or invoke the existing CLI with an argument array. It has no public-Git-history mode: do not weaken its package/site/evidence policy to scan a complete repository. Source-tree/ref/history review is a separate packet concern.

**Node imports and subprocess convention** (test lines 1–11, 47–50):

```javascript
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

function runChecker(args) {
  return spawnSync(process.execPath, [checker, ...args], {
    encoding: "utf8"
  });
}
```

**Temporary fixture cleanup** (test lines 53–59):

```javascript
function withTempDirectory(callback) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "gemodelr-public-content-"));
  try {
    callback(root);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}
```

Copy result assertions from tests lines 75–77 (`status === 0`, explicit success output) and 103–107 (`status === 1`, stable failure reason). For a new packet tool, meaningful fixtures cover revision/tree selection, changed asset digest, dirty/untracked canary exclusion, output collisions, and no implicit remote actions. Reuse the existing scanner fixture builder only when archive-content behavior itself is under test; do not add a new framework.

### Installed release smoke

**Analog:** `tools/ci/run-installed-core-tests.R` lines 3–55 and 81–99.

**Explicit library and namespace ownership** (lines 20–31):

```r
lib = normalizePath(requiredEnvironment("GEModelR_TEST_LIBRARY"),
                    winslash = "/", mustWork = TRUE)
packagePath = normalizePath(file.path(lib, "GEModelR"),
                            winslash = "/", mustWork = TRUE)
.libPaths(c(lib, .libPaths()))
library(GEModelR, lib.loc = lib)
library(Matrix)
loadedPath = normalizePath(getNamespaceInfo(asNamespace("GEModelR"), "path"),
                           winslash = "/", mustWork = TRUE)
stopifnot(identical(loadedPath, packagePath))
stopifnot(identical(normalizePath(find.package("GEModelR"), winslash = "/"),
                    packagePath))
```

Reuse the runtime floor validation at lines 33–55. Run a new smoke with `Rscript --vanilla` in a fresh process; do not source the package or reload its namespace mid-run. The unrelated-directory/cleanup pattern is at lines 81–89:

```r
originalWorkdir = getwd()
workdir = tempfile("GEModelR-installed-core-")
dir.create(workdir)
on.exit({
  setwd(originalWorkdir)
  unlink(workdir, recursive = TRUE)
}, add = TRUE)
setwd(workdir)
```

The new smoke does not need to invoke the entire installed test suite: it needs the documented public installation/use contract and an explicit numerical expectation.

### Redistributable public model and numerical assertion

**Analogs:** `vignettes/helpers.R` lines 1–39; `vignettes/first-simulation.Rmd` lines 37–62; `tests/testthat/test-documented-workflow.R` lines 102–112.

Make the smoke distribution self-contained. The helper writes a three-region TABLO file and supplies in-memory arrays with weights `c(1, 1.5, 2)` and stocks `c(100, 200, 300)`; it needs no HAR/private GTAP input. Copy that tiny fixture definition into the selected smoke artifact or deliberately install an agreed helper; do not assume an installed package contains a source checkout's `vignettes/helpers.R`.

**Public workflow** (vignette lines 38–42, 52–62):

```r
fixture = makeFirstSimulationFixture()
model = GEModelR::GEModel$new()
model$loadTablo(fixture$tabloPath)
model$setClosure("tax")
model$loadData(fixture$inputData, engine = "sparse")
model$setShocks(setNames(4, 'tax["south"]'))
model$solveModel(
  iter = 1,
  steps = 1,
  engine = "sparse",
  postsim = FALSE,
  diagnostics = TRUE,
  output = "full",
  backend = "Matrix",
  reduction = "off"
)
```

**Existing independent expectation** (documented-workflow test line 111):

```r
expect_equal(unname(preferred$solution), c(0, 6, 0), tolerance = 1e-12)
```

For a standalone runner, express this with a finite-value check and `all.equal(..., tolerance = 1e-12)`/`stopifnot`, then record the actual installed package version/source identity. A printed solution alone is not a passing smoke result.

### Publication packet, registry draft, and documentation

**Analog:** `docs/release/REPOSITORY.md` lines 3–27, 43–78, and 105–112.

Copy its explicit facts/authority style without changing its canonical markers during local preparation:

```text
Owner-Slug: DavidZenz
Repository-Name: GEModelR
Canonical-URL: https://github.com/DavidZenz/GEModelR
Issue-Tracker: https://github.com/DavidZenz/GEModelR/issues
Visibility-Boundary: private-development
Release-Authorization: not-authorized
```

The metadata inventory at lines 45–62 covers refs/objects plus separately stored GitHub metadata and secret names only; lines 64–78 describe identity comparison and recovery without destructive defaults. Use these as the handoff pattern for the exact proposed public tree/history and external action list. A package `.Rbuildignore` does not dispose of public Git history.

The final concrete decision should name source commit/tree, version/tag type, archive digest, intended public refs/history, destinations, registry changes, notes, known limits, and any settings/app actions. It comes after useful local preparation. Keep Phase 06 accepted and its recorded limitations visible; do not recreate its gap loop.

For the new registry JSON, follow the official schema already researched in `07-RESEARCH.md`: an array with `package`, canonical Git `url`, and an explicit release-tag `branch`. No local package registry analog exists. Parse the draft and compare identity/tag against the packet; that is static validation, not a deployed-channel claim.

Support cadence, final version/tag, signature choice, and publication destinations need concrete proposals in the packet. Preserve selected GPL-3.0-or-later and current development metadata until an explicit release-boundary task changes them. Do not invent a key installation requirement or call an unsigned tag signed.

## Shared Patterns

- **R conventions:** Two-space indentation, `=` assignment, camelCase helpers, explicit strings/numerics, `stop(..., call. = FALSE)` for actionable input failures; see installed runner lines 3–18.
- **CLI boundaries:** Explicit input/library/output paths; argument-vector child processes; nonzero failure status with stable reason; Node built-ins and base R rather than new dependencies.
- **Artifact integrity:** One selected source revision, one retained archive identity, scans/checks attributed to those exact bytes, and honest `not_run`/`not_available` outcomes.
- **Authority:** Read-only checkout credentials in CI (`contents: read`, `persist-credentials: false`, workflow lines 9–20); local packet generation must not mutate remotes/settings/refs/services.
- **Privacy:** Stage public artifacts deliberately, then scan them. Keep private source/history inventories outside public evidence. Never include raw private input paths, credentials, large outputs, or arbitrary dirty work.
- **Execution scope:** No tests/builds/installs were run for this map. New executable logic should receive focused tests during implementation; prose changes need consistency review. Existing Phase 06 waivers remain honored.

## No Analog Found

| Capability | Reason / planning consequence |
|---|---|
| R-universe `packages.json` | No registry file was found; use the researched official schema and a tag-pinned local draft. |
| Explicit committed-source export and public Git ref/history projection | The qualification workflow checks its current checkout, not a dirty-development export/projection. Define this deliberately; never silently mirror all refs or rewrite canonical provenance. |
| Unified local packet builder | Existing workflow provides strong behavior pieces but no single local packet implementation; keep any new orchestration thin and tested. |
| Dedicated initial release-note/support-policy template | Draft concrete policy from existing identity/governance and package documentation; do not imply a new cadence is already approved. |

## Metadata

**Analog search scope:** Release workflow, existing Node scanner/test entry points, installed R runner, deterministic vignette fixture/public example, numerical expectation, and canonical repository record.
**Source files inspected:** 8; analog search stopped after five reusable families.
**Project skills:** `.codex/skills/` and `.agents/skills/` are absent.
**Writes:** This PATTERNS.md only; no source edits, commits, tests, builds, installs, or external writes.
