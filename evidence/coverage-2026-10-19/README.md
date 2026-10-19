# Current-public-suite coverage — clmm

Regenerated **19 October 2026** against public source/test commit `3d6b079a693b13df4ff5cc1cc9dbfb8ede13cd4b` (source tree SHA-256 `ef3fecb99afad78a0382a22b390d056cc4f1fe699805e92f73593d7cec05c352`). Deployed package `0xa5a0c25c79e428eba04fb98b3fb2a34db45ab26d4c8faf0d7e39d66a63891e64`, version 22.

**Unfiltered unit tests: 292/292 passed, zero failures. Coverage tracing: 187/292 tests only — PARTIAL, not full-suite coverage.**

The latest public source/tests are measured here, not an older source anchor plus a historical patch. Full tracing still overflows the stock CLI's stack on both macOS arm64 and isolated Linux aarch64, even with a 512-MiB Rust thread-stack setting. [Diagnostic summary](tracing-limitations.json). This report does not hide that failure or label the filtered run complete.

## Measured production coverage

- Lines: **26.24%** (996/3796).
- CFG-edge branches: **31.83%** (566/1778).
- Functions: **35.53%**.
- Explicit trace filter: `security_acl_tests|acl_tests|access_control_simple_tests|math_|i32::|i64::|i128::|string_tools`.

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

## Evidence and methodology

[Full unfiltered test log](full-tests.log), [filtered trace log](traced-tests.log), [run scope/trace-count checks](run.json), [production coverage JSON](production-coverage.json), [production-only LCOV](production-lcov.info), [raw test-build LCOV](raw-lcov.info), [instruction summary](instruction-summary.log), [LCOV-generation log](lcov-generation.log), [source/test hashes](source-hashes.json), [normal function inventory](normal-build-functions.json), [normal-bytecode comparison](normal-bytecode.json), [official CLI provenance](release-download.json).

Production code excludes dependencies, test modules, inline tests and test-only helpers using the normal non-test build's function inventory. Instrumented line denominators are validated against official Sui LCOV before exclusions; zero-hit lines/functions remain included. Branches use official Sui CFG-successor edges, including unconditional edges, not a decision-only metric. Only workspace paths are normalized in public artifacts; source bytes and coverage counts are unchanged.

The normal-build root bytecode still matches the recorded immutable mainnet-module hashes. This is not a fresh chain fetch, a dependency-bytecode audit, a production fix or a mainnet upgrade.

## Reproduce the current partial report

Use Node.js 22+ and the checksum-verified official tracing-enabled Sui **1.66.2-a9a6825eaf62**, available from https://github.com/MystenLabs/sui/releases/tag/mainnet-v1.66.2. At the public repository root:

```sh
SUI_BINARY=/path/to/tracing/sui node tools/coverage-current.mjs /tmp/turbos-clmm-coverage-current --documented-partial
```

The destination must not exist. This first builds normal bytecode and runs **all 292 tests without a filter**, then explicitly captures the documented subset for coverage. It uses disposable source copies and an empty isolated CLI configuration, checks source/test hashes and per-test trace completeness for the selected subset, and never signs or submits a transaction. No old test overlay is applied.

Without `--documented-partial`, the tool attempts full tracing and **fails rather than reporting success** if the runtime crashes or any trace/test is missing. Running on Linux alone did not resolve the stock CLI's overflow.

## Remaining work

Full-suite line/branch capture is still unresolved. Passing all tests does not prove exhaustive authorization/invariant testing; uncovered production functions/lines are listed in the JSON. These are real gaps/tool limitations, not a declaration of compliance closure. Historical snapshots are retained.
