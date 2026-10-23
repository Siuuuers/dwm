# Witnessed: guarded Auto

This 2026-09-14 increment starts at
`31561cd8bf12e41936047cba4716c4f75b663559` and advances `dwm-vky.14`.
The mounted rail now toggles the existing Profile Auto preference. A failed
write preserves Auto and Skip; a committed Auto On stops Skip. Settings and
the rail use the same preference. No save/checkpoint schema changed.

One host timer binds the exact registered, acknowledged line and native
runtime frontier. Short, Normal and Long mean 1, 2 and 4 eligible foreground
seconds after complete reveal. Pause, focus/custody loss, and held input
suspend the remaining time; the first resumed delta is discarded. Synchronous
suspension notification also covers a transition between timer ticks. Normal
Accept, a new source, preference restoration or a delay change retires the
old timer. An eligible replacement receives a full delay. Duplicate reveal
signals cannot restart a consumed or refused command.

DialogicBridge rechecks the exact proof, Profile preference, acknowledged
presentation, completed reveal and next ordinary-text event before one native
advance. Auto cannot cross choices, effects, markers, challenge/route entry,
return, unknown events or completion. No extra per-line run checkpoint is
introduced. Registered-line presentation keeps its existing atomic Profile
write. The native player Auto flag remains neutral; forced and one-event
Dialogic Auto capabilities are preserved, but no production authoring or
setter currently enables them. Their existing acknowledgement guards are
tested separately and are not a claim of host timer/boundary parity.

## Verification

| Final run | Result | Scope |
| --- | --- | --- |
| `witnessed-auto-final-focused` | 85/85 tests, 1,846 assertions | Profile adapter, timer, rail, Bridge and mounted Dialogic |
| `witnessed-auto-regression` | 198/198 tests, 7,108 assertions | 15 reading/input suites on the Windows display driver |
| `witnessed-auto-tooling-green` | 14/14 tests, 410 assertions | Public inventories and documentation validator |
| `witnessed-auto-contract` | Exit 0; 64 scenes, 137 entries | Dialogic content contract |
| `witnessed-auto-docs` | Exit 0; 16 packets, 4 authorities, 1 workflow | Documentation and scoped 23-Bead snapshot |
| `witnessed-auto-native-uia` | Exit 0 | Native Windows UIA Auto invocation and isolated real Profile write |
| `witnessed-auto-render-green` | Exit 0; 3 images | English, Simplified Chinese and Traditional Chinese at 150% |

Counts overlap and are not additive. The mounted runtime tests use real
Dialogic with explicitly synthetic text and registered authored IDs. They
cover keyboard activation of the actual Auto rail, Profile failure/Skip
arbitration, one ordinary-line advance, reveal completion, full-delay restart
after Normal Accept, and Pause both with and without an intervening timer
tick. Unit and Bridge tests cover exact delay presets, stale/empty proofs,
mutation custody, duplicate/reentrant callbacks, source retirement,
preferences/restore and all non-text boundaries. This is not a human playtest.

The native probe directly mounts the rail with isolated real ProfileManager;
it does not substitute a fake narrative Bridge. Windows UIAutomation
InvokePattern targets the exact process and enabled Auto button. The result
is one semantic activation, zero Button.pressed signals during invocation,
zero physical contacts, and persisted Profile Auto Off to On. A separate
programmatic Button.pressed emission is rejected before READY. This proves
the native provider and preference seam, not screen-reader speech, timer
behavior or narrative advancement. Those runtime paths have separate tests.

The three 1280×720 images show complete localized labels and the six-cell
rail at 150%. Their synthetic, unregistered captions deliberately leave all
transport controls disabled; the images prove copy and geometry, not command
availability. No art, font or rail geometry changes are included.

GameState and SaveManager inventories were regenerated. Their public records,
signatures and contracts are unchanged; only call-site and dynamic-reference
data changed. The source report records this comparison and hashes 15 source,
fixture and verification-helper files with LF normalization.

## Diagnostic history and remaining work

All 18 terminal engine runs are retained, with 25 hashed artifacts. The
retained RED runs include absent owner APIs, one controller type-inference
error, the missing mounted Auto node, a Text.text_finished callback signature
mismatch and the old Skip-only focus expectation. A later fixture correction
waits for asynchronous text publication and uses three ordinary lines: the
old two-line fixture correctly stopped Auto before Return. The native helper
first failed to parse because its Profile variable was out of scope; the
corrected render and native invocation pass.
The first tooling invocation named the wrong test directory and executed no
suites; the wrapper rejected it with exit 126. The corrected paths pass.

Review reproduced a real between-tick suspension defect: a covered interval
could be charged on the first resumed tick. The final fix preserves the exact
remaining time and synchronously invalidates that delta. Both unit and mounted
Pause cases pass after their recorded RED.

The regression reports 2,280 detached-node/orphan observations from Dialogic
fixtures. Logs retain Unicode/NUL diagnostics; native UIA has four such
warnings before READY. No warning-free, leak-free, whole-tree or whole-game
claim is made. The unrelated global UI literal audit defect remains tracked
by `dwm-vky.15`.

Shared Primary-language system TTS does not yet exist. Dialogic authored Voice
is not a substitute; this increment does not certify speech completion
arbitration. Session History, Backup Save/Load, exact-variant Next, complete
transport arbitration and visible Profile-write error recovery remain
unfinished. `dwm-vky.14` stays open.

No `dwm-634` or `dwm-634.*` Bead, implementation, branch, worktree or dirty
change is included. Those externally owned tasks are excluded from this goal.

## Reproduction

Use the exact arguments in `runs.jsonl` through
`tools/testing/Invoke-IsolatedGodot.ps1`, one engine at a time and with a fresh
isolated root. The wrapper supplies `--headless`, `--path` and `--log-file`.
The Windows runs explicitly override the display driver. While the native
probe waits at READY, run `Invoke-WitnessedTransportAccessibilityAction.ps1`
with that exact log, an output path and `-Control Auto`.

The documentation run uses the archived 23-Bead snapshot copied to its
recorded temporary path. Source hashes and inventory comparison are in
`source-and-inventory.json`. Archived text is UTF-8/LF; log trailing whitespace
is removed without modifying original raw logs. `SHA256SUMS.txt` covers the
ledger, logs, snapshot, UIA receipt, source report and images, excluding this
README and itself.
