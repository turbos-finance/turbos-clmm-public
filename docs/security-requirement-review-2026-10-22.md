# CLMM security test scope and residual review — 22 October 2026

Target: deployed CLMM package v22, with `pool::VERSION = 18`. Production source and
deployment metadata are unchanged. This document distinguishes observed test results,
language/input restrictions and explicit exclusions; it does not claim exhaustive testing.

## Evidence map

| Control / invariant family | Executed evidence | Scope and qualification |
|---|---|---|
| Four ACL roles at all 14 live factory/reward management entries | `security_entrypoint_tests`: 56 cases, checked by `check-security-witnesses.mjs` | Required-only success; missing, other-only and revoked role rejection at the exact production module/code |
| Governance/referral capability ownership | Existing ACL/Partner ownership and transfer tests; compiler negatives | Sui-owned input rules and defining-module constructors are shared boundaries. A failed input take is not relabelled as an unauthorized business call |
| NFT/pool identity, user position access and Burn NFT proof | Position/Burn NFT tests; NFT and proof constructor negatives | Normal NFT-owned positions and pool binding are tested separately from synthetic owner-address compatibility states |
| Reward index/vault/amount bounds and exact withdrawals/refunds | Boundary and entry tests | Real vault ID binding and amount conservation, not only the role-check helper |
| Fee collection versus LP principal; flash repayment pool/partner/amount binding | Fee/flash, Partner-flash and Partner-router tests | Both swap directions; exact/under/over/repeated operations; two receipt types also cannot be forged or dropped |
| Pause, deadlines, prices, slippage and partial fills | Position, router, Partner-router and quote/cross tests | Real execution paths and exact defining-module rejections; not all compound-condition alternatives are inferred from a line hit |
| Position exit obligations | `security_exit_obligation_tests`: nine cases | Zero liquidity alone cannot clear outstanding token fees/rewards; partial collection still rejects burn; complete collection allows it |
| Version acceptance and retirement state | 66 separate version fixture cases; all 53 direct version calls mapped | Current-version guard passes in normal execution; exact future-version rejection at each direct check and three delegated wrappers. Explicit test-only private-state constructor in a disposable copy; not a historical package deployment/rollout test |
| Fee-tier witness, uniqueness, rate and spacing | `security_fee_tier_tests`: 11 cases, mapped to four assertions | Real OTW versus ordinary drop type; duplicate type; fee 0/999999/1000000/u32-max; spacing 0/1/16383/16384. Both compound-bound rejection arms tested. Accepted tiers deploy a real pool with exact readback |
| NFT metadata persistence | `security_metadata_tests`: seven cases | Stored defaults, next-transaction persistence, actual newly minted NFT fields, unchanged old NFT, recipient delivery and reserves/refunds |
| Integer/rounding boundaries | `security_numeric_properties_tests`: 37 cases, plus existing math tests | Wider-integer quotient/remainder oracle, representative deterministic grids, zero division and overflow negatives. Not exhaustive proof for every possible input |
| Owner-address position compatibility | 34 separate compatibility fixture cases, on both toolchains with 34 traces | Actually minted record rekeyed in a disclosed test-only overlay, preserving its bytes and pool fields; not a mainnet legacy-object survey |
| Retired externally public management entries | 21 exact abort-stub cases | The wider source inventory also contains friend/private retired helpers; these are not falsely counted as externally callable runtime cases |

See the [647-test report and artifacts](../evidence/security-tests-2026-10-22-guards/README.md),
[executed witness mapping](../evidence/security-tests-2026-10-22-guards/security-witnesses.json),
[version-surface mapping](../evidence/security-tests-2026-10-22-guards/version-surface-witnesses.json)
and [guard inventory](../evidence/security-tests-2026-10-22-guards/security-guard-inventory.json).

## Version-check witness review

The normal-build inventory contains **53 direct calls to `check_version`**. Each call
has a normal-suite execution hit. In the unmodified source/test tree, `Versioned` is
only constructed at the current constant 18, and the version setter writes that same
constant. Thus these hits demonstrate current-version guard passes, not unknown
assertion outcomes. This does not mean every enclosing business operation succeeds.

