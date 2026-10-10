class_name SettingsContent
extends Control

signal close_requested()

@export_enum("desktop", "title", "pause") var host_context: String = "desktop"
@export var interaction_enabled: bool = true

const WRITE_RECOVERY := preload("res://scenes/ui/witnessed/WitnessedTransportRecovery.tscn")
const CONTROLLER := preload("res://scripts/ui/SettingsPanelController.gd")
const REGISTRY := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
const COMFORT := preload("res://scripts/audio/accessibility/ListeningComfortNoticeCoordinator.gd")
const PRESENTATION := preload("res://scripts/ui/SettingsTheme.gd")
const RESET_CONFIRMATION := preload("res://scripts/ui/SettingsResetConfirmation.gd")
const INPUT_REGISTRY := preload("res://scripts/settings/ControlsActionRegistry.gd")
const CONTROLS_SHEET := preload("res://scripts/ui/SettingsControlsSheet.gd")
const CATEGORY_FIELDS: Dictionary = {
	"language": ["language.primary_locale_id"],
	"reading": ["reading.reveal_speed", "reading.auto_enabled", "reading.auto_delay", "reading.skip_mode", "reading.read_aloud_enabled", "reading.read_aloud_rate"],
	"audio": ["audio.master_volume", "audio.master_muted", "audio.music_volume", "audio.music_muted", "audio.ambience_volume", "audio.ambience_muted", "audio.sfx_volume", "audio.sfx_muted", "audio.mute_when_inactive", "audio.output_mode"],
	"display": ["display.window_mode", "display.window_size"],
	"controls": [],
	"accessibility": ["accessibility.font_style", "accessibility.text_size", "accessibility.large_targets", "accessibility.high_contrast", "accessibility.reduced_motion", "accessibility.steady_interface", "accessibility.screen_shake", "accessibility.colour_differentiation", "accessibility.sound_detail_text"],
	"records": ["exceptional_replay.available", "exceptional_replay.replay_full", "dark_mode.next_run_enabled"],
}
const RESET_METHODS: Dictionary = {
	"controls": "reset_controls",
	"preferences": "reset_preferences", "visited_history": "reset_visited_history",
	"gallery": "reset_gallery", "entire_profile": "reset_entire_profile",
}

var _scene_presentation := false
@onready var rail_scroll: ScrollContainer = $RailScroll
@onready var sheet_scroll: ScrollContainer = $SheetScroll
var controls: Dictionary = {}
var rows: Dictionary = {}
var records: Dictionary = {}
var statuses: Dictionary = {}
var test_buttons: Dictionary = {}
var test_statuses: Dictionary = {}
var confirmations: Dictionary = {}
var _services: Dictionary = {}
var _controller: RefCounted
var _rails: Dictionary = {}
var _sheets: Dictionary = {}
var _localized_labels: Dictionary = {}
var _wrapped: Array[Label] = []
var _reset_buttons: Dictionary = {}
var _controls_sheet: VBoxContainer
var _selected: String = "language"
var _comfort_note: Label
var _general_status: Label
var _sample_labels: Array[Label] = []
var _presentation_locale: String = ""
var _presentation_font_style: String = ""
var _presentation_percent: int = 0
var _presentation_palette: StringName = &""
var _presentation_high_contrast: bool = false
var _presentation_colour_preset: String = ""
var _presentation_day: Variant = 0
var _run_palette: StringName = &"after_hours"
var _run_day: Variant = 1
var _selected_extension: Control
var _reset_consent: Dictionary = {}
var _confirmation_generation: int = 0
var _reset_busy := false
# Presentation of ProfileManager's retained mutation fence; never an unlock owner.
var _profile_write_uncertain := false
var _write_recovery: Control


func configure_services(services: Dictionary) -> void:
	if not is_node_ready():
		_services = services.duplicate()


func configure_run_presentation(palette: StringName, day: int) -> Dictionary:
	return _configure_run_presentation_context(palette, day, false)

func configure_scene_run_presentation(palette: StringName) -> Dictionary:
	return _configure_run_presentation_context(palette, null, true)

