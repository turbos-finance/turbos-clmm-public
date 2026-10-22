# CLMM version-surface and fee-tier evidence — 22 October 2026

This revision supersedes the 636-test snapshot for the current tracked tests.
Production source, dependency settings and deployment metadata are unchanged.

## Verified results

| Check | Result |
|---|---:|
| Original Sui 1.66.2 unfiltered unit suite | **647/647 passed** |
| Sui 1.81.1 unfiltered unit suite and individual value traces | **647/647**, no exclusions |
| Production line coverage | **91.86%**, 3487/3796 |
| Production CFG-successor-edge coverage | **88.41%**, 1572/1778 |
| Production function coverage | **84.24%**, 358/425 |
| Original normal-build root modules | **33/33 match** recorded deployed bytecode hashes |
| Separate version fixture | **66/66 passed** |
| Separate owner-address compatibility fixture | **34/34 passed** on both toolchains, **34 individual traces** |
| Separate compiler-negative cases | **12/12 expected rejections**, exact diagnostic codes |

The version, compatibility and compiler cases are separate from the 647-case
normal-source coverage denominator. There are 11 additional normal-source tests
and 30 additional version-fixture tests versus the previous revision.

## Controls added to the witness review

### Every direct version check

The [machine-checked mapping](version-surface-witnesses.json) accounts for all
**53 direct `check_version` calls** in the original normal-build function inventory.
Each has a current-version guard pass in normal execution and a named rejection
test for synthetic stored version 19, requiring exactly `pool::23`.

The normal tree's only `Versioned` constructor uses constant 18; its setter writes
the same constant. This makes a normal guard-line hit a current-version pass.
It does **not** imply the entire enclosing operation completed successfully.

Three delegated public wrappers also reject the future version: the two Partner
direction routers and Burn NFT fee collection. The 56 entry rejections plus 10
direct version-state/upgrade cases form the separate **66-case fixture**. New cases
include position mint/burn/increase/decrease/collection, real Burn NFT proofs,
all four flash borrow/repay APIs, and all 12 ordinary one-/two-hop router APIs.
Flash repayment fixtures borrow under the current version and prepare exact real
repayment coins and receipts before calling repayment with the future version.

The future-state constructor exists only as a disclosed `#[test_only]` overlay
in a disposable package. Its normal build still matches all 33 deployment hashes.
This is not a historical package replay, governance-custody or mainnet rollout test.

### Four fee-tier/witness assertions

`tests/security_fee_tier_tests.move` adds **11 cases**:

- Genuine one-time-witness acceptance versus an ordinary drop type: `fee::0`.
- Unique type acceptance versus duplicate registration: `pool_factory::3`.
- Fee 0 and 999999 accepted; 1000000 and u32-max rejected: `pool_factory::1`.
- Spacing 1 and 16383 accepted; 0 and 16384 rejected: `pool_factory::2`.
- Both maximal valid values accepted together.

The two spacing rejection cases independently exercise each arm of its compound
bound. Accepted tiers must also deploy a real pool and read back the exact fee
and spacing, not merely avoid an abort. The
[executed witness mapping](security-witnesses.json) binds these four source assertions
to named tests passing on both toolchains. It also retains all 14 live ACL entries'
56 required/missing/other-only/revoked-role cases and lists 138 selected boundary cases.

## Scope and remaining work

John specified no numerical minimum. These percentages and passing tests do not
automatically close “every auth check / invariant.” The remaining work is semantic
witness review for the other guards/invariants, compound-condition alternatives,
rounding specifications and reachability decisions. The static inventory still
retains all 425 normal functions and uncovered code in its denominator.

The [requirement review](../../docs/security-requirement-review-2026-10-22.md) preserves
the observed legacy-position transfer and nearest-versus-ceiling rounding limits.
Synthetic compatibility tests are not a mainnet old-object survey. No legacy rights
migration or arithmetic production fix is claimed. Earlier reports remain historical.

## Evidence

- [Main tests](full-tests.log), [traced tests](traced-tests.log), [run completeness](run.json), [results](result.json).
- [Production coverage JSON](production-coverage.json), [production LCOV](production-lcov.info), [raw official LCOV](raw-lcov.info).
- [Source/test hashes](source-hashes.json), [normal bytecode comparison](normal-bytecode.json), [normal function inventory](normal-build-functions.json).
- [Version-surface mapping](version-surface-witnesses.json), [other executed witnesses](security-witnesses.json), [guard inventory](security-guard-inventory.json), [public/friend inventory](security-entry-inventory.json).
- [Version results](version-fixture/result.json), [version test log](version-fixture/tests.log).
- [Compatibility results](legacy-fixture/result.json), [original-toolchain tests](legacy-fixture/tests.log), [traced tests](legacy-fixture/traced-tests.log).
- [Compiler-negative results](capabilities/result.json), [diagnostic logs](capabilities/).
- [Tracing binary provenance](release-download.json), [toolchain separation](toolchain-notes.json), [export checksums](export-manifest.json).

Tested source/test tree SHA-256:
`840504273e62d119b23d1c77e890a49d97e7004ad635972e4ae5c5833e58e770`.
Base public commit before this revision: `0d26f5aacc1fd06242983dc6b9b24d6a3352b022`.
The base commit alone does not contain the additions; use this revision's tracked
tests and hashes. Report/source hashes are rechecked before publication.

## Metric definitions and reproduction

Dependencies and test-only code are excluded using the original normal-build
function inventory; compiler source maps validate the LCOV denominators. Branches
mean **CFG successor edges including unconditional edges**, not decision-only
coverage or MC/DC. Bytecode comparison uses recorded immutable deployment hashes,
not a new chain read or independent dependency-bytecode audit.

Sui **1.66.2-a9a6825eaf62** remains the deployment-matching toolchain. Checksum-verified
official **1.81.1-e04cf9aa915c** is only for coverage and the second compatibility
execution; its newer-format bytecode is not a deployment build. The test framework
stays pinned to `a9a6825eaf6273cc819ee3bcf65fd4909f7624a9`.

With Node.js 22+ and new destination paths:

```sh
SUI_BINARY=/path/to/sui-1.66.2 \
SUI_TRACE_BINARY=/path/to/sui-1.81.1 \
node tools/test-security.mjs /tmp/clmm-current-new --trace-full

SUI_BINARY=/path/to/sui-1.66.2 \
node tools/test-version-gates.mjs /tmp/clmm-current-new /tmp/clmm-version-new

SUI_BINARY=/path/to/sui-1.66.2 \
SUI_TRACE_BINARY=/path/to/sui-1.81.1 \
node tools/test-legacy-positions.mjs /tmp/clmm-current-new /tmp/clmm-legacy-new

SUI_BINARY=/path/to/sui-1.66.2 \
node tools/test-capabilities.mjs /tmp/clmm-current-new /tmp/clmm-compiler-new

node tools/check-security-witnesses.mjs \
  /tmp/clmm-current-new /tmp/clmm-version-new /tmp/clmm-witnesses-new.json

node tools/security-guard-inventory.mjs \
  /tmp/clmm-current-new/evidence /tmp/clmm-guards-new.json

node tools/check-version-surface.mjs \
  /tmp/clmm-current-new /tmp/clmm-version-new \
  /tmp/clmm-guards-new.json /tmp/clmm-version-witnesses-new.json
```

No production modification, contract upgrade, wallet access, signing, MVR update
or mainnet transaction is part of this evidence-only revision.
