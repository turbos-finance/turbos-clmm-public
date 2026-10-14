# Production-code coverage — clmm

Generated on 2026-10-14 with official Sui 1.66.2-a9a6825eaf62, tracing enabled.
Source anchor: `a02c7a0b78d8a53bb0534835c309b2d115254e01`. Mainnet package: `0xa5a0c25c79e428eba04fb98b3fb2a34db45ab26d4c8faf0d7e39d66a63891e64`.

**Scope: PARTIAL tracing run; not the full passing test suite**.
187 traced tests passed, zero failed.
Filter: `security_acl_tests|acl_tests|access_control_simple_tests|math_|i32::|i64::|i128::|string_tools`. Full-suite tracing crashes with a stack overflow on this macOS toolchain, including after increasing the thread stack to 512 MiB. These results exclude unsupported complex cases, not contract assertions; the existing untraced full suite passes. Full-suite coverage remains outstanding.

## Results

- Production line coverage: **26.24%** (996/3796).
- Production CFG-edge branch coverage: **31.83%** (566/1778).
- Production function coverage: **35.53%**.

| Production file | Lines hit/found | CFG edges hit/found | Functions hit/found |
|---|---:|---:|---:|
| sources/acl.move | 40/40 | 36/38 | 8/8 |
| sources/fee.move | 10/11 | 2/3 | 3/4 |
| sources/fee10000bps.move | 7/7 | 0/0 | 1/1 |
| sources/fee1000bps.move | 0/7 | 0/0 | 0/1 |
| sources/fee100bps.move | 0/7 | 0/0 | 0/1 |
| sources/fee20000bps.move | 0/7 | 0/0 | 0/1 |
| sources/fee2000bps.move | 0/7 | 0/0 | 0/1 |
| sources/fee2500bps.move | 0/7 | 0/0 | 0/1 |
| sources/fee3000bps.move | 7/7 | 0/0 | 1/1 |
| sources/fee500bps.move | 7/7 | 0/0 | 1/1 |
| sources/lib/full_math_u128.move | 11/17 | 0/0 | 4/6 |
| sources/lib/full_math_u32.move | 0/17 | 0/0 | 0/6 |
| sources/lib/full_math_u64.move | 0/17 | 0/0 | 0/6 |
| sources/lib/i128.move | 106/128 | 61/68 | 23/31 |
| sources/lib/i32.move | 112/126 | 64/68 | 25/30 |
| sources/lib/i64.move | 92/116 | 60/60 | 18/28 |
| sources/lib/math_bit.move | 45/52 | 47/61 | 2/2 |
| sources/lib/math_liquidity.move | 51/51 | 34/48 | 7/7 |
| sources/lib/math_sqrt_price.move | 14/82 | 8/53 | 2/8 |
| sources/lib/math_swap.move | 0/78 | 0/39 | 0/3 |
| sources/lib/math_tick.move | 117/128 | 115/140 | 7/7 |
| sources/lib/math_u128.move | 54/91 | 29/63 | 10/18 |
| sources/lib/math_u256.move | 4/18 | 4/12 | 1/5 |
| sources/lib/math_u64.move | 17/29 | 11/21 | 4/7 |
| sources/partner.move | 0/97 | 0/40 | 0/13 |
| sources/pool.move | 96/1056 | 31/516 | 8/103 |
| sources/pool_factory.move | 124/338 | 37/83 | 16/45 |
| sources/pool_fetcher.move | 0/21 | 0/4 | 0/2 |
| sources/position_manager.move | 9/531 | 0/185 | 1/38 |
| sources/position_nft.move | 0/48 | 0/0 | 0/5 |
| sources/reward_manager.move | 35/67 | 0/0 | 6/13 |
| sources/lib/string_tools.move | 38/68 | 27/57 | 3/6 |
| sources/swap_router.move | 0/513 | 0/219 | 0/16 |

## Counting methodology

Official `sui move coverage lcov` supplies hits and CFG successor edges (including
unconditional/single-successor edges). This is the native Sui branch metric, not a
decision-only percentage. Function names from the separately verified normal build
exclude dependency modules, tests modules, inline tests/test-only helpers and compiler
test poison. Compiler JSON source maps supply instrumented line numbers; the full
test-build line denominator is checked against official LCOV in every root module
before exclusions. Zero-hit production lines are retained in production-lcov.info.

Raw test-build LCOV and the instruction-summary log are retained for comparison; neither
is labelled production line coverage. Raw SF paths are normalized to workspace-relative
paths; no local user paths or traces containing arbitrary live transaction state are published.
Normal-build function inventory is linked to the existing bytecode-verification result.

## Evidence

- [Machine-readable production results and uncovered functions/lines](production-coverage.json).
- [Production-only LCOV](production-lcov.info), [raw test-build LCOV](raw-lcov.info).
- [Trace test output](traced-tests.log), [instruction summary](instruction-summary.log).
- [Normal-build function inventory](normal-build-functions.json).
- [Official release SHA-256 provenance](release-download.json).

## Reproduce

The source/dependencies and explicit test overlay are the same as AUTH-TEST-MATRIX.md.
Obtain the official tracing-enabled CLI for your platform from the pinned release:
https://github.com/MystenLabs/sui/releases/tag/mainnet-v1.66.2
The macOS arm64 archive used here has SHA-256
`6e1256e494f5ef234c0ac78b2b52669cb07b2216950e3304565da629b19de9d1`.
Do not reuse that platform-specific hash for another archive.

```bash
cd tools/repro
npm install --ignore-scripts
SUI_BINARY=/absolute/path/to/tracing/sui node reproduce.mjs /tmp/turbos-clmm-coverage coverage
```

The destination must not exist. Coverage uses one test thread, RUST_MIN_STACK=536870912
and a 1,000,000,000 VM test budget. These are host/unit-test settings, not mainnet gas.
A five-GiB free-disk guard stops the dedicated child process if needed. No transaction
is signed or broadcast. The parser validates totals before emitting reports.

## Remaining work

These percentages show real gaps; they are not an assertion of exhaustive authorization
or invariant testing, sufficient audit scope, or R10 closure. Add positive/negative
cases for every remaining privileged call site and invariant, use uncoveredFunctions
and uncoveredLines to prioritize, and regenerate the report. Full-suite tracing must also be repaired or run on a compatible independent platform.
