# Title Art and Bottom-Up Caption Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the exact empty title-art placement and reusable bottom-up narrative caption components authorized by section 10.5 of the accepted 2026-08-14 amendment.

**Architecture:** The title slice is one inert, childless placement node owned by `MenuScene`, with host visibility and exact source-focus restoration centralized in that scene. The caption slice separates a presentation-only semantic stack from a Dialogic adapter: immutable projections remain current-first in the scene tree for assistive order, a custom container places them oldest-to-current from top to bottom, and an explicit non-default Dialogic style replaces the fallback textbox with exactly one project-owned text owner. Stable caption identity comes from an injected event-index registry rather than prose or Dialogic labels.

**Tech Stack:** Godot 4.6.3-stable-mono, GDScript, GUT, Dialogic 2.0-Alpha-19, isolated PowerShell Godot runner.

## Global Constraints

- Implement only the initial partial evidence in `docs/design/2026-08-14-title-art-placement-and-bottom-up-scene-caption-rhythm-amendment.md` section 10.5.
- The logical verification canvas is exactly `1280×720`; the title presenter is exactly `Rect2(320, 64, 960, 656)` and remains empty.
- Do not add title image, title copy, placeholder copy, texture binding, crop law, manifest entry, or runtime asset.
- Do not change `project.godot`, `.beads/`, any HTML, existing production timeline, existing `DialogueBox`, Gallery, ending return, window matte/scaler, or global Dialogic style activation.
- Keep `New Acc` as initial title focus; after closing Log in or Settings, restore the exact initiating ledger row.
- Single-language visible caption depth is three semantic beats; Dual Language visible depth is one semantic beat containing Primary then Secondary.
- Dialogic append fragments extend the current semantic card and never create another card.
- Exactly one live node in the active custom style may belong to `dialogic_dialog_text`; never combine the bundled fallback VN textbox with the project-owned caption owner.
- The custom style is loaded only by explicit `res://dialogic/styles/NarrativeCaptionStyle.tres` path in this slice; it is not registered or made default.
- Every test and import command runs through `tools/testing/Invoke-IsolatedGodot.ps1`; never launch Godot directly against production user data.
- Preserve all unrelated dirty work. Stage and commit only the exact paths named by the task being committed.

## File Map

### Title slice

- Modify `scenes/menu/MenuScene.tscn`: own the empty presenter and close the ledger at x=320.
- Modify `scripts/ui/MenuScene.gd`: centralize Log in/Settings presenter replacement and source-focus return.
- Create `tests/scene/test_menu_title_art_presenter.gd`: deterministic 1280×720 geometry, inertness, host, and focus evidence.

### Caption slice

- Create `scripts/ui/narrative/NarrativeCaptionStackContainer.gd`: current-first child order with bottom-up physical layout.
- Create `scripts/ui/narrative/NarrativeCaptionLayer.gd`: immutable session/language projection and three-card rendering.
- Create `scenes/shared/narrative/NarrativeCaptionLayer.tscn`: reusable transparent caption deck with one Dialogic text owner.
- Create `scripts/narrative/DialogicCaptionProjectionSource.gd`: fail-closed event-index-to-semantic-ID projection.
- Create `scripts/ui/narrative/DialogicNarrativeCaptionLayer.gd`: signal lifecycle adapter from Dialogic to the presenter.
- Create `scenes/dialogic/NarrativeCaptionDialogicLayer.tscn`: Dialogic layout-layer wrapper for the reusable presenter.
- Create `dialogic/styles/NarrativeCaptionStyle.tres`: complete opt-in clone of the bundled style with only its textbox layer replaced.
- Create `tests/fixtures/dialogic/narrative_caption_style_fixture.dtl`: physical four-beat/five-segment fixture.
- Create `tests/unit/test_narrative_caption_layer.gd`: stack, append, Dual, immutability, and geometry evidence.
- Create `tests/unit/test_dialogic_caption_projection_source.gd`: identity registry and failure evidence.
- Create `tests/unit/test_dialogic_narrative_caption_layer.gd`: fake-runtime signal lifecycle evidence.
- Create `tests/integration/test_narrative_caption_dialogic_style.gd`: real Dialogic style/timeline evidence.
- Modify `tests/smoke_load_scenes.gd`: load both new scenes.

---

### Task 1: Empty title-art placement and hosted replacement

**Files:**
- Modify: `scenes/menu/MenuScene.tscn`
- Modify: `scripts/ui/MenuScene.gd`
- Test: `tests/scene/test_menu_title_art_presenter.gd`

**Interfaces:**
- Consumes: existing `%LogInButton`, `%SettingButton`, `%BackupAppHost`, `%SettingHost`, `BackupApp.window_hidden`, and Settings `%CloseButton.pressed`.
- Produces: owned `%TitleArtPresenter`, `MenuScene.close_active_title_destination() -> void`, and the private `_show_title_destination(host: Control, source: BaseButton) -> void` seam.

- [ ] **Step 1: Record the byte-safe protected-path baseline**

Run the complete aggregate command in Execution Appendix D and preserve `PROTECTED_COUNT` plus `PROTECTED_AGGREGATE` in the execution transcript. The aggregate is calculated over the sorted path-plus-per-file-hash lines, so the final scope audit compares bytes and the protected path set rather than assuming a clean worktree or comparing status letters.

- [ ] **Step 2: Write the failing title scene tests**

Create `tests/scene/test_menu_title_art_presenter.gd` with this fixture and assertions:

```gdscript
extends "res://addons/gut/test.gd"

const MENU_SCENE := preload("res://scenes/menu/MenuScene.tscn")

func _make_fixture() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var menu := MENU_SCENE.instantiate() as MenuScene
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	return {"viewport": viewport, "menu": menu}

func test_empty_presenter_has_exact_geometry_and_is_inert() -> void:
	var fixture := await _make_fixture()
	var presenter := (fixture.menu as MenuScene).get_node_or_null("%TitleArtPresenter") as Control
	assert_not_null(presenter)
	if presenter == null:
		return
	assert_eq(presenter.get_rect(), Rect2(320.0, 64.0, 960.0, 656.0))
	assert_true(presenter.visible)
	assert_eq(presenter.get_child_count(), 0)
	assert_null(presenter.get_script())
	assert_eq(presenter.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(presenter.focus_mode, Control.FOCUS_NONE)
	assert_eq(presenter.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(presenter.tooltip_text, "")
	assert_eq(presenter.accessibility_name, "")
	assert_eq(presenter.accessibility_description, "")
	assert_eq(int(presenter.accessibility_live), 0)

func test_ledger_ends_at_presenter_edge_without_overlap() -> void:
	var fixture := await _make_fixture()
	var menu := fixture.menu as MenuScene
	var ledger := menu.get_node("MenuPanel") as Control
	var presenter := menu.get_node("%TitleArtPresenter") as Control
	assert_eq(ledger.get_rect(), Rect2(0.0, 0.0, 320.0, 720.0))
	assert_false(ledger.get_rect().intersection(presenter.get_rect()).has_area())

func test_new_acc_remains_initial_focus() -> void:
	var fixture := await _make_fixture()
	assert_same(
		(fixture.viewport as SubViewport).gui_get_focus_owner(),
		(fixture.menu as MenuScene).get_node("%NewAccButton")
	)

func test_log_in_close_restores_presenter_and_exact_source_focus() -> void:
	var fixture := await _make_fixture()
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%LogInButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	var host := menu.get_node("%BackupAppHost") as Control
	assert_true(host.visible)
	(host.get_child(0) as BackupApp).hide_window()
	await get_tree().process_frame
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_false(host.visible)
	assert_same((fixture.viewport as SubViewport).gui_get_focus_owner(), source)

func test_settings_close_and_cached_reopen_preserve_presenter_and_source() -> void:
	var fixture := await _make_fixture()
	var menu := fixture.menu as MenuScene
	var source := menu.get_node("%SettingButton") as Button
	source.grab_focus()
	source.pressed.emit()
	await get_tree().process_frame
	var host := menu.get_node("%SettingHost") as Control
	var child := host.get_child(0) as Setting
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	(child.get_node("%CloseButton") as Button).pressed.emit()
	await get_tree().process_frame
	assert_true((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_false(host.visible)
	assert_same((fixture.viewport as SubViewport).gui_get_focus_owner(), source)
	source.pressed.emit()
	await get_tree().process_frame
	assert_false((menu.get_node("%TitleArtPresenter") as Control).visible)
	assert_true(host.visible)
	assert_true(child.visible)
```