func _configure_run_presentation_context(palette: StringName, day: Variant, scene: bool = false) -> Dictionary:
	if _scene_presentation and not scene: return {"ok": false, "code": &"scene_calendar_configuration_forbidden"}
	if palette not in [&"after_hours", &"midnight"] or (not scene and (day < 1 or day > 7)):
		return {"ok": false, "code": &"invalid_settings_run_presentation"}
	if palette == _run_palette and day == _run_day:
		return {"ok": true}
	_run_palette = palette
	_scene_presentation = scene
	_run_day = day
	if _controller != null:
		_controller.refresh()
	return {"ok": true}


func set_interaction_enabled(enabled: bool) -> void:
	enabled = enabled and not _profile_write_uncertain
	interaction_enabled = enabled
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if enabled else Control.MOUSE_BEHAVIOR_DISABLED
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if enabled else Control.FOCUS_BEHAVIOR_DISABLED
	set_process_unhandled_input(enabled)
	if not enabled:
		if _controls_sheet != null:
			_controls_sheet.depart()
		_confirmation_generation += 1
		_reset_consent.clear()
		for path: StringName in statuses:
			if statuses[path].get_meta("settings_volume_preview", false):
				set_volume_value_presentation(path, float(controls[path].get_meta("settings_committed_value", controls[path].value)), false)
		if is_inside_tree():
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null and (focused == self or is_ancestor_of(focused)):
				focused.release_focus()


func is_interaction_enabled() -> bool:
	return interaction_enabled

func is_departure_blocked() -> bool:
	if _profile_write_uncertain: return true
	if _reset_busy or (_controller != null and (_controller.is_commit_pending() \
		or not _controller.get("_drag").is_empty() or not String(_controller.get("_test_kind")).is_empty() \
		or not _controller.get("_preview_operations").is_empty())):
		return true
	if _controls_sheet != null and (_controls_sheet.get("_opening_capture") \
		or _controls_sheet._modal_visible() or _controls_sheet.is_reviewing_import()): return true
	for dialog: Window in confirmations.values():
		if dialog.visible: return true
	for control: Control in controls.values():
		if control is OptionButton and control.get_popup().visible: return true
	return false


func _ready() -> void:
	set_interaction_enabled(interaction_enabled)
	for entry: Array in [["profile", "ProfileManager"], ["localization", "LocalizationManager"], ["audio", "AudioManager"], ["tts", "SystemTtsCoordinator"], ["input", "InputManager"], ["window", "WindowModeManager"]]:
		if not _services.has(entry[0]):
			_services[entry[0]] = get_node_or_null("/root/" + entry[1])
	if not _services.has("volume"):
		_services["volume"] = _services["audio"]
	if not _services.has("profile_reset_admission"):
		var application := get_node_or_null("/root/ApplicationBootstrap")
		_services["profile_reset_admission"] = Callable(application, "is_profile_reset_admitted") if application != null else Callable()
	_build_content()
	_controller = CONTROLLER.new()
	_controller.bind(self, _services)
	var profile: Variant = _services.get("profile")
	if is_instance_valid(profile) and profile.has_signal("profile_write_failed"):
		profile.profile_write_failed.connect(_on_profile_write_failed)
	refresh_labels()
	select_category("language")
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("focus_rail")


func _exit_tree() -> void:
	var profile: Variant = _services.get("profile")
	if is_instance_valid(profile) and profile.has_signal("profile_write_failed") \
			and profile.profile_write_failed.is_connected(_on_profile_write_failed):
		profile.profile_write_failed.disconnect(_on_profile_write_failed)
	if _controller != null:
		_controller.unbind()


func _process(_delta: float) -> void:
	# Recovery and audio settlement can finish without a profile change signal.
	# Observe only the visible title command; execution still checks admission again.
	if host_context == "title" and _selected == "records" and is_visible_in_tree():
		_refresh_entire_profile_admission()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _controller != null:
		_confirmation_generation += 1
		_reset_consent.clear()
		_controller.depart()


func _on_visibility_changed() -> void:
	if _controller == null:
		return
	if is_visible_in_tree():
		_controller.refresh()
		focus_rail()
	else:
		_confirmation_generation += 1
		_reset_consent.clear()
		_controller.depart()


