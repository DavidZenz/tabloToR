---
phase: 06-documentation-and-release-qualification
plan: 05
subsystem: benchmark-evidence
tags: [GTAP 12a, benchmark, unsigned evidence, provenance]

requires:
  - phase: 06-02
    provides: External full-scale benchmark instructions
  - phase: 06-04
    provides: Release boundaries and exact current blockers
provides:
  - Repository-only procedure for running and checking the full-scale A/B benchmark
  - Redacted public summary fields and an explicit unsigned-evidence policy
  - Completed C++-only full-scale zero-shock and nonzero-shock measurements retained outside the repository
  - Completed external C++ thread-scaling diagnostic across 1, 4, 8, and 12 threads; no matched-reference gate was run
affects: [NUM-03, phase-06 release qualification]

actuals:
  tasks_complete: 1
  tasks_total: 2
  commits: 1

key-files:
  created:
    - docs/release/BENCHMARK-EVIDENCE.md

key-decisions:
  - "A GPG key is not required for numerical benchmark acceptance; the result summary is explicitly unsigned."
  - "Treat MD5-derived model, package, pair, and run values as fingerprints, not author authentication."
  - "Keep all GTAP inputs and detailed run outputs outside the repository."
  - "Treat the 12-run C++ thread-scaling result as diagnostic evidence only; keep NUM-03 pending without a matched R/C++ gate."
  - "Do not change solver defaults based on the near-flat 8-thread versus 12-thread result."

requirements-completed: []

coverage:
  - id: D1
    description: "Benchmark run, acceptance, redaction, and unsigned-evidence procedure"
    requirement: NUM-03
    verification:
      - kind: other
        ref: "Required-content scan for runner, checker, gate fields, fingerprint policy, and unsigned status"
        status: pass
    human_judgment: false
  - id: D2
    description: "Current full-scale run and independent gate"
    requirement: NUM-03
    verification:
      - kind: external
        ref: "C++-only zero-shock and nonzero-shock runs plus a 12-run thread-scaling diagnostic completed; no matched reference or A/B gate was run"
        status: in-progress
    human_judgment: false

duration: 19h38m including the external C++ thread-scaling run
completed: 2026-10-15
status: in-progress
---

# Phase 06 Plan 05: Benchmark Evidence Procedure Summary

**The local inputs, closure, output directory, and exact source installation are prepared. The result will be unsigned; no GPG key is needed.**

## Accomplishments

