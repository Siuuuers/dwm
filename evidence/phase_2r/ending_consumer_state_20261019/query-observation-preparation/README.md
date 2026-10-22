# Concrete query-boundary preparation

Status: preparation only, 19 October 2026. Director6262304989 assigns A this work in parallel with external C's actual-evidence review. No query patch is implemented, compiled or dispatched by this packet. C's latest inspected PR36 comment6260852631 reviews the older proposal, not run39208992744. Consume C's new evidence findings before a native build/dispatch. This packet extends the retained internal-review.md with exact callsites and review gates.

## One observable outcome

For naturally occurring ending-window queries, establish whether the existing Windows provider Navigate implementation evaluates or returns current caption local RID/TreeId, and whether the harness's already-evaluated action predicates reject an enumerated candidate. Adapter/Context remain tree/lifecycle owners; PlatformNode owns provider navigation; Actions/Visible own harness eligibility. An instrumented result stays diagnostic-only.

Success means a source-bound record of actual navigation evaluations/results and their coverage, plus bounded harness predicate observations. It does not require a pass. Preserve original native failure, original30-second action gate and480-second journey ceiling. Never infer raw descendants from accepted Actions count or equate a local RID to a UIA RuntimeId.

## Source boundary and smallest change surface

source-pins.json hashes the exact retained input files in ../native-evidence.zip. Implementation should extend isolated diagnostic tools9b6653436e5989e9bf096360f7e7045c20f4578b, not transplant its game/engine experiments onto product.

| File / callsite in retained source | Proposed responsibility |
| --- | --- |
| node.rs, with_tree_and_context (799), resolve_with_tree_state_and_context (847) | Reuse existing context upgrade, tree read guard and resolved node. No second tree lock. |
| node.rs, Navigate (1013) | Wrap actual direction-specific predicate evaluations; capture actual selected identity and original result. |
| context.rs, Context (31) | Optional shared diagnostic handle only; no second tree, candidate registry or gameplay authority. |
| adapter.rs, Probe member (367), begin_epoch calls (437/537/557) | Supply same adapter identity and current epoch before Context publication or within existing replacement write guard. |
| consumer_probe.rs / narrow query module | Bounded owned records and opt-in output; retain current candidate discovery owner. |
| Invoke-ExportedGameplay.ps1, Actions (154), Wait-One (203); Visible (140) read-only reference | Ending-only observation of existing gate decisions and query ordinal; leave Visible unchanged. |

Only isolated tool generation/source pins, SDK patch allowlist, reader/tests and controller preparation necessary for those changes should accompany implementation. This packet does not modify any of those executable files.

## Native ownership and algorithm contract

Current Probe is private to Adapter; Context has no diagnostic epoch. Add optional Arc<QueryObservation> shared by Probe and Context, holding immutable adapter ID, diagnostic epoch, bounded request sequence/drop accounting and a separate synchronized query sink. Keep candidate discovery exclusively in Probe. Do not use a global HWND lookup or expose mutable Probe on the COM path. Preserve Context::new for existing callers/tests with a narrow optional-handle constructor/helper. Open the sink only at opt-in initialization.

Publish the shared epoch from the existing begin_epoch paths. Initial/placeholder setup precedes Context publication. Replacement changes tree and epoch under the existing tree write guard. Read epoch inside Navigate's existing read guard: matching HWND alone is insufficient when context/generation changes. Preserve all existing lifecycle/event ordering and placeholder semantics.

Use the existing resolve_with_tree_state_and_context instead of resolve for Navigate only. It supplies Node, &TreeState and &Context under the same guard; obtain root identity directly from state.root().locate(), with no second lock or parent walk. Within its closure, copy bounded source/root identity via actual Node::locate(), epoch, placeholder, thread ID, direction and timestamp. Use the exact existing filter once per original callback invocation, store its result and return it unchanged. A request-local RefCell accumulator can satisfy Fn without changing the iterator contract. Drop wrapper/iterator borrows before consuming owned facts.

