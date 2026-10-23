# FLOWS — Game and runtime flows

Ordered sequencing of the `CONTRACTS.md` APIs, plus required scene node-trees. Other files document the pieces; the ordered flow lives here.

---

# 1. Master game flow
```
MenuScene
  └─ New Acc ─▶ GameState.reset_game() ─▶ SceneRouter.start_game_from_menu()
        ├─ Day 1 & opening not seen ─▶ OpeningScene ─▶ MainGameScene
        └─ MainGameScene (Angela panel left, Computer desktop right)
              ├─ Day 1 & tutorial not seen ─▶ TutorialOverlay
              ├─ ComputerDesktop apps: Minesweeper, Contacts, Schedule, Shop, Settings, Log Out, Backup
              ├─ ScheduleApp Done ─▶ Schedule Done flow (§2)
              └─ Day 7 finished ─▶ EndingScene
```

---

# 2. Schedule Done flow (single mental model)
0. **Day 7 ending branch:** If `GameState.day == 7`, do NOT run steps 2–4. Call `GameState.resolve_day7_ending()`, store `route_context` on `GameState`, route `SceneRouter.goto_ending()`. Day 7 does not push the Minesweeper unfinished warning and does not force remaining app rounds. `resolve_day7_ending()` does NOT autosave. The immediate CALLER autosaves once, right after: `ScheduleApp` on the Day-7 Done path, `apply_hospital_recovery_and_advance_day()` on the Day-7 hospital branch. Single owner of the Day-7 autosave = the caller of `resolve_day7_ending()` (prevents double-write). Both Day-7 ending entry points resolve from the CURRENT schedule state (`CONTRACTS.md §2`). A Day-7 danger state without `sequela` never hospitalizes (`CONTRACTS.md §2` danger-without-sequela). `resolve_day7_ending()` sets `day = 8` as a terminal sentinel (`CONTRACTS.md §2`); this is load-bearing and an agent reading only this flow must not miss it.
1. Reentry guard (`_done_pressed`).
2. `GameState.should_warn_minesweeper_before_schedule_done()` → if `should_warn` true, show `MinesweeperWarningAlert`, do NOT execute.
3. Else `GameState.validate_schedule()`.
4. `GameState.execute_schedule_sequence_until_route_needed()` → returns the routing `Dictionary` (contract in `CONTRACTS.md §2`).
5. Route via `SceneRouter` only: hospital / dating / twofriends / advance / ending.

After the day advances, `SaveManager.autosave()` runs. (The Day-7 ending paths perform their own explicit autosave.)

---

# 3. Minesweeper Schedule Done warning
`ScheduleApp` MUST call `GameState.should_warn_minesweeper_before_schedule_done()` before executing Done. Full boolean contract + return keys in `CONTRACTS.md §2`.

Alert buttons:
- Close: hide alert only.
- Go / Yes: `clear_schedule_with_refund()`, hide `ScheduleApp`, open `MinesweeperApp`.

Do not use `clear_schedule_without_refund()` for this alert. Do not execute schedule effects while the alert is shown. Do not advance the day while the alert is shown. On Day 7, Done routes to ending and does NOT push this warning or force remaining app rounds.

---

# 4. Minesweeper app round + notification flow
Only **app** rounds consume motivation and app rounds. Dating challenge Minesweeper does not consume motivation and does not consume app rounds.

Starting an app round: 1 motivation + 1 app round; blocked if motivation == 0, `minesweeper_rounds_left <= minesweeper_round_floor`, or `unfinished_minesweeper_result` is not empty. Starting does not alter the floor.

Finishing an app round (`context == "app"`): clears unfinished state, increments `minesweeper_app_rounds_finished_today`, calculates/applies money, claims task rewards, applies `result["effect_ids"]` through `EffectResolver`, emits signals. Exploded rounds still reward money. Dating challenge results never reward app money. App result Dictionary schema in `CONTRACTS.md §2`.

**Real-time faint check.** After `finish_minesweeper_app_round(result)` applies rewards/effects, `MinesweeperApp` MUST call `GameState.check_immediate_faint()`. If true, route immediately to `SceneRouter.goto_hospital()` and abandon the app (rewards were already applied; abandoned boards are safe per §3). `ShopApp` MUST do the same immediately after applying a purchase's `effect_ids` (`CONTENT.md §7`).

