# GLOSSARY — Quick-reference index (pointers only)

This file is a pure navigation index. Each topic is documented in exactly one file (listed
below). Open that file and read the rule directly; do not infer it from another file. No
spec detail is restated here — if a rule is needed, follow the pointer.

## Where each rule lives
- **Schedule Done entry point.** `GameState.execute_schedule_sequence_until_route_needed()`. `CONTRACTS.md` §2; used in `FLOWS.md` §2.
- **`reset_game()` audio state.** `CONTRACTS.md` §2 (audio_state default + reset behavior).
- **Missed-group twofriends entries.** `GameState.create_missed_group_twofriends_entry()`. `CONTRACTS.md` §2.
- **Group invitation naming.** Participant-based, not open-order; first opened = inviter. `CONTENT.md` §6; `DIALOGIC.md` §6.
- **Day-7 solo dating has no `.dtl`.** Routes to `EndingScene` via `resolve_day7_ending()`. `DIALOGIC.md` §7; `CONTRACTS.md` §2.
- **Supportz.** Catalog + per-day gate. `CONTENT.md` §7; `CONTRACTS.md` §2 `can_buy_supportz()`.
- **Special Sylvia ending (`ending.sylvia.special`).** `CONTRACTS.md` §2 (Day-7 ending contracts); `FLOWS.md` §6.
- **Real-time faint check (`check_immediate_faint()`).** `CONTRACTS.md` §2.
