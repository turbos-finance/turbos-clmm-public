# CLMM current-suite testing and full coverage — 21 October 2026

This is the latest report. It supersedes the earlier partial-capture reports for the
current source/test tree; historical artifacts retain their original scope.

## Results

| Check | Verified result |
|---|---:|
| Full unfiltered unit tests | **509/509 passed, 0 failed** |
| Individual value traces | **509/509**, no filter or exclusions |
| New tests since the public 292-test baseline | **217** |
| Production line coverage | **84.80%** — 3219/3796 |
| Production CFG-edge coverage | **80.71%** — 1435/1778 |
| Production function coverage | **75.76%** — 322/425 |
| Original-toolchain normal bytecode | **33/33 root modules match** recorded deployed hashes |
| Separate private-state version fixture | **29/29 passed** |
| Separate compiler-negative cases | **5/5 expected rejections** |

The 29 fixture tests and five compiler-negative cases are reported separately, not added
to the 509-test unmodified-production-source suite. Full capture means every current test
was measured, **not** that every production line, authorization condition or invariant
already has exhaustive testing. Uncovered functions/lines remain listed in the JSON.

## What was added

- 56 real ACL entry tests: all 14 live ACL-gated factory/reward entries, each with correct,
  missing, other-only and revoked role cases; exact production abort codes/modules.
- 24 boundary/accounting tests: rewards, vault binding, fee bounds, version and pause.
- 23 Partner tests: admin capability operations, identity binding, fees, timing and transfer.
- 28 position tests: NFT/pool binding, liquidity/refund conservation, pause/recovery, deadlines,
  slippage, ownership and burn-after-clear.
- 38 fee/flash/router tests: nonzero protocol fees, LP principal separation, exact/partial/zero/
  repeated claims, receipt pool/amount checks, prices and swap thresholds in both directions.
- 21 retired public factory/reward entry tests: exact defining-module abort(0).
- 12 Partner flash tests: wrong partner/pool, under/overpayment, expired referral and combined
  pool/referral/borrowed-coin conservation in both directions.
- 15 Burn NFT tests: full-range conversion and conservation, ownership/transfer, wrong pool,
  deadlines, pause, fee/reward wrappers and direct-burn behavior.
- Three historical broad expected-failure assertions tightened to exact reasons.

## Toolchain separation — important

| Role | Version | Scope |
|---|---|---|
| Deployed-bytecode verification and baseline unit suite | Sui **1.66.2-a9a6825eaf62** | Original production manifest and normal build; all 33 recorded deployed module hashes match |
| Full value tracing and official LCOV | Sui **1.81.1-e04cf9aa915c** | Same production source/tests; original test-framework commit remains pinned |

Sui 1.66.2's value tracer overflows on collection paths even in isolated single-test runs.
The checksum-verified official 1.81.1 binary successfully captures the entire suite,
including the previously excluded paths. The reproduction runner was independently run
through the full pipeline, not just the two-case probe.

**The newer compiler emits a different bytecode format. Its output is not a replacement
deployment build and is not claimed byte-for-byte identical to the deployed package.**
Deployment/source reproducibility remains anchored to Sui 1.66.2; coverage instrumentation
uses the newer runtime only. No production logic, published package identifiers, MVR
GitInfo or mainnet state changed. See [toolchain notes](toolchain-notes.json) and
[official binary provenance/checksum](release-download.json).

## Evidence

- [509-test baseline log](full-tests.log), [509-test full tracing log](traced-tests.log),
  [run completeness](run.json), [results](result.json).
- [Production coverage JSON](production-coverage.json), [production-only LCOV](production-lcov.info),
  [raw official LCOV](raw-lcov.info), [function inventory](normal-build-functions.json).
- [Source/test hashes](source-hashes.json), [normal-bytecode comparison](normal-bytecode.json).
- [Version fixture results](version-fixture/result.json) and [test log](version-fixture/tests.log).
- [Compiler-negative results](capabilities/result.json) and [diagnostics](capabilities/).
- [Guard/test matrix](../../docs/security-test-matrix-2026-10-21.md) and
  [static entry inventory](security-entry-inventory.json); source inventory is a review aid,
  not itself coverage proof.

Exact tested production-source/test tree SHA-256:
`18e74098ef0c36833fa22b50f2cac38da236e2f8e5efbe36fbf0bbe8b6f5cccd`.
Base public commit before adding tests: `c58d1cfb0080988b9930387c4486e7dd494ea27b`.
The base commit alone does not contain the new tests; use the tracked source/test files
and hashes accompanying this report to identify the tested tree.

## Metrics and limitations

Production metrics exclude dependencies, test modules, inline tests and test-only helpers,
using the deployed-bytecode-matching normal build's function inventory. Line denominators
are validated against official LCOV using compiler source maps before exclusions. Zero-hit
production lines and functions remain in the denominator. Branches are the official Sui
CFG-successor-edge metric, including unconditional edges, not a decision-only percentage.
Absolute workspace paths are normalized in exported artifacts; counters are unchanged.

Normal-bytecode comparison uses previously recorded immutable deployed-module hashes, not
a fresh chain read or independent dependency-bytecode audit. The version-state fixture
injects only an explicit test-only constructor into a disposable copy; no production
assertions/constants change, and its normal build still matches all 33 deployed hashes.
It is not a mainnet rollout or a real historical-package compatibility test.

## Reproduce

Use Node.js 22+ and the two recorded official Sui binaries. Verify release archive checksums
before execution. Download tracing CLI from the
[official mainnet-v1.81.1 release](https://github.com/MystenLabs/sui/releases/tag/mainnet-v1.81.1).
The macOS arm64 archive SHA-256 is
`ccd02094862484820727c22f1a144e2bdffcc954b776b602e64d40592425cc7c`.
The original build CLI is recorded in the historical
[mainnet-v1.66.2 release](https://github.com/MystenLabs/sui/releases/tag/mainnet-v1.66.2).

At the repository root, all destination directories must be new:

```sh
SUI_BINARY=/path/to/sui-1.66.2 \
SUI_TRACE_BINARY=/path/to/sui-1.81.1 \
node tools/test-security.mjs /tmp/clmm-security-full-new --trace-full

SUI_BINARY=/path/to/sui-1.66.2 \
node tools/test-capabilities.mjs /tmp/clmm-security-full-new /tmp/clmm-cap-new

SUI_BINARY=/path/to/sui-1.66.2 \
node tools/test-version-gates.mjs /tmp/clmm-security-full-new /tmp/clmm-version-new
```

The first command runs all tests on the original toolchain, verifies production bytecode,
then traces all tests on the newer runtime and checks every test name/trace before reporting
full capture. No trace exclusion list is used in `--trace-full` mode. All runners use
disposable packages and an empty isolated client configuration; they never access the
user's keystore, sign or submit transactions.
