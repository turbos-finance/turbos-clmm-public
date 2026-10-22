# CLMM coverage gap review — 21 October 2026, revision 2

This revision adds 83 tests to the earlier 509-test report and records the tested
source tree at that time. Coverage percentages are measurements, not proof of
exhaustive authorization or invariant testing. Earlier reports retain their original scope.

## Verified results

| Check | Result |
|---|---:|
| Original Sui 1.66.2 unfiltered unit suite | **592/592 passed** |
| Sui 1.81.1 unfiltered suite and individual value traces | **592/592**, no exclusions |
| Production line coverage | **89.88%**, 3412/3796 |
| Production CFG-successor-edge coverage | **86.56%**, 1539/1778 |
| Production function coverage | **78.35%**, 333/425 |
| Normal-build root modules | **33/33 match** recorded deployed bytecode hashes |
| Separate private-state version fixture | **36/36 passed** |
| Separate compiler-negative capability/receipt cases | **5/5 expected rejections** |

The 36 version fixtures and five compiler cases are separate; they are not added to
the 592 normal-source runtime tests. The unit suite contains 300 additions since the
historical 292-test baseline. Every normal-source test runs on both recorded toolchains.

## Gaps closed by this revision

- **30 Partner-router tests:** both directions, exact input/output, exact pool/referral/
  output/refund conservation, expiry/start/deadline boundaries, minimum/maximum amounts,
  insufficient funding, partial-fill rejection, pause, zero amount and price validation.
- **19 factory-return tests:** NFT/pool ID/registry binding, reversed-type lookup, exact
  reserve/refund conservation, duplicate pool/type, absent fee tier, empty inputs,
  deadline/slippage, invalid ticks, zero liquidity and insufficient funding.
- **20 quote/crossing tests:** compare quote amounts with real execution in both directions
  and exact modes; traverse initialized inner boundaries while retaining outer liquidity;
  verify active liquidity and fee-growth changes; test invalid inputs and zero-fill quotes.
- **Nine position-exit tests:** zero liquidity is insufficient to burn an NFT while either
  token's fees or reward remains owed; partial claims still reject; full settlement permits
  burning, with exact collection/vault conservation assertions.
- **Five math/ACL tests:** liquidity underflow/overflow, shifted-liquidity overflow, reversed
  price-bound symmetry and absent-role removal without accidental membership or authority.
- **Seven additional version fixtures:** actual factory mint/return, quote/fetch and all
  three Partner-router interfaces reject the future stored version at pool::23.

The quote implementation is **not entirely read-only**: it settles reward growth/time.
Tests pin this deployed behavior and same-time idempotence, while checking price, active
liquidity, token reserves and crossed-tick state remain unchanged by the quote. An equal
tick range rejects earlier with an arithmetic error in full_math_u128; the test records
the exact existing behavior, not a claimed custom pool abort. Production logic is unchanged.

## Executed witnesses and remaining scope

[Executed witness mapping](security-witnesses.json) checks all **14 live ACL-gated
factory/reward entries**, each with required-only success and missing/other-only/revoked
role rejection: 56 named runtime tests, executed on both toolchains. It also lists every
new boundary test and the 26 business entries with explicit future-version rejection
fixtures. This is a narrowly scoped, reviewed mapping, not a proof of all package invariants.

Object capability construction/receipt linearity are checked separately by compiler
negatives; ownership and transfer execution tests are in the main suite. These are Sui
input/visibility restrictions, not a claim to execute unauthorized cap-gated transactions.
All 21 externally public retired factory/reward entries have exact abort-stub tests.

The report still includes all zero-hit normal-build functions/lines. Remaining review
includes rare mathematical/rounding states, legacy owner-address compatibility paths,
compound-condition alternatives and initialization/private helper exclusions. Do not
equate full capture, all live ACL entries tested, or a percentage with exhaustive
authorization or invariant testing. See the
[current matrix and residual review list](../../docs/security-test-matrix-2026-10-21.md).

## Evidence

- [Baseline tests](full-tests.log), [traced tests](traced-tests.log), [completeness](run.json), [results](result.json).
- [Production coverage JSON](production-coverage.json), [production LCOV](production-lcov.info), [raw official LCOV](raw-lcov.info).
- [Source/test hashes](source-hashes.json), [normal bytecode](normal-bytecode.json), [normal function inventory](normal-build-functions.json).
- [Version fixtures](version-fixture/result.json), [fixture test log](version-fixture/tests.log), [compiler negatives](capabilities/result.json).
- [Source entry inventory](security-entry-inventory.json), [executed witness checks](security-witnesses.json).
- [Official tracer provenance](release-download.json), [toolchain notes](toolchain-notes.json).

Tested source/test tree SHA-256: `c744d6db202d76ec599cb26bd6a64bfb2b263bfaeb4028e2846628bf89df3483`.
Base public commit before this revision: `a75e6b40d67ad8b3d22bee7d0b2e03cafb0c5ee8`.
The base commit alone does not contain this revision's tests; use the tracked tree plus hashes.

## Metric definitions and reproduction

Line/function denominators exclude dependencies and test-only code using the original
normal build's inventory. Official LCOV line denominators are validated with compiler
source maps. Branches mean **CFG successor edges, including unconditional edges**, not
decision-only coverage or MC/DC. Uncovered code is not removed to increase the percentage.
Normal bytecode compares recorded immutable deployed hashes, not a fresh chain/dependency audit.

Use Sui **1.66.2-a9a6825eaf62** for the deployment-matching normal build and original unit
run; use checksum-verified official **1.81.1-e04cf9aa915c** only for tracing. The newer
compiler's different bytecode format is not a replacement production/deployment build.
The private-state fixture inserts only a test-only constructor into a disposable copy;
its normal build still matches 33/33 modules. It is not a historical package rollout test.

From this checkout, with Node.js 22+ and new output paths:

```sh
SUI_BINARY=/path/to/sui-1.66.2 \
SUI_TRACE_BINARY=/path/to/sui-1.81.1 \
node tools/test-security.mjs /tmp/clmm-review-new --trace-full

SUI_BINARY=/path/to/sui-1.66.2 \
node tools/test-version-gates.mjs /tmp/clmm-review-new /tmp/clmm-version-new

SUI_BINARY=/path/to/sui-1.66.2 \
node tools/test-capabilities.mjs /tmp/clmm-review-new /tmp/clmm-cap-new

node tools/check-security-witnesses.mjs \
  /tmp/clmm-review-new /tmp/clmm-version-new /tmp/clmm-witnesses-new.json
```

No wallet keys, signing, mainnet transaction, production source modification, package upgrade
or MVR update is involved. Generated public artifacts normalize local workspace paths.
