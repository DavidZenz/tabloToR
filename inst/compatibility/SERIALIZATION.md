# GEModel serialization contract

## Supported portable format

`model$saveState(file)` is the supported persistence entry point. It writes one
plain-list payload with `saveRDS(payload, file, version = 3L)`. The payload uses
schema identifier `gemodel-logical-state` and schema version 1. Its top-level
allowlist is:

- `schema` and `schema_version`;
- `source`, containing the TABLO name, exact source bytes, source fingerprint,
  logical input data, and input-data fingerprint;
- `engine`, mutable `levels`, `closure`, and normalized `shocks`;
- accepted `solution`, public `data`, and `compact_output`;
- `memory_budget` and portable `diagnostics`.

Empty vectors and lists, singleton arrays, `NULL` list members, names,
dimensions, dimnames, missing values, and character encodings are retained by
the RDS transport and validated as part of the logical field structure.

`model$loadState(file)` reads artifacts from a trusted local boundary. It
rejects non-regular or empty files and checks the compressed file-size limit
before RDS decoding. The decoded envelope is then checked for exact schema and
field allowlists, primitive types, permitted attributes, dimensions,
finiteness, element and byte limits, and both source fingerprints before an
isolated replacement model is constructed. Reconstruction uses the public
`loadTablo()` and `loadData()` workflow, then verifies closure and shock
identity, level names and dimensions, accepted solution size, and output
allowlists against that reconstructed model. An existing receiver is not
mutated unless every validation and reconstruction step completes.

## Deliberately excluded runtime state

The supported payload never contains environments, functions, external
pointers, native factor handles, solver cache entries, compiler workspaces,
derived sparse indexes/specifications, or transient applied-shock and
post-simulation retry progress. Compiler functions and indexes are reconstructed
from the recorded source. Sparse/native cache and factor state start empty and
are rebuilt independently by later backend work; a Matrix solve does not create
a native cache entry.

The serialized source and loaded data are sufficient to rebuild the model; the
fingerprints detect identity mismatch or accidental artifact corruption. MD5 is
used only as deterministic local change detection, not as an authenticity or
security signature. Do not load payloads from untrusted parties: base R must
decode the RDS object before package-level allowlist validation can run.

The default maximum logical payload and input file size is 256 MiB and the
default per-value element limit is 50 million. Maintainers may lower these
limits with `options(tabloToR.serialization.max_bytes = ...)` and
`options(tabloToR.serialization.max_elements = ...)` for constrained local
workflows.

## Compatibility-only raw object persistence

`saveRDS(model)` followed by `readRDS()` remains same-version compatibility-only
best effort. Raw reference-object serialization captures implementation
environments and generated functions, can be much larger than logical state,
and is not a stable portable or cross-version contract. It must not be used to
deserialize arbitrary untrusted reference objects and does not redefine the
supported `gemodel-logical-state` schema.
