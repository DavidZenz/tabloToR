# Deferred Items

- **Pre-existing provenance/release-gate mismatch:** `R CMD check .` reports 10 unrelated failures because the fresh provenance inventory now has 280 rows after Phase 02 source additions while the Phase 1 canonical test still expects 250, producing `PROVENANCE_KEY_MISMATCH`. All Phase 02 focused gates pass; Phase 02 does not alter the reviewed provenance oracle or release-gate artifacts.
