# Dependency license compatibility audit

Audit-Version: 1
Package-License: GPL-3.0-or-later
Audit-Result: compatible
Reviewer: Codex automated technical review, requested by the maintainer
Review-Date-UTC: 2026-10-27
License-Selection-Authority: David Zenz, 2026-10-19

This review covers the declared runtime dependencies, their mandatory R package
closure, LinkingTo headers, generated wrappers, and native build inputs of
GEModelR 0.1.0. It does not change the selected package license or add conditions
to it. Dependencies retain their own licenses. Proprietary model inputs and
independently selected alternative BLAS/toolchains are outside this source release.

## R packages

| Component | Reviewed version | License/basis | Disposition |
| --- | --- | --- | --- |
| Rcpp (Imports and LinkingTo) | 1.1.1-1.1 installed | GPL version 2 or later | Select GPLv3 for the combined work; preserve upstream header notices. No Rcpp source tree is bundled. |
| Matrix | 1.6-5 and 1.7-6 | Matrix's LICENCE specifies GPLv3 for its own code; BSD-3-Clause, LGPL-2.1-or-later, GPL-2.0-or-later for bundled SuiteSparse; 1.7-6 additionally lists Apache-2.0 METIS | Compatible with GPLv3. Matrix is separately installed; GEModelR does not copy or directly vendor its SuiteSparse sources. |
| SparseM | 1.81 | GPL version 2 or later | Compatible by selecting GPLv3; separately installed. |
| lattice (Matrix dependency) | 0.20-45 | GPL version 2 or later | Compatible by selecting GPLv3; separately installed. |
| methods, graphics, grDevices, grid, stats, utils | R 4.3.0 | Part of R; GPL version 2 or 3 | Covered by the R distribution; compatible with GPLv3. |
| knitr (documentation) | 1.45 | GPL | Build tool; its own license remains applicable. |
| rmarkdown (documentation) | 2.30 | GPL-3 | Build tool; compatible. |
| pkgdown, testthat, withr (documentation/tests) | 2.2.0, 3.3.2, 3.0.2 | MIT with accompanying license files | Build/test tools; compatible. No tool source tree is included. |

The installed mandatory dependency closure was enumerated with
`tools::package_dependencies(..., which = c("Depends", "Imports", "LinkingTo"),
recursive = TRUE)`. No undeclared non-R package was found in that closure.
Optional tooling does not add a mandatory linked library to GEModelR.
Future dependency license changes require another review; this is not approval
of arbitrary future licenses or user-supplied binary bundles.

## Native build

All distributed native files are package implementation, its installed mirrors,
or Rcpp-generated interface wrappers. Includes resolve to Rcpp, R's LAPACK API,
standard C++ headers, optional OpenMP, and the package's own sparse-LU header.
No Eigen, standalone SuiteSparse, or other third-party source tree is bundled.
The separately recognized SuiteSparse backend remains unsupported in installed
builds and does not add linkage.

`src/Makevars` and `src/Makevars.win` use R-provided OpenMP, LAPACK, BLAS and
Fortran flags. The reviewed local runtime uses GCC 8.3, ATLAS BLAS and LAPACK.
The installed ATLAS/LAPACK runtime copyright records use BSD-style runtime
licenses. GCC's libstdc++, libgcc, libgfortran and libgomp use GPL with the GCC
Runtime Library Exception; the ordinary compiler invocation uses no proprietary
compiler plugin. Windows/macOS builds continue to use R's standard toolchain
interfaces. Distribution of an alternative runtime or vendored dependency
requires checking that runtime's own terms and notices.

## Primary evidence and source integrity

- [Rcpp licensing FAQ](https://www.rcpp.org/pdf/Rcpp-FAQ.pdf).
- [Matrix 1.6-5 source](https://cloud.r-project.org/src/contrib/Archive/Matrix/Matrix_1.6-5.tar.gz): archive SHA256 `726c8d46626e73d1d6e76a74679813c6df96ffdee1aee45d94e7014cb4ceb97d`; LICENCE SHA256 `0a76b1fc53fb0c8a686963103de838384f9402d23de35fcd4248f774c6d6118e`.
- [Matrix 1.7-6 source](https://cloud.r-project.org/src/contrib/Matrix_1.7-6.tar.gz): archive SHA256 `694239dbe47e659d6d39a49af95157f46bd94977c283df00c4e8a016601cf143`; LICENCE SHA256 `950f535be089f287efbfb53e97c0e4835e3ec8f4dc10770ff448f95022c33240`.
- [SparseM 1.81 source](https://cloud.r-project.org/src/contrib/Archive/SparseM/SparseM_1.81.tar.gz): archive SHA256 `bd838f381ace680fa38508ff70b3d83cb9ffa28ac1ab568509249bca53c34b33`; DESCRIPTION SHA256 `05c66d63f93eb7e7788cf4c638d5ad8aa10a3c7ed9ff1e6d1bcb01858977d862`.
- [LAPACK license](https://netlib.org/lapack/LICENSE.txt).
- [GCC Runtime Library Exception](https://www.gnu.org/licenses/gcc-exception.html) and its [component scope](https://www.gnu.org/licenses/gcc-exception-3.1-faq.html.en).
- [Apache-2.0 compatibility with GPLv3](https://www.apache.org/licenses/GPL-compatibility), relevant to Matrix's METIS dependency.

Downloaded source archives were inspected externally; they are not included in
the package. The source release preserves the upstream attribution, GPL package
metadata and component notices. Binary releases must retain their matching
corresponding source and all applicable runtime notices. This technical audit
does not claim that a release has been published or independently certified.
