# CLMM security test matrix — 21 October 2026

Status: work in progress, not an exhaustive authorization/invariant coverage claim.
Target production source is deployed CLMM v22 (`pool::VERSION = 18`). No production source,
published package addresses or production dependency settings are changed by this batch.

**Latest:** [509-test full-capture evidence](../evidence/security-tests-2026-10-21-full/).
All 509 tests pass and have traces with Sui 1.81.1; deployed-bytecode verification stays
on Sui 1.66.2 (33/33 matching). Lines: 84.80%; CFG edges: 80.71%. The 217 new cases include
the earlier 190 plus 12 Partner flash-repayment and 15 Burn NFT cases. Separate version-state
fixture: 29 tests; capability/receipt compiler negatives: five. No exclusions apply to
the latest full capture. Earlier partial reports below are historical snapshots.

## Final additions and current review status

- Partner flash repayments: both directions, exact pool/referral/output conservation,
  partner expiry, wrong partner (pool::27), wrong pool (pool::24), under/overpay (pool::25).
- Burn NFT: full-range proof conversion preserves liquidity and balances; narrow ranges
  reject (position_manager::16); wrong pools reject (15); owner/transfer, deadlines (8),
  pause (pool::8), fee/reward wrappers, and direct NFT burn without pool-asset movement.
- Tracing tooling: the original runtime still crashes, but the newer official runtime
  completes the entire unchanged-source suite; the reproducible two-toolchain runner is
  validated. This is not an upgrade to the on-chain contract or its production build.
- Remaining review: audit uncovered line/branch lists and the public/friend inventory for
  further authorization/invariant gaps. Mathematical/rare-state and untested wrapper
  branches are not silently counted as covered. No claim of 100% or final external acceptance.

**Stage-two update:** [482-test regression and selected coverage evidence](../evidence/security-tests-2026-10-21-stage2/).
The first-batch numbers below remain historical. Current total: 482 unfiltered tests,
190 new since the 292-test public baseline; 200 selected security regression tests include
10 pre-existing ACL cases. Explicit selected tracing covers 196, not the full 482.

## Stage-two additions

| Test module / fixture | New cases | Positive and negative observations |
|---|---:|---|
| `security_partner_tests` | 23 | Admin-cap operations; partner/cap ID binding; exact merged fees; no duplicate claim; ownership transfer; rate and time boundaries |
| `security_position_tests` | 28 | Real mint/refund conservation, increase/decrease conservation, NFT/pool binding, deadlines/slippage, pause/resume, uncleared NFT burn rejection, complete exit/burn, object ownership |
| `security_fee_flash_tests` | 38 | Nonzero fees in both directions, LP principal separation, partial/zero/repeated requests, exact recipient amounts; exact/under/over/wrong-pool flash repay; pause; price; router limits |
| `security_retired_tests` | 21 | All 15 externally public retired factory entries and six retired reward entries reject at exact defining-module abort(0) |
| Isolated version-state fixture | 29 separate | Current/older/future/max state, upgrade/no-downgrade, future-version rejection at 19 business/ACL/deployment entries; explicit disposable test-only overlay, normal bytecode still identical |

The version fixture is not counted among the 482 tests run against unmodified production
source. It creates private states unreachable through the public API without altering
production logic or the repository source. No actual historical package deployment is tested.

Full 200-case security tracing still fails on a collection path; four collection success/
recovery cases are explicitly excluded in partial mode, including two conservative analogous
paths. They remain in the 482-case unit suite. Selected coverage: 55.14% lines, 52.36% CFG
edges; not a full-suite percentage. See the dated report for reproduction and diagnostics.

## ACL-protected business entry points

`tests/security_entrypoint_tests.move` adds four execution tests for each entry below:

1. The operator has only the required role and the real entry succeeds.
2. The operator has no role and the real entry rejects it.
3. The operator has every other defined role, but not the required role, and is rejected.
4. An administrator revokes the required role from an operator with all four roles; the
   operator's next transaction is rejected by that same real entry.

The three rejection cases specify the exact production abort code and module, so a fixture
failure cannot silently satisfy them. Each test name is the entry's base name plus
`_allows_required_role`, `_rejects_missing_role`, `_rejects_other_roles`, or
`_rejects_revoked_role`. These are runtime tests, not just direct calls to role-check helpers.

| Production entry | Required role / mask | Rejection | Success observation |
|---|---|---|---|
| `pool_factory::set_fee_tier_v2` | CLMM / 1 | `pool_factory::6` | Registers an unused fee tier |
| `pool_factory::set_fee_protocol_v2` | CLMM / 1 | `pool_factory::6` | Accepts the rate update |
| `pool_factory::update_pool_fee_protocol_v2` | CLMM / 1 | `pool_factory::6` | Stored pool rate equals requested rate |
| `pool_factory::collect_protocol_fee_v2` | Fee claim / 4 | `pool_factory::8` | Zero-balance collection creates zero-valued coins at recipient |
| `pool_factory::collect_protocol_fee_with_return_v2` | Fee claim / 4 | `pool_factory::8` | Zero-balance collection returns zero-valued coins |
| `pool_factory::toggle_pool_status_v2` | Pause / 8 | `pool_factory::9` | Unlocked → locked → unlocked |
| `pool_factory::update_nft_name_v2` | CLMM / 1 | `pool_factory::6` | Update call succeeds; NFT metadata readback remains a follow-up |
| `pool_factory::update_nft_description_v2` | CLMM / 1 | `pool_factory::6` | Update call succeeds; NFT metadata readback remains a follow-up |
| `pool_factory::update_nft_img_url_v2` | CLMM / 1 | `pool_factory::6` | Update call succeeds; NFT metadata readback remains a follow-up |
| `reward_manager::init_reward_v2` | Reward / 2 | `pool_factory::7` | New reward has requested manager |
| `reward_manager::reset_reward_v2` | Reward / 2 | `pool_factory::7` | Nonzero emissions reset to zero; growth is zero |
| `reward_manager::add_reward_v2` | Reward / 2 | `pool_factory::7` | Vault increases by exact deposited amount |
| `reward_manager::remove_reward_v2` | Reward / 2 | `pool_factory::7` | Vault decreases by 40; recipient receives exactly 40 |
| `reward_manager::update_reward_emissions_v2` | Reward / 2 | `pool_factory::7` | Stored Q64 emissions equal requested rate |

