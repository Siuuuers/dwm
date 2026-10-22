# Remaining pure-work opportunities after admission reuse

Read-only audit while admission candidate run39765345016 executes. Runtime inspected is the admission candidate under ending-admission-candidate, otherwise based on product3f3621bd074d47c6e76d5e5b000a12ada08f142b. No runtime edits, tests or new run were made. Current CanonicalJsonWriter and DialogicEntryManifest were fetched from GitHub at that baseline: blobs2ce8da69f351e4ba858742e90136cd2bab612253 and4c8a3abab8b683c3ef63af086f451a587fad68ba respectively.

## Concrete next candidate: retain one hash within `_equal`

SceneEventContract currently evaluates:

```gdscript
return _same_types(actual, expected) and _sha(actual) != "" and _sha(actual) == _sha(expected)
```

On a successful representable comparison it serializes and hashes the identical `actual` value twice consecutively. No callback, await, input write, live proof or external read occurs between those computations. A minimal equivalent form is:

```gdscript
if not _same_types(actual, expected): return false
var actual_hash := _sha(actual)
return actual_hash != "" and actual_hash == _sha(expected)
```

This is a call-local scalar result, not a cache or trusted validation context. The exact boolean order is preserved: type/shape mismatch produces false without serialization; actual serialization failure produces false without serializing expected; otherwise expected is serialized once and the same SHA256 equality is applied. Do not replace hashes with direct Dictionary comparison, remove `_same_types`, or change writer behavior.

`_sha` invokes the existing canonical writer and hashes its returned String. Writer native eligibility only reads primitives and containers, uses regex eligibility checks, and then native JSON encoding. Its checked path builds local normalized dictionaries/arrays and strings; finite-float verification uses the local strict parser. It does not mutate supplied values, call a user owner, await, perform I/O, or retain authority. Unsupported values, malformed strings, lossy floats, invalid keys and structural refusals are still handled by exactly the same first call. Removing the immediate identical second successful serialization changes no accepted bytes or refusal boolean.

The helper serves full event/admission receipt comparison, source/anchor consistency, initial allocation reproduction, live root allocation matching, terminal provenance and reconstructed terminal records. That gives a concrete route to saved work in the measured ending operation without removing any of those comparisons or live-owner calls. No per-helper elapsed attribution exists, so this is not a speedup estimate. Three hashes becoming two on the successful helper path does not imply a one-third whole-operation improvement.

Existing public contract and receipt tests cover exact reconstruction, type and registration tampering, failures, detached inputs and fresh public validation. Prefer those plus the existing restored complete-operation comparison; do not add a test that merely counts `_sha` invocations. Any selected change should have exact-diff/short-circuit review and retain the original first-refusal semantics.

## Bundle-body audit: retain the separate obligations

`_json_data` is not redundant with header/encoding. It enforces strict JSON primitive types, finite floats, String keys and a128-depth bound before header validation. The writer intentionally accepts StringName and additionally checks canonical representability/round-trip conditions. Removing either changes accepted input or failure order.

`validate_scene_bundle_header` owns exact versioned top-level keys and additional Contacts/audio associations. Versions2/3 invoke those canonical definition owners. It is not replaceable with already-known shape or a trust flag.

The four nested `WRITER.stringify` calls occur before programme/table validation and map failures to `scene_bundle_nested_invalid`. The final full serialization occurs after those structural checks and maps remaining encoding failure to `scene_bundle_invalid`, while computing the exact whole-bundle fingerprint. Simply deleting the nested calls, moving the full encode earlier, or assuming `_json_data` implies successful canonical encoding changes failure precedence or accepted malformed-string/float behavior.

Reusing the four encoded subdocuments inside a composed final encoding might save work, but it would require a carefully designed canonical-owner API or duplicate root encoding logic in SceneEventContract. That is a larger proof surface involving key order, serialization depth and checked/native eligibility paths. It has no current subphase cost measurement and is not the next justified change.

## Other repeated computation scan

No other exact repeated same-argument `_sha` expression was found in this contract. Some equal values are intentionally rehashed after issuer/creation-owner callbacks or in separate public calls; do not reuse through those boundaries.

`make_scene_terminal_admission` validates/indexes the bundle, then its nested `make_scene_receipt` validates it again before the first issuer callback. That is another pure segment in principle. However, reusing it requires splitting event context binding and receipt construction into additional private helpers while preserving the public event shape-before-bundle refusal order. The current simple `_equal` improvement is more minimal and broadly applicable; do not combine extra context extraction merely to increase the batch size. The challenge-recall loop also rebuilds candidate receipts without live callbacks, but this normal restored route has no challenge recall, so it is not a relevant performance target now.

## Next-step decision

Finish and preserve the admission run first. If its correctness gates pass, a reviewed `_equal` scalar reuse candidate can proceed without a new architecture decision or additional instrumentation baseline. Use the current accepted restored result as the same-observer complete-operation comparator and keep all deadlines. This recommendation authorizes no additional dispatch itself.

If further improvement remains necessary after concrete pure candidates are exhausted, enable the existing aggregate observers for one purposeful restored-route diagnostic. It would distinguish residual bundle work from full receipt/authority/journal work; no new observer implementation is needed. Current restored logs have phases only, so assigning a percentage to any remaining internal path would be speculative. Even then, evidence of cost alone would not justify skipping live authority, journal traversal, mutation guards, or any of the three ending recovery checkpoints. Those are architecture/trust obligations requiring an explicit alternative design, not removable redundancy.
