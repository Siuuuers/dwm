# CONTRACTS — Authoritative code contracts

Every public API, autoload contract, resource class, and data-catalog helper signature lives in the `autoload/*.gd` / `scripts/**/*.gd` files. This document records only the **behavioral contracts that are not obvious from the code**: return dictionaries, algorithms, invariants, ownership divisions, and the authoritative path list. Do not duplicate signatures here; read the `.gd`.

Normative verbs: `MUST` = hard requirement (tests enforce); `SHOULD` = strongly recommended, deviation needs a documented reason in `ResultReport.md`; `MAY` = optional.

---

# 1. Architecture and Autoloads

Nine autoload scripts, each `extend Node`:

1. `res://autoload/GameState.gd`
2. `res://autoload/EffectResolver.gd`
3. `res://autoload/SceneRouter.gd`
4. `res://autoload/LocalizationManager.gd`
5. `res://autoload/DialogicBridge.gd`
6. `res://autoload/SaveManager.gd`
7. `res://autoload/InputManager.gd`
8. `res://autoload/AccessibilityManager.gd`
9. `res://autoload/AudioManager.gd`

**Load order in `project.godot`** (authoritative): the first four in this exact order (`GameState`, `EffectResolver`, `SceneRouter`, `LocalizationManager`), then the helpers (`DialogicBridge`, `SaveManager`, `InputManager`, `AccessibilityManager`, `AudioManager`). `DialogicBridge` comes after `LocalizationManager`. If `project.godot` exists, update its `[autoload]` section safely; if it does not exist, write the conflict in `ResultReport.md` and do not pretend a project was found.

## Ownership rules
- **GameState** owns all mutable runtime state. UI must call safe public methods instead of directly mutating dictionaries if a method exists.
- **EffectResolver** applies whitelisted effect IDs only, via two-pass validation.
- **SceneRouter** only changes scenes and stores safe route context through `GameState`. It must not apply stat, economy, affection, schedule, condition, or dating rules directly.
- **LocalizationManager** owns language lookup and locale switching.
- **SaveManager** serializes/deserializes whitelisted `GameState` data. Never saves Nodes, Objects, Callables, Resources, or live references. Never loads scripts/classes from save data.
- **InputManager** owns input actions, controller mappings, focus helpers, and rebinds.
- **AccessibilityManager** owns UI readability settings and application of accessibility settings to trees.
- **AudioManager** owns music/ambience/sfx contexts. Must not apply gameplay effects or change scenes.
- **DialogicBridge** owns all direct interaction with Dialogic. Scenes must not duplicate Dialogic detection logic.

## Optional plugin safety
Only connect to optional signals after checking the object exists and supports the signal. State Charts may be used only if already installed and safely detected; otherwise use simple enum/state variables in GDScript.

---

# 2. GameState API

`res://autoload/GameState.gd` (extends `Node`) owns all mutable runtime state. Signatures, signal signatures, constants, and state-var field lists are authoritative in the `.gd`. The behavioral contracts below are the contract. Stat/money/coin clamp numbers and initial values are authoritative in the `.gd` (`reset_game()`, `get_stat_min`/`get_stat_max`/`get_stat_display_value`/`get_stat_display_max`, `change_money`/`can_spend_money`, `change_coins`/`can_spend_coins`).

## `execute_schedule_sequence_until_route_needed()` return contract
Single orchestrator of the Schedule Done flow. Simulates the schedule left-to-right, stops when a routing decision is needed. Returns:
```gdscript
{
    "ok": bool,            # false if the schedule was invalid / could not be executed
    "executed": bool,      # true if any non-date effects were applied before stopping
    "needs_hospital": bool,
    "route": String,       # "hospital" | "dating" | "twofriends" | "advance" | "none"
    "date_entries": Array,
    "twofriends_entries": Array,
    "reason": String
}
```
Rules:
- `needs_hospital` true → caller routes `HospitalScene`, skips Angela's scheduled dates.
- `route == "dating"` → `SceneRouter.goto_dating_entries(date_entries)`.
- `route == "twofriends"` → `SceneRouter.goto_dating_entries(twofriends_entries)`.
- `route == "advance"` → `GameState.advance_day_or_end()`.
- Day-7 endings are NOT produced here: on Day 7 `ScheduleApp` calls `resolve_day7_ending()` at step 0 (`FLOWS.md §2`); this method is never invoked. `route` never equals `"ending"`.
- `GameState` never auto-routes; the caller performs the scene change through `SceneRouter`.

## `should_warn_minesweeper_before_schedule_done() -> Dictionary` return contract
```gdscript
{
    "should_warn": bool,
    "reason": String,   # diagnostic only
    "has_unfinished_round": bool, "has_playable_round": bool,
    "motivation": int, "has_non_date_entry": bool
}
```
`reason` values (authoritative): `unfinished_round_and_motivation`, `playable_round_and_motivation`, `playable_round_zero_motivation_with_non_date`, `date_present`, `no_warn`.

Boolean contract: let `has_date_entry` = the schedule contains a solo/group/twofriends entry. If `has_date_entry` is true, `should_warn = false` (`reason = "date_present"`). Otherwise `should_warn == true` when ANY of:
- an unfinished app round exists AND motivation > 0 → `unfinished_round_and_motivation`;
- playable app rounds remain AND motivation > 0 → `playable_round_and_motivation`;
- playable app rounds remain AND motivation == 0 AND the schedule has >= 1 non-date entry → `playable_round_zero_motivation_with_non_date`.

Else `should_warn = false` (`no_warn`). Tests MUST assert on `"should_warn"`, never on `reason` or a bare boolean.

## Combined-date / missed-group exclusivity (invariant)
A `twofriends` entry (from `create_missed_group_twofriends_entry()`) and an Angela solo/group date entry for the same pair **can NEVER be produced on the same day** (proof: a group invitation is generated only if NEITHER participant's contact was opened that day; scheduling an Angela pair-date requires opening that participant's contact, which suppresses the group invitation). Consequence: the single `route` key suffices; the caller MUST route exactly one of `date_entries` / `twofriends_entries` (never both). No `dating_then_twofriends` branch — unreachable by construction.

## Affection / attitude / inter-friend change sources (invariant)
`affection`, `friend_attitude`, and `inter_friend_affection` are mutated by EXACTLY two sources:
1. `apply_dating_challenge_result()` — dating-challenge `affection_delta` (solo/group participants) and `inter_friend_affection` on `twofriends` entries.
2. Contact **reply choices** that carry a whitelisted effect, applied via `EffectResolver` and defined inside the contact `.dtl` timelines.

Everything else is FLAVOUR-NEUTRAL and MUST NOT change these values: declining an invitation, ignoring a contact, missing/skipping a scheduled date, and the `nevermind` / `missed_question` / `missed_group` follow-up timelines. Implementers MUST NOT add hidden affection/attitude drift. A reply that does not carry an explicit whitelisted effect MUST NOT change affection.

## Missing-method contracts

### `has_minesweeper_app_round_available() -> bool`
`true` when `minesweeper_rounds_left > minesweeper_round_floor`. Checks ONLY the floor/rounds relationship. Does NOT check motivation or `unfinished_minesweeper_result`. Use for "is there any app round left"; use `can_start_minesweeper_app_round()` before actually starting.

