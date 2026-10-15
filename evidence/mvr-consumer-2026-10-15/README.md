# Public MVR consumer validation — 2026-10-15

**Passed:** official `mvr add @turbos/turbos/22` followed by a normal Move build containing a real non-empty import/function call.

The run started with a new empty Move cache, downloaded dependencies normally, and reused that new cache between its five consumers. It used no pre-populated or manually modified dependency checkout. Sui 1.66.2-a9a6825eaf62 and MVR 0.1.0-d85f8ad92add; mainnet read-only, empty keystore, no verifier-signed transaction.

MVR's versioned and unversioned names both resolve to deployed package `0xa5a0c25c79e428eba04fb98b3fb2a34db45ab26d4c8faf0d7e39d66a63891e64` and metadata commit `df4e892dfb970fa6919e589709554fde3fc5fa80`. The owner-executed GitInfo update succeeded: [8d2nzwYgTTizbn1QBAydvj8jnjd4ViqsQWMd9eoBfdcY](https://suivision.xyz/txblock/8d2nzwYgTTizbn1QBAydvj8jnjd4ViqsQWMd9eoBfdcY). PackageInfo remains on the expected multisig.

## Reproduce

Copy the supplied Move.toml and sources/smoke.move to a new directory. Install the stated official Sui/MVR versions and configure the client for mainnet. Then run:

```sh
mvr add @turbos/turbos/22
sui move build --build-env mainnet --silence-warnings --no-lint
```

The supplied manifest already includes the dependency that `mvr add` adds. For a first-add reproduction, remove that dependency entry before the first command. Published Move.lock records the exact resolved graph. See [result.json](result.json), [mvr-add.log](mvr-add.log), and [build.log](build.log).

This completes the latest-release MVR consumer check for this package. See [official root source/bytecode verification](../mvr-source-2026-10-15/README.md) for its separate deployed-bytecode proof. No production source or existing tests changed; no unpublished Fun changes included. This is not runtime testing, every-auth/invariant coverage, audit closure, or historical/peripheral-package completion.

The 33 dependency module BCS blobs freshly compiled through MVR also hash-identically to the previously read immutable mainnet package: [artifact-comparison.json](artifact-comparison.json). This comparison reused the recorded deployed-byte hashes; it did not perform another chain fetch.