func _build_content() -> void:
	PRESENTATION.apply_scroll(rail_scroll, false)
	PRESENTATION.apply_scroll(sheet_scroll, true)
	_selected_extension = Control.new()
	_selected_extension.name = "SelectedExtension"
	_selected_extension.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_extension.focus_mode = Control.FOCUS_NONE
	_selected_extension.draw.connect(_draw_selected_extension)
	add_child(_selected_extension)
	_selected_extension.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_presentation_resized)
	rail_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _selected_extension.queue_redraw())
	for state: String in ["Selected", "Focus", "Warning", "Unavailable"]:
		var specimen := PRESENTATION.StateSpecimen.new(state)
		$Footer/ControlSample.add_child(specimen)
		_sample_labels.append(specimen.caption)
	var registry: Dictionary = {}
	for record: Dictionary in REGISTRY.records():
		registry[record["path"]] = record
	for category: String in CATEGORY_FIELDS:
		var button := Button.new()
		button.name = category.to_pascal_case() + "Category"
		button.custom_minimum_size = Vector2(0, 52)
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		PRESENTATION.attach_state(button, true)
		var rail_label := _label("settings.category." + category)
		rail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(rail_label)
		rail_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rail_label.offset_left = 10
		rail_label.offset_right = -10
		rail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		$RailScroll/Rail.add_child(button)
		_rails[category] = button
		button.pressed.connect(func() -> void: select_category(category))
		button.gui_input.connect(_on_rail_input.bind(category))
		button.focus_entered.connect(_ensure_focus_visible.bind(rail_scroll, button))
		button.item_rect_changed.connect(_selected_extension.queue_redraw)
		var sheet := VBoxContainer.new()
		sheet.name = category.to_pascal_case() + "Sheet"
		sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sheet.add_theme_constant_override("separation", 16)
		$SheetScroll/Sheets.add_child(sheet)
		_sheets[category] = sheet
		for suffix: String in CATEGORY_FIELDS[category]:
			var path := StringName("preferences." + suffix)
			if not registry.has(path):
				push_error("unregistered_settings_control: " + path)
				continue
			records[path] = registry[path]
			_add_preference(sheet, registry[path])
			if suffix in ["audio.music_muted", "audio.ambience_muted", "audio.sfx_muted"]:
				_add_test(sheet, {"audio.music_muted": "Music", "audio.ambience_muted": "Ambience", "audio.sfx_muted": "SFX"}[suffix])
		if category == "reading":
			_add_test(sheet, "TTS")
		if category == "accessibility":
			_comfort_note = _label("")
			_comfort_note.name = "ListeningComfortNote"
			sheet.add_child(_comfort_note)
		if category == "controls":
			_controls_sheet = CONTROLS_SHEET.new()
			_controls_sheet.name = "ControlsBindings"
			_controls_sheet.configure(self, _services.get("profile"), _services.get("controller_mapped", Callable()), _services.get("input"))
			sheet.add_child(_controls_sheet)
			_add_resets(sheet, ["controls"])
		if category == "records":
			_add_resets(sheet, ["preferences", "visited_history", "gallery", "entire_profile"])
	_general_status = _label("")
	_general_status.name = "SettingsStatus"
	$SheetScroll/Sheets.add_child(_general_status)


func _add_preference(sheet: VBoxContainer, record: Dictionary) -> void:
	var path: StringName = record["path"]
	var row := VBoxContainer.new()
	row.name = String(path).trim_prefix("preferences.").replace(".", "_").to_pascal_case() + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label("settings." + String(path).trim_prefix("preferences.").replace(".", "_")))
	var control: Control
	match String(record["renderer"]):
		"toggle", "readonly_bool":
			control = CheckBox.new()
		"percent_slider":
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.01
			slider.scrollable = false
			control = slider
		_:
			control = OptionButton.new()
	control.name = "LanguageOption" if path == &"preferences.language.primary_locale_id" else row.name + "Control"
	control.focus_mode = Control.FOCUS_ALL
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = 48
	PRESENTATION.attach_state(control)
	row.add_child(control)
	if path == &"preferences.accessibility.steady_interface":
		var description := _label("settings.accessibility_steady_interface_description")
		description.name = "SteadyInterfaceDescription"
		row.add_child(description)
	if path == &"preferences.accessibility.large_targets":
		var description := _label("settings.accessibility_large_targets_description")
		description.name = "LargeTargetsDescription"
		row.add_child(description)
	var status := _label("")
	status.name = "LanguageStatus" if path == &"preferences.language.primary_locale_id" else row.name + "Status"
	row.add_child(status)
	sheet.add_child(row)
	controls[path] = control
	rows[path] = row
	statuses[path] = status
	control.gui_input.connect(_on_sheet_input.bind(control))
	control.focus_entered.connect(_ensure_focus_visible.bind(sheet_scroll, control))


