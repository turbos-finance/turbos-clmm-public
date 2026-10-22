# CLMM metadata, arithmetic and compatibility evidence — 22 October 2026

Current evidence revision for the tracked tests. Main-suite execution completed on
21 October; supplemental checks and the requirement-level review were finalized on
22 October. Earlier dated reports retain their original scope.

## Verified results

| Check | Result |
|---|---:|
| Original Sui 1.66.2 unfiltered unit suite | **636/636 passed** |
| Sui 1.81.1 unfiltered unit suite and value traces | **636/636**, no exclusions |
| Production line coverage | **91.81%**, 3485/3796 |
| Production CFG-successor-edge coverage | **88.08%**, 1566/1778 |
| Production function coverage | **84.00%**, 357/425 |
| Original normal-build root modules | **33/33 match** recorded deployed bytecode hashes |
| Separate private-state version tests | **36/36 passed** |
| Separate compatibility-state tests | **34/34 passed**, on both toolchains; **34 individual traces** |
| Separate compiler-negative cases | **12/12 expected rejections**, exact diagnostic codes checked |

The 36 version tests, 34 compatibility tests and 12 compiler cases are **separate**;
they are not added to the 636 unmodified-production-source test/coverage denominator.
There are 44 new normal-source cases since the 592-test report, and 344 since the old
292-test baseline. Test-only constructors in disposable fixture copies do not enter the
production build. Every original normal module remains deployment-bytecode matching.

## Additions

- **Seven metadata readback tests:** independent field updates, combined updates,
  UTF-8 name/description, empty metadata, persistence into the next transaction,
  newly minted NFT fields, old NFT immutability, recipient delivery and refund conservation.
- **37 arithmetic tests:** wider-integer quotient/remainder oracle for 32/64/128-bit
  floor/nearest/ceiling helpers; deterministic input grids; shifts, carries, wrapping
  subtraction, division-by-zero and narrowing/checked-overflow rejection; price-step
  boundaries. Nearest and ceiling semantics are explicitly distinguished.
- **34 compatibility tests:** a real minted Position is rekeyed under an account address
  in a disclosed test-only overlay, with unchanged payload/pool fields. Historical `+0`
  and current `-0` encodings, increase/decrease, fee/reward claims, pause, deadlines and
  NFT transfer/return behavior are exercised on both toolchains.
- **Seven additional compiler negatives:** NFT/proof and both receipt constructors;
  Partner receipt dropping; calls to a non-friend reward helper and a private cleanup
  helper. Together with the previous five cases, there are 12 exact compiler rejections.
- **Complete normal-function source inventory:** 425 functions, 172 assertions,
  67 direct role/version calls and five non-retired explicit aborts. Static execution
  anchors are not relabelled as positive/negative semantic proof.

## Important qualifications

All 14 live ACL-gated factory/reward entries still have their 56 required-only,
missing/other-only/revoked-role execution witnesses. The updated witness file also
lists the 127 boundary cases added across the latest two revisions and 26 explicit
future-version business-entry rejections.

Synthetic compatibility tests are **not** a mainnet object survey or historical package
replay. Account-keyed legacy positions are not automatically reassigned by transferring
an NFT; the new holder's increase creates a different account record. That behavior is
documented, not described as successful transfer of all legacy position rights.

Likewise, the deployed nearest-rounding helper is not relabelled as ceiling. Testing
its existing formula is not an endorsement of all conservative-rounding invariants.
See the [test-scope review and explicit limits](../../docs/security-requirement-review-2026-10-22.md).

Full capture and coverage percentages do not by themselves demonstrate exhaustive
authorization or invariant testing. The remaining
task is source-guard-by-guard semantic witness review and explicit reachability/rounding
decisions, not relabelling all uncovered code as safe or removing it from the denominator.

## Evidence

- [Main tests](full-tests.log), [full traced tests](traced-tests.log), [run completeness](run.json), [results](result.json).
- [Production coverage JSON](production-coverage.json), [production LCOV](production-lcov.info), [raw official LCOV](raw-lcov.info).
- [Source/test hashes](source-hashes.json), [normal bytecode comparison](normal-bytecode.json), [normal function inventory](normal-build-functions.json).
- [Executed witness mapping](security-witnesses.json), [public/friend inventory](security-entry-inventory.json), [all-function guard inventory](security-guard-inventory.json).
- [Version fixture results](version-fixture/result.json), [test log](version-fixture/tests.log).
- [Legacy fixture results](legacy-fixture/result.json), [original-toolchain tests](legacy-fixture/tests.log), [fixture traced tests](legacy-fixture/traced-tests.log).
- [Compiler-negative results](capabilities/result.json) and [exact diagnostic logs](capabilities/).
- [Official tracing binary provenance](release-download.json), [toolchain separation](toolchain-notes.json).

Tested source/test tree SHA-256:
`58a2433ceb5c3dddbd0741b0f20dec80d15a9d3c77ef88c928a4fa3899ad055e`.
Base public commit before these test additions: `f286c6d6242ec4caab145d8441d655c5ee288a34`.
The base commit alone does not contain the new tests. Use the tracked files and exact
hashes in this revision; production source is unchanged from the verified deployment.

## Metrics and reproduction

Line/function denominators exclude dependencies and test-only code using the original
normal build's function inventory. Official LCOV denominators are validated against
compiler source maps. Branches mean **CFG successor edges, including unconditional
edges**, not decision-only coverage or MC/DC. Normal-bytecode comparison uses recorded
immutable deployment hashes, not a new chain read or independent dependency-bytecode audit.

Sui **1.66.2-a9a6825eaf62** remains the production/deployment-matching build toolchain.
Checksum-verified official **1.81.1-e04cf9aa915c** is used only for coverage/tracing and
the second compatibility execution; its newer-format bytecode is not a deployment build.
The test framework remains pinned to `a9a6825eaf6273cc819ee3bcf65fd4909f7624a9`.

Use Node.js 22+ and new destination paths:

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
```

No production source or deployment metadata modification, MVR update, signing,
wallet access, contract upgrade or mainnet transaction is part of this revision.
