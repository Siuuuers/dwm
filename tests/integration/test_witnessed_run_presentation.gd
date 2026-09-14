extends GutTest
## The installed Dialogic layout reads a live run at scene boundaries, then keeps its
## own material snapshot while native text, art, and input remain with their owners.

const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const CAPTION_PATH := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const HOLD := preload("res://scripts/ui/witnessed/SceneArtHoldSurface.gd")
const RUN_PRESENTATION := preload("res://scripts/ui/witnessed/WitnessedRunPresentation.gd")
const PALETTES := preload("res://scripts/ui/witnessed/WitnessedPaletteRegistry.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")

class RunOwner extends Node:
	var day: Variant = 1
	var dark_mode: Variant = false
	var installed := true
	var reads := 0
	func get_run_configuration() -> Dictionary:
		reads += 1
		if not installed: return {"ok": false, "code": &"run_configuration_unavailable"}
		return {"ok": true, "value": {"dark_mode": dark_mode}}

class MemoryProfile extends Node:
	signal preference_changed(path: StringName, value: Variant)
	var high_contrast := false
	var colour_preset := "standard"
	var next_run_dark_mode := false
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		match path:
			&"preferences.dark_mode.next_run_enabled": return next_run_dark_mode
			&"preferences.accessibility.text_size": return 100
			&"preferences.accessibility.high_contrast": return high_contrast
			&"preferences.accessibility.colour_differentiation": return colour_preset
			&"preferences.accessibility.large_targets": return false
		return fallback
	func get_profile_snapshot() -> Dictionary:
		return {"preferences": {"reading": {"reveal_speed": "fast", "auto_delay": "short",
			"auto_enabled": false, "skip_mode": "read_only"}}}
	func set_colours(contrast: bool, preset: String) -> void:
		high_contrast = contrast
		colour_preset = preset
		preference_changed.emit(&"preferences.accessibility.high_contrast", contrast)
		preference_changed.emit(&"preferences.accessibility.colour_differentiation", preset)
	func set_next_run_dark_mode(value: bool) -> void:
		next_run_dark_mode = value
		preference_changed.emit(&"preferences.dark_mode.next_run_enabled", value)

class MemoryLocale extends Node:
	signal locale_changed(locale: String)
	func get_locale() -> String: return "en"

var _original_runtime: Node
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _original_runtime_index := 0
var _original_game_state: Node
var _original_game_state_index := 0
var _original_profile: Node
var _original_profile_index := 0
var _original_localization: Node
var _original_localization_index := 0
var _runtime: DialogicGameHandler
var _layout: Node
var _caption: Node
var _run_owner: RunOwner
var _profile: MemoryProfile
var _localization: MemoryLocale
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _finished := 0
var _ended := 0
var _window_size := Vector2i.ZERO
var _window_content_size := Vector2i.ZERO

func before_each() -> void:
	_finished = 0
	_ended = 0
	_window_size = get_tree().root.size
	_window_content_size = get_tree().root.content_scale_size
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.simple_history_enabled = true
	_runtime.History.full_event_history_enabled = true
	_runtime.History.visited_event_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.Text.text_finished.connect(func(_info: Dictionary): _finished += 1)
	_runtime.timeline_ended.connect(func(): _ended += 1)
	_original_game_state = get_node("/root/GameState")
	_original_game_state_index = _original_game_state.get_index()
	get_tree().root.remove_child(_original_game_state)
	_run_owner = RunOwner.new()
	_run_owner.name = "GameState"
	get_tree().root.add_child(_run_owner)
	_original_profile = get_node("/root/ProfileManager")
	_original_profile_index = _original_profile.get_index()
	get_tree().root.remove_child(_original_profile)
	_profile = MemoryProfile.new()
	_profile.name = "ProfileManager"
	get_tree().root.add_child(_profile)
	_original_localization = get_node("/root/LocalizationManager")
	_original_localization_index = _original_localization.get_index()
	get_tree().root.remove_child(_original_localization)
	_localization = MemoryLocale.new()
	_localization.name = "LocalizationManager"
	get_tree().root.add_child(_localization)

func after_each() -> void:
	get_tree().paused = false
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		var remaining: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(remaining): remaining.queue_free()
		await get_tree().process_frame
		_runtime.free()
	if is_instance_valid(_localization): _localization.free()
	get_tree().root.add_child(_original_localization)
	get_tree().root.move_child(_original_localization, _original_localization_index)
	if is_instance_valid(_profile): _profile.free()
	get_tree().root.add_child(_original_profile)
	get_tree().root.move_child(_original_profile, _original_profile_index)
	if is_instance_valid(_run_owner): _run_owner.free()
	get_tree().root.add_child(_original_game_state)
	get_tree().root.move_child(_original_game_state, _original_game_state_index)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent):
			_original_layout_parent.add_child(_original_layout)
			_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	ART.reload_placements()
	_original_layout_parent = null
	get_tree().root.size = _window_size
	get_tree().root.content_scale_size = _window_content_size

