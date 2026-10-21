# CLMM security regression evidence — 21 October 2026, first batch

Historical first-batch snapshot. The [latest 509-test full-capture report](../security-tests-2026-10-21-full/README.md)
supersedes this snapshot for current results. Historical reproduction commands refer to
the source/test file set identified by this snapshot's hashes; current tooling runs the
expanded suite. Counts below have not been retroactively changed.
Base public commit: `c58d1cfb0080988b9930387c4486e7dd494ea27b`.
Tested production-source/test tree SHA-256:
`c82fc30188d2dd17060d38118695b4cfb9a1db7e672b126d816aabdb73d37a57`.
The base commit alone does **not** contain the new tests; [source hashes](source-hashes.json)
identify the exact tested working tree. No production source, capability ownership or
mainnet deployment changed.

## Verified results

- **372/372** current unit tests passed with no filter, zero failures: [full log](full-tests.log).
- **80 new security tests** passed: 56 ACL business-entry tests and 24 boundary/accounting tests.
- All **80/80** new tests produced individual value traces in a separate selected-subset run:
  [trace log](traced-tests.log), [scope and count checks](run.json), [result](result.json).
- All **33** fresh normal-build root module hashes match the recorded immutable mainnet
  module hashes: [comparison](normal-bytecode.json). This is not a fresh chain read or
  independent dependency-bytecode audit.
- **5/5 expected compiler rejections**: four unforgeable capability types and a flash-swap
  receipt that cannot be dropped: [results](capabilities/result.json), [logs](capabilities/).
  These are compiler-negative cases, not five additional passing runtime unit tests.
- Three broad historical failure assertions were narrowed to exact errors; see the
  [coverage matrix and remaining work](../../docs/security-test-matrix-2026-10-21.md).

## Coverage scope — important

[Production coverage JSON](production-coverage.json), [production-only LCOV](production-lcov.info),
[raw LCOV](raw-lcov.info), [normal function inventory](normal-build-functions.json).

These coverage counters measure **only the 80 new tests**, not all 372 CLMM tests and not
the old 187-test subset plus the new tests. They must not be presented as merged or
full-suite coverage. The report gives 22.55% production line coverage and 16.59% CFG-edge
coverage for this selected subset only. Percentages must not be added to historical results.
Zero-hit production code remains in the denominator; dependencies and test-only functions
are excluded using the normal-build inventory. CFG edges include unconditional successors,
so this is not a decision-only branch metric.

The whole-suite tracing issue remains open. The selected-subset success does not establish
that every authorization check/invariant has adequate positive and negative testing.

## Reproduction

Node.js 22+ and recorded Sui 1.66.2-a9a6825eaf62 are required. For tracing, use the official
tracing-enabled binary from the checksum-verified mainnet-v1.66.2 release.

```sh
SUI_BINARY=/path/to/tracing/sui node tools/test-security.mjs /tmp/clmm-security-new --trace
SUI_BINARY=/path/to/sui node tools/test-capabilities.mjs /tmp/clmm-security-new /tmp/clmm-cap-negative-new
```

Both destinations must be new. The first command runs all current tests unfiltered,
compares production bytecode, then traces the 80 new tests. The second uses that passing
baseline to ensure the five injected negative fixtures fail for the expected compiler
reasons. The runners use disposable packages and an empty isolated client configuration;
they do not access a user's wallet, sign or submit transactions. Absolute workspace paths
are normalized in the exported artifacts; coverage counters and test outcomes are unchanged.
