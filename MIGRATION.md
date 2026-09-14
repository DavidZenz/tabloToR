# Migrating from tabloToR to GEModelR

GEModelR immediately replaces the predecessor package identity. It does not provide a `tabloToR` shim.
It does not inspect or uninstall another installed package and does not scan options at startup.
Update source and dependency
declarations explicitly.

## Install GEModelR

Remove the predecessor package from the active library, then install GEModelR
from a local checkout:

```r
remove.packages("tabloToR")
```

```sh
R CMD INSTALL .
```

To install a local checkout at an immutable Git commit, capture and verify the
current commit before installing it:

```sh
GEMODELR_REF="$(git rev-parse HEAD)"
git rev-parse --verify "$GEMODELR_REF^{commit}"
git checkout --detach "$GEMODELR_REF"
R CMD INSTALL .
```

This does not publish, push, tag, or change any remote.

## Replace package use in scripts and dependencies

Apply these exact source replacements:

| Before | After |
|---|---|
| `library(tabloToR)` | `library(GEModelR)` |
| `require(tabloToR)` | `require(GEModelR)` |
| `tabloToR::` | `GEModelR::` |

For example:

```r
model = GEModelR::GEModel$new()
```

Replace the package name wherever it appears in a downstream `DESCRIPTION`
dependency field:

```text
Imports: tabloToR
Depends: tabloToR
Suggests: tabloToR
Enhances: tabloToR
```

becomes:

```text
Imports: GEModelR
Depends: GEModelR
Suggests: GEModelR
Enhances: GEModelR
```

Preserve any version constraint while replacing only the package name.

For an `renv` project, perform the rename through installation and snapshotting:

```r
remove.packages("tabloToR")
renv::install(".")
renv::snapshot()
```

Run `renv::install(".")` before `renv::snapshot()`.
Do not edit `renv.lock` manually.

## Replace runtime options

Replace each supported public option exactly. A predecessor option is rejected
when its relevant operation runs; GEModelR does not silently honor it and does
not perform a package-startup scan.

Each rejection names the predecessor key, its exact GEModelR replacement, and
this guide. The same twelve-row contract is installed at
`migration/option-replacements.dcf`.

| Before | After |
|---|---|
| `tabloToR.sparse.lu_order` | `GEModelR.sparse.lu_order` |
| `tabloToR.sparse.suite_sparse_ordering` | `GEModelR.sparse.suite_sparse_ordering` |
| `tabloToR.sparse.structured_residual_tolerance` | `GEModelR.sparse.structured_residual_tolerance` |
| `tabloToR.sparse.schur_tolerance` | `GEModelR.sparse.schur_tolerance` |
| `tabloToR.sparse.schur_region_batch_size` | `GEModelR.sparse.schur_region_batch_size` |
| `tabloToR.sparse.schur_panel_size` | `GEModelR.sparse.schur_panel_size` |
| `tabloToR.sparse.schur_restart` | `GEModelR.sparse.schur_restart` |
| `tabloToR.sparse.schur_max_iterations` | `GEModelR.sparse.schur_max_iterations` |
| `tabloToR.sparse.schur_refinement_iterations` | `GEModelR.sparse.schur_refinement_iterations` |
| `tabloToR.sparse.schur_cpp_threads` | `GEModelR.sparse.schur_cpp_threads` |
| `tabloToR.serialization.max_bytes` | `GEModelR.serialization.max_bytes` |
| `tabloToR.serialization.max_elements` | `GEModelR.serialization.max_elements` |

The rename does not change option values, defaults, validation, precedence,
solver algorithms, or numerical tolerances.

## Convert saved models before upgrading

A raw `saveRDS(model)` ReferenceClass object is not portable across the package
rename. If that is the only saved form available, convert it with the approved
predecessor bridge before upgrading. Do not load a raw predecessor
ReferenceClass object in GEModelR.

The approved bridge is the predecessor package at immutable commit
`ea71afd98b4f165525b9bc0b853e25d4e8998cd8` from
`ssh://git@ssh.github.com:443/DavidZenz/tabloToR.git`. Place the raw model in the
current directory as `model-raw.rds`, then run this complete command block:

```sh
TABLOTOR_BRIDGE_ROOT="$(mktemp -d)"
export TABLOTOR_BRIDGE_SOURCE="$TABLOTOR_BRIDGE_ROOT/source"
export TABLOTOR_BRIDGE_LIB="$TABLOTOR_BRIDGE_ROOT/library"
export TABLOTOR_RAW_RDS="$(pwd)/model-raw.rds"
export TABLOTOR_LOGICAL_STATE="$(pwd)/model-logical-state.rds"
git clone --no-checkout \
  ssh://git@ssh.github.com:443/DavidZenz/tabloToR.git \
  "$TABLOTOR_BRIDGE_SOURCE"
git -C "$TABLOTOR_BRIDGE_SOURCE" checkout --detach \
  ea71afd98b4f165525b9bc0b853e25d4e8998cd8
mkdir -p "$TABLOTOR_BRIDGE_LIB"
R CMD INSTALL --library="$TABLOTOR_BRIDGE_LIB" "$TABLOTOR_BRIDGE_SOURCE"
R --vanilla -q -e 'library(tabloToR, lib.loc = Sys.getenv("TABLOTOR_BRIDGE_LIB")); model = readRDS(Sys.getenv("TABLOTOR_RAW_RDS")); model$saveState(Sys.getenv("TABLOTOR_LOGICAL_STATE"))'
```

After installing GEModelR, restore the converted logical state through the
unchanged public class and method names:

```r
model = GEModelR::GEModel$new()
model$loadState("model-logical-state.rds")
```

GEModelR accepts predecessor `gemodel-logical-state` version `1L` only when the
state is tagged with a reviewed, allowlisted predecessor source fingerprint and
all existing TABLO, model, payload, type, dimension, finiteness, and size checks
pass. It rejects untagged or unallowlisted predecessor states. Accepted
predecessor identity is normalized in memory, and subsequent `saveState()` calls
write only GEModelR identity.

## Compatibility boundary

The `GEModel` class name, public methods, method signatures, broad namespace,
legacy engine default, Matrix backend default, solver algorithms, numerical
defaults, and tolerances remain unchanged by this documentation migration.
API narrowing belongs to a later phase.

This migration does not create a compatibility package, rewrite historical
Phase 2 or benchmark evidence, edit lockfiles directly, create GitHub Pages, or
authorize publication or remote mutation.