func _add_test(sheet: VBoxContainer, kind: String) -> void:
	sheet.add_child(_label("settings.test." + kind.to_lower()))
	var button := Button.new()
	button.name = kind + "TestButton"
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_ALL
	PRESENTATION.attach_state(button)
	sheet.add_child(button)
	var status := _label("")
	status.name = kind + "TestStatus"
	sheet.add_child(status)
	test_buttons[kind] = button
	test_statuses[kind] = status
	button.pressed.connect(func() -> void: await _controller.toggle_test(kind))
	button.gui_input.connect(_on_sheet_input.bind(button))
	button.focus_entered.connect(_ensure_focus_visible.bind(sheet_scroll, button))


func _add_resets(sheet: VBoxContainer, ids: Array[String]) -> void:
	for id: String in ids:
		if id == "entire_profile" and host_context != "title":
			continue
		var button := Button.new()
		button.name = id.to_pascal_case() + "ResetButton"
		button.custom_minimum_size.y = 48
		button.focus_mode = Control.FOCUS_ALL
		PRESENTATION.attach_state(button)
		sheet.add_child(button)
		_reset_buttons[id] = button
		var dialog := RESET_CONFIRMATION.new()
		dialog.name = id.to_pascal_case() + "ResetConfirmation"
		dialog.configure(id)
		add_child(dialog)
		confirmations[id] = dialog
		dialog.dialog_hide_on_ok = false
		button.pressed.connect(_open_reset_confirmation.bind(id))
		dialog.confirmed.connect(_confirm_reset.bind(id))
		dialog.visibility_changed.connect(func() -> void:
			if not dialog.visible:
				_reset_consent.erase(id)
				restore_reset_focus(id))
		button.gui_input.connect(_on_sheet_input.bind(button))
		button.focus_entered.connect(_ensure_focus_visible.bind(sheet_scroll, button))


func _open_reset_confirmation(id: String) -> void:
	if not interaction_enabled:
		return
	if id == "entire_profile" and not can_reset_entire_profile():
		return
	_confirmation_generation += 1
	var generation := _confirmation_generation
	await _controller.depart()
	if not interaction_enabled or not is_inside_tree() or not is_visible_in_tree() or generation != _confirmation_generation:
		return
	if id == "entire_profile" and not can_reset_entire_profile():
		return
	var revision: int = _controller.get_reset_revision()
	if revision < 0:
		set_general_status("settings.status.failed")
		return
	_reset_consent[id] = revision
	confirmations[id].popup_scoped()


func _confirm_reset(id: String) -> void:
	if not interaction_enabled or not _reset_consent.has(id):
		return
	var revision: int = _reset_consent[id]
	_reset_consent.erase(id)
	confirmations[id].hide()
	await _controller.reset_profile(RESET_METHODS[id], revision)


func restore_reset_focus(id: String) -> void:
	if interaction_enabled and _reset_buttons.has(id) and _reset_buttons[id].is_visible_in_tree():
		call_deferred("_restore_reset_focus_if_current", id, _confirmation_generation)


func _restore_reset_focus_if_current(id: String, generation: int) -> void:
	if not interaction_enabled or not is_inside_tree() or generation != _confirmation_generation:
		return
	var button: Button = _reset_buttons.get(id)
	if button != null and button.is_visible_in_tree() and not button.disabled:
		button.grab_focus()


func can_reset_entire_profile() -> bool:
	if host_context != "title":
		return false
	var query: Variant = _services.get("profile_reset_admission")
	if not query is Callable or not query.is_valid():
		return false
	var admitted: Variant = query.call()
	return typeof(admitted) == TYPE_BOOL and admitted


func refresh_reset_admission(busy: bool) -> void:
	_reset_busy = busy
	for id: String in _reset_buttons:
		_reset_buttons[id].disabled = busy or (id == "entire_profile" and not can_reset_entire_profile())
		_reset_buttons[id].queue_redraw()