The tests intentionally make no assertion that ledger focus remains active while a hosted destination owns the workfield; they prove only exact return focus and do not redefine the retained host-first-focus law.

- [ ] **Step 3: Run the title tests and observe RED**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'title_art_presenter_red' -LogName 'title-art-presenter-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scene/test_menu_title_art_presenter.gd','-gexit')
```

Expected: FAIL because `%TitleArtPresenter` does not exist. The ledger test also reports the current `Rect2(0, 0, 512, 216)` once guarded beyond the missing node.

- [ ] **Step 4: Add the empty placement and exact ledger rectangle**

Insert this node before `MenuPanel` in `scenes/menu/MenuScene.tscn`:

```ini
[node name="TitleArtPresenter" type="Control" parent="."]
unique_name_in_owner = true
process_mode = 4
layout_mode = 0
offset_left = 320.0
offset_top = 64.0
offset_right = 1280.0
offset_bottom = 720.0
mouse_filter = 2
focus_mode = 0
```

Replace the `MenuPanel` anchors with fixed logical offsets:

```ini
[node name="MenuPanel" type="PanelContainer" parent="."]
layout_mode = 0
offset_right = 320.0
offset_bottom = 720.0
```

Do not add a texture property, child, label, script, tooltip, accessibility metadata, or art loader.

- [ ] **Step 5: Centralize destination visibility and focus restoration**

Add these exact members and helpers to `scripts/ui/MenuScene.gd`:

```gdscript
@onready var _title_art_presenter: Control = %TitleArtPresenter

var _active_title_host: Control = null
var _active_title_source: BaseButton = null

func _show_title_destination(host: Control, source: BaseButton) -> void:
	if is_instance_valid(_active_title_host) and _active_title_host != host:
		_active_title_host.hide()
	_title_art_presenter.hide()
	for child in host.get_children():
		child.show()
	host.show()
	_active_title_host = host
	_active_title_source = source

func close_active_title_destination() -> void:
	var source := _active_title_source
	if is_instance_valid(_backup_app_host):
		_backup_app_host.hide()
	if is_instance_valid(_setting_host):
		_setting_host.hide()
	_active_title_host = null
	_active_title_source = null
	_title_art_presenter.show()
	if is_instance_valid(source):
		source.call_deferred("grab_focus")
```

Change `_on_log_in_pressed()` so it instantiates once, connects `window_hidden` once, then calls the helper:

```gdscript
func _on_log_in_pressed() -> void:
	if not is_instance_valid(_backup_app_instance):
		_backup_app_instance = BACKUP_APP_SCENE.instantiate()
		_backup_app_host.add_child(_backup_app_instance)
		var backup_window := _backup_app_instance as AppWindowBase
		if backup_window != null and not backup_window.window_hidden.is_connected(close_active_title_destination):
			backup_window.window_hidden.connect(close_active_title_destination)
	_show_title_destination(_backup_app_host, _log_in_button)
```

Change `_on_setting_pressed()` similarly, using the existing Settings close control:

```gdscript
func _on_setting_pressed() -> void:
	if not is_instance_valid(_setting_instance):
		_setting_instance = SETTING_SCENE.instantiate()
		_setting_host.add_child(_setting_instance)
		var close_button := _setting_instance.get_node("%CloseButton") as Button
		if not close_button.pressed.is_connected(close_active_title_destination):
			close_button.pressed.connect(close_active_title_destination)
	_show_title_destination(_setting_host, _setting_button)
```

Replace the host branches of `_unhandled_input()` with one close seam:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_active_title_host):
		close_active_title_destination()
		get_viewport().set_input_as_handled()
```

Keep `_close_backup_app()` and `_close_setting()` only if another current caller still needs them; otherwise remove those now-private dead helpers. Do not modify `Setting.gd`, `BackupApp.gd`, or their scenes.

- [ ] **Step 6: Run title tests and focused regressions GREEN**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'title_art_presenter_green' -LogName 'title-art-presenter-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scene/test_menu_title_art_presenter.gd,res://tests/scene/test_settings_localization_scene.gd','-gexit')
```

Expected: PASS with no parser errors or leaked controls.

- [ ] **Step 7: Review and commit Task 1**

Review only the three task paths against the title portion of section 10.5. Then stage and commit only:

```powershell
git add -- scenes/menu/MenuScene.tscn scripts/ui/MenuScene.gd tests/scene/test_menu_title_art_presenter.gd
git commit -m "feat: add empty title art presenter"
```

---

### Task 2: Reusable semantic caption stack

**Files:**
- Create: `scripts/ui/narrative/NarrativeCaptionStackContainer.gd`
- Create: `scripts/ui/narrative/NarrativeCaptionLayer.gd`
- Create: `scenes/shared/narrative/NarrativeCaptionLayer.tscn`
- Test: `tests/unit/test_narrative_caption_layer.gd`

**Interfaces:**
- Consumes: immutable projection dictionaries with `session_id`, `semantic_id`, `primary_text`, and `secondary_text`.
- Produces: `reset_session`, `publish_beat`, `append_current`, `clear_session`, visual/assistive semantic-ID queries, immutable projection lookup, and `get_current_text_owner()`.

- [ ] **Step 1: Write failing scene/stack tests**

Create `tests/unit/test_narrative_caption_layer.gd`. Use a dynamically loaded scene path so the test parses before the scene exists:

```gdscript
extends "res://addons/gut/test.gd"

const SCENE_PATH := "res://scenes/shared/narrative/NarrativeCaptionLayer.tscn"

