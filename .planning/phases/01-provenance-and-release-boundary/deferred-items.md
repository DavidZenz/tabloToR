# Deferred Items — Phase 01

- `R CMD check` is blocked by a pre-existing toolchain mismatch: the Linuxbrew assembler requires newer GLIBC symbols than the Debian 10 runtime provides. The source-tree check also reports pre-existing ignored build artifacts and hidden benchmark experiments. These are unrelated to Plan 01-01 and remain for the portability/release-qualification phases.