func _timeline(copy: String) -> DialogicTimeline:
	var result := DialogicTimeline.new()
	result.from_text(copy)
	return result

func _mount(copy: String) -> void:
	_layout = _runtime.Styles.load_style(STYLE)
	assert_not_null(_layout)
	if _layout == null: return
	for layer: Node in _layout.get_layers():
		if layer.get_script().resource_path == CAPTION_PATH: _caption = layer
	assert_not_null(_caption)
	_runtime.start(_timeline(copy))
	await _settle()

func _settle() -> void:
	for frame: int in 4: await get_tree().process_frame

func _reading() -> Dictionary:
	var native: DialogicNode_DialogText = _caption.caption_text
	return {"node": native, "text": native.text, "visible": native.visible_characters,
		"generation": native.get_reveal_generation(), "event": _runtime.current_event_idx,
		"state": _runtime.current_state,
		"simple": _runtime.History.simple_history_content.duplicate(true),
		"full": _runtime.History.full_event_history_content.duplicate(true),
		"visited": _runtime.History.visited_event_history_content.duplicate(true),
		"finished": _finished, "ended": _ended}

func _roles() -> Dictionary:
	var result := {}
	for role: StringName in [&"field", &"deep", &"current", &"text", &"rule", &"focus_outer", &"focus_inner"]:
		result[role] = _caption.canvas.theme.get_color(role, &"WitnessedCaption")
	return result

func _parse_mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)

func test_fresh_layout_reads_installed_run_and_next_run_waits_for_real_timeline_boundary() -> void:
	_run_owner.dark_mode = true
	_run_owner.day = 5
	_profile.next_run_dark_mode = true
	await _mount("First scene is still revealing. ".repeat(40))
	if _caption == null: return
	assert_eq(_caption.get_caption_projection().palette, "Midnight")
	assert_eq(_caption.get_caption_projection().day, 5)
	assert_eq(_roles(), PALETTES.resolve_tinted("Midnight", false, "standard", 5))
	_runtime.paused = true
	var first_layout: Node = _layout
	var first_caption: Node = _caption
	var first_reading := _reading()
	var read_count := _run_owner.reads
	_profile.set_next_run_dark_mode(false)
	assert_eq(_run_owner.reads, read_count, "next-run preference does not read the installed run")
	assert_eq(_caption.get_caption_projection().palette, "Midnight")
	assert_eq(_caption.get_caption_projection().day, 5)
	_run_owner.dark_mode = false
	_run_owner.day = 7
	await _settle()
	assert_eq(_run_owner.reads, read_count, "running text never polls the run owner")
	assert_eq(_caption.get_caption_projection().palette, "Midnight")
	assert_eq(_caption.get_caption_projection().day, 5)
	assert_eq(_reading(), first_reading)
	_runtime.paused = false
	var second_copy := "Second scene has its own first text. ".repeat(24) + "Second scene has its own first text."
	_runtime.start(_timeline(second_copy))
	await _settle()
	assert_eq(_runtime.Styles.get_layout_node(), first_layout, "the actual Dialogic layout is reused")
	assert_eq(_caption, first_caption)
	assert_eq(_caption.get_caption_projection().palette, "AfterHours")
	assert_eq(_caption.get_caption_projection().day, 7)
	assert_eq(_roles(), PALETTES.resolve_tinted("AfterHours", false, "standard", 7))
	assert_eq(_caption.caption_text.get_parsed_text(), second_copy)
	assert_eq(_ended, 0, "material refresh cannot complete either timeline")

func test_live_accessibility_recolours_same_native_caption_without_owner_poll_or_input_loss() -> void:
	_run_owner.dark_mode = true
	_run_owner.day = 4
	await _mount("A long native caption keeps this reading position. ".repeat(100))
	if _caption == null: return
	var native: DialogicNode_DialogText = _caption.caption_text
	var bar: VScrollBar = _caption.get_scroll_bar()
	_runtime.paused = true
	bar.value = 100.0
	native.grab_focus()
	var before := _reading()
	var reads := _run_owner.reads
	_profile.set_colours(true, "tritan")
	await _settle()
	assert_eq(_run_owner.reads, reads, "live profile changes use the captured run tuple")
	assert_eq(_caption.get_caption_projection().palette, "Midnight")
	assert_eq(_caption.get_caption_projection().day, 4)
	assert_eq(_roles(), PALETTES.resolve_tinted("Midnight", true, "tritan", 4))
	assert_eq(_reading(), before)
	assert_eq(bar.value, 100.0)
	assert_true(native.has_focus())
	assert_eq(_caption.caption_text, native)
	var source := {"frontier": {"generation": _runtime.get_timeline_generation(),
		"event_index": _runtime.current_event_idx}, "route_id": "hospital"}
	var captured: Dictionary = _caption.capture_pause_view(source)
	assert_true(captured.get("ok", false), str(captured))
	if not captured.get("ok", false): return
	assert_true(_caption.cover_pause_view(captured.value))
	_profile.set_colours(false, "protan")
	assert_eq(_run_owner.reads, reads)
	assert_eq(_roles(), PALETTES.resolve_tinted("Midnight", false, "protan", 4))
	assert_true(_caption.restore_pause_view(captured.value))
	await _settle()
	assert_eq(_reading(), before)
	assert_eq(bar.value, 100.0)
	assert_true(native.has_focus())

