# Native owner review: run 39162900907

## Scope and custody

This read-only interpretation concerns the separately built diagnostic engine `4.6.3.stable.dwm_publication_probe_v1.35e80b3a8` and unchanged game/PCK source `81847d8b1560340a3a7769223cee0b46c6bdc0f9`. It is not official-engine acceptance. Build/package/mode custody and independent clock binding have separate owners.

Original input: `verified/original/ci/native-trace/trace-6124.jsonl` under the retained archive; 1,252,458 bytes, SHA256 `81f84fce785d9630ec2a29790804665285ad0fc05c0258fcff354573679ec337`. The unchanged reader produced [the independent replay](prepared-graph-replay.json), with 1,499 updates and no problems. The stream has one session/open/initial epoch and no footer: only a complete prefix is known.

The original Load result remains an ending-caption timeout, forced player exit -1 and driver exit 1. The original binder's banner-parse failure is retained separately; this owner review does not alter that result or perform the corrective binding.

## Actual completed path

Primary natural publication callbacks identify window 0, PID 6124, HWND 524608, caption RID `108881715921047` and game node `589916392131188`. The first connected native state is update 1414 / record 1416. That complete delta itself contains all six edges:

| Native ID | Actual role | Actual label | Index in preceding node's children | Hidden |
| --- | --- | --- | ---: | --- |
| 12884901888 | Window (133) | `"DWM "` | root | false |
| 108649787686927 | GenericContainer (14) | `"DialogicLayout_WitnessedCaption "` | 15 | false |
| 108709917229102 | GenericContainer (14) | `"WitnessedCaptionLayer "` | 3 | false |
| 108787226640610 | GenericContainer (14) | `" "` | 5 | false |
| 108843061215361 | ScrollView (108) | `" "` | 1 | false |
| 108855946117250 | GenericContainer (14) | `" "` | 0 | false |
| 108881715921047 | Button (18) | `"TEST Seven-day ending. "` | 0 | false |

Canvas/Caption RID-to-game-node correspondences are explicitly supplied by the existing natural callbacks. Blank intermediate nodes are identified above by actual native role, without inventing additional RID mappings or any RID-to-UIA RuntimeId mapping.

Updates 1415–1419 retain all six edges from update 1414 while replacing the caption. The independent time review selects six prepared captures, 1414–1419, in the original logged failure interval; three follow the recorded text completion. The target stays connected through update 1499, but those later states do not substitute for the original interval. See [the independent review](independent-reader/review.json) for the exact clock and query qualification.

## Owner implications and limits

At these prepared updates there is no missing parent edge, hidden ancestor, wrong caption role or mismatching trimmed caption label. The current Canvas was also unwithdrawn at the primary callbacks, with no Next, Pause, history, recovery or pending publication hold. This does not support another game-side ordering/withdrawal change.

The trailing space is accounted for by Godot's existing `accessibility_update_set_name`: it combines the name, a separating space and extra information. Keep the raw label; the unchanged driver's intended trim comparison remains relevant. The owner is the [pinned Godot AccessKit driver](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/drivers/accesskit/accessibility_driver_accesskit.cpp).

Connected/unhidden does not prove Windows projection. The [Windows filter alias](projection-sources/accesskit/platforms/windows/src/filters.rs) selects the consumer's [common filter](projection-sources/accesskit/consumer/src/filters.rs). GenericContainer normally receives ExcludeNode, permitting transparent traversal. The same filter can exclude a subtree based on clipping, transformed bounds and immediately adjacent filtered siblings even with hidden=false. [Node geometry](projection-sources/accesskit/consumer/src/node.rs) combines ancestor transforms. Those inputs are absent from v1; this is an evidence limitation, not a finding that clipping caused the failure.

A capture-end timestamp precedes serialization, flush request and factory return. The logged failure interval is not independent proof of adapter application before a subsequent query inside the strict Stopwatch deadline. Native timing, projected filtering and retained-adapter state remain distinct unresolved boundaries.

## Smallest next source boundary

A bounded observation immediately after the Windows adapter's existing natural consumer apply is source-feasible. It could establish the retained target/path and the filter result evaluated on that actual applied state. An actual UIA navigation decision requires observing the existing Navigate callsite separately. Neither was recorded in this run. See [the feasibility note](consumer-observation-feasibility.md).

All new upstream source copies are unmodified and bound to exact commits/Git blobs in [source-refs.json](projection-sources/source-refs.json). No game/native/controller edit, new dispatch, fix, or product promotion was performed for this review.
