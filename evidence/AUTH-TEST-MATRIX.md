> October 15 update: the tests/corrections described below are now directly tracked in the current source/test tree. The current suite passes 292 tests; use [current-checkout instructions](tests-current-2026-10-15/README.md). The remaining sections describe the October 14 overlay baseline, not a claim of exhaustive coverage.

# First authorization/invariant test batch — Turbos CLMM

Pinned deployed source: `a02c7a0b78d8a53bb0534835c309b2d115254e01`.
[Results](tests-security-2026-10-14.json): **292 passed, 0 failed**.
[Full output](tests-security-2026-10-14.log), [before-overlay baseline](tests-before-overlay-2026-10-14.json).

## Explicit test changes

Adds 10 ACL/ownership tests. All 282 existing tests remain unchanged and pass.

The source anchors and production functions are untouched in this repository. The test
patch/new files are versioned under tools/repro and applied only in a disposable test
checkout. Normal build mode never applies the overlay. No mainnet transaction is needed.

## Test mapping and remaining scope

| Control | Positive case | Negative case |
|---|---|---|
| Four ACL check functions | security_each_granted_acl_role_passes_its_check | security_missing_{clmm,reward,fee,pause}_role_is_rejected |
| Least privilege | pause-only check / fee-only check succeeds | security_pause_only_cannot_claim_fees; security_fee_only_cannot_manage_pool |
| Revocation | fee check before revocation succeeds | security_revoked_fee_role_is_rejected |
| Member removal | member receives pause role first | security_removed_member_is_rejected |
| AdminCap ownership (Sui input model) | owner initializes ACL | security_non_owner_cannot_take_pool_factory_admin_cap |

These cover check helpers, not every privileged entry-point call site. Legacy version gate,
fee destination restriction, real signed-PTB ownership validation and every invariant still
need dedicated evidence. Passing tests does not remediate the fee destination or version-gate design.

## Re-run

Install the pinned CLI from REPRODUCE-LATEST.md, then:

```bash
cd tools/repro
npm install --ignore-scripts
node reproduce.mjs /tmp/turbos-clmm-security-tests test
```

The path must not exist. Framework native functions are aligned with the CLI; VM test
budget is 1,000,000,000, not a mainnet gas payment.

A separate official tracing-enabled CLI now supplies a
[production-only coverage report](coverage-2026-10-14/README.md). Its precise full/partial
tracing scope is disclosed there; this original passing test baseline remains unchanged.
The complete every-auth/every-invariant matrix is still required. R10 is not closed.
