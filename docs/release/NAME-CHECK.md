# GEModelR Name Availability Evidence

## Configuration

Name: GEModelR
Check-Kind: initial
Checked-At-UTC: 2026-08-25T11:19:08Z
Overall-Result: NAME_AVAILABLE_NO_EXACT_COLLISION
Reviewer: awaiting-human-approval
Review-Date-UTC: awaiting-human-approval

The check uses ASCII case-folded exact matching. Substrings and Unicode
lookalikes are not exact package or repository-name collisions.

## Results

| Source | Query identity | Available | Raw MD5 | Exact matches | Result |
| --- | --- | --- | --- | --- | --- |
| CRAN current | `https://cran.r-project.org/src/contrib/PACKAGES` | yes | `9ea005e34242b4919822f2deba91538d` | NONE | pass |
| CRAN archive | `https://cran.r-project.org/src/contrib/Archive/` | yes | `d54a8ba2216796f9ecf74269e10526c4` | NONE | pass |
| Bioconductor current | `https://bioconductor.org/packages/release/bioc/src/contrib/PACKAGES` | yes | `d924d55afadb8ce1096704d2c310b440` | NONE | pass |
| Bioconductor history | `https://bioconductor.org/about/release-announcements/ + https://bioconductor.org/packages/{version}/bioc/src/contrib/PACKAGES [indexed package manifests: 3.22,3.21,3.20,3.19,3.18,3.17,3.16,3.15,3.14,3.13,3.12,3.11,3.10,3.9,3.8,3.7,3.6,3.5,3.4,3.3,3.2,3.1,3.0,2.14,2.13,2.12,2.11,2.10,2.9,2.8,2.7,2.6,2.5,2.4,2.3,2.2,2.1,2.0,1.9,1.8]` | yes | `93f141e15e1a4e00e1bc7106b0dd5283` | NONE | pass |
| R-universe | `https://r-universe.dev/api/search?q=package%3AGEModelR&limit=100` | yes | `1af3412ebd992a56cb95400969c1ebd4` | NONE | pass |
| GitHub | `https://api.github.com/search/repositories?q=GEModelR%20in%3Aname&per_page=100` | yes | `c0f2e492b5d9dfca90bd8c63a8cb529d` | NONE | pass |

## Machine-readable source rows

Source-Row: cran-current|available=yes|raw-md5=9ea005e34242b4919822f2deba91538d|matches=NONE|result=pass|query=https://cran.r-project.org/src/contrib/PACKAGES
Source-Row: cran-archive|available=yes|raw-md5=d54a8ba2216796f9ecf74269e10526c4|matches=NONE|result=pass|query=https://cran.r-project.org/src/contrib/Archive/
Source-Row: bioconductor-current|available=yes|raw-md5=d924d55afadb8ce1096704d2c310b440|matches=NONE|result=pass|query=https://bioconductor.org/packages/release/bioc/src/contrib/PACKAGES
Source-Row: bioconductor-history|available=yes|raw-md5=93f141e15e1a4e00e1bc7106b0dd5283|matches=NONE|result=pass|query=https://bioconductor.org/about/release-announcements/ + https://bioconductor.org/packages/{version}/bioc/src/contrib/PACKAGES [indexed package manifests: 3.22,3.21,3.20,3.19,3.18,3.17,3.16,3.15,3.14,3.13,3.12,3.11,3.10,3.9,3.8,3.7,3.6,3.5,3.4,3.3,3.2,3.1,3.0,2.14,2.13,2.12,2.11,2.10,2.9,2.8,2.7,2.6,2.5,2.4,2.3,2.2,2.1,2.0,1.9,1.8]
Source-Row: r-universe|available=yes|raw-md5=1af3412ebd992a56cb95400969c1ebd4|matches=NONE|result=pass|query=https://r-universe.dev/api/search?q=package%3AGEModelR&limit=100
Source-Row: github|available=yes|raw-md5=c0f2e492b5d9dfca90bd8c63a8cb529d|matches=NONE|result=pass|query=https://api.github.com/search/repositories?q=GEModelR%20in%3Aname&per_page=100

## Reproduction

Run `Rscript --vanilla tools/check_name_availability.R --name GEModelR --output docs/release/NAME-CHECK.md --check-kind initial`.
A fresh `reservation` check is required immediately before repository
reservation. A fresh `release` check is required immediately before
release or publication.

## Scope and privacy boundary

This is point-in-time exact-name collision evidence. It is not trademark clearance,
not a reservation, and not evidence that the name remains available later.
Only public query identities, hashes, and exact names are recorded; credentials,
private correspondence, and private repository metadata are excluded.
