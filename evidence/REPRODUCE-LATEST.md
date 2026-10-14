# Latest release reproduction — Turbos CLMM

Verified on 2026-10-14. Mainnet v22: `0xa5a0c25c79e428eba04fb98b3fb2a34db45ab26d4c8faf0d7e39d66a63891e64`.
MVR: `@turbos/turbos`. Source: [`a02c7a0b78d8a53bb0534835c309b2d115254e01`](https://github.com/turbos-finance/turbos-clmm-public/tree/a02c7a0b78d8a53bb0534835c309b2d115254e01).

## Result and scope

Fresh compilation reproduced all 33 root modules exactly, byte for byte, with no missing/extra modules.
[Machine-readable hashes and result](bytecode-verification-2026-10-14.json).
Source and existing tests were checked against the pinned revision and were not edited.
Only disposable manifests/dependency resolution were adjusted: current published-at, original
named address and explicit local dependencies. Recipe manifests are committed under tools/repro.
This does not assert that the original historical manifest builds unchanged today.

The report records mainnet linkage but does not independently verify dependency linkage
or type-origin tables. It is not a complete sui client verify-source result, security
audit, mvr add consumer validation, or historical-version verification. September's
build-verification.json is archived evidence, not this fresh result.

## Toolchain and dependencies

- Sui CLI: `sui 1.66.2-a9a6825eaf62` (verification host: Darwin arm64).
- Node.js >=22; comparator SDK `@mysten/sui@2.22.1`.
- Build framework: [`25804c243d07dd73c0d199e7794383bd855cd436`](https://github.com/MystenLabs/sui/tree/25804c243d07dd73c0d199e7794383bd855cd436/crates/sui-framework/packages).

## Re-run

Install the exact Sui CLI recorded above first. From this public repository's current
main branch (which supplies tools; the script separately checks out the immutable release):

```bash
cd tools/repro
npm install --ignore-scripts
# Choose a new path that does not already exist.
node reproduce.mjs /tmp/turbos-clmm-repro build
```

The script clones public source/dependencies at full SHAs, builds in a new workspace,
and reads immutable mainnet module BCS over gRPC. It never signs or submits a transaction.
It refuses to overwrite an existing workspace and exits nonzero for compilation errors
or any module mismatch. Network access to GitHub and the Sui mainnet fullnode is required.
The recipe mirrors the completed local build; an independent clean-network runner remains
a useful additional check.

## Existing test baseline

[Result](tests-2026-10-14.json), [complete output](tests-2026-10-14.log): **282 passed, 0 failed**.

```bash
node reproduce.mjs /tmp/turbos-clmm-tests test
```

Tests use framework `a9a6825eaf6273cc819ee3bcf65fd4909f7624a9` to align test_utils/native functions
with the installed CLI; production-bytecode comparison uses the older framework above.
The VM unit-test budget is 1,000,000,000 (not a mainnet gas payment). Smaller budgets
time out on existing large tick-math tests. Contract source and assertions are unchanged.
No line/branch coverage was generated: this installed CLI lacks tracing support.
Passing existing tests does not establish positive and negative tests for every
authorization check or invariant. Those remain separate open tasks.

## Additional security test batch

The test mode now runs the explicit test overlay described in
[AUTH-TEST-MATRIX.md](AUTH-TEST-MATRIX.md): **292 passed, 0 failed**.
Older baseline statements above describe the earlier run, not the current expanded suite.
Production build mode remains unchanged and does not apply the test overlay.

Historical GitInfo is deferred while latest-release evidence is prioritized.