func _refresh_entire_profile_admission() -> void:
	var button: Button = _reset_buttons.get("entire_profile")
	if button == null:
		return
	var disabled := _reset_busy or not can_reset_entire_profile()
	if button.disabled != disabled:
		button.disabled = disabled
		button.queue_redraw()


func _label(key: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrapped.append(label)
	if not key.is_empty():
		_localized_labels[label] = key
	return label


func _ensure_focus_visible(scroll: ScrollContainer, control: Control) -> void:
	scroll.ensure_control_visible(control)
	call_deferred("_clear_focus_perimeter", scroll, control)


func _clear_focus_perimeter(scroll: ScrollContainer, control: Control) -> void:
	if not is_instance_valid(control) or not control.has_focus() or not control.is_visible_in_tree():
		return
	var to_scroll := scroll.get_global_transform().affine_inverse()
	var target := (to_scroll * control.get_global_rect()).grow(8)
	var viewport := Rect2(Vector2.ZERO, scroll.size)
	if control == controls.get(&"preferences.accessibility.steady_interface"):
		var reading_row: Rect2 = (to_scroll * rows[&"preferences.accessibility.steady_interface"].get_global_rect()).grow(8)
		if reading_row.size.y <= viewport.size.y:
			target = reading_row
	if target.position.y < viewport.position.y:
		scroll.scroll_vertical -= ceili(viewport.position.y - target.position.y)
	elif target.end.y > viewport.end.y:
		scroll.scroll_vertical += ceili(target.end.y - viewport.end.y)


func refresh_labels() -> void:
	$Heading/CategoryHeading.text = text("settings.category." + _selected)
	for label: Label in _localized_labels:
		label.text = text(_localized_labels[label])
	for category: String in _rails:
		_rails[category].accessibility_name = text("settings.category." + category)
	for path: StringName in controls:
		var control: Control = controls[path]
		control.accessibility_name = text("settings." + String(path).trim_prefix("preferences.").replace(".", "_"))
		if path == &"preferences.accessibility.steady_interface":
			control.accessibility_description = text("settings.accessibility_steady_interface_description")
		if path == &"preferences.accessibility.large_targets":
			control.accessibility_description = text("settings.accessibility_large_targets_description")
		if control is OptionButton:
			var option := control as OptionButton
			option.clear()
			for value: Variant in records[path]["allowed_values"]:
				var caption := ""
				if path == &"preferences.display.window_size":
					caption = str(value).replace("x", " × ")
				elif String(path).ends_with("locale_id"):
					caption = _locale_name(str(value))
				else:
					caption = text(("settings.rate." if path == &"preferences.reading.read_aloud_rate" else "settings.value.") + str(value))
				option.add_item(caption)
				option.set_item_metadata(option.item_count - 1, value)
	for id: String in _reset_buttons:
		_reset_buttons[id].text = text("settings.reset." + id)
		confirmations[id].title = text("settings.reset." + id)
		confirmations[id].dialog_text = text("settings.confirm." + id)
		confirmations[id].get_cancel_button().text = text("settings.cancel")
		confirmations[id].get_ok_button().text = text("settings.reset." + id)
	_comfort_note.text = COMFORT.first_run_note(current_locale())
	refresh_binding_labels()
	if _controller != null:
		_controller.refresh()


func refresh_binding_labels() -> void:
	if _controls_sheet != null:
		_controls_sheet.refresh()


func _refresh_discovered_dark_mode() -> void:
	var path := &"preferences.dark_mode.next_run_enabled"
	if not rows.has(path): return
	var profile: Object = _services.get("profile")
	var available: Variant = profile.get_preference(&"preferences.dark_mode.available", false) if profile != null else false
	var discovered: bool = typeof(available) == TYPE_BOOL and available
	rows[path].visible = discovered
	controls[path].disabled = controls[path].disabled or not discovered

func apply_text_size(percent: int, large_targets: bool) -> void:
	_refresh_discovered_dark_mode()
	var locale := current_locale().replace("_", "-")
	var palette_id := get_palette_id()
	var day: Variant = null if _scene_presentation else (1 if host_context == "title" else _run_day)
	var presentation_profile: Variant = _services.get("profile")
	var font_style := str(presentation_profile.get_preference(&"preferences.accessibility.font_style", "pixel")) if presentation_profile != null else "pixel"
	var contrast_value: Variant = presentation_profile.get_preference(&"preferences.accessibility.high_contrast", false) if presentation_profile != null else false
	var colour_value: Variant = presentation_profile.get_preference(&"preferences.accessibility.colour_differentiation", "standard") if presentation_profile != null else "standard"
	if typeof(contrast_value) != TYPE_BOOL or typeof(colour_value) != TYPE_STRING:
		return
	var high_contrast: bool = contrast_value
	var colour_preset: String = colour_value
	var font_size := roundi(24.0 * float(percent) / 100.0)
	if locale != _presentation_locale or font_style != _presentation_font_style or percent != _presentation_percent or palette_id != _presentation_palette \
			or high_contrast != _presentation_high_contrast or colour_preset != _presentation_colour_preset or day != _presentation_day:
		var candidate := PRESENTATION._build_context(locale, percent, palette_id, high_contrast, colour_preset, day, font_style, _scene_presentation)
		if candidate == null:
			return
		_presentation_locale = locale
		_presentation_font_style = font_style
		_presentation_percent = percent
		_presentation_palette = palette_id
		_presentation_high_contrast = high_contrast
		_presentation_colour_preset = colour_preset
		_presentation_day = day
		theme = candidate
		PRESENTATION.apply_scroll(rail_scroll, false)
		PRESENTATION.apply_scroll(sheet_scroll, true)
		for category: String in _rails:
			PRESENTATION.apply_category(_rails[category], category == _selected)
	$Heading/CategoryHeading.add_theme_font_size_override("font_size", font_size)
	if _controls_sheet != null:
		_controls_sheet.set_presentation(theme, font_size, large_targets)
	var sample_copy: Array = PRESENTATION.SAMPLE_COPY.get(locale, PRESENTATION.SAMPLE_COPY.en)
	for index: int in range(_sample_labels.size()):
		_sample_labels[index].text = sample_copy[index]
		_sample_labels[index].add_theme_font_size_override("font_size", font_size)
		_sample_labels[index].get_parent().queue_redraw()
	for label: Label in _wrapped:
		label.add_theme_font_size_override("font_size", font_size)
	for control: Control in controls.values() + test_buttons.values() + _reset_buttons.values():
		control.add_theme_font_size_override("font_size", font_size)
		control.custom_minimum_size.y = maxf(64.0 if large_targets else 48.0, float(font_size) * 2.0)
		control.queue_redraw()
	for path: StringName in controls:
		var control: Control = controls[path]
		if control is OptionButton:
			control.get_popup().theme = theme
		if control is CheckBox:
			control.text = text("settings.value.on" if control.button_pressed else "settings.value.off")
		if control is HSlider:
			var profile: Variant = _services.get("profile")
			control.set_meta("settings_committed_value", float(profile.get_preference(path, control.value)) if profile != null else control.value)
			PRESENTATION.apply_volume_value(statuses[path], bool(statuses[path].get_meta("settings_volume_preview", false)))
		var unavailable := false
		for key: String in ["settings.status.unavailable", "settings.status.no_compatible_voice", "settings.status.locales_unavailable"]:
			unavailable = unavailable or statuses[path].text == text(key)
		control.set_meta("settings_unavailable", unavailable)
	for button: Button in _rails.values():
		var label := button.get_child(0) as Label
		var advance := theme.default_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		# Use the remaining rail width before splitting a nearly fitting category word.
		var inset := 4.0 if advance > 172.0 and advance <= 184.0 else 10.0
		label.offset_left = inset
		label.offset_right = -inset
		# Match AUTOWRAP_WORD_SMART, including long words such as Accessibility.
		var breaks := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		var text_height := theme.default_font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, 192.0 - inset * 2.0, font_size, -1, breaks).y
		button.custom_minimum_size.y = maxf(64.0 if large_targets else 52.0, text_height + 16.0)
	for dialog: ConfirmationDialog in confirmations.values():
		dialog.set_presentation(theme, font_size, large_targets)
		dialog.get_label().add_theme_font_size_override("font_size", font_size)
		for button: Button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
			button.add_theme_font_size_override("font_size", font_size)
			button.custom_minimum_size.y = maxf(64.0 if large_targets else 48.0, float(font_size) * 2.0)
	queue_redraw()
	_selected_extension.queue_redraw()


