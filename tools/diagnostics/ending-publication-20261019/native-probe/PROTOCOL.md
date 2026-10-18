# Native publication probe v1

This is an opt-in, Windows-only diagnostic patch to Godot source commit `35e80b3a8822a9df9be390814b62f44c0a9c69e8` (tree `499fa231ee5d21878988a4a9cb881749def3946d`). It is a separately built diagnostic executable, not the original official executable and not a runtime fix. The original failed game source/PCK remains `81847d8b1560340a3a7769223cee0b46c6bdc0f9`. Root owns build, package, publication and cloud execution.

## Outcome and observation boundary

The reader can reconstruct the graph **prepared for the existing AccessKit factory handoff** from each natural initial update and every complete subsequent delta. The observer copies ordered children from `accesskit_node_children(ae->node)` after the existing ordinary child pushes and the owned sub-element loop have both populated that node, immediately before the existing `accesskit_tree_update_push_node` transfers ownership. It uses the same const readers for the real initial busy window node. It does not enumerate the Godot scene tree or derive ordinary children from `ae->children`.

The complete JSON update is written after its nodes were transferred into the real update object and before that factory returns. This establishes the completed prepared batch, not adapter acceptance, native UIA exposure, or acceptance within the original deadline. A selected graph must be tied to the unchanged project's primary caption RID trace and the original native wait interval by the external evidence reader. Reproduction of the same original ending-caption failure is a separate required gate before attributing graph findings to that failure.

## Activation and ownership

Set `GODOT_ACCESSKIT_PUBLICATION_TRACE_PATH` only for the intended diagnostic process. Its value must be an absolute file path containing literal `{pid}`; the existing PID replaces that token. The parent directory must already exist. Example: `D:/evidence/native/accesskit-{pid}.jsonl`. The driver reads this variable once in its constructor, before any window creation or initial callback. An empty or absent variable leaves the probe unallocated. The existing driver strips `DWM_*` variables, so this distinct variable survives without a PowerShell driver change.

All state belongs to one private `PublicationProbe` in the existing AccessKit driver. The patch adds no public API, manager, refresh, callback registration, RID allocation, action, timer or gameplay mutation. It leaves existing getters, setters, child pushes, ownership transfers and queue clearing in their original order. Supported use is the Windows window-owner/main-thread path; the initial callback's owner-thread requirement is documented by the bundled C API. A nested update stops capture explicitly. The reader must reject overlapping or thread-inconsistent same-window captures rather than assume a total preparation order.

## JSONL records

Each complete line is one JSON object. No update is split across rows. Fields common to emitted rows are:

| Field | Type and meaning |
| --- | --- |
| `schema` | Integer `1`. |
| `seq` | Contiguous positive global record sequence, beginning at 1. |
| `event` | `session`, `window_open`, `update`, `window_close`, `stopped`, or `session_end`. |
| `ticks_us`, `unix_us` | Decimal uint64 strings measured before that row is serialized/written. Unix microseconds derive from the existing floating point system-time API; they are observational timestamps, not a claim of clock accuracy. |
| `thread_id` | Existing caller thread ID as a decimal uint64 string. |
| `node_copy_us_total` | Cumulative measured time inside successful completed-node copy operations. It excludes begin/end and lifecycle bookkeeping and is not total probe overhead. |
| `write_us_total_before_record` | Cumulative measured serialization/store/flush time for prior rows. |
| `previous_write_us` | Measured serialization/store/flush duration of the preceding successfully attempted write. The final row's own write cost cannot appear in that row. |

The `session` row additionally carries `source_base_commit`, `probe_id` (`publication-native-v1`), `engine_version`, `engine_hash`, decimal-string `pid`, `boundary` (`completed-node-before-transfer/factory-prepared`), `tree_id` (`root`), `grafts_supported` (`false`), and `limits`. The compiled version/hash are observations; they are not sufficient source authentication. The external build/run receipt must bind source and patch hashes, protocol hash, exact executable and AccessKit DLL hashes, original PCK hash, actual process PID/command, package provenance, and the original native mode results. Expected diagnostic build name is `dwm_publication_probe_v1`.

A `window_open` row records integer `window_id`, `window_open_seq` equal to that record's `seq`, decimal-string `root_id`, and decimal-string `native_handle` copied from the existing `window_create` argument. It occurs before adapter creation; it alone does not prove successful adapter activation. An initial update proves that the corresponding natural initial callback occurred. Native-handle values are not Godot RIDs or UIA RuntimeIds.

Each `update` row contains:

| Field | Type and meaning |
| --- | --- |
| `update_kind` | `initial` or `delta`. |
| `update_seq` | Contiguous positive global sequence of complete updates, across windows. |
| `window_id`, `window_open_seq`, `epoch` | Integers. Epoch starts at 1 on the first initial callback, increments on every natural initial/reinitialization callback, and resets for a new window-open record. |
| `root_id`, `focus_id` | Decimal uint64 strings copied from the effective root/focus of this prepared batch. |
| `capture_start_ticks_us`, `capture_end_ticks_us` | Decimal uint64 strings bounding the capture/assembly interval. |
| `capture_start_unix_us`, `capture_end_unix_us` | Corresponding observational wall-clock timestamps. |
| `capture_thread_id` | Caller thread at capture start; must match the row's emitting thread. |
| `complete` | Boolean `true`; only complete batches are emitted. |
| `nodes` | Array of completed replacement-node records in actual push order. Empty delta arrays are valid. |
| `node_count`, `edge_count` | Integer counts of the emitted nodes and total child IDs. |

Every node record has `id` (decimal uint64 string), `children` (ordered array of decimal uint64 strings), `role` (actual C enum integer), `hidden` (actual C getter boolean), and `label` (actual C label string or JSON null when absent). IDs are lossless strings; zero is not rejected merely because it is zero. The child array is borrowed from the const C getter and copied before transfer; it is not freed. The label getter returns a separate allocation and it is freed with `accesskit_string_free`. Labels are read from the completed AccessKit node, not substituted from source-side names.

A `window_close` row has `window_id`, `window_open_seq`, and final `epoch`. A `session_end` row has `complete` (no unfinished captured batch), `updates`, and `open_windows`. It reports capture closure at driver destruction; `open_windows` is observational and does not invent missing close notifications.

A `stopped` row has `complete:false`, `reason`, `attempted_update_seq`, and `last_complete_record_seq`. Its reasons include path/open/write failure, byte/update/node/edge/label limits, unowned/nested update, delta without initial, and invalid window close. The observer also emits one `GODOT_ACCESSKIT_PUBLICATION_TRACE_STOP <reason>` stdout line. If writing is impossible, stdout is the fallback; absence of a valid terminal row is not evidence that capture succeeded.

## Replay and completeness obligations

Start each `(pid, window_id, window_open_seq, epoch)` from its real complete initial root update. Apply each complete delta as whole-node replacements; retain omitted nodes while still reachable, and prune detached nodes/subtrees according to the pinned consumer semantics. Do not resurrect a previously removed subtree from a stale cache. Validate complete rooted reachability, ordered edges, IDs, counts, root/focus existence, single-parent/cycle constraints, contiguous sequences, timestamps and thread custody before reporting a path. Reinitialization resets the epoch; a synthetic snapshot is not substituted for the genuine initial callback.

This v1 contract supports only `TreeId::ROOT` without grafted subtrees, matching this pinned Godot driver's construction. Unsupported tree state is unknown. The dependency pins are accesskit-c `0.21.2` at `72460cd52d1b24492393cdf54a6f19d2fd63e258`; its lockfile binds accesskit `0.24.0`, accesskit_consumer `0.35.0`, and accesskit_windows `0.32.1`. Do not resolve newer semver-compatible versions for this diagnostic. The reader's pinned consumer semantics are separate from a claim that the original official binary has this exact source identity.

An overflow or malformed/truncated row prevents subsequent qualification. Missing `session_end` after forced cleanup permits only complete-prefix observations through the last validated row, with final coverage unknown. Neither a footer nor an exact file hash proves adapter acceptance. No absence beyond the captured interval is inferred from line order, and there is no assumed RID-to-UIA RuntimeId mapping.

## Limits, I/O and observer effects

Limits are 65,536 updates; 4,096 nodes and 16,384 edges per update; 8,192 UTF-8 label bytes per node and 1 MiB of label bytes per update; 4 MiB per serialized row; 64 MiB of ordinary file output. A small fixed-schema `stopped` terminal row is reserved beyond the ordinary file budget. Nothing is silently clipped, filtered by ending state, or evicted from the earlier trace. After a limit, the gameplay path continues unchanged and trace qualification stops.

The label C getter allocates its complete returned string before the observer can enforce the byte limit; this unavoidable temporary allocation is disclosed. Node/edge/aggregate-label limits bound retained capture memory, and the serialized-row limit bounds written batches. The probe copies/serializes data synchronously and may change timing. No negligible-overhead or performance-improvement claim is made.

Every complete JSONL row calls `FileAccess::store_buffer`, requests `flush`, and checks the write result/last error. In this Windows implementation `flush()` calls `fflush()` but does not propagate its return into `last_error`. Therefore this is a flush request before factory return, not a durable-storage guarantee. Actual retained complete bytes, parser validation, sequences/footer and external hashes are required; a failed or lost final write remains unknown.

## Source and verification status

Full source bases and candidates are under `baseline/` and `candidate/`; the exact inspected C header is under `reference/`. `publication-native-probe.patch` applies to the pinned Godot base. `source-pins.json` records source/blob/SHA256 custody and the patch/protocol hashes. Local work is limited to source/API inspection, patch applicability, hash checks and preservation checks. No engine compile, Godot execution, PowerShell execution, cloud dispatch or product promotion has occurred here. Root must independently audit before the separately labelled cloud build and native diagnostic.
