# Pitfalls Research

**Domain:** Renaming and releasing a native-code scientific R package
**Researched:** 2026-08-22
**Confidence:** HIGH, except legal resolution requires qualified confirmation

## Critical Pitfalls

### 1. Treating a public repository as open-source permission

**What goes wrong:** A renamed derivative is distributed without clear rights.

**Why it happens:** The upstream repository is public and forkable, but it has no license file and its `DESCRIPTION` contains a placeholder license.

**How to avoid:** Obtain explicit written permission/license from upstream rights holders or complete a counsel-reviewed clean-room/reimplementation strategy. Preserve authorship and provenance in `Authors@R`, copyright records, and source headers.

**Warning signs:** Choosing MIT/GPL unilaterally, deleting attribution, or preparing a public release before permission is recorded.

**Phase to address:** Phase 1; blocks public release and substantive rebranding distribution.

### 2. Combining rename, API redesign, and numerical refactor

**What goes wrong:** Regressions cannot be attributed and compatibility breaks silently.

**How to avoid:** Freeze numerical baselines, inventory exports, rename mechanically, then refactor behind contracts in later phases.

**Warning signs:** Large commits touching `DESCRIPTION`, all R files, solver algorithms, outputs, and tests at once.

**Phase to address:** Compatibility baseline before identity migration.

### 3. Assuming OpenMP is portable

**What goes wrong:** Installation fails on macOS or unsupported compiler stacks.

**How to avoid:** Compile and test with OpenMP flags empty; guard all parallel code; expose serial capabilities; limit check-farm threads.

**Warning signs:** Unconditional `omp.h`, required `-fopenmp`, or tests that require multiple threads.

**Phase to address:** Native portability and CI.

### 4. Relying on runtime SuiteSparse compilation

**What goes wrong:** Users need compilers/system paths at solve time and fixed Linux paths fail elsewhere.

**How to avoid:** Keep optional backend out of the launch-critical path; later add configure-time detection or remove it from supported public backends.

**Warning signs:** `Rcpp::sourceCpp()` in normal package execution and hard-coded `/usr/include/suitesparse` paths.

**Phase to address:** Build hardening.

### 5. Narrowing exports without an inventory

**What goes wrong:** Downstream scripts depend on accidentally exported helpers and break at rename.

**How to avoid:** Record current exports, classify supported/compatibility/internal symbols, test supported exports, and publish deprecations.

**Warning signs:** Replacing `exportPattern()` with a guessed list in one commit.

**Phase to address:** API contract before namespace cleanup.

### 6. Overstating package-name availability

**What goes wrong:** GEModelR conflicts with a current/past CRAN or Bioconductor name after branding work.

**How to avoid:** Run an authoritative current/past CRAN and Bioconductor name check immediately before reserving repositories and again before submission. Current exact-name searches found no obvious collision, but this is not a legal or registry reservation.

**Phase to address:** Phase 1 identity gate.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep `exportPattern()` | No docs needed | Accidental API forever | Only until export inventory completes |
| Keep `zzz*` backend wrapping | Minimal code movement | Hidden dispatch/order coupling | During first compatibility release |
| Keep runtime UMFPACK compiler | Optional Linux speed path | Unsupported installs | Experimental, never default |
| Use only synthetic tests | Fast public CI | Misses scale-specific failures | If signed external benchmark remains mandatory |

## Performance Traps

| Trap | Symptoms | Prevention | Trigger |
|------|----------|------------|---------|
| Dense diagnostic conversion | Sudden RSS spike/OOM | Explicit dense-fallback instrumentation | Tens of millions of positions |
| Giant labels/dimnames | Memory dominated before solve | Output-boundary label generation | Full GTAP dimensions |
| Unbounded worker buffers | RSS grows with threads/panels | Bounded per-worker panels and batch limits | Parallel structured backend |
| Benchmarking wrong install | Misleading speed/equality claims | Installed-tree and model signatures | Any A/B run |

## "Looks Done But Isn't" Checklist

- [ ] License text is present **and** upstream rights/attribution are documented.
- [ ] Package rename covers native initialization symbols, options, tests, benchmark signatures, docs, and install paths.
- [ ] `R CMD check --as-cran` is clean on built tarballs, not only the source directory.
- [ ] Serial, OpenMP-disabled, Windows, and macOS builds pass.
- [ ] Legacy and R reference solutions remain available and numerically gated.
- [ ] Public docs contain a redistributable end-to-end example.
- [ ] Full-scale claims identify hardware, versions, signatures, residuals, and dense-fallback status.
- [ ] Proprietary inputs and experimental scratch files are absent from source archives.

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Unlicensed derivative | Provenance and identity | Written grant/license plus source audit |
| Untraceable divergence | Compatibility baseline | Frozen A/B fixtures and export snapshot |
| OpenMP failure | Portable native build | Serial/Linux/macOS/Windows CI matrix |
| Runtime compiler dependency | Build hardening | Installed package solves without `sourceCpp()` |
| Accidental API break | Namespace/documentation | Export and downstream workflow tests |
| Misleading release | Release qualification | Signed checks and benchmark report |

## Sources

- [Upstream `DESCRIPTION`](https://raw.githubusercontent.com/mivanic/tabloToR/master/DESCRIPTION) — placeholder license/authorship metadata.
- [GitHub licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository) — absent license leaves default copyright restrictions; public forking is not redistribution permission.
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) — unambiguous provenance, licensing, naming, portability, and resource rules.
- [Writing R Extensions](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html) — OpenMP and native-code constraints.

---
*Pitfalls research for: GEModelR*
*Researched: 2026-08-22*
