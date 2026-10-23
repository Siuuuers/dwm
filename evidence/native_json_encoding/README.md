# Native canonical JSON encoding

2026-09-13; base `90c80decb`; Godot 4.6.3 mono; `dwm-634.3`.

Terminal settlement repeatedly encodes large payloads to create and verify
different recovery receipts. The measured change accelerates those encodings
without deleting a checkpoint, hash, validation boundary, or physical write.
It adds no cache or save-format change.

`CanonicalJsonWriter.stringify` first checks the complete value. Nil, booleans,
exact integers, printable ASCII String/StringName values, arrays, and dictionaries
with unique printable ASCII string-like keys use the native sorted JSON encoder.
The preflight stops beyond depth 64. Every float, other string, unsupported type,
invalid key, normalization collision, or depth miss falls through to the original
root emitter, preserving its bytes and error precedence. The depth guard keeps
cycles out of the native encoder; it does not add cycle support to the old emitter.

Godot 4.6.3's [JSON implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/json.cpp)
uses `itos` for integers, `json_escape` for strings, and `StringLikeVariantOrder`
for sorted dictionary keys. The [variant comparator](https://github.com/godotengine/godot/blob/4.6.3-stable/core/variant/variant.cpp)
and [StringName comparator](https://github.com/godotengine/godot/blob/4.6.3-stable/core/string/string_name.h)
establish case-sensitive lexical ordering for every String/StringName pairing.
On printable ASCII this is the old writer's UTF-8 byte order. Floats and other
strings deliberately retain the established checked implementation.

## Controlled file and full-flow measurements

The unchanged fixture in `../checkpoint_json_fast_path/baseline-autosave.json`
has 456,379 bytes and SHA-256
`f2435ab5c2fbc0ef94a27540040878dac030b382614306ea6070c8b1215df542`.
Five iterations before and after all produced identical canonical bytes.
Median emission fell from **68.074 ms to 28.498 ms** (about 58%).
This fixture contains no floats or non-printable/non-ASCII keys or values.
Excluded documents retain the original emitter and incur an eligibility scan;
the fixed-file improvement is not a universal serialization speed guarantee.
The final source audit found a concrete excluded path: Chinese ordinary replies
store localized text in contact receipts, which also enters Minesweeper terminal
action candidates and admission payloads. Profile documents contain floats and
also fall back. Measure those real paths next: their extra partial preflight may
add overhead, and the ASCII fixture does not establish their performance.

The matching headless click runs use `DWM_CHECKPOINT_PROFILE=1`, the temporary
profiling patch, and the same command arguments. Each is a fresh process with
App win/loss followed by Dating loss:

| Boundary | Before | After |
| --- | ---: | ---: |
| App first reveal, synchronous | 225.250 ms | 221.347 ms |
| App later new-board first reveal, synchronous | 611.308 ms | 530.264 ms |
| App win to settled | 1.409 s | 0.886 s |
| App loss to settled | 1.231 s | 0.855 s |
| Dating first reveal, synchronous | 420.370 ms | 317.854 ms |
| Dating loss to settled | 0.481 s | 0.431 s |

Seeds, history lengths and document sizes vary between these full-flow runs;
the final App history has 216 later routine inputs versus 242 in the baseline.
This is one process per version, not an OS input-to-paint measurement or a
controlled attribution of every full-flow difference. Routine reveal medians
remain around 23-29 ms; this patch targets encoding, not routine input handling.

One additional final Windows/OpenGL process, with temporary profiling removed,
completed Expert App win/loss and Dating win. App settled at 0.864/0.859 seconds;
Dating win settled at 0.489 seconds. A second Windows/OpenGL process passed
actual New Account, pre-expiry Slot 1 Save, Schedule Done, Day 2 Autosave Load,
and older Slot 1 Load, restoring the earlier Day 1 message correctly.

## Compatibility and recovery checks

The eleven canonical JSON, strict parser, checkpoint, file storage, save schema,
day snapshot, consequence state and publication-ledger suites passed
**199 tests / 5,233 assertions**. The frozen 1,177-value byte/refusal signature
remains `aa397baf53746ea17fbe3fb31998b05a72e54fb65b91c70d16c5c1635f4f3ae7`.
Five new tests cover signed int64 boundaries beyond double precision, every
printable ASCII character in keys and values, mixed StringName/typed/shared
containers, depth 64/65, and fallback values/refusal order.

The consequence coordinator plus surrounding Minesweeper unit/integration/host
suites passed **122 tests / 1,647 assertions**. These are 321 distinct tests and
6,880 assertions before the repository gates. Existing Dialogic test-process
orphan reports and malformed-string fixture diagnostics are not new failures.

The first repository gate correctly reported one stale generated SaveManager
call-site line after adding the encoder helper. Regeneration changes only that
line (`CanonicalJsonWriter.gd:69` to `:104`); all 74 SaveManager contracts and
the unchanged 239 GameState contracts are preserved.
The final repository gate passes 14 tests / 410 assertions, bringing the total
to **335 distinct tests / 7,290 assertions**. The failed stale-inventory attempt
is retained alongside the passing rerun.

## Reproduction and remaining work

`runs.jsonl` records every attempted run and its actual exit code. The associated
logs are retained here. All engine processes used `Invoke-IsolatedGodot.ps1`
and temporary user directories, never the player's production saves.

The diagnostic patch is archived as `temporary-consequence-profiling.patch`.
It was applied for the headless before/after comparison and first contract run,
then removed from production before the coordinator and native checks. Its
applicability to the final source was checked with `git apply --check --unidiff-zero`.
To reproduce those detailed timings in an isolated checkout, use `git apply --unidiff-zero`
on that patch
and set `DWM_CHECKPOINT_PROFILE=1` when invoking the click benchmark; the exact
arguments are in the run ledger. Nested phase measurements are inclusive and
must not be summed as independent costs.

The performance Bead stays in progress: terminal settlement is still noticeable,
first reveal still includes checkpoint work, and larger manual/dialogue histories
need continued measurement. Cold/external JSON parsing still uses StrictJson.
The independent receipt hashes and complete-action crash-recovery policy remain
required when choosing the next simplification.

After this change, the App consequence accept phase remains 631 ms for the win
and 522 ms for the loss. Its repeated checkpoint preparations are about 37-39 ms
each for the win and 25-26 ms for the loss, versus 80-90 ms and 54-56 ms before.
Live restore checks add about 15-16 ms / 10-11 ms each. Completion autosave still
takes 138/149 ms, including required physical writes and schema work. These
observations support investigating repeated detached state copies and payload
encoding next; they do not justify removing distinct recovery proofs.
