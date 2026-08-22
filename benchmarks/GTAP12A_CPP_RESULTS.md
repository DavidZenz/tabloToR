# GTAP 12a Native Solver Results

## Configuration

Benchmarks ran on 2026-08-22 using the package at commit `6d8ea6c`, R 4.x,
Matrix 1.6.3, an AMD Ryzen 5 3600X (6 cores/12 threads), and 62.9 GiB of
physical RAM. The unaggregated model has 163 regions, 65 commodities,
26,781,398 equation positions, and at most 80,306,307 sparse nonzeros.

The final run selected the opt-in `StructuredSchurFGMRESCpp` backend, panel
size 64, regional batch size 8, and four threads. It used `iter = 3`,
`steps = c(1, 3)`, and `postsim = TRUE`; its run signature was
`cb5d4dcc252c43c66c52f8e6b6f5bb7b`.

## Full Run

| Measurement | R baseline | C++ result |
| --- | ---: | ---: |
| Solve time | 18,608 s | 4,662.1 s |
| Peak RSS | 29.6 GiB | 25.34 GiB |
| Maximum full residual | at most `2e-7` | `9.014e-8` |
| Dense full-system fallback | No | No |

The C++ solve was 3.99 times faster and used 14.4% less peak memory. All
26,781,398 solution values and selected post-simulation outputs were finite.
Across 12 coefficient solves, diagnostics recorded 10 structural-cache hits,
two misses, 12 numeric refactorizations, and four effective OpenMP threads.

## One-Step Gates

The matched R/native A/B check measured 1,767.3 s for R, 1,180.7 s for serial
C++, and 695.4 s for four-thread C++. Native and R vectors differed by at most
`2.83e-27`; serial and four-thread C++ vectors were identical.

The panel sweep selected 64 without a correctness or memory tradeoff:

| Panel size | Solve seconds | Peak RSS (GiB) |
| ---: | ---: | ---: |
| 64 | 699.5 | 14.47 |
| 256 | 799.8 | 14.55 |
| 512 | 1,191.1 | 14.60 |
| 1024 | 1,936.8 | 14.57 |

The regional-batch sweep measured 701.8, 699.5, and 694.5 seconds at
batch sizes 4, 8, and 16. The 1.1% spread is too small to justify the extra
workspace; batch 8 had the lowest measured RSS and remains the conservative
selection.

The thread sweep measured 1,246.8, 887.4, 704.4, and 656.0 seconds at 1, 2,
4, and 8 threads, respectively. That is 1.40x, 1.77x, and 1.90x scaling over
one thread. Every thread count produced an identical solution and a
`6.78e-8` residual. Four threads remain the documented conservative setting;
eight may be useful when the machine is otherwise idle.

Use `run_gtap12a_ab.R`, `run_gtap12a_sweep.R`, `run_gtap12a_scaling.R`, and
`check_benchmark_gate.R` to reproduce these checks with locally supplied GTAP
inputs. Proprietary inputs and full solution artifacts are intentionally not
stored in the repository.
