# Week Tint (Desktop Shell and Angela Panel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the desktop shell and the Angela panel HUD slide from the shipped Day 1 palette toward a colder Day 7 palette, with Day 1 byte-identical to today.

**Architecture:** One new pure helper, `WeekTint`, owns the day curve and the OK-HSL room-role transform. `DesktopTheme.build` gains a trailing `week_tint` parameter defaulting to `0.0` so every existing caller is unchanged. The two shell presenters that already know the day (`ComputerDesktop` through its `_day` field, `StatHud` through its owner's `day`) pass the tint on the refresh paths that already fire at boundaries (login, day advance, eviction). Nothing animates; nothing reads the clock.

**Tech Stack:** Godot 4.6.3 (mono build, GDScript only), GUT test runner, `Color.ok_hsl_h/s/l` and `Color.from_ok_hsl` (verified present in this build).

**Spec:** `docs/design/2026-09-12-instrumentarium-drift-deck-all-input-and-week-tint-amendment.md`, Section 5 (as corrected on 2026-09-12: the shipped tuple is the Day 1 endpoint; the whole range lies on the cold side). Beads epic `dwm-vky`.

## Global Constraints

- Day curve, verbatim from the spec: Day 1 `0.00`, Day 2 `0.08`, Day 3 `0.20`, Day 4 `0.38`, Day 5 `0.58`, Day 6 `0.80`, Day 7 `1.00`.
- Room roles only: `habitat`, `face`, `paper`, `structure`, `secondary_ink`, `inward_preview`. Never `ink`, `paper_ink`, `focus`, `paper_focus`, `danger`, `destructive`, `filed`, `secondary_dark_ink`, and never DesktopTheme's `current`.
- Hue never rotates. High-contrast tuples: zero amplitude. CVD presets (`protan`, `deutan`, `tritan`): lightness deltas only.
- Day 1 (tint `0.0`) must return colours **byte-identical** to the shipped tuple; every existing Day-1 test and render stays exact.
- Tint is computed only on existing boundary refresh paths; no `_process`, no Tween, no timer.
- Reduced Motion needs no handling: the tint never moves.
- No file under `scripts/settings/` or the pinned registries (`PausePaletteRegistry`, `WitnessedPaletteRegistry`, `MinesweeperPaletteRegistry`) is touched by this plan; those surfaces are the second plan.
- Frozen gate: none of the touched files is in the gate's bound path list (`tools/evidence/generate_phase2r_schedule_gate.gd` `SOURCE_PATHS`), but `DesktopTheme.gd`, `StatHud.gd` and `ComputerDesktop.gd` are hashed in `tools/desktop_shell/evidence/result.json`, `tools/stat_hud/evidence/result.json`, `tools/title_resume/evidence/result.json` and `tools/title_shell/evidence/result.json`. Do **not** re-seal per task; the amendment's Section 13 orders one re-seal after all increments. Record the stale hashes in the Beads task notes instead.
- Repo rules: claim a Beads child task before editing (`bd create ... --parent dwm-vky`, then `bd update <id> --claim`); never `git stash`; write patch scripts with the Write tool, never Bash heredocs (they collapse backslashes); GUT `assert_ne` against `null` counts as a failure, use `assert_not_null`; pre-flight every new test file with a one-file `-gtest=` run because `--check-only` is blind to autoload identifiers.
- Test runner invocation (headless, from the repo root, exact binary):

```bash
"C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_week_tint.gd -gexit
```

  Read the `Totals` block; three `Unicode parsing error ... NUL` lines and an `ObjectDB instances leaked` warning are pre-existing noise.

---

## File Structure

| File | Responsibility |
|---|---|
| Create `scripts/ui/theme/WeekTint.gd` | Pure static helper: day curve and OK-HSL room-role transform. No scene, no state. |
| Create `tests/unit/test_week_tint.gd` | Unit tests for the helper against the real settings tuples. |
| Modify `scripts/ui/desktop/DesktopTheme.gd:7-15` | `build` gains `week_tint: float = 0.0`; applies the helper to its role dictionary before styling. |
| Create `tests/unit/test_desktop_theme_week_tint.gd` | Proves Day 1 exactness and Day 7 darkening for both palettes. |
| Modify `scripts/ui/ComputerDesktop.gd:734-740` | `_refresh_launcher` passes `WeekTint.tint_for_day(_day)`. |
| Create `tests/integration/test_desktop_week_tint.gd` | Proves the eviction (day-advance) boundary rebuilds the theme with the tint. |
| Modify `scripts/ui/StatHud.gd:112-121` | `_refresh_presentation` keys its cache on the tint and passes it. |
| Create `tests/unit/test_stat_hud_week_tint.gd` | Proves the HUD theme follows its owner's day and rebuilds on `day_changed`. |

---

### Task 1: WeekTint helper

**Files:**
- Create: `scripts/ui/theme/WeekTint.gd`
- Test: `tests/unit/test_week_tint.gd`

**Interfaces:**
- Consumes: `scripts/settings/SettingsPaletteRegistry.gd` `static func resolve(palette_id: StringName, high_contrast: bool, colour_preset: String) -> Dictionary` (read-only, in tests).
- Produces: `WeekTint.tint_for_day(day: int) -> float`, `WeekTint.apply(roles: Dictionary, tint: float, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary`, `WeekTint.ROOM_ROLES`, `WeekTint.COLD_DELTAS`.

- [ ] **Step 1: Claim the Beads task**

```bash
bd create "Week tint: WeekTint helper" -t task -p 2 -l ui --parent dwm-vky --silent
bd update <id> --claim
```

- [ ] **Step 2: Write the failing test**

Create `tests/unit/test_week_tint.gd`:

```gdscript
extends "res://addons/gut/test.gd"

const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const REGISTRY := preload("res://scripts/settings/SettingsPaletteRegistry.gd")


func test_curve_is_zero_on_day_one_and_one_on_day_seven() -> void:
	assert_eq(WEEK_TINT.tint_for_day(1), 0.0)
	assert_eq(WEEK_TINT.tint_for_day(7), 1.0)
	assert_eq(WEEK_TINT.tint_for_day(0), 0.0, "before the week clamps to Day 1")
	assert_eq(WEEK_TINT.tint_for_day(9), 1.0, "after the week clamps to Day 7")
	assert_almost_eq(WEEK_TINT.tint_for_day(2), 0.08, 0.0001)
	assert_almost_eq(WEEK_TINT.tint_for_day(4), 0.38, 0.0001)
	assert_almost_eq(WEEK_TINT.tint_for_day(6), 0.80, 0.0001)
	var previous := -1.0
	for day: int in range(1, 8):
		var tint: float = WEEK_TINT.tint_for_day(day)
		assert_gt(tint, previous, "curve is strictly increasing at day %d" % day)
		previous = tint


func test_tint_zero_returns_identical_colours() -> void:
	var roles: Dictionary = REGISTRY.resolve(&"after_hours", false, "standard")
	var tinted: Dictionary = WEEK_TINT.apply(roles, 0.0)
	assert_eq(tinted.size(), roles.size())
	for role: String in roles:
		assert_eq(tinted[role], roles[role], role)


func test_tint_one_darkens_only_room_roles_and_keeps_hue() -> void:
	var roles: Dictionary = REGISTRY.resolve(&"after_hours", false, "standard")
	var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0)
	for role: String in ["face", "habitat", "paper"]:
		assert_lt(tinted[role].ok_hsl_l, roles[role].ok_hsl_l, role + " lightness drops")
		assert_almost_eq(tinted[role].ok_hsl_h, roles[role].ok_hsl_h, 0.02, role + " hue is kept")
	assert_lt(tinted["structure"].ok_hsl_s, roles["structure"].ok_hsl_s, "structure loses saturation")
	assert_almost_eq(tinted["face"].ok_hsl_l, roles["face"].ok_hsl_l - 0.05, 0.003, "face cold endpoint is L -0.05")
	for role: String in ["ink", "paper_ink", "focus", "paper_focus", "danger", "destructive", "filed", "secondary_dark_ink"]:
		assert_eq(tinted[role], roles[role], role + " is not a room role")


func test_partial_tint_lands_between_the_endpoints() -> void:
	var roles: Dictionary = REGISTRY.resolve(&"midnight", false, "standard")
	var half: Dictionary = WEEK_TINT.apply(roles, 0.5)
	var full: Dictionary = WEEK_TINT.apply(roles, 1.0)
	assert_lt(half["face"].ok_hsl_l, roles["face"].ok_hsl_l)
	assert_gt(half["face"].ok_hsl_l, full["face"].ok_hsl_l)


func test_high_contrast_has_zero_amplitude() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var roles: Dictionary = REGISTRY.resolve(palette, true, "standard")
		var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0, true, "standard")
		for role: String in roles:
			assert_eq(tinted[role], roles[role], "%s %s" % [palette, role])


func test_cvd_presets_change_lightness_only() -> void:
	for preset: String in ["protan", "deutan", "tritan"]:
		var roles: Dictionary = REGISTRY.resolve(&"after_hours", false, preset)
		var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0, false, preset)
		assert_lt(tinted["paper"].ok_hsl_l, roles["paper"].ok_hsl_l, preset + " paper darkens")
		assert_almost_eq(tinted["paper"].ok_hsl_s, roles["paper"].ok_hsl_s, 0.01, preset + " paper keeps saturation")
		assert_eq(tinted["structure"], roles["structure"], preset + " structure has only a saturation delta, so it stays exact")


func test_apply_does_not_mutate_input_and_ignores_foreign_keys() -> void:
	var roles := {"habitat": Color("0b0d13"), "current": Color("789083"), "label": "not a colour"}
	var before: Color = roles["habitat"]
	var tinted: Dictionary = WEEK_TINT.apply(roles, 0.5)
	assert_eq(roles["habitat"], before, "input dictionary is untouched")
	assert_ne(tinted["habitat"], before, "output habitat is tinted")
	assert_eq(tinted["current"], Color("789083"), "non-room colour keys pass through")
	assert_eq(tinted["label"], "not a colour", "non-colour values pass through")
	assert_eq(tinted["habitat"].a, 1.0, "alpha is preserved")


func test_text_contrast_holds_at_the_cold_endpoint() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var roles: Dictionary = REGISTRY.resolve(palette, false, "standard")
		var tinted: Dictionary = WEEK_TINT.apply(roles, 1.0)
		assert_gt(_contrast(tinted["paper_ink"], tinted["paper"]), 4.5, str(palette) + " paper")
		assert_gt(_contrast(tinted["ink"], tinted["face"]), 4.5, str(palette) + " face")


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
```

- [ ] **Step 3: Run the test to verify it fails**

Run: the runner command from Global Constraints with `-gtest=res://tests/unit/test_week_tint.gd`.
Expected: the script fails to load because `res://scripts/ui/theme/WeekTint.gd` does not exist (GUT reports a parse/preload error and zero passing tests). That is RED.

- [ ] **Step 4: Write the helper**

Create `scripts/ui/theme/WeekTint.gd`:

```gdscript
extends RefCounted
## Week tint: the room ages from the shipped Day 1 tuple (tint 0.0) toward a colder Day 7
## endpoint (tint 1.0). Amendment 2026-09-12, Section 5 (corrected: shipped = Day 1).
## Room roles only. Hue never rotates: only OK-HSL lightness and saturation move.
## High contrast keeps zero amplitude; CVD presets move lightness only.
## Callers evaluate this only at boundaries (login, day advance, return, Load); it never animates.

const CURVE := {1: 0.0, 2: 0.08, 3: 0.20, 4: 0.38, 5: 0.58, 6: 0.80, 7: 1.0}
const ROOM_ROLES: Array[String] = ["habitat", "face", "paper", "structure", "secondary_ink", "inward_preview"]
## Cold endpoint deltas at tint 1.0: role -> [lightness_delta, saturation_delta] in OK HSL.
const COLD_DELTAS := {
	"habitat": [-0.035, -0.015],
	"face": [-0.05, -0.012],
	"paper": [-0.05, -0.025],
	"structure": [0.0, -0.016],
	"secondary_ink": [-0.01, 0.0],
	"inward_preview": [-0.01, 0.0],
}


static func tint_for_day(day: int) -> float:
	if day <= 1:
		return 0.0
	if day >= 7:
		return 1.0
	return float(CURVE[day])


static func apply(roles: Dictionary, tint: float, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary:
	var result := roles.duplicate()
	if high_contrast or tint <= 0.0:
		return result
	var amount := clampf(tint, 0.0, 1.0)
	var lightness_only := colour_preset != "standard"
	for role: String in ROOM_ROLES:
		if not result.has(role) or not result[role] is Color:
			continue
		var deltas: Array = COLD_DELTAS[role]
		var lightness_delta := float(deltas[0]) * amount
		var saturation_delta := 0.0 if lightness_only else float(deltas[1]) * amount
		if is_zero_approx(lightness_delta) and is_zero_approx(saturation_delta):
			continue
		var source: Color = result[role]
		var lightness := clampf(source.ok_hsl_l + lightness_delta, 0.0, 1.0)
		var saturation := clampf(source.ok_hsl_s + saturation_delta, 0.0, 1.0)
		result[role] = Color.from_ok_hsl(source.ok_hsl_h, saturation, lightness, source.a)
	return result
```

- [ ] **Step 5: Run the test to verify it passes**

Run: same command. Expected: `Totals` shows 8 tests passing, 0 failing.

- [ ] **Step 6: Prove RED by mutation**

Temporarily change `"face": [-0.05, -0.012]` to `"face": [0.0, 0.0]`, rerun, and confirm `test_tint_one_darkens_only_room_roles_and_keeps_hue` fails. Restore the line. Rerun to green.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/theme/WeekTint.gd tests/unit/test_week_tint.gd
git commit -m "feat(ui): add WeekTint day curve and room-role transform"
```

(Commit message and attribution follow the repo's commit invariants; if the repo's commit guard demands `DWM_COMMIT_AUTHORIZED=1`, set it for this commit only.)

---

### Task 2: DesktopTheme accepts a week tint

**Files:**
- Modify: `scripts/ui/desktop/DesktopTheme.gd:1-15`
- Test: `tests/unit/test_desktop_theme_week_tint.gd`

**Interfaces:**
- Consumes: `WeekTint.apply(roles, tint)` from Task 1.
- Produces: `DesktopTheme.build(locale: String, percent: int, palette: StringName = &"after_hours", week_tint: float = 0.0) -> Theme`. All existing callers keep compiling because the parameter is trailing and defaulted.

- [ ] **Step 1: Claim the Beads task**

```bash
bd create "Week tint: DesktopTheme.build week_tint parameter" -t task -p 2 -l ui --parent dwm-vky --silent
bd update <id> --claim
```

- [ ] **Step 2: Write the failing test**

Create `tests/unit/test_desktop_theme_week_tint.gd`:

```gdscript
extends "res://addons/gut/test.gd"

const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")


func test_default_tint_keeps_shipped_day_one_colours() -> void:
	var implicit := DESKTOP_THEME.build("en", 100, &"after_hours")
	assert_eq(implicit.get_color("face", "Desktop"), Color("151b25"))
	assert_eq(implicit.get_color("habitat", "Desktop"), Color("0b0d13"))
	var explicit := DESKTOP_THEME.build("en", 100, &"after_hours", WEEK_TINT.tint_for_day(1))
	assert_eq(explicit.get_color("face", "Desktop"), Color("151b25"))
	var midnight := DESKTOP_THEME.build("en", 100, &"midnight", 0.0)
	assert_eq(midnight.get_color("face", "Desktop"), Color("14201d"))
	assert_eq(midnight.get_color("habitat", "Desktop"), Color("0d1514"))


func test_day_seven_tint_darkens_room_roles_only() -> void:
	for palette: StringName in [&"after_hours", &"midnight"]:
		var day_one := DESKTOP_THEME.build("en", 100, palette, WEEK_TINT.tint_for_day(1))
		var day_seven := DESKTOP_THEME.build("en", 100, palette, WEEK_TINT.tint_for_day(7))
		for role: String in ["face", "habitat"]:
			assert_lt(day_seven.get_color(role, "Desktop").ok_hsl_l, day_one.get_color(role, "Desktop").ok_hsl_l, "%s %s" % [palette, role])
		assert_lt(day_seven.get_color("structure", "Desktop").ok_hsl_s, day_one.get_color("structure", "Desktop").ok_hsl_s, "%s structure" % palette)
		for role: String in ["ink", "focus", "current"]:
			assert_eq(day_seven.get_color(role, "Desktop"), day_one.get_color(role, "Desktop"), "%s %s" % [palette, role])
		assert_eq(day_seven.get_color("font_color", "Label"), day_one.get_color("font_color", "Label"))
		assert_eq(day_seven.default_font_size, day_one.default_font_size)


func test_button_styleboxes_follow_the_tinted_face() -> void:
	var day_seven := DESKTOP_THEME.build("en", 100, &"after_hours", 1.0)
	var normal: StyleBoxFlat = day_seven.get_stylebox("normal", "Button")
	assert_eq(normal.bg_color, day_seven.get_color("face", "Desktop"))
	assert_ne(normal.bg_color, Color("151b25"))
	var focus: StyleBoxFlat = day_seven.get_stylebox("focus", "Button")
	assert_eq(focus.border_color, Color("a9935f"), "focus outline never tints")


func test_unknown_palette_still_returns_null() -> void:
	assert_null(DESKTOP_THEME.build("en", 100, &"unknown", 1.0))
```

- [ ] **Step 3: Run the test to verify it fails**

Run with `-gtest=res://tests/unit/test_desktop_theme_week_tint.gd`.
Expected: RED. `build` takes three arguments today, so the four-argument calls raise "Too many arguments" parse errors and the file does not load.

- [ ] **Step 4: Modify `DesktopTheme.build`**

Replace lines 1 to 15 of `scripts/ui/desktop/DesktopTheme.gd` (the header through the `roles` dictionary) so the file begins:

```gdscript
extends RefCounted

const ENGLISH := preload("res://assets/ui/contacts/fonts/source-sans-3-regular.ttf.woff2")
const SIMPLIFIED := preload("res://assets/ui/contacts/fonts/source-han-sans-sc-regular.otf")
const TRADITIONAL := preload("res://assets/ui/contacts/fonts/source-han-sans-hc-regular.otf")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")

static func build(locale: String, percent: int, palette: StringName = &"after_hours", week_tint: float = 0.0) -> Theme:
	if palette not in [&"after_hours", &"midnight"]: return null
	var result := Theme.new()
	result.default_font = {"en": ENGLISH, "zh-CN": SIMPLIFIED, "zh-HK": TRADITIONAL}.get(locale, ENGLISH)
	result.default_font_size = int(24 * percent / 100.0)
	var roles := {"habitat": Color("0d1514") if palette == &"midnight" else Color("0b0d13"), "face": Color("14201d") if palette == &"midnight" else Color("151b25"),
		"ink": Color("d8cfb7"), "structure": Color("657d89"),
		"focus": Color("a9935f"), "current": Color("789083")}
	roles = WEEK_TINT.apply(roles, week_tint)
```

The rest of the function (the `for role in roles:` loop onward) is unchanged.

- [ ] **Step 5: Run the test to verify it passes**

Run the new file. Expected: 4 passing. Then run the existing Day-1 consumers to prove exactness held:

```bash
... -gtest=res://tests/unit/test_desktop_theme_week_tint.gd,res://tests/integration/test_run_palette_host.gd -gexit
```

Expected: all passing (the palette host asserts `face == 151b25` / `14201d` at Day 1).

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/desktop/DesktopTheme.gd tests/unit/test_desktop_theme_week_tint.gd
git commit -m "feat(ui): DesktopTheme.build takes a week_tint, Day 1 unchanged"
```

---

### Task 3: Desktop shell passes the tint at boundaries

**Files:**
- Modify: `scripts/ui/ComputerDesktop.gd` (the `const` block near the top where `DESKTOP_THEME` is preloaded, and `_refresh_launcher` at lines 734-740)
- Test: `tests/integration/test_desktop_week_tint.gd`

**Interfaces:**
- Consumes: `DesktopTheme.build(locale, percent, palette, week_tint)` from Task 2; `WeekTint.tint_for_day` from Task 1; the desktop's existing `_day` field (`scripts/ui/ComputerDesktop.gd:58`), which is set by `configure_*` app bindings and by `dispatch_desktop_eviction` (line 683) on day advance; `test_run_palette_host.gd`'s static `make_captured_run(dark)` and its inner class `IsolatedDesktop`.
- Produces: nothing new; behaviour only.

- [ ] **Step 1: Claim the Beads task**

```bash
bd create "Week tint: desktop shell refresh passes tint from _day" -t task -p 2 -l ui --parent dwm-vky --silent
bd update <id> --claim
```

- [ ] **Step 2: Write the failing test**

Create `tests/integration/test_desktop_week_tint.gd`:

```gdscript
extends "res://addons/gut/test.gd"

const HOST_TEST := preload("res://tests/integration/test_run_palette_host.gd")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")


func _fixture() -> Dictionary:
	var run: Dictionary = HOST_TEST.make_captured_run(true)
	assert_true(run.get("ok", false), JSON.stringify(run))
	if not run.get("ok", false):
		return {}
	add_child_autofree(run.value.state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 720)
	add_child_autofree(viewport)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(HOST_TEST.IsolatedDesktop)
	assert_true(desktop.configure_run_configuration(run.value.state).ok)
	viewport.add_child(desktop)
	return {"desktop": desktop, "state": run.value.state}


func _settle() -> void:
	for frame in 3:
		await get_tree().process_frame


func test_day_one_desktop_theme_is_the_shipped_midnight_face() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	await _settle()
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), Color("14201d"))
	assert_eq(f.desktop.theme.get_color("habitat", "Desktop"), Color("0d1514"))


