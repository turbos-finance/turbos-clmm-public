# Turbos CLMM Protocol

## Overview
Turbos CLMM (Concentrated Liquidity Market Maker) is a high-performance, modular, and secure on-chain liquidity protocol implemented in Move. It enables users to provide liquidity within custom price ranges, perform efficient swaps, and manage positions with fine-grained control. The protocol is designed for composability, extensibility, and robust security.

## Modules

### 1. pool.move
- **Purpose:** Implements the core CLMM pool logic, including liquidity management, swaps, fee accrual, and reward distribution.
- **Key Features:**
  - Add/remove liquidity within tick ranges
  - Swap tokens with concentrated liquidity
  - Collect fees and protocol rewards
  - Tick and position management

### 2. pool_factory.move
- **Purpose:** Manages pool creation, configuration, and administration.
- **Key Features:**
  - Deploy new pools with custom parameters
  - Set and update fee tiers
  - Manage protocol-level settings

### 3. position_manager.move
- **Purpose:** Handles user positions, NFT minting/burning, and position metadata.
- **Key Features:**
  - Mint/burn position NFTs
  - Track user positions and rewards
  - Update NFT metadata (name, description, image)

### 4. position_nft.move
- **Purpose:** Defines the NFT standard for representing liquidity positions.
- **Key Features:**
  - Mint and burn position NFTs
  - Store position-specific metadata

### 5. fee.move & feeXXXXbps.move
- **Purpose:** Define fee tiers and tick spacing for pools.
- **Key Features:**
  - Create and manage fee configurations
  - Support multiple fee levels (e.g., 100bps, 500bps, 3000bps, etc.)

### 6. math_liquidity.move
- **Purpose:** Provides core math for liquidity calculations.
- **Key Features:**
  - Compute liquidity for given amounts and price ranges
  - Convert between liquidity and token amounts

### 7. math_sqrt_price.move
- **Purpose:** Math utilities for price and tick calculations using Q64.64 fixed-point arithmetic.
- **Key Features:**
  - Calculate next sqrt price after swaps
  - Convert between price and tick

### 8. math_swap.move
- **Purpose:** Swap math logic for CLMM swaps.
- **Key Features:**
  - Compute swap steps and amounts
  - Handle fee and price impact calculations

### 9. math_tick.move
- **Purpose:** Tick and price range management.
- **Key Features:**
  - Convert between ticks and sqrt prices
  - Tick spacing and range validation

### 10. partner.move
- **Purpose:** Partner/referral system for protocol integrations.
- **Key Features:**
  - Register and manage partners
  - Distribute referral fees

### 11. reward_manager.move
- **Purpose:** Manage additional reward programs for liquidity providers.
- **Key Features:**
  - Track and distribute external rewards

### 12. swap_router.move
- **Purpose:** High-level router for multi-hop swaps and user-friendly interfaces.
- **Key Features:**
  - Route swaps across multiple pools
  - Support for complex swap paths

### 13. pool_fetcher.move
- **Purpose:** Utility for querying pool and position data.
- **Key Features:**
  - Fetch pool state and user positions

### 14. lib/math_*.move, lib/i*.move
- **Purpose:** Low-level math and integer utilities (u64, u128, i32, i64, i128, bit operations).
- **Key Features:**
  - Safe arithmetic, overflow checks
  - Bitwise and fixed-point math

## Security
- All modules are designed with strict overflow checks, input validation, and permission controls.
- Extensive unit tests cover edge cases and extreme values.

## Getting Started
1. Clone the repository.
2. Install Move toolchain and dependencies.
3. Run unit tests:
   ```
   move test
   ```
4. Deploy modules to your Move-compatible blockchain.

## License
MIT © Turbos Finance, Inc.
## Current-release metadata verification (2026-10-15)

See [verified build configuration and official source-verification evidence](evidence/mvr-source-2026-10-15/README.md). This update does not change production functions. MVR GitInfo update and a fresh-cache registry-consumer run are separate follow-ups.

## Public MVR consumer result (2026-10-15)

The owner executed the current-version GitInfo update. The official MVR add and a real-import consumer build both passed using a new empty cache for the validation run. See [consumer logs, manifest, lockfile and results](evidence/mvr-consumer-2026-10-15/README.md). This supersedes the earlier metadata-update-pending status, without changing the source commit recorded in MVR.

## Tests in the current checkout (2026-10-15)

The reviewed test changes are now directly tracked in the source/tests tree: **292 passed, 0 failed**. Run `node tools/test-current.mjs NEW_DISPOSABLE_DIRECTORY`. See [current test code, run instructions and results](evidence/tests-current-2026-10-15/README.md). Production bytecode and MVR source links are unchanged. Historical tools/repro overlays and coverage reports retain their original scope.

## Current coverage snapshot (2026-10-19)

All **292/292** current public tests passed unfiltered. Coverage remains **partial (187/292 traced tests)** because full tracing still overflows the stock CLI on macOS and Linux. See [current scope, reports, logs and reproduction](evidence/coverage-2026-10-19/README.md). No production code was changed.

## Latest security testing and full capture (2026-10-22)

**647/647 tests pass and all 647 have individual value traces**, without a test filter or
exclusions. Production line coverage is **91.86%** and CFG-edge coverage is **88.41%**.
There are 355 additional tests versus the historical 292-test baseline, plus
66 separately reported version-state tests, 34 compatibility-state tests (with separate
traces) and 12 compiler-negative cases.

See the [current report, logs, metric definitions and reproduction](evidence/security-tests-2026-10-22-guards/README.md)
and [guard/test matrix](docs/security-test-matrix-2026-10-21.md).
The [executed witness mapping](evidence/security-tests-2026-10-22-guards/security-witnesses.json)
checks all 14 live ACL-gated factory/reward entries against 56 named positive/negative
runtime cases, plus four fee-tier/witness assertions. The
[version-surface mapping](evidence/security-tests-2026-10-22-guards/version-surface-witnesses.json)
covers all 53 direct version checks and three delegated wrappers, with the stated
normal-current versus synthetic-future scope. Metadata persistence/readback, additional arithmetic boundaries and
synthetic account-keyed legacy positions are now tested. See the
[test-scope review and compatibility/rounding limits](docs/security-requirement-review-2026-10-22.md).
The earlier 509/592/636-test reports remain historical snapshots.
Sui 1.81.1 is used **only for coverage instrumentation**; deployment bytecode verification
remains on Sui 1.66.2 and matches all 33 recorded deployed root-module hashes. Production
source, mainnet state and MVR pointers are unchanged. This supersedes the older partial
capture status for the current suite, not the historical results themselves. Full capture
does not imply exhaustive authorization or invariant coverage.
