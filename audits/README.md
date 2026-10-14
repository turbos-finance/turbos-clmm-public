# Audit evidence - Turbos CLMM

Audit PDFs retain their original authors' copyright and terms. The repository's MIT
license applies to Turbos-owned source and documentation; it does not relicense third-party reports.

Original reports are included unchanged:
[CertiK 2023](certik-clmm-2023.pdf), [MoveBit CLMM 2024](movebit-clmm-2024.pdf),
and [MoveBit Math 2025](movebit-math-2025.pdf).

| Report | Period | Reviewed revisions | Reported result |
|---|---|---|---|
| CertiK | Delivered 2023-09-04; start date not specified in the executive summary | `7ffa9e052cc3946198e7173aea3576e66fa7dbfc`, `56096599900e89cffbe4aa09dcbcfd749960df46`, `d01e557e3fb613451b805c136f2a3f55d58d3d65` | 29 findings: 27 resolved, 1 partially resolved, 1 acknowledged |
| MoveBit CLMM | 2024-12-05 through 2024-12-17 | `487e891e4cdc4450a0cb172ed4bd01a2692320df`, `b657a46a3cd4cc77091abedd94e73da4d11c67b2` | 11 findings: 9 fixed, 2 acknowledged |
| MoveBit Math | 2025-05-24 (one day, as stated in the report) | `66eccab8e5adc902e61b1574475c7eedd50dbfee`, `1cd4d973d014ad64fd5cbd079f19f351d777a9fd` | 4 minor findings, all fixed |

The firms, scopes, file hashes, architecture and methods are documented in the original
reports. Individual reviewer names and the CertiK engagement start date need auditor
confirmation where not disclosed. All cited commit anchors are checked for public
availability in `evidence/audit-source-provenance.json`.

## Deployed-source relationship

The mainnet v22 source commit remains `a02c7a0b78d8a53bb0534835c309b2d115254e01`.
This release adds documentation and evidence only; it does not change contract source.
`@turbos/turbos` GitInfo pins that exact deployed commit.

Compared with the last math audit revision `1cd4d973...`, v22 changes 14 source files
(763 insertions, 248 deletions). A math audit does not cover the whole protocol's later
ACL, pool, factory, router or privileged-operation changes. A complete finding-to-fix/test
matrix and a reviewed audit-to-deployment delta are still needed. Public report availability
alone does not establish that every part of deployed v22 meets the latest audit-quality bar.
