# Deferred Items

- **Pre-existing provenance/release-gate mismatch:** `R CMD check .` reports 10 unrelated failures because the fresh provenance inventory has 251 rows while the Phase 1 canonical test still expects 250, producing `PROVENANCE_KEY_MISMATCH`. Plan 02-03 focused numerical tests pass; this plan does not alter provenance or release-gate artifacts.