func set_volume_value_presentation(path: StringName, value: float, preview: bool, reason: String = "") -> void:
	if not statuses.has(path):
		return
	var label: Label = statuses[path]
	var active := preview and interaction_enabled and reason.is_empty()
	label.set_meta("settings_volume_preview", active)
	label.text = text(reason) if not reason.is_empty() else (text("settings.value.preview") + " " if active else "") + "%d%%" % roundi(value * 100.0)
	PRESENTATION.apply_volume_value(label, active)


func text(key: String, parameters: Dictionary = {}) -> String:
	var localization: Variant = _services.get("localization")
	if localization != null and localization.has_method("has_key") and localization.has_key(key):
		return localization.t(key, parameters)
	return key


func current_locale() -> String:
	var profile: Variant = _services.get("profile")
	return str(profile.get_preference(&"preferences.language.primary_locale_id", "en")) if profile != null else "en"


func get_palette_id() -> StringName:
	# Pending title intent is never a substitute for a captured in-run palette.
	if host_context != "title":
		return _run_palette
	var profile: Variant = _services.get("profile")
	if not is_instance_valid(profile) or not profile.has_method("get_preference"):
		return &"after_hours"
	var available: Variant = profile.get_preference(&"preferences.dark_mode.available", false)
	var pending: Variant = profile.get_preference(&"preferences.dark_mode.next_run_enabled", false)
	return &"midnight" if typeof(available) == TYPE_BOOL and available \
			and typeof(pending) == TYPE_BOOL and pending else &"after_hours"


