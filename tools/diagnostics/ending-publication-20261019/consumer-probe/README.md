# Applied Windows consumer probe v1

Diagnostic source only; not an official SDK or gameplay correction. `apply_probe.py --crate-root PATH` installs into the exact published `accesskit_windows` 0.32.1 crate after verifying the retained adapter bytes. It does not change dependencies. `generate_candidate.py` reproducibly derives candidate adapter hooks from the retained baseline; `consumer_probe.rs` is hand-written. Source refs retain upstream Git/blob/SHA custody. No `Navigate` hooks, new accessibility queries, or C ABI changes.

Dependency gate: accesskit-c 0.21.2 at 72460cd52d1b24492393cdf54a6f19d2fd63e258; accesskit 0.24.0 checksum 5351dcebb14b579ccab05f288596b2ae097005be7ee50a7c3d4ca9d0d5a66f6a; consumer 0.35.0 checksum 53cf47daed85312e763fbf85ceca136e0d7abc68e0a7e12abe11f48172bc3b10; Windows 0.32.1 published archive checksum eff7009f1a532e917d66970a1e80c965140c6cfbbabbdde3d64e5431e6c78e21. Builder must retain original and derived locks and resolved metadata, rejecting upgrades/duplicate common or consumer types.

## Observation contract

Set `GODOT_ACCESSKIT_CONSUMER_TRACE_PATH` to a fresh run-specific `trace-{pid}.jsonl` path; `{pid}` is substituted. File append supports multiple adapters; fresh path avoids merging executions/PID reuse. Each adapter owns its optional observer and file handle; no extra mutex or recursive context reads. Open failures go to stderr. Callback discovery runs before existing filter returns. Active/focus snapshots use the existing tree write guard after the natural commit, after existing selection-event computation; serialization and I/O run after dropping it. Initialization copies the already constructed committed tree before Context ownership; placeholder replacement copies under its existing assignment guard. Original event/action/filter algorithms are unchanged.

Discovery uses exact raw label `trim_end() == "TEST Seven-day ending."`; raw label is preserved in records. Matches are provisional candidates, not proof of primary-caption identity. Offline binding to the unchanged primary callback using local ID and root TreeId custody remains mandatory. Candidate IDs are never interpreted as composite IDs or UIA RuntimeIds. All same-epoch matches are retained, including old nodes/removals. A second ID makes that epoch ambiguous even after removal. Unique binding persists through rename/removal; a genuine new-tree/placeholder replacement resets epoch. No identity joins across epoch/adapter/process lifetimes.

## JSONL

Commit fields: schema=1, source=`accesskit_windows-0.32.1-consumer-probe-v1`, event=`consumer_commit`, pid, hwnd (hex), adapter_id, epoch, seq, unix_us, capture_end_unix_us, cause, placeholder, binding_state, candidates, bound, discovery_overflow, path_truncated, label_truncated, host_focused, root, nodes. Cause: initial/placeholder_initial/placeholder_replacement/update/focus/placeholder_focus. Binding: unbound/ambiguous/present/absent. Identity: `{local_id: u64, tree_id: string}` obtained through public `Node::locate` (`State::locate_node`) with TreeId's Debug rendering. `nodes` is target-to-root; node fields identity,parent,raw_label,role,hidden,focused,filter,geometry. Filter is the actual common_filter evaluated on the committed state by this observer, NOT a provider query.

The two UTC timestamps bracket snapshot copying, not producer/query chronology and not an atomic cross-layer snapshot. Seq is per-adapter attempted capture, not producer update_seq. Geometry records observed raw/transformed bounds, transform, clips_children, explicit missing sibling predicate inputs. Do not explain a clipping exclusion fully or choose a correction without obtaining those missing inputs separately.

Footer: schema=1,event=consumer_footer,pid,adapter_id,seq (last attempted capture),records (attempted emitted commits),dropped_records,write_failed. A missing footer supports only complete-prefix analysis. Any write error is stderr-visible and sticky; subsequent captures are dropped. A partial row, count/sequence mismatch, any dropped records or failure must reject continuous-coverage claims. Footer is best-effort at adapter Drop; abnormal process termination may omit it.

Limits: 16 unique candidates; 4096 visited nodes on unfiltered initial/replacement DFS; 32 path nodes; 1024 UTF-8 bytes per label; 16384 commit records per adapter then captures counted as dropped. Initial scan/candidate overflow is sticky per epoch and prevents uniqueness. Path and label truncation are explicit per record. No full-tree scan on normal updates. Geometry fields are bounded numeric/enum representations; output bound is the above fixed record/field limits, not a time bound. The exact filter may recurse/traverse beyond copied limits; observer alters timing and proves no performance property. Filesystem write latency remains unbounded by the observer but occurs outside the tree guard.

## Cloud-only verification

On Windows cloud runner, after applying into the exact crate, run `cargo test --manifest-path PATH/Cargo.toml consumer_probe -- --nocapture`. Tests cover hidden discovery, actual focus commits, old-node discovery, committed removal versus never-bound, rename retention, initial/placeholder epoch reset, duplicate/capacity ambiguity, initial scan overflow, UTF-8/JSON escaping, path/label truncation and record ceiling. Do not count source review as compilation/test success. Native original 30s action/480s journey gates and executable qualification remain external and unchanged.

## Query observer extension (prepared, not locally executed)

The query candidate adds `query_probe.rs` and patches the exact retained `node.rs`
and `context.rs`, in addition to the existing adapter/consumer observer. The
installer verifies all three upstream baselines before copying any candidate.
Both `GODOT_ACCESSKIT_CONSUMER_TRACE_PATH` and
`GODOT_ACCESSKIT_QUERY_TRACE_PATH` must be enabled: canonical consumer discovery
owns arming. Query paths replace `{pid}` and append `.adapter-{id}.jsonl`.

`Context` shares only an optional diagnostic `Arc`; tree and candidate ownership
stay unchanged. Epoch resets happen before Context publication or under the
replacement write guard. Caption discovery arms even ambiguous candidates and
removal does not disarm. Each captured request includes its epoch-start/arm times.
Pre-arm and pre-resolution calls are not recorded. The observer emits after the
existing resolver releases its tree guard and preserves the original Result,
including explicit `outcome_ok` and HRESULT. It wraps only original Navigate
predicate invocations, not recursive filter internals.

Limits: 256 stored predicate entries, 1024 UTF-8 label bytes, 16384 reserved
requests across the process, 384KiB per serialized request and 64MiB total bytes
including footers. Serialized expansion can omit additional complete candidate
objects; counts distinguish evaluated from recorded entries. Limits never stop
navigation. Footers count attempted writes; a write-failed footer is incomplete.
A missing footer cannot establish continuous coverage. Request IDs are global;
emission sequences are per adapter file and can differ from request order.

Eight `query_probe` Rust tests cover lifecycle arming, predicate order, root
exception, entry/label/serialized caps, concurrent output and the actual COM
Navigate body with observation enabled/disabled. These tests are prepared for
cloud execution only; no local Rust, Godot or PowerShell execution is claimed.