func test_no_installed_run_keeps_preview_defaults_until_a_real_scene_boundary() -> void:
	_run_owner.installed = false
	_run_owner.dark_mode = true
	_run_owner.day = 6
	await _mount("An uninstalled run cannot supply this caption colour. ".repeat(20))
	if _caption == null: return
	assert_eq(_caption.get_caption_projection().palette, "AfterHours")
	assert_eq(_caption.get_caption_projection().day, 1)
	assert_eq(_roles(), PALETTES.resolve_tinted("AfterHours", false, "standard", 1))
	var retained: Node = _caption
	_run_owner.installed = true
	assert_eq(_caption.get_caption_projection().day, 1, "install alone does not poll during reveal")
	_runtime.start(_timeline("The next actual scene reads the newly installed run. ".repeat(20)))
	await _settle()
	assert_eq(_caption, retained)
	assert_eq(_caption.get_caption_projection().palette, "Midnight")
	assert_eq(_caption.get_caption_projection().day, 6)
	assert_eq(_roles(), PALETTES.resolve_tinted("Midnight", false, "standard", 6))

func test_invalid_run_read_and_invalid_day_leave_existing_material_and_reading_atomic() -> void:
	_run_owner.dark_mode = true
	_run_owner.day = 3
	await _mount("Invalid owner must not change this current native line. ".repeat(20))
	if _caption == null: return
	var before := _reading()
	var theme: Theme = _caption.canvas.theme
	var projection: Dictionary = _caption.get_caption_projection()
	for day: int in [0, 8]:
		assert_false(_caption.configure_presentation("en", 100, "Midnight", false, "standard", false, day))
		assert_eq(_caption.canvas.theme, theme)
		assert_eq(_caption.get_caption_projection(), projection)
	for invalid: Variant in [0, 8, "4"]:
		_run_owner.day = invalid
		assert_eq(RUN_PRESENTATION.read(_run_owner), {})
		assert_false(_caption.configure_run_presentation(_run_owner))
		assert_eq(_caption.canvas.theme, theme)
		assert_eq(_caption.get_caption_projection(), projection)
		assert_eq(_reading(), before)
	_run_owner.day = 4
	_run_owner.dark_mode = "true"
	assert_eq(RUN_PRESENTATION.read(_run_owner), {})
	assert_false(_caption.configure_run_presentation(_run_owner))
	_run_owner.dark_mode = false
	_run_owner.installed = false
	assert_eq(RUN_PRESENTATION.read(_run_owner), {})
	assert_false(_caption.configure_run_presentation(_run_owner))
	assert_eq(_caption.canvas.theme, theme)
	assert_eq(_caption.get_caption_projection(), projection)
	assert_eq(_reading(), before)

func test_colour_change_keeps_a_real_pending_caption_click_until_one_release() -> void:
	_run_owner.dark_mode = true
	_run_owner.day = 2
	await _mount("A native pending click must finish this line once. ".repeat(100))
	if _caption == null: return
	if _layout.get_parent() != get_tree().root:
		_layout.reparent(get_tree().root)
	_layout.layer = 129
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	_runtime.Text.text_started.connect(func(_info: Dictionary):
		_caption.caption_text.set_process(false)
		_caption.set_process(false))
	_runtime.start(_timeline("A fresh native click is armed on this caption. ".repeat(100)
		+ "\nA guard caption keeps the timeline open."))
	await _settle()
	_runtime.Inputs.input_block_timer.stop()
	var native: DialogicNode_DialogText = _caption.caption_text
	assert_true(native.revealing)
	native.grab_focus()
	var point: Vector2 = get_tree().root.get_final_transform() * (
		_caption.canvas.get_global_transform_with_canvas()
		* _caption.get_caption_projection().caption_visible_rect.get_center())
	var before := _reading()
	var reads := _run_owner.reads
	_parse_mouse(point, true)
	Input.flush_buffered_events()
	var pending: Dictionary = _caption.accept_input._candidate.duplicate(true)
	assert_false(pending.is_empty(), "real down contact arms one native caption accept")
	_profile.set_colours(true, "deutan")
	assert_eq(_caption.accept_input._candidate, pending, "material publication leaves armed input intact")
	assert_eq(_run_owner.reads, reads)
	assert_eq(_reading(), before)
	_parse_mouse(point, false)
	await _settle()
	assert_eq(_finished, int(before.finished) + 1)
	assert_eq(_runtime.current_event_idx, before.event)
	assert_eq(_ended, 0)

