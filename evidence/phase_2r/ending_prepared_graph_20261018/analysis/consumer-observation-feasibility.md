# Feasibility: applied consumer state and actual query projection

## Decision

A small opt-in observation is feasible inside the existing `accesskit_windows` 0.32.1 owner. The needed consumer state and filter functions are already accessible there. No new Godot/game API, C ABI, accessibility refresh, RID allocation or consumer algorithm change is required.

This is a source-level feasibility finding only. No AccessKit patch, compilation, native/controller change or new execution has been made. The exact inspected sources are retained under [projection-sources](projection-sources/source-refs.json).

## Three different observations

| Observation | Concrete location | What it can establish | What it cannot establish |
| --- | --- | --- | --- |
| Prepared graph / predicted projection | Current Godot v1 node capture; a possible same-boundary bounds/transform/clip extension | What the producer assembled; a source-based filter prediction if every required input is available | Actual consumer retention, an actual provider request, or UIA client delivery |
| Applied consumer state / eligibility evaluated on that state | Windows Adapter::update_if_active, immediately after natural update_and_process_changes returns | Whether the target exists in the actual committed Tree::state(), its parent chain, and the result of the exact common_filter evaluated there | That a UIA client asked for it, or that the observer's extra filter evaluation was a query |
| Actual provider navigation and filtering | Existing PlatformNode::Navigate and the filter invocations it already performs | Which candidate nodes the provider evaluated for that navigation, returned filter decisions, and the resulting node/None | A request for a node never evaluated, all property/hit-test behavior, or attribution to a particular PowerShell query without external timing correlation |

Keep these record types and claims separate. In particular, the phrase “actual projection decision” must specify whether it is an observer evaluation on applied state or an existing provider-request evaluation.

## Minimal applied-state hook and owner

In [platforms/windows/src/adapter.rs](projection-sources/accesskit/platforms/windows/src/adapter.rs), lines 434–439, the Active branch already acquires the context's tree write guard and performs the natural update. A bounded read immediately after line 437 can use that same guard's `tree.state()`. It must not call `context.read_tree()` while holding the write guard.

This placement matters. [consumer/src/tree.rs](projection-sources/accesskit/consumer/src/tree.rs), lines 620–708, first updates next_state, then invokes ChangeHandler callbacks, then commits changed node data and other state. The node_added/node_updated callbacks alone are not a retained-after-apply boundary. Tree::state() after update_and_process_changes returns is the committed state.

Public consumer reads already available to the Windows crate include Tree::state, State::node_by_id, State::root/root_id, Node::parent/children/data, State::locate_node, and common_filter. State::locate_node gives the actual local AccessKit ID and TreeId. Do not reinterpret the consumer's private composite NodeId or infer a UIA RuntimeId.

The target's existing internal NodeId can be observed in the existing change callbacks when the admitted ending caption appears, then checked in the committed state after apply. This avoids constructing a private ID or scanning the whole tree on every update. A candidate observer must report all matching IDs/ambiguity and bind the selected local ID back to the unchanged primary caption callback; a label alone is not sufficient identity. An observed ID must be scoped to its Context/epoch and removed or reset with that lifetime. Any diagnostic identity bookkeeping has no authority over the accessibility tree.

Lifecycle coverage must include natural initialization: adapter.rs 506–514 constructs the initial Tree/Context, and 421–432 handles a placeholder becoming the real tree. Reset the diagnostic epoch on those genuine paths. Do not join old state merely because an HWND or local node ID is reused. The existing Context owns the HWND and tree lock; any small optional observer belongs there or in the existing adapter, not a separate runtime manager.

A useful bounded record would contain PID/source identity, HWND, context/epoch, its own apply sequence, timestamp/thread, local root/target IDs, target present/missing, actual ancestor path, role/hidden/label, and filter result. Geometry inputs can explain an exclusion: raw/transformed bounds, clips_children, relevant filtered parent and adjacent sibling facts. Record missing geometry explicitly. Avoid giving a new SDK sequence the producer's update_seq name unless their pairing is demonstrated.

## Actual query filtering is a second callsite

[platforms/windows/src/node.rs](projection-sources/accesskit/platforms/windows/src/node.rs), lines 1013–1029, implements IRawElementProviderFragment::Navigate. Parent/sibling/child navigation uses the exact existing filter or filter_with_root_exception predicates. Its resolver holds a read guard on the actual committed tree (lines 792–861).

