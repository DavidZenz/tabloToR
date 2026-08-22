# Technical Plan: Accelerating the Sparse Solver with Native C++

## 1. Objective and constraints

Accelerate the validated StructuredSchurFGMRES engine without changing the GEModel API, sparse numerical method, closure semantics, Euler stepping, or default residual tolerance. The implementation must preserve these invariants:

- Commodity blocks remain sparse throughout factorization and panel solves.
- No dense representation of the full coefficient or solution system is built.
- Every solve is checked against the full-system relative residual limit of 2e-7 before its solution is applied.
- engine = "legacy" remains available, and the current R implementation remains an explicitly selected correctness reference; an explicit native request never falls back.
- Native buffers and factors are released between solves unless explicitly retained as reusable structural metadata.

Dense LAPACK LU is not suitable for the commodity blocks. A typical block is approximately 2469 x 2469 but only about 2% structurally dense. Densifying one such block requires roughly 46.5 MiB and about 10 billion factorization operations. Dense LAPACK is reserved for the genuinely dense regional and global Schur blocks.

## 2. Measured baseline

The completed GTAP 12a benchmark used 163 regions, 65 commodities, 26,781,398 equations, 80,306,307 maximum nonzeros, iter = 3, steps = c(1, 3), and postsim = TRUE.

| Measurement | Result |
| --- | ---: |
| Full solve time | 18,608 s (5h 10m) |
| Sparse matrix emission | 622 s total; 51.9 s/solve |
| Factorization and structured solve | 17,027 s total; 1,419 s/solve |
| State/formula updates | 520 s total; 43.3 s/solve |
| Peak RSS | 29.6 GiB |
| Dense fallback | No |

The factorization/Schur phase accounts for more than 90% of measured solve time. A representative reduced solve used 65 sparse commodity blocks, 163 regional blocks, an external dimension of 113,783, and a global block of size 9. FGMRES converged in one reduced iteration; therefore the Krylov loop is not currently a meaningful optimization target.

## 3. Current hotspot

sparse_exact_schur_build() in R/sparseSchurComplement.R repeatedly:

1. extracts a sparse right-hand panel and converts it to a dense matrix;
2. dispatches Matrix::solve(sparseLU, panel) through R's S4 machinery;
3. multiplies sparse left blocks by the dense solution panel; and
4. allocates dense corrections that are immediately accumulated and discarded.

With the default 64-column panel, the GTAP structure causes roughly 115,000 panel iterations per solve. Some panels are structurally zero but are only identified after sparse slicing and dense allocation. The first optimization must reduce and instrument this work rather than replacing a sparse algorithm with a dense one.

## 4. Phase 0: instrumentation and no-code tuning

Add aggregate diagnostics to sparse_exact_schur_build():

- local and regional factorization time;
- panels inspected, zero panels skipped, and panels solved;
- right-panel extraction/coercion time;
- triangular-solve time;
- sparse-dense multiplication and accumulation time;
- columns solved and peak panel-buffer size; and
- regional/global correction time.

Do not emit one log record per panel. Store counters and phase totals in lastDiagnostics and the benchmark CSV.

Benchmark schur_panel_size = 64, 256, 512, 1024 using the same saved reduced system or one-step public API run. Record wall time, peak RSS, and full true residual. Select the largest panel that improves time without materially increasing peak memory. Repeat a smaller sweep of schur_region_batch_size only after panel behavior is understood.

This phase establishes how much time is S4 dispatch, sparse slicing, numeric factor solving, and multiplication. C++ work starts only from these measured results.

## 5. Phase 1: native sparse multi-RHS solve kernel

Implement a small, serial Rcpp kernel before porting the full builder:

    tabloToR_sparse_lu_solve(factor, rhs)

The kernel consumes Matrix's existing sparseLU representation:

- sparse triangular L and U dtCMatrix slots;
- row and column permutations p and q; and
- a dense, column-major multi-RHS panel.

It performs sparse forward/back substitution directly over the CSC slots and returns the same shape as Matrix::solve(). This preserves Matrix's trusted sparse factorization and ordering while removing repeated S4 method dispatch. Permutation handling must be derived from the factor contract and verified by tests, not inferred from one matrix.

Required kernel tests compare against Matrix::solve() for:

- one and many right-hand sides;
- random nonsymmetric sparse matrices and all supported LU orderings;
- nontrivial row and column permutations;
- zero columns, ill-scaled but nonsingular systems, and nonfinite rejection; and
- residual and maximum absolute solution error below 1e-10 on fixtures.

This drop-in kernel is a correctness and profiling milestone. It is not the final interface because one native call per panel would still leave excessive boundary crossings and allocations.

## 6. Phase 2: fused serial Schur accumulation

Implement a native batch kernel such as:

    tabloToR_schur_accumulate_batch(
      factors, left_blocks, right_blocks, target_metadata,
      panel_size, output_layout
    )

For one regional batch, the kernel must:

1. read CSC right-block columns directly without creating sparse slices;
2. detect structurally zero panels before allocating or clearing dense data;
3. fill a reusable dense RHS buffer;
4. solve it with the native sparse triangular kernel;
5. multiply sparse left blocks by the dense panel without densifying the left block; and
6. accumulate directly into preallocated regional/global correction buffers.