func test_art_hold_recolours_only_material_with_same_art_and_continue_custody() -> void:
	var created: Dictionary = TemporaryStorage.create("witnessed-run-presentation-art")
	assert_true(created.get("ok", false), "the art fixture requires isolated storage: " + str(created))
	if not created.get("ok", false): return
	var fixture_path: String = str(created["value"]).path_join("art.json")
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_string(JSON.stringify({"schema_version": 1,
		"assets": {"fixture.portrait": {"path": "res://icon.svg", "size": [128, 128]}},
		"scenes": {"opening.day1": {"background": "", "portraits": ["fixture.portrait"], "cg": ""}}}))
	file.close()
	assert_true(ART.reload_placements(fixture_path))
	_run_owner.dark_mode = true
	_run_owner.day = 6
	var hold: Control = HOLD.new()
	assert_true(hold.configure("opening.day1", "retained-art-token", 100, "en", true))
	add_child_autofree(hold)
	for frame: int in 8:
		await get_tree().process_frame
		if hold.has_drawn_art(): break
	assert_true(hold.has_drawn_art(), "the real imported portrait was drawn")
	var art: Control = hold.art
	var texture: Texture2D = art._portraits[0].texture
	assert_not_null(texture)
	var art_modulate := art.modulate
	var portrait_modulate: Color = art._portraits[0].modulate
	var button: Button = hold.next_button
	var token: String = hold._token
	var disabled: bool = button.disabled
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var pressed := [0]
	button.pressed.connect(func(): pressed[0] += 1)
	assert_eq(hold._palette, "Midnight", "art hold binds the installed run at ready")
	assert_eq(hold._day, 6)
	assert_eq(hold._background.color, PALETTES.resolve_tinted("Midnight", false, "standard", 6)[&"field"])
	assert_eq(hold._footer.color, PALETTES.resolve_tinted("Midnight", false, "standard", 6)[&"deep"])
	var reads := _run_owner.reads
	_profile.set_colours(true, "tritan")
	assert_eq(_run_owner.reads, reads, "art hold live accessibility does not repoll the run")
	assert_eq(hold._palette, "Midnight")
	assert_eq(hold._day, 6)
	assert_eq(hold._background.color, PALETTES.resolve_tinted("Midnight", true, "tritan", 6)[&"field"])
	assert_eq(art._portraits[0].texture, texture)
	assert_eq(get_viewport().gui_get_focus_owner(), focus_owner, "colour-only change retains art action focus")
	_profile.set_colours(false, "standard")
	assert_true(hold.configure_run_presentation(_run_owner))
	assert_eq(hold._palette, "Midnight")
	assert_eq(hold._day, 6)
	var source := {"frontier": {"art": true}}
	var captured: Dictionary = hold.capture_pause_view(source)
	assert_true(captured.get("ok", false), str(captured))
	if not captured.get("ok", false): return
	assert_true(hold.cover_pause_view(captured.value))
	var covered_focus: Control = get_viewport().gui_get_focus_owner()
	assert_true(hold.configure_presentation("en", 100, "AfterHours", true, "deutan", false, 7))
	assert_eq(get_viewport().gui_get_focus_owner(), covered_focus, "covered material update cannot take focus")
	var expected: Dictionary = PALETTES.resolve_tinted("AfterHours", true, "deutan", 7)
	assert_eq(hold._background.color, expected[&"field"])
	assert_eq(hold._footer.color, expected[&"deep"])
	assert_eq(button.get_theme_color(&"font_color"), expected[&"text"])
	var theme: Theme = hold.theme
	_run_owner.day = 8
	assert_false(hold.configure_run_presentation(_run_owner))
	assert_eq(hold.theme, theme, "invalid run cannot replace art hold materials")
	assert_true(hold.restore_pause_view(captured.value))
	assert_eq(hold.art, art)
	assert_eq(art._portraits[0].texture, texture)
	assert_eq(art.modulate, art_modulate, "art container is not tinted")
	assert_eq(art._portraits[0].modulate, portrait_modulate, "portrait pixels are not tinted")
	assert_eq(hold.next_button, button)
	assert_eq(hold._token, token)
	assert_eq(button.disabled, disabled)
	assert_eq(pressed[0], 0)
