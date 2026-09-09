extends Control
## Transient art-only reading surface. Its Continue starts the original DTL; it witnesses no text.
signal continue_requested(token: String)
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
var art: ART_VIEW
var next_button: Button
var _token := ""
var _entry_id := ""
var _percent := 100
var _locale := "en"
var _show_portraits := true
var _drawn := false
var _paused := false
var _retired := false
var _covered := false
var _await_neutral := true
var _anchor: Dictionary = {}
var _capture_id := 0
var _input_owner: Node

func configure(entry_id: String, token: String, percent: int = 100,
		locale: String = "en", show_portraits: bool = true) -> bool:
	_token = token
	_entry_id = entry_id
	_percent = percent
	_locale = locale
	_show_portraits = show_portraits
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	size = Vector2(1280, 720)
	var background := ColorRect.new()
	background.color = Color("151920")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = size
	add_child(background)
	art = ART_VIEW.new()
	art.name = "SceneArt"
	add_child(art)
	art.configure_entry(entry_id, percent, false, show_portraits)
	art.draw.connect(_on_art_drawn)
	next_button = Button.new()
	next_button.name = "ContinueArt"
	next_button.text = "Continue" if not locale.begins_with("zh") else "\u7e7c\u7e8c" if locale == "zh-HK" else "\u7ee7\u7eed"
	next_button.position = Vector2(448, 656)
	next_button.size = Vector2(384, 48)
	next_button.add_theme_font_size_override("font_size", int(20 * percent / 100.0))
	next_button.focus_mode = Control.FOCUS_ALL
	next_button.disabled = true
	next_button.pressed.connect(_on_continue)
	add_child(next_button)
	return art.visible

func _ready() -> void:
	_input_owner = get_node_or_null("/root/InputManager")
	var profile := get_node_or_null("/root/ProfileManager")
	if profile != null and profile.has_signal("preference_changed"):
		profile.connect("preference_changed", _on_preference_changed)
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null and localization.has_signal("locale_changed"):
		localization.connect("locale_changed", _on_locale_changed)

func _on_preference_changed(path: StringName, value: Variant) -> void:
	if path == &"preferences.accessibility.text_size" and value is int and value in [100, 125, 150]:
		_percent = value
		_refresh_reading_preferences()

func _on_locale_changed(locale: String) -> void:
	_locale = locale.replace("_", "-")
	_refresh_reading_preferences()

func _refresh_reading_preferences() -> void:
	if _retired: return
	art.configure_entry(_entry_id, _percent, false, _show_portraits)
	next_button.add_theme_font_size_override("font_size", int(20 * _percent / 100.0))
	next_button.text = "Continue" if not _locale.begins_with("zh") else "\u7e7c\u7e8c" if _locale == "zh-HK" else "\u7ee7\u7eed"

func _on_art_drawn() -> void:
	if not _retired: _drawn = true

func has_drawn_art() -> bool:
	return _drawn and not _retired

func _process(_delta: float) -> void:
	if _retired: return
	var held := Input.is_action_pressed(&"ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _input_owner != null and _input_owner.has_method("get_physical_contacts"):
		held = not _input_owner.get_physical_contacts().is_empty()
	if _await_neutral and not held: _await_neutral = false
	var admitted := _input_owner == null or not _input_owner.has_method("is_source_input_admitted") \
		or bool(_input_owner.is_source_input_admitted())
	var enabled := _drawn and not _paused and not _covered and not _await_neutral \
		and not get_tree().paused and admitted
	var was_disabled := next_button.disabled
	next_button.disabled = not enabled
	if enabled and was_disabled and is_visible_in_tree(): next_button.grab_focus()

func _on_continue() -> void:
	if _retired or _paused or _covered or not _drawn or _await_neutral or next_button.disabled: return
	next_button.disabled = true
	continue_requested.emit(_token)

func set_presentation_paused(value: bool) -> void:
	_paused = value
	if value: next_button.disabled = true

func retire() -> void:
	_retired = true
	hide()
	set_process(false)
	next_button.disabled = true

func capture_pause_view(source: Dictionary) -> Dictionary:
	if not has_drawn_art() or _covered or not is_visible_in_tree():
		return {"ok": false, "code": &"pause_view_unavailable"}
	_capture_id += 1
	_anchor = {"view_id": get_instance_id(), "capture_id": _capture_id,
		"token": _token, "source": source.duplicate(true)}
	return {"ok": true, "value": _anchor.duplicate(true)}

func cover_pause_view(anchor: Dictionary) -> bool:
	if _retired or anchor != _anchor or _anchor.is_empty(): return false
	_covered = true
	hide()
	return true

func restore_pause_view(anchor: Dictionary) -> bool:
	if _retired or anchor != _anchor or _anchor.is_empty(): return false
	_covered = false
	show()
	return true
