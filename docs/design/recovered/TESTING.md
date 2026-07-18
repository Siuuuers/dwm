# TESTING — Required test files and requirements

Documents the test-file list and test requirements. Command definitions live in `PHASES.md` §2.

## Required test files
```
res://tests/smoke_load_scenes.gd
res://tests/unit/test_game_state.gd
res://tests/unit/test_effect_resolver.gd
res://tests/unit/test_schedule_rules.gd
res://tests/unit/test_minesweeper_rewards.gd
res://tests/unit/test_localization.gd
res://tests/unit/test_save_manager.gd
res://tests/unit/test_input_accessibility.gd
res://tests/unit/test_shop_rules.gd
res://tests/unit/test_audio_manager.gd
```
If GUT is not installed, still create the test files; skip only the GUT command and report exactly: `GUT addon file does not exist.`

Future smoke test (Dialogic manifest; see `DIALOGIC.md` §11):
```
res://tests/smoke_dialogic_timelines.gd
```

---

# Smoke test — `res://tests/smoke_load_scenes.gd`
Must:
- extend `SceneTree`.
- load every required scene, instantiate every required scene.
- not depend on user input, not trigger auto-routing.
- exit `0` if all required scenes load and instantiate.
- exit `1` if any required scene fails.

Required scene paths (authoritative list in `CONTRACTS.md` §11): all `scenes/.../*.tscn` listed there, plus the updated shared/app/dating UI scenes (`StatHud` with `MinesweeperRoundRow`, `ShopItemBox` with quantity selector, `ComputerDesktop` with `NotificationLayer`, `ScheduleApp` with `MinesweeperWarningAlert`, `DatingScene` with previous-dialogue nodes, `MinesweeperChallengeOverlay` with placeholder result buttons).

The test may optionally check important named child nodes but must not fail merely because art files are missing.

---

# `test_game_state.gd`
- `reset_game()` sets day 1, money 0, coins 0, penalty 0, pressure 3, health 6, motivation 7.
- `change_stat()` clamps pressure 0..12, health -2..9, motivation 0..7.
- display pressure clamps 0..9; display health clamps 0..9, negative health displays as 0.
- `change_money()` never below -30; overdraft spending works from nonnegative money; blocks when money already negative.
- coin spending blocks when insufficient.
- `mark_opening_seen()` / `mark_tutorial_seen()` work.
- `advance_day_or_end()` resets daily motivation and Minesweeper app state; after Day 7 it returns false (ending resolved via `route_context["ending_id"]`; `day` is not changed to 8).

## Minesweeper round-floor tests
After `reset_game()`: `minesweeper_round_floor == 0`, `minesweeper_rounds_left == 2`, display left/max both 2, total playable 2, playable remaining 2.
Starting/consuming two app rounds without Supportz displays `2/2` → `1/2` → `0/2`; cannot start a third without Supportz.
After one Supportz/floor effect: floor -1, display max 2, total playable 3; with one Supportz, three app rounds display `-1/2`.
After three Supportz/floor effects: floor -3, total playable 5; a fourth does not go below -3; with three Supportz, five app rounds display `-3/2`; cannot start a sixth.
Save/load preserves and clamps `minesweeper_round_floor` and `minesweeper_rounds_left`.

## Condition tests
- danger resolution adds penalty; pressure >9 resets to 9; health <1 resets to 1; combined daily penalty caps at 6; total penalty caps at 42.
- sequela + new danger can produce faint; faint sets pending hospital.
- hospital recovery resets health 6, pressure 3, clears pending hospital.

## Special Sylvia ending / real-time faint tests
- `hospital_skipped_sylvia_solo_count` starts 0; `reset_game()` zeroes it; save/load preserves it (whitelisted in `to_save_dict`/`apply_save_dict`).
- hospital recovery increments `hospital_skipped_sylvia_solo_count` by 1 for each pending **Sylvia solo** date cleared; group/other dates do not count.
- `check_immediate_faint()` returns `true` (and sets `pending_hospital`) only when `condition_effects_today` has `sequela` AND pressure >= 10 OR health <= 0; returns `false` on a danger day without `sequela`.
- `should_route_sylvia_special_ending()` is `false` at 0–1 skips, `true` at >= 2.
- `resolve_day7_ending()` returns `ending.sylvia.special` (highest precedence) when `hospital_skipped_sylvia_solo_count >= 2`, even if a candidate friend exists; sets `epilogue_ending_id = "ending.priscilla_lavinia"` when `should_route_priscilla_lavinia_post_ending()` is true and the primary is not already `ending.priscilla_lavinia`.

## Save whitelist tests
- `to_save_dict()` returns JSON-safe data; `apply_save_dict()` preserves safe state.
- save data includes no Nodes/Objects/Callables/Resources.

---

# `test_effect_resolver.gd`
- known health/pressure/motivation/money/coin effects mutate correctly.
- unknown effect is blocked and mutates nothing; mixed known+unknown applies nothing.
- inventory and gift inventory effects add items.
- affection effect changes correct friend only; attitude changes correct friend only; inter-friend affection works.
- `minesweeper:round_floor:-1` works; `minesweeper:max_rounds:+1` remains a compatibility alias.
- repeated floor effects clamp at -3; visible denominator remains 2 after all.
- no effect directly mutates GameState dictionaries when a safe method exists.