func test_day_advance_eviction_rebuilds_the_theme_with_the_day_seven_tint() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	await _settle()
	var evicted: Dictionary = f.desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 7})
	assert_true(evicted.get("ok", false), str(evicted))
	await _settle()
	var expected := DESKTOP_THEME.build("en", 100, &"midnight", WEEK_TINT.tint_for_day(7))
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), expected.get_color("face", "Desktop"))
	assert_ne(f.desktop.theme.get_color("face", "Desktop"), Color("14201d"), "Day 7 is colder than Day 1")
	assert_eq(f.desktop.theme.get_color("ink", "Desktop"), Color("d8cfb7"), "ink never tints")


func test_tint_only_changes_at_the_boundary_not_on_ordinary_refresh() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	await _settle()
	assert_true(f.desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 3}).ok)
	await _settle()
	var day_three: Color = f.desktop.theme.get_color("face", "Desktop")
	f.desktop._refresh_launcher()
	await _settle()
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), day_three, "an ordinary refresh reuses the same day, so the tint is unchanged")
	assert_eq(day_three, DESKTOP_THEME.build("en", 100, &"midnight", WEEK_TINT.tint_for_day(3)).get_color("face", "Desktop"))
```

- [ ] **Step 3: Run the test to verify it fails**

Run with `-gtest=res://tests/integration/test_desktop_week_tint.gd`.
Expected: the first test passes (Day 1 is already correct); the second and third fail because the desktop still builds with no tint, so `face` stays `14201d` after eviction. That is the RED that matters; note it in the task's Beads notes.

