# CLMM requirement-level review — 22 October 2026

Target: deployed CLMM package v22, with `pool::VERSION = 18`. Production source and
deployment metadata are unchanged. This document distinguishes observed test results,
language/input restrictions and explicit exclusions; it does not declare external acceptance.

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
| Version acceptance and retirement state | 36 separate version fixture cases | Explicit test-only private-state constructor in a disposable copy; not a historical package deployment/rollout test |
| NFT metadata persistence | `security_metadata_tests`: seven cases | Stored defaults, next-transaction persistence, actual newly minted NFT fields, unchanged old NFT, recipient delivery and reserves/refunds |
| Integer/rounding boundaries | `security_numeric_properties_tests`: 37 cases, plus existing math tests | Wider-integer quotient/remainder oracle, representative deterministic grids, zero division and overflow negatives. Not exhaustive proof for every possible input |
| Owner-address position compatibility | 34 separate compatibility fixture cases, on both toolchains with 34 traces | Actually minted record rekeyed in a disclosed test-only overlay, preserving its bytes and pool fields; not a mainnet legacy-object survey |
| Retired externally public management entries | 21 exact abort-stub cases | The wider source inventory also contains friend/private retired helpers; these are not falsely counted as externally callable runtime cases |

See the [636-test report and artifacts](../evidence/security-tests-2026-10-22/README.md),
[executed witness mapping](../evidence/security-tests-2026-10-22/security-witnesses.json)
and [guard inventory](../evidence/security-tests-2026-10-22/security-guard-inventory.json).

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

## Remaining acceptance work

The previously listed metadata readback, synthetic owner-address compatibility and
additional arithmetic-boundary test batches are implemented and verified. Remaining work
is the **guard-by-guard semantic witness review**, particularly compound-condition arms,
rounding specifications and reachability/exclusion decisions. The source inventory and
named test mapping make that review concrete; neither a percentage nor this static list
automatically establishes “every auth check / invariant.” External acceptance remains a
separate decision. No production upgrade, MVR update or mainnet transaction was performed.