func _make_layer() -> Control:
	var packed := load(SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return null
	var layer := packed.instantiate() as Control
	add_child_autofree(layer)
	layer.size = Vector2(1280.0, 720.0)
	await get_tree().process_frame
	return layer

func _projection(id: StringName, primary: String, secondary := "") -> Dictionary:
	return {
		"session_id": &"fixture.session",
		"semantic_id": id,
		"primary_text": primary,
		"secondary_text": secondary,
	}

func test_single_language_publishes_oldest_to_current_but_keeps_current_first_semantics() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	assert_true(layer.call("reset_session", &"fixture.session", &"single").ok)
	assert_true(layer.call("publish_beat", _projection(&"one", "One")).ok)
	await get_tree().process_frame
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one"])
	var stack := layer.get_node("%CaptionStack") as Control
	var current := layer.get_node("%CurrentCard") as Control
	assert_almost_eq(current.position.y + current.size.y, stack.size.y, 0.01)
	assert_true(layer.call("publish_beat", _projection(&"two", "Two")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one", &"two"])
	assert_true(layer.call("publish_beat", _projection(&"three", "Three")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one", &"two", &"three"])
	assert_eq(layer.call("get_assistive_semantic_ids"), [&"three", &"two", &"one"])
	assert_almost_eq(current.position.y + current.size.y, stack.size.y, 0.01)

func test_fourth_beat_evicts_only_oldest_visible_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	for row in [[&"one", "One"], [&"two", "Two"], [&"three", "Three"], [&"four", "Four"]]:
		assert_true(layer.call("publish_beat", _projection(row[0], row[1])).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"two", &"three", &"four"])
	assert_eq(layer.call("get_assistive_semantic_ids"), [&"four", &"three", &"two"])
	assert_true((layer.call("get_projection", &"one") as Dictionary).is_empty())

func test_append_extends_current_in_both_languages_without_creating_a_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	layer.call("publish_beat", _projection(&"single", "First"))
	assert_true(layer.call("append_current", _projection(&"single", " continued")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"single"])
	assert_eq((layer.call("get_projection", &"single") as Dictionary).primary_text, "First continued")
	layer.call("reset_session", &"fixture.session", &"dual")
	layer.call("publish_beat", _projection(&"one", "Primary", "Secondary"))
	assert_true(layer.call("append_current", _projection(&"one", " plus", " 續")).ok)
	assert_eq(layer.call("get_visual_semantic_ids"), [&"one"])
	assert_eq((layer.call("get_projection", &"one") as Dictionary).primary_text, "Primary plus")
	assert_eq((layer.call("get_projection", &"one") as Dictionary).secondary_text, "Secondary 續")

func test_dual_mode_keeps_exactly_one_semantic_card() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"dual")
	for row in [[&"one", "One", "一"], [&"two", "Two", "二"], [&"three", "Three", "三"], [&"four", "Four", "四"]]:
		assert_true(layer.call("publish_beat", _projection(row[0], row[1], row[2])).ok)
		assert_eq(layer.call("get_visual_semantic_ids"), [row[0]])
		assert_eq(layer.call("get_assistive_semantic_ids"), [row[0]])
	assert_true((layer.get_node("%CurrentSecondary") as Control).visible)

func test_projection_storage_is_immutable_and_append_fails_closed_on_wrong_identity() -> void:
	var layer := await _make_layer()
	if layer == null:
		return
	layer.call("reset_session", &"fixture.session", &"single")
	var input := _projection(&"one", "Original")
	layer.call("publish_beat", input)
	input.primary_text = "Mutated"
	assert_eq((layer.call("get_projection", &"one") as Dictionary).primary_text, "Original")
	var failure: Dictionary = layer.call("append_current", _projection(&"other", "Wrong"))
	assert_false(failure.ok)
	assert_eq(failure.code, &"caption_identity_mismatch")
```

- [ ] **Step 2: Run the caption unit test and observe RED**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'caption_layer_red' -LogName 'caption-layer-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_narrative_caption_layer.gd','-gexit')
```

Expected: FAIL because `NarrativeCaptionLayer.tscn` and its class do not exist.

- [ ] **Step 3: Implement the current-first/bottom-up container**

Create `scripts/ui/narrative/NarrativeCaptionStackContainer.gd`:

```gdscript
extends Container
class_name NarrativeCaptionStackContainer

@export var separation: float = 8.0

func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	var visible_count := 0
	for child in get_children():
		if child is Control and (child as Control).visible:
			var minimum := (child as Control).get_combined_minimum_size()
			result.x = maxf(result.x, minimum.x)
			result.y += minimum.y
			visible_count += 1
	if visible_count > 1:
		result.y += separation * float(visible_count - 1)
	return result

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var bottom := size.y
	for child in get_children():
		if not child is Control or not (child as Control).visible:
			continue
		var control := child as Control
		var height := control.get_combined_minimum_size().y
		fit_child_in_rect(control, Rect2(0.0, bottom - height, size.x, height))
		bottom -= height + separation
```

The scene tree order is Current, Previous, Oldest. Iterating that order while subtracting from the bottom keeps semantic/assistive order current-first and physical order oldest-to-current.

- [ ] **Step 4: Implement immutable caption publication**

Create `scripts/ui/narrative/NarrativeCaptionLayer.gd` with this public contract and core implementation:

```gdscript
extends Control
class_name NarrativeCaptionLayer

const LANGUAGE_SINGLE: StringName = &"single"
const LANGUAGE_DUAL: StringName = &"dual"

@onready var _stack: NarrativeCaptionStackContainer = %CaptionStack
@onready var _cards: Array[Control] = [%CurrentCard, %PreviousCard, %OldestCard]
@onready var _primary_labels: Array[RichTextLabel] = [%CurrentPrimary, %PreviousPrimary, %OldestPrimary]
@onready var _secondary_labels: Array[RichTextLabel] = [%CurrentSecondary, %PreviousSecondary, %OldestSecondary]

var _session_id: StringName = &""
var _language_mode: StringName = LANGUAGE_SINGLE
var _projections: Array[Dictionary] = []

func reset_session(session_id: StringName, language_mode: StringName = LANGUAGE_SINGLE) -> Dictionary:
	if session_id == &"":
		return {"ok": false, "code": &"caption_session_required"}
	if language_mode not in [LANGUAGE_SINGLE, LANGUAGE_DUAL]:
		return {"ok": false, "code": &"caption_language_mode_unknown"}
	_session_id = session_id
	_language_mode = language_mode
	_projections.clear()
	_render()
	return {"ok": true, "code": &"caption_session_reset"}

func publish_beat(projection: Dictionary) -> Dictionary:
	var validated := _validate_projection(projection)
	if not validated.ok:
		return validated
	var owned: Dictionary = projection.duplicate(true)
	if _language_mode == LANGUAGE_DUAL:
		_projections.assign([owned])
	else:
		_projections.push_front(owned)
		if _projections.size() > 3:
			_projections.resize(3)
	_render()
	return {"ok": true, "code": &"caption_published"}

func append_current(fragment_projection: Dictionary) -> Dictionary:
	var validated := _validate_projection(fragment_projection)
	if not validated.ok:
		return validated
	if _projections.is_empty() or StringName(_projections[0].semantic_id) != StringName(fragment_projection.semantic_id):
		return {"ok": false, "code": &"caption_identity_mismatch"}
	var updated: Dictionary = _projections[0].duplicate(true)
	updated.primary_text = str(updated.primary_text) + str(fragment_projection.primary_text)
	updated.secondary_text = str(updated.secondary_text) + str(fragment_projection.secondary_text)
	_projections[0] = updated
	_render()
	return {"ok": true, "code": &"caption_appended"}

func clear_session() -> void:
	_session_id = &""
	_projections.clear()
	if is_node_ready():
		_render()

func get_visual_semantic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for index in range(_projections.size() - 1, -1, -1):
		result.append(StringName(_projections[index].semantic_id))
	return result

func get_assistive_semantic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for projection in _projections:
		result.append(StringName(projection.semantic_id))
	return result

func get_projection(semantic_id: StringName) -> Dictionary:
	for projection in _projections:
		if StringName(projection.semantic_id) == semantic_id:
			return projection.duplicate(true)
	return {}

func get_current_text_owner() -> DialogicNode_DialogText:
	return %CurrentPrimary as DialogicNode_DialogText

func _validate_projection(projection: Dictionary) -> Dictionary:
	for key in ["session_id", "semantic_id", "primary_text", "secondary_text"]:
		if not projection.has(key):
			return {"ok": false, "code": &"caption_projection_incomplete"}
	if StringName(projection.session_id) != _session_id:
		return {"ok": false, "code": &"caption_session_mismatch"}
	if StringName(projection.semantic_id) == &"":
		return {"ok": false, "code": &"caption_identity_required"}
	return {"ok": true, "code": &"caption_projection_valid"}

func _render() -> void:
	for index in _cards.size():
		var shown := index < _projections.size()
		_cards[index].visible = shown
		if not shown:
			_primary_labels[index].text = ""
			_secondary_labels[index].text = ""
			continue
		var projection := _projections[index]
		var primary := str(projection.primary_text)
		# Dialogic has already started revealing the current owner before its
		# text_started signal. Avoid reassigning identical text so reveal state survives.
		if _primary_labels[index].text != primary:
			_primary_labels[index].text = primary
		_secondary_labels[index].text = str(projection.secondary_text)
		_secondary_labels[index].visible = _language_mode == LANGUAGE_DUAL and index == 0
	_stack.queue_sort()
```

- [ ] **Step 5: Build the transparent reusable scene**

Create `scenes/shared/narrative/NarrativeCaptionLayer.tscn` with this exact node topology and properties:

```text
NarrativeCaptionLayer (Control, full rect, mouse ignore, NarrativeCaptionLayer.gd)
└── CaptionDeck (Control, anchors full width, offsets top=448 bottom=-64, mouse ignore)
    └── CaptionStack (NarrativeCaptionStackContainer, full rect)
        ├── CurrentCard (MarginContainer, minimum height 64, mouse ignore)
        │   └── VBoxContainer
        │       ├── CurrentPrimary (DialogicNode_DialogText, fit_content, textbox_root=self, start_hidden=false)
        │       └── CurrentSecondary (RichTextLabel, fit_content, hidden)
        ├── PreviousCard (MarginContainer, minimum height 56, mouse ignore)
        │   └── VBoxContainer
        │       ├── PreviousPrimary (RichTextLabel, fit_content)
        │       └── PreviousSecondary (RichTextLabel, fit_content, hidden)
        └── OldestCard (same plain-label structure as PreviousCard)
```

Use `unique_name_in_owner = true` for the stack, all three cards, and all six labels. Do not add a `DialogicNode_NameLabel`, opaque StyleBox, focusable control, speaker copy, animation player, or a second `DialogicNode_DialogText`. Give the root and deck `mouse_filter = 2`, and give every RichTextLabel `focus_mode = 0` and `mouse_filter = 2`.

- [ ] **Step 6: Run Task 2 GREEN**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'caption_layer_green' -LogName 'caption-layer-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_narrative_caption_layer.gd','-gexit')
```

Expected: PASS; one/two/three/four-beat, append, Dual, immutable storage, and bottom alignment all hold.

- [ ] **Step 7: Review and commit Task 2**

Review the four task paths for projection-only ownership and one Dialogic text owner. Then stage and commit only:

```powershell
git add -- scripts/ui/narrative/NarrativeCaptionStackContainer.gd scripts/ui/narrative/NarrativeCaptionLayer.gd scenes/shared/narrative/NarrativeCaptionLayer.tscn tests/unit/test_narrative_caption_layer.gd
git commit -m "feat: add bottom-up narrative caption layer"
```

---

### Task 3: Fail-closed Dialogic bridge and explicit custom style

**Files:**
- Create: `scripts/narrative/DialogicCaptionProjectionSource.gd`
- Create: `scripts/ui/narrative/DialogicNarrativeCaptionLayer.gd`
- Create: `scenes/dialogic/NarrativeCaptionDialogicLayer.tscn`
- Create: `dialogic/styles/NarrativeCaptionStyle.tres`
- Create: `tests/fixtures/dialogic/narrative_caption_style_fixture.dtl`
- Create: `tests/unit/test_dialogic_caption_projection_source.gd`
- Create: `tests/unit/test_dialogic_narrative_caption_layer.gd`
- Create: `tests/integration/test_narrative_caption_dialogic_style.gd`

**Interfaces:**
- Consumes: Task 2 `NarrativeCaptionLayer` API, Dialogic `timeline_started`, `timeline_ended`, `Text.text_started(info)`, and `current_event_idx`.
- Produces: `DialogicCaptionProjectionSource.configure/get_session_projection/project_text`; `DialogicNarrativeCaptionLayer.bind_runtime/unbind_runtime/get_presenter/get_last_failure`; one explicit style resource and one physical fixture.

- [ ] **Step 1: Write projection-source and adapter RED tests**

Create `tests/unit/test_dialogic_caption_projection_source.gd` with exact cases for:

```gdscript
var source_script := load("res://scripts/narrative/DialogicCaptionProjectionSource.gd") as Script
assert_not_null(source_script)
if source_script == null:
	return
var source := source_script.new()
var configured: Dictionary = source.configure(
	&"fixture.session",
	&"single",
	[
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 1, "event_kind": "signal", "semantic_id": &"fixture.signal"},
	]
)
assert_true(configured.ok)
var projected: Dictionary = source.project_text(0, {"text": "Words", "append": false})
assert_true(projected.ok)
assert_eq(projected.projection.semantic_id, &"fixture.caption.one")
assert_eq(projected.projection.primary_text, "Words")
assert_false(source.project_text(99, {"text": "same prose", "append": false}).ok)
assert_eq(source.project_text(1, {"text": "same prose", "append": false}).code, &"unknown_caption_event")
```

Also assert duplicate indices, empty IDs, unsupported modes, and mutated caller dictionaries fail or cannot mutate configured state.

Create `tests/unit/test_dialogic_narrative_caption_layer.gd` with local fake runtime/text subsystem classes exposing only the three required signals, `current_event_idx`, and `get_subsystem("Text")`. Assert:

```gdscript
var adapter_scene := load("res://scenes/dialogic/NarrativeCaptionDialogicLayer.tscn") as PackedScene
assert_not_null(adapter_scene)
if adapter_scene == null:
	return
var adapter := adapter_scene.instantiate()
add_child_autofree(adapter)
await get_tree().process_frame
assert_true(adapter.bind_runtime(runtime, source).ok)
assert_true(adapter.bind_runtime(runtime, source).ok)
assert_eq(runtime.timeline_started.get_connections().size(), 1)
assert_eq(runtime.timeline_ended.get_connections().size(), 1)
assert_eq(runtime.text.text_started.get_connections().size(), 1)
runtime.timeline_started.emit()
runtime.current_event_idx = 0
runtime.text.text_started.emit({"text": "First", "append": false})
assert_eq(adapter.get_presenter().get_visual_semantic_ids(), [&"fixture.caption.one"])
runtime.text.text_started.emit({"text": " plus", "append": true})
assert_eq(adapter.get_presenter().get_projection(&"fixture.caption.one").primary_text, "First plus")
runtime.timeline_ended.emit()
assert_true(adapter.get_presenter().get_visual_semantic_ids().is_empty())
```

Add a second timeline-start assertion proving stale cards are cleared, and an unbind assertion proving every connection count returns to zero.

- [ ] **Step 2: Run bridge unit tests and observe RED**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'caption_bridge_red' -LogName 'caption-bridge-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dialogic_caption_projection_source.gd,res://tests/unit/test_dialogic_narrative_caption_layer.gd','-gexit')
```

Expected: FAIL because both scripts and the wrapper scene are absent.

- [ ] **Step 3: Implement the event-index projection source**

Create `scripts/narrative/DialogicCaptionProjectionSource.gd`:

```gdscript
extends RefCounted
class_name DialogicCaptionProjectionSource

var _session_id: StringName = &""
var _language_mode: StringName = &"single"
var _records: Dictionary = {}

func configure(session_id: StringName, language_mode: StringName, event_records: Array[Dictionary]) -> Dictionary:
	if session_id == &"" or language_mode not in [&"single", &"dual"]:
		return {"ok": false, "code": &"caption_source_configuration_invalid"}
	var candidate := {}
	for record in event_records:
		if not record.has_all(["event_index", "event_kind", "semantic_id"]):
			return {"ok": false, "code": &"caption_event_record_incomplete"}
		var index := int(record.event_index)
		if candidate.has(index) or StringName(record.semantic_id) == &"":
			return {"ok": false, "code": &"caption_event_record_invalid"}
		candidate[index] = record.duplicate(true)
	_session_id = session_id
	_language_mode = language_mode
	_records = candidate
	return {"ok": true, "code": &"caption_source_configured"}

func get_session_projection() -> Dictionary:
	return {"session_id": _session_id, "language_mode": _language_mode}

func project_text(event_index: int, text_info: Dictionary) -> Dictionary:
	var record: Dictionary = _records.get(event_index, {})
	if record.is_empty() or str(record.event_kind) != "text":
		return {"ok": false, "code": &"unknown_caption_event"}
	if not text_info.has("text") or not text_info.has("append"):
		return {"ok": false, "code": &"caption_text_info_incomplete"}
	return {
		"ok": true,
		"code": &"caption_text_projected",
		"append": bool(text_info.append),
		"projection": {
			"session_id": _session_id,
			"semantic_id": StringName(record.semantic_id),
			"primary_text": str(text_info.text),
			"secondary_text": str(text_info.get("secondary_text", "")),
		},
	}
```

- [ ] **Step 4: Implement the Dialogic layout adapter**

Create `scripts/ui/narrative/DialogicNarrativeCaptionLayer.gd`:

```gdscript
extends DialogicLayoutLayer
class_name DialogicNarrativeCaptionLayer

@onready var _presenter: NarrativeCaptionLayer = %NarrativeCaptionLayer

var _runtime: Node = null
var _text_subsystem: Node = null
var _source: DialogicCaptionProjectionSource = null
var _last_failure: Dictionary = {}

func bind_runtime(runtime: Node, source: DialogicCaptionProjectionSource) -> Dictionary:
	if (
		runtime == null
		or source == null
		or not runtime.has_method("get_subsystem")
		or not runtime.has_signal("timeline_started")
		or not runtime.has_signal("timeline_ended")
	):
		return {"ok": false, "code": &"caption_runtime_binding_invalid"}
	if _runtime == runtime and _source == source:
		return {"ok": true, "code": &"caption_runtime_already_bound"}
	unbind_runtime()
	var text_subsystem := runtime.call("get_subsystem", "Text") as Node
	if text_subsystem == null or not text_subsystem.has_signal("text_started"):
		return {"ok": false, "code": &"caption_text_subsystem_missing"}
	_runtime = runtime
	_text_subsystem = text_subsystem
	_source = source
	_runtime.connect("timeline_started", _on_timeline_started)
	_runtime.connect("timeline_ended", _on_timeline_ended)
	_text_subsystem.connect("text_started", _on_text_started)
	return {"ok": true, "code": &"caption_runtime_bound"}

func unbind_runtime() -> void:
	if is_instance_valid(_runtime):
		if _runtime.is_connected("timeline_started", _on_timeline_started):
			_runtime.disconnect("timeline_started", _on_timeline_started)
		if _runtime.is_connected("timeline_ended", _on_timeline_ended):
			_runtime.disconnect("timeline_ended", _on_timeline_ended)
	if is_instance_valid(_text_subsystem) and _text_subsystem.is_connected("text_started", _on_text_started):
		_text_subsystem.disconnect("text_started", _on_text_started)
	_runtime = null
	_text_subsystem = null
	_source = null

func get_presenter() -> NarrativeCaptionLayer:
	return _presenter

func get_last_failure() -> Dictionary:
	return _last_failure.duplicate(true)

func _on_timeline_started() -> void:
	var session: Dictionary = _source.get_session_projection()
	var result := _presenter.reset_session(session.session_id, session.language_mode)
	_last_failure = {} if result.ok else result.duplicate(true)

func _on_timeline_ended() -> void:
	_presenter.clear_session()

func _on_text_started(info: Dictionary) -> void:
	var projected: Dictionary = _source.project_text(int(_runtime.get("current_event_idx")), info)
	if not projected.ok:
		_last_failure = projected.duplicate(true)
		return
	var result: Dictionary = (
		_presenter.append_current(projected.projection)
		if projected.append
		else _presenter.publish_beat(projected.projection)
	)
	_last_failure = {} if result.ok else result.duplicate(true)

func _exit_tree() -> void:
	if is_instance_valid(_presenter):
		_presenter.clear_session()
	unbind_runtime()
```

Create `scenes/dialogic/NarrativeCaptionDialogicLayer.tscn` as a full-rect `Control` scripted by this class with one full-rect instance of `res://scenes/shared/narrative/NarrativeCaptionLayer.tscn` named and uniquely owned as `%NarrativeCaptionLayer`.

- [ ] **Step 5: Run bridge unit tests GREEN**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'caption_bridge_green' -LogName 'caption-bridge-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dialogic_caption_projection_source.gd,res://tests/unit/test_dialogic_narrative_caption_layer.gd','-gexit')
```

Expected: PASS; unknown events fail closed and repeated binding produces no duplicate signals.

- [ ] **Step 6: Write the physical style integration test and fixture**

Create `tests/fixtures/dialogic/narrative_caption_style_fixture.dtl`:

```text
# timeline_id: fixture.narrative_caption.style
# locale: en
# type: caption_style_fixture
Narrator: First caption.
Narrator: Second caption.
Narrator: Third caption.[n+] Continued third caption.
Narrator: Fourth caption.
return
```

Create `tests/integration/test_narrative_caption_dialogic_style.gd` with setup that dynamically loads the not-yet-created style, explicitly loads it into a test host, awaits deferred layout insertion, configures records for event indices `0..3`, binds the active `DialogicNarrativeCaptionLayer`, starts the physical timeline, and advances each segment. Its assertions must include:

```gdscript
assert_not_null(load("res://dialogic/styles/NarrativeCaptionStyle.tres"))
assert_ne(ProjectSettings.get_setting("dialogic/layout/default_style", ""), STYLE_PATH)
assert_eq(_nodes_in_active_layout("dialogic_dialog_text").size(), 1)
assert_eq(adapter.get_presenter().get_current_text_owner(), _nodes_in_active_layout("dialogic_dialog_text")[0])
assert_eq(adapter.get_presenter().get_visual_semantic_ids(), [&"fixture.caption.two", &"fixture.caption.three", &"fixture.caption.four"])
assert_eq(segment_count, 5)
assert_eq(adapter.get_presenter().get_projection(&"fixture.caption.three").primary_text, "Third caption. Continued third caption.")
```

The helper `_nodes_in_active_layout(group_name)` filters `get_tree().get_nodes_in_group(group_name)` through `Dialogic.Styles.get_layout_node().is_ancestor_of(node)`. Assert the active layout contains no node whose script class is `DialogicNode_NameLabel`, no `DialogueBox`, and no bundled `VN_TextboxLayer`. Clean up with `Dialogic.end_timeline(true)`, unbind the adapter, queue-free the active layout, clear the `dialogic_layout_node` tree metadata, and await one frame in `after_each()`.

- [ ] **Step 7: Run physical integration RED**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'caption_style_red' -LogName 'caption-style-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_narrative_caption_dialogic_style.gd','-gexit')
```