### `can_buy_supportz() -> bool`
`true` only when BOTH: `minesweeper_app_rounds_finished_today >= 2` AND `minesweeper_round_floor > MINESWEEPER_ROUND_FLOOR_MIN` (-3). The separate per-purchase cap (`shop_purchase_counts["supportz"] < 3`) is enforced by `ShopApp` / `EffectResolver`. Supportz catalog/per-day gate/floor clamp: `CONTENT.md §7`.

### `get_daily_message_friend_for_finished_round(round_number: int, target_day: int = -1) -> String`
- `round_number == 1` → first friend in `DataCatalog.get_daily_contact_message_order(target_day)`.
- `round_number == 2` → second friend.
- `round_number == 3` (Day 7 only) → third friend, but ONLY if `minesweeper_round_floor < 0`.
- Returns `""` if the order is empty, index out of range, or the solo message was suppressed by a group invitation that day.

### `unlock_contact_message_after_minesweeper_finished(result: Dictionary) -> Dictionary`
Called by `finish_minesweeper_app_round(result)` after rewards, for app-context finishes only. Sets `contact_message_unlocks["day:<day>:friend:<friend>"] = true` and emits `contact_message_unlocked`. On Day 7 the unlock also requires `get_affection_tier(friend) in ["ambiguous","love"]` (the ending-candidate gate). NEVER writes `route_context["ending_id"]`.

### `has_unread_friend_messages() -> Dictionary`
```gdscript
{ "priscilla": bool, "lavinia": bool, "sylvia": bool }
```
A friend is unread when `contact_message_unlocks["day:<day>:friend:<id>"] == true` AND `daily_opened_contacts["day:<day>:friend:<id>"] != true`. No UI consumer yet (Phase 3 builds the badge/notification against this shape).

### Reserved / stub declarations (do not invent semantics)
- `post_ending_queue: Array` and `chat_state: Dictionary` are declared and save-whitelisted but reserved/opaque; no logic may read or write them yet.
- `get_contact_choices(friend_id, target_day) -> Array` is a deliberate stub (always `[]`); reply choices are presented by the DTL.
- `should_route_hospital() -> bool` returns `pending_hospital` (no side effects).

### `create_missed_group_twofriends_entry(day: int, friend_ids: Array, inviter_id: String) -> Dictionary`
Single named producer of `twofriends_entries`. Side effect: increments `missed_group_date_counts["<sorted friend_a>_<friend_b>"]` by 1 (key = the two ids sorted alphabetically, e.g. `"priscilla_lavinia"`). Returned shape:
```gdscript
{
    "type": "twofriends", "friend_ids": Array[String], "inviter_id": String,
    "day": int, "source": "missed_group", "advance_day_after_finish": false
}
```
The `advance_day_after_finish` flag is provenance only; the router MUST NOT read it (day advance governed by `pending_date_advance_day_after_finish`, §4). Used by end-of-day flow and `HospitalScene` post-recovery routing.

## Day-7 ending contracts

`ending_id` storage: `resolve_day7_ending()` writes the chosen id into `GameState.route_context["ending_id"]` (String). `EndingScene` reads `route_context["ending_id"]`; empty/unknown falls back to `"alone"`. `route_context` is the only store.

### `get_day7_ending_candidates_from_schedule() -> Array[String]`
Returns friend ids valid as Day-7 ending candidates: a friend whose Day-7 contact message is unlocked (`contact_message_unlocks["day:7:friend:<friend>"]`), whose Day-7 solo ending-candidate date entry is present in `schedule_entries`, AND whose affection tier is `ambiguous` or `love` (affection >= 4). Max length 1. Ambiguous reaches only dark/sweet; true requires `love`.

