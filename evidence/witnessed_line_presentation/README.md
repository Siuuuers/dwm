# Witnessed: durable line presentation

This 2026-09-14 increment starts at `0ff28f6fad2418b244b3a5e4b1c43ef5327caf60`.
It implements normal presentation acknowledgement for registered, single-line
canonical dialogue, a prerequisite of the remaining `dwm-vky.14` controls.

The mounted CaptionLayer records a line through the existing atomic Profile
visited-history mutation when its parsed caption enters the visible stream.
It does not wait for glyph completion, require Skip, or add a run checkpoint.
Bridge admission binds the Profile instance, entry, stage, playback token,
line ownership, and runtime generation/event/request. A repeated successful
acknowledgement does no additional FileOps work. Hidden captions can retain
their source proof, but cannot commit until actually visible.

The first Read Only Skip stop retains the line's pre-presentation unread
state. A later deliberate activation may continue that now-read line. A
recoverable write failure permits a fresh explicit retry; an indeterminate
failure remains blocked under the same Profile, including after source
replacement. A new Profile owner clears that latch. Synchronous source
replacement cannot borrow an old click or automatic callback. The interval
between replacement announcement and actual text publication blocks input.

Native Auto, automatic Choice opening, and both native Auto-Skip timer exits
consult the mounted admission policy at advancement. Refusing automatic
Choice opening retains the normal advance wait so a later successful manual
retry can proceed. These guards do not implement the full guarded Auto owner.

The relevant authority is the presentation boundary in the accepted seven-day
flow (lines 651-656), the Settings reading amendment section 9.2, and the
accepted Witnessed Read Only stop/second-activation rule. Visited history is
not an echo/effect receipt or proof of a narrative consequence. Rehearsal has
no direct Profile visited mutation. Legacy, no-ID and unregistered prose
retain their input behavior; registered wrong-owner text fails closed.

## Verification

| Final run | Result | Scope |
| --- | --- | --- |
| `witnessed-line-presentation-green` | 54/54 tests, 931 assertions | Real mounted runtime and focused Bridge proofs |
| `witnessed-line-presentation-regression` | 166/166 tests, 6,561 assertions | 12 suites: adapter, Bridge, Skip policy/controller/button/rail, production text, caption input, Pause and run presentation |
| `witnessed-line-presentation-tooling` | 14/14 tests, 410 assertions | Reproducible public inventories and documentation validator |
| `witnessed-line-presentation-contract` | Exit 0; 64 scenes, 137 entries | Dialogic content contract |
| `witnessed-line-presentation-docs-complete-snapshot` | Exit 0; 16 packets, 4 authorities, 1 workflow | Current docs with a scoped 23-Bead snapshot |

Counts overlap and are not additive. The regression uses the Windows display
driver and OpenGL renderer with an offscreen window. Its physical-event tests
inject events into the real mounted input/runtime path. It is not a human
play session, a screen-reader speech test, or a new Windows UIA provider run.
Earlier rail UIA evidence remains a separate historical checkpoint.

The focused tests include persisted reload through a fresh ProfileManager
using memory-backed atomic storage (not a separate application process),
duplicate publication, wrong ownership, stale/empty proofs, reentrant writes,
mutation custody, fatal-owner rebinding, hidden/late captions, source removal
and announced replacement, ordinary Accept, and both native timed Skip paths.
The content fixture uses authored registered IDs and short fixture text.

GameState and SaveManager inventories were regenerated. Public records,
signatures and contracts remain unchanged; only call-site and dynamic
reference data changed. `source-and-inventory.json` records this comparison
and LF-normalized source hashes.

## Diagnostic history and limits

All 17 terminal engine runs are retained in `runs.jsonl` and `logs/`.
Initial RED runs expose missing ordinary acknowledgement and automatic
advancement guards. The first retry fixture accidentally failed a read of an
existing Profile, producing an indeterminate transaction; the corrected
fixture fails only the initial transaction-marker write and asserts the
recoverable `write_not_committed`, `fatal=false` result.

The review RED reproduces late binding, timed Skip, stale input and empty
proof defects. The lifecycle RED also reproduces announced replacement.
Three preliminary hidden-caption attempts did not reach the intended next
line; they are fixture diagnostics, not proof of the visibility defect. The
final `visible-red` run reaches real LINE_B under a hidden ancestor and fails
only because that line was incorrectly marked visited. The final GREEN fixes
that assertion. The first docs run used a snapshot missing required metadata;
the corrected scoped snapshot restores metadata without changing Beads.
Both snapshots are archived. An initial forbidden wrapper argument was
rejected before engine launch and is not an engine run in this ledger.

The regression reports 2,136 detached-node/orphan observations from Dialogic
fixtures; tooling reports 24. Logs retain Unicode/NUL diagnostics. No
leak-free, whole-tree, full reading-rail, or whole-game completion is claimed.
There is not yet a dedicated visible error notice for failed Profile writes;
fresh explicit retry is covered. Only registered single-line sources use
this acknowledgement: the current registry has 18 ordinary reply lines and
two observer-associated lines. Multi-segment prose does not receive invented
line IDs. Session History, guarded Auto, Backup Save/Load, exact-variant Next,
full arbitration and shared TTS remain unfinished. `dwm-vky.14` stays open.

No `dwm-634` or `dwm-634.*` task, implementation, branch, worktree or dirty
change was modified. No save/checkpoint schema changed.

## Reproduction

Use the exact script/test arguments in `runs.jsonl` through
`tools/testing/Invoke-IsolatedGodot.ps1`, one engine at a time, with a fresh
isolated root. The wrapper supplies `--headless`, `--path` and `--log-file`;
do not pass those arguments again. Windows overrides appear explicitly in
the regression entry. Copy the archived complete snapshot to the temporary
path named by the successful docs run before repeating that command.

Archived text uses UTF-8/LF with trailing whitespace removed from logs.
`SHA256SUMS.txt` covers the logs, ledger,
snapshots and source/inventory report; it excludes this report and itself.