Expected: FAIL because `NarrativeCaptionStyle.tres` does not exist.

- [ ] **Step 8: Create the complete opt-in style**

Create `dialogic/styles/NarrativeCaptionStyle.tres` as a byte-for-byte structural clone of `addons/dialogic/Modules/DefaultLayoutParts/Style_VN_Default/default_vn_style.tres`, with only these two semantic substitutions:

```diff
-[ext_resource type="PackedScene" path="res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Textbox/vn_textbox_layer.tscn" id="5_o6sv8"]
+[ext_resource type="PackedScene" path="res://scenes/dialogic/NarrativeCaptionDialogicLayer.tscn" id="5_o6sv8"]
@@
-name = "Visual Novel Style"
+name = "Narrative Caption Style"
```

Keep the same base and layer IDs `10` through `17`; layer `13` now points to the project-owned wrapper. This preserves a complete selectable style while guaranteeing that the active layout does not instantiate the fallback textbox. Do not add the style to `project.godot` or Dialogic's style directory.
The replacement ext-resource line deliberately has no copied `uid`: retaining the bundled textbox scene's UID would let Godot resolve the old scene despite the new path. The editor may generate a matching UID for the new wrapper during isolated import; never copy the fallback UID.

- [ ] **Step 9: Run physical integration GREEN**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'caption_style_green' -LogName 'caption-style-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_narrative_caption_dialogic_style.gd','-gexit')
```

Expected: PASS with five `text_started` segments, four semantic cards over time, one active Dialogic text owner, and no global style change.

- [ ] **Step 10: Review and commit Task 3**

Review all eight task paths for fail-closed identity, signal disconnects, one text owner, explicit style selection, and no mutation calls. Then stage and commit only:

```powershell
git add -- scripts/narrative/DialogicCaptionProjectionSource.gd scripts/ui/narrative/DialogicNarrativeCaptionLayer.gd scenes/dialogic/NarrativeCaptionDialogicLayer.tscn dialogic/styles/NarrativeCaptionStyle.tres tests/fixtures/dialogic/narrative_caption_style_fixture.dtl tests/unit/test_dialogic_caption_projection_source.gd tests/unit/test_dialogic_narrative_caption_layer.gd tests/integration/test_narrative_caption_dialogic_style.gd
git commit -m "feat: add opt-in Dialogic caption style"
```

---

### Task 4: Scene smoke, regressions, and protected-path proof

**Files:**
- Modify: `tests/smoke_load_scenes.gd`
- Verify: all exact task paths and protected paths

**Interfaces:**
- Consumes: Task 1 title scene and Tasks 2–3 caption scenes/style.
- Produces: isolated smoke/regression evidence and a final scope-safe diff.

- [ ] **Step 1: Add the new scenes to smoke coverage**

Append exactly these paths to `REQUIRED_SCENE_PATHS` in `tests/smoke_load_scenes.gd`:

```gdscript
	"res://scenes/shared/narrative/NarrativeCaptionLayer.tscn",
	"res://scenes/dialogic/NarrativeCaptionDialogicLayer.tscn",
