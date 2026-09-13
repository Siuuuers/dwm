# Production Skip command repair — dwm-3an

2026-09-13, isolated branch `fix/dialogic-production-skip` from `3cd20d7e1`.
Installed Godot 4.6.3 mono, serialized runs through `Invoke-IsolatedGodot.ps1`.

The production adapter now supplies the missing `current_line_id()` and classifies
the actual next Dialogic event without executing or mutating it. Identity comes
only from an explicitly authored `#id:<registered semantic line ID>` on a native
text event. The bridge checks registered ownership against its active semantic
entry before revealing text or writing visited history. No path, index, prose,
label, or generated translation ID is substituted for missing semantic identity.

The existing production preference binding supplies the real ProfileManager and
live reading mode to Skip. Failed preference binding restores the previous Skip
provider/mode. The validated line-owner map is built once and reused; Skip does not
read or validate manifests on every step. The ProfileManager remains the sole
visited-history writer, including its durable-commit-before-publication behavior.

Only recognized text can be advanced. Choices, state-capable signals, native
variable events, transitions, and unsupported events stop the command. Unknown
policy values also stop. Multi-segment text is refused because its unseen segments
do not yet have separate authored identities. A real text event completes through
its `advance` signal rather than abandoning its coroutine with an index jump.

Dialogic normally opens a following Choice as soon as its question finishes
revealing. A temporary, Skip-only flag suppresses that automatic opening for this
one reveal. Ordinary input and default restore reveal retain native behavior.
The bridge rejects nested Skip calls and checks playback generation, request,
event index, pause state, and semantic token after reveal and visited publication.
A callback cannot mark or advance a replacement frontier.

## Verification

| Evidence | Result and scope |
| --- | --- |
| `dialogic-skip-final-focused-20260913.log` | 54/54, 655 assertions, exit 0: real runtime, production adapter and bridge, real ProfileManager over FakeFileOps; policy, preferences, adapter contract and callback/reentry tests |
| `dialogic-skip-lifecycle-regression-20260913.log` | 99/100 initially; one existing caption test double lacked the newly required visited interface. The other 69 tests outside that caption suite passed, including live admission, restore, Pause and run presentation |
| `dialogic-skip-caption-regression-20260913.log` | Final caption suite 31/31, 3,775 assertions, exit 0 after adding fail-closed history stubs to that test double; existing assertions preserved |
| `dialogic-skip-profile-reset-20260913.log` | 3/3, 155 assertions, exit 0; real profile reset consumers |
| `dialogic-skip-inventory-docs-20260913.log` | 14/14, 410 assertions, exit 0; public-surface and documentation gate after regenerating inventories from the final source/test tree |
| `invocations.jsonl` | Exact arguments, isolated roots, timestamps and actual process exit codes, including unsuccessful investigative runs |

The native fixture uses synthetic anonymous text and existing registered reply IDs
in an isolated entry locator. No shipped prose or manifest was authored or changed.
It proves read-only first-unread stop, subsequent visited advance, live all-text
mode, refused missing/unregistered/cross-owner IDs, choice/signal/return/unknown
boundaries, and ordinary `Inputs.handle_input()` continuing a stopped Choice.
A fresh ProfileManager reads the saved visited line through a fresh JsonFileStorage
over the same FakeFileOps. This proves serialization/reload, not physical-disk
crash durability. Existing addon/GUT orphan and NUL diagnostics remain; successful
final runs have no script errors and exit normally.

## Separate shutdown defect — dwm-so4

The initial fixture used an unregistered `Narrator:` speaker. Even its setup-only
test, with no Skip call, passed assertions and then crashed on shutdown with exit
`-1073741819`. Binding without playback exited 0. Retaining the timeline, forcing
the owned caption style, and reducing to two text lines did not fix the crash.
Removing only the `Narrator:` prefix while keeping every event made setup exit 0.
The final complete Skip suite also exits 0 with anonymous text.

`production_skip_with_unregistered_speaker.dtl.txt` preserves the failing fixture.
The binding, setup, retained-fixture, owned-style, minimal-content, and anonymous
probe logs preserve the ablations. Runtime-created character lifetime is a
hypothesis, not a proven root cause. This bug is **not fixed** by dwm-3an; do not
treat an assertion summary as success when the engine process crashed afterward.

An earlier classifier prototype also failed because `Resource.duplicate()` drops
Dialogic's unexported event properties. The corrected classifier reads an already
decoded event or parses a new detached event from its authored source.

## Remaining work

This closes the missing production command/adapter seam. It does not complete the
Witnessed six-control rail, session Skip toggle, Auto exclusion, or physical-device
acceptance. Those remain explicit work on `dwm-eei`. Binding the unused legacy
DialogueBox alone would not implement the mounted native Witnessed transport.

All 64 shipped timeline records currently have empty line/event arrays and the
story files are placeholders. Future dialogue must carry its approved semantic IDs;
fixture execution is not evidence of finished narrative content. The broader goal
remains active. No GameState, SaveManager, Minesweeper or protected dating latency
source was changed. Historical UI evidence resealing remains the final epic gate.
