# Ordinary-message expiry receipt

2026-09-13, base `8f96bab81`, Godot 4.6.3 mono.

The accepted [Contacts amendment](../../docs/design/2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md)
requires unanswered ordinary correspondence to vanish at midnight whether seen
or unread, retaining one invisible deterministic tombstone (§13.1), persisting
that fact (§14.2), and restoring the selected save's earlier state when loading
a pre-expiry snapshot (§25.5).

`ContactInvitationState.prepare_resolve_day_end` now places the optional string
`ordinary_expired_entry_id` on its existing `resolve_day_end` receipt. The shared
closure path is used by normal day resolution and condition Hospital. Unanswered
ordinary messages are virtual until a reply is witnessed, so expiry allocates
no message row, canonical sequence, watermark, reply, echo, text, or separate
receipt/index. Replied exchanges retain their existing history and pending echo.
The six identities derive from `SevenDayCalendar`; the normal narrative registry
loader verifies the same identities. Midnight recording performs no narrative
file loading.

The new field must name the exact ordinary entry for receipt days 1–6. Exact-key
validation rejects additional text or other payloads, and cross-receipt checks
reject duplicate expiry ownership and any replied-and-expired contradiction.
Generation also refuses an expired entry when queried for its original day.

No Contacts or RunSnapshot schema member changed. Legacy closure receipts without
the field still validate, and replay returns the stored receipt/state unchanged
without backfill.
Such legacy receipts cannot prove an expiry fact that was never recorded;
ordinary calendar filtering still prevents yesterday's menu in their actual
post-midnight day. No future state is overlaid onto an earlier selected save.

## Verification

[runs.jsonl](runs.jsonl) records actual isolated commands, roots, times and exit
codes. All logs are retained alongside it.

| Run | Evidence |
| --- | --- |
| `ordinary-expiry-receipt-red-corrected-20260913.log` | Expected RED: 0/1 test, 12/14 assertions, exit 1. Missing expiry record and stale original-day generation both fail. |
| `ordinary-expiry-receipt-green-20260913.log` | 70/70 tests, 1,309 assertions, exit 0: ordinary state, Contacts state, actual checkpoint runtime and ordinary UI. |
| `ordinary-expiry-receipt-final-unit-20260913.log` | Final ordinary suite: 11/11 tests, 271 assertions, exit 0. Adds three explicit legacy-replay assertions to the preceding run. |
| `ordinary-expiry-receipt-surrounding-20260913.log` | 90/90 tests, 971 assertions, exit 0: Hospital state/runtime/port, RunSnapshot, production day snapshots and day coordinator. |
| `ordinary-expiry-receipt-native-final-20260913.log` | Windows/OpenGL full bootstrap and actual Backup Save/Load journey, exit 0 in 14.41 seconds. |
| `ordinary-expiry-receipt-native-reviewed-20260913.log` | Final expiry journey after strengthening the original-day query, exit 0 in 14.23 seconds. Source of the three retained captures. |
| `ordinary-expiry-receipt-seven-days-20260913.log` | Full native seven-day reply/follow-up/failed echo checkpoint/Pause/Autosave Load/fresh Next journey, exit 0 in 23.21 seconds. |
| `ordinary-expiry-repository-gate-20260913.log` | Public-surface inventory and document-validator tests: 14/14 tests, 410 assertions, exit 0. |

The latest results cover 174 distinct passing tests and 2,693 assertions. The
final 11-test ordinary suite supersedes its earlier result within the 70-test
batch; it is not counted twice. These are focused checks, not a full-suite claim.
Existing Unicode and 24 outside-test Dialogic/GUT orphan diagnostics remain in
the logs.

The expiry journey uses actual New Account, viewed-but-unanswered Lavinia Day 1,
public Backup Slot 1 Save, public Schedule Done and warnings, one retained
day-end expiry, and full Autosave Load with exact Contacts/receipt equality.
It then loads the earlier Slot 1, verifies the exact original Day 1 state and
absence of future expiry, returns Home from the correctly restored Backup app,
and verifies all three original reply controls are visible and enabled.
No game state, messages, clock, reply or persistence owner is seeded or replaced.
UI actions use the installed controls' signals and public commands; this is not
hardware or assistive-technology acceptance testing.

The final native check explicitly queries the expired entry with its original
Day 1, independently proving receipt-based suppression rather than merely the
Day 2 calendar filter. The late-reply runtime assertion checks the existing
wrong-day guard; authenticated same-day expiry rejection is covered by the unit
suite.

The inspected, unmodified captures retained here are
`ordinary-expiry-day1-unanswered.png`, `ordinary-expiry-day2-restored.png`, and
`ordinary-expiry-earlier-slot-restored.png`. They show the original choices,
the empty post-expiry transcript, and the original choices after earlier Load.

The first RED setup used an incorrect expected entry prefix; it is retained as
`ordinary-expiry-receipt-red-20260913.log` but only the corrected run is claimed.
The first native attempt exited 1 because the fixture tried to switch directly
from the restored Backup app to Contacts. Its physical Slot 1 snapshot confirmed
`active_app_id=backup`. Correcting the test to use Home resolved that failure;
no production navigation rule was changed.

Both public-surface inventories were regenerated after the final source change
with actual exit 0. Comparing their parsed records with the base while excluding
only call-site locations gives identical contracts: 239 GameState and 74
SaveManager entries. The generated files update test call-site locations only.
Independent review found no production blocker and requested the stronger
original-day probe above; that correction passed the final native run.

The ordinary expiry gap is addressed by this increment. Day 7 Auto, Skip, TTS,
assistive traversal and remaining shortcut parity are still open; broader echo
and drain requirement evidence and parent Beads are not closed here. The rare
solo-invitation erasure family and Minesweeper latency are outside this change.