**Day-7 candidate gating.** `is_date_unlocked(friend_id, 7)` returns `true` when `contact_message_unlocks` has `"day:7:friend:<friend_id>"` AND `get_affection_tier(friend_id) in ["ambiguous","love"]`. For days 1–6, `is_date_unlocked` uses the normal `date_unlocks` mechanism (written by `choose_contact_option`, which writes `date_unlocks` ONLY on the friend's solo invitation day — `is_invitation_day(friend_id)`). Day 7 is NOT an `is_invitation_day()` day.

### `resolve_day7_ending() -> Dictionary`
Single entry point for the Day-7 ending branch (do not run normal Schedule Done steps 2-4 on Day 7; see `FLOWS.md §2` step 0). Returns:
```gdscript
{
    "ok": bool, "candidate_friend_id": String, "ending_id": String,
    "route_context_set": bool, "epilogue_ending_id": String, "reason": String
}
```
Ending-id resolution (authoritative in this §2):
- Definition — "dated on Day 7" := a Day-7 solo ending-candidate date entry for `f` is present in `schedule_entries`.
- Special Sylvia (highest precedence): `should_route_sylvia_special_ending()` true → `ending.sylvia.special`.
- Else if `should_route_priscilla_lavinia_post_ending()` true → `ending.priscilla_lavinia`.
- Else if `candidate_friend_id == ""` → `ending.alone`.
- Else for candidate `f`: `true` path: `dating_route_state[f]["true_path_count"] >= 4 AND get_affection_tier(f) == "love"` → `ending.<f>.true`; `dark` path: `dark_points >= 2` → `ending.<f>.dark`; `sweet` path: `dark_points <= 1` → `ending.<f>.sweet`; fallback → `ending.alone`.
- Epilogue: if `should_route_priscilla_lavinia_post_ending()` true AND primary `ending_id != "ending.priscilla_lavinia"`, set `epilogue_ending_id = "ending.priscilla_lavinia"`.

Sets `route_context["ending_id"]` / `["epilogue_ending_id"]`, sets `day = 8` (terminal sentinel; consistent with `advance_day_or_end()` at `day >= 7`). Caller routes `EndingScene` via `route_context["ending_id"]`. AUTOSAVE OWNER: `resolve_day7_ending()` never autosaves; the immediate caller (`ScheduleApp` on Day-7 Done; `apply_hospital_recovery_and_advance_day()` on the Day-7 hospital branch) calls `SaveManager.autosave()` exactly once, immediately after. No other caller autosaves on this path.

### `should_route_priscilla_lavinia_post_ending() -> bool`
`true` only when `missed_group_date_counts.get("priscilla_lavinia", 0) >= 2`. Single producer is `create_missed_group_twofriends_entry()` (Day 2 + Day 6 missed groups). When true, both participants skip Day-7 solo invitations.

### `should_route_sylvia_special_ending() -> bool`
`true` only when `hospital_skipped_sylvia_solo_count >= 2`. Counter incremented inside `apply_hospital_recovery_and_advance_day()` for each scheduled solo entry with `friend_id == "sylvia"`, read BEFORE the schedule is cleared, reset by `reset_game()`. Only Days 1, 3, 4, 5 can carry a Sylvia solo date, so the counter can only accrue there.

### Day-7 ending entry points (invariant)
Exactly two callers, both resolve from CURRENT `schedule_entries` / `contact_message_unlocks` / affection:
1. `Schedule Done` step 0 when `GameState.day == 7`.
2. The Day-7 branch of `apply_hospital_recovery_and_advance_day()` (day == 7), reached after a mid-day `check_immediate_faint()` routes `HospitalScene` → recovery.

Consequence: a Day-7 mid-day faint before any ending-candidate date is scheduled resolves the ending from the (possibly empty) current schedule — `ending.alone` or `ending.sylvia.special`.

### Day-7 danger-without-sequela (invariant)
`Schedule Done` step 0 bypasses condition resolution on Day 7. `check_immediate_faint()` requires `sequela` AND a danger stat (pressure >= 10 or health <= 0). A Day-7 danger state WITHOUT `sequela` can never hospitalize that day — it skips straight to the ending with no `HospitalScene`.

## Ending gallery
`record_ending_seen(ending_id: String) -> void` adds `ending_id` to `seen_endings` (key = id, value = true) so `GalleryScene` shows reached endings. Unknown/empty ids ignored. `seen_endings` is in `to_save_dict()` (whitelisted in `SaveManager`), reset to `{}` only by `reset_game()` (NOT cleared on day advance).

## Reset behavior (contracts not inferable from code alone)
- `settings["language"]` PERSISTS across `reset_game()` (sticky last locale; `LocalizationManager` is the only locale writer; never reset to `en`). All other `settings` reset to §8 defaults.
- `seen_endings` → `{}` (gallery store; NOT cleared on day advance).
- `audio_state` → default `{ "current_bgm_id":"", "current_ambience_id":"", "current_context_id":"", "current_context":{}, "music_muted": false }`. `music_muted` lives in `audio_state`; volume keys (`music_volume`/`voice_volume`/`sfx_volume`/`ambience_volume`) are `settings` keys and reset with settings. No pre-reset audio/volume value preserved.
- `hospital_skipped_sylvia_solo_count` → 0.
- `reset_game()` must not directly change scenes. Scene routing belongs to `SceneRouter`.

## Day advancement
`advance_day_or_end()` algorithm (authoritative in `.gd`):
- Records accepted-but-unscheduled invitations into `missed_invitations` (via `collect_unscheduled_accepted_invitations_for_day_end()`) BEFORE clearing daily state, then clears schedule / pending dates / daily condition marker / daily invitation-response state.
- If `day >= 7`: do NOT advance; set `day = 8` sentinel; return `false`. Day-7 ending resolution owned by `resolve_day7_ending()`.
- Otherwise: increment day, begin the new day, return `true`.
- After a successful advance, calls `SaveManager.autosave()`. The Day-7 hospital ending branch performs its own autosave.

`_begin_new_day()` resets motivation, minesweeper rounds, `unfinished_minesweeper_result`, app-rounds-finished-today, daily Minesweeper money, `penalty_points_today`, `condition_effects_today`, daily contact-open and invitation-read state; and adds `sequela` iff the previous day had an uncleared danger condition (`condition_streak_days == 1`).

## Condition resolution
Call `resolve_pressure_health_condition_end_of_day()` once during Schedule Done. Guard against resolving the same day more than once. Authoritative design contract (tests enforce):
- INVARIANT: `condition_streak_days` is a one-day boolean carry, NOT an accumulator — set to `1` by condition resolution on a danger day, read-and-reset to `0` by `_begin_new_day()` (adds next-day `sequela`) or cleared by `apply_hospital_recovery_and_advance_day()`. Never exceeds 1.
- Danger day occurs if pressure >= 10 OR health <= 0. NOTE: the HUD displays pressure only up to 9 (`get_stat_display_max`); the internal range is 0..12, so pressure 10–12 is an intended "hidden" danger zone the meter cannot show. It always resolves at end-of-day condition resolution (or via hospital), so it is design, not a bug.
- If only one danger condition true: `nausea`. If both: `dizzy`. If danger day: apply `sequela` to next day.
- Penalty: pressure penalty = pressure - 9 when pressure > 9; health penalty = 1 - health when health <= 0; daily penalty capped at 6; total penalty capped at 42.
- After counting: pressure above 9 resets to 9; health below 1 resets to 1.
- `sequela` only remains for that day. If the day had `sequela` and also gets `nausea`/`dizzy`, append `faint`. Set `pending_hospital` true; emit `condition_effect_resolved` then `hospital_needed`.

### `check_immediate_faint() -> bool` (real-time faint detection)
Called by `MinesweeperApp` (after `finish_minesweeper_app_round`) and `ShopApp` (after applying purchase `effect_ids`). Returns `true` and triggers hospital routing when:
- `condition_effects_today.has(CONDITION_SEQUELA)` AND (`get_stat(STAT_PRESSURE) >= 10` OR `get_stat(STAT_HEALTH) <= 0`).
- INVARIANT: `sequela` is only present at mid-day when carried from the PREVIOUS day's danger condition. A mid-day faint — and thus the Day-7 hospital / Special Sylvia path — requires the prior day to have been a danger day not hospital-cleared.
- On trigger: sets `pending_hospital = true`, emits `condition_effect_resolved` and `hospital_needed`, returns `true`. Caller routes `SceneRouter.goto_hospital()` and abandons the current app (abandoned boards are safe per `FLOWS.md §3`). Does NOT apply end-of-day penalty. Does NOT fire on a danger day without `sequela`.

Hospital recovery (`apply_hospital_recovery_and_advance_day()`): restores health = 6, pressure = 3; clears `pending_hospital`, condition streak, sequela, and schedule (no refund). BEFORE clearing the schedule: for each entry with `type == "solo"` and `friend_id == "sylvia"`, increments `hospital_skipped_sylvia_solo_count` by 1 (must read `schedule_entries`, not `pending_date_entries`, and run before `clear_schedule_without_refund()`). Then:
- `day < 7`: call `advance_day_or_end()`, return its result.
- `day == 7`: do NOT advance. Call `resolve_day7_ending()` (same precedence as normal Day-7 Done), `SaveManager.autosave()`, return `false`.
- `HospitalScene` calls `SceneRouter.goto_ending()` when the method returned `false`; otherwise `goto_main()` (CONTRACTS §4 / FLOWS §6).

## Invitation rules
Friend IDs: `priscilla`, `lavinia`, `sylvia`. Solo/group invitation days and group pairs are authoritative in `CONTENT.md §4` (mirrored in `GameState.gd _INVITATION_DAYS` / `DataCatalog.get_invitation_days()`). Day-7 ending-candidate solo invitations are NOT in the `CONTENT.md §4` list; they are generated by the Day-7 ending path and must not be returned by `get_invitation_days()`.

Individual invitation timing:
- First solo invitation available after 1 completed Minesweeper app round; second after 2.
- Day 7 solo-only order: after 1 round Priscilla; after 2 rounds Lavinia; after 3 rounds Sylvia (requires `minesweeper_round_floor < 0`).
- Day 7 still allows only 1 date action / 1 date-or-ending candidate.

Special schedule validation rule (Day 4 Priscilla first): on Day 4, if Angela accepted Priscilla's solo dating invitation, the Priscilla solo date may only be added as the first sequence entry. Applies only to `day == 4`, `type == "solo"`, `friend_id == "priscilla"`. `GameState` validation MUST enforce this so UI cannot bypass. If already in slot 0, later actions may be added normally.

Group invitation rule:
- A group invitation can appear only after 3 completed Minesweeper app rounds (base = 2, so `minesweeper_round_floor <= -1`).
- Generated only if neither participant's contact was opened by Angela that day. On group days each pair member's message IS their solo invitation, so "solo invitation read" == "contact opened".
- Generation is performed inside `GameState.open_contact()` (`_maybe_generate_group_invitation`), evaluated BEFORE marking the contact opened: requires `is_group_invitation_day()`, `minesweeper_app_rounds_finished_today >= 3`, `not daily_group_invitation_generated`, the friend in a group pair, and neither pair member yet in `daily_opened_contacts`; then sets `daily_group_invitation_generated`, `daily_group_invitation_pair`, `pending_group_date_inviter_id`. The first opened contact among the pair after eligibility becomes the inviter.
- A generated group invitation suppresses individual invitations from both participants for that day.
- Reading the group offer message (NOT a separate accept/decline) makes the group date ADDABLE via `read_group_offer()` (writes the group date_unlock key); adding it to the schedule bar via `add_schedule_date_entry` is the only "accept", identical to the solo flow.
- Group date-unlock key: `"day:<day>:group:<sorted_friend_a>_<sorted_friend_b>"`. A group date counts as one scheduled date action.
- NOTE: `ending.priscilla_lavinia` requires 2 missed group dates (Day 2 + Day 6). The per-day Supportz gate / floor clamp is owned by `CONTENT.md §4` and `CONTRACTS.md §2` (`can_buy_supportz()`); do not restate the numbers here.

Unscheduled invitations:
- If Angela does not schedule an invitation before ending the day, the date is missed. On the next day, the related friend(s) may show a missed-date message.
- If a group date is unscheduled, `create_missed_group_twofriends_entry()` produces a `twofriends` entry shown after all schedule flow. The `twofriends` date also has a placeholder Minesweeper challenge. If Angela goes to hospital, show hospital first, then the twofriends dating scene if pending. On the next day, each group participant sends a missed-date/questioning message.

### Follow-up label selection (next-day beginning)
Selected when Angela opens that friend's contact DTL on day D+1. Labels: `nevermind`, solo `missed_question`, group `missed_question_<participant>`. Query via `get_missed_invitation_for_friend(friend_id, D+1)`; selection rule:
- solo `missed_question`: shown iff the returned record has `source == "solo"`.
- group `missed_question_<participant>`: shown iff `source == "group"` (a stood-up group participant sends this IN ADDITION to the `twofriends` scene). Localization key = `invitation.group.priscilla_lavinia.day{N}.{inviter}.missed_question_<participant>` (`CONTENT.md §6`).
- `nevermind`: shown iff the friend had an available solo invitation offer on day D AND `daily_opened_contacts["day:<D>:friend:<id>"] != true`.
- otherwise: the normal daily message.

`missed_invitations` (save-whitelisted) holds `Array[Dictionary]`; each record `{ "friend_id": String, "source": "solo" | "group", "day": int }` where `day` is the invitation day D (guilt appears on D+1). Populated at day-end by `advance_day_or_end()` from `collect_unscheduled_accepted_invitations_for_day_end()`. `get_missed_invitation_for_friend(friend_id, target_day)` returns the record whose `day == target_day - 1` (a copy), else `{}`. The Priscilla/Lavinia ending counter is a SEPARATE store (`missed_group_date_counts` via `create_missed_group_twofriends_entry()`). The hospital-recovery day-advance path does NOT populate `missed_invitations` (a fainting day supersedes stand-up bookkeeping).

## Date entry dictionary shapes
Shapes authoritative in `autoload/GameState.gd` (`add_schedule_date_entry`, `build_date_entry_from_unlock`, `create_missed_group_twofriends_entry`); read the `.gd`. Do not duplicate fields here.
INVARIANT (provenance only): `GameState` MUST set `advance_day_after_finish = true` on every solo/group date entry it produces; only `create_missed_group_twofriends_entry` sets `false`. The router MUST NOT read a per-entry `advance_day_after_finish` to decide the day advance (§4).
### `dating_route_state` / `inter_friend_route_state` key schema
Shapes authoritative in `autoload/GameState.gd`; read the `.gd`. `affection_tier` is NOT stored in `dating_route_state` (compute via `get_affection_tier(friend_id)`). `inter_friend_route_state` key = `"<sorted_a>_<b>"` (e.g. `"priscilla_lavinia"`).

Day-7 `ending.priscilla_lavinia` reads `missed_group_date_counts["priscilla_lavinia"]`, NOT this dict. Assertion (ending resolution; authoritative in this §2; `DIALOGIC.md §7` confirms this file owns it): for candidate `f`, `ending.<f>.true` requires `dating_route_state[f]["true_path_count"] >= 4 AND get_affection_tier(f) == "love"`; `ending.<f>.dark` requires `dating_route_state[f]["dark_points"] >= 2 AND f is the resolved Day-7 candidate.

## Invitation dictionary shape
Shape authoritative in `autoload/GameState.gd`; read the `.gd`. Key schemes (non-obvious, kept): `contact_message_unlocks`/`contact_choice_state`/`date_unlocks`/`daily_opened_contacts` = `"day:<day>:friend:<friend_id>"`; solo invitation key = `solo:<friend_id>:day:<day>`; group invitation key = `group:<sorted_a>_<sorted_b>:day:<day>` (e.g. `group:lavinia_priscilla:day:2`). Allowed invitation states: `new`, `read`, `missed`, `expired`.

## Schedule rules
Schedule bar has 7 boxes.
- Adding any action or date costs 1 motivation immediately; removing refunds 1.
- Same non-date actions can be added multiple times.
- Dating requires an accepted invitation.
- Adding a date consumes motivation immediately but does not spend money immediately.
- `validate_schedule()` simulates the schedule left-to-right.
- If removing a prior work action invalidates a later date, automatically remove invalid later date entries and refund their motivation.
- Day 1..6 max scheduled date actions: 2. Day 7 max: 1. Group date counts as 1. No duplicate date for same friend/group on same day. Cannot add any action at 0 motivation. Pressing Done with no scheduled action is valid.

`get_max_scheduled_dates_for_current_day()`: returns 2 for Day 1..6, 1 for Day 7.

Schedule action effect arrays are authoritative in `CONTENT.md §9`; do not restate here. Summary: `dating` (requires friend, no direct effect), `training` / `working` / `rest` (non-date, motivation_cost 1).

Date-entry `advance_day_after_finish`: `GameState` MUST set `true` on every solo/group date entry it produces. Only `create_missed_group_twofriends_entry` sets `false`. This per-entry field is provenance metadata only; the end-of-queue day advance is governed by the queue-level `pending_date_advance_day_after_finish` (§4). The router MUST NOT read a per-entry `advance_day_after_finish` to decide the day advance.

## Minesweeper app round model (authoritative numbers)
Angela starts each day with **2 base app rounds**. Visible display is a base-round debt display. Visible range: `-3..2`. Visible maximum: `2`. Internal playable rounds: `2..5`.
`total_playable_rounds = MINESWEEPER_BASE_ROUNDS - minesweeper_round_floor` (floor 0 → 2, -1 → 3, -2 → 4, -3 → 5).

Signed-display formula (contract; `StatHud` and `TESTING.md` Minesweeper round-floor tests depend on it):
- `get_minesweeper_display_rounds_left() -> int` returns `minesweeper_rounds_left` clamped to `[-3, 2]`. `minesweeper_rounds_left` legitimately goes negative once Supportz lowers the floor below 0.
- `get_minesweeper_display_rounds_max() -> int` returns `MINESWEEPER_DISPLAY_MAX` (always `2`). The denominator NEVER changes with Supportz.
- Display string: `LocalizationManager.t("hud.minesweeper_rounds", {"remaining": get_minesweeper_display_rounds_left(), "max": get_minesweeper_display_rounds_max()})` → `Minesweeper: {remaining}/{max}`.
- `get_minesweeper_safety_level() -> int`: `1` default; `2` if `inventory.has("lucky_charm")`; `3` if `inventory.has("debug_key")` (debug_key overrides lucky_charm). Does NOT change the visible round display. Phase 6 effects: `2` halves `extra_mines` (floor, min 0) + expands first-click safe region to 3×3; `3` sets `extra_mines = 0` + auto-flags one confirmed mine. Phases 0–5 ignore safety_level beyond display.

Assertion examples (day start `rounds_left = 2`, `floor = 0`): no Supportz `2/2 → 1/2 → 0/2` (3rd blocked); 1 Supportz (`floor -1`) `2/2 → 1/2 → 0/2 → -1/2` (4th blocked); 3 Supportz (`floor -3`) `2/2 → … → -3/2` (6th blocked).

`reset_game()` sets `minesweeper_round_floor = 0`, `minesweeper_rounds_left = 2`, `minesweeper_rng_seed = randi()` (fresh PRNG seed for Phase 6; persisted in saves). `_begin_new_day()` sets `minesweeper_rounds_left = 2`, `unfinished_minesweeper_result = {}`, `minesweeper_app_rounds_finished_today = 0`, `minesweeper_money_earned_today = 0`. `minesweeper_round_floor` persists across days; resets only on new game.

Default `minesweeper_selected_difficulty = "beginner"`. Starting an app round costs 1 motivation and 1 app round; blocked if motivation == 0, `minesweeper_rounds_left <= minesweeper_round_floor`, or `unfinished_minesweeper_result` is not empty. `start_minesweeper_app_round(difficulty)` is the ONLY UI entry point; it performs the guards then calls `consume_minesweeper_app_round()` (UI MUST NOT call `consume_minesweeper_app_round()` directly).

Finishing an app round (requires `result["context"] == "app"`): clears unfinished state, increments `minesweeper_app_rounds_finished_today`, calculates/applies money, claims one-time task rewards, applies `result["effect_ids"]` through `EffectResolver`, emits signals. Exploded rounds still reward money. Dating challenge results (`context != "app"`) never reward app money.

Daily money cap: `108 + 54 * max(0, total_playable_rounds - 2)`. Applied reward must not exceed the remaining daily cap. The cap uses internal total playable rounds, not the visible denominator.

### Minesweeper RNG seed (authoritative)
`GameState.minesweeper_rng_seed: int` is the single source of board randomness for Phase 6. `reset_game()` initializes to `randi()`; persists across days via the save whitelist. Phase 6 MUST seed its PRNG from `minesweeper_rng_seed` and advance deterministically per generated board. Placeholder phases 0–5 ignore the seed.

Supportz lowers `minesweeper_round_floor` by -1 per purchase (clamp -3..0).

## Boundary Dictionary catalogue
Every `Dictionary` that crosses a module/flow boundary is listed with its authoritative definition. Use only the listed fields; MUST NOT add unlisted fields that affect logic.

| Dictionary | Authoritative definition |
| --- | --- |
| `execute_schedule_sequence_until_route_needed()` return | CONTRACTS §2 (above) |
| `should_warn_minesweeper_before_schedule_done()` return | CONTRACTS §2 (above) |
| `resolve_day7_ending()` return | CONTRACTS §2 (above) |
| Date-entry (solo / group / twofriends) | CONTRACTS §2 (above) |
| Invitation dictionary | CONTRACTS §2 (above) |
| `dating_route_state` / `inter_friend_route_state` value | CONTRACTS §2 (above) |
| Minesweeper **app round result** | CONTRACTS §2 (below) |
| `unfinished_minesweeper_result` | CONTRACTS §2 (below) |
| Dating challenge result | FLOWS §6 (challenge-result Dictionary schema) |
| Save dictionary | CONTRACTS §6 (below) |

### Minesweeper app round result Dictionary — authoritative schema
`finish_minesweeper_app_round(result)` MUST receive a `Dictionary` with AT LEAST:
```gdscript
{
    "context": "app",                # REQUIRED; MUST equal "app". Dating challenges use "dating".
    "difficulty": String,            # "beginner" | "intermediate" | "expert"
    "outcome": String,               # "exploded" | "cleared" | "perfect" | "no_flag" | "foresight"
    "effect_ids": Array,             # whitelisted effect IDs via EffectResolver (MAY be empty)
    "task_ids": Array,               # claimed MinesweeperTaskData ids, e.g. ["complete_beginner","perfect_beginner"]
    "three_bv": int,                 # board 3BV; used only for foresight-rate display
    "click_count": int               # total clicks (used only for foresight rate display)
}
```
`calculate_minesweeper_money_reward(result)` / `apply_minesweeper_money_reward(result)` read `outcome` + `difficulty` + `task_ids`. `EffectResolver.apply_effect_ids(result["effect_ids"])` runs only after rewards; a dating challenge (`context != "app"`) MUST NOT reach this method for app money. `check_and_claim_minesweeper_task_rewards(result)` reads `task_ids`; each id claimed once (cap 9 total, `CONTENT §8`).

### `unfinished_minesweeper_result` shape (transient, NEVER saved)
```gdscript
{ "context": "app", "difficulty": String, "started_at_unix": int }
```
Excluded from `to_save_dict()`; cleared on day reset.

## Save methods
`to_save_dict()` returns JSON-safe whitelisted state only. `apply_save_dict(data)` safely validates and applies whitelisted state only. Whitelisted fields are authoritative in `GameState._SAVE_WHITELIST` (the runtime-enforced list used by `to_save_dict()` / `apply_save_dict()`). Never execute data from save; never instantiate classes from save; never call arbitrary methods from save; never save Nodes/Objects/Callables/Resources/live references.

### `DataCatalog` required interface (15 read-only methods)
`res://scripts/data/DataCatalog.gd` (`class_name DataCatalog`, `extends RefCounted`). Pure data source; no gameplay logic, no `GameState` mutation. All methods safe, return copies/values (never live references):
```
get_friend_ids() -> Array[String]
get_friends() -> Dictionary
get_friend(friend_id: String) -> Dictionary
get_shop_items() -> Array
get_shop_item(item_id: String) -> Dictionary
get_schedule_actions() -> Array
get_schedule_action(action_id: String) -> Dictionary
get_minesweeper_tasks() -> Array
get_minesweeper_task(task_id: String) -> Dictionary
get_daily_contact_message_order(target_day: int = -1) -> Array[String]
get_contact_message_order_or_fallback(target_day: int = -1) -> Array[String]
get_invitation_days() -> Dictionary
get_invitation_days_for_friend(friend_id: String) -> Array[int]
get_group_invitation_days() -> Array[int]
get_group_invitation_pairs() -> Array[Array]
```
Invariant: `get_daily_contact_message_order(d)` MUST equal `CONTENT.md §5` for d in 1..7; `get_invitation_days()` MUST equal `CONTENT.md §4` solo rows. `GameState` calls these read-only; it must never pass `DataCatalog` into effect execution.

---

# 3. EffectResolver

`res://autoload/EffectResolver.gd` (extends `Node`). Applies whitelisted effect IDs only, via two-pass validation. No `eval`, no dynamic arbitrary method calls, no resource/save-executed logic. Normalize (trim + lowercase) before validating/applying.

## Rules
- Validate ALL IDs before applying any. If any unknown ID exists: `push_warning`; apply nothing; return false.
- If all known: apply through safe `GameState` public methods only.

## Required known effects
- Pressure: `pressure:+1` `+2` `+3` `+4` `-1` `-2` `-3` `-4`
- Health: `health:+1` `+2` `+3` `+4` `-1` `-2` `-3` `-4`
- Motivation: `motivation:+1` `-1`
- Money positive: `money:+1` `+5` `+6` `+9` `+10` `+12` `+20` `+27` `+30` `+45` `+54`
- Money negative: `money:-5` `-10` `-15` `-20` `-25` `-30` `-35` `-40` `-45`
- Coins: `coin:+1` `-1` `-2` `-3`
- Inventory: `inventory:add:pineapple_bun` `inventory:add:quiet_tea` `inventory:add:lucky_charm` `inventory:add:debug_key` `inventory:add:priscilla_gift` `inventory:add:lavinia_gift` `inventory:add:sylvia_gift`
- Affection: `affection:<priscilla|lavinia|sylvia>:+1` `+2` `-1`
- Friend attitudes (allowed: `impressed` `amused` `concerned` `upset` `mad` `lovely`): `friend_attitude:<friend>:<attitude>`
- Inter-friend affection: `inter_friend_affection:priscilla:lavinia:+1|-1` and the `lavinia:priscilla` mirror.
- Minesweeper: `minesweeper:max_rounds:+1` (legacy alias for `minesweeper:round_floor:-1`). Both MUST use safe `GameState.change_minesweeper_round_floor(-1)` only; never mutate `minesweeper_round_floor` / `minesweeper_rounds_left` directly.

---

# 4. SceneRouter

`res://autoload/SceneRouter.gd` (extends `Node`). Scene paths:
- Menu: `res://scenes/menu/MenuScene.tscn`
- Opening: `res://scenes/opening/OpeningScene.tscn`
- Main: `res://scenes/main/MainGameScene.tscn`
- Ending: `res://scenes/ending/EndingScene.tscn`
- Hospital: `res://scenes/hospital/HospitalScene.tscn`
- Dating: `res://scenes/dating/DatingScene.tscn`

## Behavior
`start_game_from_menu`:
1. `GameState.reset_game()`.
2. If Day 1 and `opening_seen` is false, route `OpeningScene`.
3. Otherwise route `MainGameScene`.

`goto_dating_entries(entries)`: MUST call `GameState.prepare_dating_entries(entries)` (populates `pending_date_entries` / `pending_date_entry_index` / `pending_date_friend_id`; sets `pending_date_advance_day_after_finish = true`), then starts `DatingScene`. `DatingScene` reads via `get_current_pending_date_entry()`.

`finish_current_dating_and_route`:
1. `GameState.advance_date_queue_or_day()` exactly once.
2. If it returns `true` (more entries remain), route the next `DatingScene` using the already-advanced index; do not change scenes via `GameState`.
3. If `false`: clear pending date state and clear the schedule without refund. `advance_date_queue_or_day()` has already performed the day transition when `pending_date_advance_day_after_finish == true` (or resolved the ending via `route_context["ending_id"]`), and left the day unchanged when `false`. Then: if `route_context.get("ending_id","") != ""` → `goto_ending()`; else `goto_main()`.
INVARIANT: `finish_current_dating_and_route` MUST NOT call `advance_day_or_end()` directly. The single day-advance happens only inside `advance_date_queue_or_day()` when the queue is exhausted AND `pending_date_advance_day_after_finish == true`.

`goto_ending()` takes no parameter; reads `GameState.route_context["ending_id"]`; empty/unknown falls back to `"alone"`.

## Dating queue ownership (single division of labor)
- `GameState.prepare_dating_entries(entries)` is the PRIMARY setup path (called by `SceneRouter.goto_dating_entries`). Populates `pending_date_entries` / `pending_date_entry_index` / `pending_date_friend_id`, sets `pending_date_advance_day_after_finish = true` (default: a normal end-of-day queue advances the day exactly once when it finishes).
- `GameState.pending_date_advance_day_after_finish: bool` is the SINGLE governing flag for the end-of-queue day advance. `true` for every normal end-of-day queue (set by `prepare_dating_entries`); the day advance happens exactly once inside `advance_date_queue_or_day()` when the queue is exhausted and the flag is `true`.
- `GameState.prepare_dating_queue(friend_ids)` is a CONVENIENCE wrapper: builds entries via `build_date_entry_from_unlock(friend_id)` for each id, delegates to `prepare_dating_entries`. Adds no separate queue state.
- `GameState.advance_date_queue_or_day()` is STATE-ONLY: advances `pending_date_entry_index`, returns `true` while more entries remain. When none remain it calls `advance_day_or_end()` ONLY IF `pending_date_advance_day_after_finish == true`; otherwise leaves the day unchanged. MUST NOT change scenes.
- `SceneRouter.finish_current_dating_and_route()` is the ROUTING owner: decides the next scene using `advance_date_queue_or_day()` for the state transition. Scene changes happen ONLY here, never inside `GameState`.

SceneRouter must not apply stat/economy/affection rules directly.

---

# 5. LocalizationManager

`res://autoload/LocalizationManager.gd` (extends `Node`). Supported locales: `en`, `zh_CN`, `zh_HK`. Current locale stored in `GameState.settings["language"]`. Missing keys return `[missing:key]`, `push_warning` once per key, do not crash.

UI text rule: do not hardcode final user-facing text in UI scripts; use `LocalizationManager.t("key")` with `params` for dynamic text. Visible UI refreshes on `locale_changed`.

Locale write path: `set_locale(locale)` MUST delegate to `GameState.set_language(locale)` and MUST NOT store the locale anywhere else. `GameState.settings["language"]` is where the locale is stored. On success emits `locale_changed(locale)`; `GameState` emits `language_changed`. Reading the current locale goes through `GameState.settings["language"]`, not a separate field.

---

# 6. SaveManager

`res://autoload/SaveManager.gd` (extends `Node`). Save folder: `user://saves/`. Autosave `user://saves/autosave.json`, quick `user://saves/quick.json`, slots `slot_1.json`..`slot_7.json`. Do not create `slot_8.json` / `slot_9.json`.

Use only primitive JSON-safe data (Dictionary, Array, String, int, float, bool, null). Do not save live Nodes, Callable, Object references, arbitrary Resources, scripts/classes from save data.

Save data preserves only the fields in `GameState._SAVE_WHITELIST` (the single authoritative, runtime-enforced whitelist used by `to_save_dict()` / `apply_save_dict()`). `SaveManager` serializes `GameState.to_save_dict()` and never maintains its own copy.

> `minesweeper_rng_seed` is included in `GameState._SAVE_WHITELIST` (persists across save/load per Phase-6 deterministic-board contract).
> `post_ending_queue` is saved by the whitelist; reserved/opaque (§2), needs no behavior. (`pending_date_queue` / `pending_date_index` were removed — superseded by `pending_date_entries` / `pending_date_entry_index`.)

Transient / NOT saved: `unfinished_minesweeper_result`. Any Node/Object/Callable/Resource/live reference is never serialized.

## Save dictionary shape
`{ "schema_version": int, "kind": String, "slot_id": int, "saved_at_unix_time": int, "scene_id": String, "route_context": Dictionary, "summary": Dictionary, "game_state": Dictionary }`.

## Load behavior
Read `schema_version`; if higher than `SAVE_SCHEMA_VERSION` (future build) or data malformed, reject safely without crashing. Otherwise `migrate_save_dict(data)` forward to current `SAVE_SCHEMA_VERSION` (chained by version), then apply only whitelisted fields to `GameState`; never crash from missing/corrupt save files. After a successful load, route through `SceneRouter` based on `scene_id` and `route_context`: if `route_context.get("ending_id","")` is a non-empty valid ending id → `EndingScene`; else if `day` 1..7 → `MainGameScene`; else `EndingScene`. Quick save allowed in `MainGameScene` and desktop apps; quick load must show confirmation in UI unless test code calls directly. Load routing always resolves to `EndingScene`/`MainGameScene`; never resumes an in-progress dating queue.

> **REQUIRED GUARD (implemented):** `SaveManager.apply_save_dict()` clears `pending_date_*` on load via `GameState.clear_pending_date_state()` unless the saved `scene_id == "dating"`. Prevents a mid-queue save from restoring stale `pending_date_*` with no consumer. Implemented; do not reintroduce stale mid-queue state.

---

# 7. InputManager and FocusGrid

`res://autoload/InputManager.gd` (extends `Node`). `res://scripts/ui/FocusGrid.gd` also created.

## Required actions
`ui_accept`, `ui_cancel`, `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_focus_next`, `ui_focus_prev`, `game_quick_save`, `game_quick_load`, `game_open_log` (reserved; no flow binding), `game_skip_text`, `game_toggle_auto`, `game_hint`, `game_new_board`, `game_close_window`, `game_next_tab`, `game_prev_tab`, `game_page_next`, `game_page_prev`, `game_open_settings`, `game_open_schedule`, `game_open_contacts`.

## Input rules
Do not hardcode keyboard-only logic in UI scripts; use input actions. Every clickable Button must be keyboard/controller focusable unless intentionally decorative (`focus_mode = Control.FOCUS_ALL`). Each scene calls `InputManager.focus_first_control(self)` after building UI (usually deferred). Icon grids define focus neighbors through `FocusGrid.gd`. On controller input, show focus ring strongly. Right-click removal must have controller/keyboard alternatives.

Minesweeper board grid navigation (Phase 6) is a focused-cell model, not app-icon `FocusGrid`: directional actions move the focused cell, `ui_accept` reveals, `game_hint` flags, a chord action chords, and `BoardScroll` auto-scrolls to the focused cell. Concrete scheme owned by `PHASES.md §7`.

---

# 8. AccessibilityManager and helpers

`res://autoload/AccessibilityManager.gd` (extends `Node`). Helpers: `res://scripts/ui/AccessibleButton.gd`, `res://scripts/ui/LocalizedText.gd`, `res://scripts/ui/SafeImage.gd`.

## Settings stored in `GameState.settings`
```gdscript
{ "music_volume":float, "voice_volume":float, "text_speed":float, "auto_text_speed":float,
  "fullscreen":bool, "language":String, "font_scale":float, "high_contrast":bool,
  "reduced_motion":bool, "screen_shake_strength":float, "large_click_targets":bool,
  "hold_to_confirm":bool, "colorblind_mode":String, "show_focus_ring":bool,
  "controller_cursor_enabled":bool, "skip_unseen_text_allowed":bool, "auto_advance_dialogue":bool,
  "subtitles_enabled":bool, "captions_enabled":bool, "subtitle_speaker_names":bool,
  "subtitle_background_opacity":float, "text_box_opacity":float, "visual_audio_cues":bool,
  "flashing_effects_enabled":bool, "tutorial_replay_available":bool, "pause_on_focus_loss":bool,
  "sfx_volume":float, "ambience_volume":float, "mute_audio_on_focus_loss":bool }
```
`pause_on_focus_loss` is a persisted settings key; its wiring is optional/no-op does not violate any contract. `mute_audio_on_focus_loss` is the only focus-loss behavior `AudioManager` MUST honor.

Recommended defaults: music_volume 0.8, voice_volume 0.8, text_speed 1.0, auto_text_speed 1.0, fullscreen false, language `en`, font_scale 1.0, high_contrast false, reduced_motion false, screen_shake_strength 0.5, large_click_targets false, hold_to_confirm false, colorblind_mode `none`, show_focus_ring true, controller_cursor_enabled false, skip_unseen_text_allowed false, auto_advance_dialogue false, subtitles_enabled true, captions_enabled true, subtitle_speaker_names true, subtitle_background_opacity 0.85, text_box_opacity 0.90, visual_audio_cues true, flashing_effects_enabled false, tutorial_replay_available true, pause_on_focus_loss true, sfx_volume 0.8, ambience_volume 0.65, mute_audio_on_focus_loss false.

## Accessibility acceptance criteria
All important dialogue readable as text; important sound cues also have visual cues; no essential info conveyed by color alone (every color status also includes text/icon/pattern/symbol); dialogue self-paced unless auto enabled and interruptible; skip respects `skip_unseen_text_allowed`; destructive actions require confirmation; focus ring visible on controller/keyboard; every gameplay button has keyboard/controller alternative; right-click actions have alternatives; large click target mode enforces minimum `custom_minimum_size`; reduced motion disables nonessential animation/fades/shake/flashing; psychological horror must not depend on strobing/flicker; any flashing effect disabled by default unless approved.

Secret Supportz accessibility: Supportz may be visually transparent but must keep an accessible/focus label (`shop.secret_supportz.accessible_name`); if `show_focus_ring`/`high_contrast`, show a subtle outline while focused. If made completely invisible and unfocusable, write the conflict into `ResultReport.md`.

---

# 9. AudioManager, AudioManifest, and audio resources

`res://autoload/AudioManager.gd` (extends `Node`). `res://scripts/data/AudioManifest.gd`, `res://scripts/resources/BgmTrackData.gd`, `res://scripts/resources/AudioCueData.gd` also created. No hard audio dependency; the prototype runs without audio files.

`GameState` audio additions: signal `audio_state_changed(result: Dictionary)`; `var audio_state: Dictionary` default `{ "current_bgm_id":"", "current_ambience_id":"", "current_context_id":"", "current_context":{}, "music_muted":false }`. Volume keys live in `GameState.settings` (§8). Methods: `set_audio_state_value`, `get_audio_state_value`, `get_audio_state_save_dict`, `apply_audio_state_save_dict`. `reset_game()` resets `audio_state` to default; `to_save_dict()` includes it; `SaveManager` whitelist includes it.

Implementation rules: persistent AudioStreamPlayer nodes; crossfade support; missing track path MUST NOT crash, returns `{ "ok":false, "reason":"missing_audio", "track_id":track_id, "path":path }`; do not save players/resources; do not execute audio metadata; no `eval`. Context IDs (per-app context values bound in `FLOWS.md §8`): `menu`, `opening`, `tutorial`, `main_desktop`, `contacts`, `minesweeper`, `shop`, `schedule`, `backup`, `settings`, `dating`, `dating_challenge`, `dating_dark_path`, `dating_true_path`, `hospital`, `ending`. `FLOWS.md §8` uses only these context IDs. Reconciliation notes:
- `contacts` context resolves to the `contacts_soft` track (prototype). `contacts_soft` is a track id, NOT a context id.
- `dating` accepts context params `mood` (`"mad"` etc.), `route_type` (`"solo"`/`"group"`/`"twofriends"`), `friend_id(s)`, `day`. These are NOT separate context ids.
- `desktop_night_uncertain` is a BGM track only, not a context id.
Context dictionaries are JSON-safe and may include `friend_id`, `friend_ids`, `mood`, `day`, `pressure`, `health`, `motivation`, `attitude`, `route_type`, `challenge_phase`, `ending_id`.

Scene integration rules (full mapping in `FLOWS.md` audio section): scenes call `AudioManager.set_music_context(...)` on ready/open; never crash if AudioManager missing; `MainGameScene` refreshes context on danger-stat change without spamming; `ComputerDesktop` returns to `main_desktop` when hiding an app; `MinesweeperChallengeOverlay` switches to `dating_challenge`/`dating_dark_path`/`dating_true_path`; `HospitalScene` → `hospital`; `EndingScene` resolves `ending_id` then sets context.

AudioManifest required methods: `get_expected_audio_paths()`, `get_bgm_tracks()`, `get_audio_cues()`, `get_path(category, id)`, `has_track(track_id)`, `get_track_data(track_id)`, `get_missing_audio_paths()`. Always `ResourceLoader.exists(path)` before loading; missing audio MUST NOT crash, reported in `ResultReport.md`.

BgmTrackData / AudioCueData: both `extend Resource` with `class_name`; exported fields per `DIALOGIC.md`/original spec (id, display_name, localization_key, path, category, mood_tags, loop, volumes, fades, priority, fallback_track_id, description_key; cue adds bus). Allowed BGM categories: `menu opening desktop app chat tutorial backup settings contacts schedule shop minesweeper dating challenge dark_path true_path hospital ending group`. Allowed cue categories: `sfx ui voice stinger ambience`.

Accessibility and audio: no essential info conveyed by music alone; horror tension may support mood but required gameplay info must also be text/icon/status; if `visual_audio_cues` enabled, important audio cues have a visible label; `mute_audio_on_focus_loss` may mute while unfocused.

---

# 10. DialogicBridge

`res://autoload/DialogicBridge.gd` (extends `Node`). Owns all direct interaction with Dialogic. Full requirement in `DIALOGIC.md`; API contract here. Signals and method signatures authoritative in the `.gd`.

Allowed marker style ONLY:
```dtl
do DialogicBridge.timeline_marker("safe_marker_id")
```
Validate `safe_marker_id` against a whitelist; unknown markers ignored safely with `push_warning`. Gameplay state changes stay in scene scripts via safe `GameState` methods or `EffectResolver` with known effect IDs. No `eval`; no arbitrary gameplay effects from DTL; no `GameState` method calls by name; no save/resource method execution; validate timeline IDs against the manifest; return safe error dictionaries for unknown IDs / missing files / missing Dialogic.

---

# 11. Required scene / script / autoload paths (authoritative list)

This section is the path list the smoke test (`tests/smoke_load_scenes.gd`) MUST load. Autoload script paths and load order are in §1.

## Autoload scripts
See §1 (nine paths, authoritative load order).

## Scene `.tscn` paths
- `res://scenes/menu/MenuScene.tscn`
- `res://scenes/menu/GalleryScene.tscn`
- `res://scenes/menu/Setting.tscn`
- `res://scenes/opening/OpeningScene.tscn`
- `res://scenes/main/MainGameScene.tscn`
- `res://scenes/desktop/ComputerDesktop.tscn`
- `res://scenes/apps/MinesweeperApp.tscn`
- `res://scenes/apps/ContactListApp.tscn`
- `res://scenes/apps/ShopApp.tscn`
- `res://scenes/apps/ScheduleApp.tscn`
- `res://scenes/apps/SettingsApp.tscn`
- `res://scenes/apps/LogOutApp.tscn`
- `res://scenes/apps/BackupApp.tscn`
- `res://scenes/overlay/TutorialOverlay.tscn`
- `res://scenes/ending/EndingScene.tscn`
- `res://scenes/hospital/HospitalScene.tscn`
- `res://scenes/dating/DatingScene.tscn`
- `res://scenes/dating/MinesweeperChallengeOverlay.tscn`
- `res://scenes/shared/BoxMeter.tscn`
- `res://scenes/shared/StatHud.tscn`
- `res://scenes/shared/AppWindowBase.tscn`
- `res://scenes/shared/IconButton.tscn`
- `res://scenes/shared/ContactBox.tscn`
- `res://scenes/shared/ChatBubble.tscn`
- `res://scenes/shared/ShopItemBox.tscn`
- `res://scenes/shared/ScheduleEntryBox.tscn`
- `res://scenes/shared/SaveSlotRow.tscn`
- `res://scenes/shared/DialogueBox.tscn`

## Data / helper / resource scripts
- `res://scripts/data/DialogicTimelineCatalog.gd` (DIALOGIC §10)
- `res://scripts/data/DataCatalog.gd` (§2 interface above)
- `res://scripts/data/ArtManifest.gd` (CONTENT §11)
- `res://scripts/data/AudioManifest.gd` (CONTENT §13)
- `res://scripts/ui/FocusGrid.gd` (§7)
- `res://scripts/ui/AccessibleButton.gd` (§8)
- `res://scripts/ui/LocalizedText.gd` (§8)
- `res://scripts/ui/SafeImage.gd` (§8)
- `res://scripts/resources/StatValue.gd` (CONTENT §10)
- `res://scripts/resources/FriendData.gd`
- `res://scripts/resources/ChatMessageData.gd`
- `res://scripts/resources/InvitationData.gd`
- `res://scripts/resources/ScheduleActionData.gd`
- `res://scripts/resources/ShopItemData.gd`
- `res://scripts/resources/EffectData.gd`
- `res://scripts/resources/MinesweeperTaskData.gd`
- `res://scripts/resources/BgmTrackData.gd` (§9 — MUST add if absent)
- `res://scripts/resources/AudioCueData.gd` (§9 — MUST add if absent)

## Test scripts
- `res://tests/smoke_load_scenes.gd`
- `res://tests/smoke_dialogic_timelines.gd` (DIALOGIC §11 — future)
- `res://tests/unit/test_game_state.gd`
- `res://tests/unit/test_effect_resolver.gd`
- `res://tests/unit/test_schedule_rules.gd`
- `res://tests/unit/test_minesweeper_rewards.gd`
- `res://tests/unit/test_localization.gd`
- `res://tests/unit/test_save_manager.gd`
- `res://tests/unit/test_input_accessibility.gd`
- `res://tests/unit/test_shop_rules.gd`
- `res://tests/unit/test_audio_manager.gd`