- [ ] **Step 4: Modify `ComputerDesktop`**

Near the top of `scripts/ui/ComputerDesktop.gd`, next to the existing `const DESKTOP_THEME := preload(...)` line, add:

```gdscript
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
```

In `_refresh_launcher` (line 740) replace

```gdscript
	theme = DESKTOP_THEME.build(_locale, percent, _run_palette)
```

with

```gdscript
	theme = DESKTOP_THEME.build(_locale, percent, _run_palette, WEEK_TINT.tint_for_day(_day))
```

No other line changes. `_day` is already updated on every boundary the spec names that the desktop can see (app binding at configure time, eviction on day advance); login and Load re-run `_configure_from_bootstrap`, which ends in `_refresh_launcher`.

- [ ] **Step 5: Run the test to verify it passes**

Run the new file: 3 passing. Then the regression net:

```bash
... -gtest=res://tests/integration/test_desktop_week_tint.gd,res://tests/integration/test_run_palette_host.gd,res://tests/unit/test_desktop_theme_week_tint.gd -gexit
```

Expected: all passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/ComputerDesktop.gd tests/integration/test_desktop_week_tint.gd
git commit -m "feat(desktop): shell theme follows the week tint at day boundaries"
```

---

### Task 4: Angela panel HUD follows the tint

**Files:**
- Modify: `scripts/ui/StatHud.gd:5` (consts) and `:112-121` (`_refresh_presentation`)
- Test: `tests/unit/test_stat_hud_week_tint.gd`

**Interfaces:**
- Consumes: `DesktopTheme.build(locale, percent, palette, week_tint)`; `WeekTint.tint_for_day`; the HUD's `_owner` object, whose `day` property and `day_changed` signal the HUD already binds (`StatHud.gd:48`, `:79`).
- Produces: nothing new; behaviour only. The HUD keeps building with the default `&"after_hours"` palette exactly as today (it is an opaque typographic HUD; palette binding for it is out of scope).

- [ ] **Step 1: Claim the Beads task**

```bash
bd create "Week tint: StatHud presentation follows owner day" -t task -p 2 -l ui --parent dwm-vky --silent
bd update <id> --claim
```

- [ ] **Step 2: Write the failing test**

Create `tests/unit/test_stat_hud_week_tint.gd`:

```gdscript
extends "res://addons/gut/test.gd"

