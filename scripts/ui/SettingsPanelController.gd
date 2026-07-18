class_name SettingsPanelController
extends RefCounted

const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")

var _host: Node
var _language_option: OptionButton
var _language_status: Label
var _accessibility_container: VBoxContainer
var _audio_container: VBoxContainer
var _profile: Node
var _localization: Node
var _controls: Dictionary = {}
var _confirmations: Dictionary = {}


func bind(host: Node, language_option: OptionButton, language_status: Label, accessibility_container: VBoxContainer, audio_container: VBoxContainer) -> Dictionary:
	if _host != null:
		return _fail(&"already_bound")
	if host == null or language_option == null or language_status == null or accessibility_container == null or audio_container == null:
		return _fail(&"invalid_settings_host")
	_profile = host.get_node_or_null("/root/ProfileManager")
	_localization = host.get_node_or_null("/root/LocalizationManager")
	if _profile == null or _localization == null:
		return _fail(&"settings_dependencies_unavailable")
	_host = host
	_language_option = language_option
	_language_status = language_status
	_accessibility_container = accessibility_container
	_audio_container = audio_container
	_build_language_options()
	_build_preference_controls()
	_build_reset_controls()
	if not _language_option.item_selected.is_connected(_on_language_selected):
		_language_option.item_selected.connect(_on_language_selected)
	if not _profile.preference_changed.is_connected(_on_preference_changed):
		_profile.preference_changed.connect(_on_preference_changed)
	return _success()


func unbind() -> Dictionary:
	if _language_option != null and _language_option.item_selected.is_connected(_on_language_selected):
		_language_option.item_selected.disconnect(_on_language_selected)
	if _profile != null and _profile.preference_changed.is_connected(_on_preference_changed):
		_profile.preference_changed.disconnect(_on_preference_changed)
	_host = null
	_language_option = null
	_language_status = null
	_accessibility_container = null
	_audio_container = null
	_profile = null
	_localization = null
	_controls.clear()
	_confirmations.clear()
	return _success()


func _build_language_options() -> void:
	_language_option.clear()
	var selected := 0
	var current: String = _localization.get_locale()
	for locale in _localization.get_selectable_locales():
		var display_name: String = locale["native_name"]
		if locale["release_status"] == "draft":
			display_name = _localization.t("locale.release_status.draft", {"native_name": display_name})
		var index := _language_option.item_count
		_language_option.add_item(display_name)
		_language_option.set_item_metadata(index, locale["id"])
		if locale["id"] == current:
			selected = index
	_language_option.select(selected)
	_language_status.text = _language_option.get_item_text(selected) if _language_option.item_count > 0 else ""


func _build_preference_controls() -> void:
	var paths: Array = PROFILE_SCHEMA.PREFERENCE_DEFAULTS.keys()
	paths.sort()
	for path_value in paths:
		var path := StringName(path_value)
		if path in [&"preferences.language", &"preferences.dialogue.skip_mode", &"preferences.accessibility.colorblind_mode"]:
			continue
		var container := _audio_container if String(path).begins_with("preferences.audio.") else _accessibility_container
		var default_value: Variant = PROFILE_SCHEMA.PREFERENCE_DEFAULTS[String(path)]
		if typeof(default_value) == TYPE_BOOL:
			_add_boolean_control(container, path)
		elif typeof(default_value) == TYPE_FLOAT:
			_add_float_control(container, path)
	var skip := OptionButton.new()
	skip.name = "SkipModeOption"
	skip.add_item(_localization.t("settings.dialogue.skip_mode.read_only"))
	skip.set_item_metadata(0, "read_only")
	skip.add_item(_localization.t("settings.dialogue.skip_mode.all_text"))
	skip.set_item_metadata(1, "all_text")
	var current_skip := str(_profile.get_preference(&"preferences.dialogue.skip_mode", "read_only"))
	skip.select(1 if current_skip == "all_text" else 0)
	skip.item_selected.connect(func(index: int) -> void: _profile.set_preference(&"preferences.dialogue.skip_mode", skip.get_item_metadata(index)))
	_accessibility_container.add_child(skip)
	_controls[&"preferences.dialogue.skip_mode"] = skip
	_add_colorblind_control()


