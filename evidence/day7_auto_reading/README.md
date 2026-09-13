# Day 7 Auto reading

2026-09-14; `dwm-bap`; source baseline `047eb091e8858bcdbe8bad6b0cdc451f98d22170`.

The production Day 7 prelude now reads the committed profile's Auto Dialogue
setting and Short / Normal / Long delay of 1 / 2 / 4 foreground seconds.
The delay runs only on a visibly presented, durably acknowledged card with
admitted input custody. Focus loss, Pause, a covered view and held input suspend
the remaining time. Replacement cards and changed reading preferences start a
fresh delay. Auto requests navigation once; it never invents a button press,
acknowledges an unseen card, retries a failed save, or completes the final route
handoff. The final card requires fresh manual Next.

The passive Auto indicator shares the existing footer with Next. The default
standalone Gallery surface has no reading-profile binding and keeps its manual
behavior. No new preference, run-save field, checkpoint writer or save schema is
introduced. No `dwm-634` work, branch or task state is changed.

Authority: `docs/design/current-ui/settings.md` section 9.1;
`docs/design/current-ui/witnessed-scene.md` section 8.2;
`docs/design/2026-08-07-seven-day-dialogic-flow-design.md` section 9.3.
The existing AccessibilityManager helper's three-second Long value is not used
for this four-second contract. No production system-TTS coordinator is installed;
this increment does not claim speech, Skip, assistive traversal or full shortcut
parity. `dwm-bap` and the full echo/drain acceptance remain open.

## Development evidence

The native RED journey reached Day 7 through actual New Account, Contacts,
Lavinia's reply and daily public Schedule Done. It failed because the original
surface did not reflect the committed Auto preference. The first focused run
then exposed a replacement-card assertion in the test helper; it was corrected
to preserve and verify both exact receipts, including deferred redraw alignment.

The first implementation passed all 31 native surface/input/Auto tests, then
the full artwork journey exposed a real layout regression: a separate Auto row
reduced the scroll aperture enough to hide the current body. Sharing the footer
with Next restores the existing reading height; native artwork/text-size coverage
and the same full journey verify the repair. Failed runs remain in the ledger.

## Verification and limitations

| Isolated Godot check | Observed result |
| --- | --- |
| Final native Auto, presentation and input suites | 32/32 tests, 537 assertions; exit 0 |
| Final native seven-day Auto/Retry/Pause/Autosave Load/manual Next journey | PASS; exit 0 |
| Six surrounding suites with this change | 56/59 tests, 1804/1812 assertions; exit 1 |
| Identical surrounding suites with the three production files restored to HEAD | The same three failures and eight assertions; engine exit 1 |
| Current documents with fresh 167-issue Beads snapshot | PASS: 16 packets, 4 authorities, agent workflow; exit 0 |
| Regenerated public inventories and document regression suites | 14/14 tests, 410 assertions; exit 0 |

The surrounding batch is **not green**. Both versions fail these existing
`test_desktop_bootstrap_wiring.gd` tests at the same assertions:

- `test_gameplay_mount_uses_real_ports_and_first_reveal_persists_one_charge`:
  lines 616, 620, 622 and 624.
- `test_fresh_graph_keeps_prior_day_two_autosave_after_failed_completion`:
  line 738 twice.
- `test_fresh_graph_keeps_prior_autosave_after_failed_condition_departure`:
  line 742 twice.

For that differential check, only ApplicationBootstrap, Day7PreludeOwner and
Day7PreludeSurface were temporarily replaced with their `047eb091e` Git blobs,
then restored in `finally`. The baseline engine exit is 1 in `runs.jsonl`; the
outer restoration command returned 0 and is not treated as a passing test.
The failures concern checkpoint failure injection in the excluded Minesweeper
work. They are recorded here as an overlap, not repaired, reclassified or closed.
This proves no added failures in that batch, not correctness of the excluded work.

The public inventories retain all 239 GameState and 74 SaveManager contracts.
Only call-site and dynamic-reference line locations moved with the integration
test. The requirement rules and historical seals are unchanged. Independent
review found no remaining production blocker and confirmed the differential
result. Its test-timeout finding was repaired by using a five-second wall-clock
deadline; the full native journey passed again with that final helper.

`runs.jsonl` records the actual arguments, engine exits and isolated directories;
the named logs and Beads snapshot are archived alongside it. Native tests inject
Godot input events through the viewport; this is not hardware certification.
The final restored-card capture was visually inspected, as was the earlier
layout-failure capture. No player save was used. Existing Unicode NUL diagnostics
and Dialogic orphan reports remain in the logs; trailing horizontal whitespace
and final newlines alone are normalized when archiving.