| Direction | Preserve exact operation |
| --- | --- |
| Parent | filtered_parent(filter_with_root_exception) |
| NextSibling | following_filtered_siblings(filter).next() |
| PreviousSibling | preceding_filtered_siblings(filter).next() |
| FirstChild | filtered_children(filter).next() |
| LastChild | filtered_children(filter).next_back() |
| Other | None |

Preserve self.relative(result.id()).into() and Err(Error::empty()) exactly. Capture selected local ID/TreeId separately from the original Result/HRESULT; return the original Result unchanged. After the resolver returns and the tree guard is released, serialize/emit owned data. Never acquire a sink lock or perform I/O under the tree guard. Observation failures disable/drop observation without replacing native errors or panicking.

Minimal coverage intentionally starts only after successful resolver callback entry. Context upgrade/node-resolution failures before that callback are **not captured**; record this in session metadata and reader output. Do not fabricate a local identity from internal NodeId. A broader pre-resolution observer is deferred unless this gap becomes material.

## Bounded records and coverage

Arm navigation capture in each epoch after existing unfiltered discovery first sees any ending-caption candidate, including ambiguous candidates. Keep it armed through removal for the remainder of that epoch. This uses a shared diagnostic flag set by the canonical discovery owner under lifecycle/tree ownership; it is not a second binding decision. Do not filter requests to the caption ID: ancestor/sibling traversals are needed to see how a query reaches it. Record arming/reset facts and make pre-arm coverage explicitly absent.

Proposed fixed limits:256 predicate entries per request,1024 label bytes per entry,16384 recorded requests per process,384KiB serialized bytes per request and64MiB query-output bytes per process (the first reached cap wins). These are recording limits only. On capacity exhaustion, continue all original predicates/navigation unchanged; mark truncation and dropped records. Label truncation must remain distinguishable from an exact label match. Bound serialization size; do not build an unbounded string before truncating. Give emission ordering its own sequence: concurrent requests may complete out of request-ID order. A missing footer is prefix-only coverage, never absence proof.

Each request carries schema/source ID, PID/HWND, adapter ID/epoch, request ID/thread, capture start/end UTC, direction, actual source/root local ID+TreeId, placeholder state, actual candidate sequence, actual selected identity or None, original outcome, and coverage flags. Each candidate records predicate kind, returned FilterResult, local ID/TreeId, role, hidden/focused and bounded raw label. These wrap only Navigate's externally supplied predicate invocation; recursive common_filter internals are not separately traced. Relevant internal clipping/sibling inputs remain explicitly uncaptured. Do not claim an ExcludeSubtree cause without those inputs.

Cross-process clocks provide interval association only. No synthetic shared request ID is claimed between a native Navigate and PowerShell FindAll. Observe natural calls; never issue extra navigation, GetRuntimeId or property requests merely to decorate a record.

## Harness observation: exact minimal batch

Leave Visible unchanged. Behind an explicit diagnostic switch, Wait-One creates an ending-only observation context immediately before invoking its existing Find closure (Load mode and exact ending name). Use that invocation's existing Stopwatch and query ordinal, and clear the context in finally on success, exception or early return. Preserve Day5 tracing as a separate existing scope.

Actions calls Nodes once exactly as before. Keep the raw returned nodes.Count, and record each existing Where-Object iteration's ordinal plus its already-computed visible/enabled/name/invoke/accepted variables. Null means not evaluated. Do not read names of invisible/disabled descendants or add any Current, GetRuntimeId, TryGetCurrentPattern, FindAll or Navigate call. Ordinals identify positions in this collection only; no direct mapping from a UIA descendant to an AccessKit RID is established.

Attach the batch to the already-existing caption-action-enumeration event after Find returns. Reuse its query start/end and matches fields. Do not add Record calls: Record synchronously rewrites events.json. Bound the batch to4096 recorded descendants and1MiB aggregate serialized bytes, whichever is reached first, with observed_count, omitted_count and complete. Copy at most1024 UTF-8 bytes of an already-evaluated name, marking name_truncated separately; retain the full original value for the unchanged name comparison. Do not construct an unbounded serialized copy before enforcing these limits. Counts are returned collection size, not whole provider-tree size. Overflows stop recording only. Keep all post-acquisition/enumeration deadline checks and existing native responsiveness gating, ambiguity, sleeps and acceptance unchanged. A thrown provider error remains the same error; do not fabricate a completed batch.

