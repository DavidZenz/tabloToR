# Deferred Items — Phase 01

- `R CMD check` is blocked by a pre-existing toolchain mismatch: the Linuxbrew assembler requires newer GLIBC symbols than the Debian 10 runtime provides. The source-tree check also reports pre-existing ignored build artifacts and hidden benchmark experiments. These are unrelated to Plan 01-01 and remain for the portability/release-qualification phases.

- A sanitized source-tarball check installs, loads, compiles, and passes tests, but retains pre-existing release-hygiene diagnostics: undocumented exported objects/S4 class, hidden development files included by the build, and an installed-size note. The nonstandard License note is intentional until the dependency compatibility audit resolves the package license.
