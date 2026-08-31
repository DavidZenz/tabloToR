# Deferred Items — Phase 01


- The exact `R CMD check .` now passes after host toolchain repair, but retains pre-existing release-hygiene diagnostics: undocumented exported objects/S4 class, hidden development files included by the build, and an installed-size note. The nonstandard License note is intentional until the dependency compatibility audit resolves the package license.