```

- [ ] **Step 2: Run scene smoke**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'title_caption_scene_smoke' -LogName 'title-caption-scene-smoke.log' -GodotArgs @('-s','res://tests/smoke_load_scenes.gd')
```

Expected: `SMOKE_LOAD_SCENES: PASS` and both new scenes load once.

- [ ] **Step 3: Run all focused suites together**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'title_caption_focused' -LogName 'title-caption-focused.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scene/test_menu_title_art_presenter.gd,res://tests/unit/test_narrative_caption_layer.gd,res://tests/unit/test_dialogic_caption_projection_source.gd,res://tests/unit/test_dialogic_narrative_caption_layer.gd,res://tests/integration/test_narrative_caption_dialogic_style.gd','-gexit')
```

Expected: PASS with zero GUT failures and zero script/parser errors.

- [ ] **Step 4: Run applicable title/Dialogic regressions**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'title_caption_regressions' -LogName 'title-caption-regressions.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scene/test_settings_localization_scene.gd,res://tests/unit/test_dialogic_runtime_adapter.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_dialogic_effect_boundary.gd,res://tests/integration/test_dialogic_restore.gd,res://tests/integration/test_dialogic_skip.gd,res://tests/integration/test_narrative_checkpoint_wiring.gd,res://tests/integration/test_ending_dialogic_wiring.gd,res://tests/unit/tooling/test_project_config_guard.gd','-gexit')
```