const HUD := preload("res://scenes/shared/StatHud.tscn")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")


class OwnerFixture extends Node:
	signal day_changed(day: int)
	var day: int = 1
	var money: int = 0
	var coins: int = 0
	var condition_effects_today: Array = []
	var penalty_points_today: int = 0
	func get_stat_display_value(_stat: String) -> int: return 0
	func get_stat_display_max(_stat: String) -> int: return 9
	func advance_to(new_day: int) -> void:
		day = new_day
		day_changed.emit(new_day)


func _fixture() -> Dictionary:
	var owner := OwnerFixture.new()
	add_child_autofree(owner)
	var hud: Control = HUD.instantiate()
	hud.configure(owner)
	add_child_autofree(hud)
	return {"hud": hud, "owner": owner}


func test_day_one_hud_theme_is_the_shipped_face() -> void:
	var f := _fixture()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))


func test_day_changed_rebuilds_the_hud_theme_with_the_tint() -> void:
	var f := _fixture()
	f.owner.advance_to(7)
	var expected := DESKTOP_THEME.build("en", 100, &"after_hours", WEEK_TINT.tint_for_day(7))
	assert_eq(f.hud.theme.get_color("face", "Desktop"), expected.get_color("face", "Desktop"))
	assert_ne(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))
	assert_eq(f.hud.theme.get_color("ink", "Desktop"), Color("d8cfb7"), "ink never tints")


