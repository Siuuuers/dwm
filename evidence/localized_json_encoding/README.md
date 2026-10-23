# Localized canonical JSON encoding

2026-09-13; base `099a37aa4`; Godot 4.6.3 mono; `dwm-634.3`.

The preceding ASCII fast path excluded a real gameplay case: Chinese ordinary
replies persist authored text in Contacts receipts. That state also enters
Minesweeper rewards and admission payloads, causing repeated encoding to use the
original emitter after a rejected eligibility scan.

The native preflight now accepts valid Unicode scalar strings from U+0020 through
U+10FFFF, excluding the surrogate range. Its full-string regular expression uses
`\A` and `\z`. All C0 controls, floats, invalid keys/types, normalization
collisions and depth misses retain the original root emitter and error ordering.
There is no new cache, save format, checkpoint policy or physical write change.

Exact-version proof: Godot's [JSON encoder](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/json.cpp)
uses [String.json_escape](https://github.com/godotengine/godot/blob/4.6.3-stable/core/string/ustring.cpp#L4259).
For the admitted range, only quotes and backslashes are escaped; other scalars
are preserved. [String comparison](https://github.com/godotengine/godot/blob/4.6.3-stable/core/string/ustring.h)
uses scalar order, which equals UTF-8 byte order for valid Unicode. The StringName
comparison chain was established in `../native_json_encoding/README.md`.
The [RegEx implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/modules/regex/regex.cpp)
matches the explicit char32 buffer with PCRE2-32; the positive range excludes
invalid scalar values without relying on UTF-mode validation.

## Real reply and fixed-file evidence

The click benchmark now supports `--reply-locale=en|zh-CN|zh-HK`. When requested,
it prepares and acknowledges the registered Day-1 Lavinia A reply through the
configured production ContactCommandPort, then checks its exact authored text and
persisted receipt before timing any board. The final helper compares the live
receipt and the latest stable checkpoint with type-aware `_deep_same`.
No option preserves the previous flow. This exercises the production persistence
seam; it does not claim a physical Contacts Label draw or hardware mouse input.

`baseline-zh-CN-autosave.json` was copied byte-for-byte from the retained isolated
baseline run after App win/loss and Dating loss. It is 423,637 bytes, SHA-256:
`a49f3912e71a94033ba9b61195e65bcce3be5b1571cf400f28b67c179fb1ad99`.
The six non-ASCII strings are the reply's text snapshot and rendered text across
the current snapshot and two recovery snapshots. It has no floats or C0 strings.
The repeated file benchmark validates both the strict-parsed save and the direct
normalized value, and checks exact canonical bytes on every iteration.

Five iterations per version gave median encoding **62.503 ms -> 26.567 ms**, with
identical output bytes and hashes. A separate explicitly synthetic probe appended
Unicode at the end of the preceding ASCII fixture: the rejected-scan path took
88.278 ms versus 69.238 ms for its original emitter, confirming potential overhead.
With the Unicode guard, that probe took 29.664 ms. The unchanged ASCII case was
29.760 ms before and 30.488 ms after; these small samples do not establish a
general regression or guarantee for every document.

One fresh headless process per version, with `DWM_CHECKPOINT_PROFILE=1` and
`--reply-locale=zh-CN --dating-ending=loss`, observed:

| Boundary | Before | After |
| --- | ---: | ---: |
| App win to settled | 1.307 s | 0.852 s |
| App loss to settled | 1.143 s | 0.861 s |
| Dating first reveal, synchronous | 372.270 ms | 329.557 ms |
| Dating loss to settled | 0.459 s | 0.415 s |

Seeds, histories and sizes vary: later App routine counts are 181 before and
209 after. This is observational end-to-settlement timing, not controlled
attribution of every difference or OS input-to-paint latency. The baseline reply
helper used Dictionary equality; after review the final helper uses strict typed
comparison. This verification happens before the measured board actions.

Two final Windows/OpenGL processes passed:

- Traditional Chinese reply, App win/loss (0.814/0.763 s), Dating win (0.404 s).
- Simplified Chinese reply, App win/loss (0.841/0.807 s), Dating loss (0.384 s).

Both runs report the authored 24-byte Chinese reply and its durable checkpoint.
These select the receipt's locale; they do not change or audit the whole UI's
display-language preference. The benchmark's final non-ASCII reporting threshold
was corrected from greater-than-126 to greater-than-127 after the HK run; the
registered Chinese text and its true report are unaffected.

## Checks and remaining work

The four new Unicode tests initially failed three native-eligibility expectations
against the ASCII guard; the retained red log is expected. The final writer suite
passes 13 tests / 876 assertions. It pins scalar and UTF-8-width boundaries,
noncharacters, C1, BOM, Unicode line separators, combining/precomposed key order,
StringName values/keys, quote/backslash escaping and all constructible C0 controls.
Godot replaces malformed String.chr inputs, so no raw malformed-scalar fixture
proof is claimed. The range guard and existing fallback remain in place.

The eleven focused canonical/strict JSON, checkpoint, file storage, save schema,
day snapshot, consequence state and publication suites pass **203 tests / 5,469
assertions**, including the writer tests above. The frozen 1,177-case signature
remains `aa397baf53746ea17fbe3fb31998b05a72e54fb65b91c70d16c5c1635f4f3ae7`.
The repository gate adds 14 tests / 410 assertions, for **217 distinct tests /
5,879 assertions**. Regenerated inventories preserve all 239 GameState and 74
SaveManager contracts; only scanned call locations and the benchmark's Contacts
reference change. Existing test-process orphan reports and malformed-string
diagnostics are not new failures.

Every attempted engine run is recorded in `runs.jsonl` and its adjacent log.
There are 14 runs: 13 exits of zero and the expected writer red test above.
The synthetic probe source is archived as `benchmark_unicode_encoder.gd.txt`;
copy it to the ignored `.godot/phase2r_logs/benchmark_unicode_encoder.gd` path to
repeat the exact ledger command. All runs used `Invoke-IsolatedGodot.ps1` and
isolated user directories; the real player's saves were not used.

The Bead stays in progress. Terminal settlement remains noticeable, first reveal
still includes checkpoint work, and long-history stress remains outstanding.
Documents with any C0 or float still incur a rejected eligibility scan before
the checked emitter. Continue measuring repeated payload copies and encodings
without removing distinct recovery proofs or changing complete-action recovery.