**Faint check precedes the notification (ordering invariant).** On a finished app round, `check_immediate_faint()` is evaluated BEFORE `ComputerDesktop` evaluates the new-message notification. If the faint check routes to `HospitalScene`, the new-message notification MUST NOT be shown (the desktop is being torn down; do not pop a notification against a replaced scene). `ComputerDesktop` evaluates/shows the notification only on the no-faint path.

Clearing unfinished round: no refund, no count, no reward, no notification, never unlocks friend messages.

**New-message notification** (owned by `ComputerDesktop`): appears only
- after the first finished app round of the current day,
- after the second finished app round of the current day,
- after the third finished app round of Day 7, but ONLY if `minesweeper_round_floor < 0`,
- and only if a solo friend message/invitation becomes available.

Does NOT appear for the third-or-later finished round (except Day 7 above), for dating challenges, for incomplete/abandoned boards, or if no friend message becomes available. Friend selection: `GameState.get_daily_message_friend_for_finished_round(round_number, target_day)`; first → first daily solo friend, second → second, Day-7 third → third (only if floor < 0). If a group invitation suppressed solo invitations that day, do not show a solo notification for suppressed contacts. Buttons: Close (hide only); Go / Yes (hide MinesweeperApp, open ContactListApp, open the correct friend via safe method, hide notification).

Group-invitation silence: a group invitation for the `priscilla_lavinia` pair may appear only after 3 completed app rounds (requires `minesweeper_round_floor <= -1`). The third finished round produces a new-message notification ONLY on Day 7, so Day 2 / Day 6 group eligibility is intentionally silent. Consequence: `ending.priscilla_lavinia` needs 2 missed group dates (Day 2 + Day 6); the per-day Supportz gate is owned by `CONTENT.md §4` (`CONTRACTS.md §2` `can_buy_supportz()`).

---

# 5. Invitation flow (contact opening)
When a contact is opened:
1. `ContactListApp` calls `GameState.open_contact(friend_id)`.
2. `ContactListApp` asks `GameState` what message state is available.
3. `ContactListApp` selects a safe timeline ID from `DialogicTimelineCatalog` (`DIALOGIC.md`).
4. `ContactListApp` starts the timeline through `DialogicBridge`.
5. `ContactListApp` does not mutate dictionaries directly.

Opening a contact before a date-unlocking message exists MUST NOT create a schedule date. Daily messages and reply choices may apply whitelisted effects. Group invitation: the first opened contact among the pair after eligibility becomes the inviter; a generated group invitation suppresses individual invitations from both participants for that day.

Reading a solo OR group dating offer message makes that date ADDABLE in `ScheduleApp` (appears as an invitation date button); NOT auto-added. There is no separate accept/decline — adding the date to the schedule bar via `add_schedule_date_entry` is the only "accept". For solo, the unlock is `date_unlocks["day:<day>:friend:<friend_id>"]` (set by `choose_contact_option`); for group, `date_unlocks["day:<day>:group:<sorted pair>"]` (set when the group offer is read). `generate_group_invitation(friend_id)` is called by `open_contact` when eligible and sets `daily_group_invitation_generated` / `daily_group_invitation_pair` / `inviter_id`.

## 5.1 Group reply-order (owned by `GameState.choose_contact_option`, `CONTRACTS.md §2`)
When a group invitation for pair `priscilla_lavinia` is generated on Day 2 or Day 6, the **inviter** is the first contact opened by player. State key consulted: `contact_choice_state["day:<day>:friend:<friend_id>"]` (set once that friend has replied). `need_reply_<non_inviter>_first` text is the player-facing warning only; the rule above is the machine-enforced gate. Day 2 and Day 6 mirror. No other flow may mutate `contact_choice_state` directly.

---

# 6. Dating / hospital / ending flow
`DatingScene` loads the current entry from `GameState.get_current_pending_date_entry()`. Supports solo / group / twofriends. For each date entry: start pre-challenge timeline → show `MinesweeperChallengeOverlay` → overlay emits `challenge_finished(result)` → `DatingScene` calls `GameState.apply_dating_challenge_result(entry, result)` ONLY (never `finish_minesweeper_app_round`) → start post-challenge timeline → call `SceneRouter.finish_current_dating_and_route()`.