func test_same_day_refresh_keeps_the_cached_theme_instance() -> void:
	var f := _fixture()
	f.owner.advance_to(4)
	var built: Theme = f.hud.theme
	f.hud.refresh_all()
	assert_true(f.hud.theme == built, "no rebuild when locale, size and day are unchanged")
```

Check before writing: confirm the HUD scene path with `ls scenes/shared/StatHud.tscn`; if the scene lives elsewhere, use that path (the class is `scripts/ui/StatHud.gd`). Confirm `refresh_all` is the public refresh entry point at `StatHud.gd` (it is the connected slot at line 55).

- [ ] **Step 3: Run the test to verify it fails**

Run with `-gtest=res://tests/unit/test_stat_hud_week_tint.gd`.
Expected: test 1 and 3 pass; test 2 fails with `face` still `151b25` after `advance_to(7)`. RED on the law under test.

- [ ] **Step 4: Modify `StatHud`**

After line 5 (`const DESKTOP_THEME := preload(...)`) add:

```gdscript
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
```

Replace `_refresh_presentation` (lines 112-121, through the `theme = DESKTOP_THEME.build(_locale, percent)` line) with:

```gdscript
func _refresh_presentation() -> void:
	_locale = str(_localization.get_locale()).replace("_", "-") if is_instance_valid(_localization) and _localization.has_method("get_locale") else "en"
	if not COPY.has(_locale):
		_locale = "en"
	var percent := int(_profile.get_preference("preferences.accessibility.text_size", 100)) if is_instance_valid(_profile) and _profile.has_method("get_preference") else 100
	var day: Variant = _owner.get("day") if is_instance_valid(_owner) else null
	var tint: float = WEEK_TINT.tint_for_day(int(day)) if typeof(day) == TYPE_INT else 0.0
	var presentation_key := "%s:%d:%.2f" % [_locale, percent, tint]
	if presentation_key == _presentation_key:
		return
	_presentation_key = presentation_key
	theme = DESKTOP_THEME.build(_locale, percent, &"after_hours", tint)
```