This first step records Visible's result, not its internal failing term. A false value cannot distinguish offscreen from bounds failure or identify an unread caption name. Exact visibility subpredicate instrumentation is deferred until evidence requires it. Existing ending events show25 zero-match enumerations, first started24.0903407s and last finished29.9057838s, after206 nonresponsive native checks. There is no enumeration evidence for that preceding unresponsive interval.

## Failure-first acceptance checks for later implementation

1. Parent root-exception and ordinary child/sibling navigation return the same identities/errors with observation enabled/disabled, including hidden/focused, ExcludeNode/ExcludeSubtree, first/last and unknown direction. Spy predicates establish identical evaluation order/count, not merely equal final answers.
2. Placeholder replacement and initial/active Context publication bind the same tree/epoch under the existing guard. Multiple adapters, root providers, rename/removal and ambiguity cannot silently rebind by HWND.
3. Candidate/label/output caps, unavailable output and write failure preserve native results, do not stop traversal and surface coverage loss. Concurrent requests produce parseable complete records without sink lock under tree guard. Resolution-before-callback gaps remain explicit.
4. Harness observations produce identical accepted elements and provider read sequence for each short-circuit branch; an unevaluated predicate stays null. Keep Visible unmodified. Exercise invisible, disabled, wrong-name and unsupported-Invoke branches, zero descendants, repeated waits, exceptions and storage caps against fake provider boundaries. Same object returns, ambiguity failure and exception propagation must remain unchanged; cleanup must not leak a batch into another wait. Retain existing late-root/late-match/timely-match/ambiguity deadline tests.
5. Reader rejects changed source/SDK/EXE/PCK bindings and mismatched PID/window/adapter/epoch. Missing records/footer, truncated labels and unpaired clocks cannot become exclusion/delivery claims. Do not carry the old pre-banner exception forward as a general permissive parser.

Only source/diff/static preparation is authorized now. Later focused Rust and PowerShell tests execute in cloud before one coherent native diagnostic, after C's evidence review is consumed. Do not repeat completed fixture/producer/order campaigns or treat these planned tests as executed.

## Reuse assessment

Run39208992744 retains consumer-native-template artifact12167797082 (SHA256a0dc470050ffa34a4f952043584dd6f0be58f6058f1fef255b1439fdc1843c84) and consumer-native-package artifact12167567802 (SHA256b427722caa48650588ceeb20e9cb4419b034b82c3f9ffd0f6091e39d64689069), plus independently retained SDK archive. Existing controller uploads bin outputs/build receipts and explicitly excludes bin/obj; no compatible object cache is established.

These existing outputs could support a harness-only diagnostic with unchanged EXE/PCK, after fresh availability/hash checks. They cannot gain a new Navigate hook: the Windows SDK is statically linked, so changed Rust SDK code requires rebuilding the library and relinking a separately named diagnostic engine. Existing template alone is not a relinkable object cache. Reuse frozen game PCK, verified headers/dependency sources and build recipe where hashes match; inspect any genuine build cache before promising incremental compilation. No new download/build/dispatch was needed for this compatibility assessment, and artifact availability must be rechecked at use time.

## Decision rules

A returned caption identity establishes only that the observed provider call returned it, not client delivery or successful Invoke eligibility. A captured harness rejection establishes only the already-evaluated gate facts for that candidate/query ordinal. If no caption is observed, report the exact armed interval/callsite coverage and truncation/drop limits; do not infer clipping or absence. If all observed provider/action stages admit it but the wait still fails, preserve the discrepancy and investigate the next concrete delivery/timing boundary. No product fix is selected in this preparation.

## Internal preparation review

Two independent internal source reviews checked native ownership/callsites and harness read/flush behavior. Final review clarified reuse of resolve_with_tree_state_and_context for direct root identity and explicit copied-name/aggregate byte caps. Six retained source hashes were rechecked. These are source-level preparation checks only; external C evidence review and executable patch/test qualification remain pending.
