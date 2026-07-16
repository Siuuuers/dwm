extends Node
# InputManager (CONTRACTS §7): owns input actions, controller mappings, focus helpers,
# and safe rebinds. Does not hardcode keyboard-only logic in UI. Every gameplay button
# must be keyboard/controller focusable.

signal input_scheme_changed(scheme: String)
signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)
signal input_bindings_changed()

const INPUT_SETTINGS_PATH := "user://input_bindings.json"

# game_* actions and their default keyboard keys. The ui_* actions are provided by Godot.
const _DEFAULT_GAME_ACTIONS := {
	"game_quick_save": KEY_F5,
	"game_quick_load": KEY_F9,
	"game_open_log": KEY_L,
	"game_skip_text": KEY_CTRL,
	"game_toggle_auto": KEY_A,
	"game_hint": KEY_H,
	"game_new_board": KEY_N,
	"game_close_window": KEY_ESCAPE,
	"game_next_tab": KEY_E,
	"game_prev_tab": KEY_Q,
	"game_page_next": KEY_BRACKETRIGHT,
	"game_page_prev": KEY_BRACKETLEFT,
	"game_open_settings": KEY_F1,
	"game_open_schedule": KEY_F2,
	"game_open_contacts": KEY_F3,
}

const _REQUIRED_UI_ACTIONS := [
	"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
	"ui_focus_next", "ui_focus_prev",
]

var _current_scheme: String = "keyboard"


func _ready() -> void:
	ensure_default_input_map()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func ensure_default_input_map() -> void:
	# Ensure ui_* exist (Godot usually provides them; add empty ones if missing so lookups are safe).
	for action in _REQUIRED_UI_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	# Add the game_* actions with default keyboard bindings if absent.
	for action in _DEFAULT_GAME_ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var ev := InputEventKey.new()
			ev.physical_keycode = _DEFAULT_GAME_ACTIONS[action]
			InputMap.action_add_event(action, ev)


func get_current_input_scheme() -> String:
	return _current_scheme


func set_current_input_scheme(scheme: String) -> void:
	if scheme != _current_scheme:
		_current_scheme = scheme
		emit_signal("input_scheme_changed", scheme)


func is_controller_connected() -> bool:
	return Input.get_connected_joypads().size() > 0


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		emit_signal("controller_connected", device_id)
	else:
		emit_signal("controller_disconnected", device_id)


func get_action_label(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return ""
	var events := InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			var code: int = (ev as InputEventKey).physical_keycode
			if code == 0:
				code = (ev as InputEventKey).keycode
			return OS.get_keycode_string(code)
		if ev is InputEventJoypadButton:
			return "Joy %d" % (ev as InputEventJoypadButton).button_index
	return ""


func rebind_action(action_name: String, event: InputEvent) -> Dictionary:
	if not InputMap.has_action(action_name):
		return {"ok": false, "reason": "unknown_action", "action": action_name}
	if event == null:
		return {"ok": false, "reason": "null_event", "action": action_name}
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	emit_signal("input_bindings_changed")
	return {"ok": true, "action": action_name}


func reset_bindings_to_default() -> void:
	for action in _DEFAULT_GAME_ACTIONS.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	ensure_default_input_map()
	emit_signal("input_bindings_changed")


func save_input_settings() -> void:
	var out: Dictionary = {}
	for action in _DEFAULT_GAME_ACTIONS.keys():
		if not InputMap.has_action(action):
			continue
		var codes: Array = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				codes.append((ev as InputEventKey).physical_keycode)
		out[action] = codes
	var f := FileAccess.open(INPUT_SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out))
		f.close()


func load_input_settings() -> void:
	if not FileAccess.file_exists(INPUT_SETTINGS_PATH):
		return
	var f := FileAccess.open(INPUT_SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	for action in (json.data as Dictionary).keys():
		if not InputMap.has_action(action):
			continue
		var codes = json.data[action]
		if not (codes is Array):
			continue
		InputMap.action_erase_events(action)
		for code in codes:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(code)
			InputMap.action_add_event(action, ev)
	emit_signal("input_bindings_changed")


# ---- Focus helpers ----
func focus_first_control(root: Node) -> bool:
	var target := _find_first_focusable(root)
	if target != null:
		target.grab_focus()
		return true
	return false


func _find_first_focusable(node: Node) -> Control:
	if node == null:
		return null
	if node is Control:
		var c := node as Control
		if c.focus_mode == Control.FOCUS_ALL and c.visible and not _is_disabled(c):
			return c
	for child in node.get_children():
		var found := _find_first_focusable(child)
		if found != null:
			return found
	return null


func _is_disabled(control: Control) -> bool:
	if control is BaseButton:
		return (control as BaseButton).disabled
	return false


func make_button_focusable(button: BaseButton) -> void:
	if button != null:
		button.focus_mode = Control.FOCUS_ALL


func apply_focus_to_tree(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		(root as BaseButton).focus_mode = Control.FOCUS_ALL
	for child in root.get_children():
		apply_focus_to_tree(child)
