# Independent traversal source and experiment review

Execution status at review: **pending**. This review used retained source only; no test execution or native game qualification was performed.

## Defect identified by control-flow inspection

Both `next_filtered_sibling` and `previous_filtered_sibling` initialize `consider_children` to false. Their sibling branch sets it to true for `ExcludeNode`, but leaves its previous value intact for `ExcludeSubtree`. Consequently an excluded subtree can inherit true from a preceding transparent leaf and be entered incorrectly. After traversing its excluded child, ascending to the excluded parent terminates traversal before a reachable sibling.

The child branch already assigns the Boolean for either result. The reviewed candidate makes the sibling branches consistent by replacing exactly two conditional assignments with:

```rust
consider_children = result == FilterResult::ExcludeNode;
```

## Minimal fixture and proposed checks

An included root R has ordered children `[A, B, C, E]`. A and E are included buttons; B is an `ExcludeNode` leaf; C is `ExcludeSubtree` with one `ExcludeSubtree` leaf D. These are six nodes including R.

Starting at A, B sets the Boolean true. Moving from childless B to C fails to clear it. The next iteration enters D; ascending back to C then returns no sibling. The contract requires E. Reversing the root order to `[E, C, B, A]` exercises the corresponding preceding-sibling defect.

The six new tests use the actual pinned consumer tree and public iterators, not a translated traversal implementation:

- Forward and reverse excluded-child cases with an explicit ID-based filter.
- Forward and reverse excluded-child cases with `common_filter` and hidden excluded nodes.
- Forward and reverse excluded-leaf controls, with D omitted.

## Independent pre-dispatch review

Reviewed `run.py`, `regression.rs`, `iterators.baseline.rs`, and `Cargo.seed.lock`. No dispatch blocker was found. The baseline iterator source matches the retained source byte-for-byte. Fixture APIs follow the pinned source's existing tests.

The runner verifies the published crate checksum and exact iterator source bytes, checks the AccessKit dependency version/checksum after metadata resolution, and retains the resolved lock. Both test invocations use that lock with `--locked`; its hash must remain unchanged. `--lib iterators::` includes existing iterator tests and the six additions.

Baseline qualification requires exit 101, exactly the four named excluded-child failures, and the expected failure summary. A compile error alone cannot satisfy those checks. The candidate must exit zero and report no failures. The candidate replaces exactly two matching source fragments and retains identical regression bytes. Logs, source copies, hashes, and a receipt are preserved.

The seed lock may change during initial metadata resolution; retention and pin checks occur before the paired locked runs. Compilation remains unverified until execution. A nonblocking reporting improvement would record preparation exceptions explicitly in the receipt; otherwise the Actions console may be needed to explain a preparation failure.

## Limits

Requests 71 and 145 contain an excluded node repeated after other excluded candidates, consistent with descent followed by ascent. They do not record the necessary child/parent relationships or iterator phase, and constructor back-boundary evaluation also contributes predicate observations. The live topology correspondence therefore remains unproven.

An executed reproduction can establish the pinned iterator defect and this correction on the tested cases. It cannot by itself establish the cause of the live ending failure, justify changing saved data or game behavior, or qualify an official/native build.

## Executed-evidence review

Independently inspected retained results for GitHub run `39234407866`, job `117999882218`, after the preceding pre-dispatch review. No test rerun was performed. The original receipt identifies source commit `27dd7a7d0e2c064451d40aa4ce44fdca751be878`, Rust 1.85.0, and diagnostic-only execution with no game execution or official acceptance claim.

Verified all **14 manifest entries** against their retained byte counts and SHA-256 hashes. All **15 file entries** in `cloud-evidence.zip` match the extracted evidence byte-for-byte. The retained runner, regression fixture, baseline iterator source, and seed lock exactly match the independently reviewed inputs. The published crate's iterator source matches the baseline. The corrected source differs only by the two reviewed Boolean-assignment replacements.

Baseline and candidate receipts contain identical `cargo test --locked` arguments, including `--lib iterators::` and `--test-threads=1`. Their log hashes match the receipt. The runner's successful completion includes its unchanged resolved-lock check after the paired runs.

- Baseline: **14 passed, 4 failed**, exit 101. The failures are exactly `forward_excluded_child_common`, `forward_excluded_child_explicit`, `reverse_excluded_child_common`, and `reverse_excluded_child_explicit` in `iterators::dwm_traversal_regression`. Each reports expected node 5 but actual `None`.
- Candidate: **18 passed, 0 failed**, exit 0. All six new regressions and the same twelve existing iterator tests pass.

This establishes the pinned iterator defect by execution and demonstrates the two-assignment correction on this focused suite. The live ending topology correspondence and official/native game qualification remain unproven; the earlier limits still apply.