The separate fixture supplies stored version 19 to each of those 53 functions and
requires the exact `pool::23` rejection. It also tests three public delegating wrappers:
the two Partner-router direction wrappers and Burn NFT fee collection. Together with
10 direct acceptance/upgrade/no-downgrade state cases, this is **66 fixture tests**.
Repayment cases first borrow under a valid current version and construct real exact
repayment coins/receipts, then attempt repayment under the future version. Position
and Burn NFT paths use real created objects, not forged inputs.

`check-version-surface.mjs` checks the 53-function inventory, matching source/test
hashes, guard-line execution, all 56 named future-entry rejections and their exact
expected module/code annotations. It does not prove governance custody, deployed
rollout behavior, or historical package compatibility. Fixture runs remain separate
from normal-source line/edge coverage.

## Source inventory and exclusions

The inventory covers every one of the **425 normal-build production functions**, using
the original-toolchain function inventory and exact production source hashes. It records
**172 assertions, 67 direct role/version-check calls and five non-retired explicit abort
statements**, including private math/state helpers. It also identifies 50 functions with
capability/receipt inputs, 38 abort-zero retired functions and 15 lifecycle `init` functions.

An executed source line is **not** proof that both outcomes of its condition have been
tested. The inventory leaves those witness decisions explicit rather than auto-closing them.
Line/function coverage also retains unused code in its denominator.

Three assertion anchors have no normal-suite line hit. They are in these two helpers:

| Helper | Anchors | Current-source classification |
|---|---|---|
| `pool::update_reward_manager` | Reward index below maximum and initialized length | Friend-only. No incoming call in current production source; the public `reward_manager::update_reward_manager` is an unconditional abort stub. A separate compiler fixture rejects calling the helper from a non-friend module |
| `position_manager::clean_position` | Stored tick bounds match the requested bounds | Private. No incoming call in current production source. A separate compiler fixture rejects an external call. Do not confuse it with the different private `pool::clean_position` used by the old pool migration helper |

These are classified as unavailable through the current public surface, **not as executed
negative runtime tests**. The same review distinguishes lifecycle initializers, unused
getters, obsolete private helpers and normal live business entries. A future upgrade that
connects an unused helper to a live entry must revisit the relevant test requirement.

## Compatibility result that must not be overstated

The fixture uses zero as the lower tick to distinguish historical `+0` key encoding from
current `-0` encoding. It relocates a real minted pool Position under an owner-address key,
without rewriting the Position payload, NFT, pool fields or production checks.

For both encodings, the original holder can increase/decrease liquidity and collect fees
and rewards, with conservation assertions; pause and expired deadlines reject correctly.
However, transferring the NFT does **not** reassign an account-keyed pool Position:

- The new holder cannot decrease or collect the original holder's record.
- Increasing as the new holder creates that holder's own pool record and leaves the
  original record intact. This must not be presented as migration of the old entitlement.
- Returning the NFT without an intervening increase restores the original-holder path.

Thus synthetic compatibility behavior is now tested, but **legacy NFT transferability is
not claimed to be equivalent to a modern NFT-keyed position**. We have not asserted that
any particular live object still uses this representation. No migration or production fix
is included in this evidence-only change.

## Rounding result that must not be overstated

`full_math_*::mul_div_round` uses nearest rounding, with half ties up, not ceiling.
The deployed token-B delta's `true` mode calls that nearest helper; tests distinguish this
from `mul_div_ceil` instead of silently calling both “round up.” The amount-A rational
oracle independently checks its floor/ceiling modes. Large B-price-step boundary cases
use exact quotients and do not prove conservative rounding for all fractional cases.

This documents current arithmetic semantics, not approval of every economic rounding
invariant or an unreviewed claim of an exploitable vulnerability. Production formulas
have not been changed. A stronger conservative-rounding requirement needs explicit
specification, reachability analysis and audit review before any contract change.

## Remaining test review

The previously listed metadata readback, synthetic owner-address compatibility,
additional arithmetic boundaries, all direct version-call witnesses and fee-tier guard
batches are implemented and verified. Remaining work is the **semantic witness review
for the other source guards and invariants**, particularly compound-condition arms,
rounding specifications and reachability/exclusion decisions. The source inventory and
named test mapping make that review concrete; neither a percentage nor this static list
demonstrates exhaustive authorization or invariant testing. No production upgrade,
MVR update or mainnet transaction was performed.