The lines that follow (the `FontVariation` with `tnum`) are unchanged.

- [ ] **Step 5: Run the test to verify it passes**

Run the new file: 3 passing. Then run every suite that touches the HUD or the shell scene to prove nothing else moved:

```bash
... -gtest=res://tests/unit/test_stat_hud_week_tint.gd,res://tests/integration/test_ui_art_placements.gd,res://tests/integration/test_run_palette_host.gd -gexit
```

Expected: all passing (the art placement test asserts the Angela panel's three art children, which are untouched).

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/StatHud.gd tests/unit/test_stat_hud_week_tint.gd
git commit -m "feat(hud): Angela panel theme follows the week tint on day_changed"
```

---

### Task 5: Full-tree confirmation and evidence note

**Files:**
- No source changes. Beads notes only.

- [ ] **Step 1: Run the scene smoke and the full unit tree**

```bash
"C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path . -s res://tests/smoke_load_scenes.gd
"C:/Program Files/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

Expected: `SMOKE_LOAD_SCENES: PASS (26/26)`; the unit tree passes with the same pre-existing failures as at the branch point, if any (record the branch-point totals first by running the same command before Task 1, and compare).

- [ ] **Step 2: Render Day 1 and Day 7 evidence**

Copy `tests/ui/render_art_placements.gd` to `temp-artifacts/render_week_tint.gd`, change its evidence folder to `user://evidence/week_tint`, remove the `_place` lines for `shell.*`, `character.priscilla` and `background.dating.solo.priscilla_day1`, and before the `MAIN.instantiate()` capture add a second capture after `shell.get_node("%ComputerDesktop").dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 7})` (find the desktop node path in `scenes/main/MainGameScene.tscn`; use `find_child("ComputerDesktop", true, false)` if the name differs). Run with `--rendering-method gl_compatibility` (not headless). Copy the Day 1 and Day 7 shell captures to `evidence/week_tint/renders/`. Day 1 must be pixel-identical to `evidence/found_paintings/renders/03-shell-layers.png` except for the clock.

- [ ] **Step 3: Record the stale evidence hashes**

```bash
bd update dwm-vky --append-notes "Week tint increment 1 landed: WeekTint helper, DesktopTheme week_tint, ComputerDesktop and StatHud pass tint at boundaries. Files hashed in tools/desktop_shell, tools/stat_hud, tools/title_resume, tools/title_shell evidence result.json are now stale (DesktopTheme.gd, StatHud.gd, ComputerDesktop.gd); re-seal once after all amendment increments per Section 13."
```

- [ ] **Step 4: Close the child tasks**

```bash
bd close <task-1-id> --reason "WeekTint helper with 8 unit tests, mutation-proved"
bd close <task-2-id> --reason "DesktopTheme.build week_tint, Day 1 exact, palette host green"
bd close <task-3-id> --reason "desktop shell passes tint at eviction boundary, 3 integration tests"
bd close <task-4-id> --reason "StatHud keyed on tint, rebuilds on day_changed"
```

Leave `dwm-vky` open; the second plan (Settings, Schedule, Shop, Backup, Minesweeper, Pause, Witnessed) follows.

---

## Self-review

**Spec coverage (Section 5):** 5.1 curve → Task 1 `CURVE`; 5.2 room roles, endpoints, hue fixed, high-contrast zero, CVD lightness-only → Task 1 `apply`; 5.3 binding to run mode → untouched, the desktop still chooses `_run_palette` from `dark_mode`; 5.4 never animates, exempt from Steady Interface and Reduced Motion → no timers or tweens anywhere; boundaries → Tasks 3 and 4 use only existing boundary refresh paths. Not covered here by design: the six other surfaces (second plan) and the `resolve_tinted` registry entry point (only needed when Settings joins).

**Placeholder scan:** none; every code step is complete.

**Type consistency:** `WeekTint.tint_for_day(day: int) -> float` and `WeekTint.apply(roles: Dictionary, tint: float, high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary` are used with those exact names and arities in Tasks 2, 3 and 4. `DesktopTheme.build`'s fourth parameter is `week_tint: float = 0.0` in Task 2 and is called positionally with a float in Tasks 3 and 4.