14 entries × 4 cases = **56 new tests**. Role masks refer to deployed bit positions, not
numbers of signers. These 14 entries are the live ACL-gated entries in `pool_factory` and
`reward_manager`; this is not a claim to cover every guard in the entire CLMM package.

## Boundary and accounting tests

`tests/security_boundary_tests.move` adds **24 tests**:

| Area | Cases | Assertion / exact rejection |
|---|---|---|
| Reward withdrawal | Exact balance; zero; twice; over balance; repeated full withdrawal; invalid index | Vault decrease equals coins received; pool A/B reserves unchanged; `pool::16` or `pool::13` |
| Reward deposit | Excess input refund; zero deposit refund; exact input; invalid index | Exact vault increase and refund conservation; `pool::13` |
| Reward-vault binding | Use a different real vault of the same coin type | `pool::14`, not an insufficient-balance error |
| Reward indices | Initialization beyond max; skipped initialization index; reset beyond max; emissions for nonexistent slot | `pool::13` |
| Protocol fee bounds | Global/pool rates 0 and 999999 allowed; 1000000 rejected | Pool rate readback; `pool_factory::1` |
| Version | Current version accepted; reapplying current upgrade rejected | `pool::22`; does not test synthetic future-version state |
| Pause | Pause then call real `position_manager::mint_with_return_` | `pool::8`, not a test-framework or input-preparation error |

## Tightened historical negative tests

- `pool_factory_acl_tests::test_add_role_unauthorized`: narrowed to
  `sui::test_scenario::3`. This proves object-ownership rejection, **not** execution of
  `pool_factory::add_role` by a non-owner.
- `reward_manager_acl_tests::{test_deprecated_init_reward_function,test_deprecated_reset_reward_function}`:
  narrowed to `reward_manager::0`, matching the actual retired entry-point stubs.

## Reproduce

Use the recorded Sui 1.66.2 CLI. At this checkout's root:

```sh
SUI_BINARY=/path/to/sui node tools/test-security.mjs /tmp/clmm-security-new
```

The destination must not already exist. The runner creates disposable test and normal-build
packages and an empty isolated client configuration; it never signs or submits a transaction.
It runs the entire current suite, checks that all 80 new test names were actually executed,
checks exact production-source hashes against the verified baseline, and compares fresh
normal-build root bytecode against the recorded deployed-module hashes. No fresh chain read
or independent dependency-bytecode audit is claimed.

To also collect coverage of **only the 80 new tests**, using the official tracing-enabled CLI:

```sh
SUI_BINARY=/path/to/tracing/sui node tools/test-security.mjs /tmp/clmm-security-trace-new --trace
```

This is explicitly a selected-subset report, not full CLMM coverage. Missing traces, duplicate
test names, a failed test, source drift, insufficient disk space or a runtime timeout fail the
runner. Historical coverage reports remain historical; they are not silently relabelled.

## Capability construction and receipt obligations

`tools/compile-fail/` and `tools/test-capabilities.mjs` provide five compiler-negative cases,
run against the same passing source/test tree. Four cases try to construct
`PoolFactoryAdminCap`, `RewardManagerAdminCap`, `PartnerAdminCap` and `PartnerCap` outside
their defining modules; all reject with `E04001` restricted visibility. A fifth tries to
return without consuming `FlashSwapReceipt`; it rejects with `E06001` missing drop ability.
These prove compiler restrictions, not an on-chain custody check or runtime role execution.
They are counted separately from the 372 runtime tests.

Validated first-batch evidence: [results and logs](../evidence/security-tests-2026-10-21/).

## Remaining work before the 23 October evidence submission

- Complete cap-gated entry inventory and capability ownership/transfer execution paths;
  construction-restriction fixtures for the four capability types are now validated.
- Partner flash partner-ID binding and Burn NFT paths are now tested in the latest report;
  continue reviewing less common mathematical/state combinations and wrapper branches.
- Review public/friend entry inventory against all positive/negative test mappings. The 21
  externally public retired factory/reward entries are tested; private/friend retired helpers
  remain compiler visibility boundaries, not direct runtime cases.
- Full-suite tracing is now resolved with the isolated newer runtime; retain the original
  toolchain's failure evidence and keep production bytecode verification on its original compiler.
- Final source/bytecode consistency checks, sensitive-content review, and public evidence links.
