# CLMM security testing — stage two, 21 October 2026

Historical partial-capture snapshot, not a declaration of exhaustive compliance. The
[latest 509-test full-capture report](../security-tests-2026-10-21-full/README.md) supersedes
this result for the current suite. Commands below refer to the source/test file set
identified by this snapshot's hashes; current tooling runs the expanded suite.
Base public commit: `c58d1cfb0080988b9930387c4486e7dd494ea27b`.
Exact tested production-source/test tree SHA-256:
`51620deca234a4b3a2ed250a7694b5a054b462c4f9db2d2266dba0476e0157c3`.
The new tests are not contained in that base commit; [source hashes](source-hashes.json)
identify the tested working tree. Historical stage-one evidence is retained separately.

## Results and counting

| Evidence | Result | Scope |
|---|---:|---|
| Full unfiltered unit suite | **482/482 passed** | Current production source plus test tree, no test-only source overlay |
| New tests since the public 292-test baseline | **190** | 80 first-batch + 110 second-batch |
| Selected security regression modules | **200 passed** | 190 new tests + 10 existing `security_acl_tests` |
| Selected value traces | **196/200** | Four explicitly excluded collection paths; not all 482 tests |
| Private-state version fixture | **29/29 passed** | Separate, explicit test-only constructor in a disposable copy |
| Compiler-negative cases | **5/5 expected rejections** | Four capability construction restrictions + receipt no-drop obligation |
| Normal-build root bytecode | **33/33 matched** | Recorded immutable deployed-module hashes, no fresh chain read |

[Full tests](full-tests.log), [selected tracing tests](traced-tests.log), [run scope](run.json),
[results](result.json), [bytecode comparison](normal-bytecode.json),
[capability compiler evidence](capabilities/result.json),
[version fixture evidence](version-fixture/result.json).

The 29 version-fixture cases and five compiler rejections are **not** added to the 482-test
unmodified-production-source count. No production source or mainnet state was changed.

## Coverage measured by the 196 selected tests

- Production lines: **55.14%** (2093/3796).
- Production CFG-successor edges: **52.36%** (931/1778).
- Production functions: **56.94%** (242/425).

[Coverage JSON](production-coverage.json), [production-only LCOV](production-lcov.info),
[raw LCOV](raw-lcov.info), [normal-build function inventory](normal-build-functions.json).

These are selected-subset measurements, not full-suite coverage and not the union of the
historical math-test subset with the new security tests. Percentages cannot be added to
historical reports. All normal production functions remain in the denominator, including
zero-hit code. Dependencies and test-only functions are excluded. CFG edges include
unconditional successors; this is not a decision-only branch percentage.

## Tracer limitations

The full 200-security-test tracing attempt overflowed the stock Sui 1.66.2 tracer at the
normal LP fee-collection path. A historical fee-collection test reproduces the failure
even when run alone. The passing unit suite is unaffected. The explicit partial capture
omits four collection success/recovery tests; two are conservative analogous-path
exclusions, not individually diagnosed failures. See [diagnostic scope](tracing-limitations.json)
and [explicit configuration](../../tools/security-trace-exclusions.json).

No missing trace was silently counted as complete. The four tests remain in the unfiltered
482-test passing suite. Full CLI/runtime tracing remains work in progress.

## Version-state fixture is explicit and isolated

Because the production API cannot manufacture arbitrary private `Versioned` state, the
version runner injects only an extra `#[test_only]` constructor into a disposable copy of
`pool.move`, then runs 29 targeted tests. The public production source is untouched; no
assertions, constants or production logic are changed. A fresh normal build **with** that
constructor still matches all 33 recorded deployed module hashes, proving it does not
enter production bytecode. The overlay source hashes and exact fixture are recorded.

Cases include current/older/future/max stored versions, upgrading older state, rejecting
repeat upgrades/downgrades, and future-state rejection at 14 ACL business entries, four
ACL mutation entries and pool deployment. This is not a mainnet upgrade rehearsal or a
claim to execute a real historical package version.

## Reproduce

Use Node.js 22+ and checksum-verified tracing-enabled Sui 1.66.2-a9a6825eaf62.
All destination directories must be new:

```sh
SUI_BINARY=/path/to/sui node tools/test-security.mjs /tmp/clmm-security-stage2 --trace-partial
SUI_BINARY=/path/to/sui node tools/test-capabilities.mjs /tmp/clmm-security-stage2 /tmp/clmm-cap-stage2
SUI_BINARY=/path/to/sui node tools/test-version-gates.mjs /tmp/clmm-security-stage2 /tmp/clmm-version-stage2
```

Omit `--trace-partial` to run unfiltered tests plus bytecode verification only. `--trace`
attempts every security regression module and fails if the tracer crashes; it does not
silently apply the partial exclusion list. The empty isolated client configuration and
disposable packages prevent access to a user's keystore; no signing or submission occurs.

## Review matrix and open work

[Detailed matrix](../../docs/security-test-matrix-2026-10-21.md),
[static public/friend entry inventory](security-entry-inventory.json).
The inventory is a source-review aid, **not** proof that every listed guard is covered.
Outstanding work includes full-suite coverage tooling, additional partner flash-repayment
binding and specialized burned-position NFT paths, broader invariant review, and publication
of reviewed evidence. Passing all tests alone does not prove every authorization check or
invariant is sufficiently tested.