func _locale_name(locale: String) -> String:
	var localization: Variant = _services.get("localization")
	if localization != null:
		for record: Dictionary in localization.get_selectable_locales():
			if record["id"] == locale:
				return localization.t("locale.release_status.draft", {"native_name": record["native_name"]}) if record["release_status"] == "draft" else record["native_name"]
	return locale


func get_controller() -> RefCounted:
	return _controller


func control_for(path: StringName) -> Control:
	return controls.get(path)


func get_category_ids() -> Array:
	return CATEGORY_FIELDS.keys()


func wrapping_labels() -> Array[Label]:
	return _wrapped.duplicate()


func test_status(kind: String) -> String:
	return test_statuses[kind].text


func set_general_status(key: String) -> void:
	if _profile_write_uncertain: key = "settings.status.uncertain"
	_general_status.text = "" if key.is_empty() else text(key)
	_general_status.visible = not key.is_empty()


func is_profile_write_uncertain() -> bool:
	return _profile_write_uncertain


func _on_profile_write_failed(result: Dictionary) -> void:
	if _profile_write_uncertain or not (result.get("fatal", false) or result.get("code") == &"indeterminate_commit"):
		return
	# Fence immediately. The output transaction still owns its synchronous failure
	# compensation; presentation cleanup must wait until its stack has unwound.
	_profile_write_uncertain = true
	interaction_enabled = false
	call_deferred("_present_profile_write_uncertainty")


func _present_profile_write_uncertainty() -> void:
	if not is_inside_tree(): return
	set_interaction_enabled(false)
	set_general_status("settings.status.uncertain")
	_controller.depart()
	if is_instance_valid(_write_recovery): return
	_write_recovery = WRITE_RECOVERY.instantiate()
	_write_recovery.name = "SettingsWriteRecovery"
	add_child(_write_recovery)
	_write_recovery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var profile: Variant = _services.get("profile")
	if not _write_recovery.bind_owners(_services.get("localization"), _services.get("input"), func() -> bool: return false): return
	if not _write_recovery.configure_presentation(current_locale(),
		int(profile.get_preference(&"preferences.accessibility.text_size", 100)), String(get_palette_id()),
		bool(profile.get_preference(&"preferences.accessibility.high_contrast", false)),
		String(profile.get_preference(&"preferences.accessibility.colour_differentiation", "standard")),
		bool(profile.get_preference(&"preferences.accessibility.large_targets", false)),
		String(profile.get_preference(&"preferences.accessibility.font_style", "pixel"))): return
	_write_recovery.present(false, false, &"settings")