`MinesweeperChallengeOverlay` result MUST set `result["context"] = "dating"`. Dating challenge does not consume motivation or app rounds.

## Challenge-result `Dictionary` schema (authoritative here)
`MinesweeperChallengeOverlay` emits `challenge_finished(result)` with `result` containing AT LEAST:
```gdscript
{
    "context": "dating",            # REQUIRED; never "app"
    "path": "sweet" | "dark" | "true",
    "affection_delta": int,         # one of -1, 0, +1, +2
    "dark_point": int,              # 1 if path == "dark", else 0
    "entered_true_path": bool,      # path == "true"
    "board_performance": Dictionary # OPTIONAL; Phase 6 real-board metrics; placeholder sends {}
}
```
Button mapping (overlay): normal result buttons → `path="sweet"`, `dark_point=0`; dark mine buttons → `path="dark"`, `dark_point=1`; perfect true-path button → `path="true"`, `dark_point=0`, `entered_true_path=true`. Affection delta from the mine-affection selector (-1/0/+1/+2).

`apply_dating_challenge_result(entry, result)` MUST, via safe `GameState` methods only:
- Resolve Angela's participants by entry `type`: `solo` ⇒ `[entry["friend_id"]]`; `group` ⇒ `entry["friend_ids"]` (BOTH receive Angela's effect); `twofriends` ⇒ `[]` (Angela ABSENT: do NOT change Angela's affection, do NOT touch `dating_route_state`).
- For EACH Angela participant `p`: `change_affection(p, result["affection_delta"])`; `dating_route_state[p]["date_count"] += 1`; `+= result["dark_point"]` to `dark_points`; if `entered_true_path` increment `true_path_count`; set `previous_entered_true_path = entered_true_path`.
- Pair tracking: for `group` AND `twofriends`, update `inter_friend_route_state["<sorted pair>"]` (`date_count +1`, `dark_points += dark_point`). For `twofriends`, ALSO apply placeholder Angela-absent affection via `change_inter_friend_affection(friend_a, friend_b, result["affection_delta"])` (lives ONLY in `inter_friend_affection`, never Angela's `affection`).
- `entry["friend_id"]` exists ONLY for solo entries; group/twofriends use `friend_ids` / `inviter_id`.

True-path entry rule (enforced by the OVERLAY before emitting): to ENTER true path, `dating_route_state[friend_id]["previous_entered_true_path"]` must be true, EXCEPT on the friend's FIRST solo dating day (exempt): Priscilla Day 1, Sylvia Day 1, Lavinia Day 2 (i.e. `min(DataCatalog.get_invitation_days_for_friend(friend_id))`). If not met, the perfect finish falls back to `path="dark"` (`dark_point=1`). Assertion: a 4th true-path count requires the prior 3 challenges for that friend to have each set `previous_entered_true_path=true`, reachable for every friend from their first solo day (Priscilla 1→2→4→6, Sylvia 1→3→4→5, Lavinia 2→3→5→6).

**Romance ↔ Minesweeper coupling (Phase 6).** Board skill MUST feed romance. `MinesweeperChallengeOverlay` (and the real board) MUST populate `result["board_performance"]`; `apply_dating_challenge_result(entry, result)` MUST use it to modulate outcomes: a real-board `perfect`/`foresight` clear SHOULD boost `affection_delta` / satisfy `entered_true_path` eligibility in addition to the flag chain; an `exploded` real board SHOULD reduce/nullify the positive `affection_delta`. The player-choice mine-affection selector remains the baseline; board performance is an additive modifier. Placeholder overlay sends `board_performance = {}`.

Hospital: `HospitalScene` starts `hospital.faint`; on continue calls `GameState.apply_hospital_recovery_and_advance_day()`. That method performs the day advance internally (days 1–6) or resolves the ending (day 7) and returns `true` if a new day began (day 1..6) or `false` if the ending was resolved (day 7). The caller MUST NOT call any other day-advance. Else if the method returned `true` → `goto_main()`, else → `goto_ending()`. On the Day-7 case the method has already called `resolve_day7_ending()` and set `route_context["ending_id"]` / `epilogue_ending_id` (Special Sylvia first, `CONTRACTS.md §2`). `EndingScene` plays the primary ending, then the epilogue when present. Do not auto-route during smoke test.

Ending: `EndingScene` selects one ending timeline by ending ID (alone / priscilla|lavinia|sylvia × sweet|dark|true / sylvia.special / priscilla_lavinia). Day-7 Done MUST call `resolve_day7_ending()` before routing to `EndingScene`; MUST NOT push the Minesweeper unfinished warning and MUST NOT force remaining app rounds. `EndingScene` plays the primary `ending_id`, then (when `epilogue_ending_id` set, currently `ending.priscilla_lavinia`) plays that timeline afterward. Return-to-menu calls `SceneRouter.goto_menu()`.

Twofriends missed-group: Angela absent. Apply placeholder inter-friend affection and route state (`inter_friend_affection`, `inter_friend_route_state`, `missed_group_date_counts`). Two missed group dates for the same Priscilla/Lavinia pair enable `ending.priscilla_lavinia` via `should_route_priscilla_lavinia_post_ending()`. `inter_friend_affection` / `inter_friend_route_state` are read by the twofriends/group DTL timelines for flavour; ending resolution reads only `missed_group_date_counts` (`CONTRACTS §2`).

---

# 7. Save / load flow
`SaveManager` serializes the whitelisted `GameState` state (`CONTRACTS.md §6`). After successful load, route through `SceneRouter` based on `scene_id` and `route_context`. If a save was taken mid-schedule (ScheduleApp open), reload restores `MainGameScene` and does NOT auto-run Done. If `route_context["ending_id"]` is a non-empty valid ending id → `EndingScene`; else if `day` 1..7 → `MainGameScene`; else `EndingScene`. Reject unsupported schema versions and malformed data safely; never crash from missing or corrupt save files. (Save guard requirement: `CONTRACTS.md §6`.)

---

# 8. Audio context flow (scene integration)
Scenes request music via `AudioManager.set_music_context(...)`; never load raw paths or create their own `AudioStreamPlayer`. Missing tracks MUST NOT crash.

- `MenuScene` ready → `set_music_context("menu")`.
- `OpeningScene` ready → `set_music_context("opening")`.
- `TutorialOverlay` shown → `set_music_context("tutorial")`.
- `MainGameScene` ready → `set_music_context("main_desktop", {"day": GameState.day})`; on danger-stat change → `refresh_current_context()` (no spam restarts).
- `ComputerDesktop` opens app → `minesweeper|contacts|shop|schedule|backup|settings`; hides app → return to `main_desktop`.
- `ContactListApp` opens friend → `set_music_context("contacts", {"friend_id": friend_id})` (resolves to `contacts_soft`).
- `DatingScene` start → `set_music_context("dating", context)` with friend_id/friend_ids/route_type/day/mood; attitude `mad`/`upset` → mood `"mad"`; group with one mad → `group_tension`; twofriends → `twofriends_absent`.
- `MinesweeperChallengeOverlay` → `dating_challenge` / `dating_dark_path` / `dating_true_path`.
- `HospitalScene` ready → `set_music_context("hospital")`.
- `EndingScene` → resolve `ending_id` then `set_music_context("ending", {"ending_id": ending_id})`.

Context-to-track resolution (authoritative mapping; `AudioManager.resolve_bgm_for_context`):
- menu→`menu_theme`; opening→`opening_forget_me_not`; tutorial→`tutorial_soft_screen`; main_desktop→ pressure≥10 `desktop_alone_pressure` / health≤0 `desktop_alone_low_health` / else `desktop_alone_day`; minesweeper→`minesweeper_focus`; contacts→`contacts_soft`; shop→`shop_idle`; schedule→`schedule_planning`; backup→`backup_safe`; settings→`settings_calm`; hospital→`hospital_room`; ending→ per `ending_id` (fallback sweet/dark/true→`ending_sweet`/`ending_dark`/`ending_true`, final fallback `ending_alone`).
- `dating` (`AudioManager.resolve_bgm_for_context("dating", ctx)`): `route_type == "twofriends"` → `twofriends_absent`; `route_type == "group"` → `group_tension` if any participant `attitude`/`mood` is `mad`/`upset`, else `group_priscilla_lavinia`; `route_type == "solo"` (or unset) → `mood == "mad"` → `<friend>_mad`, else friend default warm `priscilla_warm` | `lavinia_quiet` | `sylvia_mystery`. `dating_challenge` / `dating_dark_path` / `dating_true_path` are SEPARATE contexts → `date_challenge_normal` / `date_challenge_dark` / `date_challenge_true`.
- OPTIONAL, unused in prototype (treat as unused, like `desktop_night_uncertain`): `priscilla_playful`, `priscilla_dark`, `priscilla_true`, `lavinia_walk`, `lavinia_dark`, `lavinia_true`, `sylvia_soft`, `sylvia_dark`, `sylvia_true`.
- Any unresolved/missing track returns the safe missing-audio result and never crashes.
- `tutorial→tutorial_soft_screen` is declared above but `tutorial_soft_screen` need not exist as a file; if absent, `AudioManager` returns the safe missing-audio result (intended silent tutorial). Track id is declared in `CONTENT.md §13`.

---

# 9. Required scene node-trees (required layouts)
Rule: every scene either has a `.tscn` with the required tree, or builds it in `_ready()`. Scripts include clear member names and document the intended tree in comments. Scenes MUST NOT auto-quit or auto-route during smoke instantiation. Opening/Tutorial/Dating/Hospital/Ending/Contacts use Dialogic timelines (`DIALOGIC.md`).

## MenuScene
Root `Control`. Left-center panel ~4/10 width, ~3/10 height. Buttons: New Acc, Log in, Gallery, Setting, Shut down (all focusable, localized). New Acc → `SceneRouter.start_game_from_menu()`. Log in shows `BackupApp` inside rectangle. Gallery → opens `GalleryScene`. Setting shows `Setting` inside rectangle. Shut down asks confirmation → `get_tree().quit()`. Controller cancel closes BackupApp/Setting if open.

## OpeningScene
Root `Control`. Continue/finish → `GameState.mark_opening_seen()` + `SceneRouter.goto_main()`. Do not auto-finish during smoke.

## MainGameScene
Root `Control`. Left Angela/stat panel stretch_ratio 3; right computer panel stretch_ratio 5. Left: day label, pressure (HUD display 0..9; **internal 0..12; danger/faint at >=10 — intended hidden zone that resolves at day-end condition resolution**), health 0..9, motivation 0..7, money, coin, condition display, penalty (if >0), Angela placeholder. `StatHud` updates on `GameState` signals. Day 1 with opening seen + tutorial not seen → `TutorialOverlay`. Quick save/load via `SaveManager` (unless disabled in unsafe route context).

## EndingScene
Root `Control`. Shows placeholder ending by affection/route state. Return to Menu → `SceneRouter.goto_menu()`.

## GalleryScene
Root `Control`. Opened from a `Gallery` button on `MenuScene`. Reads `GameState.seen_endings` and shows one tile per ending reached (`seen_endings[id] == true`); unseen endings hidden or locked. Each visible tile shows the ending name (`gallery.ending.<id>.title`) and, on activate, replays the ending timeline through `DialogicBridge` / `EndingScene` (read-only, no route_context write, no day advance). Return to Menu → `SceneRouter.goto_menu()`.

## HospitalScene
Root `Control`. Continue → `GameState.apply_hospital_recovery_and_advance_day()`. If the method returned `true` → `goto_main()`; else (`day == 7`, ending resolved) → `goto_ending()`. Do not auto-route during smoke. Strings come from the Dialogic `hospital.faint` timeline; the layout example is illustrative only.

## Shared UI
- `BoxMeter`: `PanelContainer` → `VBoxContainer` (`HeaderHBox` Name+Value, `GridContainer` BoxGrid).
- `StatHud`: `PanelContainer` → `VBoxContainer` (DayLabel; PressureMeter; HealthMeter; MotivationMeter; MoneyRow; **MinesweeperRoundRow** using `hud.minesweeper_rounds` with `remaining`/`max`, red/warning only when `get_minesweeper_display_rounds_left() > 0`, numeric text always shown, high-contrast override; CoinRow; ConditionDisplay; PenaltyLabel). PressureMeter shows `get_stat_display_value(STAT_PRESSURE)` (display max 9 by design); the internal stat may reach 12 and trigger danger at >=10 without the meter showing it — this is intended (resolves at day end).
- `AppWindowBase`: `PanelContainer` → `VBoxContainer` (TopBar→TopBarHBox Title+spacer+HideButton; ContentMargin→ContentHost). Hide (not free); Escape/cancel hides; first interactive child focused on open.
- `IconButton`: `Button` → `VBoxContainer` (IconImage + IconLabel).

## TutorialOverlay
Covers intended tutorial area. Requires Dialogic 2 (`DIALOGIC.md §5`). Finish → `GameState.mark_tutorial_seen()` + hide/free. If Dialogic 2 is missing, Phase 2 is blocked (report `Dialogic 2 addon file does not exist.`). Scene scripts must still parse/instantiate under smoke without crashing.

## ComputerDesktop
`Control` → SafeImage/ColorRect + `GridContainer` (columns=4; Minesweeper, Contacts, Schedule, Shop, Setting, Logout, Backup) + `AppWindowHost` + **`NotificationLayer`** (right-bottom `MinesweeperMessageNotification` hidden by default: Close/Go/Yes, all focusable; appears only per §4; does not steal focus unless controller/keyboard focus mode). Only one app window visible; hide (not free); reopen preserves state same day; `daily_state_reset` clears cached windows; Minesweeper difficulty persists in `GameState`.

## MinesweeperApp
`PanelContainer` → `VBoxContainer` (TopBar; MinesweeperRoot: DifficultyTabs; StatusRow; ToolRow; TaskListPanel hidden; BoardScroll; SimulationButtons; InvitationNotification hidden). Placeholder only. Difficulty tabs Beginner/Intermediate/Expert; store in `GameState.minesweeper_selected_difficulty`. Show safety level (`get_minesweeper_safety_level()`: 1 default, 2 with lucky_charm, 3 with debug_key); display-only in phases 0–5, modifies board generation in Phase 6. Show rounds left/max using signed display (`CONTRACTS.md` Minesweeper model). Show coins, foresight rate `float(three_bv)/float(max(1,click_count))*100.0`. Start round → `GameState.start_minesweeper_app_round(difficulty)`; finish → `GameState.finish_minesweeper_app_round(result)`; clear unfinished → `GameState.clear_unfinished_minesweeper_round()`. Simulated result buttons: Exploded, Clear, Perfect, No-flag clear, Foresight clear. No full board logic in phases 0–5 (real playable board is Phase 6; the live board must reuse these same start/finish/clear calls and the app-round result contract).

## ContactListApp
`PanelContainer` → `VBoxContainer` (TopBar; ContactsRoot: ContactList stretch 3 [Priscilla/Lavinia/Sylvia ContactBox] + ChatPanel stretch 7 [ChatTitleLabel; ChatScroll→ChatMessageList; ChoiceList; InvitationResponseRow]). Opening contact → `GameState.open_contact(friend_id)`. Messages grey rounded; friend left, Angela right; scroll to bottom; history stored as read. Uses Dialogic with custom chat-bubble layout. ContactBox: Button→HBox(PortraitImage; TextVBox Name+Status; UnreadBadgeLabel). ChatBubble: PanelContainer→VBox(SpeakerLabel; RichTextLabel MessageLabel).

## ShopApp
`PanelContainer` → `VBoxContainer` (TopBar; ShopRoot: CurrencyStatusRow; ItemGrid columns=3 [9 boxes/page, 2 pages]; PageRow; StatusLabel). Each `ShopItemBox`: ItemImage, Name, Price, EffectSummary, PurchaseCount, **QuantityRow** (minus/label/plus, focusable), BuyButton (`shop.buy_quantity`), SoldOutLabel (`shop.sold_out`), optional **SecretBuyButton** (transparent, Supportz). Quantity starts 1, clamps to buyable count; max 0 unlimited limited by affordability; price 0 + max 0 caps at 99. Buying checks: item exists; purchase count not over max; money via `can_spend_money`, coins via `can_spend_coins`; `EffectResolver.are_effect_ids_known`; Supportz also requires `can_buy_supportz()`. On pass: spend currency, apply effects, increment `shop_purchase_counts`, refresh. If effect application unexpectedly fails after spending: refund, do not increment, show status. Supportz: invisible normal visuals, secret focusable buy area, 1 per activation, disabled after 3, focus outline under high-contrast/focus-ring.

## ScheduleApp
`PanelContainer` (extends AppWindowBase) → `VBoxContainer` (TopBar; ScheduleRoot: ActionButtonRow [Dating, Training, Working, Rest]; InvitationButtonRow [≤2 accepted dates]; ScheduleBar [7 boxes]; GiftPickerPanel hidden; BottomButtonRow; StatusLabel; **MinesweeperWarningAlert** hidden [AlertHeader Close; AlertBody; AlertButtonRow Go/Yes]). Pressing action fills first empty box; right-click/controller removes last entry; scheduled entry click removes + shifts. Date entries show gift plus box; one gift per date. Done follows §2. Day 4 Priscilla first-slot: enabled only when bar empty; greyed + disabled otherwise; UI status explains; GameState enforces in `add_schedule_date_entry`/validation. Day 7: show date buttons for unlocked ending candidates (a friend whose Day-7 contact message is unlocked AND whose affection tier is `ambiguous` or `love`; gating in `CONTRACTS.md §2`); allow ≤1 date/ending candidate; disable Training/Working/Rest; validation blocks Done or removes non-date safely; unfinished board abandoned safely; determine candidate via `GameState.resolve_day7_ending()` (single entry point; writes `route_context["ending_id"]`); clear unexecuted schedule without refund unless cancelled; route `SceneRouter.goto_ending()`.

## Setting / SettingsApp
Menu-sized `Setting.tscn` and desktop `SettingsApp.tscn`. Controls for every `GameState.settings` key (`CONTRACTS.md §8`). Language: English/Chinese/Cantonese via `LocalizationManager.set_locale`. Accessibility via `AccessibilityManager.apply_settings_to_tree`. Audio volumes via `AudioManager.apply_volume_settings()` (safe if AudioManager missing).

## LogOutApp
Confirm panel: Yes → `SceneRouter.goto_menu()`; No → close. Does not quit game. Routes confirmation text through `LocalizationManager.t("logout.confirm")` once that key exists in `CONTENT.md §2`.

## BackupApp
`PanelContainer` → `VBoxContainer` (TopBar; BackupRoot: ModeTabs [SaveMode/LoadMode]; SaveGrid columns=3 [Autosave, QuickSave, Slot1..7]; StatusLabel; ReturnButton). Save/load/delete via `SaveManager`; does not mutate `GameState` directly; delete requires confirmation; exactly 7 numbered slots (no slot_8/9). `SaveSlotRow`: SlotTitleLabel, MetadataLabel, Save/Load/Delete buttons, WarningLabel.

## DatingScene
`Control` → (SafeImage/ColorRect DatingBackground; DatingRoot: CharacterZone [Left/Center/Right slots, ~1/3 height]; PreviousDialogueScroll→PreviousDialogueList; DialogueBox). Loads entry from `get_current_pending_date_entry()`. Solo: Angela left + friend right. Group: Angela left + other center + inviter right. Twofriends: first friend (original inviter) left + second right, Angela absent. Previous dialogue: visible stack shows current + previous 2 (grey, rise, oldest removed when >2); full log retained for Log button. Show `MinesweeperChallengeOverlay` after pre-challenge text. Finish → `SceneRouter.finish_current_dating_and_route()`.

## DialogueBox
`PanelContainer` → `VBoxContainer` (SpeakerRow [SpeakerNameLabel; InputHintLabel]; DialogueTextLabel; ControlRow [Log/Skip/Auto/Next]). Important dialogue readable as text; self-paced unless auto (interruptible); skip respects `skip_unseen_text_allowed`; placeholder log if full impl not ready.

## MinesweeperChallengeOverlay
`PanelContainer` → `VBoxContainer` (TitleLabel; BoardInfoLabel; BoardScroll→PlaceholderBoard [9×9, 18 mines placeholder]; NormalResultButtons; DarkPathButtons; StatusLabel; CancelOrCloseButton). Buttons simulate: mine affection -1/0/+1/+2; complete sweet path; dark mine dark path; perfect true path. True path requires previous true path (EXCEPT on the friend's FIRST solo dating day: Priscilla Day 1, Sylvia Day 1, Lavinia Day 2) else dark-path perfect fallback. Every dark finish +1 dark point; true path adds none. Emits `challenge_finished(result)` with `context="dating"`. Does not consume app rounds or reward app money.