If a later task needs actual query evidence, a local opt-in wrapper around those existing predicate invocations can record their existing return value once, without adding a predicate call, a navigation call, a COM request or a refresh. Record the requested direction/from-node, candidate ID, decision and final returned node/None under a request identifier. Parent navigation must retain its existing root-exception predicate.

This can observe a request only if it reaches this provider method. The absence of a target-specific filter record does not prove the target was filtered out: traversal may never reach it, or a client may use cached data. Likewise, not every AccessKit filtering operation is a UIA query—change handlers also use filters when deciding which events to queue. Do not label all filter calls as client queries.

Read/copy only bounded facts while the existing tree guard is held. Keep serialization/I/O out of that critical section where practicable, preserve original call/return/event ordering, and avoid introducing an inverse file-lock/tree-lock order across the main and UIA threads. The observer still changes timing and requires explicit overflow/write-failure/coverage limits. It must never issue a new accessibility query to fill a missing record.

## Exact dependency ownership required

The current diagnostic linked a prebuilt static AccessKit SDK. Editing Godot's C++ source or the C header cannot instrument the Rust implementation already inside that library. This extension requires a separately labelled rebuild of the AccessKit static library, then relinking the diagnostic Godot executable.

| Owner | Exact version / source | Role |
| --- | --- | --- |
| accesskit-c | 0.21.2; commit 72460cd52d1b24492393cdf54a6f19d2fd63e258 | Existing C ABI/staticlib wrapper; Cargo.lock is the dependency baseline |
| accesskit | 0.24.0 | Node/update data types; no algorithm edit required |
| accesskit_consumer | 0.35.0 | Retained Tree and common_filter; no algorithm edit required |
| accesskit_windows | 0.32.1 | Adapter/Context/provider owner where opt-in hooks would live |
| Inspected AccessKit monorepo | 1bbcf100942bac96c2c3a4a91cb67b0b20201a24 | Exact source for the Windows/consumer files retained here |

The original [Cargo.lock](projection-sources/accesskit-c/Cargo.lock), Git blob `e63b6cd1379bcd3b33706f0870b5fd8e841c5877`, records:

- accesskit 0.24.0: `5351dcebb14b579ccab05f288596b2ae097005be7ee50a7c3d4ca9d0d5a66f6a`
- accesskit_consumer 0.35.0: `53cf47daed85312e763fbf85ceca136e0d7abc68e0a7e12abe11f48172bc3b10`
- accesskit_windows 0.32.1: `eff7009f1a532e917d66970a1e80c965140c6cfbbabbdde3d64e5431e6c78e21`

A minimal dependency route is a local patched copy of the exact published Windows crate, overridden from the accesskit-c build; leave common/consumer and unrelated dependencies at their locked versions/checksums. The build must first verify that the inspected hook files match the retained Git blobs. If using the monorepo path directly, its Windows Cargo.toml contains path dependencies on common/consumer; those paths must be handled explicitly so two incompatible copies of the same-version Node/TreeUpdate types do not enter the graph. Do not silently substitute a newer semver-compatible dependency.

Retain the original and derived lockfiles, all actual patch/source hashes, resolved dependency metadata, Rust/MSVC/CRT/target flags, static library/header/export identity and final executable hash. The public source tag and locked archive checksums are source expectations; they are not direct observations of adapter application or proof of the original official 7d41 binary's complete source identity.

## Concrete next task, if selected

The narrow next outcome is: “At a natural ending update, the actual Windows consumer state contains or lacks the bound current caption, and its exact filter evaluated on that applied state returns Include/ExcludeNode/ExcludeSubtree.”

An applied-state observer can answer that without changing game behavior. If it returns Include while the original native gate still fails, that still leaves actual query traversal/properties/timing unresolved; a Navigate observer would then be a separate boundary, not an automatic claim that UIA is defective. If it returns ExcludeSubtree, capture the actual predicate inputs before proposing any fix. A missing applied target would require comparing its exact update/context custody with the already observed producer handoff.

No implementation or new run is authorized by this feasibility note itself. Root owns any next patch/build/controller decision and must preserve the original native acceptance gates and the separate diagnostic-binary qualification.