Expected: PASS. If a pre-existing unrelated failure appears, preserve its raw evidence and prove whether it reproduces at the Task 1 baseline before changing any additional file.

- [ ] **Step 5: Prove the protected paths were not changed by this plan**

Run the complete aggregate command in Execution Appendix D again. Expected: `PROTECTED_COUNT` and `PROTECTED_AGGREGATE` are identical to Task 1 Step 1; the aggregate covers the sorted protected path set and every per-file SHA-256. Also run:

```powershell
git diff --name-only c729592cb -- '*.html' project.godot .beads scenes/shared/DialogueBox.tscn scripts/ui/DialogueBox.gd dialogic/timelines
```

Expected: no path newly changed by this implementation; pre-existing differences are documented rather than staged or overwritten.

- [ ] **Step 6: Review the final scoped diff**

Run:

```powershell
git diff --check
git status --short
git log --oneline -6
```

Inspect every task-owned file. Confirm no title artwork, placeholder copy, global style setting, alternate text owner, raw-prose identity inference, persistence mutation, or claim of full shell/Narrative Host completion exists.

- [ ] **Step 7: Commit smoke coverage**

Stage and commit only:

```powershell
git add -- tests/smoke_load_scenes.gd
git commit -m "test: cover title and caption presentation scenes"
```

The completed slice is evidence only for section 10.5. The handoff must explicitly state that artwork binding, Gallery title hosting, full title scaler/matte, production narrative routing, full Narrative Host, ending return, archive reuse, and global Dialogic activation remain deferred.

---

## Execution Appendix A: Complete caption scene resources

Task 2 Step 5 creates `scenes/shared/narrative/NarrativeCaptionLayer.tscn` with these complete bytes:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/narrative/NarrativeCaptionLayer.gd" id="1_layer"]
[ext_resource type="Script" path="res://scripts/ui/narrative/NarrativeCaptionStackContainer.gd" id="2_stack"]
[ext_resource type="Script" path="res://addons/dialogic/Modules/Text/node_dialog_text.gd" id="3_dialog_text"]