---

# `test_schedule_rules.gd`
- adding action costs motivation; cannot add at 0 motivation; removing refunds.
- `clear_schedule_with_refund()` removes + refunds; `clear_schedule_without_refund()` removes, no refund.
- cannot schedule date without accepted invitation; can after; two dates Day1..6 if two invitations; cannot exceed two Day1..6; cannot exceed one on Day7; no duplicate solo/group on same day; group counts as one.
- removing work before a date invalidates + removes/refunds later date.

## Schedule Done warning tests
`should_warn_minesweeper_before_schedule_done()` returns a `Dictionary` with key `"should_warn"` (assert on this key, not a bare boolean):
- `"should_warn" == true` when: unfinished app round + motivation>0; playable remains + motivation>0 + empty schedule; playable remains + motivation==0 + ≥1 non-date entry.
- `"should_warn" == false` when: no unfinished + no playable; motivation 0 + no non-date; schedule has only date entries + no unfinished.
Warning Go/Yes calls `clear_schedule_with_refund()` and verifies entries removed, motivation refunded, no effects applied, day not advanced.

## Day-4 Priscilla first-slot tests
- Priscilla Day-4 solo can be added as first entry.
- cannot be added when any other entry exists.
- if in slot 0, later entries may be added.
- UI helper/status may disable the button when schedule not empty (GameState enforces).

---

# `test_minesweeper_rewards.gd`
- app finish rewards money; exploded still rewards; incomplete does not; dating challenge does not reward app money.
- daily reward cap enforced (108 + 54*max(0, total-2)); one Supportz → total 3; three → total 5; cap uses internal total, not visible denominator; visible denominator stays 2.
- task rewards add coins once only; total cannot exceed 9; repeated same task adds none; `win_win_win` claimable once when met.

---

# `test_localization.gd`
- default locale valid; set en / zh_CN / zh_HK works; unsupported rejected or falls back safely.
- missing key returns `[missing:key]` without crash; param replacement works.
- newer keys: `hud.minesweeper_rounds`, `desktop.notification.new_message_from_friend`, `desktop.notification.new_message_title`, `schedule.alert.minesweeper_needed.title/.body/.detail`, `shop.buy_quantity`, `shop.quantity.value`, `shop.sold_out`, `shop.secret_supportz.accessible_name` all exist + param replacement; missing new keys still return `[missing:key]`.

---

# `test_save_manager.gd`
- save folder creation succeeds or safe error; `save_slot(1)` writes JSON or safe error; `load_slot(1)` rejects missing slot; corrupted JSON rejects; quick/autosave round-trip; unsupported schema rejects; malformed rejects.
- save data includes no Nodes/Objects/Callables/Resources; applying routes safely; saved `minesweeper_round_floor` preserved + clamped.
- `hospital_skipped_sylvia_solo_count` is included in the whitelist and preserved + clamped on load.
- `minesweeper_rng_seed` is included in the whitelist and preserved on load; boards generated from the same seed are reproducible.
- `migrate_save_dict` upgrades an older `schema_version` forward to the current one (e.g. v1 → v2) and fills any newly added whitelisted fields with safe defaults; a save whose `schema_version` is higher than the current build is still rejected.

---

# `test_input_accessibility.gd`
- required input actions exist after `ensure_default_input_map()`; `focus_first_control()` finds a focusable button; `make_button_focusable()` sets focus mode.
- accessibility settings exist in `GameState.settings`; font scale / high contrast / reduced motion change safely; localization refresh no crash.
- UI-specific: shop quantity minus/plus/buy focusable; notification Close/Go/Yes focusable; schedule warning Close/Go/Yes focusable; sold-out has visible text not grey-only; Minesweeper HUD warning has numeric text not red-only; secret Supportz has accessible/focus label if focusable.

---

# `test_shop_rules.gd`
- all 18 shop item templates exist; Supportz exists, not visible as normal, `is_secret_buy_button==true`, max 3, effect `minesweeper:round_floor:-1`.
- quantity starts 1, cannot go below 1, cannot exceed buyable; buyable respects max count, money/coin affordability, overdraft; max 0 unlimited limited by affordability; price 0 + max 0 uses safe cap 99.
- buying qty 3 applies inventory effect 3×; qty 2 spends total twice; repeated stat effects clamp; unknown effect blocks entire purchase before spend; unexpected post-spend failure refunds + no count increment; sold-out disables + shows localized text.
- Supportz secret buy works; lowers floor; does not change visible denominator; disabled after 3; fourth blocked.

---

# `test_audio_manager.gd`
- AudioManager / AudioManifest parse; expected BGM paths dictionary exists.
- missing BGM does not crash; `play_bgm` with missing track returns safe error; repeated `play_bgm` same track does not restart unless forced.
- `set_music_context("menu")` resolves a track; `set_music_context("dating", {"friend_id":"lavinia","mood":"mad"})` resolves Lavinia mad or fallback.
- volume settings apply without crash; audio state save dict is JSON-safe; loading save with unknown current_bgm_id does not crash; scene smoke tests do not require actual audio files.