One native call should process a complete batch, reducing approximately 115,000 R-level panel calls to about 21 batch calls. Buffer capacity is reused across commodity blocks and panels. The R layer continues to orchestrate scaling, partition validation, factor creation, and residual checks; native dispatch is fail-closed.

Cache structural metadata across Euler solves when dimensions and qualifiers are unchanged:

- local row/column membership and external offsets;
- active right columns and left-row incidence;
- panel schedules and target mappings;
- sparse-factor permutations or symbolic analysis where supported; and
- reusable output and workspace capacities.

Numeric factors must be refreshed when coefficients change. Structural caching must be invalidated by closure or set-dimension changes.

## 7. Phase 3: bounded parallel execution

Add OpenMP only after the serial native path is numerically equivalent and faster.

Parallelize work by regional batch because batches own disjoint regional, region-global, and global-region outputs. Compute the shared global-global correction separately. Commodity factors and sparse coupling blocks are read-only inside the parallel region.

Rules for the parallel implementation:

- extract all R object slots and allocate buffers before entering OpenMP;
- do not call the R API, allocate R objects, raise R errors, or check interrupts from worker threads;
- give each worker only one bounded panel/batch workspace, never a complete private copy of the Schur output;
- capture worker errors in native status objects and raise them on the main thread;
- prevent nested OpenMP/BLAS oversubscription; and
- expose a thread-count option with a serial default until validated.

Benchmark 1, 2, 4, and 8 threads. Treat scaling as empirical; memory bandwidth, sparse triangular dependencies, and dense BLAS work make near-linear speedup unlikely. A 2-4x parallel improvement is a planning target, not a guarantee.

## 8. Phase 4: dense regional factor kernels

After native Schur accumulation is stable, use LAPACK dgetrf/dgetrs for the approximately 698 x 698 dense regional blocks and the small global block. These matrices are genuinely dense, so LAPACK is methodologically appropriate.

Keep factor storage in RAII-managed native objects with deterministic cleanup. If external pointers are exposed to R, provide finalizers and define how cached factors are rebuilt after serialization. Unsupported native platforms fail during preflight; callers may explicitly select the R backend.

## 9. Deferred work

### Native FGMRES

Defer until profiling shows materially more than one Krylov iteration or at least 10% of step time. Porting Arnoldi and the preconditioner now would add substantial complexity for negligible GTAP 12a benefit.

### Native coefficient emission and updates

Emission and updates currently consume about six percent of solve time. Revisit them only after Schur acceleration changes the profile. Any native emitter must aggregate duplicate triplets, preserve qualifiers, and create valid sorted CSC slots without attaching full labels.

### Direct SuiteSparse integration

Do not link against private Matrix-package symbols. A direct UMFPACK/KLU backend is optional only if configure-time detection, Windows/macOS behavior, cleanup, and a portable fallback are specified. RcppEigen is likewise adopted only after representative sparse-factor benchmarks demonstrate stability and speed.

## 10. Build infrastructure

Phase 1 needs only the existing Rcpp dependency. Add BLAS/LAPACK linkage when Phase 4 begins:

    PKG_LIBS = $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)

For optional OpenMP, use guarded SHLIB_OPENMP_CXXFLAGS in src/Makevars and provide an appropriate src/Makevars.win. Set CXX_STD = CXX17 only if the implementation actually requires C++17; SystemRequirements alone does not select the compiler standard.

## 11. Verification gates

Every phase must pass before merging:

1. All 94 package tests and R CMD check.
2. New sparse-LU multi-RHS tests against Matrix::solve().
3. Block-by-block equality for regional, region-global, global-region, and global-global Schur outputs between R and C++.
4. Synthetic structured-solver solution error and true relative residual below 1e-8; the fixture must be tracked in the repository.
5. One-step GTAP A/B comparison before any full run:
   - full relative residual at most 2e-7;
   - maximum absolute native-vs-R solution difference at most 1e-6;
   - no nonfinite solution or post-simulation values; and
   - no dense fallback.
6. Thread-count comparison showing equivalent results for 1, 2, 4, and 8 threads within the same tolerances.
7. Only after those gates pass, repeat the full iter = 3, steps = c(1, 3), postsim = TRUE benchmark.

Extend benchmark_gtap12a.R to record the maximum full-system residual, selected-output finiteness, panel counters, native thread count, and native/R backend identity. Benchmark artifacts must be sufficient to audit correctness without relying on console logs.

## 12. Performance acceptance criteria

Do not merge a phase based on projected gains. Require measured improvement on the same machine and input:

- Phase 0 selects a panel configuration with no residual or memory regression.
- Phase 1 must outperform Matrix::solve() on representative multi-RHS block kernels while matching its result.
- Phase 2 must reduce one-step end-to-end time by at least 20% without raising peak RSS by more than 10%.
- Phase 3 must demonstrate useful scaling at four threads and remain within the configured memory budget.
- The final full run must remain below the current 29.6 GiB peak and improve total wall time materially while preserving all numerical gates.

An aspirational outcome is 5-10 minutes per solve on an 8-core target machine, but implementation order and merge decisions are driven by measurements, not that estimate.