[node name="NarrativeCaptionLayer" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
focus_mode = 0
script = ExtResource("1_layer")

[node name="CaptionDeck" type="Control" parent="."]
layout_mode = 1
anchors_preset = -1
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 128.0
offset_top = 448.0
offset_right = -128.0
offset_bottom = -64.0
mouse_filter = 2
focus_mode = 0

[node name="CaptionStack" type="Container" parent="CaptionDeck"]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
focus_mode = 0
script = ExtResource("2_stack")

[node name="CurrentCard" type="MarginContainer" parent="CaptionDeck/CaptionStack"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(0, 64)
layout_mode = 2
mouse_filter = 2
focus_mode = 0
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 6
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 6

[node name="VBox" type="VBoxContainer" parent="CaptionDeck/CaptionStack/CurrentCard"]
layout_mode = 2
mouse_filter = 2

[node name="CurrentPrimary" type="RichTextLabel" parent="CaptionDeck/CaptionStack/CurrentCard/VBox" node_paths=PackedStringArray("textbox_root")]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
focus_mode = 0
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 2
script = ExtResource("3_dialog_text")
textbox_root = NodePath(".")
start_hidden = false

[node name="CurrentSecondary" type="RichTextLabel" parent="CaptionDeck/CaptionStack/CurrentCard/VBox"]
unique_name_in_owner = true
visible = false
layout_mode = 2
mouse_filter = 2
focus_mode = 0
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 2

[node name="PreviousCard" type="MarginContainer" parent="CaptionDeck/CaptionStack"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(0, 64)
layout_mode = 2
mouse_filter = 2
focus_mode = 0
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 6
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 6

[node name="VBox" type="VBoxContainer" parent="CaptionDeck/CaptionStack/PreviousCard"]
layout_mode = 2
mouse_filter = 2

[node name="PreviousPrimary" type="RichTextLabel" parent="CaptionDeck/CaptionStack/PreviousCard/VBox"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
focus_mode = 0
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 2

[node name="PreviousSecondary" type="RichTextLabel" parent="CaptionDeck/CaptionStack/PreviousCard/VBox"]
unique_name_in_owner = true
visible = false
layout_mode = 2
mouse_filter = 2
focus_mode = 0
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 2

[node name="OldestCard" type="MarginContainer" parent="CaptionDeck/CaptionStack"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(0, 64)
layout_mode = 2
mouse_filter = 2
focus_mode = 0
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 6
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 6

[node name="VBox" type="VBoxContainer" parent="CaptionDeck/CaptionStack/OldestCard"]
layout_mode = 2
mouse_filter = 2

[node name="OldestPrimary" type="RichTextLabel" parent="CaptionDeck/CaptionStack/OldestCard/VBox"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
focus_mode = 0
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 2

[node name="OldestSecondary" type="RichTextLabel" parent="CaptionDeck/CaptionStack/OldestCard/VBox"]
unique_name_in_owner = true
visible = false
layout_mode = 2
mouse_filter = 2
focus_mode = 0
bbcode_enabled = true
fit_content = true
scroll_active = false
autowrap_mode = 2
```

Task 3 Step 4 creates `scenes/dialogic/NarrativeCaptionDialogicLayer.tscn` with these complete bytes:

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/narrative/DialogicNarrativeCaptionLayer.gd" id="1_adapter"]
[ext_resource type="PackedScene" path="res://scenes/shared/narrative/NarrativeCaptionLayer.tscn" id="2_presenter"]

[node name="NarrativeCaptionDialogicLayer" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
focus_mode = 0
script = ExtResource("1_adapter")

[node name="NarrativeCaptionLayer" parent="." instance=ExtResource("2_presenter")]
unique_name_in_owner = true
layout_mode = 1
```

## Execution Appendix B: Complete bridge RED/GREEN tests

Task 3 Step 1 creates `tests/unit/test_dialogic_caption_projection_source.gd` with these complete bytes:

```gdscript
extends "res://addons/gut/test.gd"

const SOURCE_PATH := "res://scripts/narrative/DialogicCaptionProjectionSource.gd"

func _make_source() -> RefCounted:
	var source_script := load(SOURCE_PATH) as Script
	assert_not_null(source_script)
	if source_script == null:
		return null
	return source_script.new() as RefCounted

func test_registered_text_index_projects_exact_identity_without_reading_prose() -> void:
	var source := _make_source()
	if source == null:
		return
	var records: Array[Dictionary] = [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 1, "event_kind": "signal", "semantic_id": &"fixture.signal"},
	]
	assert_true(source.call("configure", &"fixture.session", &"single", records).ok)
	var projected: Dictionary = source.call("project_text", 0, {"text": "Repeated prose", "append": false})
	assert_true(projected.ok)
	assert_eq(projected.projection.semantic_id, &"fixture.caption.one")
	assert_eq(projected.projection.primary_text, "Repeated prose")
	assert_false(source.call("project_text", 99, {"text": "Repeated prose", "append": false}).ok)
	assert_eq(source.call("project_text", 1, {"text": "Repeated prose", "append": false}).code, &"unknown_caption_event")

func test_append_keeps_the_registered_event_identity() -> void:
	var source := _make_source()
	if source == null:
		return
	source.call("configure", &"fixture.session", &"dual", [
		{"event_index": 4, "event_kind": "text", "semantic_id": &"fixture.caption.append"},
	])
	var projected: Dictionary = source.call("project_text", 4, {
		"text": " fragment",
		"secondary_text": " 片段",
		"append": true,
	})
	assert_true(projected.ok)
	assert_true(projected.append)
	assert_eq(projected.projection.semantic_id, &"fixture.caption.append")
	assert_eq(projected.projection.secondary_text, " 片段")

func test_configuration_fails_closed_and_does_not_publish_partial_state() -> void:
	var source := _make_source()
	if source == null:
		return
	assert_false(source.call("configure", &"", &"single", []).ok)
	assert_false(source.call("configure", &"fixture.session", &"unknown", []).ok)
	assert_false(source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"one"},
		{"event_index": 0, "event_kind": "text", "semantic_id": &"two"},
	]).ok)
	assert_false(source.call("project_text", 0, {"text": "Words", "append": false}).ok)

func test_configured_records_are_owned_copies() -> void:
	var source := _make_source()
	if source == null:
		return
	var record := {"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"}
	var records: Array[Dictionary] = [record]
	assert_true(source.call("configure", &"fixture.session", &"single", records).ok)
	record.semantic_id = &"mutated"
	var projected: Dictionary = source.call("project_text", 0, {"text": "Words", "append": false})
	assert_eq(projected.projection.semantic_id, &"fixture.caption.one")
```

Task 3 Step 1 also creates `tests/unit/test_dialogic_narrative_caption_layer.gd` with these complete bytes. It uses dynamic paths so the RED file parses before either production script exists:

```gdscript
extends "res://addons/gut/test.gd"

const SOURCE_PATH := "res://scripts/narrative/DialogicCaptionProjectionSource.gd"
const ADAPTER_SCENE_PATH := "res://scenes/dialogic/NarrativeCaptionDialogicLayer.tscn"

class FakeTextSubsystem:
	extends Node
	signal text_started(info: Dictionary)

class FakeRuntime:
	extends Node
	signal timeline_started
	signal timeline_ended
	var current_event_idx := -1
	var text := FakeTextSubsystem.new()
	var mutation_calls: Array[StringName] = []

	func _init() -> void:
		add_child(text)

	func get_subsystem(name: String) -> Node:
		return text if name == "Text" else null

	func start_timeline() -> void:
		mutation_calls.append(&"start_timeline")

	func advance() -> void:
		mutation_calls.append(&"advance")

func _make_source() -> RefCounted:
	var source_script := load(SOURCE_PATH) as Script
	assert_not_null(source_script)
	if source_script == null:
		return null
	var source := source_script.new() as RefCounted
	var result: Dictionary = source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 1, "event_kind": "text", "semantic_id": &"fixture.caption.two"},
	])
	assert_true(result.ok)
	return source

func _make_adapter() -> Node:
	var packed := load(ADAPTER_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return null
	var adapter := packed.instantiate()
	add_child_autofree(adapter)
	await get_tree().process_frame
	return adapter

func test_binding_is_idempotent_and_timeline_signals_reset_the_presenter() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	assert_true(adapter.call("bind_runtime", runtime, source).ok)
	assert_true(adapter.call("bind_runtime", runtime, source).ok)
	assert_eq(runtime.timeline_started.get_connections().size(), 1)
	assert_eq(runtime.timeline_ended.get_connections().size(), 1)
	assert_eq(runtime.text.text_started.get_connections().size(), 1)
	runtime.timeline_started.emit()
	runtime.current_event_idx = 0
	runtime.text.text_started.emit({"text": "First", "append": false})
	var presenter: Node = adapter.call("get_presenter")
	assert_eq(presenter.call("get_visual_semantic_ids"), [&"fixture.caption.one"])
	runtime.current_event_idx = 1
	runtime.text.text_started.emit({"text": "Second", "append": false})
	assert_eq(presenter.call("get_visual_semantic_ids"), [&"fixture.caption.one", &"fixture.caption.two"])
	runtime.timeline_started.emit()
	assert_true((presenter.call("get_visual_semantic_ids") as Array).is_empty())
	assert_true(runtime.mutation_calls.is_empty())

func test_append_uses_current_identity_and_end_clears_without_mutating_runtime() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	adapter.call("bind_runtime", runtime, source)
	runtime.timeline_started.emit()
	runtime.current_event_idx = 0
	runtime.text.text_started.emit({"text": "First", "append": false})
	runtime.text.text_started.emit({"text": " continued", "append": true})
	var presenter: Node = adapter.call("get_presenter")
	assert_eq((presenter.call("get_projection", &"fixture.caption.one") as Dictionary).primary_text, "First continued")
	runtime.timeline_ended.emit()
	assert_true((presenter.call("get_visual_semantic_ids") as Array).is_empty())
	assert_true(runtime.mutation_calls.is_empty())

func test_unbind_disconnects_every_owned_signal() -> void:
	var source := _make_source()
	var adapter := await _make_adapter()
	if source == null or adapter == null:
		return
	var runtime := FakeRuntime.new()
	add_child_autofree(runtime)
	adapter.call("bind_runtime", runtime, source)
	adapter.call("unbind_runtime")
	assert_eq(runtime.timeline_started.get_connections().size(), 0)
	assert_eq(runtime.timeline_ended.get_connections().size(), 0)
	assert_eq(runtime.text.text_started.get_connections().size(), 0)
```

## Execution Appendix C: Complete real-Dialogic integration test

Task 3 Step 6 creates `tests/integration/test_narrative_caption_dialogic_style.gd` with these complete bytes:

```gdscript
extends "res://addons/gut/test.gd"

const STYLE_PATH := "res://dialogic/styles/NarrativeCaptionStyle.tres"
const FIXTURE_PATH := "res://tests/fixtures/dialogic/narrative_caption_style_fixture.dtl"
const SOURCE_PATH := "res://scripts/narrative/DialogicCaptionProjectionSource.gd"

var _host: Node = null
var _adapter: Node = null
var _segments: Array[Dictionary] = []
var _snapshots: Array = []

func before_each() -> void:
	_segments.clear()
	_snapshots.clear()
	ProjectSettings.set_meta("caption_test_old_skip_delay", ProjectSettings.get_setting("dialogic/text/text_reveal_skip_delay", 0.1))
	ProjectSettings.set_setting("dialogic/text/text_reveal_skip_delay", 0.0)

func after_each() -> void:
	if Dialogic.Text.text_started.is_connected(_capture_segment):
		Dialogic.Text.text_started.disconnect(_capture_segment)
	if is_instance_valid(_adapter):
		_adapter.call("unbind_runtime")
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
	elif Dialogic.Styles.has_active_layout_node():
		var active := Dialogic.Styles.get_layout_node()
		if is_instance_valid(active):
			active.queue_free()
	await get_tree().process_frame
	if get_tree().has_meta("dialogic_layout_node"):
		get_tree().remove_meta("dialogic_layout_node")
	ProjectSettings.set_setting(
		"dialogic/text/text_reveal_skip_delay",
		ProjectSettings.get_meta("caption_test_old_skip_delay", 0.1)
	)
	ProjectSettings.remove_meta("caption_test_old_skip_delay")

func test_explicit_style_drives_physical_timeline_with_one_text_owner() -> void:
	var style := load(STYLE_PATH)
	assert_not_null(style)
	assert_true(FileAccess.file_exists(FIXTURE_PATH))
	if style == null or not FileAccess.file_exists(FIXTURE_PATH):
		return
	assert_ne(str(ProjectSettings.get_setting("dialogic/layout/default_style", "")), STYLE_PATH)

	_host = Node.new()
	add_child_autofree(_host)
	var layout := Dialogic.Styles.load_style(STYLE_PATH, _host)
	assert_not_null(layout)
	await get_tree().process_frame
	await get_tree().process_frame

	_adapter = layout.find_child("NarrativeCaptionDialogicLayer", true, false)
	assert_not_null(_adapter)
	if _adapter == null:
		return
	var source_script := load(SOURCE_PATH) as Script
	assert_not_null(source_script)
	if source_script == null:
		return
	var source := source_script.new()
	assert_true(source.call("configure", &"fixture.caption.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 1, "event_kind": "text", "semantic_id": &"fixture.caption.two"},
		{"event_index": 2, "event_kind": "text", "semantic_id": &"fixture.caption.three"},
		{"event_index": 3, "event_kind": "text", "semantic_id": &"fixture.caption.four"},
	]).ok)
	assert_true(_adapter.call("bind_runtime", Dialogic, source).ok)
	Dialogic.Text.text_started.connect(_capture_segment)

	Dialogic.start_timeline(FIXTURE_PATH)
	await _wait_for_segment_count(1)
	for expected_count in range(2, 6):
		Dialogic.Text.skip_text_reveal()
		Dialogic.Inputs.handle_input()
		await _wait_for_segment_count(expected_count)

	assert_eq(_segments.size(), 5)
	assert_eq(_snapshots[3], [&"fixture.caption.one", &"fixture.caption.two", &"fixture.caption.three"])
	assert_eq(_snapshots[4], [&"fixture.caption.two", &"fixture.caption.three", &"fixture.caption.four"])
	var presenter: Node = _adapter.call("get_presenter")
	assert_eq((presenter.call("get_projection", &"fixture.caption.three") as Dictionary).primary_text, "Third caption. Continued third caption.")

	var owners := _nodes_in_active_layout("dialogic_dialog_text")
	assert_eq(owners.size(), 1)
	assert_same(presenter.call("get_current_text_owner"), owners[0])
	assert_true(_nodes_in_active_layout("dialogic_name_label").is_empty())
	assert_null(layout.find_child("VN_TextboxLayer", true, false))
	assert_null(layout.find_child("DialogueBox", true, false))

func _capture_segment(info: Dictionary) -> void:
	_segments.append(info.duplicate(true))
	var presenter: Node = _adapter.call("get_presenter")
	_snapshots.append((presenter.call("get_visual_semantic_ids") as Array).duplicate())

func _wait_for_segment_count(expected: int) -> void:
	for _frame in 120:
		if _segments.size() >= expected:
			return
		await get_tree().process_frame
	assert_true(false, "timed out waiting for Dialogic text segment %d" % expected)

func _nodes_in_active_layout(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	var layout := Dialogic.Styles.get_layout_node()
	if not is_instance_valid(layout):
		return result
	for node in get_tree().get_nodes_in_group(group_name):
		if layout == node or layout.is_ancestor_of(node):
			result.append(node)
	return result
```

The test deliberately stops after observing the fourth beat. It does not accept past that beat before asserting `[two, three, four]`, because `timeline_ended` correctly clears the presenter. Cleanup then awaits `Dialogic.end_timeline(true)` and restores the in-memory reveal-delay setting without saving `project.godot`.

## Execution Appendix D: Byte-safe protected-path audit

Replace Task 1 Step 1's status-only baseline with this read-only aggregate command and preserve its complete output in the execution transcript:

```powershell
$protectedPaths = @(
  git ls-files --cached --modified --others --exclude-standard -- project.godot .beads ':(glob)**/*.html' scenes/shared/DialogueBox.tscn scripts/ui/DialogueBox.gd dialogic/timelines
) | Sort-Object -Unique
$atlasRoot = 'C:\Users\glori\Documents\Codex\2026-08-14\new-chat\lawful-universe-atlas'
$protectedLines = @(
  foreach ($protectedPath in $protectedPaths) {
    if (Test-Path -LiteralPath $protectedPath -PathType Leaf) {
      $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $protectedPath).Hash
      "$hash  $protectedPath"
    } else {
      "MISSING  $protectedPath"
    }
  }
  foreach ($atlasHtml in Get-ChildItem -LiteralPath $atlasRoot -Recurse -File -Filter '*.html' | Sort-Object FullName) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $atlasHtml.FullName).Hash
    "$hash  $($atlasHtml.FullName)"
  }
)
$protectedBytes = [Text.Encoding]::UTF8.GetBytes(($protectedLines -join "`n"))
$protectedSha = [Security.Cryptography.SHA256]::Create()
try {
  $protectedAggregate = [BitConverter]::ToString($protectedSha.ComputeHash($protectedBytes)).Replace('-', '')
} finally {
  $protectedSha.Dispose()
}
"PROTECTED_COUNT=$($protectedLines.Count)"
"PROTECTED_AGGREGATE=$protectedAggregate"
```

Run the identical command again in Task 4 Step 5. `PROTECTED_COUNT` and `PROTECTED_AGGREGATE` must be identical; the latter commits to the sorted path set and every per-file SHA-256. A matching status letter is not accepted as byte-preservation proof. If an external process changes a protected file during execution, stop and report that independently rather than overwriting or staging it.
