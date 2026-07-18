extends Node
# InputManager (CONTRACTS §7): owns input actions, controller mappings, focus helpers,
# and safe rebinds. Does not hardcode keyboard-only logic in UI. Every gameplay button
# must be keyboard/controller focusable.

signal input_scheme_changed(scheme: String)
signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)
signal input_bindings_changed()

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
var _profile: Node
var _mutation_gate: Object


func _ready() -> void:
	pass

func configure_mutation_gate(gate: Object) -> Dictionary:
	return _configure_gate(gate)

func initialize(profile: Node) -> Dictionary:
	if profile == null or not profile.has_method("get_input_mappings") or not profile.has_method("set_input_mapping"):
		return {"ok": false, "code": &"invalid_profile_manager"}
	_profile = profile
	ensure_default_input_map()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed): Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if not profile.input_mappings_changed.is_connected(apply_profile_mappings): profile.input_mappings_changed.connect(apply_profile_mappings)
	apply_profile_mappings()
	return {"ok": true}

func apply_profile_mappings(action_id: StringName = &"") -> Dictionary:
	if _profile == null: return {"ok": false, "code": &"not_initialized"}
	var mappings: Dictionary = _profile.get_input_mappings()
	var actions: Array = [String(action_id)] if action_id != &"" else mappings.keys()
	for action_value in actions:
		var action := String(action_value)
		if not mappings.has(action) or not InputMap.has_action(action): continue
		InputMap.action_erase_events(action)
		for record: Dictionary in mappings[action]:
			var event: InputEvent
			if record["kind"] == "key":
				var key_event := InputEventKey.new()
				key_event.physical_keycode = record["physical_keycode"]
				key_event.keycode = record["keycode"]
				key_event.shift_pressed = record["shift"]
				key_event.alt_pressed = record["alt"]
				key_event.ctrl_pressed = record["ctrl"]
				key_event.meta_pressed = record["meta"]
				event = key_event
			else:
				var joy_event := InputEventJoypadButton.new()
				joy_event.button_index = record["button_index"]
				joy_event.device = record["device"]
				event = joy_event
			InputMap.action_add_event(action, event)
	emit_signal("input_bindings_changed")
	return {"ok": true}


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
	if _profile == null: return {"ok": false, "reason": "not_initialized", "action": action_name}
	var record: Dictionary
	if event is InputEventKey:
		var key_event := event as InputEventKey
		record = {"kind": "key", "physical_keycode": key_event.physical_keycode, "keycode": key_event.keycode, "shift": key_event.shift_pressed, "alt": key_event.alt_pressed, "ctrl": key_event.ctrl_pressed, "meta": key_event.meta_pressed}
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		record = {"kind": "joypad_button", "button_index": joy_event.button_index, "device": joy_event.device}
	else: return {"ok": false, "reason": "unsupported_event", "action": action_name}
	return _profile.set_input_mapping(StringName(action_name), [record])


func reset_bindings_to_default() -> void:
	for action in _DEFAULT_GAME_ACTIONS.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	ensure_default_input_map()
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

func _configure_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method): return {"ok": false, "code": &"invalid_mutation_gate", "details": {}, "receipt": {}}
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id(): return {"ok": false, "code": &"mutation_gate_already_configured", "details": {}, "receipt": {}}
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}