func select_category(category: String) -> void:
	if not _sheets.has(category):
		return
	if category != _selected and _controller != null:
		_confirmation_generation += 1
		_reset_consent.clear()
		_controller.depart()
	_selected = category
	for id: String in _sheets:
		_sheets[id].visible = id == category
		_rails[id].set_pressed_no_signal(id == category)
		PRESENTATION.apply_category(_rails[id], id == category)
	$Heading/CategoryHeading.text = text("settings.category." + category)
	$Footer.visible = category == "accessibility"
	$Footer/ControlSample.visible = category == "accessibility"
	sheet_scroll.offset_bottom = $Footer.offset_top if category == "accessibility" else $Footer.offset_bottom
	sheet_scroll.scroll_vertical = 0
	queue_redraw()
	_selected_extension.queue_redraw()


func _draw_selected_extension() -> void:
	if not _rails.has(_selected):
		return
	var button: Button = _rails[_selected]
	var row := get_global_transform().affine_inverse() * button.get_global_rect()
	var top := maxf(row.position.y, rail_scroll.position.y + 8)
	var bottom := minf(row.end.y, rail_scroll.position.y + rail_scroll.size.y - 8)
	if bottom <= top:
		return
	# Only paint crosses the spine: no target, focus, or category semantics move.
	var extension := Rect2(224, top, 16, bottom - top)
	var roles := PRESENTATION.roles_for(self)
	_selected_extension.draw_rect(extension, roles.filed)
	_selected_extension.draw_line(Vector2(extension.position.x, top), Vector2(240, top), roles.paper_ink, 2)
	_selected_extension.draw_line(Vector2(extension.position.x, bottom), Vector2(240, bottom), roles.paper_ink, 2)


func _on_presentation_resized() -> void:
	queue_redraw()
	_selected_extension.queue_redraw()


func _draw() -> void:
	var roles := PRESENTATION.roles_for(self)
	draw_rect(Rect2(Vector2.ZERO, size), roles.habitat)
	draw_rect(Rect2(16, 16, 208, 624), roles.face)
	draw_rect(Rect2(240, 16, size.x - 256, 624), roles.paper)
	draw_line(Vector2(232, 24), Vector2(232, 632), roles.structure, 2)
	draw_line(Vector2(256, 95), Vector2(size.x - 32, 95), roles.paper_ink, 2)
	if _selected == "accessibility":
		draw_line(Vector2(256, 495), Vector2(size.x - 32, 495), roles.paper_ink, 2)


func focus_rail() -> void:
	if _selected == "controls" and _controls_sheet != null and _controls_sheet.restore_pending_focus():
		return
	if interaction_enabled and is_visible_in_tree() and _rails.has(_selected):
		_rails[_selected].grab_focus()


func focus_sheet() -> void:
	if not interaction_enabled:
		return
	for control: Control in _sheet_focusables(_sheets[_selected]):
		control.grab_focus()
		return


func _sheet_focusables(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.focus_mode == Control.FOCUS_ALL:
			if (child is BaseButton and child.disabled) or (child is Slider and not child.editable):
				continue
			found.append(child)
		found.append_array(_sheet_focusables(child))
	return found


func sheet_has_focus() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused != null and sheet_scroll.is_ancestor_of(focused)


func handle_back() -> void:
	if not interaction_enabled:
		return
	if await _controller.back():
		return
	if sheet_has_focus():
		focus_rail()
	else:
		close_requested.emit()


func _on_rail_input(event: InputEvent, category: String) -> void:
	if not interaction_enabled:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_focus_next"):
		focus_sheet()
		accept_event()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var categories: Array = get_category_ids()
		var delta := 1 if event.is_action_pressed("ui_down") else -1
		select_category(categories[posmod(categories.find(category) + delta, categories.size())])
		focus_rail()
		accept_event()


func _on_sheet_input(event: InputEvent, control: Control) -> void:
	if not interaction_enabled:
		return
	if control is HSlider and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		accept_event()
		for path: StringName in controls:
			if controls[path] == control:
				await _controller.step_volume(path, 1 if event.is_action_pressed("ui_right") else -1)
		accept_event()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_focus_prev"):
		focus_rail()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not interaction_enabled or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		await handle_back()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		var delta := -1 if event.keycode == KEY_PAGEUP else 1
		sheet_scroll.scroll_vertical += roundi(sheet_scroll.size.y * 0.85) * delta
		get_viewport().set_input_as_handled()