func _add_boolean_control(container: VBoxContainer, path: StringName) -> void:
	var checkbox := CheckBox.new()
	checkbox.name = String(path).get_file().to_pascal_case()
	checkbox.text = _localization.t("settings.%s" % String(path).trim_prefix("preferences.").replace(".", "_"))
	checkbox.button_pressed = bool(_profile.get_preference(path, false))
	checkbox.toggled.connect(func(value: bool) -> void: _profile.set_preference(path, value))
	container.add_child(checkbox)
	_controls[path] = checkbox


func _add_float_control(container: VBoxContainer, path: StringName) -> void:
	var row := HBoxContainer.new()
	row.name = "%sRow" % String(path).get_file().to_pascal_case()
	var label := Label.new()
	label.text = _localization.t("settings.%s" % String(path).trim_prefix("preferences.").replace(".", "_"))
	var slider := HSlider.new()
	slider.name = String(path).get_file().to_pascal_case()
	slider.min_value = 0.05 if String(path).ends_with("text_speed") or String(path).ends_with("font_scale") else 0.0
	slider.max_value = 3.0 if String(path).ends_with("text_speed") or String(path).ends_with("font_scale") else 1.0
	slider.step = 0.05
	slider.value = float(_profile.get_preference(path, PROFILE_SCHEMA.PREFERENCE_DEFAULTS[String(path)]))
	slider.value_changed.connect(func(value: float) -> void: _profile.set_preference(path, value))
	row.add_child(label)
	row.add_child(slider)
	container.add_child(row)
	_controls[path] = slider


func _add_colorblind_control() -> void:
	var option := OptionButton.new()
	option.name = "ColorblindModeOption"
	var values := ["none", "protanopia", "deuteranopia", "tritanopia"]
	for value in values:
		option.add_item(_localization.t("settings.accessibility.colorblind_mode.%s" % value))
		option.set_item_metadata(option.item_count - 1, value)
	var current := str(_profile.get_preference(&"preferences.accessibility.colorblind_mode", "none"))
	option.select(values.find(current))
	option.item_selected.connect(func(index: int) -> void: _profile.set_preference(&"preferences.accessibility.colorblind_mode", option.get_item_metadata(index)))
	_accessibility_container.add_child(option)
	_controls[&"preferences.accessibility.colorblind_mode"] = option


func _build_reset_controls() -> void:
	for record in [
		{"id": &"preferences", "method": &"reset_preferences"},
		{"id": &"visited_history", "method": &"reset_visited_history"},
		{"id": &"gallery", "method": &"reset_gallery"},
		{"id": &"entire_profile", "method": &"reset_entire_profile"},
	]:
		var button := Button.new()
		button.name = "%sResetButton" % String(record["id"]).to_pascal_case()
		button.text = _localization.t("settings.reset.%s" % record["id"])
		var dialog := ConfirmationDialog.new()
		dialog.name = "%sResetConfirmation" % String(record["id"]).to_pascal_case()
		_host.add_child(dialog)
		button.pressed.connect(dialog.popup_centered)
		dialog.confirmed.connect(func() -> void: _profile.call(record["method"]))
		_accessibility_container.add_child(button)
		_confirmations[record["id"]] = dialog


func _on_language_selected(index: int) -> void:
	var locale_id := str(_language_option.get_item_metadata(index))
	var result: Dictionary = _localization.set_locale(locale_id)
	if result.get("ok", false):
		_language_status.text = _language_option.get_item_text(index)


func _on_preference_changed(path: StringName, value: Variant) -> void:
	if not _controls.has(path):
		return
	var control: Control = _controls[path]
	if control is OptionButton:
		var option := control as OptionButton
		for index in range(option.item_count):
			if option.get_item_metadata(index) == value:
				option.select(index)
				break
	elif control is BaseButton:
		(control as BaseButton).set_pressed_no_signal(value)
	elif control is Range:
		(control as Range).set_value_no_signal(float(value))


func _success() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
