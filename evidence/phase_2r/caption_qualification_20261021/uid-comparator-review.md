# Retained UID comparator correction — exact review packet

21 October 2026, Hong Kong. Director6309346765 selects this narrow correction after C6309090907/6309092712 closed the actual failed-run review. Run39550111534 remains failed/consumed; its original evidence at2fb17a7f is not replaced. No new Godot/PowerShell execution or controller installation occurred while preparing this packet.

Observable outcome: before the eight focused tests can begin, the newly generated Continue UID must be canonical and must differ from every retained peer's effective Godot numeric ID. Existing compatible noncanonical text must not cause a false rejection; malformed peers, collisions and incomplete comparison must still fail with useful evidence.

## Exact scope and pins

- Qualification source remains **b2cb75a792790f7bf396073b1586026fa1e20482**. Production/lifecycle code, eight selected tests, native Text/Continue driver, engine, individual waits and result/exit checks are unchanged.
- Corrected helper commit **c6ba4934914e7d3222d658352c61d04d0e57c374**, helper SHA256 **80d9abe7f3d79fb0d275ca79b3120d09988da0d85dc9fcea79581802b4ce8020**.
- Unchanged raw-capture helper SHA256 **a04a8560ea2ac7e8ff77d6bb3e3ffe8d1404193f5e1de2a71676332403fe7379**.
- Proposed controller SHA256 **d9aa96f039721dfeabea89d79d79fdb1085cd4811bafb116ad85b2ae237de5cc**. It is inert under evidence. Only the two helper pins and focused-artifact upload condition differ from the consumed controller.

## Comparator and refusal behavior

Only one existing helper function changes: `check_runtime_uid`; one small `decode_peer_uid` function is added. All other existing functions are AST-identical, including strict `decode_generated_uid`, raw/index/settings enforcement, exact restoration, phase gating and generated path/hash equality. The one exact runtime UID/source-blob allowance remains unchanged. No source UID bytes are edited, no peer or C# path is excluded, and no new runtime path is admitted.

Peer parsing follows pinned Godot4.6.3 commit35e80b3a8822a9df9be390814b62f44c0a9c69e8: [ResourceFormatLoader](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/resource_loader.cpp) passes [FileAccess::get_line](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/file_access.cpp) directly to [ResourceUID::text_to_id](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/resource_uid.cpp). The line ends at CR, LF or NUL; one initial UTF8 BOM is handled as by String::utf8; whitespace is not stripped. All original bytes, including unread trailing bytes, remain in custody. The decoder accepts a-z and0-9, uses the engine's base34/digit values including z/9 aliases, wraps unsigned64 arithmetic and applies the63-bit mask. Comparison uses resulting numeric IDs, so textual masked aliases cannot bypass collision checks.

One deliberate stricter malformed-input rule is documented: a bare `uid://` suffix is refused, though engine text_to_id maps that empty payload to0. Nonempty valid `uid://a` remains a legitimate zero ID. Invalid prefix/characters are refused; malformed UTF8 cannot qualify as the required ASCII UID text. This is not a claim of accepting every engine input indiscriminately.

Each peer row is attached before decoding. Original bytes/hash, tracked sidecar and source identities, parsed line and effective ID are retained when available. A refusal names the peer, retains attempted progress and marks comparison incomplete. Completion becomes true only after all peers are examined; any effective collision still rejects the policy. Post-import policy failure prevents restoration and test stages as before.

## Artifact-upload correction

The focused-artifact upload now runs only after the focused step has a success/failure/cancelled outcome. A skipped focused step leaves its upload skipped rather than generating the secondary no-files error seen in39550111534. An attempted focused stage still uploads on failure and retains `if-no-files-found: error`; raw preparation always uploads. The unchanged runner/native result checks remain responsible for required per-stage evidence; the upload guard detects an empty matching artifact set. No test failures are converted to successes.

## Verification

Independent reviews checked decoder/line/BOM behavior against the pinned engine, complete/failure evidence, unchanged guards, controller condition and final immutable hashes. Final **21 Python/Git regression tests PASS** (15 existing plus6 targeted cases). Coverage includes the exact retained ResourceWrapper UID, malformed-peer progress, a signed-mask alias collision, unsigned overflow/full alphabet aliases and line/BOM handling while retaining original bytes. The strict newly generated decoder still rejects the oversized ResourceWrapper text. Existing path/source/raw/index/restoration/equality refusals remain covered.

The first new ResourceWrapper fixture tried to recapture into an already protected baseline; that test-only setup now uses a fresh evidence directory for its new fixture commit. The baseline-protection rule was not weakened. The diagnostic failure and final passing logs are retained. Inherited capture-helper ResourceWarnings remain disclosed.

An independent offline replay used the original import artifact's generated bytes and exact pinned tracked Git objects:1692 tracked UID sidecars plus25 generated peers = **1717 peers**, all decoded, **zero collisions against Continue559672156520183150**. Every examined object's bytes/hash/provenance is recorded. This is arithmetic/inventory replay, not a new Windows run or a replay of all preparation phases. Complete rows are in `comparator/retained-inventory-replay.json.gz`; summary and reproduction script are retained. Reproduction requires the pinned tracked Git objects to be present locally; the script does not provision them, and Git lazy fetching must be disabled when reproducing offline. No native reachability, registration, geometry, gameplay or screen-reader pass is inferred.

Relevant files: `prepare_caption.py`, `test_prepare_caption.py`, `controller.proposed.yml`, `replay_retained_inventory.py`, and `comparator/` diffs/static comparison/final test receipts/full replay. The prior helper and result are available at their immutable original commits.

## Next action

C reviews only this exact comparator/diagnostic/upload delta and focused regressions, reusing closed source/driver/runner/result reviews. Under Director6309346765, after C clears this exact packet, A may replace consumed controlleraf329296a779fd04dd434f6ed51214d1de8ef83b with the reviewed bytes using an immediate expected-head check and run ONE new official Windows4.6.3-standard focused attempt. First failure stops; no further user/Director confirmation is required after C clearance. No automatic retry or exported gameplay attempt. Productc8358870/master/integration movement, merge and release remain outside scope.