- Documented the existing A/B runner, independent gate invocation, required NUM-03 result fields, output redaction, and unchanged acceptance thresholds.
- Updated the procedure to require the benchmark gate and independent checker while explicitly omitting cryptographic author authentication.
- Kept MD5 values labeled as fingerprints and retained the separate Phase 1 legal and attribution blockers.
- Staged the four runner inputs outside the repository with private permissions and created the closure RDS from the existing 53-variable GTAPinR example closure.
- Built the source archive from commit `ae3ba3cb1e16e18ad1bd0567a91d2933580b13be` and installed GEModelR 0.1.0 into a temporary library. Archive SHA-256: `8d3774d787dcef7b8f7a95c1a85e41093161e454ac7386241da1e72b5ca372fc`.
- Confirmed the host has 12 logical CPUs and 62 GiB RAM. The benchmark explicitly requested four threads; native diagnostics reported four effective threads.
- Following the user's direction, stopped the R reference run. The initial C++ cycle (one warm-up plus three measurements) had no shock and an all-zero solution; it is retained as historical evidence only.
- Followed that with four measured C++ runs under a nonzero shock: `aoreg[GBR] = 1` (+1 percentage point of region-specific output-augmenting productivity), with no warm-up and no R baseline. All four completed with finite outputs, no dense full-system operations, identical solution vectors, and the same maximum full relative residual (`7.95680055533905e-08`). The solution had 26,781,398 entries and was nonzero.
- Completed a separate C++ thread-scaling diagnostic on 2026-10-16/17 using the same nonzero shock, installed GEModelR 0.1.0 build (`a6fb6102aca4dcc893e091be050ede61` package fingerprint; source commit `901fcb0c070f802b6ca0e4e15604de5e0e0c39bd`), `iter=3`, `steps=1,3`, postsimulation enabled, panel size 64, region batch size 16, and no memory budget. The 12 measured runs were interleaved across 1, 4, 8, and 12 threads, three per setting, with no warm-up and no R baseline. Solver wall time from first launch to last completion was 19h37m26s. The host had 12 logical CPUs and 62.9 GiB physical RAM.
- The candidate-only scaling summary gate passed after all runs completed. Every run completed with finite solution and selected outputs, no dense full-system operations, maximum full relative residual `7.95680055533905e-08`, and zero maximum absolute solution difference from the one-thread result. All runs had matching pair signatures. This is not the matched A/B gate and does not complete NUM-03.
- Thread-scaling medians (ranges) were: 1 thread, solve 10,401 s (10,379–10,633), Schur build 8,199 s (8,173–8,356), peak RSS 31.35 GiB (31.27–31.57); 4 threads, 4,644 s (4,626–4,679), 2,452 s (2,439–2,466), 30.68 GiB (30.68–30.68); 8 threads, 4,076 s (4,056–4,127), 1,870 s (1,767–1,912), 31.05 GiB (30.53–31.37); 12 threads, 4,096 s (4,042–4,154), 1,866 s (1,834–1,881), 31.41 GiB (30.67–31.63). Solve-time speedups versus one thread were 2.24x, 2.55x, and 2.54x for 4, 8, and 12 threads; versus four threads, 8 and 12 threads were 1.14x and 1.13x. The 12-thread median was 0.5% slower than the 8-thread median.
- `pidstat` observed up to 1, 4, 8, and 12 simultaneously active solver threads at the respective settings. Mean process CPU was approximately 100%, 250%, 362%, and 422%, or about 1.0, 2.5, 3.6, and 4.2 fully busy core equivalents across each whole run. This shows that the OpenMP loop can use the requested workers, while whole-run work averages substantially fewer cores; it does not isolate a single bottleneck. Per-core `mpstat` and per-thread `pidstat` logs remain external.
- The launcher's first summary-only invocation used a bare flag and exited before starting any extra solve; it did not alter the 12 completed measurements. Re-running the summarizer with `--summarize-only=true` passed its correctness and scaling gate. The external output directory contains the per-run CSV/RDS records and CPU logs; none were added to the repository.
- Shock-run elapsed times were 6,434.333, 5,064.091, 4,986.797, and 5,024.168 seconds (median 5,044.130 seconds; range 4,986.797–6,434.333 seconds). The first run was notably slower; a memory-heavy task had recently competed for resources, but its precise contribution is unmeasured. Runs 2–4 ranged from 4,986.797 to 5,064.091 seconds. Peak RSS ranged from 28.284 to 29.638 GiB.
- Investigated CPU use: the benchmark requested four threads on a 12-logical-CPU host, and native diagnostics confirmed four effective threads. OpenMP is used for the regional Schur batch loop in `src/sparse-schur-openmp.cpp`; the global Schur pass, factor setup, regional dense factor/solve loops, and other R-side phases remain serial. Process snapshots showed one busy thread during serial work and up to four in the OpenMP section. The low whole-run host utilization therefore reflects both the explicit four-thread cap and limited parallel coverage, not an OS CPU quota.
- Raw records and solutions for both candidate-only cycles remain outside the repository.

## Pending Task: Matched A/B Acceptance

The candidate-only measurements do not provide a matched reference record, so
the A/B checker was not run and NUM-03 remains pending. The existing R baseline
is retained as historical; it was not rerun. The initial C++ cycle had no
shocks file and an all-zero solution. The later four-run C++ follow-up and the
12-run thread-scaling diagnostic used the nonzero GBR productivity shock above.
They provide candidate-only solve and scaling evidence, but no matched R/C++
comparison or NUM-03 A/B gate pass.

The candidate-only summaries and full records are stored outside the checkout.
The earlier four-run shock CSVs have `git_commit=NA` because the shell's
Homebrew Git binary could not run against the host glibc; the later
thread-scaling CSVs recorded source commit
`901fcb0c070f802b6ca0e4e15604de5e0e0c39bd`. The source archive SHA-256 remains
available from the package-build record.

## Next Step

Keep NUM-03 pending until a matched-reference policy is established and its
corresponding comparison gate passes. The user directed that the R baseline not
be rerun; do not start it unless the user redirects that decision. Do not
describe the C++-only measurements as a current A/B acceptance result.

---
*Phase: 06-documentation-and-release-qualification*
*Status: in progress*
